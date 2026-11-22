extends Node

# Global run state (autoload "Game"): score, lives, skill charges, cheese, gun level.

signal score_changed(score: int)
signal lives_changed(lives: int)
signal charges_changed(charges: int, cheese: int)
signal gun_level_changed(level: int)
signal weapon_changed(weapon: int)
signal dance_changed(active: bool)
signal overdrive_changed(state: int)   # 0 none, 1 ready (banked), 2 active
signal grazed(at: Vector2, on_beat: bool)
signal mech_parts_changed(parts: int)
signal mech_core_ready
signal mech_changed(active: bool)   # dance break between waves (see LevelRunner)
signal wave_changed(wave: int)
signal game_over
signal combo_changed(combo: int, multiplier: int)
signal judged(judgement: int)
signal reward(kind: String)          # "battery" / "yarn" from combo milestones
signal level_changed(level: int)
signal shake_requested(strength: float)
signal fever_changed(active: bool)
signal second_wind_changed(active: bool)
signal player_hit(cause: String)   # "shot", "ram", "beam" (for stats)

const START_LIVES = 3
const CHEESE_PER_CHARGE = 10
const MAX_CHARGES = 3
const MAX_GUN_LEVEL = 5
# On-beat clicks in a row needed for score multiplier x1, x2, x3, x4
const COMBO_TIERS = [0, 5, 12, 24]
# Combo milestones (on-beat hits in a row) that hand out rewards
const BATTERY_EVERY = 5
const YARN_EVERY = 15
# Kills that weren't on-beat clicks drop 1 cheese every this many kills
const PLAIN_KILLS_PER_CHEESE = 4
# FEVER (rewards skilled players): every FEVER_EVERY on-beat hits in a row -> FEVER_BEATS beats
# of piercing, +50% damage shots and full music.
const FEVER_EVERY = 16
const FEVER_BEATS = 8
const FEVER_DAMAGE = 1.5
var fever_beats = 0
var spell_power = 1.0   # Spell Chain multiplier for the skill being cast (set by GestureInput)

# Physics layer bits (match [layer_names] in project.godot)
const LAYER_PLAYER = 1
const LAYER_PLAYER_SHOT = 2
const LAYER_ENEMY = 4
const LAYER_ENEMY_SHOT = 8
const LAYER_PICKUP = 16

# Playfield in world/screen coordinates
const SCREEN = Rect2(0, 0, 1280, 720)

var score = 0
var lives = START_LIVES
var charges = 0
var cheese = 0
var gun_level = 1
# Weapons (playtest 2): switch any time with 1/2/3, Q/E or the mouse wheel. Gun level
# (yarn) powers whichever weapon is equipped. Kept across deaths and levels.
enum Weapon { SPREAD, LASER, FISH }
const WEAPON_NAMES = ["YARN SPREAD", "LASER POINTER", "FISH SEEKERS"]
const WEAPON_HINTS = ["point blank - eats bullets into spell fuel", "aim it - strongest, pierces", "homing - easy, weaker"]
var weapon = Weapon.FISH   # playtest 3: Fish is the default; the others reward skill
var focus_override = false   # automated playthroughs hold "focus" with this
var dancing = false          # true during a dance break between waves
var player_ref: Node2D = null   # the cat (set by Shmitten; bullets use it for graze/aim)
# GRAZE (playtest 3, Touhou): a bullet passing very close counts once: GRAZE_SCORE points; on
# the beat it also builds toward cheese (1 per GRAZES_PER_CHEESE on-beat grazes).
const GRAZE_SCORE = 20
const GRAZES_PER_CHEESE = 3
var beat_grazes = 0
# CATNIP OVERDRIVE (playtest 3 idea): every OVERDRIVE_COMBO on-beat hits in a row banks one
# overdrive (max 1). Press F to unleash OVERDRIVE_SECONDS of a giant rainbow beam.
const OVERDRIVE_COMBO = 50
const OVERDRIVE_SECONDS = 5.0
var overdrive = 0   # 0 none, 1 ready, 2 active
# MECHA-MEOW (playtest 5): the rarest power-up. Earn MECH_PARTS_NEEDED parts by playing well -
# every boss spell card CAPTURED and every MECH_COMBO on-beat hits in a row give one part - and
# a golden MECH CORE drops; collect it to pilot the mech for Shmitten.MECH_SECONDS.
# Parts carry across planets (lost only on a game over).
# Playtest 6: 6 mechs in one run was not "very rare" -> 4 parts, combo parts every 75 hits,
# capture parts only for cards captured WITH a drawn spell, and at most one mech per planet
# (parts wait at 3/4 until the next planet).
const MECH_PARTS_NEEDED = 4
const MECH_COMBO = 75
var mech_parts = 0
var mech_used_this_level = false
var magnet_until = -1.0
# RANK (classic shmup dynamic difficulty, content pass): the stronger your gun, the tougher the
# mice - so skilled players get meatier fights while beginners (who lose gun levels when hit)
# barely notice. Applied to health when an enemy spawns.
const RANK_PER_GUN_LEVEL = 0.15        # mice: up to x1.6 at gun level 5
const BOSS_RANK_PER_GUN_LEVEL = 0.075  # bosses: up to x1.3


