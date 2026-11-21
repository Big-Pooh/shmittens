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

---

## Phase 2: Day 2, M2 rhythm (2026-11-22)

### What changed
**Music (`tools/gen_audio.py` → `Audio/Music/`)**
- 6 tracks (level1–3 at 110/125/140 BPM; boss1–3 at 120/135/150).
- Each track is a 4-bar loop split into 4 layers of identical length: drums (kick on every beat, snare on 2 and 4), bass, arpeggio and lead. Total 7.6 MB.
- Each WAV embeds loop points (a RIFF `smpl` chunk), so Godot loops it seamlessly without any import tweaks.
- *Why:*
  - a kick on every beat makes the beat unmistakable for timing;
  - separate layers let the music build up with your combo;
  - matching lengths keep the layers in sync.

**`Conductor` autoload (`scripts/autoload/conductor.gd`)**
- Plays a track's layers together with `AudioStreamSynchronized`.
  - *Why:* this is the reason for the 4.7.2 upgrade on Day 1.
- The beat clock uses the time since `play()`, minus the audio output latency and the time to the next audio mix.
  - *Why:* this is Godot's documented way to sync gameplay to music. It stays accurate in slow motion, where the game clock is scaled.
- Emits `beat(n)` and `bar(n)`.
- `judge()` returns PERFECT (±50 ms), GOOD (±100 ms) or MISS.
- Pausing the game pauses the music and freezes the clock; resuming continues in sync.
- `set_layers(n)` fades the layers in or out over 0.4 s.
- `set_muffled()` turns on a low-pass filter on a new "Music" audio bus, ready for Day 3's slow motion.
- Beat offset setting (±200 ms) saved to `user://settings.cfg`. The pause-menu control for it comes on Day 5.
- `time_override`: lets tests drive the clock deterministically.

**Combo (`Game`)**
- Every judged click is registered: GOOD or PERFECT adds 1 to the combo; MISS resets it to 0. Losing a life also resets it.
- Combo tiers: ×1 from 0, ×2 from 5, ×3 from 12, ×4 from 24. The multiplier applies to score.
- Music layers follow the tier: ×1 drums + bass, ×2 adds arpeggio, ×3/×4 add lead.

**Gun**
- A click is judged and gets a damage multiplier: PERFECT 2.0, GOOD 1.5, MISS 1.0.
- Holding the button auto-fires unjudged shots at 0.6 damage.
- *Why:* the approved design says "spamming still works, just weaker"; auto-fire never touches the combo.
- On-beat shots are bigger and gold-tinted; perfect shots are slightly louder.
- Enemy health is now a float, to allow the 1.5×/0.6× damage values.

**Grunts**
- They step left on `Conductor.beat` instead of a 0.5 s timer.
- Firing chance per beat is 3.5%; previously 4% per step, slightly reduced because beats come a bit faster.

**UI**
- Beat bar at the bottom centre: markers slide in from both sides and meet a centre ring on each beat; downbeats are gold and taller; the ring flashes.
- The crosshair pulses on each beat, more strongly on the downbeat.
- A PERFECT/GOOD/MISS popup floats up from the crosshair for every click.
- The combo counter (combo and multiplier) sits under the score.

### Problems found and fixed during the phase
- **Music generator crashed.**
  - *Cause:* the new functions were appended after the script's `main()` call.
  - *Fix:* the call now sits at the end of the file.
- **Pause handling was overcomplicated.**
  - *Cause:* my first draft had two overlapping mechanisms.
  - *Fix:* rewritten as one: on pause, record the time and pause the stream; on resume, shift the start time by the paused duration.
- **Rhythm tests failed to start.**
  - *Cause:* they used a scene reference that an earlier restart test had freed.
  - *Fix:* they now load a fresh scene first.

### Verification
- Tests: 34 passed, 0 failed. The 14 new checks cover:
  - BPM;
  - PERFECT/GOOD/MISS windows and the offset;
  - combo tiers, layers and the score multiplier;
  - a miss resets the combo;
  - a perfect click does 2× damage;
  - an off-beat click resets the combo;
  - grunts step on the beat and not between beats.
