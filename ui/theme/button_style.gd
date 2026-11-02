extends RefCounted
## Estilo de botones: teclas de metal con el borde del color de acento (el tema por defecto de Godot es gris y desentona).
## El borde inferior más grueso hace de "canto" de la tecla; al pulsar se invierte, como si se hundiera.

const Palette := preload("res://ui/theme/palette.gd")


static func apply(button: Button, accent: Color = Palette.TEAL) -> void:
	var edge := Palette.GOLD_DIM if accent == Palette.TEAL else Color(accent, 0.7)
	button.add_theme_stylebox_override("normal", _key(Palette.METAL, edge))
	button.add_theme_stylebox_override("hover", _key(Color(accent, 0.16).blend(Palette.METAL_LIGHT), accent, true))
	button.add_theme_stylebox_override("pressed", _key(Color(accent, 0.30).blend(Palette.METAL_DARK), accent, false, true))
	button.add_theme_stylebox_override("focus", _key(Color(accent, 0.10).blend(Palette.METAL), Palette.GOLD))
	button.add_theme_stylebox_override("disabled", _key(Palette.METAL_DARK, Color(Palette.GOLD_DIM, 0.35)))
	button.add_theme_color_override("font_color", Palette.TEXT)
	button.add_theme_color_override("font_hover_color", Palette.TEXT_TITLE)
	button.add_theme_color_override("font_pressed_color", Palette.GOLD)
	button.add_theme_color_override("font_focus_color", Palette.TEXT_TITLE)
	button.add_theme_color_override("font_disabled_color", Color(Palette.TEXT_DIM, 0.5))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not button.disabled else Control.CURSOR_ARROW


static func _key(fill: Color, border: Color, glow := false, pushed := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.border_width_bottom = 2 if pushed else 4
	box.border_width_top = 4 if pushed else 2
	box.set_corner_radius_all(3)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	if glow:
		box.shadow_color = Color(border, 0.35)
		box.shadow_size = 7
	return box
