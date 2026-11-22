extends RefCounted

class_name Levels

# All level content in one place. Each level: title, music tracks, story card text, waves.
# A wave is a list of groups that spawn together; a group is:
#   enemy:     "grunt" | "gunner" | "dasher" | "shield"
#   formation: "grid" (columns x rows) | "column" (count) | "v" (count) | "line" (count, dashers)
#   health:    hit points per enemy (a normal shot does 1, a PERFECT click 2)
#   x:         optional right edge of the formation (default 1180)
# The next wave starts on the bar after the previous one is cleared.

const ENEMY_SCENES = {
	"grunt": preload("res://scenes/enemies/grunt.tscn"),
	"gunner": preload("res://scenes/enemies/gunner.tscn"),
	"dasher": preload("res://scenes/enemies/dasher.tscn"),
	"shield": preload("res://scenes/enemies/shield_mouse.tscn"),
	"weaver": preload("res://scenes/enemies/weaver.tscn"),
	"turret": preload("res://scenes/enemies/turret.tscn"),
	"splitter": preload("res://scenes/enemies/splitter.tscn"),
	"bomber": preload("res://scenes/enemies/bomber.tscn"),
}

const LEVELS = [
	{
		"title": "MOUSETRONICA",
		"planet": "Mousetronica, the factory planet",
		"planet_color": Color(0.95, 0.6, 0.35),
		"track": "level1",
		"boss_track": "boss1",
		"boss": "tank",
		"par_seconds": 55.0,   # playtest 2: slower BPM, tougher bosses (speedrunner median 51 s)
		"volley_rate": 0.5,   # onboarding: grunt volleys half as often in level 1
		"story": "Sho's robot mice are built on Mousetronica.\nShmitten and friends fly in to shut the factory down.",
		"waves": [
			[{"enemy": "grunt", "formation": "grid", "columns": 3, "rows": 3, "health": 2}],
			[{"enemy": "grunt", "formation": "grid", "columns": 4, "rows": 4, "health": 2}],
			[{"enemy": "weaver", "formation": "line", "count": 3, "health": 2, "x": 1100}],
			[{"enemy": "gunner", "formation": "column", "count": 3, "health": 4}],
			[{"enemy": "grunt", "formation": "grid", "columns": 3, "rows": 5, "health": 3, "x": 1000},
			 {"enemy": "gunner", "formation": "column", "count": 2, "health": 4}],
			[{"enemy": "grunt", "formation": "v", "count": 5, "health": 3},
			 {"enemy": "weaver", "formation": "line", "count": 2, "health": 2, "x": 1120}],
			[{"enemy": "gunner", "formation": "v", "count": 3, "health": 4},
			 {"enemy": "weaver", "formation": "line", "count": 3, "health": 2, "x": 1150}],
			[{"enemy": "gunner", "formation": "v", "count": 5, "health": 5}],
			[{"enemy": "grunt", "formation": "grid", "columns": 4, "rows": 3, "health": 3},
			 {"enemy": "gunner", "formation": "column", "count": 2, "health": 4, "x": 900}],
			[{"enemy": "grunt", "formation": "grid", "columns": 3, "rows": 4, "health": 3},
			 {"enemy": "splitter", "formation": "column", "count": 2, "health": 3, "x": 880}],
		],
	},
	{
		"title": "DRAINIA",
		"planet": "Drainia, the sewer moon",
		"planet_color": Color(0.4, 0.8, 0.6),
		"track": "level2",
		"boss_track": "boss2",
		"boss": "mothership",
		"par_seconds": 52.0,
		"story": "The trail leads to Drainia, the sewer moon,\nwhere Sho's cheese fleet guards the way.",
		"waves": [
			[{"enemy": "dasher", "formation": "line", "count": 3, "health": 2}],
			[{"enemy": "grunt", "formation": "grid", "columns": 4, "rows": 4, "health": 3}],
			[{"enemy": "weaver", "formation": "line", "count": 4, "health": 3, "x": 1100},
			 {"enemy": "splitter", "formation": "column", "count": 2, "health": 3, "x": 900}],
			[{"enemy": "gunner", "formation": "column", "count": 3, "health": 5},
			 {"enemy": "dasher", "formation": "line", "count": 2, "health": 2}],
			[{"enemy": "midboss", "boss": "tanky_jr"}],
			[{"enemy": "grunt", "formation": "v", "count": 7, "health": 3},
			 {"enemy": "dasher", "formation": "line", "count": 3, "health": 3}],
			[{"enemy": "bomber", "formation": "column", "count": 2, "health": 4, "x": 1180},
			 {"enemy": "grunt", "formation": "v", "count": 5, "health": 3}],
			[{"enemy": "gunner", "formation": "grid", "columns": 2, "rows": 4, "health": 5}],
			[{"enemy": "dasher", "formation": "line", "count": 3, "health": 3},
			 {"enemy": "weaver", "formation": "line", "count": 3, "health": 3, "x": 1000}],
			[{"enemy": "dasher", "formation": "line", "count": 4, "health": 3},
			 {"enemy": "splitter", "formation": "column", "count": 2, "health": 3, "x": 980}],
		],
	},
	{
		"title": "RATOPOLIS",
		"planet": "Ratopolis, the castle planet",
		"planet_color": Color(0.65, 0.5, 0.9),
		"track": "level3",
		"boss_track": "boss3",
		"boss": "rat_king",
		"par_seconds": 52.0,
		"story": "King Ratbert, Sho's loyal general, rules Ratopolis.\nHe knows the way to Sho's planet...",
		"waves": [
			[{"enemy": "shield", "formation": "grid", "columns": 3, "rows": 3, "health": 3}],
			[{"enemy": "turret", "formation": "line", "count": 2, "health": 6, "x": 1190},
			 {"enemy": "grunt", "formation": "grid", "columns": 3, "rows": 3, "health": 4, "x": 1000}],
			[{"enemy": "shield", "formation": "column", "count": 4, "health": 3, "x": 1000},
			 {"enemy": "gunner", "formation": "column", "count": 3, "health": 5}],
			[{"enemy": "dasher", "formation": "line", "count": 4, "health": 3},
			 {"enemy": "grunt", "formation": "grid", "columns": 3, "rows": 4, "health": 4}],
			[{"enemy": "midboss", "boss": "saucer_scout"}],
			[{"enemy": "shield", "formation": "v", "count": 7, "health": 4}],
			[{"enemy": "splitter", "formation": "column", "count": 3, "health": 4, "x": 1000},
			 {"enemy": "gunner", "formation": "column", "count": 2, "health": 5, "x": 1180}],
			[{"enemy": "shield", "formation": "grid", "columns": 2, "rows": 4, "health": 4, "x": 1020},
			 {"enemy": "gunner", "formation": "column", "count": 3, "health": 6},
			 {"enemy": "dasher", "formation": "line", "count": 2, "health": 3}],
			[{"enemy": "weaver", "formation": "line", "count": 5, "health": 4, "x": 1100},
			 {"enemy": "shield", "formation": "column", "count": 3, "health": 4, "x": 950},
			 {"enemy": "bomber", "formation": "column", "count": 2, "health": 4, "x": 1180}],
			[{"enemy": "shield", "formation": "grid", "columns": 2, "rows": 3, "health": 4, "x": 1060},
			 {"enemy": "weaver", "formation": "line", "count": 3, "health": 4, "x": 880}],
		],
	},
	{
		"title": "FLEXOR",
		"planet": "Flexor, Sho's fortress planet",
		"planet_color": Color(0.9, 0.3, 0.45),
		"track": "level4",
		"boss_track": "boss4",
		"boss": "sho",
		"par_seconds": 60.0,
		"story": "Flexor: Sho's own planet. The Princess is held here.\nEverything Sho has is waiting for you!",
		"waves": [
			[{"enemy": "grunt", "formation": "grid", "columns": 4, "rows": 4, "health": 4},
			 {"enemy": "dasher", "formation": "line", "count": 2, "health": 2}],
			[{"enemy": "turret", "formation": "line", "count": 3, "health": 10, "x": 1190},
			 {"enemy": "weaver", "formation": "line", "count": 3, "health": 4, "x": 1000},
			 {"enemy": "bomber", "formation": "column", "count": 2, "health": 5, "x": 880}],
			[{"enemy": "shield", "formation": "column", "count": 4, "health": 5, "x": 1000},
			 {"enemy": "gunner", "formation": "v", "count": 5, "health": 5}],
			[{"enemy": "dasher", "formation": "line", "count": 5, "health": 3},
			 {"enemy": "gunner", "formation": "column", "count": 3, "health": 6}],
			[{"enemy": "midboss", "boss": "royal_guard"}],
			[{"enemy": "shield", "formation": "grid", "columns": 3, "rows": 4, "health": 5, "x": 1040},
			 {"enemy": "grunt", "formation": "v", "count": 7, "health": 4}],
			[{"enemy": "bomber", "formation": "column", "count": 3, "health": 5, "x": 1180},
			 {"enemy": "dasher", "formation": "line", "count": 3, "health": 4}],
			[{"enemy": "gunner", "formation": "grid", "columns": 2, "rows": 4, "health": 6},
			 {"enemy": "dasher", "formation": "line", "count": 3, "health": 3},
			 {"enemy": "shield", "formation": "column", "count": 3, "health": 5, "x": 960}],
			[{"enemy": "grunt", "formation": "grid", "columns": 4, "rows": 4, "health": 5},
			 {"enemy": "turret", "formation": "line", "count": 2, "health": 12, "x": 1190},
			 {"enemy": "splitter", "formation": "column", "count": 3, "health": 4, "x": 760}],
			[{"enemy": "splitter", "formation": "column", "count": 3, "health": 5, "x": 1000},
			 {"enemy": "gunner", "formation": "v", "count": 5, "health": 6}],
		],
	},
]

