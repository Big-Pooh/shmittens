extends Boss

class_name Mothership

# Level 2 boss.
#   Even bars: launches 3 grunts on the downbeat.
#   Odd bars:  beat 2 lines up with the cat and shows the warning line (2 beats),
#              beat 4 fires a screen-wide beam at that height (lasts most of a beat).
# Phase 2: launches 2 grunts every bar; beam still on odd bars.

const TEXTURE = preload("res://Art/Generated/boss_mothership.png")
const GRUNT = preload("res://scenes/enemies/grunt.tscn")


func _init():
	build(TEXTURE, 5.0, 66.0, 160.0)
	boss_name = "MOUSE MOTHERSHIP"


func on_beat(n: int):
	var beat = n % Conductor.BEATS_PER_BAR
	var bar = n / Conductor.BEATS_PER_BAR
	var launch_bar = phase == 2 or bar % 2 == 0
	var beam_bar = bar % 2 == 1
	if beat == 0 and launch_bar:
		var count = 2 if phase == 2 else 3
		var slots = []
		for i in count:
			slots.append(Vector2(position.x - 160 - i * 70, 140 + i * 210 + (bar % 2) * 60))
		summon(GRUNT, slots, 3.0)
	if beam_bar:
		if beat == 1:
			var y = clamp(player_position().y, 120.0, 600.0)
			move_to_y(y, 0.2)
			telegraph()
			var beam = EnemyBeam.create(global_position.x - 80, y, Conductor.seconds_per_beat * 2.0, Conductor.seconds_per_beat * 0.8)
			get_tree().current_scene.add_child(beam)
