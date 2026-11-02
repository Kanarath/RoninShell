extends Control
## Vista ampliada de un panel (objetivos, mapa o expediente): el panel "salta" desde su sitio hasta ocupar
## buena parte de la pantalla con un zoom, y vuelve al cerrarse. No copia nada: mueve el contenido real
## del panel a la ventana grande, así que sigue vivo (se actualiza mientras está ampliado).

signal opened
signal closed

const Palette := preload("res://ui/theme/palette.gd")
const CutFrame := preload("res://ui/widgets/cut_frame.gd")

const SHARE := Vector2(0.78, 0.8)   # parte de la pantalla que ocupa ampliado
const TIME := 0.3

var frame := CutFrame.new()
var _dim := ColorRect.new()
var _source: Control = null
var _content: Control = null
var _open := false
var _tween: Tween = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_dim.color = Color(0.0, 0.02, 0.02, 0.86)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	frame.fill_alpha = 1.0
	frame.column.remove_child(frame.content)   # el contenido real llega del panel de origen
	frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(frame)


func is_open() -> bool:
	return _open


## Amplía el panel dado (un CutFrame). Si ya hay uno ampliado, no hace nada.
func open_from(source: Control) -> void:
	if _open:
		return
	_finish_close()
	_open = true
	_source = source
	_content = source.content
	source.column.remove_child(_content)
	frame.column.add_child(_content)
	frame.title = source.title
	visible = true
	opened.emit()

	var from := source.get_global_rect()
	var to := _target_rect()
	if not CutFrame.animate or not is_inside_tree():
		_place(to, 1.0)
		return
	_place(from, 0.0)
	_animate(to, 1.0)


func open() -> void:
	pass   # solo se abre desde un panel (open_from)


func close() -> void:
	if not _open:
		return
	_open = false
	if not CutFrame.animate or not is_inside_tree():
		_finish_close()
		return
	_animate(_source.get_global_rect(), 0.0, _finish_close)


func toggle() -> void:
	close()


func _target_rect() -> Rect2:
	var size_px := (size * SHARE).floor()
	return Rect2(((size - size_px) / 2.0).floor(), size_px)


func _place(rect: Rect2, dim_alpha: float) -> void:
	frame.position = rect.position
	frame.size = rect.size
	_dim.modulate.a = dim_alpha


func _animate(rect: Rect2, dim_alpha: float, then := Callable()) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(frame, "position", rect.position, TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(frame, "size", rect.size, TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_dim, "modulate:a", dim_alpha, TIME)
	if then.is_valid():
		_tween.chain().tween_callback(then)


## Devuelve el contenido a su panel y esconde la ventana.
func _finish_close() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if _content != null and _source != null:
		frame.column.remove_child(_content)
		_source.column.add_child(_content)
	_content = null
	_source = null
	if visible:
		visible = false
		closed.emit()
	_open = false


func _gui_input(event: InputEvent) -> void:
	# Un clic fuera de la ventana ampliada la cierra.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not frame.get_rect().has_point(event.position):
			close()
