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
}

const LEVELS = [
	{
		"title": "MOUSE FACTORY",
		"track": "level1",
		"boss_track": "boss1",
		"boss": "tank",
		"par_seconds": 45.0,
		"volley_rate": 0.5,   # onboarding: grunt volleys half as often in level 1
		"story": "The Rat King has taken the Queen!\nShmitten flies into the Mouse Factory to find her.",
		"waves": [
			[{"enemy": "grunt", "formation": "grid", "columns": 3, "rows": 3, "health": 2}],
			[{"enemy": "grunt", "formation": "grid", "columns": 4, "rows": 4, "health": 2}],
			[{"enemy": "gunner", "formation": "column", "count": 3, "health": 4}],
			[{"enemy": "grunt", "formation": "grid", "columns": 3, "rows": 5, "health": 3, "x": 1000},
			 {"enemy": "gunner", "formation": "column", "count": 2, "health": 4}],
			[{"enemy": "gunner", "formation": "v", "count": 5, "health": 5}],
		],
	},
	{
		"title": "SEWER FLEET",
		"track": "level2",
		"boss_track": "boss2",
		"boss": "mothership",
		"par_seconds": 40.0,
		"story": "The trail leads down into the sewers,\nwhere the mouse fleet guards the way.",
		"waves": [
			[{"enemy": "dasher", "formation": "line", "count": 3, "health": 2}],
			[{"enemy": "grunt", "formation": "grid", "columns": 4, "rows": 4, "health": 3}],
			[{"enemy": "gunner", "formation": "column", "count": 3, "health": 5},
			 {"enemy": "dasher", "formation": "line", "count": 2, "health": 2}],
			[{"enemy": "grunt", "formation": "v", "count": 7, "health": 3},
			 {"enemy": "dasher", "formation": "line", "count": 3, "health": 3}],
			[{"enemy": "gunner", "formation": "grid", "columns": 2, "rows": 4, "health": 5}],
		],
	},
	{
		"title": "RAT KING'S CASTLE",
		"track": "level3",
		"boss_track": "boss3",
		"boss": "rat_king",
		"par_seconds": 60.0,
		"story": "At last, the Rat King's castle.\nThe Queen is somewhere inside...",
		"waves": [
			[{"enemy": "shield", "formation": "grid", "columns": 3, "rows": 3, "health": 4}],
			[{"enemy": "shield", "formation": "column", "count": 4, "health": 4, "x": 1000},
			 {"enemy": "gunner", "formation": "column", "count": 3, "health": 5}],
			[{"enemy": "dasher", "formation": "line", "count": 4, "health": 3},
			 {"enemy": "grunt", "formation": "grid", "columns": 3, "rows": 4, "health": 4}],
			[{"enemy": "shield", "formation": "v", "count": 7, "health": 5}],
			[{"enemy": "shield", "formation": "grid", "columns": 2, "rows": 4, "health": 5, "x": 1020},
			 {"enemy": "gunner", "formation": "column", "count": 3, "health": 6},
			 {"enemy": "dasher", "formation": "line", "count": 2, "health": 3}],
		],
	},
]

const BOSS_SCRIPTS = {
	"tank": preload("res://scenes/enemies/bosses/mecha_tank.gd"),
	"mothership": preload("res://scenes/enemies/bosses/mothership.gd"),
	"rat_king": preload("res://scenes/enemies/bosses/rat_king.gd"),
}
const BOSS_SLOT = Vector2(1060, 360)

const SPACING = Vector2(78, 70)
const DEFAULT_RIGHT_X = 1180.0
const SPAWN_X = 1380.0


static func count() -> int:
	return LEVELS.size()


# Slot positions for a group, in screen coordinates.
static func formation_slots(group: Dictionary) -> Array:
	var right = group.get("x", DEFAULT_RIGHT_X)
	var mid_y = Game.SCREEN.get_center().y
	var slots = []
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


# Instantiates the enemies of one group (not yet added to the tree).
static func create_group(group: Dictionary, volley_rate: float = 1.0) -> Array:
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
