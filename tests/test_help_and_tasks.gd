extends "res://tests/framework/test_case.gd"
## Ayuda integrada (--help, man, cheatsheet) y los objetivos que se demuestran en la terminal
## (stat, hallazgo, revisar, autoevaluación opcional).

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const CommandDocs := preload("res://engine/commands/command_docs.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")
const ObjectiveCheck := preload("res://engine/missions/objective_check.gd")
const ReportReview := preload("res://engine/missions/report_review.gd")

const BOOK_PATH := "res://data/missions/primer_contacto.json"


func _game() -> Dictionary:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	var engine := MissionEngine.new(MissionLoader.load_file(BOOK_PATH)["book"])
	var tracker := MissionTracker.new(engine)
	var session := ShellSession.new(world, CommandSet.create_registry(tracker))
	session.tracker = tracker
	return {"engine": engine, "session": session}


func _s() -> RefCounted:
	return _game()["session"]


func _out(s: RefCounted, line: String) -> String:
	return s.run(line).stdout


func _skip_to_mission(game: Dictionary, steps: Array) -> void:
	for line: String in steps:
		game["session"].run(line)


# --- --help, -h, help, man, cheatsheet ---

func test_help_largo_funciona_en_todas_las_herramientas() -> void:
	var s := _s()
	for command in ["ls", "cat", "grep", "find", "chmod", "stat", "nmap", "curl", "ping", "hallazgo", "revisar"]:
		var out := _out(s, "%s --help" % command)
		assert_true(out.begins_with("Uso: "), "%s --help muestra el uso" % command)
		assert_true("man %s" % command in out, "%s --help apunta a la ficha completa" % command)


func test_help_de_nmap_explica_las_opciones() -> void:
	var out := _out(_s(), "nmap --help")
	assert_true("-sn" in out and "-sV" in out and "-Pn" in out and "-p-" in out)
	assert_true("nmap -Pn 10.0.0.9" in out, "incluye ejemplos")


func test_dash_h_solo_es_ayuda_donde_lo_es_en_la_realidad() -> void:
	var s := _s()
	assert_true(_out(s, "nmap -h").begins_with("Uso: nmap"))
	assert_true(_out(s, "curl -h").begins_with("Uso: curl"))
	assert_true(_out(s, "ping -h").begins_with("Uso: ping"))
	assert_true("invalid option -- 'h'" in s.run("ls -h").stderr, "en ls -h es otra opción, no se pisa")
	assert_eq(_out(s, "echo --help"), "--help\n", "echo escribe lo que le pasas")
	assert_eq(_out(s, "echo -h"), "-h\n")


func test_help_con_nombre_de_comando() -> void:
	var s := _s()
	assert_true(_out(s, "help grep").begins_with("Uso: grep"))
	assert_eq(s.run("help nada").stderr, "help: no hay ayuda para 'nada'\n")
	assert_true("man <comando>" in _out(s, "help") and "cheatsheet" in _out(s, "help"))


func test_man_muestra_la_ficha_completa_con_limites() -> void:
	var s := _s()
	var page := _out(s, "man nmap")
	var flat := " ".join(page.replace("\n", " ").split(" ", false))  # las frases largas se parten en líneas
	assert_true(page.begins_with("NMAP(1)"))
	for section in ["USO", "OPCIONES", "EJEMPLOS", "NOTAS", "QUÉ NO PUEDES CONCLUIR", "VER TAMBIÉN"]:
		assert_true(section in page, "la ficha incluye %s" % section)
	assert_true("filtered" in flat and "no se puede saber" in flat)
	assert_true("Una versión (-sV) no prueba que haya una vulnerabilidad" in flat, "enseña qué NO concluir")
	assert_eq(s.run("man zzz").stderr, "No manual entry for zzz\n")
	assert_eq(s.run("man zzz").exit_code, 16)
	assert_true("What manual page do you want?" in s.run("man").stderr)


