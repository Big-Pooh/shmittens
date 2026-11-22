extends RefCounted

class_name UiTheme

# SPRINT 3: one pastel theme for every menu (it replaces Godot's default grey look).
# v0.12 playtest ("not pastel enough, I want pink"): bubblegum-pink buttons with a white-cream
# glow on hover, berry panels with pink borders, mint sliders.
# Applied to the root window by Game, so every scene picks it up automatically.

const INK = Color(0.36, 0.12, 0.30)
const LILAC = Color(0.93, 0.50, 0.72)       # bubblegum pink (name kept for callers)
const LILAC_HI = Color(1.0, 0.66, 0.84)
const PLUM = Color(0.26, 0.09, 0.22, 0.96)  # berry
const GOLD = Color(1, 0.82, 0.35)
const PINK_LIGHT = Color(1, 0.78, 0.9)
const CREAM = Color(1, 0.96, 0.88)
const BG = Color(0.12, 0.04, 0.12)          # full-screen menu background (deep raspberry)
const MINT = Color(0.55, 0.95, 0.82)
const TEXT = Color(1, 0.96, 1)


static func box(bg: Color, border: Color, width: int = 2, radius: int = 12, pad: int = 10) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 3
	return s


static func make() -> Theme:
	var t = Theme.new()
	t.default_font_size = 18
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, box(LILAC, INK))
		t.set_stylebox("hover", cls, box(LILAC_HI, CREAM, 3))
		t.set_stylebox("pressed", cls, box(INK, PINK_LIGHT, 3))
		t.set_stylebox("focus", cls, box(Color(0, 0, 0, 0), CREAM, 3))
		t.set_stylebox("disabled", cls, box(Color(0.42, 0.3, 0.4), INK))
		# dark berry text on pink reads far better than white (v0.12 screenshot check)
		t.set_color("font_color", cls, Color(0.28, 0.06, 0.22))
		t.set_color("font_hover_color", cls, Color(0.2, 0.03, 0.16))
		t.set_color("font_pressed_color", cls, PINK_LIGHT)
		t.set_color("font_focus_color", cls, Color(0.28, 0.06, 0.22))
		t.set_color("font_disabled_color", cls, Color(0.78, 0.66, 0.74))
		t.set_constant("outline_size", cls, 0)
	t.set_stylebox("panel", "PanelContainer", box(PLUM, LILAC, 3, 16, 16))
	t.set_stylebox("panel", "Panel", box(PLUM, LILAC, 3, 16, 16))
	t.set_stylebox("slider", "HSlider", box(INK, LILAC, 2, 6, 2))
	t.set_stylebox("grabber_area", "HSlider", box(MINT, MINT, 0, 6, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, GOLD, 0, 6, 2))
	t.set_stylebox("background", "ProgressBar", box(Color(0.1, 0.08, 0.16), INK, 2, 6, 0))
	t.set_stylebox("panel", "PopupMenu", box(PLUM, LILAC, 2, 10, 6))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_stylebox("hover", "PopupMenu", box(LILAC_HI, GOLD, 0, 6, 2))
	return t
