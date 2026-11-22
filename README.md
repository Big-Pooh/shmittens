# Shmittens! ✰

**Draw spells to the beat.** A cute rhythm shoot-'em-up: Shmitten the superhero cat and her
friends Pip, Nori and Kiwi fly across the galaxy to rescue the Princess of Pisitania from
Sho, the buff demon lord of the mice.

▶ **Play the web demo:** https://big-pooh.github.io/shmittens/
⬇ **Downloads (Windows / macOS):** see [Releases](https://github.com/Big-Pooh/shmittens/releases)

## How to play
| | |
|---|---|
| Move | **W A S D** (hold **Shift** to focus: slower, shows your hitbox) |
| Aim | mouse |
| Shoot | **Space** - tap on the beat for PERFECT shots, hold to fire to the beat |
| Weapons | **1 / 2 / 3**, **Q / E** or mouse wheel - Spread, Laser, Fish |
| Spells | hold **right-click** and draw over the enemies: circle, line, zigzag, triangle |
| Bomb | **X** (one per planet) |
| Overdrive | **F** when ready (50 on-beat hits in a row) |
| Pause | **Esc** |

Features: four planets and a final boss with Touhou-style **spell cards**, bullets that pulse to
the music, companions that join your combo, a rare mech suit, Relaxed / Normal / Hard / Touhou
modes, Endless mode, and a tutorial.

## Development
- Engine: **Godot 4.7.2**. Open `project.godot`.
- Tests: `Godot --headless -s tests/run_tests.gd` (runs in CI on every push).
- Release (tests -> builds -> tag -> web demo -> GitHub Release): `tools/release.sh X.Y.Z "notes"`.
- Placeholder art and audio are generated: `python3 tools/gen_art.py && python3 tools/gen_cute_art.py && python3 tools/gen_audio.py`.
- Design, audit log, KPIs, GTM plan and roadmap: [`docs/`](docs/).

## License
Copyright © 2026 Big-Pooh. All rights reserved. The source is public for transparency and
devlogs; it is not open source. See [LICENSE](LICENSE).