func test_cheatsheet_completa_y_por_tema() -> void:
	var s := _s()
	var all := _out(s, "cheatsheet")
	for title in ["ORIENTARTE", "LEER Y BUSCAR", "PERMISOS E IDENTIDAD", "RED Y RECONOCIMIENTO", "HTTP", "COMBINAR Y EDITAR", "TU CUADERNO"]:
		assert_true(title in all, "falta la sección %s" % title)
	var network := _out(s, "cheatsheet red")
	assert_true("nmap -Pn <host>" in network and "curl" not in network, "un tema solo muestra su sección")
	assert_true("Temas:" in s.run("cheatsheet nada").stderr)


func test_ver_la_ayuda_queda_registrado() -> void:
	var s := _s()
	s.run("nmap --help")
	s.run("man curl")
	var viewed: Array = []
	for event: Dictionary in s.events:
		if event["type"] == "help_viewed":
			viewed.append(event["tool"])
	assert_eq(viewed, ["nmap", "curl"])


func test_todos_los_comandos_registrados_tienen_ficha() -> void:
	var registry = CommandSet.create_registry(_game()["session"].tracker)
	for command_name in registry.names():
		assert_true(CommandDocs.has(command_name), "'%s' no tiene ficha de ayuda" % command_name)


func test_las_fichas_estan_bien_formadas() -> void:
	for command_name: String in CommandDocs.DOCS:
		var doc: Dictionary = CommandDocs.DOCS[command_name]
		assert_true(str(doc.get("usage", "")) != "" and str(doc.get("summary", "")) != "", "%s: uso y resumen" % command_name)
		assert_true(CommandDocs.man_page(command_name).length() > 40, "%s: man_page" % command_name)
		for see in doc.get("see_also", []):
			assert_true(CommandDocs.has(see), "%s: 'ver también' apunta a %s, que no existe" % [command_name, see])
		for example: Array in doc.get("examples", []):
			assert_eq(example.size(), 2, "%s: cada ejemplo es [comando, explicación]" % command_name)


# --- stat, groups e identidad ---

func test_stat_muestra_dueno_grupo_y_permisos() -> void:
	var s := _s()
	var out := _out(s, "stat /etc/shadow")
	assert_true("File: /etc/shadow" in out)
	assert_true("Access: (0640/-rw-r-----)" in out, "modo octal y simbólico")
	assert_true("Uid: (    0/    root)" in out and "Gid: (   42/  shadow)" in out)
	assert_true("regular file" in out)
	assert_true("directory" in _out(s, "stat /etc"))


func test_stat_errores() -> void:
	var s := _s()
	assert_eq(s.run("stat /nope").stderr, "stat: cannot statx '/nope': No such file or directory\n")
	assert_eq(s.run("stat /root/secreto.txt").stderr, "stat: cannot statx '/root/secreto.txt': Permission denied\n", "sin acceso al directorio no se puede ni consultar")
	assert_eq(s.run("stat").stderr, "stat: missing operand\n")


func test_groups_e_id_muestran_los_grupos() -> void:
	var s := _s()
	assert_eq(_out(s, "groups"), "ronin\n")
	assert_eq(_out(s, "id"), "uid=1000(ronin) gid=1000(ronin) groups=1000(ronin)\n")


func test_ls_l_y_stat_registran_el_archivo_consultado() -> void:
	var s := _s()
	s.run("ls -l /etc/shadow")
	s.run("stat nota.txt")
	s.run("ls /etc")  # sin -l no se consultan permisos
	var stats: Array = []
	for event: Dictionary in s.events:
		if event["type"] == "file_stat":
			stats.append(event["path"])
	assert_eq(stats, ["/etc/shadow", "/home/ronin/nota.txt"])


