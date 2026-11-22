extends Boss

class_name BigCheese

# World 2, Cheddaria: THE BIG CHEESE, a giant cheese-wheel robot. Three cards:
#   0 "Wheel of Fortune" - a rotating ring on the downbeat + a bounce fan off the dunes.
#   1 "Cheese Grater"    - a wall with a moving gap + an accelerating galaxy.
#   2 "Fondue Flood"     - BEAT ARMOUR: cheese rain + split orbs + reversing sun spirals.

const TEXTURE = preload("res://Art/Generated/boss_big_cheese.png")


func _init():
	build(TEXTURE, 5.0, 80.0, 1200.0)
	boss_name = "THE BIG CHEESE"
	cards = [
		{"name": "Wheel of Fortune", "share": 0.34, "seconds": 35.0, "armored": false, "weak": "shockwave"},
		{"name": "Cheese Grater", "share": 0.33, "seconds": 35.0, "armored": false, "weak": "laser"},
		{"name": "Fondue Flood", "share": 0.33, "seconds": 40.0, "armored": true, "weak": "lightning"},
	]


func on_beat(n: int):
	var beat = n % 4
	var bar = n / 4
	match card:
		0:
			if beat == 0:
				ring(16, 160.0, bar * 0.13 * mirror)
			if beat == 2 and bar % 2 == 1:
				bounce_fan(6, 180.0)
		1:
			if beat == 0:
				wall(330.0 + 200.0 * sin(bar * 0.8), 190.0, 170.0)
			if beat == 2:
				galaxy(4, 260.0, 21.0)
		_:
			if beat == 0 and bar % 2 == 0:
				curtain(10, 140.0, 260.0 + 160.0 * sin(bar), EnemyShot.Kind.ORB)
			if beat == 2:
				split_orbs(3, 120.0)
			if beat == 1 or beat == 3:
				sun(2, 150.0, 23.0, bar)
	if beat == 0 and bar % 2 == 0:
		drift_to(360.0 + 140.0 * sin(bar * 0.7), Conductor.seconds_per_beat * 8.0)
	if beat == 3:
		telegraph()


func on_lead_note(pitch: int, _length: int):
	staff_note(pitch, 200.0)
