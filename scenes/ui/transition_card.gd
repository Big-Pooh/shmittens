extends CanvasLayer

class_name TransitionCard

# Placeholder story card between levels (playtest 2: "otherwise there's no logic"):
#   result of the level just cleared (rank, time, perfect %), a little journey map
#   (FACTORY -> SEWERS -> CASTLE -> QUEEN) with the cat flying to the next stop, and the next
#   level's title and story. SPACE / click continues (the runner moves on at the next bar);
#   otherwise it moves on by itself after LevelRunner.CLEARED_BARS bars.

signal dismissed

const CAT_SHEET = preload("res://Art/Popo-AnimationSheet.png")
const QUEEN = preload("res://Art/Generated/queen.png")
const GOLD = Color(1, 0.82, 0.25)
# playtest 4: a planet map (Mario Galaxy style): home -> 4 planets -> the Princess on Flexor.
# Stop 0 is home (Pisitania); stop i + 1 is level i.
const HOME = "PISITANIA"
const HOME_COLOR = Color(1, 0.7, 0.55)
const MAP_Y = 420.0
const MAP_X0 = 170.0
const MAP_DX = 235.0

var cleared_index = 0
var rank = ""
var seconds = 0
var perfect_percent = 0
var cat: Sprite2D
var time = 0.0
var closing = false


static func create(index: int, level_rank: String, level_seconds: int, perfect: int) -> TransitionCard:
	var card = TransitionCard.new()
	card.cleared_index = index
	card.rank = level_rank
	card.seconds = level_seconds
	card.perfect_percent = perfect
	return card


func _ready():
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.14, 0.92)
	bg.size = Game.SCREEN.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var level = Levels.LEVELS[cleared_index]
	_text("LEVEL %d CLEAR!" % (cleared_index + 1), 44, GOLD, 18)
	_text("RANK %s      time %d:%02d      perfect %d" % [rank, seconds / 60, seconds % 60, perfect_percent] + "%", 22, Color(0.9, 0.9, 1), 76)
	var line = []
	var now = Game.challenge_results()
	for c in Game.PLANET_CHALLENGES:
		line.append(("★ " if now[c] else "☆ ") + Game.PLANET_CHALLENGE_NAMES[c])
	_text("CHALLENGES:   " + "      ".join(line), 18, Color(1, 0.9, 0.5), 108)
	_show_cards(Game.level_cards_won, 140)
	var map = Node2D.new()
	add_child(map)
	map.draw.connect(_draw_map.bind(map))
	map.queue_redraw()
	for i in _stops():
		_text(_stop_name(i), 16, Color(1, 1, 1) if i <= cleared_index - _base() + 2 else Color(0.6, 0.6, 0.7), MAP_Y + 42, MAP_X0 + i * MAP_DX - 100, 200)
	var princess = Sprite2D.new()
	princess.texture = QUEEN
	princess.scale = Vector2(2.5, 2.5)
	princess.position = Vector2(MAP_X0 + (_stops() - 1) * MAP_DX + 30, MAP_Y - 50)
	add_child(princess)
	if _world() == 1:
		princess.visible = false   # world 2's goal is the Star of Pisitania
		_text("★", 40, GOLD, MAP_Y - 80, MAP_X0 + (_stops() - 1) * MAP_DX - 70, 200)
	cat = Sprite2D.new()
	cat.texture = CAT_SHEET
	cat.hframes = 10
	cat.vframes = 5
	cat.scale = Vector2(1.4, 1.4)
	cat.position = Vector2(MAP_X0 + clamp(cleared_index - _base() + 1, 0, _stops() - 1) * MAP_DX, MAP_Y - 52)
	add_child(cat)
	var next = cleared_index + 1
	if next < Levels.count():
		var nl = Levels.LEVELS[next]
		_text("NEXT: LEVEL %d - %s" % [next + 1, nl.title], 26, GOLD, 498)
		_text(nl.story, 20, Color(0.9, 0.9, 1), 536)
	_text(Banter.pick(Banter.MAP_TIPS), 18, Color(1, 0.85, 0.6), 610)
	_text(Game.btn("SPACE", "A") + " - continue", 18, Color(0.7, 0.7, 0.85), 650)
	var tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(cat, "position:x", MAP_X0 + clamp(next - _base() + 1, 0, _stops() - 1) * MAP_DX, 2.2).set_trans(Tween.TRANS_SINE)


