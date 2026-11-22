extends SceneTree
# Renders the Steam capsule set into marketing/capsules/ (procedural art, style guide colours).
#   Godot --path . -s tools/capsules.gd          (needs a window: not --headless)
# Layout rule (GTM review): big logo, one character, high contrast, readable at 120x45.

const OUT = "res://marketing/capsules/"
const CAT_SHEET = preload("res://Art/Popo-AnimationSheet.png")
const SHO = preload("res://Art/Generated/boss_sho.png")
const GRUNT = preload("res://Art/Generated/grunt.png")
const SIZES = {
	"header_460x215": Vector2i(460, 215),
	"small_231x87": Vector2i(231, 87),
	"main_616x353": Vector2i(616, 353),
	"vertical_374x448": Vector2i(374, 448),
	"library_600x900": Vector2i(600, 900),
	"library_hero_3840x1240": Vector2i(3840, 1240),
	"logo_1280x720": Vector2i(1280, 720),
}
const NIGHT = Color(0.043, 0.031, 0.086)
const GOLD = Color(1, 0.84, 0.35)
const PINK = Color(1, 0.6, 0.8)

var jobs: Array = []


func _initialize():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for key in SIZES:
		jobs.append(key)
	_next()


func _next():
	if jobs.is_empty():
		print("capsules done")
		quit()
		return
	var key = jobs.pop_front()
	var size: Vector2i = SIZES[key]
	var vp = SubViewport.new()
	vp.size = size
	vp.transparent_bg = key.begins_with("logo")
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	_compose(vp, key, Vector2(size))
	for i in 3:
		await process_frame
	var img = vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + key + ".png"))
	vp.queue_free()
	_next()


func _compose(vp: SubViewport, key: String, s: Vector2):
	var logo_only = key.begins_with("logo")
	var hero = key.begins_with("library_hero")
	var tall = s.y > s.x
	var k = min(s.x / 616.0, s.y / 353.0) if not tall else s.x / 374.0
	if not logo_only:
		var bg = ColorRect.new()
		bg.color = NIGHT
		bg.size = s
		vp.add_child(bg)
		var art = Node2D.new()
		vp.add_child(art)
		art.draw.connect(func():
			var rng = RandomNumberGenerator.new()
			rng.seed = 3
			for i in int(s.x * s.y / 900.0):
				art.draw_circle(Vector2(rng.randf() * s.x, rng.randf() * s.y), rng.randf_range(0.6, 1.8) * max(k, 1.0), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
			art.draw_circle(Vector2(s.x * 0.92, s.y * 1.15), s.y * 0.75, Color(0.95, 0.6, 0.45, 0.35))
			art.draw_circle(Vector2(s.x * 0.92, s.y * 1.15), s.y * 0.55, Color(1, 0.72, 0.55, 0.25)))
		art.queue_redraw()
		# the hook in one picture: a glowing drawn circle around a little swarm
		var swarm_center = Vector2(s.x * (0.72 if not tall else 0.62), s.y * (0.62 if not tall else 0.72))
		var ring = Node2D.new()
		vp.add_child(ring)
		var r = (s.y if not tall else s.x) * 0.22
		ring.draw.connect(func():
			ring.draw_arc(swarm_center, r, 0, TAU * 0.95, 64, Color(0.5, 0.9, 1, 0.9), max(3.0, 5.0 * k))
			ring.draw_arc(swarm_center, r * 1.08, 0, TAU, 64, Color(1, 1, 1, 0.35), max(1.5, 2.0 * k)))
		ring.queue_redraw()
		for i in 3:
			var m = Sprite2D.new()
			m.texture = GRUNT
			m.scale = Vector2.ONE * max(1.2, 2.2 * k)
			m.position = swarm_center + Vector2.from_angle(TAU * i / 3.0 + 0.4) * r * 0.45
			vp.add_child(m)
		if s.x >= 600 or hero:
			var sho = Sprite2D.new()
			sho.texture = SHO
			sho.scale = Vector2.ONE * (2.6 * k if not tall else 2.2 * k)
			sho.position = Vector2(s.x * 0.88, s.y * (0.5 if not tall else 0.34))
			sho.modulate = Color(1, 1, 1, 0.85)
			vp.add_child(sho)
		var cat = Sprite2D.new()
		cat.texture = CAT_SHEET
		cat.hframes = 10
		cat.vframes = 5
		cat.scale = Vector2.ONE * (3.6 * k if not hero else 9.0)
		cat.position = Vector2(s.x * (0.3 if not tall else 0.38), s.y * (0.66 if not tall else 0.5))
		vp.add_child(cat)
	if hero:
		return   # Steam library hero: art only, no logo
	var logo = Label.new()
	logo.text = "SHMITTENS!"
	var logo_size = int((s.y * 0.26 if not tall else s.x * 0.135) if not logo_only else 200)
	if key.begins_with("small"):
		logo_size = int(s.y * 0.42)
	logo.add_theme_font_size_override("font_size", logo_size)
	logo.add_theme_color_override("font_color", GOLD)
	logo.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.3))
	logo.add_theme_constant_override("outline_size", max(4, logo_size / 7))
	logo.position = Vector2(s.x * 0.05, s.y * (0.06 if not tall else 0.08)) if not logo_only else Vector2(0, 200)
	logo.size = Vector2(s.x * 0.9, 0) if not logo_only else Vector2(s.x, 0)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if not (tall or logo_only) else HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(logo)
	if not key.begins_with("small"):
		var tag = Label.new()
		tag.text = "Draw spells to the beat"
		var tag_size = max(12, int(logo_size * 0.32))
		tag.add_theme_font_size_override("font_size", tag_size)
		tag.add_theme_color_override("font_color", PINK)
		tag.add_theme_color_override("font_outline_color", Color(0.2, 0.12, 0.3))
		tag.add_theme_constant_override("outline_size", max(3, tag_size / 5))
		tag.position = logo.position + Vector2(0, logo_size * 1.15)
		tag.size = logo.size
		tag.horizontal_alignment = logo.horizontal_alignment
		vp.add_child(tag)