func test_whoami_id_y_groups_registran_la_identidad() -> void:
	var s := _s()
	s.run("whoami")
	s.run("id")
	s.run("groups")
	var tools: Array = []
	for event: Dictionary in s.events:
		if event["type"] == "identity_checked":
			tools.append(event["tool"])
	assert_eq(tools, ["whoami", "id", "groups"])


func test_eventos_de_red_nuevos() -> void:
	var s := _s()
	s.run("ping -c 1 10.0.0.9")
	s.run("curl web01:81")
	s.run("curl web01:8080")
	var types: Array = []
	for event: Dictionary in s.events:
		types.append(event["type"])
	assert_true("ping_no_reply" in types and "connection_refused" in types and "connection_timeout" in types)


# --- Criterio con texto ---

func test_criterio_contains_busca_terminos_sin_mayusculas() -> void:
	var events := [{"type": "finding_recorded", "kind": "indicio", "text": "Apache 2.4.49 en web01"}]
	assert_true(ObjectiveCheck.passes({"event": "finding_recorded", "contains": {"text": ["apache", "2.4"]}}, events))
	assert_false(ObjectiveCheck.passes({"event": "finding_recorded", "contains": {"text": ["apache", "nginx"]}}, events), "deben aparecer todos los términos")
	assert_true(ObjectiveCheck.passes({"event": "finding_recorded", "where": {"kind": ["indicio"]}, "contains": {"text": ["web01"]}}, events))


# --- hallazgo ---

func test_hallazgo_sin_argumentos_explica_los_tipos() -> void:
	var out := _out(_s(), "hallazgo")
	for kind in ["indicio", "hipotesis", "confirmado", "falso-positivo"]:
		assert_true(kind in out)
	assert_true("Todavía no has registrado ningún hallazgo" in out)


func test_hallazgo_valida_los_argumentos_y_guarda_el_cuaderno() -> void:
	var s := _s()
	assert_true("tipo desconocido 'grave'" in s.run("hallazgo grave 'algo'").stderr)
	assert_true("falta la descripción" in s.run("hallazgo indicio").stderr)
	s.run("hallazgo indicio 'una prueba cualquiera'")
	s.run("hallazgo hipótesis 'otra'")
	var book := _out(s, "hallazgo")
	assert_true("[INDICIO] una prueba cualquiera" in book and "[HIPOTESIS] otra" in book)


func test_hallazgo_da_feedback_de_clasificacion() -> void:
	var game := _game()
	_skip_to_mission(game, ["nmap -sV web01"])  # desbloquea m3_clasificar_version (misión 3 es la actual solo tras la 1 y 2)
	# La clasificación solo se evalúa en la misión actual: avanzamos hasta la misión 3.
	var fresh := _game()
	_skip_to_mission(fresh, ["cat nota.txt", "ls -a", "cat .hidden", "cat /etc/passwd", "cat /etc/shadow", "ls -l /etc/shadow", "id", "chmod 000 nota.txt", "cat nota.txt",
			"ping -c 2 web01", "nmap -sn 10.0.0.0/24", "cat /etc/hosts", "ping -c 2 10.0.0.9", "nmap -Pn 10.0.0.9"])
	assert_eq(fresh["engine"].mission_index, 2)
	var s: RefCounted = fresh["session"]
	s.run("nmap -sV web01")
	var too_much = s.run("hallazgo confirmado 'Apache 2.4.49 es vulnerable'")
	assert_eq(too_much.exit_code, 1)
	assert_true("No cuadra" in too_much.stdout and "prueba repetible" in too_much.stdout, "explica por qué no es 'confirmado'")
	assert_eq(fresh["engine"].status_of("m3_clasificar_version"), "pending", "una clasificación errónea no completa el objetivo")
	var right = s.run("hallazgo indicio 'Apache 2.4.49 en web01:80'")
	assert_eq(right.exit_code, 0)
	assert_true("Bien clasificado" in right.stdout)
	assert_eq(fresh["engine"].status_of("m3_clasificar_version"), "done")