# The spell cards captured on this planet, revealed one after another (flip-in).
func _show_cards(won: Array, y: float):
	if won.is_empty():
		_text("No spell cards captured here - capture one (no hits, no bomb) to start your album!", 16, Color(0.7, 0.7, 0.85), y + 70)
		return
	_text("SPELL CARDS WON", 16, Color(1, 0.75, 0.95), y)
	var shown = won.slice(0, 7)
	var gap = 14.0
	var total = shown.size() * SpellCardView.CARD_SIZE.x + (shown.size() - 1) * gap
	for i in shown.size():
		var v = SpellCardView.make(shown[i][0], shown[i][1])
		v.position = Vector2(640 - total / 2.0 + i * (SpellCardView.CARD_SIZE.x + gap), y + 24)
		v.pivot_offset = SpellCardView.CARD_SIZE / 2.0
		v.scale = Vector2(0, 1)
		add_child(v)
		var tw = v.create_tween()
		tw.tween_interval(0.25 + 0.18 * i)
		tw.tween_property(v, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _text(text: String, size: int, color: Color, y: float, x: float = 60.0, width: float = 1160.0) -> Label:
	var label = Label.new()
	label.text = text
	label.position = Vector2(x, y)
	label.size = Vector2(width, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	return label


# Sprint 6: one map per world (4 planets each). The card shows the world of the NEXT planet.
const WORLD_SIZE = 4
const HOMES = ["PISITANIA", "STARGATE"]


func _world() -> int:
	return clamp((cleared_index + 1) / WORLD_SIZE, 0, (Levels.count() - 1) / WORLD_SIZE)


func _base() -> int:
	return _world() * WORLD_SIZE


func _stops() -> int:
	return WORLD_SIZE + 1


func _stop_name(i: int) -> String:
	return HOMES[_world()] if i == 0 else Levels.LEVELS[_base() + i - 1].title


func _stop_color(i: int) -> Color:
	return HOME_COLOR if i == 0 else Levels.LEVELS[_base() + i - 1].get("planet_color", Color(0.6, 0.6, 0.8))


func _draw_map(map: Node2D):
	for i in _stops() - 1:
		var a = Vector2(MAP_X0 + i * MAP_DX, MAP_Y)
		var b = Vector2(MAP_X0 + (i + 1) * MAP_DX, MAP_Y)
		var steps = 13
		for k in steps:
			if k % 2 == 0:
				map.draw_line(a.lerp(b, float(k) / steps), a.lerp(b, float(k + 1) / steps), Color(1, 1, 1, 0.5), 3.0)
	for i in _stops():
		var done = i <= cleared_index - _base() + 1
		var at = Vector2(MAP_X0 + i * MAP_DX, MAP_Y)
		var color = _stop_color(i) if done or i == cleared_index - _base() + 2 else _stop_color(i).darkened(0.55)
		map.draw_circle(at, 30.0, color)
		map.draw_circle(at + Vector2(-8, -8), 20.0, color.lightened(0.15))
		map.draw_arc(at, 40.0, -0.4, PI + 0.4, 32, Color(1, 1, 1, 0.3), 3.0)
		if done:
			map.draw_string(ThemeDB.fallback_font, at + Vector2(-8, 8), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1))
		if i > 0:
			var st = Game.stars(_base() + i - 1)
			var rank = Game.planet_records.get("level%d" % (_base() + i), {}).get("rank", "")
			var txt = "★".repeat(st) + "☆".repeat(3 - st) + ("  " + rank if rank != "" else "")
			map.draw_string(ThemeDB.fallback_font, at + Vector2(-34, -44), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)


func _process(delta):
	time += delta
	cat.frame = int(time * 12.0) % 10


func _unhandled_input(event):
	if closing:
		return
	if event.is_action_pressed("shoot") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		closing = true
		dismissed.emit()


func close():
	queue_free()
