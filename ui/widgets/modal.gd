extends Control
## Ventana modal sobre la pantalla principal: fondo oscurecido y un marco con título.
## Se abre y se cierra con open()/close() (F1/F10 o Esc desde la pantalla principal).
## Al abrirse hace un zoom corto desde el centro (si los efectos están activos).

signal opened
signal closed

const Palette := preload("res://ui/theme/palette.gd")
const CutFrame := preload("res://ui/widgets/cut_frame.gd")

const ZOOM_FROM := 0.9
const ZOOM_TIME := 0.22

var frame := CutFrame.new()
var content: VBoxContainer
var _tween: Tween = null


func _init(modal_title := "", min_size := Vector2(640, 420)) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.02, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	frame.title = modal_title
	frame.fill_alpha = 1.0
	frame.custom_minimum_size = min_size
	frame.resized.connect(func() -> void: frame.pivot_offset = frame.size / 2.0)
	center.add_child(frame)
	content = frame.content


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	_zoom_in()
	opened.emit()


func close() -> void:
	if not visible:
		return
	_stop_zoom()
	visible = false
	closed.emit()


func toggle() -> void:
	close() if visible else open()


## Zoom suave desde el centro: crece de 90 % a 100 % mientras aparece.
func _zoom_in() -> void:
	_stop_zoom()
	if not CutFrame.animate or not is_inside_tree():
		return
	frame.pivot_offset = frame.size / 2.0
	frame.scale = Vector2(ZOOM_FROM, ZOOM_FROM)
	modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(frame, "scale", Vector2.ONE, ZOOM_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, ZOOM_TIME * 0.8)


func _stop_zoom() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	frame.scale = Vector2.ONE
	modulate.a = 1.0


func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label
