extends Control
## Carcasa del cyberdeck alrededor de toda la ventana: marco de metal con remaches, esquinas doradas
## y una franja inferior con rejillas, interruptores y LEDs. Los LEDs reaccionan a lo que haces
## (blink_led) y las rejillas respiran con una ola de luz teal. Con efectos apagados queda estática.

const Palette := preload("res://ui/theme/palette.gd")

## Margen que la carcasa reserva al contenido (izquierda, arriba, derecha, abajo).
const INSET := Vector4(26, 14, 26, 38)

static var animate := true

var _clock := 0.0
var _since_draw := 0.0
var _leds := [0.0, 0.0, 0.0]   # brillo extra de cada LED, que decae solo
const LED_COLORS := [Color("d9583f"), Color("e8a33a"), Color("5ee6cf")]


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Enciende un LED un momento (0 rojo = error, 1 ámbar = aviso, 2 teal = acierto).
func blink_led(index: int) -> void:
	if index >= 0 and index < _leds.size():
		_leds[index] = 1.0
		queue_redraw()


func _process(delta: float) -> void:
	if not animate or not is_visible_in_tree():
		return
	_clock += delta
	for i in _leds.size():
		_leds[i] = maxf(0.0, _leds[i] - delta * 1.4)
	_since_draw += delta
	if _since_draw >= 0.07:
		_since_draw = 0.0
		queue_redraw()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Palette.BG)
	_body(s)
	_corners(s)
	_strip(s)


## Placa de metal que enmarca el contenido: borde claro arriba-izquierda, oscuro abajo-derecha.
func _body(s: Vector2) -> void:
	var plate := Rect2(5, 5, s.x - 10, s.y - 10)
	draw_rect(plate, Palette.METAL, false, 4.0)
	draw_rect(Rect2(plate.position + Vector2(2, 2), plate.size - Vector2(4, 4)), Color(Palette.GOLD_DIM, 0.55), false, 1.0)
	draw_line(plate.position, Vector2(plate.end.x, plate.position.y), Color(Palette.STEEL, 0.5), 1.0)
	draw_line(plate.position, Vector2(plate.position.x, plate.end.y), Color(Palette.STEEL, 0.35), 1.0)
	# Remaches a lo largo de los lados, cada 56 px.
	var x := 40.0
	while x < s.x - 40.0:
		_rivet(Vector2(x, 9))
		x += 56.0
	var y := 40.0
	while y < s.y - 50.0:
		_rivet(Vector2(9, y))
		_rivet(Vector2(s.x - 9, y))
		y += 56.0


func _corners(s: Vector2) -> void:
	var arm := 34.0
	var thick := 7.0
	for corner in [[Vector2(0, 0), 1, 1], [Vector2(s.x, 0), -1, 1], [Vector2(0, s.y), 1, -1], [Vector2(s.x, s.y), -1, -1]]:
		var o: Vector2 = corner[0]
		var dx: float = corner[1]
		var dy: float = corner[2]
		draw_colored_polygon(PackedVector2Array([o, o + Vector2(dx * arm, 0), o + Vector2(dx * arm, dy * thick),
			o + Vector2(dx * thick, dy * thick), o + Vector2(dx * thick, dy * arm), o + Vector2(0, dy * arm)]), Palette.GOLD)
		draw_line(o + Vector2(dx * 2, dy * 2), o + Vector2(dx * (arm - 2), dy * 2), Color(Palette.TEXT_TITLE, 0.8), 1.0)
		draw_line(o + Vector2(dx * thick, dy * thick), o + Vector2(dx * thick, dy * (arm - 2)), Palette.GOLD_DIM, 1.0)
		_screw(o + Vector2(dx * 11, dy * 11))


## Franja de mandos de abajo: rejillas con ola de luz, interruptores, tres LEDs y un mando dorado.
func _strip(s: Vector2) -> void:
	var top := s.y - 36.0
	draw_rect(Rect2(14, top, s.x - 28, 24), Palette.METAL_DARK)
	draw_line(Vector2(14, top), Vector2(s.x - 14, top), Color(Palette.STEEL, 0.4), 1.0)
	for side in 2:
		for i in 7:
			var x := (48.0 + i * 11.0) if side == 0 else (s.x - 48.0 - 6.0 - i * 11.0)
			var wave := 0.5 + 0.5 * sin(_clock * 3.0 - i * 0.8) if animate else 0.6
			draw_rect(Rect2(x, top + 5, 6, 14), Color(Palette.TEAL_DIM, 0.35 + 0.5 * wave))
	# Interruptores decorativos en el centro-izquierda.
	for i in 3:
		var sx := s.x / 2.0 - 70.0 + i * 22.0
		draw_rect(Rect2(sx, top + 5, 10, 14), Palette.METAL_LIGHT)
		draw_rect(Rect2(sx + 2, top + 6 + (0 if i != 1 else 6), 6, 6), Palette.STEEL)
	# LEDs de estado (reaccionan a los comandos).
	for i in LED_COLORS.size():
		var at := Vector2(s.x / 2.0 + 40.0 + i * 20.0, top + 12)
		var base: Color = LED_COLORS[i]
		var glow: float = _leds[i]
		draw_circle(at, 4.5, Color(base, 0.10 + 0.5 * glow))
		draw_circle(at, 3.0, Color(base, 0.25).lerp(base, minf(1.0, 0.18 + glow)))
	# Mando dorado.
	var knob := Vector2(s.x / 2.0 + 130.0, top + 12)
	draw_circle(knob, 8.0, Palette.METAL_LIGHT)
	draw_circle(knob, 6.0, Palette.GOLD_DIM)
	draw_circle(knob, 4.5, Palette.GOLD)
	draw_line(knob, knob + Vector2(0, -6), Palette.TEXT_TITLE, 1.5)


func _rivet(at: Vector2) -> void:
	draw_circle(at, 2.2, Palette.METAL_DARK)
	draw_circle(at, 1.6, Color(Palette.STEEL, 0.8))


func _screw(at: Vector2) -> void:
	draw_circle(at, 4.0, Palette.METAL_DARK)
	draw_circle(at, 3.3, Palette.RIVET)
	draw_line(at + Vector2(-2.2, 1.2), at + Vector2(2.2, -1.2), Palette.METAL_DARK, 1.2)