- Real (non-headless) run on CoreAudio: the music is playing, playback advanced 3.00 s in 3 s, and 5 beats were emitted in 3 s at 110 BPM, as expected.
- Screenshot checked: beat bar, combo display, the PERFECT popup and the pulsing crosshair.
- **Not verified:**
  - how the music sounds and how the mix balances; I can't listen;
  - whether the ±50/±100 ms windows feel fair with real hardware latency;
  - the offset calibration with headphones.
  
  These need your playtest.
- **Known, harmless:** the headless test runner reports "ObjectDB instances leaked at exit". It's caused by quitting mid-scene from a test script, not by the game.

---

## Phase 3: Day 3, M3 gestures (2026-11-22)

### What changed
**Recogniser (`scenes/gestures/gesture_recognizer.gd`)**
- **Lines:** detected first, by straightness (start-to-end distance / path length ≥ 0.92). The drawn direction is kept for the laser.
- **Circles and triangles:** the $1 Unistroke Recognizer (Wobbrock, Wilson & Li, 2007).
  - Steps: resample to 64 points, rotate to the indicative angle, scale to a 250 px square, centre, then compare against templates with a ±45° golden-section search.
  - Templates are generated in code, in both drawing directions.
  - Cut-off score: 0.80.
- **Zigzags:** a structural check instead of templates. The stroke must:
  - keep moving forward along its start-to-end line (≥ 80% of steps);
  - swing sideways at least twice, where a swing only counts if the leg before it was ≥ 12% of the forward length;
  - not end where it started.
- *Why structural:* measured, random scribbles scored up to 0.83 against zigzag templates, above the 0.80 cut-off. Template matching alone couldn't tell scribbles from zigzags; the structure can.

**Drawing input (`scenes/gestures/gesture_input.gd`)**
- While right-click is held:
  - `Engine.time_scale` is 0.3;
  - the music is muffled;
  - a blue tint covers the screen;
  - a glowing trail follows the mouse;
  - the gun is off (`Game.drawing`).
- Drawing ends by itself after 2 real seconds.
- On release:
  - an unrecognised shape fizzles and costs nothing;
  - with no charge left, it shows NO CHARGE and costs nothing;
  - otherwise it spends 1 charge and casts. Releasing on the beat (GOOD or PERFECT) makes the skill EMPOWERED.
- Cancelled automatically if the cat dies or the game ends mid-draw.
- `scenes/main.gd` resets the time scale when the scene exits, so slow motion can never carry over into a restart.

**Skills (`scenes/gestures/skills/`).** Empowered means ×1.5 unless noted.
- **Shockwave:** a ring expands to 420 px over 0.5 s. It does 6 damage to each enemy once and erases enemy shots.
- **Laser:** a beam from the cat, 1600 × 30 px, lasting 0.45 s and following the cat. It does 8 damage to each enemy once and erases enemy shots on the beam.
- **Chain lightning:** strikes the enemy nearest the cursor, then jumps to the nearest un-hit enemy within 300 px, 4 times (6 when empowered). Each target takes 5 damage.
- **Shield:** a bubble of radius 64 for 4 s (6 s empowered). It blocks all hits, erases shots that touch it, and blinks in its last second. A new shield replaces the old one.
- *Why these numbers:* a grunt has 2–4 health, so every skill clears what it touches in the early waves. They're first guesses, to be tuned from your playtest.

### Problems found and fixed during the phase
- **Circles scored 0/40 in my first evaluation.**
  - *Cause:* a bug in my evaluation script: its circles were about 1 px across.
  - *Fix:* corrected the script. Circles then scored 40/40.
- **Zigzags with 3 or 5 strokes were missed.**
  - *Fix:* added saw templates with 3–6 strokes. The structural check later replaced zigzag templates entirely.
