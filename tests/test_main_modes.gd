extends "res://tests/framework/test_case.gd"
## Modos y repaso vistos desde la pantalla principal: la orquestación completa.

const NOW := 9000000.0
const DAY := 86400.0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _main() -> Control:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var root := scene.instantiate()
	_tree().root.add_child(root)
	root.controller.now_fn = func() -> float: return NOW
	return root


func _dispose(root: Control) -> void:
	_tree().root.remove_child(root)
	root.free()


func _run(root: Control, lines: Array) -> void:
	for line: String in lines:
		root.terminal.submit(line)


# --- Modo libre ---

func test_lo_hecho_en_modo_libre_no_cuenta_para_los_objetivos() -> void:
	var root := _main()
	_run(root, ["modo libre"])
	assert_eq(root._mission_label.text, "MODO LIBRE")
	assert_true(root.session.free_mode)
	_run(root, ["cat nota.txt"])
	assert_eq(root.main_engine.status_of("m1_nota"), "pending", "en modo libre leer la nota no completa nada")
	assert_eq(root.main_engine.xp, 0)
	_run(root, ["modo mision"])
	assert_false(root.session.free_mode)
	_run(root, ["cat nota.txt"])
	assert_eq(root.main_engine.status_of("m1_nota"), "done", "fuera del modo libre sí cuenta")
	_dispose(root)


func test_el_modo_libre_marca_los_eventos_pero_el_mapa_los_ve() -> void:
	var root := _main()
	_run(root, ["modo libre", "ping -c 1 web01"])
	var last: Dictionary = root.session.events[-1]
	assert_true(last.get("free", false), "el evento queda marcado como libre")
	assert_true("10.0.0.5" in root.network_map.discovered_ips(), "el mapa sí refleja lo que descubres jugando libre")
	_dispose(root)


func test_el_panel_de_objetivos_explica_el_modo_libre() -> void:
	var root := _main()
	_run(root, ["modo libre"])
	var texts := ""
	for child in root._objectives_frame.content.get_children():
		if child is Label:
			texts += child.text
	assert_true("reiniciar" in texts and "modo mision" in texts)
	_dispose(root)


# --- Reiniciar ---

func test_reiniciar_restaura_el_laboratorio_sin_tocar_el_progreso() -> void:
	var root := _main()
	_run(root, ["cat nota.txt", "echo basura > nota.txt", "chmod 000 .hidden"])
	var xp_before: int = root.main_engine.xp
	var old_session: RefCounted = root.session
	assert_eq(old_session.host.fs.read_file("/home/ronin/nota.txt"), "basura\n")
	_run(root, ["reiniciar"])
	assert_true(root.session != old_session, "sesión nueva")
	assert_true("Red autorizada" in root.session.host.fs.read_file("/home/ronin/nota.txt"), "la nota original vuelve")
	assert_eq(root.session.host.fs.get_node_info("/home/ronin/.hidden")["mode"], "600", "los permisos también")
	assert_eq(root.main_engine.xp, xp_before, "el progreso no se toca")
	assert_eq(root.main_engine.status_of("m1_nota"), "done")
	assert_true("Laboratorio reiniciado" in root.terminal.output_text())
	assert_eq(root.network_map.discovered_ips(), [], "el mapa vuelve a empezar")
	_dispose(root)


# --- Repaso ---