func rank_health(is_boss: bool) -> float:
	return 1.0 + (BOSS_RANK_PER_GUN_LEVEL if is_boss else RANK_PER_GUN_LEVEL) * (gun_level - 1)
# PLANET CHALLENGES (replay goals, design review): per planet attempt we track hits taken, spell
# cards captured vs met, and which spell shapes were cast. Best results are saved per planet:
# planet_records["level1"] = {"rank": "A", "no_hit": true, "all_cards": false, "all_spells": true}
const PLANET_CHALLENGES = ["no_hit", "all_cards", "all_spells"]
const PLANET_CHALLENGE_NAMES = {"no_hit": "No hits", "all_cards": "Capture every card", "all_spells": "Use all 4 spells"}
var planet_records = {}
var level_hits = 0
var level_cards_met = 0
var level_cards_captured = 0
var level_spells = {}   # CIRCLE spell: every pickup flies to the cat until play_time > this
var wave = 0
var combo = 0
var plain_kills = 0
var level = 0
var wave_total = 0
# level to (re)start at when the main scene loads; kept across reset() so retry works
var start_level = 0
# Checkpoint: wave to resume from after a game over (waves.size() = the boss)
var start_wave = 0
# Assist (beginner care): each game over on the same level adds one, up to MAX_ASSIST.
# Effects: enemy shots ASSIST_SHOT_SLOWDOWN slower per level, +1 life per level (up to +2).
const MAX_ASSIST = 3
const ASSIST_SHOT_SLOWDOWN = 0.12
const LEVEL_SHOT_SPEED = [1.0, 1.15, 1.3, 1.2]   # Flexor: denser waves, slightly slower bullets
const LEVEL_COUNT = 4   # Levels.LEVELS.size() (playtest 4: + Flexor, Sho's planet)   # playtest 1: dodging felt too easy (was 0.8/0.9/1.0)
var assist = 0
# per-level rank stats (time is measured by the level runner)
var level_judged = 0
var level_perfects = 0
var level_deaths = 0   # deaths in the current level attempt (early guardian)
# Second Wind (beginner care, reacts within a level): 2 deaths within SECOND_WIND_WINDOW seconds
# -> enemy shots SECOND_WIND_SLOWDOWN slower for SECOND_WIND_TIME seconds.
const SECOND_WIND_WINDOW = 45.0
const SECOND_WIND_TIME = 45.0
const SECOND_WIND_SLOWDOWN = 0.15
var play_time = 0.0
var recent_deaths = []
var second_wind_until = -1.0
var ranks = []   # rank letter per cleared level this run
# true while the tutorial runs (main.gd starts the Tutorial instead of a level)
var tutorial_mode = false
# Automated playthroughs aim with this instead of the mouse (null = use the mouse)
var aim_override = null

