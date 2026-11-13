class_name UIKit
extends RefCounted
## Shared styling helpers for in-game UI.

const UV := Color("8A2BE2")
const GLOW := Color("B66DFF")
const GOLD := Color("F2B84B")
const RED := Color("D7263D")
const TEXT := Color("EDEAF5")
const BG := Color("0B0A14")


static func sb(bg: Color, border: Color, glow := false, bw := 2, radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(18)
	if glow:
		s.shadow_color = Color(GLOW, 0.4)
		s.shadow_size = 12
	return s


static func style_button(b: Button, selected := false) -> void:
	var n := sb(Color(0.06, 0.04, 0.12, 0.92), UV)
	if selected:
		n = sb(Color(0.3, 0.12, 0.55, 0.95), GLOW, true)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", sb(Color(0.16, 0.07, 0.3, 0.95), GLOW, true))
	b.add_theme_stylebox_override("pressed", sb(Color(0.3, 0.12, 0.55, 0.98), GLOW, true))
	b.add_theme_stylebox_override("disabled", sb(Color(0.06, 0.05, 0.1, 0.5), Color(0.3, 0.28, 0.4, 0.5)))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.62))
	b.focus_mode = Control.FOCUS_NONE


static func button(text: String, size := 30, min_size := Vector2(0, 66)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_button(b)
	return b


static func label(text: String, size := 30, color := TEXT, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func panel(alpha := 0.94, border := UV) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(Color(0.045, 0.035, 0.1, alpha), border, true, 2, 14))
	return p
