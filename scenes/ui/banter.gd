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


const CAT_SHEET = preload("res://Art/Popo-AnimationSheet.png")


# Speech bubble with an animated PORTRAIT of the speaker (presentation pass): the speaker's own
# sprite (the cat's flying frames) in a little frame that bobs and blinks while it talks.
func _bubble(text: String, color: Color, target, offset: Vector2, seconds: float) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", style)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var portrait = _portrait(target)
	if portrait:
		row.add_child(portrait)
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.25))
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	add_child(panel)
	bubbles.append([panel, target, offset, seconds])
	if target:
		panel.position = target.global_position + offset
	return panel


# The text of a bubble (tests).
static func text_of(bubble: Control) -> String:
	for l in bubble.find_children("*", "Label", true, false):
		return l.text
	return ""


func _portrait(target) -> Control:
	if target == null or not is_instance_valid(target):
		return null
	var tex: Texture2D = null
	var region = Rect2()
	if target is Shmitten:
		tex = CAT_SHEET
		region = Rect2(0, 0, 64, 48)
	elif "sprite" in target and target.sprite and target.sprite.texture:
		tex = target.sprite.texture
	if tex == null:
		return null
	var holder = Control.new()
	holder.custom_minimum_size = Vector2(34, 30)
	var icon = TextureRect.new()
	if region.size != Vector2.ZERO:
		var atlas = AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = region
		tex = atlas
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(34, 30)
	icon.pivot_offset = Vector2(17, 15)
	holder.add_child(icon)
	# 3-frame talk animation: bob up, squash, back (loops while the bubble lives)
	var tween = icon.create_tween().set_loops()
	tween.tween_property(icon, "scale", Vector2(1.08, 0.92), 0.12)
	tween.tween_property(icon, "scale", Vector2(0.94, 1.08), 0.12)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.12)
	return holder


const HUD_BAND = 344.0   # below the HUD band (0-272) and the banner lane (292-332)


func _process(delta):
	for b in bubbles:
		b[3] -= delta
		var label: Control = b[0]
		if b[1] != null and is_instance_valid(b[1]):
			label.position = b[1].global_position + b[2]
		label.position.x = clamp(label.position.x, 8.0, 1272.0 - label.size.x)
		label.position.y = clamp(label.position.y, HUD_BAND, 640.0)
	# bubbles never overlap: later bubbles are pushed up above earlier ones
	var placed: Array = []
	# keep clear of the HUD's centre message and banners too
	var hud = get_tree().current_scene.get_node_or_null("HUD") if get_tree().current_scene else null
	if hud:
		if hud.message.visible:
			placed.append(Rect2(hud.message.position, hud.message.size).grow(6))
		for c in hud.get_children():
			if c.name.begins_with("Banner"):
				placed.append(Rect2(0, c.position.y, 1280, 44))
	for b in bubbles:
		var c: Control = b[0]
		var r = Rect2(c.position, c.size)
		var guard = 0
		while placed.any(func(p): return p.grow(2).intersects(r)) and guard < 6:
			r.position.y -= r.size.y + 4.0
			if r.position.y < HUD_BAND:   # never into the score / boss bar / card band: go below
				r.position.y = placed.map(func(p): return p.end.y).max() + 4.0
			guard += 1
		c.position = r.position
		placed.append(r)
		if b[3] < 0.3:
			c.modulate.a = max(b[3] / 0.3, 0.0)
	for b in bubbles.filter(func(b): return b[3] <= 0.0):
		b[0].queue_free()
	bubbles = bubbles.filter(func(b): return b[3] > 0.0)
