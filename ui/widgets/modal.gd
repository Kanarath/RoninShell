extends Control
## Ventana modal sobre la pantalla principal: fondo oscurecido y un marco con título.
## Se abre y se cierra con open()/close() (F1/F10 o Esc desde la pantalla principal).

signal opened
signal closed

const Palette := preload("res://ui/theme/palette.gd")
const CutFrame := preload("res://ui/widgets/cut_frame.gd")

var frame := CutFrame.new()
var content: VBoxContainer


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
	center.add_child(frame)
	content = frame.content


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func toggle() -> void:
	close() if visible else open()


func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label
