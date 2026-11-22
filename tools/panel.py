#!/usr/bin/env python3
"""Hypothetical panel of 100 first-time testers + three evaluator views (player, critic, business).

Usage (from the project root):  python3 tools/panel.py [--testers 100] [--analyze-only]
Output: montecarlo/panel_report.md (also printed). Raw runs: montecarlo/panel_runs/ (git-ignored).

IMPORTANT: these are MODELS, not predictions. Play data is simulated (tests/persona_bot.gd driving
the real game); judgements are explicit heuristics below. Use them to compare versions.

Panel: each tester i has (seeded)
  skill      ~ Beta(2, 2.5)        - how well they play (0 = beginner, 1 = speedrunner)
  patience   ~ U(0.25, 1)          - tolerance for failure
  rhythm     ~ U(0, 1)             - how much they enjoy rhythm mechanics
  challenge  ~ clamp(N(skill, .2)) - preferred difficulty
  aesthetic  ~ U(0, 1)             - how much art/audio quality matters to them
  relaxed    - picks RELAXED at the first-start prompt: 70% of testers with challenge < 0.3 (assumption)
Each tester plays one full sped-up run (bot persona "skill:<skill>").

Targets (benchmark-adjusted, see docs/KPI.md):
  player: fun rate >= 80%, drop rate <= 20% per level, completion >= 60%
  critic: endorsement >= 80%     business: purchase intent >= 25%, GTM success >= 24% (3x 8% base)
"""
import argparse
import concurrent.futures as cf
import glob
import json
import math
import os
import random
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
GODOT = os.environ.get("GODOT", os.path.expanduser("~/Desktop/Godot_v4.7.2.app/Contents/MacOS/Godot"))
OUT = os.path.join(ROOT, "montecarlo")
RUNS = os.path.join(OUT, "panel_runs")
LEVELS = 3
PAR = [55.0, 48.0, 50.0]

# Presentation quality of the current assets (0-1). Fixed judgement, NOT computable from code:
# generated placeholder pixel art (the cat is hand-made) and generated chiptune loops/sfx.
# Raise these only when real art / music replace the placeholders.
# Playtest 2: one cohesive cute (chibi) style for every enemy, boss, pickup and shot, replacing
# mismatched robot sprites -> 0.55. Still generated placeholders; real art is the big lever.
ART_QUALITY = 0.55
AUDIO_QUALITY = 0.5
ORIGINALITY = 0.85   # rhythm + drawn-gesture skills + shmup is an unusual combination

# Feature checklist: (name, weight, check(root) -> 0..1). Evidence comes from the project files.
def _exists(*parts):
    return os.path.exists(os.path.join(ROOT, *parts))

def _grep(path, needle):
    p = os.path.join(ROOT, path)
    return os.path.exists(p) and needle in open(p, encoding="utf-8").read()

CHECKLIST = [
    ("tutorial / onboarding", 1.0, lambda: 1.0 if _exists("scenes", "tutorial.gd") else 0.0),
    ("pause menu", 0.5, lambda: 1.0 if _exists("scenes", "ui", "pause_menu.gd") else 0.0),
    ("settings: volume + fullscreen", 1.0, lambda: 1.0 if _exists("scenes", "ui", "settings_menu.gd") else 0.0),
    ("save progress / continue / level select", 1.0, lambda: 1.0 if _grep("scripts/autoload/game.gd", "unlocked_level") else 0.0),
    ("accessibility: reduce shake/flash, relaxed mode", 1.0, lambda: (0.5 if _grep("scripts/autoload/game.gd", "reduce_effects") else 0.0) + (0.5 if _grep("scripts/autoload/game.gd", "relaxed_mode") else 0.0)),
    ("game feel: shake, particles, beat fx", 1.0, lambda: 1.0 if _exists("scenes", "levels", "beat_fx.gd") else 0.0),
    ("mastery: ranks / FEVER", 0.5, lambda: 1.0 if _grep("scripts/autoload/game.gd", "FEVER_EVERY") else 0.0),
    ("replay mode after the story", 1.0, lambda: 1.0 if _exists("scenes", "levels", "endless.gd") else 0.0),
    ("high scores saved", 0.5, lambda: 1.0 if _grep("scripts/autoload/game.gd", "best_scores") else 0.0),
    # playtest 2
    ("weapon variety + switching", 1.0, lambda: 1.0 if _grep("scripts/autoload/game.gd", "WEAPON_NAMES") else 0.0),
    ("boss design: readable patterns + beat-armour phase", 1.0, lambda: 1.0 if _grep("scenes/enemies/bosses/boss.gd", "ARMOR_PIPS") else 0.0),
    ("story cards between levels", 0.5, lambda: 1.0 if _exists("scenes", "ui", "transition_card.gd") else 0.0),
    ("spell-shape guides", 0.5, lambda: 1.0 if _exists("scenes", "gestures", "gesture_guide.gd") else 0.0),
    ("no dead time between waves (dance breaks)", 0.5, lambda: 1.0 if _grep("scenes/levels/level_runner.gd", "set_dancing") else 0.0),
]


