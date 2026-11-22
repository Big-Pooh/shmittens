extends Boss

class_name RatKing

# Level 3 boss, "King Ratbert", Sho's loyal general. Playtest 2: "too many random bullets and hard to hit"
# -> no shot-blocking guards, no jumping to your height, every bullet is part of a fixed
# pattern. Three spell cards:
#   0 "Royal Decree" - a 14-candy ring that rotates a little every bar + a 5-shot arc on beat 3.
#   1 "Rat Race Rondo" - two counter-rotating rice spirals on every beat (a readable lattice)
#     and an orb ring every other bar that freezes on the beat, then re-aims at you.
#   2 "Long Live the King" (beat armour) - a 3-petal flower on every downbeat + the crossing
#     spirals on beats 2 and 4. Long melody notes become chords.
# Slow figure-of-eight drift throughout.

const TEXTURE = preload("res://Art/Generated/boss_rat_king.png")

var counter_angle = 0.0


func _init():
	build(TEXTURE, 6.0, 84.0, 700.0)
	boss_name = "KING RATBERT"
	cards = [
		{"name": "Royal Decree", "share": 0.35, "seconds": 35.0, "armored": false, "weak": "laser"},
		{"name": "Rat Race Rondo", "share": 0.35, "seconds": 35.0, "armored": false, "weak": "shockwave"},
		{"name": "Long Live the King", "share": 0.3, "seconds": 40.0, "armored": true, "weak": "lightning"},
	]


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	match card:
		0:
			if beat == 0:
				ring(14, 160.0, bar * 0.11)
			if beat == 2:
				if bar % 2 == 0:
					arc(5, 14.0, 190.0)
				else:
					rose(12, 170.0, 4, bar * 0.5)
		1:
			spiral(1, 150.0, 31.0)
			_counter_spiral()
			if beat == 0 and bar % 2 == 0:
				freeze_ring(12, 170.0, 210.0, EnemyShot.Kind.ORB, bar * 0.25)
		_:
			if beat == 0:
				flower(3, 12, 180.0, EnemyShot.Kind.RICE, bar * 0.17)
			if beat == 1 or beat == 3:
				sun(1, 150.0, 31.0, bar)
				_counter_spiral()
	if beat == 0 and bar % 2 == 0:
		drift_to(360.0 + 150.0 * sin(bar * 0.8), Conductor.seconds_per_beat * 8.0)
	if beat == 3:
		telegraph()


# The second arm turns the other way, so the two arms cross in a readable lattice.
func _counter_spiral():
	if Game.assist >= 2:
		return
	fire_shot(Vector2.from_angle(PI + counter_angle), 150.0, EnemyShot.Kind.RICE)
	counter_angle -= deg_to_rad(31.0)


func on_lead_note(pitch: int, length: int):
	staff_note(pitch, 205.0, 2 if length >= 2 and card == 2 else 1)