# ---- settings + saved progress (user://settings.cfg, shared with the Conductor's beat offset)
const SETTINGS_PATH = "user://settings.cfg"
var music_volume = 0.8
var sfx_volume = 0.8
var fullscreen = false
var reduce_effects = false   # accessibility: no screen shake, softer flashes
var relaxed_mode = false     # accessibility: always at least assist 1 (slower shots, +1 life, guardian)
var meows_enabled = true     # Settings -> "Cat meows"
# Challenge modes (playtest 4): 0 NORMAL, 1 HARD, 2 TOUHOU (unlocked by beating the story on HARD).
# HARD: faster, denser patterns, tougher bosses, no assists / guardian / second wind.
# TOUHOU: twice the bullets (a bit slower), bigger graze for triple points, 1 free bomb per life.
enum Challenge { NORMAL, HARD, TOUHOU }
const CHALLENGE_NAMES = ["NORMAL", "HARD", "BULLET HELL"]   # (never "Touhou": trademark)
const CHALLENGE_DENSITY = [1.0, 1.4, 2.0]
const CHALLENGE_SHOT_SPEED = [1.0, 1.15, 0.9]
const CHALLENGE_BOSS_HEALTH = [1.0, 1.6, 2.0]   # longer fights for players who chose them
var challenge = Challenge.NORMAL
var hard_cleared = false     # unlocks TOUHOU
var bomb_stock = 0           # TOUHOU: free bombs (1 per life)
# One-time tips (playtest 4: "I didn't know until the end how spell cards work")
var tips_seen = {}
# ONE NAME PER SPELL, used by the guide, banners, popups, card weaknesses and the tutorial.
const SPELL_TITLES = {"shockwave": "CIRCLE BURST", "laser": "LINE SLASH", "lightning": "ZIGZAG BOLT", "shield": "TRIANGLE SHIELD"}
const SPELL_ICONS = {"shockwave": "○", "laser": "―", "lightning": "ϟ", "shield": "△"}
# Feedback and bug reports (GTM: an in-game path for testers). Opened in the browser; nothing is
# sent automatically.
const FEEDBACK_URL = "https://github.com/Big-Pooh/shmittens/issues/new?template=playtest_feedback.yml"
const BUG_URL = "https://github.com/Big-Pooh/shmittens/issues/new?template=bug_report.yml"
const STEAM_URL = "https://github.com/Big-Pooh/shmittens"   # swap for the Steam page once it is live
# DEMO build (export feature "demo"): the story stops after world 1 with a wishlist screen.
func is_demo() -> bool:
	return OS.has_feature("demo")


func open_feedback():
	track("feedback_opened")
	OS.shell_open(FEEDBACK_URL)


func open_bug_report():
	OS.shell_open(BUG_URL)
var skip_intro = false   # tests and simulations start games without the story
# BOMB (playtest 5: 11 bombs in one run crowded out drawing -> cut to about a quarter): one bomb
# per planet, and it needs at least BOMB_MIN_CHARGES charges. TOUHOU keeps its free bomb per life.
const BOMB_MIN_CHARGES = 2
var bomb_used_this_level = false


# Returns true the first time a tip is requested (and remembers it).
func first_time(tip: String) -> bool:
	if tips_seen.has(tip):
		return false
	tips_seen[tip] = true
	save_settings()
	return true
var difficulty_chosen = false   # first START asks Relaxed / Normal once
var unlocked_level = 0       # highest story level the player may start
var story_complete = false   # unlocks Endless
var best_scores = {}         # "level1".."level3", "endless" -> best score
var endless_mode = false
# false in simulations (tests/playthrough.gd): never write the player's real save/settings
var persist = true
var is_game_over = false
var drawing = false   # true while a skill gesture is being drawn (gun is disabled)


func reset():
	score = 0
	lives = START_LIVES + min(assist, 2)
	charges = 0
	cheese = 0
	gun_level = 1
	wave = 0
	combo = 0
	plain_kills = 0
	fever_beats = 0
	recent_deaths.clear()
	second_wind_until = -1.0
	is_game_over = false
	drawing = false
	dancing = false
	beat_grazes = 0
	bomb_stock = 1 if is_touhou() else 0
	if overdrive == 2:
		overdrive = 1   # an overdrive cut short by a restart stays banked
	combo_changed.emit(combo, multiplier())
	score_changed.emit(score)
	lives_changed.emit(lives)
	charges_changed.emit(charges, cheese)
	gun_level_changed.emit(gun_level)
	weapon_changed.emit(weapon)
	wave_changed.emit(wave)


func add_score(points: int):
	score += points * multiplier()
	score_changed.emit(score)
	if score > session.get("best_run_score", 0.0):
		session["best_run_score"] = float(score)   # survives the score reset on retry/title


func add_cheese(amount: int = 1):
	cheese += amount
	while cheese >= CHEESE_PER_CHARGE:
		cheese -= CHEESE_PER_CHARGE
		charges = min(charges + 1, MAX_CHARGES)
	# at max charges the meter stays full instead of being wasted
	if charges == MAX_CHARGES:
		cheese = min(cheese, CHEESE_PER_CHARGE)
	charges_changed.emit(charges, cheese)


