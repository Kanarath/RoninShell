extends "res://ui/widgets/modal.gd"
## Panel de pruebas (F11): botones para saltar directo a un laboratorio, una misión, un modo o un
## repaso, sin tener que jugar todo lo anterior. Solo para probar: no es parte de la experiencia.
##
## Emite "action(nombre, datos)"; la pantalla principal decide qué hacer con cada una.

signal action(action_name: String, data: Dictionary)

const ButtonStyle := preload("res://ui/theme/button_style.gd")

var _body := VBoxContainer.new()


func _init() -> void:
	super("Modo pruebas", Vector2(880, 560))
	frame.title = "Modo pruebas  ·  solo para probar"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
	content.add_child(_label("F11 o Esc para cerrar. Saltar a una misión deja las anteriores como completadas (sin XP).", Palette.TEXT_DIM, 12))


## Construye los botones. campaign = [{id, title, missions: [títulos]}]; review_concepts = [conceptos].
func setup(campaign: Array, review_concepts: Array) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

	for book: Dictionary in campaign:
		_section("%s  ·  ir a una misión" % book["title"])
		var grid := _grid()
		var index := 0
		for title: String in book["missions"]:
			_button(grid, "Misión %d: %s" % [index + 1, title], "jump_mission", {"book": book["id"], "index": index})
			index += 1
		_button(grid, "Libro completado", "jump_mission", {"book": book["id"], "index": book["missions"].size()}, Palette.GOLD)

	_section("Modos y repasos")
	var modes := _grid()
	_button(modes, "Modo libre", "mode_free")
	_button(modes, "Modo misión", "mode_mision")
	_button(modes, "Salir del repaso", "review_exit")
	var reviews := _grid()
	for concept: String in review_concepts:
		_button(reviews, "Repaso: %s" % concept.replace("_", " "), "review", {"concept": concept})

	_section("Ventanas")
	var windows := _grid()
	_button(windows, "Chuleta (F1)", "open_cheatsheet")
	_button(windows, "Ajustes (F10)", "open_settings")
	_button(windows, "Menú inicial (F9)", "open_menu")

	_section("Estado y ayudas")
	var tools := _grid()
	_button(tools, "Dar 300 XP", "give_xp")
	_button(tools, "Marcar todos los repasos como atrasados", "overdue_reviews")
	_button(tools, "Reiniciar este laboratorio", "reset_lab")
	_button(tools, "Borrar todo el progreso", "delete_progress", {}, Palette.DANGER)


func _section(text: String) -> void:
	var heading := _label(text.to_upper(), Palette.GOLD, 13)
	heading.add_theme_constant_override("line_spacing", 0)
	_body.add_child(heading)


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_body.add_child(grid)
	return grid


func _button(parent: Control, text: String, action_name: String, data := {}, accent: Color = Palette.TEAL) -> void:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.clip_text = true
	ButtonStyle.apply(button, accent)
	button.pressed.connect(func() -> void: action.emit(action_name, data))
	parent.add_child(button)


## Botones creados, para los tests: [{text, action, data}] no se guarda; se consulta el árbol.
func button_texts() -> Array[String]:
	var texts: Array[String] = []
	_collect(_body, texts)
	return texts


func press(button_text: String) -> bool:
	return _press_in(_body, button_text)


func _collect(node: Node, into: Array[String]) -> void:
	for child in node.get_children():
		if child is Button:
			into.append(child.text)
		_collect(child, into)


func _press_in(node: Node, button_text: String) -> bool:
	for child in node.get_children():
		if child is Button and child.text == button_text:
			child.pressed.emit()
			return true
		if _press_in(child, button_text):
			return true
	return false
