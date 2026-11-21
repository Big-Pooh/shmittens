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
| 6 | M5 polish | ⏭ next |
| 7 | Tutorial (your addition) | — |

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
- **Screens:** `scenes/ui/title`, `pause_menu.gd`, `ending`; `scenes/levels/queen_cage.gd`.
- **Enemies:** `grunt`, `gunner`, `dasher`, `shield_mouse` (all extend `enemy_base.gd`; behaviour in `on_beat(n)` / `_behave(delta)`).
- **Design rules:** see "Revision 1" in `docs/PLAN.md`. Drops and enemy attacks are deterministic and rhythm-driven.
- **`scenes/ui/`:**
  - `hud.gd`: built in code;
  - `crosshair.gd`: the sprite cursor, confined to the window.

## Next session (Day 6: polish)
1. **Background beat hints (your request):** sparkles and background stars that pulse on every beat, with a bigger burst on the downbeat; a subtle screen-edge glow on the beat. They should help you feel the rhythm without looking at the beat bar.
2. Juice:
   - screen shake on boss hits, player death and skill casts;
   - hit flashes and small explosion particles;
   - a visual for the dash warning.
3. Sound pass:
   - distinct sounds per skill, a boss warning siren, and a combo-milestone jingle;
   - check the music/sfx balance.
4. Balancing, based on your playtest if available: drop amounts, boss health, wave sizes.
5. A final full run through all 3 levels (scripted), plus a screenshot sheet.
6. Then **Day 7, the tutorial** (see "Addition: tutorial" in `docs/PLAN.md`).

## Known issues / notes
- **Playtest pending:** gesture recognition with real mouse strokes, slow-motion feel, rhythm windows and latency, skill balance.
- Placeholder art and sounds are generated. Replace any PNG/WAV under `Art/Generated/` or `Audio/` freely.
- The cat sheet's rows 1–4 are unused (waiting for you to say what those poses are for).
- The stale `movie_writer` path to an old "Game Prototypes" folder was dropped from `project.godot`.
- The test runner loads game classes at runtime on purpose (see the comment in `tests/run_tests.gd`).
