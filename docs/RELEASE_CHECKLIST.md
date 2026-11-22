# Release checklist (Steam demo / Early Access)
✅ done · ⬜ to do · 👤 owner (needs the Steam account or real people)

## Build and tech
- ✅ One-command release: `tools/release.sh X.Y.Z "notes"` (tests → Web, Windows, macOS exports → tag → GitHub Pages → GitHub Release)
- ✅ CI runs the 341-check headless test suite on every push (`.github/workflows/tests.yml`)
- ✅ The tests never touch the player's save (snapshot and byte-for-byte restore)
- ✅ Demo build flag (`demo` export feature): the story stops after world 1, then a wishlist and feedback screen
- ✅ **Performance** (`tests/perf_test.gd`, debug build, M1):
  - a real BULLET HELL fight against Sho MAXIMUM FLEX peaks at **53 bullets**, at **4.3 ms average** (12.8 ms p95) of game processing per frame;
  - the synthetic worst case of 600 bullets is 22 ms (over budget). That's about 10× more than any pattern spawns.
  - If denser modes are ever added, move enemy bullets to a pooled MultiMesh manager.
- ✅ Platform layer (`scripts/platform.gd`): achievements and stats forward to Steam when the GodotSteam extension is present; otherwise a no-op
- ⬜ macOS notarization and a Windows code-signing certificate, to avoid "unidentified developer" warnings (needs Apple and Microsoft developer accounts)
- ⬜ Web build: check rhythm feel in Chrome, Firefox and Safari on a 2020-class laptop
- 👤 Steamworks: app ID, achievements uploaded (ids in `scripts/progression.gd`), cloud saves (`user://settings.cfg`), depots

## Content (v0.12, branch `iterate/designer-7`)
- ✅ 2 worlds, 8 planets, 10 waves each, 7 mid-bosses, 8 bosses, **30 spell cards**, 8 enemy types
- ✅ 16 arranged 32-bar tracks (8 planets + 8 bosses), each planet with its own motif
- ✅ Tutorial (including a spell-card practice boss), 4 difficulties, Endless, card album, 16 achievements, 6 hats

## Accessibility and settings
- ✅ Relaxed mode, assists, high-contrast bullets, reduce effects, key rebinding, gamepad support (with on-screen prompts that match), beat offset, volume sliders, a meow toggle
- ⬜ Localisation (ES, PT-BR, DE, FR, JA, ZH): all texts are currently inline. Next step: move them into a CSV and use Godot's `tr()`

## Store and marketing
- ✅ Capsule set and 6 screenshots (`marketing/`), Steam copy, a 45 s trailer script, raw trailer footage, press kit, social kit, devlog #1
- 👤 Pay the Steam Direct fee and set up the "Coming Soon" page; cut the trailer (needs ffmpeg or an editor); a press@ email alias
- 👤 10–20 cold external playtests on the web demo; collect the Feedback-form answers and session stats
