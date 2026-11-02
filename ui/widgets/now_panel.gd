extends "res://ui/widgets/modal.gd"
## "¿Qué hago ahora?" (F4): dónde estás y el siguiente paso pequeño, sin gastar pistas.

var lines_shown := 0
var _body := VBoxContainer.new()


func _init() -> void:
	super("¿Qué hago ahora?", Vector2(640, 300))
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_body)
	content.add_child(_label("F4 o Esc para cerrar.", Palette.TEXT_DIM, 12))


## Muestra un resumen de NowAdvice.build().
func show_advice(advice: Dictionary) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var lines: Array = advice["lines"]
	for i in lines.size():
		var color := Palette.GOLD if i == 0 else Palette.TEXT
		var label := _label(str(lines[i]), color, 15 if i == 0 else 14)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(580, 0)
		_body.add_child(label)
	frame.title = str(advice["title"])
	frame.queue_redraw()
	lines_shown = lines.size()
