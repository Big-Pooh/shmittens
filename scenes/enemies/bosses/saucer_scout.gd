extends Boss

class_name SaucerScout

# Mid-boss of Ratopolis: a scouting dish with a periscope. Two cards:
#   0 "Scout Drizzle" - a cheese-orb rain with a safe column every other bar + staff notes.
#   1 "Searchlight"   - NEW PATTERN: a fan of bullets sweeping up and down like a searchlight
#                       on every hi-hat; read the sweep and slip under it.

const TEXTURE = preload("res://Art/Generated/boss_saucer_scout.png")


func _init():
	build(TEXTURE, 4.0, 56.0, 190.0)
	boss_name = "SAUCER SCOUT"
	cards = [
		{"name": "Scout Drizzle", "share": 0.5, "seconds": 22.0, "armored": false, "weak": "shockwave"},
		{"name": "Searchlight", "share": 0.5, "seconds": 24.0, "armored": false, "weak": "laser"},
	]


func on_beat(n: int):
	var bar = n / 4
	if card == 0 and n % 4 == 0 and bar % 2 == 0:
		curtain(9, 140.0, 220.0 + 140.0 * (bar % 3), EnemyShot.Kind.ORB)
	if n % 4 == 3:
		telegraph()


func on_hat(n: int):
	if card == 1 and (Game.assist == 0 or (n / 2) % 2 == 0):
		searchlight(fmod(Conductor.beat_position() / 8.0, 1.0), 3, 210.0)


func on_lead_note(pitch: int, _length: int):
	if card == 0:
		staff_note(pitch, 190.0)
