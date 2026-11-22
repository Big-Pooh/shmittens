extends Node2D

class_name Banter

# Gags and silly lines (playtest 5: "it takes itself too serious"). Audience: cat lovers and
# casual rhythm players of all ages -> wholesome puns, cartoon villains, no meanness.
# Speech bubbles follow whoever speaks and pop after a moment. Purely cosmetic.

const MOUSE_WAVE = [
	"Squeak! For the cheese!", "Is it leg day?", "Sho said this would be EASY!",
	"Formation! ...which one is left?", "I was promised dental.", "Cheese first, questions later!",
	"Wait, is that a CAT?", "Ten-HUT! Squeak-HUT!", "I forgot my helmet. Again.",
]
const MOUSE_DEFEAT = [
	"Nooo my cheese!", "Tell my mom I squeaked!", "Worth it.", "I regret nothing!",
	"Squeak you later!", "Oof. Ow. Squeak.",
]
const BOSS_CARD = {
	"TANKY THE MECHA-MOUSE": ["Beep boop. Prepare to be... TANKED.", "Clockwork waltz! One-two-three, beep!"],
	"THE CHEESE SAUCER": ["Cheese rain incoming! Bring an umbrella!", "Holey lattice! Mind the holes. It's ALL holes."],
	"KING RATBERT": ["Bow before King Ratbert! ...please?", "Rat race! I'm winning! Am I winning?", "Long live ME! (Sho said I could say that)"],
	"SHOCIREL, DEMON LORD OF THE MICE": ["Do you even lift, kitty?", "PROTEIN RAIN! Stay hydrated!", "Waltz with my MUSCLES!", "Behold my FINAL FORM! (it's the same, but shinier)"],
	"TRAINING TANKY": ["I'm just a practice tank. Please be gentle."],
	"TANKY JR.": ["My dad is a TANK! ...a bigger one."],
	"SAUCER SCOUT": ["Scout report: one cat. Very fluffy. Send cheese."],
	"ROYAL GUARD": ["Halt! Nobody sees Sho without an appointment!"],
}
const BOSS_STUNNED = ["My armour! I JUST polished it!", "Ow! My beat! You broke my beat!", "That's... not fair... it was on the beat...", "Seeing stars. And cheese."]
const BOSS_DEFEAT = {
	"SHOCIREL, DEMON LORD OF THE MICE": "Not... my... GAINS...",
	"KING RATBERT": "I'm telling Sho!",
	"THE CHEESE SAUCER": "Abandon cheese!",
	"TANKY THE MECHA-MOUSE": "Error 404: tank not found.",
}
const CAT_COMBO = ["Purr-fect!", "Meow-velous!", "Claw-some!", "Paws-itively rhythmic!", "Hiss-terical!", "Fur real?!", "Un-fur-gettable!", "The cat's pajamas!"]
const GAME_OVER = [
	"Shmitten used one of her nine lives. (She only had three. Math is hard.)",
	"Even superheroes need a cat nap.",
	"The mice are doing a little victory dance. Rude.",
	"Somewhere, a mouse is writing this down in its diary.",
]
const MAP_TIPS = [
	"Tip: mice cannot read. Please don't tell them.",
	"Fun fact: cheese is 90% holes.",
	"Tip: Sho skips cardio. Use this information wisely.",
	"Tip: if you fail, try being a cat about it.",
	"Fun fact: Pip has a pilot licence. Nobody has checked it.",
	"Tip: dancing between waves is not optional. It is the law.",
	"Fun fact: Kiwi can't actually fly. Don't tell Kiwi.",
]

var bubbles: Array = []   # [label, target(Node2D or null), offset, time_left]


static func pick(lines: Array) -> String:
	return lines[randi() % lines.size()]


func _ready():
	z_index = 70
	get_tree().node_added.connect(_on_node_added)
	Game.combo_changed.connect(_on_combo)


func _on_node_added(node: Node):
	if node is EnemyBase and not node is Boss:
		node.died.connect(_on_mouse_died)


func _on_mouse_died(enemy: EnemyBase):
	if randf() < 0.12 and is_inside_tree():
		say_at(enemy.global_position, pick(MOUSE_DEFEAT), Color(0.95, 0.9, 1))


func _on_combo(combo: int, _m: int):
	if combo > 0 and combo % 10 == 0 and is_inside_tree() and Game.player_ref:
		say(Game.player_ref, pick(CAT_COMBO), Color(1, 0.85, 0.4))


# A random mouse on screen says something as a wave arrives.
func wave_chatter():
	await get_tree().create_timer(1.2, false).timeout
	if not is_inside_tree() or randf() > 0.6:
		return
	var mice = get_tree().get_nodes_in_group("enemies").filter(func(e): return not e.is_dead and not e is Boss)
	if not mice.is_empty():
		say(mice[randi() % mice.size()], pick(MOUSE_WAVE), Color(0.95, 0.9, 1))


func boss_card(boss: Boss, index: int):
	var lines = BOSS_CARD.get(boss.boss_name, [])
	if lines.is_empty():
		return
	say(boss, lines[min(index, lines.size() - 1)], Color(1, 0.7, 0.8), 2.6)


func boss_stunned(boss: Boss):
	say(boss, pick(BOSS_STUNNED), Color(0.6, 1, 1))


func boss_defeated(boss: Boss):
	if BOSS_DEFEAT.has(boss.boss_name):
		say_at(boss.global_position, BOSS_DEFEAT[boss.boss_name], Color(1, 0.7, 0.8), 2.6)


func say(target: Node2D, text: String, color: Color, seconds: float = 1.8):
	_bubble(text, color, target, Vector2(-40, -90), seconds)


func say_at(at: Vector2, text: String, color: Color, seconds: float = 1.8):
	var label = _bubble(text, color, null, Vector2.ZERO, seconds)
	label.position = at + Vector2(-40, -70)


func _bubble(text: String, color: Color, target, offset: Vector2, seconds: float) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.25))
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	label.add_theme_stylebox_override("normal", style)
	add_child(label)
	bubbles.append([label, target, offset, seconds])
	if target:
		label.position = target.global_position + offset
	return label


func _process(delta):
	for b in bubbles:
		b[3] -= delta
		var label: Label = b[0]
		if b[1] != null and is_instance_valid(b[1]):
			label.position = b[1].global_position + b[2]
		label.position.x = clamp(label.position.x, 8.0, 1272.0 - label.size.x)
		label.position.y = clamp(label.position.y, 50.0, 640.0)
		if b[3] < 0.3:
			label.modulate.a = max(b[3] / 0.3, 0.0)
	for b in bubbles.filter(func(b): return b[3] <= 0.0):
		b[0].queue_free()
	bubbles = bubbles.filter(func(b): return b[3] > 0.0)
