#!/usr/bin/env python3
"""Monte Carlo playthroughs: many sped-up automated runs per persona, in parallel.

Usage (from the project root):
    python3 tools/montecarlo.py --runs 40                 # 40 runs per persona
    python3 tools/montecarlo.py --analyze-only            # recompute from saved runs

Each run is tests/playthrough.gd (headless, --fixed-fps 60, ~100x real time) with a different
seed. Raw results are saved to montecarlo/runs/<persona>_<seed>.json; the report goes to
montecarlo/report.md and is printed.

MODELS (heuristics - documented so they can be challenged and tuned):

Drop (quit) model - a run's level records are replayed through a quitting rule:
  - after each game over on a level, a player quits with probability
        q = QUIT_BASE[persona] * (1 + 0.5 * (game_overs_so_far_on_this_level - 1))   (max 0.9)
  - a level that is cleared with zero deaths in under 40% of its par time bores a skilled
    player: speedrunner/average quit with probability BOREDOM_QUIT[persona]
  - a run where the bot hit its retry limit counts as a certain quit at that level
  Drop rate(level) = share of players who started the level and quit during it.

Fun score (0-100) per level, averaged over the runs that played it:
  challenge   0.35  deaths per minute close to the persona's sweet spot (bell curve)
  frustration 0.25  1 - min(game_overs, 4) / 4
  rhythm      0.20  on-beat share of judged clicks ((perfect + good) / judged)
  skills      0.10  skill casts per minute, saturating at 2/min, minus fizzle share
  pace        0.10  level time within the persona's comfortable range
"""
import argparse
import concurrent.futures as cf
import glob
import json
import math
import os
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
GODOT = os.environ.get("GODOT", os.path.expanduser("~/Desktop/Godot_v4.7.2.app/Contents/MacOS/Godot"))
OUT = os.path.join(ROOT, "montecarlo")
PERSONAS = ["noob", "average", "speedrunner"]
LEVELS = 3

QUIT_BASE = {"noob": 0.22, "average": 0.12, "speedrunner": 0.06}
BOREDOM_QUIT = {"noob": 0.0, "average": 0.02, "speedrunner": 0.05}
PAR = [55.0, 52.0, 52.0]
DEATHS_PER_MIN_SWEET = {"noob": 0.8, "average": 0.6, "speedrunner": 0.35}
PACE_RANGE = {"noob": (60, 240), "average": (45, 180), "speedrunner": (25, 90)}


def run_one(persona, seed):
    cmd = [GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, "-s", "tests/playthrough.gd", "--", persona, str(seed)]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=900).stdout
    for line in out.splitlines():
        if line.startswith("RESULT "):
            data = json.loads(line[7:])
            with open(os.path.join(OUT, "runs", "%s_%d.json" % (persona, seed)), "w") as f:
                json.dump(data, f)
            return data
    return None


def level_fun(persona, lv):
    minutes = max(lv["seconds"] / 60.0, 0.05)
    dpm = lv["deaths"] / minutes
    sweet = DEATHS_PER_MIN_SWEET[persona]
    challenge = math.exp(-((dpm - sweet) / max(sweet, 0.1)) ** 2 / 2.0)
    frustration = 1.0 - min(lv["game_overs"], 4) / 4.0
    judged = lv["perfect"] + lv["good"] + lv["miss"]
    rhythm = (lv["perfect"] + lv["good"]) / judged if judged else 0.0
    attempts = lv["casts"] + lv["fizzles"]
    skills = min(lv["casts"] / minutes / 2.0, 1.0) * (1.0 - (lv["fizzles"] / attempts if attempts else 0.0))
    lo, hi = PACE_RANGE[persona]
    pace = 1.0 if lo <= lv["seconds"] <= hi else math.exp(-((lv["seconds"] - (lo if lv["seconds"] < lo else hi)) / hi) ** 2 * 4)
    parts = {"challenge": challenge, "frustration": frustration, "rhythm": rhythm, "skills": skills, "pace": pace}
    score = 100 * (0.35 * challenge + 0.25 * frustration + 0.20 * rhythm + 0.10 * skills + 0.10 * pace)
    return score, parts


