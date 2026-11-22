extends Control

class_name SpellCardView

# A collectible SPELL CARD (owner request: "an actual card you see at the end of the level").
# Drawn in code: a gilded frame, the boss's portrait, the card's name, the boss's name, the
# spell it is weak to, capture count, and a NEW! ribbon the first time you win it.
# Locked cards (album) show a "?" silhouette.

const CARD_SIZE = Vector2(118, 166)

var card_name = ""
var boss_name = ""
var weak = ""
var portrait: Texture2D
var is_new = false
var locked = false
var captures = 0
var time = 0.0


static func make(entry: Dictionary, new_badge: bool = false, is_locked: bool = false) -> SpellCardView:
	var v = SpellCardView.new()
	v.card_name = entry.get("name", "")
	v.boss_name = entry.get("boss", "")
	v.weak = entry.get("weak", "")
	v.captures = entry.get("captures", 0)
	var script_path = entry.get("script", "")
	if script_path != "" and ResourceLoader.exists(script_path):
		var script = load(script_path)
		if "TEXTURE" in script:
			v.portrait = script.TEXTURE
	v.is_new = new_badge
	v.locked = is_locked
	v.custom_minimum_size = CARD_SIZE
	v.size = CARD_SIZE
	return v


func _process(delta):
	time += delta
	if is_new:
		queue_redraw()


func _draw():
	var r = Rect2(Vector2.ZERO, CARD_SIZE)
	var font = ThemeDB.fallback_font
	if locked:
		draw_rect(r, Color(0.16, 0.13, 0.25))
		draw_rect(r, Color(0.45, 0.4, 0.6), false, 3.0)
		draw_string(font, Vector2(0, CARD_SIZE.y / 2 + 16), "?", HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x, 48, Color(0.5, 0.45, 0.7))
		return
	# card body: deep violet with a soft gradient band
	draw_rect(r, Color(0.2, 0.12, 0.32))
	draw_rect(Rect2(6, 6, CARD_SIZE.x - 12, 84), Color(0.34, 0.22, 0.5))
	# gilded frame (shimmers when new)
	var shine = 0.75 + 0.25 * sin(time * 4.0) if is_new else 1.0
	draw_rect(r, Color(1, 0.82, 0.35, shine), false, 4.0)
	draw_rect(r.grow(-6), Color(1, 0.9, 0.6, 0.6), false, 1.5)
	# portrait
	if portrait:
		var ps = portrait.get_size()
		var k = min(70.0 / ps.x, 70.0 / ps.y)
		var pr = Rect2(Vector2(CARD_SIZE.x / 2.0 - ps.x * k / 2.0, 48 - ps.y * k / 2.0), ps * k)
		draw_texture_rect(portrait, pr, false)
	# texts
	var name_size = 12 if card_name.length() <= 13 else (10 if card_name.length() <= 17 else 9)
	draw_string(font, Vector2(4, 104), card_name, HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x - 8, name_size, Color(1, 0.92, 0.7))
	draw_string(font, Vector2(4, 122), boss_name.capitalize(), HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x - 8, 8 if boss_name.length() > 18 else 9, Color(0.85, 0.8, 1))
	if weak != "":
		draw_string(font, Vector2(6, 140), "weak: " + Game.SPELL_ICONS.get(weak, "") + " " + Game.SPELL_TITLES.get(weak, ""), HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x - 12, 9, Color(0.6, 0.95, 1))
	if captures > 1:
		draw_string(font, Vector2(6, 156), "x%d" % captures, HORIZONTAL_ALIGNMENT_RIGHT, CARD_SIZE.x - 12, 10, Color(1, 0.85, 0.5))
	if is_new:
		draw_colored_polygon(PackedVector2Array([Vector2(CARD_SIZE.x - 44, 0), Vector2(CARD_SIZE.x, 0), Vector2(CARD_SIZE.x, 44)]), Color(1, 0.35, 0.55))
		draw_string(font, Vector2(CARD_SIZE.x - 34, 16), "NEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