const BOSS_SCRIPTS = {
	"sho": preload("res://scenes/enemies/bosses/sho.gd"),
	"tanky_jr": preload("res://scenes/enemies/bosses/tanky_jr.gd"),
	"saucer_scout": preload("res://scenes/enemies/bosses/saucer_scout.gd"),
	"royal_guard": preload("res://scenes/enemies/bosses/royal_guard.gd"),
	"tank": preload("res://scenes/enemies/bosses/mecha_tank.gd"),
	"mothership": preload("res://scenes/enemies/bosses/mothership.gd"),
	"rat_king": preload("res://scenes/enemies/bosses/rat_king.gd"),
}
const BOSS_SLOT = Vector2(1060, 360)

const SPACING = Vector2(86, 74)   # playtest 2: the cute mice are rounder
const DEFAULT_RIGHT_X = 1180.0
const SPAWN_X = 1380.0


static func count() -> int:
	return LEVELS.size()


# Slot positions for a group, in screen coordinates.
static func formation_slots(group: Dictionary) -> Array:
	var right = group.get("x", DEFAULT_RIGHT_X)
	var mid_y = Game.SCREEN.get_center().y
	var slots = []
	if group.enemy == "midboss":
		return [BOSS_SLOT]
	match group.formation:
		"grid":
			var rows = group.rows
			var top = mid_y - (rows - 1) * SPACING.y / 2.0
			for column in group.columns:
				for row in rows:
					slots.append(Vector2(right - column * SPACING.x, top + row * SPACING.y))
		"column":
			var n = group.count
			var gap = min(SPACING.y * 1.6, 460.0 / max(n - 1, 1))
			for i in n:
				slots.append(Vector2(right, mid_y + (i - (n - 1) / 2.0) * gap))
		"v":
			# arrow pointing left: apex in front, arms trailing up-right and down-right
			var n = group.count
			var apex = Vector2(right - (n / 2) * 60.0, mid_y)
			slots.append(apex)
			for i in range(1, n):
				var arm = (i + 1) / 2
				var side = -1 if i % 2 == 1 else 1
				slots.append(apex + Vector2(arm * 60.0, side * arm * 62.0))
		"line":
			var n = group.count
			for i in n:
				slots.append(Vector2(right, 110 + (i + 0.5) * (500.0 / n)))
	return slots