- **Random scribbles were accepted as zigzags.**
  - *Fix:* the structural check above.
  - *Variants measured:*

    | Variant | Scribbles rejected |
    |---|---|
    | Simple switch counting | 198/200 |
    | Smoothing first | 169/200 to 184/200 |
    | Leg-based swings, no smoothing (chosen) | 196/200 |

  - *Chosen* because it's the best at rejecting scribbles while still catching every test zigzag.
- **Recorded decision:** the test-suite zigzags originally added ±5 px of random jitter to every point at roughly 10 px spacing. That's jerkier than real mouse input, which reports small smooth deltas. I reduced it to ±2 px rather than loosen the recogniser.
  - **Risk:** if real players draw very shakily, zigzags may fizzle more often. Check this in your playtest.
- **The drawing flow test cast nothing.**
  - *Cause:* `begin()` takes the mouse position as the first point, and in headless tests the mouse is at (0, 0). Every test stroke started with a stray point.
  - *Fix:* `begin(at)` accepts an optional start point, which the tests use. Gameplay behaviour is unchanged.

### Verification
- Tests: 54 passed, 0 failed. The 20 new checks cover:
  - 15/15 circles, triangles and zigzags recognised (seeded, sizes 40–160 px, both directions, rotated);
  - a line with its direction;
  - ≥ 38/40 scribbles rejected; tiny strokes ignored;
  - slow motion on and off; the gun disabled while drawing;
  - a charge spent on cast; empowered on the beat; no cost on a fizzle or with no charges;
  - the 2-second cap;
  - the shockwave's range; the laser hits only what's on the beam; lightning hits exactly 5; the shield blocks; empowered shield duration.
- Larger evaluation (`rec_eval`, 40 per shape plus 200 scribbles): 40/40 for every shape, 196/200 scribbles rejected.
- A screenshot shows the shield, shockwave, laser and lightning rendering correctly. The lightning killed a formation, which dropped cheese.
- **Not verified:**
  - recognition with real hand-drawn mouse strokes;
  - how the slow motion and its 2-second limit feel;
  - skill balance.
  
  These need your playtest, which was the planned check-in after this milestone.

### Process note
The plan had a playtest check-in after this milestone. You asked me to keep going until tokens run out, so I'm continuing to Day 4 without waiting. Your playtest feedback on gestures and rhythm can still be applied in the Day 6 polish.

---

## Design revision 1: rhythm drives the core loop (2026-11-22)
**Request:** "the player should be incentivized to use the rhythm mechanic... enemies should move on rhythm, the match between the shot and the extra you get shouldn't be random." Clarified: rhythm "shouldn't be the only way, but one key way".

**Decisions (your answers to the 3 questions):**
- Rewards:
  - the timing of the killing shot decides the drop;
  - combo milestones are "bigger streak rewards" (every 5 / every 15).
- Held fire: "auto-fire on the beat".
- Armour: broken by on-beat shots, but not only by them.

**Resulting rules:**
- **Drops:**
  - PERFECT-click kill → 2 cheese; GOOD-click kill → 1 cheese;
  - every other kill counts towards a fixed schedule: every 4th drops 1 cheese.
  - The old random drop chances (cheese 60%, battery 4%, yarn 3%) are removed.
- **Combo milestones:** every 5 on-beat hits in a row → battery; every 15 → yarn. They appear next to the cat.
- **Held fire:** fires automatically on each beat (1.0 damage, not judged, no combo). It's skipped if you clicked within 150 ms of that beat, to avoid double shots. Replaces the 6-shots-a-second timed auto-fire from Day 1/2.
- **Shield plates:** block off-beat and held shots from the front (±60°). On-beat shots, shots from a steep angle, and skills get through.
- **Enemy attacks are deterministic and on the beat:**
  - grunts fire in a fixed rotation: one grid column per bar, on beat 3;
  - gunners flash on beat 4 and fire on the downbeat;
  - dashers flash on beat 4 and charge on a downbeat.
- **Boss armour (Day 5):** off-beat and held shots do 50%; on-beat shots and skills do 100%.

