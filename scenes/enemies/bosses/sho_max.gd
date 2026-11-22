extends Boss

class_name ShoMax

# World 2 finale, Mount Flexmore: SHO, MAXIMUM FLEX - the rematch. Four cards using everything:
#   0 "Flex Supreme"                      - rose + aimed triple + butterfly wings.
#   1 "Protein Tsunami"                   - walls with a moving gap + cheese-orb rain.
#   2 "Gainz Galaxy"                      - accelerating galaxy + reversing sun spirals.
#   3 "Final Form (For Real This Time)"  - BEAT ARMOUR: flower + split orbs + crossing spirals.

const TEXTURE = preload("res://Art/Generated/boss_sho_max.png")

var counter_angle = 0.0


func _init():
	build(TEXTURE, 5.0, 92.0, 2200.0)
	boss_name = "SHO, MAXIMUM FLEX"
	cards = [
		{"name": "Flex Supreme", "share": 0.25, "seconds": 38.0, "armored": false, "weak": "shockwave"},
		{"name": "Protein Tsunami", "share": 0.25, "seconds": 38.0, "armored": false, "weak": "laser"},
		{"name": "Gainz Galaxy", "share": 0.25, "seconds": 38.0, "armored": false, "weak": "shockwave"},
		{"name": "Final Form (For Real This Time)", "share": 0.25, "seconds": 45.0, "armored": true, "weak": "lightning"},
	]


func on_beat(n: int):
	var beat = n % 4
	var bar = n / 4
	match card:
		0:
			if beat == 0:
				rose(18, 190.0, 5, bar * 0.2)
			if beat == 2:
				aimed(3, 230.0, 7.0)
			if beat == 3 and bar % 2 == 1:
				butterfly(3, 170.0, 1.0)
		1:
			if beat == 0:
				wall(340.0 + 210.0 * sin(bar * 0.85), 190.0, 175.0)
			if beat == 2 and bar % 2 == 0:
				curtain(11, 145.0, 260.0 + 200.0 * cos(bar), EnemyShot.Kind.ORB)
		2:
			galaxy(3, 270.0, 19.0)
			if beat == 1 or beat == 3:
				sun(2, 155.0, 23.0, bar)
		_:
			if beat == 0:
				flower(3, 12, 180.0, EnemyShot.Kind.RICE, bar * 0.13)
			if beat == 2:
				split_orbs(3, 125.0)
			if beat == 1 or beat == 3:
				spiral(1, 150.0, 29.0)
				if Game.assist < 2:
					fire_shot(Vector2.from_angle(PI + counter_angle), 150.0, EnemyShot.Kind.RICE)
					counter_angle -= deg_to_rad(29.0)
	if beat == 0 and bar % 2 == 0:
		drift_to(360.0 + 160.0 * sin(bar * 0.6), Conductor.seconds_per_beat * 8.0)
	if beat == 3:
		telegraph()


func on_lead_note(pitch: int, length: int):
	staff_note(pitch, 215.0, 2 if length >= 2 and card >= 2 else 1)
