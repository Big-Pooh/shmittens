# Smittens! ✰ — plan to build the game

## Context
Smittens is a very early Godot prototype (`~/Desktop/game demos/Smittens! ✰`). The goal is to turn it into a sideways shooter. A superhero cat fights hordes of robot mice across 3 levels to rescue the kidnapped queen. The core verb is shooting. The fun comes from **mouse-drawn gesture skills** and a **beat/rhythm layer**.

**What exists today:**
- `shmitten.gd/.tscn`: the cat. 8-direction WASD movement with acceleration and friction (max 600, accel 2000, friction 2000). It feels good, so I'll keep it.
- `enemy.tscn`: one body with 4 flipped cat sprites as placeholders, and an empty script.
- `main.gd`: empty.
- Art: `Art/Popo-AnimationSheet.png` (cat, 64×48 frames, 22 used in rows of 10/2/3/4/3, facing right) and `SuperKucingFlyingAnimation.gif`.
- Bug: sprites and collision shapes sit at large offsets from their node origins (e.g. sprite at (372, 233)), so hits won't line up with what you see.
- Godot 4.2, "Mobile" renderer, no git repo.

**Decisions so far:**
- Sideways layout: cat on the left, enemies come from the right.
- Mouse aims. Left-click shoots toward the cursor. Hold right-click to draw a gesture.
- Desktop only.
- 3 levels, each ending in a boss. Story screens between levels.
- 4 skills: circle → shockwave, line → laser beam, zigzag → chain lightning, triangle → shield.
- Skill ammo comes from pickups dropped by enemies (Chicken-Invaders-style drops).
- Slow motion while drawing.
- Enemies are robot mice. I'll draw placeholder pixel art.
- Rhythm, all four parts: on-beat shots hit harder (with combos), on-beat gestures are stronger, enemies act on the beat, and the music intensifies. I'll generate placeholder music loops.

## Game design (what you'd be approving)

**Controls**
- WASD moves.
- Mouse aims. The cursor is a crosshair that pulses on the beat.
- Left-click shoots toward the cursor. Holding left-click auto-fires weaker shots.
- Hold right-click to draw; release to cast. Shooting is off while drawing.
- Esc pauses.

**Rhythm**
- One music track per level: Level 1 is 110 BPM, Level 2 is 125, Level 3 is 140, and each boss track is +10 BPM.
- A beat bar at the bottom of the screen shows beats coming in. The crosshair also pulses on each beat.
- Each click is judged on timing:
  - **Perfect**: within ±50 ms of a beat. Bigger shot, double damage.
  - **Good**: within ±100 ms. 1.5× damage.
  - **Off-beat**: a normal shot, and the combo resets.
- Auto-fire shots are never judged.
- Each on-beat click adds to the combo. Combo tiers ×1 → ×2 → ×3 → ×4 multiply score.
- Each combo tier unlocks another music layer (drums → bass → arpeggio → lead), so the music intensifies as you play well.
- Releasing a gesture on the beat makes the skill **empowered** (+50% size, damage and duration).
- Robot mice act on beats:
  - formations step on every beat, like the classic invader march;
  - gunners flash on the beat before they fire;
  - dashers charge on the downbeat.
  
  This makes attacks readable to the rhythm.
- The music keeps real time during slow motion. A muffling filter is applied to it as feedback that you're drawing.
- The pause menu has a **beat offset** setting (±ms) to make up for headphone or speaker delay.

**Gestures**
- Holding right-click starts slow motion (game at 30% speed, for at most 2 real seconds) and shows a glowing trail.
- On release, the shape is recognised:
  - **Circle → Shockwave:** a ring expands from the cat and damages everything it passes.
  - **Line → Laser:** a piercing beam from the cat in the direction you drew.
  - **Zigzag → Chain lightning:** hits the enemy nearest the cursor, then jumps to 4 more.
  - **Triangle → Shield:** a bubble that absorbs all hits for 4 seconds.
- Each skill costs 1 charge. An unrecognised shape fizzles and costs nothing.
- How recognition works: the "$1 Unistroke" method, a simple, well-known way to compare a drawing against stored example shapes, which works whatever size you draw at. Circles and triangles are recognised whichever way you draw them. Lines are detected separately by how straight the stroke is, and the direction you drew is kept for the laser.

**Pickups (enemy drops)**
- **Cheese bits** (common): every 10 gives 1 skill charge. You can hold at most 3 charges.
- **Battery** (rare): +1 charge straight away.
- **Yarn gift** (rare): gun level +1, up to 5, which adds more and wider shot streams. You lose a level when you die.
- Pickups drift left and are pulled towards the cat when it's close.

**Player**
- 3 lives. One hit costs a life. The hitbox is a small core, not the whole sprite, which is normal for this kind of shooter. You're invulnerable for 2 seconds after respawning.
- Game over offers a retry from the start of the current level.