func test_hallazgo_sobre_otro_tema_se_registra_sin_juicio() -> void:
	var s := _s()
	var result = s.run("hallazgo indicio 'algo sin relación con la misión'")
	assert_eq(result.exit_code, 0)
	assert_eq(result.stdout, "Hallazgo registrado como INDICIO: algo sin relación con la misión\n")


# --- Revisión de informe ---

func test_el_revisor_marca_lo_que_falta() -> void:
	var spec: Dictionary = MissionLoader.load_file(BOOK_PATH)["book"]["missions"][3]["objectives"][3]["report"]
	var weak := ReportReview.review("Hay un problema en el servidor, conviene mirarlo con calma y detenimiento en algún momento.", spec)
	assert_false(weak["complete"])
	var oks := 0
	for element: Dictionary in weak["elements"]:
		oks += 1 if element["ok"] else 0
	assert_eq(oks, 0, "ninguna palabra clave de ningún elemento")
	var strong := ReportReview.review("Archivo de configuración antiguo expuesto en /backup/config.old, accesible sin autenticación (GET devuelve 200) y con credenciales de base de datos. Recomendación: eliminarlo y rotar las credenciales.", spec)
	assert_true(strong["complete"])
	assert_eq(strong["warnings"], [])


func test_el_revisor_avisa_de_exageraciones_y_textos_cortos() -> void:
	var spec := {"min_chars": 50, "forbidden": ["hackead"], "elements": [{"id": "x", "label": "X", "any": ["alfa"]}]}
	var short := ReportReview.review("alfa", spec)
	assert_false(short["complete"])
	assert_true("demasiado corto" in short["warnings"][0])
	var boasting := ReportReview.review("alfa: el servidor ha sido hackeado por completo, un desastre sin paliativos absoluto", spec)
	assert_false(boasting["complete"], "un elemento presente no basta si exagera")
	assert_true("hackead" in boasting["warnings"][0])


func test_revisar_sin_informe_pendiente_da_error() -> void:
	assert_eq(_s().run("revisar").stderr, "revisar: ahora mismo no hay ningún informe que revisar.\n")


func _game_at_report() -> Dictionary:
	var game := _game()
	_skip_to_mission(game, ["cat nota.txt", "ls -a", "cat .hidden", "cat /etc/passwd", "cat /etc/shadow", "ls -l /etc/shadow", "id", "chmod 000 nota.txt", "cat nota.txt",
			"ping -c 2 web01", "nmap -sn 10.0.0.0/24", "cat /etc/hosts", "ping -c 2 10.0.0.9", "nmap -Pn 10.0.0.9",
			"nmap web01", "curl web01:81", "curl web01:8080", "nmap -sV web01", "hallazgo indicio 'Apache 2.4.49 en web01:80'", "nmap -Pn -sV 10.0.0.9",
			"curl web01/robots.txt", "curl web01/backup/", "curl web01/backup/config.old", "hallazgo confirmado 'config.old expuesto en /backup/config.old'"])
	return game


func test_revisar_el_informe_paso_a_paso() -> void:
	var game := _game_at_report()
	var s: RefCounted = game["session"]
	assert_eq(game["engine"].mission_index, 3)
	var first = s.run("revisar")
	assert_eq(first.exit_code, 1)
	assert_true("[ ] Qué es" in first.stdout and "[ ] Recomendación" in first.stdout, "el borrador inicial no cumple nada")
	s.run("echo 'Archivo de configuración expuesto en /backup/config.old, se obtiene con curl y da acceso a credenciales.' >> informe/borrador.md")
	var second = s.run("revisar")
	assert_true("[x] Qué es" in second.stdout and "[x] Dónde" in second.stdout)
	assert_true("[ ] Recomendación" in second.stdout, "aún falta la recomendación")
	assert_eq(game["engine"].status_of("m4_informe"), "pending")
	s.run("echo 'Recomendación: eliminar el archivo y rotar las credenciales.' >> informe/borrador.md")
	var done = s.run("revisar")
	assert_eq(done.exit_code, 0)
	assert_true("cumple la lista de comprobación" in done.stdout)
	assert_eq(game["engine"].status_of("m4_informe"), "done")
	assert_true(game["engine"].is_finished())