func add_charge(amount: int = 1):
	charges = min(charges + amount, MAX_CHARGES)
	charges_changed.emit(charges, cheese)


# Returns false if there was no charge to spend.
func use_charge() -> bool:
	if charges <= 0:
		return false
	charges -= 1
	charges_changed.emit(charges, cheese)
	return true


# ---- session stats (playtest 3): what actually happened in a real play session, saved on
# your machine only (user://sessions/<start time>.json) so playtests can be analysed.
var session = {}
var session_file = ""

func track(key: String, amount: float = 1.0):
	session[key] = session.get(key, 0.0) + amount


func save_session(reason: String):
	if not persist or session.is_empty():
		return
	if session_file == "":
		DirAccess.make_dir_recursive_absolute("user://sessions")
		session_file = "user://sessions/%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
	var data = session.duplicate()
	data["last_event"] = reason
	data["level"] = level + 1
	data["score"] = score
	data["relaxed_mode"] = relaxed_mode
	var f = FileAccess.open(session_file, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))


func add_mech_part(reason: String):
	if level < 2 and not endless_mode:
		return   # playtest 7: the mech is a planet-3+ reward (one new system at a time)
	if mech_used_this_level and mech_parts >= MECH_PARTS_NEEDED - 1:
		return   # one mech per planet: the last part waits for the next planet
	mech_parts += 1
	track("mech_parts")
	track("mech_part_" + reason)
	if mech_parts >= MECH_PARTS_NEEDED:
		mech_parts = 0
		mech_used_this_level = true
		track("mech_cores")
		mech_core_ready.emit()
	mech_parts_changed.emit(mech_parts)


# Spread pellets EAT bullets: every BULLETS_PER_CHEESE eaten bullets = 1 cheese (spell fuel).
const BULLETS_PER_CHEESE = 3
var bullets_eaten = 0

func eat_bullet():
	bullets_eaten += 1
	track("bullets_eaten")
	if bullets_eaten % BULLETS_PER_CHEESE == 0:
		add_cheese(1)


# HIT-PAUSE (presentation pass): freeze the action for a moment on big impacts (armour
# shattered, a spell card ending). The music clock runs on real time, so the beat never slips.
const HIT_PAUSE = 0.05

func hit_pause(seconds: float = HIT_PAUSE):
	if drawing or reduce_effects or Engine.time_scale < 0.99 or not is_inside_tree():
		return
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func(): if not drawing: Engine.time_scale = 1.0)
	track("hit_pauses")


func set_overdrive(state: int):
	overdrive = state
	overdrive_changed.emit(state)


func graze(at: Vector2):
	var on_beat = Conductor.judge() != Conductor.Judgement.MISS
	add_score(GRAZE_SCORE * (3 if is_touhou() else 1))
	track("grazes")
	if on_beat:
		beat_grazes += 1
		track("beat_grazes")
		if beat_grazes % GRAZES_PER_CHEESE == 0:
			add_cheese(1)
	grazed.emit(at, on_beat)


func set_dancing(on: bool):
	if on == dancing:
		return
	dancing = on
	dance_changed.emit(on)


func set_weapon(w: int):
	w = posmod(w, WEAPON_NAMES.size())
	if w == weapon:
		return
	weapon = w
	weapon_changed.emit(weapon)
	Sfx.play("weapon_switch", -8.0)


func cycle_weapon(step: int):
	set_weapon(weapon + step)


func add_gun_level(amount: int = 1):
	gun_level = clamp(gun_level + amount, 1, MAX_GUN_LEVEL)
	gun_level_changed.emit(gun_level)


func multiplier() -> int:
	var tier = 0
	for i in COMBO_TIERS.size():
		if combo >= COMBO_TIERS[i]:
			tier = i
	return tier + 1


# Called for every judged click. On-beat (GOOD/PERFECT) grows the combo, MISS resets it.
# The music gets a layer per multiplier tier: x1 drums+bass, x2 +arp, x3/x4 +lead.
func register_judgement(judgement: int):
	level_judged += 1
	if judgement == Conductor.Judgement.PERFECT:
		level_perfects += 1
	if judgement == Conductor.Judgement.MISS:
		combo = 0
	else:
		combo += 1
		if combo % BATTERY_EVERY == 0:
			reward.emit("battery")
		if combo % YARN_EVERY == 0:
			reward.emit("yarn")
		if combo % FEVER_EVERY == 0:
			fever_beats = FEVER_BEATS
			fever_changed.emit(true)
		if combo % MECH_COMBO == 0:
			add_mech_part("combo")
		if combo % OVERDRIVE_COMBO == 0 and overdrive == 0:
			set_overdrive(1)
			track("overdrives_earned")
	judged.emit(judgement)
	combo_changed.emit(combo, multiplier())
	Conductor.set_layers(4 if is_fever() else multiplier() + 1)


