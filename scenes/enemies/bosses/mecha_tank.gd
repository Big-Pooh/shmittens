extends Boss

class_name MechaTank

# Level 1 boss, "Tanky": the gentle introduction to patterns. Two spell cards:
#   0 "Toy Cannon Parade" - a 5-candy arc on the downbeat (nudged every bar so the safe lanes
#     alternate) + the melody as staff notes. Drifts between two heights.
#     Every 4th bar a small 3-petal rose blooms.
#   1 "Clockwork Waltz" (beat armour) - a 2-arm "sun" spiral on beats 2 and 4 that reverses
#     every bar, a 2-petal flower every other bar, staff notes.

const TEXTURE = preload("res://Art/Generated/boss_tank.png")


func _init():
	build(TEXTURE, 5.0, 78.0, 380.0)   # playtest 3: x2 again - card timers now cap the fight for beginners
	boss_name = "TANKY THE MECHA-MOUSE"
	cards = [
		{"name": "Toy Cannon Parade", "share": 0.5, "seconds": 30.0, "armored": false, "weak": "laser"},
		{"name": "Clockwork Waltz", "share": 0.5, "seconds": 35.0, "armored": true, "weak": "lightning"},
	]


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	if card == 0:
		if beat == 0:
			arc(5, 16.0, 180.0, 180.0 + (8.0 if bar % 2 == 0 else -8.0))
		if beat == 2 and bar % 4 == 3:
			rose(12, 160.0, 3, bar * 0.3)   # playtest 4: a little bloom to read
	else:
		if beat == 1 or beat == 3:
			sun(2, 150.0, 37.0, bar)
		if beat == 0 and bar % 2 == 0:
			flower(2, 10, 170.0, EnemyShot.Kind.ORB, bar * 0.2)
		if beat == 2 and bar % 2 == 1:
			butterfly(3, 170.0, 0.9)   # curving wings
	if beat == 0 and bar % 2 == 0:
		drift_to(260.0 if (bar / 2) % 2 == 0 else 460.0, Conductor.seconds_per_beat * 4.0)
	if beat == 3:
		telegraph()


func on_lead_note(pitch: int, _length: int):
	staff_note(pitch, 190.0 if card == 0 else 210.0)
