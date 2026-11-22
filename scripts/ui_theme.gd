extends RefCounted

class_name UiTheme

# SPRINT 3: one pastel theme for every menu (it replaces Godot's default grey look).
# Rounded lilac buttons with a gold glow on hover/focus, plum panels, mint sliders and toggles.
# Applied to the root window by Game, so every scene picks it up automatically.

const INK = Color(0.20, 0.13, 0.30)
const LILAC = Color(0.42, 0.33, 0.62)
const LILAC_HI = Color(0.55, 0.44, 0.78)
const PLUM = Color(0.13, 0.09, 0.22, 0.96)
const GOLD = Color(1, 0.82, 0.35)
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
		t.set_stylebox("hover", cls, box(LILAC_HI, GOLD, 3))
		t.set_stylebox("pressed", cls, box(INK, GOLD, 3))
		t.set_stylebox("focus", cls, box(Color(0, 0, 0, 0), GOLD, 3))
		t.set_stylebox("disabled", cls, box(Color(0.3, 0.28, 0.36), INK))
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, GOLD)
		t.set_color("font_pressed_color", cls, GOLD)
		t.set_color("font_focus_color", cls, TEXT)
		t.set_color("font_outline_color", cls, INK)
		t.set_constant("outline_size", cls, 4)
	t.set_stylebox("panel", "PanelContainer", box(PLUM, GOLD, 3, 16, 16))
	t.set_stylebox("panel", "Panel", box(PLUM, GOLD, 3, 16, 16))
	t.set_stylebox("slider", "HSlider", box(INK, LILAC, 2, 6, 2))
	t.set_stylebox("grabber_area", "HSlider", box(MINT, MINT, 0, 6, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, GOLD, 0, 6, 2))
	t.set_stylebox("background", "ProgressBar", box(Color(0.1, 0.08, 0.16), INK, 2, 6, 0))
	t.set_stylebox("panel", "PopupMenu", box(PLUM, GOLD, 2, 10, 6))
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_stylebox("hover", "PopupMenu", box(LILAC_HI, GOLD, 0, 6, 2))
	return t