def drop_profile(persona, run):
    """Probability that this player is still playing at the start of each level, and drops per level."""
    alive = 1.0
    starts, drops = [0.0] * LEVELS, [0.0] * LEVELS
    for lv in run["levels"]:
        i = lv["level"] - 1
        starts[i] += alive
        stay = 1.0
        for k in range(1, lv["game_overs"] + 1):
            q = min(QUIT_BASE[persona] * (1 + 0.5 * (k - 1)), 0.9)
            stay *= 1 - q
        if not lv["cleared"]:
            stay = 0.0   # bot hit its retry limit
        elif lv["deaths"] == 0 and lv["seconds"] < 0.4 * PAR[i]:
            stay *= 1 - BOREDOM_QUIT[persona]
        drops[i] += alive * (1 - stay)
        alive *= stay
    return starts, drops, alive if run["finished"] else 0.0


def analyze():
    runs = {p: [] for p in PERSONAS}
    for f in glob.glob(os.path.join(OUT, "runs", "*.json")):
        r = json.load(open(f))
        runs[r["persona"]].append(r)
    lines = ["# Smittens Monte Carlo report", ""]
    for persona in PERSONAS:
        rs = runs[persona]
        if not rs:
            continue
        n = len(rs)
        lines.append("## %s (%d runs)" % (persona, n))
        lines.append("")
        lines.append("| Level | reached | cleared | drop rate | fun | deaths | game overs | minutes | on-beat | fizzles | top killers |")
        lines.append("|---|---|---|---|---|---|---|---|---|---|---|")
        starts_sum, drops_sum, finish_sum = [0.0] * LEVELS, [0.0] * LEVELS, 0.0
        for r in rs:
            s, d, fin = drop_profile(persona, r)
            starts_sum = [a + b for a, b in zip(starts_sum, s)]
            drops_sum = [a + b for a, b in zip(drops_sum, d)]
            finish_sum += fin
        for i in range(LEVELS):
            played = [lv for r in rs for lv in r["levels"] if lv["level"] == i + 1]
            if not played:
                lines.append("| %d | 0%% | - | - | - | - | - | - | - | - | - |" % (i + 1))
                continue
            k = len(played)
            fun = [level_fun(persona, lv)[0] for lv in played]
            killers = {}
            for lv in played:
                for cause, c in lv["causes"].items():
                    killers[cause] = killers.get(cause, 0) + c
            top = ", ".join("%s %.1f" % (c, v / k) for c, v in sorted(killers.items(), key=lambda kv: -kv[1])[:2])
            judged = sum(lv["perfect"] + lv["good"] + lv["miss"] for lv in played)
            onbeat = sum(lv["perfect"] + lv["good"] for lv in played) / judged if judged else 0
            attempts = sum(lv["casts"] + lv["fizzles"] for lv in played)
            fizz = sum(lv["fizzles"] for lv in played) / attempts if attempts else 0
            drop_rate = drops_sum[i] / starts_sum[i] if starts_sum[i] else 0
            lines.append("| %d | %d%% | %d%% | %d%% | %.0f | %.1f | %.1f | %.1f | %d%% | %d%% | %s |" % (
                i + 1, 100 * k / n, 100 * sum(lv["cleared"] for lv in played) / k, 100 * drop_rate,
                sum(fun) / k, sum(lv["deaths"] for lv in played) / k, sum(lv["game_overs"] for lv in played) / k,
                sum(lv["seconds"] for lv in played) / k / 60, 100 * onbeat, 100 * fizz, top))
        lines.append("")
        lines.append("Finished the game (bot, with retries): %d%%. Modelled players still playing at the end: %d%%." % (
            100 * sum(r["finished"] for r in rs) / n, 100 * finish_sum / n))
        lines.append("")
    report = "\n".join(lines)
    with open(os.path.join(OUT, "report.md"), "w") as f:
        f.write(report + "\n")
    print(report)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=30, help="runs per persona")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    ap.add_argument("--analyze-only", action="store_true")
    args = ap.parse_args()
    os.makedirs(os.path.join(OUT, "runs"), exist_ok=True)
    if not args.analyze_only:
        for f in glob.glob(os.path.join(OUT, "runs", "*.json")):
            os.remove(f)
        jobs = [(p, s) for p in PERSONAS for s in range(1, args.runs + 1)]
        done = 0
        with cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            for _ in cf.as_completed([pool.submit(run_one, p, s) for p, s in jobs]):
                done += 1
                if done % 20 == 0 or done == len(jobs):
                    print("  %d/%d runs" % (done, len(jobs)), file=sys.stderr)
    analyze()


if __name__ == "__main__":
    main()
