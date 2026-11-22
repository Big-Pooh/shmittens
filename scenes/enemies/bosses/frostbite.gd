extends Boss

class_name Frostbite

# World 2, Frostwhisker: CAPTAIN FROSTBITE on his snowflake sled. Three cards:
#   0 "Snowfall"        - drifting orb snow from the top + staff notes.
#   1 "Icicle Lattice"  - the spear pincer from top and bottom + a 2-arm spiral.
#   2 "Blizzard"        - BEAT ARMOUR: freeze rings that re-aim, split orbs and a bounce fan.

const TEXTURE = preload("res://Art/Generated/boss_frostbite.png")


func _init():
	build(TEXTURE, 5.0, 80.0, 1500.0)
	boss_name = "CAPTAIN FROSTBITE"
	cards = [
		{"name": "Snowfall", "share": 0.34, "seconds": 35.0, "armored": false, "weak": "shockwave"},
		{"name": "Icicle Lattice", "share": 0.33, "seconds": 35.0, "armored": false, "weak": "lightning"},
		{"name": "Blizzard", "share": 0.33, "seconds": 42.0, "armored": true, "weak": "lightning"},
	]


func on_beat(n: int):
	var beat = n % 4
	var bar = n / 4
	match card:
		0:
			if beat == 0 or beat == 2:
				curtain(11, 130.0, 300.0 + 220.0 * sin(bar * 0.6), EnemyShot.Kind.ORB, 0.25 * sin(bar * 1.3))
		1:
			if beat == 0:
				pincer(10, 150.0, 320.0 + 200.0 * sin(bar * 0.9))
			if beat == 2:
				spiral(2, 150.0, 33.0)
		_:
			if beat == 1 and bar % 2 == 0:
				freeze_ring(12, 160.0, 220.0, EnemyShot.Kind.ORB, bar * 0.3)
			if beat == 3:
				split_orbs(3, 120.0)
			if beat == 2 and bar % 2 == 1:
				bounce_fan(6, 190.0)
	if beat == 0 and bar % 2 == 0:
		drift_to(360.0 + 160.0 * sin(bar * 0.5), Conductor.seconds_per_beat * 8.0)
	if beat == 3:
		telegraph()


func on_lead_note(pitch: int, _length: int):
	staff_note(pitch, 200.0)
