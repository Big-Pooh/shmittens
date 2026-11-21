# Smittens! ✰: progress

Resume a session by reading this file and `docs/PLAN.md` only. The full history is in `docs/AUDIT_LOG.md`.

## Status
| Day | Milestone | State |
|---|---|---|
| 1 | M0 setup + M1 core shooter | ✅ done |
| 2 | M2 rhythm | ⏭ next |
| 3 | M3 gestures (playtest check-in after) | — |
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

## Next session (Day 2: rhythm)
1. Music:
   - `tools/gen_audio.py`: add 4 synced layers (drums, bass, arpeggio, lead), 8-bar loops at 110/125/140 BPM plus boss variants.
2. `Conductor` autoload:
   - plays the layers with `AudioStreamSynchronized`;
   - song position from the playback position, corrected for output latency;
   - `beat`/`bar` signals;
   - `judge()` returns PERFECT (±50 ms), GOOD (±100 ms) or MISS;
   - a beat offset setting.
3. Gun: judge clicks (not auto-fire). Perfect = 2× damage and a bigger shot; Good = 1.5×; Off-beat resets the combo. Add combo tiers ×1–×4 to the score multiplier, and turn music layers on by tier.
4. Grunt: replace `STEP_INTERVAL` with `Conductor.beat`.
5. UI: a beat bar at the bottom centre; the crosshair pulses on the beat; a combo display.
6. Tests: the judging windows and offset with fake times; the combo resets on a miss; grunts step on the beat.

## Known issues / notes
- Placeholder art and sounds are generated. Replace any PNG/WAV under `Art/Generated/` or `Audio/` freely.
- The cat sheet's rows 1–4 are unused (waiting for you to say what those poses are for).
- The stale `movie_writer` path to an old "Game Prototypes" folder was dropped from `project.godot`.
- The test runner loads game classes at runtime on purpose (see the comment in `tests/run_tests.gd`).
