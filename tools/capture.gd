extends SceneTree
# Marketing capture: plays a planet from a given wave with the speedrunner bot while Godot's
# movie writer records. Usage (from the project root):
#   Godot --path . --write-movie out/f.png --fixed-fps 30 --quit-after 900 -s tools/capture.gd -- <planet 0-3> <wave> [persona]
# Then pick frames for screenshots, or record to an .avi for trailer footage.

var bot


func _initialize():
	var args = OS.get_cmdline_user_args()
	var game = root.get_node("Game")
	game.persist = false
	game.skip_intro = true
	game.fullscreen = false
	game.challenge = 0
	game.relaxed_mode = false
	game.start_level = int(args[0]) if args.size() > 0 else 0
	game.start_wave = int(args[1]) if args.size() > 1 else 0
	change_scene_to_file("res://scenes/main.tscn")
	create_timer(0.5).timeout.connect(_attach.bind(args[2] if args.size() > 2 else "speedrunner"))


func _attach(persona: String):
	var main = current_scene
	var game = root.get_node("Game")
	game.gun_level = 3
	game.add_charge(3)
	game.challenge = 0   # the player's saved difficulty loads after _initialize; footage is NORMAL
	for tip in ["spell_cards", "overdrive", "bomb", "companions", "mech", "weakness"]:
		game.tips_seen[tip] = true   # no tutorial pop-ups in marketing footage
	main.get_node("Shmitten").is_invulnerable = true   # keep the footage going
	bot = load("res://tests/persona_bot.gd").new()
	bot.setup(persona, 7, {})
	main.add_child(bot)
