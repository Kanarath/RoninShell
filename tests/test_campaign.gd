extends "res://tests/framework/test_case.gd"
## La campaña: varios laboratorios que se desbloquean en orden, con progreso independiente.

const Missions := preload("res://tests/test_missions.gd")
const WebMissions := preload("res://tests/test_web_missions.gd")


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


func _run(root: Control, lines: Array) -> void:
	for line: String in lines:
		root.terminal.submit(line)


func _finish_first_lab(root: Control) -> void:
	_run(root, Missions.M1_STEPS)
	_run(root, Missions.M2_STEPS)
	_run(root, Missions.M3_STEPS)
	_run(root, Missions.M4_STEPS)


func test_al_empezar_solo_el_primer_laboratorio_esta_disponible() -> void:
	var root := _main()
	assert_eq(root.controller.book_states, {"primer_contacto": "disponible", "tienda_web": "bloqueado", "guardia_logs": "bloqueado", "endurecimiento": "bloqueado"})
	_run(root, ["laboratorio"])
	var out: String = root.terminal.output_text()
	assert_true("LABORATORIOS" in out and "primer_contacto" in out and "tienda_web" in out)
	assert_true("(activo)" in out and "bloqueado" in out)
	_run(root, ["laboratorio tienda_web"])
	assert_true("está bloqueado" in root.terminal.output_text())
	assert_eq(root.active_book, "primer_contacto", "no se cambia a un laboratorio bloqueado")
	_dispose(root)


func test_completar_un_laboratorio_desbloquea_el_siguiente_y_lo_anuncia() -> void:
	var root := _main()
	_finish_first_lab(root)
	assert_true(root.engines["primer_contacto"].is_finished())
	assert_eq(root.controller.book_states["tienda_web"], "disponible")
	var out: String = root.terminal.output_text()
	assert_true("Nuevo laboratorio disponible: Tienda web" in out)
	assert_eq(out.count("Nuevo laboratorio disponible"), 1, "se anuncia una sola vez")
	_dispose(root)


func test_cambiar_de_laboratorio_cambia_mundo_misiones_y_mapa() -> void:
	var root := _main()
	_finish_first_lab(root)
	_run(root, ["laboratorio tienda_web"])
	assert_eq(root.active_book, "tienda_web")
	assert_eq(root.session.host.hostname, "audit-web")
	assert_eq(root.world.title, "Tienda web (auditoría autorizada)")
	assert_true("ALCANCE Y CABECERAS" in root._mission_label.text)
	assert_true(root.network_map.world == root.world, "el mapa dibuja la red del laboratorio activo")
	assert_true("LABORATORIO: TIENDA WEB" in root.terminal.output_text())
	assert_eq(root.terminal.prompt_label.text, "ronin@audit-web:~$ ")
	_dispose(root)


func test_el_progreso_de_cada_laboratorio_es_independiente() -> void:
	var root := _main()
	_finish_first_lab(root)
	var xp_first: int = root.engines["primer_contacto"].xp
	_run(root, ["laboratorio tienda_web", "cat cliente.txt"])
	assert_eq(root.engines["tienda_web"].status_of("w1_alcance"), "done")
	assert_eq(root.engines["primer_contacto"].xp, xp_first, "lo del segundo no toca el primero")
	assert_true(root.engines["tienda_web"].xp > 0)
	_dispose(root)


func test_volver_al_primer_laboratorio_conserva_lo_que_habias_hecho_en_el() -> void:
	var root := _main()
	_run(root, ["echo recuerdo > marca.txt"])
	_finish_first_lab(root)
	_run(root, ["laboratorio tienda_web", "pwd", "laboratorio primer_contacto"])
	assert_eq(root.active_book, "primer_contacto")
	assert_eq(root.session.host.fs.read_file("/home/ronin/marca.txt"), "recuerdo\n", "la sesión del primer laboratorio se conserva")
	assert_eq(root.session.host.hostname, "ronin-box")
	_dispose(root)


