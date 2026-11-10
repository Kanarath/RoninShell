extends "res://tests/framework/test_case.gd"
## "Ampliar" el panel de la terminal: oculta la columna lateral (objetivos/mapa/expediente) para
## que la terminal ocupe todo el ancho. A diferencia de los otros paneles, no abre ninguna ventana:
## sigue siendo la misma terminal, con el mismo foco de escritura.

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _main() -> Control:
	var root := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_tree().root.add_child(root)
	return root


func _dispose(root: Control) -> void:
	_tree().root.remove_child(root)
	root.free()


func test_ampliar_oculta_la_columna_lateral_y_el_contenido_sigue_siendo_el_mismo() -> void:
	var root := _main()
	assert_true(root._side_column.visible)
	assert_false(root._terminal_focused)
	root._toggle_terminal_focus()
	assert_true(root._terminal_focused)
	assert_false(root._side_column.visible)
	assert_true(root.terminal.get_parent() != null, "la terminal no se mueve: se queda donde estaba")
	root._toggle_terminal_focus()
	assert_false(root._terminal_focused)
	assert_true(root._side_column.visible)
	_dispose(root)


func test_esc_devuelve_la_columna_lateral() -> void:
	var root := _main()
	root._toggle_terminal_focus()
	assert_true(root._terminal_focused)
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root._input(event)
	assert_false(root._terminal_focused)
	assert_true(root._side_column.visible)
	_dispose(root)


func test_esc_prioriza_cerrar_una_ventana_antes_que_salir_del_foco_de_terminal() -> void:
	var root := _main()
	root._toggle_terminal_focus()
	root.cheatsheet_panel.open()
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root._input(event)
	assert_false(root.cheatsheet_panel.is_open())
	assert_true(root._terminal_focused, "el primer Esc cierra la ventana; el foco de terminal se mantiene")
	_dispose(root)


func test_escribir_en_la_terminal_funciona_igual_ampliada() -> void:
	var root := _main()
	root._toggle_terminal_focus()
	root.terminal.submit("echo hola")
	assert_true("hola" in root.terminal.output_text())
	_dispose(root)
