extends "res://tests/framework/test_case.gd"
## Resumen de campaña (F5): los laboratorios de un vistazo, con el estado y el progreso real de cada uno.

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _main() -> Control:
	var root := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_tree().root.add_child(root)
	return root


func _dispose(root: Control) -> void:
	_tree().root.remove_child(root)
	root.free()


func _key(root: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	root._unhandled_input(event)


func test_f5_abre_y_cierra_el_resumen() -> void:
	var root := _main()
	assert_false(root.campaign_panel.is_open())
	_key(root, KEY_F5)
	assert_true(root.campaign_panel.is_open())
	_key(root, KEY_F5)
	assert_false(root.campaign_panel.is_open())
	_dispose(root)


func test_incluye_todos_los_laboratorios_de_la_campana_en_orden() -> void:
	var root := _main()
	root._refresh_campaign_panel()
	var ids: Array = []
	for row in root.campaign_panel._rows.get_children():
		ids.append(row)
	assert_eq(ids.size(), root.CAMPAIGN.size(), "una fila por laboratorio")
	_dispose(root)


func test_el_primero_esta_disponible_y_activo_y_el_resto_bloqueado() -> void:
	var root := _main()
	root._refresh_campaign_panel()
	var first_row: Control = root.campaign_panel._rows.get_child(0)
	var first_title: Label = first_row.get_child(1).get_child(0)
	assert_true("(activo)" in first_title.text)
	var second_row: Control = root.campaign_panel._rows.get_child(1)
	var second_sub: Label = second_row.get_child(1).get_child(1)
	assert_true("Bloqueado" in second_sub.text)
	_dispose(root)


func test_completar_el_primer_laboratorio_lo_marca_completado_y_desbloquea_el_segundo() -> void:
	var root := _main()
	root.debug_panel.press("Libro completado")
	root._refresh_campaign_panel()
	var first_row: Control = root.campaign_panel._rows.get_child(0)
	var first_sub: Label = first_row.get_child(1).get_child(1)
	assert_true("Completado" in first_sub.text)
	var second_row: Control = root.campaign_panel._rows.get_child(1)
	var second_sub: Label = second_row.get_child(1).get_child(1)
	assert_false("Bloqueado" in second_sub.text)
	_dispose(root)
