# Smittens! ✰: progress

Resume a session by reading this file and `docs/PLAN.md` only. The full history is in `docs/AUDIT_LOG.md`.

## Status
| Day | Milestone | State |
|---|---|---|
| 1 | M0 setup + M1 core shooter | ✅ done |
| 2 | M2 rhythm | ✅ done |
| 3 | M3 gestures (playtest check-in after) | ⏭ next |
| 4 | M4a enemies + levels | — |
| 5 | M4b bosses + screens | — |
| 6 | M5 polish | — |

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
  - `wave_director.gd`: endless growing grunt formations, a placeholder until Day 4;
  - `starfield.gd`.
- **`scenes/ui/`:**
  - `hud.gd`: built in code;
  - `crosshair.gd`: the sprite cursor, confined to the window.

## Next session (Day 3: gestures)
1. `scenes/gestures/gesture_input.gd`:
   - while the `draw` action (right mouse) is held: `Engine.time_scale = 0.3` (at most 2 real seconds), `Conductor.set_muffled(true)`, a glowing `Line2D` trail, and gun shooting disabled;
   - on release: recognise the shape, spend 1 charge, cast. Empowered if `Conductor.judge()` isn't MISS.
2. `gesture_recognizer.gd`: the $1 Unistroke method with circle, triangle and zigzag templates (both directions), plus a separate straightness check for lines that keeps the direction. Unrecognised shapes fizzle at no cost.
3. Skills in `scenes/gestures/skills/`:
   - shockwave (an expanding ring that damages once per enemy);
   - laser (a piercing beam in the drawn direction);
   - chain lightning (nearest to the cursor, then 4 jumps);
   - shield (absorbs hits for 4 s).
   
   Empowered = +50% size, damage and duration.
4. HUD: show the recognised skill name (or "fizzle") at the cat.
5. Tests: synthetic strokes for each shape at several sizes and directions with noise; scribbles are rejected; charges are spent or not; each skill hits the right targets; the shield blocks; slow motion is capped at 2 s; empowered values apply.
6. Then **stop for your playtest** (the planned check-in).

## Known issues / notes
- Placeholder art and sounds are generated. Replace any PNG/WAV under `Art/Generated/` or `Audio/` freely.
- The cat sheet's rows 1–4 are unused (waiting for you to say what those poses are for).
- The stale `movie_writer` path to an old "Game Prototypes" folder was dropped from `project.godot`.
- The test runner loads game classes at runtime on purpose (see the comment in `tests/run_tests.gd`).