func test_la_campaña_solo_se_cambia_desde_el_modo_mision() -> void:
	var root := _main()
	_finish_first_lab(root)
	_run(root, ["modo libre", "laboratorio tienda_web"])
	assert_eq(root.active_book, "primer_contacto")
	assert_true("solo se puede cambiar desde el modo misión" in root.terminal.output_text())
	_run(root, ["modo mision", "laboratorio no_existe"])
	assert_true("no existe 'no_existe'" in root.terminal.output_text())
	_dispose(root)


func test_reiniciar_afecta_solo_al_laboratorio_activo() -> void:
	var root := _main()
	_finish_first_lab(root)
	_run(root, ["echo a > uno.txt", "laboratorio tienda_web", "echo b > dos.txt", "reiniciar"])
	assert_false(root.session.host.fs.exists("/home/ronin/dos.txt"), "el laboratorio web vuelve al principio")
	_run(root, ["laboratorio primer_contacto"])
	assert_true(root.session.host.fs.exists("/home/ronin/uno.txt"), "el primero no se tocó")
	_dispose(root)


func test_el_repaso_funciona_desde_el_segundo_laboratorio() -> void:
	var root := _main()
	_finish_first_lab(root)
	_run(root, ["laboratorio tienda_web", "repaso iniciar permisos"])
	assert_eq(root.controller.mode, "repaso")
	assert_eq(root.session.host.hostname, "audit-box")
	_run(root, ["repaso salir"])
	assert_eq(root.active_book, "tienda_web")
	assert_eq(root.session.host.hostname, "audit-web", "al salir vuelves al laboratorio donde estabas")
	_dispose(root)


# --- Guardado ---

func test_ida_y_vuelta_del_guardado_de_la_campaña() -> void:
	var root := _main()
	_finish_first_lab(root)
	_run(root, ["laboratorio tienda_web", "cat cliente.txt"])
	var saved: Dictionary = JSON.parse_string(JSON.stringify(root.campaign_to_dict()))
	var xp_first: int = root.engines["primer_contacto"].xp
	var xp_second: int = root.engines["tienda_web"].xp

	var other := _main()
	assert_true(other.load_campaign(saved))
	assert_eq(other.engines["primer_contacto"].xp, xp_first)
	assert_eq(other.engines["tienda_web"].xp, xp_second)
	assert_eq(other.active_book, "tienda_web", "se recuerda en qué laboratorio estabas")
	other._update_book_states()
	assert_eq(other.controller.book_states["primer_contacto"], "completado")
	_dispose(root)
	_dispose(other)


func test_los_guardados_antiguos_se_siguen_leyendo() -> void:
	var root := _main()
	_run(root, ["cat nota.txt"])
	var engine_dict: Dictionary = root.engines["primer_contacto"].to_dict()

	var plain := _main()
	assert_true(plain.load_campaign(engine_dict), "formato más antiguo: solo el progreso del primer libro")
	assert_eq(plain.engines["primer_contacto"].xp, 100)

	var middle := _main()
	assert_true(middle.load_campaign({"progress": engine_dict, "reviews": {"permisos": {"box": 1, "due": 5.0}}}), "formato con repasos")
	assert_eq(middle.engines["primer_contacto"].xp, 100)
	assert_eq(middle.scheduler.box_of("permisos"), 1)

	assert_false(middle.load_campaign({}), "sin datos no se restaura nada")
	_dispose(root)
	_dispose(plain)
	_dispose(middle)


func test_un_guardado_con_un_laboratorio_activo_desconocido_vuelve_al_primero() -> void:
	var root := _main()
	root.load_campaign({"campaign": {}, "active_book": "inventado"})
	assert_eq(root.active_book, "primer_contacto")
	_dispose(root)


func test_las_misiones_web_se_completan_dentro_de_la_campaña() -> void:
	var root := _main()
	_finish_first_lab(root)
	_run(root, ["laboratorio tienda_web"])
	_run(root, WebMissions.M1)
	_run(root, WebMissions.M2)
	_run(root, WebMissions.M3)
	assert_true(root.engines["tienda_web"].is_finished())
	assert_eq(root.controller.book_states["tienda_web"], "completado")
	assert_true("LABORATORIO COMPLETADO" in root._mission_label.text)
	_dispose(root)
