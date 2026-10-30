extends "res://tests/framework/test_case.gd"
## Comando nano y ventana del editor: abrir, guardar con permisos y avisar de cambios sin guardar.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const LabController := preload("res://engine/lab_controller.gd")
const EditorPanel := preload("res://ui/widgets/editor_panel.gd")


func _game() -> Dictionary:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	var controller := LabController.new()
	var session := ShellSession.new(world, CommandSet.create_registry(null, controller))
	return {"session": session, "controller": controller}


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_nano_pide_un_archivo_y_rechaza_directorios_y_rutas_malas() -> void:
	var s: RefCounted = _game()["session"]
	assert_true("falta el nombre" in s.run("nano").stderr)
	assert_true("Is a directory" in s.run("nano informe").stderr)
	assert_true("No such file" in s.run("nano no_existe/x.txt").stderr)
	assert_true("solo se puede editar un archivo" in s.run("nano a b").stderr)


func test_nano_respeta_permisos_al_abrir() -> void:
	var s: RefCounted = _game()["session"]
	assert_true("Permission denied" in s.run("nano /etc/shadow").stderr, "sin lectura no se abre")
	assert_true("Permission denied" in s.run("nano /etc/nuevo.txt").stderr, "sin escritura en el directorio no se crea")


func test_nano_pide_a_la_interfaz_abrir_el_editor() -> void:
	var game := _game()
	var s: RefCounted = game["session"]
	var result = s.run("nano informe/borrador.md")
	assert_eq(result.exit_code, 0)
	var requests: Array = game["controller"].take_requests()
	assert_eq(requests.size(), 1)
	assert_eq(requests[0]["type"], "edit")
	assert_true(str(requests[0]["path"]).ends_with("informe/borrador.md"))


func _open_panel(s: RefCounted, path: String) -> Control:
	var panel := EditorPanel.new()
	_tree().root.add_child(panel)
	panel.open_file(s, path, path)
	return panel


func _dispose(panel: Control) -> void:
	_tree().root.remove_child(panel)
	panel.free()


func test_guardar_escribe_en_el_laboratorio_y_registra_el_evento() -> void:
	var s: RefCounted = _game()["session"]
	var path: String = s.cwd + "/informe/borrador.md"
	var panel := _open_panel(s, path)
	panel.text_edit.text = "Hallazgo: panel-old expuesto.\n"
	panel._on_text_changed()
	assert_true(panel.dirty)
	var outcome: Dictionary = panel.save()
	assert_true(outcome["ok"])
	assert_false(panel.dirty)
	assert_true("panel-old expuesto" in s.run("cat informe/borrador.md").stdout, "el archivo cambió de verdad")
	var edited := 0
	for event: Dictionary in s.events:
		if event["type"] == "file_edited":
			edited += 1
	assert_eq(edited, 1)
	_dispose(panel)


func test_guardar_un_archivo_nuevo_en_un_directorio_propio() -> void:
	var s: RefCounted = _game()["session"]
	var path: String = s.cwd + "/informe/notas.txt"
	var panel := _open_panel(s, path)
	assert_eq(panel.text_edit.text, "", "un archivo nuevo empieza vacío")
	panel.text_edit.text = "pendiente: revisar puertos"
	assert_true(panel.save()["ok"])
	assert_true("revisar puertos" in s.run("cat informe/notas.txt").stdout)
	_dispose(panel)


func test_guardar_sin_permiso_de_escritura_falla_sin_tocar_nada() -> void:
	var s: RefCounted = _game()["session"]
	var panel := _open_panel(s, "/etc/hostname")
	panel.text_edit.text = "otro"
	var outcome: Dictionary = panel.save()
	assert_false(outcome["ok"])
	assert_true("Permission denied" in outcome["message"])
	assert_false("otro" == s.run("cat /etc/hostname").stdout.strip_edges())
	_dispose(panel)


func test_cerrar_con_cambios_avisa_y_cierra_a_la_segunda() -> void:
	var s: RefCounted = _game()["session"]
	var panel := _open_panel(s, s.cwd + "/informe/borrador.md")
	assert_true(panel.request_close(), "sin cambios cierra a la primera")
	var panel2 := _open_panel(s, s.cwd + "/informe/borrador.md")
	panel2.text_edit.text = "algo nuevo"
	panel2._on_text_changed()
	assert_false(panel2.request_close(), "avisa y sigue abierto")
	assert_true(panel2.is_open())
	assert_true(panel2.request_close(), "a la segunda descarta")
	assert_false(panel2.is_open())
	_dispose(panel)
	_dispose(panel2)


func test_nano_tiene_documentacion_y_aparece_en_la_chuleta() -> void:
	var s: RefCounted = _game()["session"]
	assert_true("nano" in s.run("nano --help").stdout)
	assert_true("nano" in s.run("cheatsheet").stdout)
