# Smittens! ✰: progress

Resume a session by reading this file and `docs/PLAN.md` only. The full history is in `docs/AUDIT_LOG.md`.

## Status
| Day | Milestone | State |
|---|---|---|
| 1 | M0 setup + M1 core shooter | ✅ done |
| 2 | M2 rhythm | ✅ done |
| 3 | M3 gestures (playtest check-in after) | ✅ done (playtest still pending) |
| 4 | M4a enemies + levels | ⏭ next |
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
  - `wave_director.gd`: endless growing grunt formations, a placeholder until Day 4;
  - `starfield.gd`.
- **`scenes/ui/`:**
  - `hud.gd`: built in code;
  - `crosshair.gd`: the sprite cursor, confined to the window.

## Next session (Day 4: enemies + levels)
1. Enemy types, each extending `enemy_base.gd` and acting on `Conductor.beat`, with art added to `tools/gen_art.py`:
   - **Gunner:** hovers; flashes on the beat before firing an aimed shot every 4 beats.
   - **Dasher:** charges horizontally at the cat's height on the downbeat (bar).
   - **Shield mouse:** a front shield blocks shots coming from the left within ±60°; skills and shots from an angle get through.
2. `LevelData` and `WaveData` resources (`scenes/levels/`):
   - a level holds its track, a list of waves, and a boss (Day 5);
   - a wave holds enemy type, formation (grid/column/V), count, health and timing.
3. Replace the endless `wave_director` with a level runner: waves start on bar boundaries; "LEVEL CLEAR" when all are done.
4. Three levels:
   - level1 (110 BPM): grunts and gunners;
   - level2 (125 BPM): adds dashers;
   - level3 (140 BPM): adds shield mice.
5. Tests: each enemy's beat behaviour, the shield-mouse blocking angles, and level progression (forcing waves to clear).

## Known issues / notes
- **Playtest pending:** gesture recognition with real mouse strokes, slow-motion feel, rhythm windows and latency, skill balance.
- Placeholder art and sounds are generated. Replace any PNG/WAV under `Art/Generated/` or `Audio/` freely.
- The cat sheet's rows 1–4 are unused (waiting for you to say what those poses are for).
- The stale `movie_writer` path to an old "Game Prototypes" folder was dropped from `project.godot`.
- The test runner loads game classes at runtime on purpose (see the comment in `tests/run_tests.gd`).