func reset_combo():
	combo = 0
	combo_changed.emit(combo, multiplier())
	Conductor.set_layers(2)


# Returns true when this non-rhythm kill earns a cheese (every PLAIN_KILLS_PER_CHEESE-th).
func register_plain_kill() -> bool:
	plain_kills += 1
	return plain_kills % PLAIN_KILLS_PER_CHEESE == 0


func set_level(value: int, total_waves: int):
	level = value
	level_judged = 0
	level_perfects = 0
	level_deaths = 0
	wave_total = total_waves
	wave = 0
	level_hits = 0
	level_cards_met = 0
	level_cards_captured = 0
	level_spells = {}
	bomb_used_this_level = false
	mech_used_this_level = false
	level_changed.emit(level)
	wave_changed.emit(wave)


# Enemy shot speed multiplier: gentler early levels, slower with assist.
func shot_speed_factor() -> float:
	var base = LEVEL_SHOT_SPEED[clamp(level, 0, LEVEL_SHOT_SPEED.size() - 1)]
	var wind = 1.0 - SECOND_WIND_SLOWDOWN if second_wind_active() else 1.0
	return base * (1.0 - ASSIST_SHOT_SLOWDOWN * assist) * wind * CHALLENGE_SHOT_SPEED[challenge]


# How many bullets patterns fire (1.0 normal, more on HARD/TOUHOU).
func density() -> float:
	return CHALLENGE_DENSITY[challenge]


func is_touhou() -> bool:
	return challenge == Challenge.TOUHOU


func difficulty_name() -> String:
	return "RELAXED" if relaxed_mode else CHALLENGE_NAMES[challenge]


# Sets the difficulty: "relaxed", "normal", "hard" or "touhou".
func set_difficulty(name: String):
	relaxed_mode = name == "relaxed"
	challenge = {"hard": Challenge.HARD, "touhou": Challenge.TOUHOU}.get(name, Challenge.NORMAL)
	if challenge == Challenge.TOUHOU and not hard_cleared:
		challenge = Challenge.HARD
	clear_assist()


func second_wind_active() -> bool:
	return play_time < second_wind_until


func _process(delta):
	if get_tree().paused:
		return
	var was = second_wind_active()
	play_time += delta
	if was and not second_wind_active():
		second_wind_changed.emit(false)


# Called on retry after a game over on the same level.
func add_assist():
	if challenge != Challenge.NORMAL:
		return   # HARD / TOUHOU: no help
	assist = min(assist + 1, MAX_ASSIST)


# New game: no assist.
func clear_assist():
	assist = 1 if relaxed_mode else 0


# Next level: struggling players keep a little help (one level less); others stay at 0.
func carry_assist():
	assist = max(assist - 1, 1 if relaxed_mode else 0)


# Extra warning beats for beams/dashes while assisted.
func warning_beats(base: int) -> int:
	return base + (1 if assist > 0 else 0)


# Screen shake (pixels); the main scene applies it.
func shake(strength: float):
	if reduce_effects:
		return
	shake_requested.emit(strength)


func is_fever() -> bool:
	return fever_beats > 0


func _ready():
	Conductor.beat.connect(_on_beat)
	load_settings()
	apply_settings()


func load_settings():
	var c = ConfigFile.new()
	if c.load(SETTINGS_PATH) != OK:
		return
	music_volume = c.get_value("audio", "music_volume", music_volume)
	sfx_volume = c.get_value("audio", "sfx_volume", sfx_volume)
	fullscreen = c.get_value("video", "fullscreen", fullscreen)
	reduce_effects = c.get_value("access", "reduce_effects", reduce_effects)
	relaxed_mode = c.get_value("access", "relaxed_mode", relaxed_mode)
	meows_enabled = c.get_value("audio", "meows", meows_enabled)
	challenge = c.get_value("access", "challenge", challenge)
	hard_cleared = c.get_value("progress", "hard_cleared", hard_cleared)
	planet_records = c.get_value("progress", "planet_records", planet_records)
	tips_seen = c.get_value("progress", "tips_seen", tips_seen)
	difficulty_chosen = c.get_value("access", "difficulty_chosen", difficulty_chosen)
	unlocked_level = c.get_value("progress", "unlocked_level", unlocked_level)
	story_complete = c.get_value("progress", "story_complete", story_complete)
	best_scores = c.get_value("progress", "best_scores", best_scores)


