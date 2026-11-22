extends Boss

class_name Sho

# Final boss (playtest 4 story): SHOCIREL, "Sho", the buff demon lord of the mice, who
# kidnapped the Princess of Pisitania. Four spell cards, the full Touhou-style toolbox:
#   0 "Flex Parade"        - a 5-petal rose on the downbeat, an aimed triple on beat 3,
#                            staff notes for the melody.
#   1 "Protein Rain"       - cheese orbs rain from the top in columns (a safe column moves
#                            each bar) + sun spirals on beats 2 and 4.
#   2 "Demon Lord's Waltz" - 3-arm sun spiral every beat (reverses each bar) + a ring that
#                            freezes on the beat and re-aims at you every other bar.
#   3 "Muscle Supernova"   - BEAT ARMOUR. A 3-petal flower each downbeat, a rose on beat 3,
#                            crossing spirals, and a little random spray.

const TEXTURE = preload("res://Art/Generated/boss_sho.png")

var counter_angle = 0.0


func _init():
	build(TEXTURE, 5.0, 90.0, 1000.0)
	boss_name = "SHOCIREL, DEMON LORD OF THE MICE"
	cards = [
		{"name": "Flex Parade", "share": 0.25, "seconds": 35.0, "armored": false, "weak": "shockwave"},
		{"name": "Protein Rain", "share": 0.25, "seconds": 35.0, "armored": false, "weak": "laser"},
		{"name": "Demon Lord's Waltz", "share": 0.25, "seconds": 35.0, "armored": false, "weak": "shockwave"},
		{"name": "Muscle Supernova", "share": 0.25, "seconds": 40.0, "armored": true, "weak": "lightning"},
	]


# The safe column of the protein rain drifts along with the bar number.
static func rain_gap(bar: int) -> float:
	return 300.0 + 220.0 * sin(bar * 0.7)


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	match card:
		0:
			if beat == 0:
				rose(18, 190.0, 5, bar * 0.2)
			if beat == 2:
				aimed(3, 230.0, 7.0)
		1:
			if beat == 0:
				curtain(12, 150.0, rain_gap(bar), EnemyShot.Kind.ORB, 0.15 * sin(bar))
			if beat == 2:
				split_orbs(3, 130.0)   # protein shakes that burst
			if beat == 1 or beat == 3:
				sun(2, 160.0, 24.0, bar)
		2:
			sun(3, 150.0, 19.0, bar)
			if beat == 3 and bar % 2 == 1:
				butterfly(3, 160.0, 1.0)
			if beat == 1 and bar % 2 == 0:
				freeze_ring(12, 170.0, 220.0, EnemyShot.Kind.ORB, bar * 0.3)
		_:
			if beat == 0:
				flower(3, 12, 180.0, EnemyShot.Kind.RICE, bar * 0.13)
			if beat == 2:
				if bar % 2 == 0:
					rose(14, 170.0, 4, bar * 0.4, EnemyShot.Kind.CANDY)
				else:
					galaxy(5, 280.0, 17.0)
			if beat == 1 or beat == 3:
				spiral(1, 150.0, 29.0)
				_counter_spiral()
				spray(2, 180.0)
	if beat == 0 and bar % 2 == 0:
		drift_to(360.0 + 160.0 * sin(bar * 0.6), Conductor.seconds_per_beat * 8.0)
	if beat == 3:
		telegraph()


func _counter_spiral():
	if Game.assist >= 2:
		return
	fire_shot(Vector2.from_angle(PI + counter_angle), 150.0, EnemyShot.Kind.RICE)
	counter_angle -= deg_to_rad(29.0)


func on_lead_note(pitch: int, length: int):
	staff_note(pitch, 210.0, 2 if length >= 2 and card >= 2 else 1)