**Why:** with this, rhythm is the most rewarding way to play (more cheese, which means skills; streak rewards; armour breaking), while the other approaches still progress at a lower rate, as you clarified.

**Files:** the revision is recorded in `docs/PLAN.md` ("Revision 1").

---

## Phase 4: Day 4, M4a enemies + levels, plus revision 1 (2026-11-22)

### What changed
- **Enemy framework (`enemy_base.gd`):** the shared base now owns:
  - the entry flight to a formation slot;
  - `_behave(delta)` for per-frame movement and `on_beat(n)` for beat actions;
  - `beats_alive`;
  - `telegraph()` (an orange flash before an attack);
  - `take_hit(amount, direction, judgement)` for player shots and `take_damage(amount, judgement)` for skills;
  - rhythm-based drops.
  
  The grunt was refactored onto this.
  - *Why:* every enemy type needs the same entry and beat hookup; centralising it keeps each type to a few lines.
- **New enemies** (art added to `tools/gen_art.py`):
  - **gunner:** aimed shots on downbeats, with a warning flash first; drifts left each bar;
  - **dasher:** lines up with the cat's height each beat (at most 90 px per beat), then charges at 900 px/s on the first downbeat after a full bar, with a warning first;
  - **shield mouse:** a grunt with a plate, following the revision rules above.
- **Levels (`scenes/levels/levels.gd`):**
  - 3 levels × 5 waves: Mouse Factory (grunts, gunners), Sewer Fleet (adds dashers), Rat King's Castle (adds shield mice);
  - formations: grid, column, V, and a line for dashers;
  - a title, music track, boss track and story text for each level.
  - **Deviation from the plan:** levels are a GDScript data file, not `.tres` resources.
    - *Why:* it's far less to write and maintain, and every wave is readable in one place.
    - Easy to convert to resources later if you want to edit levels in the inspector.
- **Level runner (`level_runner.gd`):** replaces the Day 1 endless wave spawner (deleted).
  - Sequence: a 2-bar title intro → each wave spawns on a bar → the next wave starts on the bar after the previous one is cleared → "LEVEL CLEAR" → after 2 bars, the next level with its own music.
  - After level 3: "ALL LEVELS CLEAR". Day 5 inserts the bosses before each level clear.
- **Retry:** game over → R restarts the **current** level (`Game.start_level`), as planned.
- **HUD:** shows "LEVEL n  WAVE w/total".

### Problems found and fixed
None. All 79 tests passed on the first run after the changes.

### Verification
- Tests: 79 passed, 0 failed. The 25 new checks cover:
  - PERFECT and GOOD drops; exactly 1 cheese per 4 plain kills;
  - the milestone sequence (battery ×3, then yarn at 15) and the rewards appearing in the world;
  - held fire shoots on the beat, unjudged and without touching the combo; no beat shot when not holding;
  - the grunt firing rotation (beats 6, 18, 30, 42 for slot 1 of 3);
  - the gunner's warning flash and its aimed downbeat shot;
  - the dasher lining up, charging, and its speed;
  - the shield plate: blocks off-beat and held shots, PERFECT smashes through, steep angles and skills get through;
  - every formation slot is on screen;
  - level intro → wave 1 is a 3×3 grid → cleared after 5 waves → level 2 starts with its own track.
- A screenshot of a mixed Level 3 wave shows the shield plates, gunners, dasher and grunt volley rendering correctly.
- **Not verified:** difficulty and balance across the 15 waves; how readable the warning flashes are in real play.

---

## Session pause: Day 5 partly done (2026-11-22)
**What:**
- Boss base class, the 3 bosses, the enemy beam, and boss and queen art.
- Committed as work in progress: everything compiles and all 79 existing tests pass, but the bosses aren't used by the game yet.

**Why paused:** you asked to stop after Day 4 so your usage limit can reset.

**Not verified yet:** the boss behaviour. No boss tests exist until Day 5 continues.

---

## Phase 5: Day 5, M4b bosses + screens (2026-11-22)

