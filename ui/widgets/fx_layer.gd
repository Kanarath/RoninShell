extends Control
## Capa de efectos sobre la interfaz: ondas al hacer clic y ráfagas de chispas (al completar objetivos).
## No intercepta el ratón. Con enabled = false no hace nada (ajuste de efectos).

const Palette := preload("res://ui/theme/palette.gd")

const RIPPLE_TIME := 0.45

var enabled := true
var _ripples: Array = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func _input(event: InputEvent) -> void:
	if enabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		ripple(event.position)


## Un aro teal que se expande desde el punto del clic.
func ripple(at: Vector2) -> void:
	if not enabled:
		return
	_ripples.append({"at": at, "age": 0.0})
	set_process(true)


## Ráfaga de chispas cuadradas (pixel) que saltan hacia arriba y caen con la gravedad.
func burst(at: Vector2, color: Color, amount := 28) -> void:
	if not enabled or not is_inside_tree():
		return
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.amount = amount
	particles.lifetime = 0.9
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = Vector2(0, -1)
	particles.spread = 110.0
	particles.gravity = Vector2(0, 360)
	particles.initial_velocity_min = 110.0
	particles.initial_velocity_max = 260.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5
	var fade := Gradient.new()
	fade.set_color(0, color)
	fade.set_color(1, Color(color, 0.0))
	particles.color_ramp = fade
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	add_child(particles)


## Cartel dorado que sube y se desvanece (subida de nivel). No bloquea nada.
func banner(text: String, color: Color = Palette.GOLD) -> void:
	if not enabled or not is_inside_tree():
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.BG)
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.size = Vector2(500, 64)
	label.position = Vector2(size.x / 2.0 - 250.0, size.y * 0.30)
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(0.6, 0.6)
	label.modulate.a = 0.0
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.25)
	tween.chain().tween_interval(0.9)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_property(label, "position:y", label.position.y - 30.0, 0.5)
	tween.chain().tween_callback(label.queue_free)


func _process(delta: float) -> void:
	for ripple_data: Dictionary in _ripples:
		ripple_data["age"] += delta
	_ripples = _ripples.filter(func(r: Dictionary) -> bool: return r["age"] < RIPPLE_TIME)
	queue_redraw()
	if _ripples.is_empty():
		set_process(false)


func _draw() -> void:
	for ripple_data: Dictionary in _ripples:
		var t: float = ripple_data["age"] / RIPPLE_TIME
		var radius := 4.0 + 26.0 * (1.0 - pow(1.0 - t, 3.0))
		draw_arc(ripple_data["at"], radius, 0.0, TAU, 28, Color(Palette.TEAL, 0.85 * (1.0 - t)), 2.0)
