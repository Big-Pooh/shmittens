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
| 12 | Playtest 4 (iteration 8): story, planets, Sho, modes, companions | ✅ on branch `feedback/playtest-2` |
| 13 | Playtest 5 (iteration 9): music-tied patterns, companion roles, bombs, card tutorial, mech, gags | ✅ on branch `feedback/playtest-2` |
| 14 | Playtest 6 (iteration 10): rarer mech, spell break, spread niche | ✅ on branch `feedback/playtest-2` |
| 15 | GTM programme: deploy pipeline (v0.10, v0.11), reviewer agents, mech redesign, meows, spell roles, 8 waves + mid-bosses + 2 enemies, GTM docs and marketing kit | ✅ public repo https://github.com/Big-Pooh/shmittens, dev branch `feedback/playtest-2`; next steps in `docs/ROADMAP_30D.md` |

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

## ACTIVE GOAL (2026-11-22): every senior-designer score ≥ 7, then ship
Branch `iterate/designer-7`. **Do not release or deploy Pages until the designer scores every category ≥ 7.** v0.11.0 stays live. Push commits for backup only.
Designer v0.11 scores: core loop 7, feel 7, onboarding 6, content 4, presentation 5, GTM 4.
**Now (2026-11-22, commit after 4fce754):** core 7, feel 7, onboarding 7 (conditional), content 6, presentation 7, GTM 5. The rest is blocked on the owner (Steam page) and real cold testers; see AUDIT_LOG Phase 16.

**Checklist** (✅ done · ⬜ to build · 👤 needs the owner or real players):
- **Onboarding**
  - ✅ web/first-launch tap calibration (8–16 taps → `offset_ms`)
  - ✅ first-unlock tips: companions (planet 2), mech (planet 3), weakness icon
  - ✅ Ratopolis easing (turret health 6, shield mice −1)
  - ◐ beginner who never picks Relaxed: drop 4 / 22 / 18 / 26% (model floor: 22% quit per game over)
  - 👤 5 cold testers (4/5 finish the tutorial in ≤ 6 min, 4/5 cast every spell)
- **Content**
  - ✅ 3 unique mid-bosses (own sprites, 2 cards each, a new pattern)
  - ✅ 2 new enemy behaviours (splitter, beat-bomber)
  - ✅ planet ranks on the map + 3 challenges per planet (no-hit, all cards captured, all spells used)
  - ✅ average-persona story ≥ 10 min (9.8–10.0 after the refit to human data; 10 waves per planet; rank system)
  - 👤 3 cold testers ≥ 15 min
- **Presentation**
  - ✅ parallax backdrop per planet (2 layers + ambient effect)
  - ✅ a distinct lead melody per planet, with the boss sharing its motif
  - ✅ hit-pause 40–60 ms on phase breaks and Spell Break
  - ✅ animated portraits in speech bubbles
  - ◐ HUD overlap check (wave label fixed, at 720p capture); web performance not measured on a 2020 laptop
- **GTM**
  - ✅ capsule set + 6 screenshots + raw trailer footage (AVI)
  - ✅ in-game feedback link + bug-report path
  - ✅ demo-scope freeze flag
  - ✅ gamepad support (or "mouse required")
  - 👤 Steam page live
  - 👤 10+ cold playtests and survey
  - 👤 devlog + GIFs posted
  - 👤 ≥ 100 wishlists

## ACTIVE: GO-LIVE SPRINTS 1–7 (owner, 2026-11-22: "utmost speed, I only check at the end")
Branch `iterate/designer-7`. Commit and push after each sprint. **No release until the owner checks.**
Core loop is FROZEN: polish and content only.
- [x] **S1 Music:** 32-bar arranged tracks (intro, A, B, bridge, A′), boss tracks build; MusicPatterns follows the arrangement; QOA compression for size.
- [x] **S2 Animation:** 2-frame idle/blink on the beat for every mouse and boss (`*_b.png`), cute defeat poof, boss entrance bounce.
- [x] **S3 UI theme:** pastel rounded theme on the root window, menu hover/press sounds, styled panels.
- [x] **S4 Meta:** cat hats (unlocked by stars and cards) + wardrobe, local achievements with toasts (Steam-ready API), album/stats screen.
- [ ] **S5 Settings:** key rebinding, colour-blind / high-contrast bullet palette.
- [ ] **S6 World 2:** planets 5–8 (Cheddaria, Neon Nibble, Frostwhisker, Mount Flexmore) with 10 waves each, 4 bosses (Big Cheese, DJ Squeak, Captain Frostbite, Sho Maximum Flex), music, themes, story; map per world; the demo stops after world 1.
- [ ] **S7 Tech:** Platform/achievement abstraction (Steamworks-ready), BULLET HELL performance stress test, release checklist doc.