func save_settings():
	if not persist:
		return
	var c = ConfigFile.new()
	c.load(SETTINGS_PATH)   # keep other sections (beat offset, tutorial)
	c.set_value("audio", "music_volume", music_volume)
	c.set_value("audio", "sfx_volume", sfx_volume)
	c.set_value("video", "fullscreen", fullscreen)
	c.set_value("access", "reduce_effects", reduce_effects)
	c.set_value("access", "relaxed_mode", relaxed_mode)
	c.set_value("audio", "meows", meows_enabled)
	c.set_value("access", "challenge", challenge)
	c.set_value("progress", "hard_cleared", hard_cleared)
	c.set_value("progress", "planet_records", planet_records)
	c.set_value("progress", "tips_seen", tips_seen)
	c.set_value("access", "difficulty_chosen", difficulty_chosen)
	c.set_value("progress", "unlocked_level", unlocked_level)
	c.set_value("progress", "story_complete", story_complete)
	c.set_value("progress", "best_scores", best_scores)
	c.save(SETTINGS_PATH)


func apply_settings():
	for bus_name in ["Music", "SFX"]:
		var bus = AudioServer.get_bus_index(bus_name)
		if bus >= 0:
			var volume = music_volume if bus_name == "Music" else sfx_volume
			AudioServer.set_bus_volume_db(bus, linear_to_db(max(volume, 0.0001)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


# This attempt's challenge results.
func challenge_results() -> Dictionary:
	return {
		"no_hit": level_hits == 0,
		"all_cards": level_cards_met > 0 and level_cards_captured >= level_cards_met,
		"all_spells": level_spells.size() >= 4,
	}


# Merges this attempt into the planet's saved record (best rank, any challenge ever completed).
func record_planet(level_index: int, rank: String):
	var key = "level%d" % (level_index + 1)
	var rec = planet_records.get(key, {"rank": "", "no_hit": false, "all_cards": false, "all_spells": false})
	var order = ["", "C", "B", "A", "S"]
	if order.find(rank) > order.find(rec.rank):
		rec.rank = rank
	var now = challenge_results()
	for c in PLANET_CHALLENGES:
		rec[c] = rec[c] or now[c]
	planet_records[key] = rec
	track("challenges_done", float(now.values().count(true)))


func stars(level_index: int) -> int:
	var rec = planet_records.get("level%d" % (level_index + 1), {})
	return PLANET_CHALLENGES.filter(func(c): return rec.get(c, false)).size()


# A story level was cleared: unlock the next one and keep the best score.
func record_level_clear(level_index: int):
	unlocked_level = max(unlocked_level, min(level_index + 1, LEVEL_COUNT - 1))
	record_score("level%d" % (level_index + 1))
	save_settings()


func record_score(key: String) -> bool:
	var is_best = score > best_scores.get(key, 0)
	if is_best:
		best_scores[key] = score
		save_settings()
	return is_best


func _on_beat(_n: int):
	if fever_beats > 0:
		fever_beats -= 1
		if fever_beats == 0:
			fever_changed.emit(false)
			Conductor.set_layers(multiplier() + 1)


func set_wave(value: int):
	wave = value
	wave_changed.emit(wave)


# Called when the cat is hit. Returns the lives left.
func lose_life() -> int:
	level_deaths += 1
	recent_deaths.append(play_time)
	recent_deaths = recent_deaths.filter(func(t): return play_time - t <= SECOND_WIND_WINDOW)
	if recent_deaths.size() >= 2 and challenge == Challenge.NORMAL:
		var was_active = second_wind_active()
		second_wind_until = play_time + SECOND_WIND_TIME
		if not was_active:
			second_wind_changed.emit(true)
	lives = max(lives - 1, 0)
	lives_changed.emit(lives)
	add_gun_level(-1)
	reset_combo()
	if is_touhou():
		bomb_stock = 1   # a fresh bomb with every life
	if lives == 0:
		mech_parts = 0   # a game over loses the collected mech parts
		mech_parts_changed.emit(mech_parts)
	if lives == 0 and not is_game_over:
		is_game_over = true
		game_over.emit()
	return lives
