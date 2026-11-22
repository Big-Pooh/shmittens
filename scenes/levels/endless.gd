extends RefCounted

class_name Endless

# Endless mode (unlocked after the story): waves cycle through every story wave with health
# rising each wave; every BOSS_EVERY-th wave is a boss (tank -> mothership -> Rat King -> ...),
# and the music moves to the next track after each boss. Best score is saved.

const BOSS_EVERY = 5
const HEALTH_GROWTH = 0.12   # +12% enemy health per wave
const TRACKS = ["level1", "level2", "level3"]


static func stage(wave: int) -> int:
	return (wave / BOSS_EVERY) % TRACKS.size()


static func is_boss_wave(wave: int) -> bool:
	return (wave + 1) % BOSS_EVERY == 0


static func wave_groups(wave: int) -> Array:
	var pool = []
	for level in Levels.LEVELS:
		for w in level.waves:
			pool.append(w)
	var base = pool[(wave * 7) % pool.size()]   # deterministic tour of all waves
	var scale = 1.0 + HEALTH_GROWTH * wave
	var groups = []
	for g in base:
		var copy = g.duplicate()
		copy.health = int(ceil(g.health * scale))
		groups.append(copy)
	return groups


static func boss_health_scale(wave: int) -> float:
	return 1.0 + 0.25 * (wave / BOSS_EVERY / TRACKS.size())   # each full cycle of bosses is tougher