**Enemies (robot mice, placeholder pixel art in the cat's style, facing left)**
- **Grunt:** marches in formation on the beat and sometimes fires.
- **Gunner:** fires an aimed shot every 4 beats, with a warning flash first.
- **Dasher:** on the downbeat, charges across at the cat's height.
- **Shield mouse** (Level 3 only): blocks shots from the front. Shockwave, lightning, or shots from an angle get past it.
- **Bosses:**
  - Level 1, **Mecha-Mouse Tank**: bullet patterns on the beat.
  - Level 2, **Mouse Mothership**: launches grunts and fires a laser on the downbeat.
  - Level 3, **Rat King**: two phases. The queen's cage hangs nearby, and defeating him leads to the rescue ending.

**Levels:** 4–5 waves and then a boss each:
- Level 1 Mouse Factory: grunts and gunners.
- Level 2 Sewer Fleet: adds dashers.
- Level 3 Rat King's Castle: everything, plus shield mice.

**Screens:** title, intro story (the Rat King kidnaps the queen), a story card between levels, pause (resume / beat offset / quit), game over (retry level / quit), and a victory/rescue ending.

**HUD:**
- top: lives, score, combo multiplier, boss health bar during boss fights;
- bottom: skill charges with the cheese meter, gun level, and the beat bar.

## Technical approach

**Setup**
- `git init`, with the prototype committed first as-is.
- Upgrade to **Godot 4.7.2**, which is already installed from the Space Invaders work. It's needed for `AudioStreamSynchronized`, which plays the music layers in perfect sync. After this the project needs 4.7.2 to open.
- 1280×720 window with scaling, and pixel-perfect texture filtering.
- Fix the cat's sprite and collision offsets, and animate the flying cycle from sheet row 0.

**Autoloads (always-loaded global scripts)**
- **`Conductor`:** plays the level's music layers and gets the song position from the audio playback position, corrected for output delay. Emits `beat(n)` and `bar(n)` signals. `judge(time)` returns PERFECT, GOOD or MISS. It also handles the beat offset setting, turning layers on and off, and the slow-motion filter.
- **`Game`:** lives, score, combo, charges, cheese, gun level, current level, and retry/continue.
- **`Sfx`:** a sound-effect player, the same pattern as Space Invaders `Scenes/sfx.gd`.

**Gameplay code**
- `player/`: `shmitten` (existing movement plus lives, invulnerability, and a small core hitbox) and `gun` (aiming, auto-fire, on-beat judging, spread by gun level).
- `gestures/`:
  - `gesture_input`: captures the stroke, shows the trail, and runs slow motion (`Engine.time_scale`);
  - `gesture_recognizer`: the $1 method plus the line check;
  - `skills/`: shockwave, laser, lightning, shield.
- `enemies/`: an `enemy_base` (health, hit flash, drops, beat hookup) plus one script per type and the 3 bosses.
- `pickups/`: a single `pickup` scene configured by type.
- `levels/`:
  - `LevelData` and `WaveData` resources hold BPM, music, waves and boss;
  - a `wave_director` spawns waves on bar boundaries;
  - `level_1..3.tres`.
- `ui/`: HUD, beat bar, title, story, pause, game over, victory.
- `tools/gen_art.py` and `tools/gen_audio.py`: Python scripts in the repo that generate the placeholder pixel art, sound effects and music layers (8-bar loops per level and boss), so they can be regenerated or replaced.

## Milestones
Each milestone ends playable, tested, and committed.

1. **M0 Setup:** git, the 4.7.2 upgrade, project settings, the cat scene fix and animation.
2. **M1 Core shooter:** aim and shoot, grunt waves, damage, lives, the 3 pickups, HUD.
3. **M2 Rhythm:** the Conductor, generated loops, the beat bar, on-beat shots and combo, grunts marching on the beat.
4. **M3 Gestures:** capture, slow motion, recognition, the 4 skills, charges, empowered skills on the beat.
   - **→ Check-in:** I'll stop here so you can play and judge the feel of rhythm and gestures before I build content.
5. **M4 Content:** the gunner, dasher and shield mice, 3 levels, 3 bosses, music intensity layers, story and menu screens, the ending.
6. **M5 Polish:** screen shake and hit flashes, sound pass, balancing, the beat offset setting, a final full run.

## Delivery schedule (sized for token limits)
One session per day. Each one starts a **new conversation** (long conversations cost more with every message) and ends with a commit and an updated `docs/PROGRESS.md`. Size is relative effort.

| Day | Milestone | Size | You get |
|---|---|---|---|
| 1 | M0 setup + M1 core shooter | M | The cat flies, aims and shoots; grunt waves; pickups; lives; HUD |
| 2 | M2 rhythm | M | Music, the beat bar, on-beat shots and combo, mice marching on the beat |
| 3 | M3 gestures | L | Slow-motion drawing, the 4 skills, charges. **You playtest after this** |
| 4 | M4a enemies + levels | M | Gunner, dasher and shield mice; 3 levels of waves; music layers |
| 5 | M4b bosses + screens | L | 3 bosses, title/story/pause/game-over screens, the rescue ending |
| 6 | M5 polish | S | Effects, sound pass, balancing from your feedback, final check |

Days 1 and 6 are the easiest to merge with a neighbouring day if you have budget left.

**How each session saves tokens**
- **Handoff file:** on Day 1, I copy this plan into the repo as `docs/PLAN.md`, plus `docs/PROGRESS.md` (what's done, what's next, known issues). Each new session starts by reading those two files instead of the whole project.
- **Screenshots:** images are expensive, so I take one per new screen or major visual change, not per tweak.
- **Tests:** they print one line per check, and failures only, so the output stays small.
- **Generators:** the art and audio scripts are written once and reused, not re-pasted.
- **Audit log:** at the end of every phase, append an entry to `docs/AUDIT_LOG.md`: what changed, why, the decisions made, problems found, and how it was verified. Requested by the user for audit purposes.
- **No sub-agents:** I don't start helper agents, because each one starts from scratch and re-reads everything.
- **To start a day, say:** "Continue Smittens: day N", in a new conversation opened in the Smittens folder.

## Day 1 (current session): M0 setup + M1 core shooter
1. **Git:**
   - `git init`, then commit the prototype as-is, including `demos/DEMO.avi` (10 MB).
   - Add `.DS_Store` to `.gitignore`.
2. **Upgrade:**
   - Open the project once in Godot 4.7.2 headless so it converts, and set features to 4.7.
   - Remove the stale `null` input event in `move_up`.
3. **Project settings:**
   - 1280×720 with `canvas_items` stretch; nearest-pixel textures.
   - Inputs: `shoot` = left mouse, `draw` = right mouse, `pause` = Esc. WASD stays as it is.
   - Named physics layers: player, player_shot, enemy, enemy_shot, pickup.
4. **Folders:**
   - `scenes/{player,enemies,pickups,ui,levels}`, `scripts/autoload`, `tools`, `tests`, `docs`.
   - `shmitten.*` moves to `scenes/player/` with `git mv`, so its history is kept.
   - The placeholder `enemy.*` is replaced and `main.*` is rewritten.
5. **Cat:**
   - Centre the sprite on the origin and play the 10-frame flying loop from row 0.
   - Keep the existing movement code, and keep the cat on screen.
   - Add a small core hitbox (`Area2D`), 3 lives, 2 seconds of blinking invulnerability, and a respawn.
6. **Gun:**
   - Fires toward the cursor; a click shoots straight away.
   - Holding the button auto-fires at about 6 shots a second.
   - Gun levels 1–5 add spread streams.
   - The crosshair replaces the mouse cursor.
7. **Grunt robot mouse:**
   - An `enemy_base` script handles health, a hit flash, drops and score.
   - The grunt enters from the right in formation, bobs, steps left on a timer and sometimes fires.
   - The timer gets swapped for the beat on Day 2.
8. **Wave director (simple):**
   - Endless grunt formations of growing size.
   - Proper levels come on Day 4.
9. **Pickups:**
   - cheese (10 = 1 charge, max 3), battery (+1 charge), yarn (+1 gun level, −1 on death);
   - they drift left and are pulled to the cat when close.
10. **`Game` autoload:** score, lives, charges, cheese, gun level, game over. Game over restarts the run (with a "Retry" prompt).
11. **HUD:** lives, score, charges and the cheese meter, gun level. Plus a scrolling starfield background.
12. **Generators:**
    - `tools/gen_art.py`: mouse, shots, cheese, battery, yarn, crosshair.
    - `tools/gen_audio.py`: shoot, hit, explode, pickup and player-hit sounds.
    - An `Sfx` autoload using the Space Invaders pattern.
13. **Tests:** `tests/run_tests.gd`, run headless, prints only failures plus a one-line summary. It covers:
    - shots kill a grunt;
    - drops turn into charges and gun levels;
    - hits cost lives;
    - invulnerability;
    - game over and restart;
    - the cat stays on screen.
14. **Handoff:** write `docs/PLAN.md` (this plan) and `docs/PROGRESS.md`, then commit.

**Day 1 stops when** the tests pass, one gameplay screenshot looks right, and the work is committed. Not on Day 1: music, beat, gestures, other enemy types, bosses, menus.

## Verification
- **Headless test scripts**, like the Space Invaders playtest:
  - **Recogniser:** synthetic circles, triangles, zigzags and lines (different sizes, directions and noise) are classified correctly, and random scribbles are rejected.
  - **Conductor:** timing judgments with fake song times, including the offset setting.
  - **Combat:** shots kill enemies; pickups turn into charges and gun levels; each skill damages the right targets; the shield blocks hits.
  - **Flow:** forcing waves to clear leads to the boss, then the next level, then victory; game over leads to retry.
- **Screenshots** of each screen and level to check the layout.
- **Your playtest:** I can't judge rhythm timing feel, audio sync or how drawing feels from tests, so the M3 check-in is where you play and give feedback.

## Open points (sensible defaults, change if you like)
- Placeholder enemy, boss and queen art will be simple. Replace it any time without code changes.
- The cat sheet's rows 1–4 (other poses) will stay unused until you say what each is for.
- Balance numbers (damage, drop rates, BPMs) are first guesses, tuned at the M3 check-in.
