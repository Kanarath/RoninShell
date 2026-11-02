extends MarginContainer
## Placa del cyberdeck: metal oscuro con borde dorado, tornillos y un LED que respira junto al título.
## Los hijos se añaden a "content" (debajo del título). Con expandable = true aparece un botón para
## ampliar el panel (la ventana la gestiona quien escucha expand_requested).

signal expand_requested

const Palette := preload("res://ui/theme/palette.gd")

const CUT := 7.0          # chaflán de las esquinas
const SCREW_INSET := 10.0
const REDRAW_EVERY := 0.07

## Efectos animados (LED, brillo interior). Se apaga desde Ajustes junto al resto de efectos.
static var animate := true

var title: String = "":
	set(value):
		title = value
		if _title_label != null:
			_title_label.text = value.to_upper()
var expandable := false:
	set(value):
		expandable = value
		_expand_button.visible = value

var content := VBoxContainer.new()
## Opacidad del relleno. Los paneles de la pantalla principal son algo translúcidos (se intuye el
## kanji de fondo); las ventanas modales usan 1.0 para que nada se cuele por detrás del texto.
var fill_alpha := 0.9
var column := VBoxContainer.new()
var _title_label := Label.new()
var _expand_button := ExpandButton.new()
var _phase := 0.0
var _since_draw := 0.0


## Botón con dos flechas en diagonal (ampliar). Se dibuja a mano para no depender de la fuente.
class ExpandButton extends Button:
	const P := preload("res://ui/theme/palette.gd")

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(28, 22)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "Ampliar"
		visible = false
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var color: Color = P.GOLD if is_hovered() else P.GOLD_DIM
		var c := size / 2.0
		var a := 7.0
		var t := 4.0
		draw_polyline(PackedVector2Array([c + Vector2(a - t, -a), c + Vector2(a, -a), c + Vector2(a, -a + t)]), color, 2.0)
		draw_polyline(PackedVector2Array([c + Vector2(-a + t, a), c + Vector2(-a, a), c + Vector2(-a, a - t)]), color, 2.0)
		draw_line(c + Vector2(-a + 2, a - 2), c + Vector2(a - 2, -a + 2), Color(color, 0.7), 1.5)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("margin_left", 22)
	add_theme_constant_override("margin_right", 22)
	add_theme_constant_override("margin_top", 13)
	add_theme_constant_override("margin_bottom", 13)

	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	column.add_child(head)
	var led_space := Control.new()
	led_space.custom_minimum_size = Vector2(16, 0)
	head.add_child(led_space)
	_title_label.add_theme_color_override("font_color", Palette.TEXT_TITLE)
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title_label)
	_expand_button.pressed.connect(func() -> void: expand_requested.emit())
	head.add_child(_expand_button)

	var rule := ColorRect.new()
	rule.color = Color(Palette.GOLD_DIM, 0.6)
	rule.custom_minimum_size = Vector2(0, 1)
	column.add_child(rule)

	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	column.add_child(content)


func _gui_input(event: InputEvent) -> void:
	# Un clic en la cabecera también amplía (además del botón).
	if expandable and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.position.y < 40.0:
		expand_requested.emit()


func _process(delta: float) -> void:
	if not animate or not is_visible_in_tree():
		return
	_phase += delta
	_since_draw += delta
	if _since_draw >= REDRAW_EVERY:
		_since_draw = 0.0
		queue_redraw()


func _plate(inset: float) -> PackedVector2Array:
	var s := size
	var c := CUT
	var i := inset
	return PackedVector2Array([
		Vector2(c + i, i), Vector2(s.x - c - i, i), Vector2(s.x - i, c + i), Vector2(s.x - i, s.y - c - i),
		Vector2(s.x - c - i, s.y - i), Vector2(c + i, s.y - i), Vector2(i, s.y - c - i), Vector2(i, c + i),
	])


func _draw() -> void:
	var s := size
	var outline := _plate(1.0)
	var breath := 0.5 + 0.5 * sin(_phase * 1.6) if animate else 0.5

	draw_colored_polygon(outline, Color(Palette.PANEL, fill_alpha))
	# Bisel superior: una línea clara bajo el borde, como el canto de una placa de metal.
	draw_line(Vector2(CUT + 3, 4.5), Vector2(s.x - CUT - 3, 4.5), Color(Palette.STEEL, 0.28), 1.0)
	# Borde: oro oscuro por fuera, oro vivo por dentro.
	draw_polyline(outline + PackedVector2Array([outline[0]]), Palette.GOLD_DIM, 3.0, true)
	var inner := _plate(3.0)
	draw_polyline(inner + PackedVector2Array([inner[0]]), Color(Palette.GOLD, 0.85), 1.0, true)
	# Resplandor teal que respira por dentro.
	var glow := _plate(6.0)
	draw_polyline(glow + PackedVector2Array([glow[0]]), Color(Palette.TEAL_DIM, 0.18 + 0.22 * breath), 1.0, true)

	# Tornillos en las cuatro esquinas, cada uno con la ranura en un ángulo distinto.
	var spots := [Vector2(SCREW_INSET, SCREW_INSET), Vector2(s.x - SCREW_INSET, SCREW_INSET),
		Vector2(SCREW_INSET, s.y - SCREW_INSET), Vector2(s.x - SCREW_INSET, s.y - SCREW_INSET)]
	for i in spots.size():
		_screw(spots[i], 0.5 + i * 0.9)

	# LED del título.
	var led := Vector2(24, 24)
	draw_circle(led, 5.0, Color(Palette.TEAL, 0.10 + 0.18 * breath))
	draw_circle(led, 2.6, Palette.TEAL.lerp(Color.WHITE, 0.25 * breath))


func _screw(at: Vector2, angle: float) -> void:
	draw_circle(at, 3.6, Palette.METAL_DARK)
	draw_circle(at, 3.0, Palette.RIVET)
	var d := Vector2.from_angle(angle) * 2.3
	draw_line(at - d, at + d, Palette.METAL_DARK, 1.2)
