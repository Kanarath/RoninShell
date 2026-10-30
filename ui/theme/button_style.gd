extends RefCounted
## Estilo de botones acorde a la paleta (el tema por defecto de Godot es gris y desentona).

const Palette := preload("res://ui/theme/palette.gd")


static func apply(button: Button, accent: Color = Palette.TEAL) -> void:
	button.add_theme_stylebox_override("normal", _box(Palette.PANEL_DEEP, Palette.TEAL_DIM))
	button.add_theme_stylebox_override("hover", _box(Color(accent, 0.16), accent))
	button.add_theme_stylebox_override("pressed", _box(Color(accent, 0.30), accent))
	button.add_theme_stylebox_override("focus", _box(Color(accent, 0.10), Palette.GOLD, 2))
	button.add_theme_stylebox_override("disabled", _box(Palette.PANEL_DEEP, Color(Palette.TEAL_DIM, 0.4)))
	button.add_theme_color_override("font_color", Palette.TEXT)
	button.add_theme_color_override("font_hover_color", Palette.TEXT_TITLE)
	button.add_theme_color_override("font_pressed_color", Palette.GOLD)
	button.add_theme_color_override("font_focus_color", Palette.TEXT_TITLE)
	button.add_theme_color_override("font_disabled_color", Color(Palette.TEXT_DIM, 0.5))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not button.disabled else Control.CURSOR_ARROW


static func _box(fill: Color, border: Color, border_width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(3)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
