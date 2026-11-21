# Smittens! ✰: audit log

One entry per phase: what changed, why, the decisions made, and how it was verified. Newest last.

---

## Phase 0: baseline (2026-11-22)
**What:** `git init`; committed the untouched prototype as `95c7bdc`.

**Why:** gives a fixed, reviewable starting point, so every later change can be diffed against the original.

**Contents at baseline:**
- `shmitten.gd/.tscn`: WASD movement with acceleration and friction;
- `enemy.gd/.tscn`: placeholder;
- `main.gd/.tscn`: empty;
- the cat art, and `demos/DEMO.avi`.

---

## Phase 1: Day 1, M0 setup + M1 core shooter (2026-11-22)

### What changed
**Engine and settings**
- Moved from Godot 4.2 to 4.7.2.
  - *Why:* Day 2 needs `AudioStreamSynchronized` (4.3+) to keep the music layers in sync. 4.7.2 was already installed.
- Window is 1280×720 with `canvas_items` stretch, nearest-pixel filtering and a dark background.
  - *Why:* pixel art stays crisp at any window size.
- Inputs: `shoot` = left mouse, `draw` = right mouse (reserved for Day 3), `pause` = Esc, `restart` = R or Enter.
  - The broken `null` event in `move_up` was removed.
  - *Why:* this is the approved control scheme.
- Named physics layers: player, player_shot, enemy, enemy_shot, pickup.
  - *Why:* each object only checks what it can actually hit.
- Dropped the `movie_writer` path.
  - *Why:* it pointed to a folder that no longer exists ("Game Prototypes").

**Structure**
- Files moved into `scenes/`, `scripts/autoload/`, `tools/`, `tests/` and `docs/`.
  - Moves used `git mv`, so history is kept.
  - The placeholder `enemy.*` was deleted, since a real enemy system replaces it.

**Cat (`scenes/player/shmitten.*`)**
- Movement code kept as you wrote it.
- The sprite and hitboxes are now centred on the node.
  - *Why:* before, the sprite sat at about (372, 233) and the collision at (395, 227) relative to the cat's origin, so hits and the on-screen position didn't match.
- Plays the 10-frame flying loop from sheet row 0.
- Stays clamped to the screen.
- Small core hitbox (radius 9), plus a larger pickup radius.
  - *Why:* standard for this genre; it's fairer when the screen is full of bullets.
- 3 lives; a 1-second respawn delay; 2 seconds of blinking invulnerability.
- Touching an enemy costs a life and destroys that enemy.

**Gun (`gun.gd`, `player_shot.gd`)**
- Fires toward the mouse. A click fires instantly; holding fires about 6 shots a second.
- Gun level 1–5 sets the number of streams, fanned 7° apart.
- Each shot damages only one enemy.
- *Why:* the approved design. The instant click is what Day 2's on-beat judging will build on.

**Enemies (`enemy_base.gd`, `grunt.*`, `enemy_shot.gd`)**
- A shared base handles health, hit flash, score, death animation and drops.
  - Drop chances: yarn 3%, battery 4%, cheese 60%.
- The grunt flies to a formation slot, then marches left in steps, bobbing. Each step has a 4% chance to fire.
  - *Why:* the step timer is deliberately simple; Day 2 swaps it for the music beat.

**Pickups (`pickup.gd`)**
- Cheese: 10 = 1 charge, max 3 charges.
- Battery: +1 charge.
- Yarn: +1 gun level. Dying loses a gun level.
- Pickups drift left and are pulled in within 160 px of the cat.
- *Why:* the approved Chicken-Invaders-style economy.

**Waves (`wave_director.gd`)**
- Endless grunt formations that grow each wave, with health rising every 3 waves.
- *Why:* a placeholder so the game is playable now; Day 4 replaces it with designed levels.

**UI**
- The HUD shows lives (cat icons), score, wave, skill charges, the cheese meter and gun level.
- A crosshair sprite replaces the system cursor, which is confined to the window during play.
- Game over message with R to retry.
- Scrolling 3-layer starfield.
- *Why:* the HUD is built in code to keep scene files small and session cost low. It's straightforward to convert to a `.tscn` later if you want to edit it visually.

**Assets**
- `tools/gen_art.py`: ASCII-drawn pixel sprites (grunt, shots, cheese, battery, yarn, crosshair) in `Art/Generated/`.
- `tools/gen_audio.py`: 7 synthesised sound effects in `Audio/`.
- *Why:* there was no enemy, pickup or audio art. The generators make the placeholders reproducible and easy to replace.

**Tests (`tests/run_tests.gd`)**: 20 checks, covering:
- the cat stays on screen;
- shots kill enemies and score;
- one shot damages one enemy;
- cheese turns into charges; batteries and yarn work; charges are capped;
- the gun fires the right number of streams;
- enemy shots and ramming cost lives;
- dying loses a gun level;
- no double hits; invulnerability starts and ends;
- game over and restart;
- waves spawn.

### Problems found and fixed during the phase
- **The test runner wouldn't compile, then hung.**
  - *Cause:* in Godot's `-s` script mode, the test file is compiled before the `Game`/`Sfx` autoloads exist, and it referred to game classes by name.
  - *Fix:* load game classes at runtime, and add a 60-second watchdog so a broken test can't hang again.
- **Tests ran before the scene was ready.**
  - *Cause:* they waited for physics ticks, but a scene change completes on the next rendered frame.
  - *Fix:* wait for rendered frames.

### Verification
- Headless test run: 20 passed, 0 failed.
- 10-second headless run of the game: no errors.
- One gameplay screenshot checked: cat animation, 3 shot streams at gun level 3, the formation, enemy shots, crosshair and HUD all render correctly.
- **Not verified:** how it feels with a real mouse and keyboard. That waits for your playtest; the planned check-in is after Day 3.
