# Smittens! ✰: progress

Resume a session by reading this file and `docs/PLAN.md` only. The full history is in `docs/AUDIT_LOG.md`.

## Status
| Day | Milestone | State |
|---|---|---|
| 1 | M0 setup + M1 core shooter | ✅ done |
| 2 | M2 rhythm | ✅ done |
| 3 | M3 gestures (playtest check-in after) | ✅ done (playtest still pending) |
| 4 | M4a enemies + levels (+ rhythm revision 1) | ✅ done |
| 5 | M4b bosses + screens | ✅ done |
| 6 | M5 polish (+ beat hints, perf/memory) | ✅ done |
| 7 | Tutorial (your addition) | ✅ done |
| 8 | Persona playthroughs, Monte Carlo, tuning | ✅ done, merged into `main` (2026-11-22) |
| 9 | Playtest 1 + GTM iterations 0-5 | ✅ merged into `main` (2026-11-22) |
| 10 | Playtest 2 (iteration 6) | ✅ on branch `feedback/playtest-2` |
| 11 | Playtest 3 (iteration 7) | ✅ on branch `feedback/playtest-2` |
| 12 | Playtest 4 (iteration 8): story, planets, Sho, modes, companions | ✅ on branch `feedback/playtest-2`, **not merged**: waiting for your playtest |

## How to run
- Godot: `~/Desktop/Godot_v4.7.2.app` (the project needs 4.7.2).
- Play: open the project and press F5 (main scene: `scenes/main.tscn`).
- Tests: `~/Desktop/Godot_v4.7.2.app/Contents/MacOS/Godot --headless --path . -s tests/run_tests.gd`. It prints only failures plus a summary and exits non-zero on failure.
- Regenerate placeholder assets: `python3 tools/gen_art.py`, `python3 tools/gen_audio.py`.

## Where things are
- **`scripts/autoload/game.gd`** (`Game`):
  - run state: score, lives, charges, cheese, gun level, wave;
  - physics layer constants;
  - `SCREEN` rect.
- **`scripts/autoload/sfx.gd`** (`Sfx`): sound effects.
- **`scripts/autoload/conductor.gd`** (`Conductor`): music layers, beat clock, `beat`/`bar` signals, `judge()`, offset, muffle.
- **`scenes/ui/beat_bar.gd`:** the rhythm guide in the HUD.
- **`scenes/gestures/`:**
  - `gesture_input.gd`: right-click drawing, slow motion, casting;
  - `gesture_recognizer.gd`: $1 for circle/triangle, straightness for lines, a structural check for zigzags;
  - `skills/`: shockwave, laser_beam, chain_lightning, shield.
- **`scenes/player/`:**
  - `shmitten.gd/.tscn`: the cat; movement is unchanged from the prototype;
  - `gun.gd`: aims at the mouse; click or hold to fire; streams = gun level;
  - `player_shot.gd`.
- **`scenes/enemies/`:**
  - `enemy_base.gd`: health, flash, drops, score;
  - `grunt.gd/.tscn`;
  - `enemy_shot.gd`.
- **`scenes/pickups/pickup.gd`:** cheese, battery and yarn.
- **`scenes/levels/`:**
  - `levels.gd`: all level/wave data and formations;
  - `level_runner.gd`: intro → waves on bars → clear → next level;
  - `starfield.gd`.
- **Bosses:** `scenes/enemies/bosses/` (base + tank, mothership, rat_king) and `enemy_beam.gd`.
- **Effects:** `scenes/levels/beat_fx.gd` (beat sparkles and edge glow); screen shake via `Game.shake()`, applied in `main.gd`.
- **Simulation:** `tests/persona_bot.gd`, `tests/playthrough.gd`, `tools/montecarlo.py`.
- **Tutorial:** `scenes/tutorial.gd` (runs in `main` when `Game.tutorial_mode`).
- **Screens:** `scenes/ui/title`, `pause_menu.gd`, `ending`; `scenes/levels/queen_cage.gd`.
- **Enemies:** `grunt`, `gunner`, `dasher`, `shield_mouse` (all extend `enemy_base.gd`; behaviour in `on_beat(n)` / `_behave(delta)`).
- **Design rules:** see "Revision 1" in `docs/PLAN.md`. Drops and enemy attacks are deterministic and rhythm-driven.
- **`scenes/ui/`:**
  - `hud.gd`: built in code;
  - `crosshair.gd`: the sprite cursor, confined to the window.

## Current state
- **`main`:** includes the tooling and the 10 tuning commits, merged from `tuning/personas` (see `docs/KPI.md` and the audit log). Revert any single decision with `git revert <commit>`.
- **Branch `feedback/playtest-1`:** playtest fixes, music bosses, and the GTM-readiness iterations (panel: `python3 tools/panel.py`, about 100 s). All panel KPIs are met on two independent panels (`docs/GTM_READINESS.md`). The Steam uniqueness check is done (`docs/DIFFERENTIATION.md`). **Waiting for your review / merge of `feedback/playtest-1` into `main`.**
- **KPIs:** `python3 tools/montecarlo.py --runs 40` (about 1.5 min); the report is in `montecarlo/report.md`.
- **Open issues:** the beginner at the final boss (L3: 55% clear); the speedrunner L2 fun dip.

## How to check performance
`~/Desktop/Godot_v4.7.2.app/Contents/MacOS/Godot --path . -s tests/perf_benchmark.gd` (needs a window). Last result: 8.3 ms average, 9.7 ms worst frame, 42 MB, no leftover nodes.

## Known issues / notes
- **Playtest pending:** gesture recognition with real mouse strokes, slow-motion feel, rhythm windows and latency, skill balance.
- Placeholder art and sounds are generated. Replace any PNG/WAV under `Art/Generated/` or `Audio/` freely.
- The cat sheet's rows 1–4 are unused (waiting for you to say what those poses are for).
- The stale `movie_writer` path to an old "Game Prototypes" folder was dropped from `project.godot`.
- The test runner loads game classes at runtime on purpose (see the comment in `tests/run_tests.gd`).