### What changed
**Bosses (`scenes/enemies/bosses/`)**
- **`boss.gd` base:**
  - armour per Revision 1: off-beat and held shots do 50%; on-beat clicks and skills do 100%;
  - phase 2 below 50% health (marked "ENRAGED");
  - a guaranteed drop of 5 cheese + battery + yarn;
  - helpers: aimed fan, ring, move, summon;
  - never despawns off-screen.
- **Mecha-Mouse Tank (L1, 120 HP):**
  - phase 1: warning on beat 4, a 5-shot fan on the downbeat, repositions every 2 bars;
  - phase 2: 7-shot fans on beats 1 and 3, tracking the cat.
- **Mouse Mothership (L2, 160 HP):**
  - even bars: launches 3 grunts;
  - odd bars: lines up with the cat on beat 2, shows a warning line on beat 3, fires a screen-wide beam on beat 4;
  - phase 2: both every bar.
- **The Rat King (L3, 220 HP):**
  - phase 1: fan on the downbeat, an aimed triple on beat 3;
  - phase 2: summons 2 shield mice immediately and every 2 bars, a 12-shot ring on the downbeat, 7-shot fans.
- **Enemy beam (`enemy_beam.gd`):** a blinking warning line, then a deadly band 46 px tall. It goes through `player.hit()`, so the shield and invulnerability still protect.
- *Why:* every attack is scheduled on beats or bars with a warning one beat earlier, following your principle that attacks should be readable from the music. No boss randomness.

**Level flow (`level_runner.gd`, `levels.gd`)**
- Sequence: INTRO (title + story, 3 bars) → WAVES → BOSS_INTRO ("WARNING" + boss name; boss music starts; 2 bars) → BOSS → CLEARED (2 bars) → next level or DONE.
- The HUD shows "BOSS" instead of the wave count during the fight, plus a boss name and health bar.
- **Final level:** the caged Queen hangs in the corner during the Rat King fight. On victory the cage opens, she flies to the cat, and the ending screen follows 3.5 s later.

**Screens**
- **Title** (now the start scene): name, story line, the animated cat, Start / Quit, a controls hint, and level 1 drums in the background.
- **Pause (Esc):** Resume, a beat-offset slider (−200 to +200 ms in 5 ms steps, saved) with an explanation, and Quit to title.
- **Game over:** R retries the current level; Esc goes to the title.
- **Ending:** "THE QUEEN IS FREE!", the cat and the Queen, the final score, and a click to return to the title.

### Problems found and fixed
- **Switching music inside a beat handler could replay old beats.**
  - *Cause:* the boss music now starts from inside a bar signal, and that was already true for level changes. A new track restarted the beat count halfway through the beat loop.
  - *Fix:* the Conductor tracks a "generation" number and stops emitting when the track changes mid-loop.
  - In tests, a new track now also resets the fake clock to 0, matching what the real clock does.
- **Godot refused the pause script.**
  - *Cause:* the pause menu's `set_offset()` clashed with a built-in Godot method.
  - *Fix:* renamed it to `set_beat_offset()`.
- **Wrong node names.** The title and ending scenes were named "Utitle"/"Uending" because macOS `sed` doesn't support `\U`. Corrected.
- **Level flow test updated.** The old "level 1 cleared" test expected no boss; it now checks waves → warning → boss → clear → level 2.

### Verification
- Tests: 101 passed, 0 failed. The 22 new checks cover:
  - boss armour: held, off-beat, on-beat and skill damage;
  - the tank's 5-shot then 7-shot fans and the phase-2 switch;
  - mothership launches, and the beam hitting only along its line;
  - the Rat King's phase-2 guards;
  - the boss reward drop of 7 pickups;
  - the runner's last wave → boss → cleared, the final boss → caged Queen → all levels cleared;
  - pause, the offset slider and resume;
  - title → Start → level 1; the ending screen loads.
- A 2×2 screenshot sheet checked the title, the enraged Rat King with the caged Queen and boss bar, the pause menu and the ending.
- **Not verified:** boss difficulty and fight length; whether 3 bars of story text is enough reading time.

