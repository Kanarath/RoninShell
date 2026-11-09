extends "res://tests/framework/test_case.gd"
## Retos de repaso (otro laboratorio), modo libre, reinicio y comandos modo/repaso/reiniciar.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")
const LabController := preload("res://engine/lab_controller.gd")
const Scheduler := preload("res://engine/review/review_scheduler.gd")

const MAIN_BOOK := "res://data/missions/primer_contacto.json"
const REVIEW_BOOK := "res://data/missions/repaso.json"
const REVIEW_LAB := "res://data/labs/repaso_red.json"
const NOW := 5000000.0
const DAY := 86400.0

## Una solución válida para cada reto, solo con comandos.
const SOLUTIONS := {
	"r_permisos": ["ls -l /srv", "id"],
	"r_descubrimiento": ["ping -c 2 db02", "nmap -Pn db02"],
	"r_puertos": ["nmap -p- app02"],
	"r_versiones": ["nmap -Pn -sV db02"],
	"r_http": ["curl app02:8000/robots.txt", "curl app02:8000/panel-old/"],
	"r_hallazgos": ["nmap -Pn -sV db02", "hallazgo indicio 'MariaDB 10.3.29 en db02:3306'"],
	"r_informe": [
		"curl app02:8000/robots.txt", "curl app02:8000/panel-old/",
		"hallazgo confirmado 'panel-old expuesto en app02:8000/panel-old/'",
		"echo 'Panel de administración antiguo expuesto en app02:8000/panel-old/, accesible sin autenticación (GET devuelve 200). Recomendación: retirarlo o restringir el acceso.' >> informe/borrador.md",
		"revisar",
	],
	"r_interpretacion": ["curl app02:8080", "curl app02:8081"],
	"r_cabeceras": ["curl -I portal01:8080"],
	"r_cookies": [
		"curl -i -d 'usuario=cliente1&clave=prueba456' portal01:8080/acceso",
		"curl -b 'sid=ses-cli1-77b2' portal01:8080/mi-cuenta",
	],
	"r_tuberias": ["grep timeout /var/log/app/error.log | wc -l"],
	"r_variables": ["S=pagos", "grep $S /var/log/app/error.log"],
	"r_bucles": ["for s in $(cat servicios.txt); do echo $s; grep $s /var/log/app/error.log | wc -l; done"],
	"r_encadenar": ["test -f /var/log/app/error.log && grep -c ERROR /var/log/app/error.log", "test -f /var/log/app/nada.log || echo falta el registro"],
	"r_logs": ["grep ' 500' /var/log/app/access.log | wc -l"],
	"r_comodines": ["grep -c ERROR /var/log/app/*.log"],
	"r_funciones": ["contar() { grep -c \"$1\" /var/log/app/error.log; }", "contar timeout", "contar ERROR"],
	"r_case": ["for s in $(cat servicios.txt); do case $s in pagos) echo critico;; inventario) echo vigilar;; *) echo normal;; esac; done"],
	"r_archivos": ["mkdir archivo", "mv agenda.txt archivo/"],
	"r_copias": ["cp plan.conf plan.conf.bak", "echo 'modo=reforzado' > plan.conf"],
	"r_integridad": ["cp agenda.txt agenda.bak", "sha256sum agenda.txt agenda.bak"],
	"r_inventario": ["nmap 10.0.13.0/24 | grep -E 'report|open' > actual.txt"],
	"r_exposicion": ["nmap 10.0.13.0/24 | grep -E 'report|open' > actual.txt", "diff esperado.txt actual.txt"],
	"r_cuentas": ["cat accesos.txt", "echo 'ana=activa
luis=activa
temporal=bloqueada' > estado.conf.copia"],
	"r_politica": ["echo 'PASS_MIN_LEN 12
PASS_MAX_DAYS 90' > pass.conf.copia"],
	"r_avisos": ["nmap -Pn -sV db02", "avisos db02 3306"],
	"r_config": ["echo 'AccesoAnonimo no' > copias/servicio.conf"],
	"r_datos": ["ls -l copias", "chmod 600 copias/nominas.csv"],
	"r_verificar": ["echo 'SubidasPermitidas no' > copias/servicio.conf", "if grep 'SubidasPermitidas no' copias/servicio.conf; then echo cumple; else echo revisar; fi"],
	"r_control_acceso": [
		"curl -c jar.txt -d 'usuario=cliente1&clave=prueba456' portal01:8080/acceso",
		"curl -b jar.txt 'portal01:8080/factura?num=301'",
		"curl -b jar.txt 'portal01:8080/factura?num=302'",
		"curl -b 'perfil=gestor' portal01:8080/gestion",
	],
}


## El laboratorio de un reto: el suyo propio ("lab" en la misión) o el del libro.
func _lab_of(mission_id: String) -> String:
	var book: Dictionary = MissionLoader.load_file(REVIEW_BOOK)["book"]
	for mission: Dictionary in book["missions"]:
		if mission["id"] == mission_id:
			return "res://data/labs/%s.json" % mission.get("lab", book["lab"])
	return REVIEW_LAB


func _review_game(mission_id: String) -> Dictionary:
	var world = LabLoader.load_file(_lab_of(mission_id))["world"]
	var book: Dictionary = MissionLoader.load_file(REVIEW_BOOK)["book"]
	var engine := MissionEngine.new(MissionEngine.single_mission_book(book, mission_id))
	var tracker := MissionTracker.new(engine)
	var session := ShellSession.new(world, CommandSet.create_registry(tracker))
	session.tracker = tracker
	return {"engine": engine, "session": session}


func _play(game: Dictionary, lines: Array) -> void:
	for line: String in lines:
		game["session"].run(line)


# --- Datos válidos y coherentes ---

func test_los_datos_de_repaso_son_validos() -> void:
	assert_eq(LabLoader.load_file(REVIEW_LAB)["errors"], [])
	assert_eq(LabLoader.load_file("res://data/labs/repaso_web.json")["errors"], [])
	assert_eq(LabLoader.load_file("res://data/labs/repaso_logs.json")["errors"], [])
	assert_eq(LabLoader.load_file("res://data/labs/repaso_config.json")["errors"], [])
	assert_eq(LabLoader.load_file("res://data/labs/repaso_copias.json")["errors"], [])
	assert_eq(LabLoader.load_file("res://data/labs/repaso_inventario.json")["errors"], [])
	assert_eq(LabLoader.load_file("res://data/labs/repaso_cuentas.json")["errors"], [])
	assert_eq(MissionLoader.load_file(REVIEW_BOOK)["errors"], [])


func test_cada_reto_de_repaso_apunta_a_un_concepto_que_se_aprende_en_las_misiones() -> void:
	var main_concepts := {}
	for path in [MAIN_BOOK, "res://data/missions/tienda_web.json", "res://data/missions/guardia_logs.json", "res://data/missions/endurecimiento.json", "res://data/missions/incidente.json", "res://data/missions/copias.json", "res://data/missions/inventario.json", "res://data/missions/cuentas.json", "res://data/missions/radar.json"]:
		for mission: Dictionary in MissionLoader.load_file(path)["book"]["missions"]:
			for objective: Dictionary in mission["objectives"]:
				main_concepts[objective["concept"]] = true
	for mission: Dictionary in MissionLoader.load_file(REVIEW_BOOK)["book"]["missions"]:
		assert_true(main_concepts.has(mission["concept"]), "%s repasa '%s', que no se enseña en las misiones" % [mission["id"], mission["concept"]])
		assert_true(SOLUTIONS.has(mission["id"]), "falta la solución de prueba de %s" % mission["id"])


func test_los_laboratorios_de_repaso_son_otras_redes() -> void:
	var originals: Array = []
	for path in ["res://data/labs/primer_contacto.json", "res://data/labs/tienda_web.json", "res://data/labs/guardia_logs.json", "res://data/labs/endurecimiento.json", "res://data/labs/incidente.json", "res://data/labs/copias.json", "res://data/labs/inventario.json", "res://data/labs/cuentas.json", "res://data/labs/radar.json"]:
		originals.append(LabLoader.load_file(path)["world"])
	for path in [REVIEW_LAB, "res://data/labs/repaso_web.json", "res://data/labs/repaso_logs.json", "res://data/labs/repaso_config.json", "res://data/labs/repaso_copias.json", "res://data/labs/repaso_inventario.json", "res://data/labs/repaso_cuentas.json"]:
		var review = LabLoader.load_file(path)["world"]
		for original in originals:
			for ip in review.host_ips():
				assert_false(original.hosts.has(ip), "%s existe también en el laboratorio original: no sería un escenario nuevo" % ip)
			for host in review.hosts.values():
				assert_false(original.host_by_name(host.hostname) != null, "el nombre %s se repite" % host.hostname)

# --- Cada reto se puede resolver ---

func test_todos_los_retos_de_repaso_se_pueden_resolver_con_comandos() -> void:
	for mission_id: String in SOLUTIONS:
		var game := _review_game(mission_id)
		_play(game, SOLUTIONS[mission_id])
		assert_true(game["engine"].is_finished(), "el reto %s no se completa con su solución" % mission_id)
		assert_eq(game["engine"].review_concepts(), [], "%s: resuelto sin ayuda no deja nada que repasar" % mission_id)


# --- Memorizar no sirve ---

func test_las_respuestas_del_primer_laboratorio_no_resuelven_el_repaso() -> void:
	var game := _review_game("r_descubrimiento")
	_play(game, ["ping -c 2 10.0.0.9", "nmap -Pn 10.0.0.9"])
	assert_false(game["engine"].is_finished(), "repetir los comandos de la misión 2 con sus IP no vale")
	var ports := _review_game("r_puertos")
	_play(ports, ["nmap app02", "nmap -sV app02"])
	assert_false(ports["engine"].is_finished(), "el escaneo por defecto no ve el puerto 2222")
	_play(ports, ["nmap -p 2222 app02"])
	assert_true(ports["engine"].is_finished(), "pero un puerto concreto sí")


func test_el_reto_de_permisos_exige_mirar_el_directorio() -> void:
	var game := _review_game("r_permisos")
	_play(game, ["id", "ls -l /srv/datos/balance.csv"])  # ni siquiera se puede consultar desde dentro
	assert_false(game["engine"].is_finished())
	_play(game, ["ls -l /srv"])
	assert_true(game["engine"].is_finished())


func test_clasificar_mal_en_el_repaso_se_explica() -> void:
	var game := _review_game("r_hallazgos")
	_play(game, ["nmap -Pn -sV db02"])
	var result = game["session"].run("hallazgo confirmado 'MariaDB 10.3.29 es vulnerable'")
	assert_true("No cuadra" in result.stdout)
	assert_false(game["engine"].is_finished())


func test_ver_la_solucion_en_un_repaso_queda_registrado() -> void:
	var game := _review_game("r_versiones")
	for i in 3:
		game["session"].run("pista")
	_play(game, SOLUTIONS["r_versiones"])
	assert_true(game["engine"].is_finished())
	assert_eq(game["engine"].mastery_of("r_ver_db"), "solucion")


# --- Gancho de programación y XP externo ---

func test_completar_un_objetivo_programa_su_concepto_en_el_repaso() -> void:
	var scheduler := Scheduler.new()
	var book: Dictionary = MissionLoader.load_file(MAIN_BOOK)["book"]
	var engine := MissionEngine.new(book)
	engine.on_objective_done = func(objective: Dictionary, mastery: String) -> void: scheduler.schedule(objective["concept"], mastery, NOW)
	engine.request_hint(1)
	engine.update([{"type": "file_read", "path": "/home/ronin/nota.txt"}])
	assert_eq(scheduler.box_of("navegacion"), 1, "resuelto con una pista: caja baja")
	engine.update([{"type": "file_read", "path": "/home/ronin/.hidden"}])
	assert_eq(scheduler.box_of("archivos_ocultos"), 2, "resuelto solo: caja alta")


func test_award_xp_y_libro_de_una_sola_mision() -> void:
	var engine := MissionEngine.new(MissionLoader.load_file(MAIN_BOOK)["book"])
	engine.award_xp(50)
	engine.award_xp(-20)
	assert_eq(engine.xp, 50, "el XP externo nunca resta")
	var book: Dictionary = MissionLoader.load_file(REVIEW_BOOK)["book"]
	var single := MissionEngine.single_mission_book(book, "r_http")
	assert_eq(single["missions"].size(), 1)
	assert_eq(single["missions"][0]["id"], "r_http")
	assert_eq(MissionEngine.single_mission_book(book, "no_existe"), {})


# --- Controlador y comandos de modo ---

func _controller_game() -> Dictionary:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	var engine := MissionEngine.new(MissionLoader.load_file(MAIN_BOOK)["book"])
	var tracker := MissionTracker.new(engine)
	var controller := LabController.new()
	controller.scheduler = Scheduler.new()
	controller.review_book = MissionLoader.load_file(REVIEW_BOOK)["book"]
	controller.now_fn = func() -> float: return NOW
	var session := ShellSession.new(world, CommandSet.create_registry(tracker, controller))
	session.tracker = tracker
	return {"engine": engine, "controller": controller, "session": session}


func test_el_controlador_entrega_las_peticiones_una_vez_y_en_orden() -> void:
	var controller := LabController.new()
	controller.request("reset")
	controller.request("mode", {"mode": "libre"})
	var first: Array = controller.take_requests()
	assert_eq(first.size(), 2)
	assert_eq(first[1]["mode"], "libre")
	assert_eq(controller.take_requests(), [], "ya se entregaron")


func test_modo_muestra_y_cambia_a_libre_y_vuelve() -> void:
	var game := _controller_game()
	var s: RefCounted = game["session"]
	var controller: RefCounted = game["controller"]
	assert_true("Modo actual: MISION" in s.run("modo").stdout)
	var to_free = s.run("modo libre")
	assert_true("MODO LIBRE" in to_free.stdout)
	assert_eq(controller.mode, "libre")
	assert_eq(controller.take_requests()[0], {"type": "mode", "mode": "libre"})
	assert_true("Ya estás en modo LIBRE" in s.run("modo libre").stdout)
	assert_true("De vuelta a la misión" in s.run("modo mision").stdout)
	assert_eq(controller.mode, "mision")
	assert_true("modo desconocido" in s.run("modo raro").stderr)


func test_en_modo_libre_las_ordenes_de_objetivos_lo_explican() -> void:
	var game := _controller_game()
	var s: RefCounted = game["session"]
	s.run("modo libre")
	for command in ["mision", "pista", "responder", "revisar"]:
		var result = s.run(command)
		assert_eq(result.exit_code, 1, "%s en modo libre" % command)
		assert_true("modo libre" in result.stderr and "modo mision" in result.stderr, "%s explica cómo volver" % command)
	assert_true("EXPEDIENTE" in s.run("expediente").stdout, "el expediente se puede mirar igualmente")
	assert_true("PERFIL" in s.run("perfil").stdout)


func test_reiniciar_pide_restaurar_el_laboratorio() -> void:
	var game := _controller_game()
	game["session"].run("reiniciar")
	assert_eq(game["controller"].take_requests(), [{"type": "reset"}])


func test_repaso_sin_nada_programado() -> void:
	var game := _controller_game()
	var out: String = game["session"].run("repaso").stdout
	assert_true("REPASO ESPACIADO" in out and "Ahora mismo no tienes nada atrasado" in out)
	assert_true("Aún no hay nada programado" in out)
	assert_true("permisos" in out and "informe" in out, "lista los retos disponibles")
	var start = game["session"].run("repaso iniciar")
	assert_eq(start.exit_code, 1, "sin nada atrasado no inicia solo")
	assert_true("repaso iniciar <concepto>" in start.stderr)


func test_repaso_muestra_lo_atrasado_y_lo_proximo() -> void:
	var game := _controller_game()
	var scheduler: RefCounted = game["controller"].scheduler
	scheduler.schedule("permisos", "solucion", NOW - DAY)   # atrasado
	scheduler.schedule("versiones", "solo", NOW)            # dentro de 3 días
	scheduler.schedule("navegacion", "ayuda", NOW - 5 * DAY) # atrasado, pero no tiene reto
	var out: String = game["session"].run("repaso").stdout
	assert_true("[!] permisos" in out, "atrasado y con reto")
	assert_false("[!] navegacion" in out, "sin reto de repaso no se ofrece")
	assert_true("versiones" in out and "dentro de 3.0 días" in out)
	assert_true("navegacion" in out and "sin reto todavía" in out or "navegacion" not in out)
	assert_eq(game["controller"].due_reviews(), ["permisos"])


func test_iniciar_un_repaso_por_nombre_o_el_mas_atrasado() -> void:
	var game := _controller_game()
	var controller: RefCounted = game["controller"]
	controller.scheduler.schedule("permisos", "solucion", NOW - DAY)
	var started = game["session"].run("repaso iniciar")
	assert_true("Preparando el reto de repaso: permisos" in started.stdout)
	assert_eq(controller.mode, "repaso")
	assert_eq(controller.current_review_concept, "permisos")
	assert_eq(controller.take_requests(), [{"type": "review", "concept": "permisos"}])
	assert_true("ya estás en un repaso" in game["session"].run("repaso iniciar").stderr)
	assert_true("estás en un repaso" in game["session"].run("modo libre").stderr, "no se cambia de modo a medias")

	var other := _controller_game()
	other["session"].run("repaso iniciar descubrimiento hosts")
	assert_eq(other["controller"].current_review_concept, "descubrimiento_hosts", "acepta el nombre con espacios")


func test_repaso_errores() -> void:
	var game := _controller_game()
	var s: RefCounted = game["session"]
	assert_true("no hay un reto para 'navegacion'" in s.run("repaso iniciar navegacion").stderr)
	assert_true("no estás en ningún repaso" in s.run("repaso salir").stderr)
	assert_true("uso:" in s.run("repaso raro").stderr)
	var empty := ShellSession.new(LabLoader.load_file("res://data/labs/primer_contacto.json")["world"], CommandSet.create_registry(null, LabController.new()))
	assert_true("no hay retos de repaso disponibles" in empty.run("repaso").stderr)


func test_salir_de_un_repaso() -> void:
	var game := _controller_game()
	game["session"].run("repaso iniciar permisos")
	game["controller"].take_requests()
	game["session"].run("repaso salir")
	assert_eq(game["controller"].take_requests(), [{"type": "review_exit"}])


func test_las_nuevas_ordenes_tienen_ficha_y_aparecen_en_help() -> void:
	var game := _controller_game()
	for command in ["modo", "reiniciar", "repaso"]:
		assert_true(game["session"].run("%s --help" % command).stdout.begins_with("Uso: "), "%s --help" % command)
		assert_true(command in game["session"].run("help").stdout)


# --- Repasos web: otro portal, otros nombres ---

func test_las_respuestas_de_la_tienda_no_resuelven_el_repaso_del_portal() -> void:
	var cookies := _review_game("r_cookies")
	_play(cookies, ["curl -i -d 'usuario=demo&clave=demo123' portal01:8080/acceso"])
	assert_false(cookies["engine"].is_finished(), "la cuenta de la tienda no vale en el portal")
	var access := _review_game("r_control_acceso")
	_play(access, ["curl -b 'session=tok-demo-3f9a1c' 'portal01:8080/factura?num=302'", "curl -b 'rol=admin' portal01:8080/gestion"])
	assert_false(access["engine"].is_finished(), "ni el nombre de la cookie ni las rutas son los mismos")


func test_el_repaso_de_acceso_exige_la_secuencia_correcta() -> void:
	var game := _review_game("r_control_acceso")
	_play(game, ["curl -b 'sid=ses-cli1-77b2' 'portal01:8080/factura?num=302'"])
	assert_eq(game["engine"].status_of("r_acc_ajena"), "pending", "antes hay que pedir la propia (el orden importa)")
	_play(game, ["curl -b 'sid=ses-cli1-77b2' 'portal01:8080/factura?num=301'", "curl -b 'sid=ses-cli1-77b2' 'portal01:8080/factura?num=302'"])
	assert_eq(game["engine"].status_of("r_acc_ajena"), "done")
	assert_eq(game["engine"].status_of("r_acc_gestion"), "pending")


func test_las_cabeceras_del_portal_son_distintas() -> void:
	var game := _review_game("r_cabeceras")
	var out: String = game["session"].run("curl -I portal01:8080").stdout
	assert_true("X-Frame-Options: SAMEORIGIN" in out and "Server: Apache/2.4.41 (Ubuntu)" in out)
	assert_false("nginx" in out, "no es el servidor de la tienda")


func test_los_repasos_web_cuelgan_de_conceptos_de_la_tienda() -> void:
	var game := _controller_game()
	for concept in ["cabeceras_http", "cookies_sesiones", "control_acceso"]:
		assert_false(game["controller"].review_mission_for(concept).is_empty(), "hay un reto de %s" % concept)
	game["controller"].scheduler.schedule("cookies_sesiones", "solucion", NOW - DAY)
	assert_eq(game["controller"].due_reviews(), ["cookies_sesiones"], "lo aprendido en la tienda se ofrece como repaso")