def checklist():
    items = [(name, w, check()) for name, w, check in CHECKLIST]
    score = sum(w * v for _, w, v in items) / sum(w for _, w, _ in items)
    return score, items


def make_panel(n, seed=2026):
    rng = random.Random(seed)
    panel = []
    for i in range(n):
        skill = rng.betavariate(2, 2.5)
        panel.append({
            "id": i + 1, "skill": skill, "patience": rng.uniform(0.25, 1.0), "rhythm": rng.random(),
            "challenge": min(max(rng.gauss(skill, 0.2), 0.0), 1.0), "aesthetic": rng.random(),
        })
        panel[-1]["relaxed"] = panel[-1]["challenge"] < 0.3 and rng.random() < 0.7
    return panel


def run_tester(t):
    cmd = [GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, "-s", "tests/playthrough.gd", "--",
           "skill:%.3f" % t["skill"], str(t["id"]), "relaxed" if t["relaxed"] else "normal"]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=900).stdout
    for line in out.splitlines():
        if line.startswith("RESULT "):
            data = json.loads(line[7:])
            with open(os.path.join(RUNS, "%d.json" % t["id"]), "w") as f:
                json.dump(data, f)
            return data
    return None


def sigmoid(x):
    return 1.0 / (1.0 + math.exp(-x))


def tester_experience(t, run, polish):
    """Per-level fun (0-100) and quitting for one tester, from their run and tastes."""
    levels, alive, quit_at = [], True, None
    total_minutes = 0.0
    for lv in run["levels"]:
        i = lv["level"] - 1
        minutes = max(lv["seconds"] / 60.0, 0.05)
        total_minutes += minutes
        dpm = lv["deaths"] / minutes
        sweet = 0.2 + 0.9 * t["challenge"]                     # preferred deaths per minute
        challenge = math.exp(-((dpm - sweet) / max(sweet, 0.2)) ** 2 / 2)
        frustration = 1 - min(lv["game_overs"], 4) / 4 * (1.2 - t["patience"])
        judged = lv["perfect"] + lv["good"] + lv["miss"]
        onbeat = (lv["perfect"] + lv["good"]) / judged if judged else 0
        rhythm = 0.5 + (onbeat - 0.5) * (0.5 + t["rhythm"])     # rhythm fans feel success/failure more
        attempts = lv["casts"] + lv["fizzles"]
        skills = min(lv["casts"] / minutes / 2.0, 1) * (1 - (lv["fizzles"] / attempts if attempts else 0))
        fun = 100 * (0.33 * challenge + 0.22 * max(frustration, 0) + 0.18 * min(max(rhythm, 0), 1)
                     + 0.12 * skills + 0.15 * (0.6 + 0.4 * polish))
        # quitting: per game over (impatient testers quit sooner); boredom if far too easy for them
        stay = 1.0
        for k in range(1, lv["game_overs"] + 1):
            stay *= 1 - min((1.05 - t["patience"]) * 0.30 * (1 + 0.4 * (k - 1)), 0.9)
        if not lv["cleared"]:
            stay = 0.0
        elif lv["deaths"] == 0 and lv["seconds"] < 0.5 * PAR[i] and t["challenge"] > 0.7:
            stay *= 0.9
        levels.append({"level": i + 1, "fun": fun, "stay": stay})
    return levels, total_minutes


