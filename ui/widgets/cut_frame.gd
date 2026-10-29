extends MarginContainer
## Marco de panel con esquinas cortadas "a katana" y remates dorados.
## Los hijos se añaden a "content" (debajo del título).

const Palette := preload("res://ui/theme/palette.gd")

const CUT := 14.0         # tamaño del corte diagonal
const BRACKET := 22.0     # largo de los remates dorados

var title: String = "":
	set(value):
		title = value
		if _title_label != null:
			_title_label.text = value.to_upper()

var content := VBoxContainer.new()
var _title_label := Label.new()


func _init() -> void:
	add_theme_constant_override("margin_left", 18)
	add_theme_constant_override("margin_right", 18)
	add_theme_constant_override("margin_top", 12)
	add_theme_constant_override("margin_bottom", 14)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	_title_label.add_theme_color_override("font_color", Palette.TEXT_TITLE)
	_title_label.add_theme_font_size_override("font_size", 15)
	column.add_child(_title_label)

	var rule := ColorRect.new()
	rule.color = Palette.TEAL_DIM
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)

	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	column.add_child(content)


func _draw() -> void:
	var s := size
	var outline := PackedVector2Array([
		Vector2(CUT, 0), Vector2(s.x, 0), Vector2(s.x, s.y - CUT),
		Vector2(s.x - CUT, s.y), Vector2(0, s.y), Vector2(0, CUT),
	])
	# Algo translúcido para que el kanji de fondo se intuya detrás sin molestar a la lectura.
	draw_colored_polygon(outline, Color(Palette.PANEL, 0.82))
	draw_polyline(outline + PackedVector2Array([outline[0]]), Palette.TEAL_BORDER, 1.5, true)

	# Cortes diagonales y remates en oro: la "firma" visual de los marcos.
	draw_line(Vector2(0, CUT), Vector2(CUT, 0), Palette.GOLD, 3.0, true)
	draw_line(Vector2(s.x - CUT, s.y), Vector2(s.x, s.y - CUT), Palette.GOLD, 3.0, true)
	draw_polyline(PackedVector2Array([Vector2(s.x - BRACKET, 0), Vector2(s.x, 0), Vector2(s.x, BRACKET)]), Palette.GOLD, 3.0)
	draw_polyline(PackedVector2Array([Vector2(0, s.y - BRACKET), Vector2(0, s.y), Vector2(BRACKET, s.y)]), Palette.GOLD, 3.0)
