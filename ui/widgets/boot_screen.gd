extends Control
## Arranque del cyberdeck: las compuertas se abren, la pantalla se enciende y carga.
## Se dibuja en coordenadas de 320x180 (el arte pxl) y se escala entero para que los píxeles queden nítidos.
## Cualquier tecla o clic lo salta. Sin efectos (ajuste de accesibilidad) se muestra ya abierto y breve.

signal finished
signal sound_requested(sound_name: String)

const Palette := preload("res://ui/theme/palette.gd")
const SpriteStore := preload("res://ui/sprite_store.gd")

const ART := Vector2(320, 180)
const SCREEN := Rect2(46, 22, 228, 114)
const SEGMENTS := 16
const MESSAGES := [
	"CARGANDO MODULOS...",
	"MONTANDO LABORATORIOS...",
	"VERIFICANDO ALCANCE AUTORIZADO...",
	"LISTO",
]
const LED_POSITIONS := [Vector2(190, 163), Vector2(198, 163), Vector2(206, 163)]
const LED_COLORS := [Color("d9583f"), Color("e8a33a"), Color("5ee6cf")]

var vfx := true
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_update_bar()
var is_done := false

var _stage := Control.new()
var _shutter_clip := Control.new()
var _shutter_left := TextureRect.new()
var _shutter_right := TextureRect.new()
var _helmet := TextureRect.new()
var _segments: Array[ColorRect] = []
var _leds: Array[ColorRect] = []
var _vents: Array[ColorRect] = []
var _flicker := ColorRect.new()
var _message := Label.new()
var _hint := Label.new()
var _clock := 0.0
var _tween: Tween = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Palette.BG
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_stage.size = ART
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_add_texture(_stage, "boot_base", Vector2.ZERO, ART)
	for i in 10:
		var vent := ColorRect.new()
		var x := (40 + i * 7) if i < 5 else (246 + (i - 5) * 7)
		vent.position = Vector2(x, 158)
		vent.size = Vector2(4, 14)
		vent.color = Color("232b30")
		vent.color.a = 0.0
		vent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(vent)
		_vents.append(vent)

	_helmet = _add_texture(_stage, "helmet", Vector2(129, 42), Vector2(62, 52))

	for i in SEGMENTS:
		var segment := ColorRect.new()
		segment.position = Vector2(86 + i * 9, 112)
		segment.size = Vector2(7, 8)
		segment.color = Color("123d38")
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(segment)
		_segments.append(segment)

	for i in LED_POSITIONS.size():
		var led := ColorRect.new()
		led.position = LED_POSITIONS[i]
		led.size = Vector2(3, 3)
		led.color = Color("0a1416")
		led.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stage.add_child(led)
		_leds.append(led)

	_flicker.position = SCREEN.position
	_flicker.size = SCREEN.size
	_flicker.color = Color(1, 1, 1, 0)
	_flicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_flicker)

	_shutter_clip.position = SCREEN.position
	_shutter_clip.size = SCREEN.size
	_shutter_clip.clip_contents = true
	_shutter_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_shutter_clip)
	_shutter_left = _add_texture(_shutter_clip, "shutter", Vector2.ZERO, Vector2(114, 114))
	_shutter_right = _add_texture(_shutter_clip, "shutter", Vector2(114, 0), Vector2(114, 114))
	_shutter_right.flip_h = true

	_message.add_theme_color_override("font_color", Palette.TEAL_DIM)
	_message.add_theme_font_size_override("font_size", 13)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message)
	_hint.text = "pulsa una tecla"
	_hint.add_theme_color_override("font_color", Color(Palette.GOLD_DIM, 0.8))
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	resized.connect(_layout)
	set_process(true)
	_set_open(0.0)
	_update_bar()
	_message.text = MESSAGES[0]