func test_un_repaso_completo_programa_y_da_xp() -> void:
	var root := _main()
	root.scheduler.schedule("permisos", "solucion", NOW - DAY)
	var xp_before: int = root.main_engine.xp
	var main_session: RefCounted = root.session

	_run(root, ["repaso"])
	assert_true("[!] permisos" in root.terminal.output_text())
	_run(root, ["repaso iniciar"])
	assert_eq(root.controller.mode, "repaso")
	assert_eq(root.session.host.hostname, "audit-box", "otra red, otra máquina")
	assert_true("REPASO" in root._mission_label.text)
	assert_true("REPASO: PERMISOS" in root.terminal.output_text())
	assert_eq(root.main_engine.xp, xp_before, "durante el repaso el progreso real no cambia")

	_run(root, ["ls -l /srv", "id"])
	assert_eq(root.controller.mode, "mision", "al completar el reto se vuelve solo")
	assert_true(root.session == main_session, "se recupera tu laboratorio tal como lo dejaste")
	assert_eq(root.session.host.hostname, "ronin-box")
	assert_eq(root.scheduler.box_of("permisos"), 1, "acertar sube de la caja 0 a la 1")
	assert_eq(root.main_engine.xp, xp_before + 50)
	assert_true("Repaso superado" in root.terminal.output_text())
	assert_false("Has completado todas las misiones" in root.terminal.output_text(), "un repaso no anuncia el fin del laboratorio")
	assert_false("Misión completada: Repaso" in root.terminal.output_text())
	assert_true("MISIÓN 1" in root._mission_label.text)
	assert_eq(root.controller.due_reviews(), [], "ya no está atrasado")
	_dispose(root)


func test_un_repaso_con_solucion_vuelve_pronto_y_no_da_xp() -> void:
	var root := _main()
	root.scheduler.schedule("versiones", "solo", NOW)
	var xp_before: int = root.main_engine.xp
	_run(root, ["repaso iniciar versiones"])
	_run(root, ["pista", "pista", "pista"])
	assert_true("SOLUCIÓN EXPLICADA" in root.terminal.output_text())
	_run(root, ["nmap -Pn -sV db02"])
	assert_eq(root.controller.mode, "mision")
	assert_eq(root.scheduler.box_of("versiones"), 0, "viendo la solución, vuelve a la caja 0")
	assert_eq(root.main_engine.xp, xp_before, "sin XP, pero tampoco se resta nada")
	assert_true("viendo la solución" in root.terminal.output_text())
	_dispose(root)


func test_salir_de_un_repaso_no_cuenta_como_fallo() -> void:
	var root := _main()
	root.scheduler.schedule("http", "ayuda", NOW)
	var box_before: int = root.scheduler.box_of("http")
	_run(root, ["repaso iniciar http", "curl app02:8000/robots.txt", "repaso salir"])
	assert_eq(root.controller.mode, "mision")
	assert_eq(root.scheduler.box_of("http"), box_before, "abandonar no cambia la programación")
	assert_eq(root.session.host.hostname, "ronin-box")
	_dispose(root)


func test_reiniciar_durante_un_repaso_reinicia_el_laboratorio_de_repaso() -> void:
	var root := _main()
	_run(root, ["repaso iniciar permisos", "echo x > pendientes.txt"])
	assert_eq(root.session.host.fs.read_file("/home/ronin/pendientes.txt"), "x\n")
	_run(root, ["reiniciar"])
	assert_eq(root.session.host.hostname, "audit-box", "sigues en el laboratorio de repaso")
	assert_true("Auditar la red" in root.session.host.fs.read_file("/home/ronin/pendientes.txt"))
	assert_eq(root.controller.mode, "repaso")
	_dispose(root)


func test_completar_objetivos_programa_conceptos_para_el_repaso() -> void:
	var root := _main()
	_run(root, ["pista 1", "cat nota.txt", "ls -a", "cat .hidden"])
	assert_eq(root.scheduler.box_of("navegacion"), 1, "con una pista: vuelve pronto")
	assert_eq(root.scheduler.box_of("archivos_ocultos"), 2, "solo: más tarde")
	_dispose(root)


func test_el_repaso_no_se_ofrece_en_modo_libre() -> void:
	var root := _main()
	_run(root, ["modo libre", "repaso iniciar permisos"])
	assert_eq(root.controller.mode, "libre")
	assert_true("estás en modo libre" in root.terminal.output_text())
	_dispose(root)