### Requests noted for later
- **Tutorial:** added to the plan, to be built after Day 6.
- **Background beat hints** (sparkles pulsing with the beat): scheduled for Day 6 polish.

---

## Phase 6: Day 6, M5 polish + performance/memory (2026-11-22)

### What changed
**Background beat hints (your request)**
- **`beat_fx.gd`:** on every beat, 7 sparkles appear across the background and a soft glow pulses in from the screen edges. On downbeats: 16 gold sparkles and a stronger gold glow.
  - The effect runs in real time, so the hints stay in sync during slow-motion drawing.
- **Starfield:** stars brighten and grow on each beat, more on the downbeat, using `Conductor.beat_phase()`.
- *Why:* you asked for more visual hints. The beat can now be felt anywhere on screen, not just on the beat bar.

**Feel**
- **Screen shake:** player hit 12; shockwave 9, laser 6, lightning 5, shield 2 (×1.4 when empowered); boss phase change 10; boss death 18.
  - The whole world node moves; the HUD stays still.
- **Explosion particles:** 14 for enemies, 80 for bosses.
- **Dasher warning:** a harmless line along its charge path, one beat before the charge.

**Sound**
- New generated effects: one per skill (shockwave, laser, lightning, shield), a boss warning siren, a combo-milestone jingle, and a quiet "ding" on PERFECT clicks.
  - The ding adds sound feedback for hitting the beat.

**Performance and memory (your question, measured)**
- **Automated tests:** yes, every phase has run `tests/run_tests.gd`, now 111 checks. 3 new memory checks:
  - no leftover nodes after a busy fight;
  - 0 orphan nodes;
  - music track changes don't accumulate objects.
- **New `tests/perf_benchmark.gd`** (needs a real window). Load: enraged Rat King + 2 waves + constant skills and gunfire for 6 s. Results on this Mac:

  | Measure | Result |
  |---|---|
  | Average frame time | 8.3 ms (~120 fps) |
  | Worst frame | 9.7 ms |
  | Peak nodes | ~200 |
  | Static memory | 42 MB |
  | Nodes after clearing | back exactly to baseline |

- **Music memory:** Godot imports the WAVs with QOA compression (`compress/mode=2`), so the 7.6 MB on disk takes about 1.5 MB in memory. No change needed.
- **Music object leak, investigated:**
  - *Symptom:* each test run warned about leaked audio objects at exit.
  - *Measured:* after fades finish, 40 track changes add only +2 objects (one-time caching of the other tracks), so there's no growing leak. The exit warning is Godot reporting the track that was still loaded when the test quit.
  - *Change anyway:* `Conductor.play()` now stops and releases the old stream before creating a new one.
- **One 78 ms frame** appeared in the first benchmark run and never again in 3 later runs. Most likely a one-time startup cost; not reproducible, so not acted on.
- **No object pooling.** With ~120 fps and a ~10 ms worst frame under deliberate overload, measurements don't justify the added complexity.

### Problems found and fixed
- **An edit script aborted midway.**
  - *Cause:* a text match failed on an escaped `\n`. Only the first file had been changed.
  - *Fix:* detected from the error, re-applied with the correct match, and verified by running the tests.
- **The sparkle-fade test failed.**
  - *Cause:* the real music kept emitting beats during the test.
  - *Fix:* the test stops the music first.

### Verification
- Tests: 111 passed, 0 failed. New checks cover:
  - sparkle counts, the glow, and the fade;
  - the dasher's warning-only line;
  - shake moving and settling;
  - a **full scripted run** through all 3 levels, 15 waves and 3 bosses, reaching the ending screen;
  - the 3 memory checks.
- A screenshot on a downbeat shows the gold edge glow, the pulsing stars and the sparkles.
- **Not done: balancing.** There's no playtest feedback yet, and tuning drop amounts or boss health blind would just be guessing. That needs your playtest.

### Next
Day 7: the tutorial you asked for.
