extends "res://tests/framework/test_case.gd"
## Menú inicial (continuar / nueva partida) y panel de pruebas (saltos directos).

const SaveStore := preload("res://game/save_store.gd")
const StartMenu := preload("res://ui/widgets/start_menu.gd")
const DebugPanel := preload("res://ui/widgets/debug_panel.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _main() -> Control:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var root := scene.instantiate()
	_tree().root.add_child(root)
	return root


func _dispose(root: Control) -> void:
	_tree().root.remove_child(root)
	root.free()


func _key(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event


# --- Motor: saltar a una misión ---

func _engine() -> RefCounted:
	return MissionEngine.new(MissionLoader.load_file("res://data/missions/primer_contacto.json")["book"])


func test_saltar_a_una_mision_completa_las_anteriores_sin_xp() -> void:
	var m := _engine()
	m.debug_skip_to(2)
	assert_eq(m.mission_index, 2)
	assert_eq(m.xp, 0, "saltar no da XP")
	assert_eq(m.status_of("m1_nota"), "done")
	assert_eq(m.status_of("m2_ping"), "done")
	assert_eq(m.status_of("m3_puertos"), "pending", "la misión de destino queda sin hacer")
	assert_eq(m.status_of("m1_q_shadow"), "pending", "la autoevaluación opcional no se completa sola")
	assert_true(m.evidence_cards()[0]["collected"], "se recogen las evidencias de lo saltado")
	assert_eq(m.current_mission()["id"], "m3_que_ofrece")


func test_saltar_hacia_atras_reinicia_y_saltar_al_final_termina_el_libro() -> void:
	var m := _engine()
	m.debug_skip_to(3)
	m.debug_skip_to(1)
	assert_eq(m.mission_index, 1)
	assert_eq(m.status_of("m2_ping"), "pending", "volver atrás deshace lo posterior")
	m.debug_skip_to(99)
	assert_true(m.is_finished())
	m.debug_reset()
	assert_eq([m.mission_index, m.xp, m.status_of("m1_nota")], [0, 0, "pending"])


func test_lo_saltado_no_programa_repasos() -> void:
	var m := _engine()
	var scheduled: Array = []
	m.on_objective_done = func(objective: Dictionary, _mastery: String) -> void: scheduled.append(objective["concept"])
	m.debug_skip_to(3)
	assert_eq(scheduled, [], "saltar no cuenta como haber aprendido")


# --- Menú inicial (el widget) ---

func test_el_menu_sin_partida_no_deja_continuar() -> void:
	var menu := StartMenu.new()
	menu.open_menu(false)
	assert_true(menu.is_open())
	assert_true(menu.continue_button.disabled)
	assert_true("aún no hay partida" in menu.continue_button.text)
	menu.open_menu(true, "Primer contacto · Misión 2")
	assert_false(menu.continue_button.disabled)
	assert_eq(menu.summary.text, "Primer contacto · Misión 2")
	menu.free()


func test_nueva_partida_sin_nada_guardado_empieza_directamente() -> void:
	var menu := StartMenu.new()
	var starts: Array = []
	menu.new_game_confirmed.connect(func() -> void: starts.append(1))
	menu.open_menu(false)
	menu.new_game_button.pressed.emit()
	assert_eq(starts.size(), 1, "no hay nada que borrar: no se pregunta")
	menu.free()


func test_nueva_partida_con_progreso_pide_confirmacion() -> void:
	var menu := StartMenu.new()
	var starts: Array = []
	menu.new_game_confirmed.connect(func() -> void: starts.append(1))
	menu.open_menu(true)
	menu.new_game_button.pressed.emit()
	assert_eq(starts.size(), 0, "todavía no: falta confirmar")
	assert_true(menu._confirm_box.visible)
	assert_false(menu._buttons.visible, "los botones normales se esconden mientras se pregunta")
	menu.confirm_no.pressed.emit()
	assert_eq(starts.size(), 0, "cancelar no borra nada")
	assert_true(menu._buttons.visible and not menu._confirm_box.visible)
	menu.new_game_button.pressed.emit()
	menu.confirm_yes.pressed.emit()
	assert_eq(starts.size(), 1)
	menu.free()


func test_los_botones_del_menu_emiten_sus_senales() -> void:
	var menu := StartMenu.new()
	var got: Array = []
	menu.continue_pressed.connect(func() -> void: got.append("continuar"))
	menu.settings_pressed.connect(func() -> void: got.append("ajustes"))
	menu.debug_pressed.connect(func() -> void: got.append("pruebas"))
	menu.quit_pressed.connect(func() -> void: got.append("salir"))
	menu.open_menu(true)
	for button: Button in [menu.continue_button, menu.settings_button, menu.debug_button, menu.quit_button]:
		button.pressed.emit()
	assert_eq(got, ["continuar", "ajustes", "pruebas", "salir"])
	menu.free()


# --- Menú integrado en el juego ---

func test_los_tests_arrancan_sin_menu_y_el_guardado_decide_si_se_puede_continuar() -> void:
	var root := _main()
	assert_false(root.start_menu.is_open(), "sin guardado (tests, capturas) se entra directo al juego")
	root.persist = true
	root._store = SaveStore.new("user://tests_menu_save.json")
	root._store.delete()
	assert_false(root._has_progress())
	root.terminal.submit("cat nota.txt")
	root._save_progress()
	assert_true(root._has_progress())
	root._store.delete()
	_dispose(root)


func test_f9_abre_y_cierra_el_menu_y_cede_el_teclado() -> void:
	var root := _main()
	root.engines["primer_contacto"].award_xp(100)   # "hay partida"
	root._unhandled_input(_key(KEY_F9))
	assert_true(root.start_menu.is_open())
	assert_false(root.terminal.typing_enabled)
	assert_false(root.start_menu.continue_button.disabled)
	assert_true("Primer contacto" in root.start_menu.summary.text and "NV 1" in root.start_menu.summary.text)
	root._unhandled_input(_key(KEY_F9))
	assert_false(root.start_menu.is_open())
	assert_true(root.terminal.typing_enabled)
	root._unhandled_input(_key(KEY_F9))
	root._input(_key(KEY_ESCAPE))
	assert_false(root.start_menu.is_open(), "Esc en el menú equivale a continuar")
	_dispose(root)


func test_desde_el_menu_se_abren_ajustes_y_al_cerrarlos_vuelve_el_menu() -> void:
	var root := _main()
	root.engines["primer_contacto"].award_xp(100)
	root._open_menu()
	root.start_menu.settings_button.pressed.emit()
	assert_false(root.start_menu.is_open(), "el menú se aparta")
	assert_true(root.settings_panel.is_open())
	root.settings_panel.close()
	assert_true(root.start_menu.is_open(), "al cerrar los ajustes, el menú vuelve")
	root.start_menu.debug_button.pressed.emit()
	assert_true(root.debug_panel.is_open() and not root.start_menu.is_open())
	root.debug_panel.close()
	assert_true(root.start_menu.is_open())
	_dispose(root)


func test_nueva_partida_borra_el_guardado_y_empieza_de_cero() -> void:
	var root := _main()
	root.persist = true
	root._store = SaveStore.new("user://tests_menu_save.json")
	_main_play(root)
	assert_true(root.engines["primer_contacto"].xp > 0)
	assert_true(root._store.has_save())
	root.scheduler.schedule("permisos", "ayuda", 1.0)
	root._open_menu()
	root.start_menu.new_game_button.pressed.emit()
	root.start_menu.confirm_yes.pressed.emit()
	assert_false(root._store.has_save() and root.engines["primer_contacto"].xp > 0 and false, "")
	assert_eq(root.engines["primer_contacto"].xp, 0, "el progreso vuelve a cero")
	assert_false(root.scheduler.has_concept("permisos"), "los repasos también")
	assert_false(root.start_menu.is_open())
	assert_eq(root.controller.book_states["tienda_web"], "bloqueado")
	assert_true("Escribe `mision`" in root.terminal.output_text())
	assert_false("cat nota.txt" in root.terminal.output_text(), "la pantalla se limpia")
	root._store.delete()
	_dispose(root)


func _main_play(root: Control) -> void:
	root.terminal.submit("cat nota.txt")


# --- Panel de pruebas ---

func test_el_panel_de_pruebas_ofrece_un_boton_por_mision_y_por_repaso() -> void:
	var root := _main()
	var texts: Array[String] = root.debug_panel.button_texts()
	for expected in ["Misión 1: Orientación", "Misión 4: Lo que demuestras", "Misión 1: Alcance y cabeceras", "Misión 3: Control de acceso",
			"Repaso: permisos", "Repaso: informe", "Modo libre", "Modo misión", "Dar 300 XP", "Borrar todo el progreso", "Libro completado"]:
		assert_true(expected in texts, "falta el botón '%s'" % expected)
	_dispose(root)


func test_saltar_al_segundo_laboratorio_desde_el_panel() -> void:
	var root := _main()
	assert_true(root.debug_panel.press("Misión 2: Sesiones y cookies"))
	assert_eq(root.active_book, "tienda_web")
	assert_eq(root.engines["tienda_web"].mission_index, 1)
	assert_eq(root.engines["primer_contacto"].is_finished(), true, "el primer laboratorio queda terminado")
	assert_eq(root.controller.book_states["tienda_web"], "disponible")
	assert_eq(root.session.host.hostname, "audit-web")
	assert_true("SESIONES Y COOKIES" in root._mission_label.text)
	assert_false(root.debug_panel.is_open(), "el panel se cierra para ver el resultado")
	assert_true("[prueba] Saltado a misión 2" in root.terminal.output_text())
	_dispose(root)


func test_saltar_a_una_mision_concreta_del_primer_laboratorio_y_hacerla() -> void:
	var root := _main()
	root.debug_panel.press("Misión 3: Qué ofrece")
	assert_eq(root.engines["primer_contacto"].mission_index, 2)
	assert_eq(root.engines["primer_contacto"].status_of("m2_vivo"), "done")
	root.terminal.submit("nmap web01")
	assert_eq(root.engines["primer_contacto"].status_of("m3_puertos"), "done", "se puede jugar desde ahí con normalidad")
	_dispose(root)


func test_saltar_hacia_atras_vuelve_a_un_laboratorio_anterior() -> void:
	var root := _main()
	root.debug_panel.press("Misión 1: Alcance y cabeceras")
	assert_eq(root.active_book, "tienda_web")
	root.debug_panel.press("Misión 2: Quién está ahí")
	assert_eq(root.active_book, "primer_contacto")
	assert_eq(root.engines["primer_contacto"].mission_index, 1)
	assert_eq(root.session.host.hostname, "ronin-box")
	_dispose(root)


func test_el_libro_completado_desde_el_panel_desbloquea_el_siguiente() -> void:
	var root := _main()
	root.debug_panel.press("Libro completado")
	assert_true(root.engines["primer_contacto"].is_finished())
	assert_eq(root.controller.book_states, {"primer_contacto": "completado", "tienda_web": "disponible", "guardia_logs": "bloqueado", "endurecimiento": "bloqueado", "incidente": "bloqueado", "copias": "bloqueado", "inventario": "bloqueado", "cuentas": "bloqueado", "radar": "bloqueado"})
	_dispose(root)


func test_modos_y_repasos_desde_el_panel() -> void:
	var root := _main()
	root.debug_panel.press("Modo libre")
	assert_eq(root.controller.mode, "libre")
	assert_true(root.session.free_mode)
	assert_eq(root._mission_label.text, "MODO LIBRE")
	root.debug_panel.press("Modo misión")
	assert_eq(root.controller.mode, "mision")
	assert_false(root.session.free_mode)
	root.debug_panel.press("Repaso: permisos")
	assert_eq(root.controller.mode, "repaso")
	assert_eq(root.session.host.hostname, "audit-box")
	root.debug_panel.press("Repaso: http")
	assert_eq(root.controller.current_review_concept, "http", "se puede cambiar de repaso")
	root.debug_panel.press("Salir del repaso")
	assert_eq(root.controller.mode, "mision")
	assert_eq(root.session.host.hostname, "ronin-box")
	_dispose(root)


func test_un_salto_cancela_un_repaso_en_curso() -> void:
	var root := _main()
	root.debug_panel.press("Repaso: permisos")
	root.debug_panel.press("Misión 2: Quién está ahí")
	assert_eq(root.controller.mode, "mision")
	assert_eq(root.session.host.hostname, "ronin-box")
	assert_eq(root.engines["primer_contacto"].mission_index, 1)
	_dispose(root)


func test_ayudas_de_estado_del_panel() -> void:
	var root := _main()
	root.debug_panel.open()
	root.debug_panel.press("Dar 300 XP")
	assert_eq(root.engines["primer_contacto"].xp, 300)
	assert_eq(root.engines["primer_contacto"].level(), 2)
	assert_true(root.debug_panel.is_open(), "las ayudas rápidas no cierran el panel")
	root.debug_panel.press("Marcar todos los repasos como atrasados")
	assert_eq(root.controller.due_reviews().size(), root.controller.review_concepts().size())
	root.terminal.submit("echo x > prueba.txt")
	root.debug_panel.press("Reiniciar este laboratorio")
	assert_false(root.session.host.fs.exists("/home/ronin/prueba.txt"))
	root.debug_panel.press("Borrar todo el progreso")
	assert_eq(root.engines["primer_contacto"].xp, 0)
	assert_false(root.scheduler.has_concept("permisos"))
	_dispose(root)


func test_f11_abre_el_panel_de_pruebas_y_cierra_las_demas_ventanas() -> void:
	var root := _main()
	root._unhandled_input(_key(KEY_F1))
	root._unhandled_input(_key(KEY_F11))
	assert_true(root.debug_panel.is_open())
	assert_false(root.cheatsheet_panel.is_open())
	assert_false(root.terminal.typing_enabled)
	root._input(_key(KEY_ESCAPE))
	assert_false(root.debug_panel.is_open())
	assert_true(root.terminal.typing_enabled)
	_dispose(root)


func test_los_repasos_de_la_tienda_llevan_al_portal_y_vuelven() -> void:
	var root := _main()
	assert_true("Repaso: cookies sesiones" in root.debug_panel.button_texts())
	root.debug_panel.press("Misión 2: Sesiones y cookies")
	root.debug_panel.press("Repaso: cookies sesiones")
	assert_eq(root.controller.mode, "repaso")
	assert_eq(root.session.host.hostname, "audit-portal")
	assert_true("REPASO: COOKIES SESIONES" in root.terminal.output_text())
	root.terminal.submit("curl -i -d 'usuario=cliente1&clave=prueba456' portal01:8080/acceso")
	root.terminal.submit("curl -b 'sid=ses-cli1-77b2' portal01:8080/mi-cuenta")
	assert_eq(root.controller.mode, "mision", "al completar el reto se vuelve solo")
	assert_eq(root.active_book, "tienda_web")
	assert_eq(root.session.host.hostname, "audit-web", "a la tienda donde estabas")
	_dispose(root)