func _add_texture(parent: Control, art_name: String, at: Vector2, art_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = SpriteStore.ui_texture(art_name)
	rect.position = at
	rect.size = art_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


## Centra el arte con un escalado entero (si cabe) para que no se desdibujen los píxeles.
func _layout() -> void:
	var fit := minf(size.x / ART.x, size.y / ART.y)
	var factor := floorf(fit) if fit >= 1.0 else fit
	_stage.pivot_offset = ART / 2.0
	_stage.scale = Vector2(factor, factor)
	_stage.position = ((size - ART) / 2.0).floor()   # el escalado se hace desde el centro
	var origin := ((size - ART * factor) / 2.0).floor()   # esquina superior izquierda ya escalada
	_message.size = Vector2(ART.x * factor, 24)
	_message.position = origin + Vector2(0, 124 * factor - 4)
	_hint.size = Vector2(ART.x * factor, 22)
	_hint.position = origin + Vector2(0, 161 * factor - 4)


func play() -> void:
	is_done = false
	visible = true
	_layout()
	if not vfx:
		_set_open(1.0)
		progress = 1.0
		_message.text = MESSAGES[MESSAGES.size() - 1]
		_hint.visible = false
		_tween = create_tween()
		_tween.tween_interval(0.5)
		_tween.tween_callback(finish)
		return
	_tween = create_tween()
	_tween.tween_interval(0.35)
	# Se encienden los LEDs de uno en uno.
	for i in _leds.size():
		_tween.tween_callback(_set_led.bind(i, true))
		_tween.tween_callback(sound_requested.emit.bind("encendido"))
		_tween.tween_interval(0.14)
	_tween.tween_interval(0.2)
	_tween.tween_callback(sound_requested.emit.bind("compuerta"))
	_tween.tween_method(_set_open, 0.0, 1.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.2)
	# La barra avanza a trompicones, como cargando módulos de verdad.
	var stops := [0.18, 0.34, 0.5, 0.72, 0.9, 1.0]
	for i in stops.size():
		_tween.tween_property(self, "progress", stops[i], 0.35 + 0.1 * (i % 2))
		_tween.tween_callback(_say.bind(mini(i / 2, MESSAGES.size() - 2)))
	_tween.tween_callback(_say.bind(MESSAGES.size() - 1))
	_tween.tween_interval(0.55)
	_tween.tween_callback(finish)


## Salta la animación y pasa al menú con un zoom corto.
func finish() -> void:
	if is_done:
		return
	is_done = true
	if _tween != null:
		_tween.kill()
	_hint.visible = false
	if not vfx or not is_inside_tree():
		visible = false
		finished.emit()
		return
	_set_open(1.0)
	progress = 1.0
	var out := create_tween().set_parallel(true)
	out.tween_property(_stage, "scale", _stage.scale * 1.3, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_property(self, "modulate:a", 0.0, 0.4)
	out.chain().tween_callback(_after_zoom)


func _after_zoom() -> void:
	visible = false
	modulate.a = 1.0
	finished.emit()


func _input(event: InputEvent) -> void:
	if not visible or is_done:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed):
		finish()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible or not vfx:
		return
	_clock += delta
	# El casco respira y la pantalla tiene un parpadeo casi imperceptible.
	var breath := 0.5 + 0.5 * sin(_clock * 2.2)
	_helmet.modulate = Color(1, 1, 1).lerp(Color(1.25, 1.2, 1.05), breath * 0.6)
	_flicker.color.a = 0.025 if fmod(_clock, 0.9) < 0.06 else 0.0
	# Ola de luz por las rejillas de ventilación.
	for i in _vents.size():
		var wave := 0.5 + 0.5 * sin(_clock * 3.0 - float(i % 5) * 0.9)
		_vents[i].color.a = 0.55 * (1.0 - wave)


func _set_open(amount: float) -> void:
	var slide := roundf(amount * 114.0)
	_shutter_left.position.x = -slide
	_shutter_right.position.x = 114.0 + slide
	var visible_shutters := amount < 1.0
	_shutter_left.visible = visible_shutters
	_shutter_right.visible = visible_shutters


func _set_led(index: int, on: bool) -> void:
	_leds[index].color = LED_COLORS[index] if on else Color("0a1416")


func _say(index: int) -> void:
	_message.text = MESSAGES[index]


func _update_bar() -> void:
	var lit := int(round(progress * SEGMENTS))
	for i in _segments.size():
		_segments[i].color = Color("5ee6cf") if i < lit else Color("123d38")