def analyze(panel):
    polish, items = checklist()
    runs = {}
    for f in glob.glob(os.path.join(RUNS, "*.json")):
        r = json.load(open(f))
        runs[r["seed"]] = r
    starts, drops = [0.0] * LEVELS, [0.0] * LEVELS
    had_fun, finished_w, buy, minutes_all, positive = [], 0.0, [], [], []
    for t in panel:
        run = runs.get(t["id"])
        if not run:
            continue
        levels, minutes = tester_experience(t, run, polish)
        alive = 1.0
        fun_weighted, weight = 0.0, 0.0
        for lv in levels:
            i = lv["level"] - 1
            starts[i] += alive
            drops[i] += alive * (1 - lv["stay"])
            fun_weighted += alive * lv["fun"]
            weight += alive
            alive *= lv["stay"]
        finished_w += alive if run["finished"] else 0.0
        session_fun = fun_weighted / max(weight, 1e-6)
        presentation = (ART_QUALITY + AUDIO_QUALITY) / 2
        perceived = session_fun / 100 * (1 - 0.35 * t["aesthetic"] * (1 - presentation))
        had_fun.append(1.0 if perceived >= 0.55 else 0.0)
        positive.append(perceived)
        minutes_all.append(minutes)
        # purchase intent at a typical indie price: needs fun, enough content, presentation
        content = min(minutes / 25.0, 1.0) * 0.6 + 0.4 * polish
        buy.append(sigmoid((perceived - 0.62) * 9 + (content - 0.6) * 3))
    n = len(had_fun)
    fun_rate = 100 * sum(had_fun) / n
    drop_rates = [100 * drops[i] / starts[i] if starts[i] else 0 for i in range(LEVELS)]
    completion = 100 * finished_w / n
    # critic rubric
    feel = sum(positive) / n
    avg_minutes = sum(minutes_all) / n
    content_score = min(avg_minutes / 25.0, 1.0) * 0.7 + 0.3 * (1.0 if _exists("scenes", "levels", "endless.gd") else 0.0)
    onboarding = (1.0 if _exists("scenes", "tutorial.gd") else 0.0) * (1 - drop_rates[0] / 100)
    critic_score = (0.20 * ORIGINALITY + 0.25 * feel + 0.15 * polish + 0.15 * (ART_QUALITY + AUDIO_QUALITY) / 2
                    + 0.15 * content_score + 0.10 * onboarding)
    endorse = 100 * sigmoid((critic_score - 0.62) / 0.06)
    intent = 100 * sum(buy) / n
    # GTM: base rate 8% (Steam games grossing > $100k), scaled by intent vs the 19% median and endorsement
    gtm = min(8.0 * (intent / 19.0) ** 1.5 * (endorse / 70.0) ** 1.0, 60.0)
    kpis = {"fun_rate": fun_rate, "drop_rates": drop_rates, "completion": completion, "endorse": endorse,
            "intent": intent, "gtm": gtm, "avg_minutes": avg_minutes, "polish": polish, "critic_score": critic_score}
    return kpis, items


def report(kpis, items, n):
    ok = lambda b: "✅" if b else "❌"
    k = kpis
    lines = ["# Panel report (%d simulated first-time testers)" % n, "",
             "| View | KPI | Value | Target | |", "|---|---|---|---|---|",
             "| Player | had fun | %.0f%% | ≥ 80%% | %s |" % (k["fun_rate"], ok(k["fun_rate"] >= 80))]
    for i, d in enumerate(k["drop_rates"]):
        lines.append("| Player | drop rate level %d | %.0f%% | ≤ 20%% | %s |" % (i + 1, d, ok(d <= 20)))
    lines += [
        "| Player | completion (finish the story) | %.0f%% | ≥ 60%% | %s |" % (k["completion"], ok(k["completion"] >= 60)),
        "| Critic | likely to endorse | %.0f%% | ≥ 80%% | %s |" % (k["endorse"], ok(k["endorse"] >= 80)),
        "| Business | purchase intent (monetization) | %.0f%% | ≥ 25%% | %s |" % (k["intent"], ok(k["intent"] >= 25)),
        "| Business | GTM success (P > $100k gross) | %.0f%% | ≥ 24%% | %s |" % (k["gtm"], ok(k["gtm"] >= 24)),
        "", "Average session: %.1f min. Critic rubric score: %.2f. Feature checklist: %.0f%%." % (k["avg_minutes"], k["critic_score"], 100 * k["polish"]),
        "", "| Feature checklist | weight | done |", "|---|---|---|"]
    lines += ["| %s | %.1f | %.0f%% |" % (name, w, 100 * v) for name, w, v in items]
    text = "\n".join(lines)
    with open(os.path.join(OUT, "panel_report.md"), "w") as f:
        f.write(text + "\n")
    print(text)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--testers", type=int, default=100)
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    ap.add_argument("--analyze-only", action="store_true")
    ap.add_argument("--seed", type=int, default=2026, help="panel seed (different seed = different 100 testers)")
    args = ap.parse_args()
    os.makedirs(RUNS, exist_ok=True)
    panel = make_panel(args.testers, args.seed)
    if not args.analyze_only:
        for f in glob.glob(os.path.join(RUNS, "*.json")):
            os.remove(f)
        with cf.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            list(pool.map(run_tester, panel))
    kpis, items = analyze(panel)
    report(kpis, items, args.testers)


if __name__ == "__main__":
    main()