# Mid-boss group (playtest 7 content): {"enemy": "midboss", "boss": "tank", "name": "...",
# "health": 140, "card": "Card name", "seconds": 25, "weak": "laser"} - a boss script with one
# spell card and less health, flying in mid-level.
static func create_midboss(group: Dictionary) -> Boss:
	var boss = BOSS_SCRIPTS[group.boss].new()
	boss.is_midboss = true
	# dedicated mid-boss scripts bring their own name, health and 2 cards; a group may override
	if group.has("name"):
		boss.boss_name = group.name
	if group.has("health"):
		boss.max_health = group.health
	if group.has("card"):
		boss.cards = [{"name": group.card, "share": 1.0, "seconds": group.get("seconds", 25.0), "armored": false, "weak": group.get("weak", "")}]
	boss.slot_position = BOSS_SLOT
	boss.position = Vector2(SPAWN_X + 80, BOSS_SLOT.y)
	return boss


# Instantiates the enemies of one group (not yet added to the tree).
static func create_group(group: Dictionary, volley_rate: float = 1.0) -> Array:
	if group.enemy == "midboss":
		return [create_midboss(group)]
	var enemies = []
	var slots = formation_slots(group)
	for i in slots.size():
		var enemy = ENEMY_SCENES[group.enemy].instantiate()
		enemy.slot_position = slots[i]
		enemy.position = Vector2(SPAWN_X + (i % 4) * 40.0, slots[i].y)
		enemy.max_health = group.health
		if enemy is Grunt:
			# grid: one column fires per bar; other formations: thirds of the group in turn
			var columns = group.get("columns", 3)
			if group.formation == "grid":
				enemy.fire_slot = i / group.rows
				enemy.fire_slots = int(round(columns / volley_rate))
			else:
				enemy.fire_slot = i % 3
				enemy.fire_slots = int(round(3 / volley_rate))
		enemies.append(enemy)
	return enemies


# The level's boss, flying in from the right to BOSS_SLOT (not yet added to the tree).
static func create_boss(level_index: int) -> Boss:
	var boss = BOSS_SCRIPTS[LEVELS[level_index].boss].new()
	boss.slot_position = BOSS_SLOT
	boss.position = Vector2(SPAWN_X + 80, BOSS_SLOT.y)
	return boss


# Level-clear rank (mastery goal for skilled players):
#   S: at or under par time, >= 60% PERFECT clicks, no game over on this level
#   A: within 1.5x par, >= 40% PERFECT, no game over
#   B: no game over;  C: cleared after a game over
static func rank(seconds: float, par: float, perfect_ratio: float, had_game_over: bool) -> String:
	if had_game_over:
		return "C"
	if seconds <= par and perfect_ratio >= 0.6:
		return "S"
	if seconds <= par * 1.5 and perfect_ratio >= 0.4:
		return "A"
	return "B"