func test_revisar_rechaza_exagerar() -> void:
	var game := _game_at_report()
	var s: RefCounted = game["session"]
	s.run("echo 'Servidor hackeado: archivo de configuración en /backup/config.old con credenciales de base de datos obtenido con curl (GET 200). Recomendación: eliminarlo.' >> informe/borrador.md")
	var result = s.run("revisar")
	assert_eq(result.exit_code, 1)
	assert_true("afirmas algo que no has demostrado" in result.stdout)
	assert_eq(game["engine"].status_of("m4_informe"), "pending")


func test_revisar_errores_de_archivo() -> void:
	var game := _game_at_report()
	var s: RefCounted = game["session"]
	assert_eq(s.run("revisar /nope.md").stderr, "revisar: /nope.md: No such file or directory\n")
	assert_eq(s.run("revisar /home").stderr, "revisar: /home: Is a directory\n")
	assert_eq(s.run("revisar /etc/shadow").stderr, "revisar: /etc/shadow: Permission denied\n")


# --- Autoevaluación opcional ---

func test_las_preguntas_son_opcionales_y_no_bloquean_la_mision() -> void:
	var game := _game()
	_skip_to_mission(game, ["cat nota.txt", "ls -a", "cat .hidden", "cat /etc/passwd", "cat /etc/shadow", "ls -l /etc/shadow", "id", "chmod 000 nota.txt", "cat nota.txt"])
	assert_eq(game["engine"].mission_index, 1, "la misión se completa sin contestar la pregunta")
	assert_eq(game["engine"].status_of("m1_q_shadow"), "pending")
	assert_eq(game["engine"].xp, 650)


func test_la_autoevaluacion_de_una_mision_anterior_sigue_disponible() -> void:
	var game := _game()
	var s: RefCounted = game["session"]
	_skip_to_mission(game, ["cat nota.txt", "ls -a", "cat .hidden", "cat /etc/passwd", "cat /etc/shadow", "ls -l /etc/shadow", "id", "chmod 000 nota.txt", "cat nota.txt"])
	var xp_before: int = game["engine"].xp
	assert_true("PREGUNTA:" in s.run("responder").stdout, "la pregunta de la misión 1 sigue ahí aunque ya estés en la 2")
	var answer = s.run("responder 2")
	assert_true("Correcto." in answer.stdout)
	assert_eq(game["engine"].xp, xp_before + 50, "la autoevaluación da la mitad de XP")
	assert_eq(game["engine"].mission_index, 1, "contestarla tarde no mueve la misión actual")


func test_la_autoevaluacion_se_marca_como_opcional_en_la_mision() -> void:
	var s := _s()
	s.run("cat /etc/shadow")
	var overview := _out(s, "mision")
	assert_true("autoevaluación opcional" in overview)


func test_la_validacion_exige_explicar_las_clasificaciones_erroneas() -> void:
	var book: Dictionary = MissionLoader.load_file(BOOK_PATH)["book"].duplicate(true)
	var classify: Dictionary = book["missions"][2]["objectives"][3]["classify"]
	classify["feedback"].erase("confirmado")
	classify["accepted"] = ["raro"]
	var errors := " | ".join(MissionLoader.validate(book)["errors"])
	assert_true("clasificación desconocida 'raro'" in errors)
	var report_book: Dictionary = MissionLoader.load_file(BOOK_PATH)["book"].duplicate(true)
	report_book["missions"][3]["objectives"][3]["report"]["elements"] = []
	assert_true("necesita 'elements'" in " | ".join(MissionLoader.validate(report_book)["errors"]))
