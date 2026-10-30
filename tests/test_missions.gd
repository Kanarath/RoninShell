extends "res://tests/framework/test_case.gd"
## Motor de misiones: comprobación de objetivos, pistas, XP, evidencias, perfil y guardado.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")
const ObjectiveCheck := preload("res://engine/missions/objective_check.gd")
const SaveStore := preload("res://game/save_store.gd")

const BOOK_PATH := "res://data/missions/primer_contacto.json"


# --- Un libro pequeño para probar las reglas aisladas -------------------------

func _mini_book() -> Dictionary:
	return {
		"id": "mini", "title": "Mini", "lab": "x",
		"missions": [
			{"id": "a", "title": "A", "briefing": "Misión A", "objectives": [
				{"id": "o1", "text": "Objetivo 1", "concept": "uno", "check": {"event": "e1"},
				 "evidence": {"id": "ev1", "title": "Prueba 1", "detail": "detalle"}, "hints": ["h1", "h2", "solución"]},
				{"id": "q1", "text": "Pregunta 1", "concept": "dos", "requires": ["o1"],
				 "question": {"prompt": "¿?", "options": [{"text": "mal", "why": "porque no"}, {"text": "bien", "why": "porque sí"}], "correct": 1},
				 "hints": ["h1", "h2", "solución"]},
			]},
			{"id": "b", "title": "B", "briefing": "Misión B", "objectives": [
				{"id": "o2", "text": "Objetivo 2", "concept": "tres", "transfer": true, "check": {"event": "e2"}, "hints": ["h1", "h2", "solución"]},
			]},
		],
	}


func _engine() -> RefCounted:
	return MissionEngine.new(_mini_book())


func _event(type: String, data := {}) -> Dictionary:
	var event: Dictionary = data.duplicate()
	event["type"] = type
	return event


# --- Criterios ---

func test_criterio_de_evento_con_filtros() -> void:
	var events := [_event("file_read", {"path": "/a"}), _event("file_read", {"path": "/b"})]
	assert_true(ObjectiveCheck.passes({"event": "file_read", "where": {"path": "/b"}}, events))
	assert_false(ObjectiveCheck.passes({"event": "file_read", "where": {"path": "/c"}}, events))
	assert_false(ObjectiveCheck.passes({"event": "otro"}, events))
	assert_true(ObjectiveCheck.passes({"event": "file_read", "where": {"path": ["/x", "/a"]}}, events), "una lista admite cualquiera de los valores")


func test_criterio_distinct_all_any() -> void:
	var events := [_event("seen", {"ip": "1"}), _event("seen", {"ip": "1"}), _event("seen", {"ip": "2"})]
	assert_true(ObjectiveCheck.passes({"event": "seen", "distinct": "ip", "min": 2}, events))
	assert_false(ObjectiveCheck.passes({"event": "seen", "distinct": "ip", "min": 3}, events))
	assert_true(ObjectiveCheck.passes({"event": "seen", "min": 3}, events), "sin distinct se cuentan todos los eventos")
	assert_true(ObjectiveCheck.passes({"all": [{"event": "seen"}, {"event": "seen", "where": {"ip": "2"}}]}, events))
	assert_false(ObjectiveCheck.passes({"all": [{"event": "seen"}, {"event": "nada"}]}, events))
	assert_true(ObjectiveCheck.passes({"any": [{"event": "nada"}, {"event": "seen"}]}, events))


func test_los_numeros_json_comparan_bien_con_enteros() -> void:
	var data = JSON.parse_string("{\"event\": \"p\", \"where\": {\"port\": 80}}")  # JSON da 80.0
	assert_true(ObjectiveCheck.passes(data, [_event("p", {"port": 80})]))


# --- Reglas del motor ---

func test_un_objetivo_se_completa_al_ver_el_evento() -> void:
	var m := _engine()
	assert_eq(m.update([]), [])
	var notifications: Array = m.update([_event("e1")])
	assert_eq(notifications[0]["type"], "objective")
	assert_eq(notifications[0]["xp"], 100)
	assert_eq(m.status_of("o1"), "done")
	assert_eq(m.xp, 100)


func test_las_preguntas_esperan_a_sus_requisitos_y_no_se_completan_solas() -> void:
	var m := _engine()
	assert_false(m.is_available(m.objectives()[1]))
	assert_eq(m.answer(2)["ok"], false, "no hay pregunta activa aún")
	m.update([_event("e1")])
	assert_true(m.is_available(m.objectives()[1]))
	assert_eq(m.active_question()["id"], "q1")
	m.update([_event("e1"), _event("lo-que-sea")])
	assert_eq(m.status_of("q1"), "pending", "una pregunta solo se completa respondiendo")


func test_responder_mal_no_penaliza_y_da_el_motivo() -> void:
	var m := _engine()
	m.update([_event("e1")])
	var wrong = m.answer(1)
	assert_true(wrong["ok"] and not wrong["correct"])
	assert_eq(wrong["message"], "porque no", "cada error enseña por qué no es esa")
	assert_eq(m.xp, 100, "fallar no resta XP")
	assert_eq(m.attempts_of("q1"), 1)
	var right = m.answer(2)
	assert_true(right["correct"])
	assert_eq(m.status_of("q1"), "done")
	assert_eq(m.xp, 200, "se puede acertar a la primera con el mismo XP que si hubieras fallado antes")


func test_opcion_fuera_de_rango() -> void:
	var m := _engine()
	m.update([_event("e1")])
	assert_false(m.answer(0)["ok"])
	assert_false(m.answer(9)["ok"])
	assert_eq(m.attempts_of("q1"), 0, "una opción inválida no cuenta como intento")


func test_pistas_progresivas_y_su_efecto_en_xp_y_dominio() -> void:
	var m := _engine()
	var first = m.request_hint(1)
	assert_eq([first["text"], first["level"], first["is_solution"]], ["h1", 1, false])
	var second = m.request_hint(1)
	assert_eq(second["text"], "h2")
	m.update([_event("e1")])
	assert_eq(m.mastery_of("o1"), "ayuda")
	assert_eq(m.xp, 70, "con pistas de orientación: menos XP, pero nunca cero")

	var solution = m.request_hint(2) # pregunta aún no disponible? ya lo está tras o1
	assert_true(solution["ok"])
	m.request_hint(2)
	var last = m.request_hint(2)
	assert_true(last["is_solution"], "la última pista es la solución explicada")
	assert_eq(m.request_hint(2)["level"], 3, "pedir más no pasa del último nivel")
	m.answer(2)
	assert_eq(m.mastery_of("q1"), "solucion")
	assert_eq(m.xp, 70 + 30)


func test_pistas_de_objetivos_no_validos() -> void:
	var m := _engine()
	assert_false(m.request_hint(0)["ok"])
	assert_false(m.request_hint(7)["ok"])
	assert_false(m.request_hint(2)["ok"], "la pregunta aún está bloqueada")
	m.update([_event("e1")])
	assert_false(m.request_hint(1)["ok"], "un objetivo ya completado no necesita pista")


func test_completar_la_mision_avanza_a_la_siguiente() -> void:
	var m := _engine()
	m.update([_event("e1")])
	var notifications: Array = m.answer(2)["notifications"]
	assert_eq(notifications[-1]["type"], "mission")
	assert_eq(m.mission_index, 1)
	assert_eq(m.current_mission()["title"], "B")
	m.update([_event("e2")])
	assert_true(m.is_finished())
	assert_eq(m.xp, 100 + 100 + 150, "el objetivo de transferencia vale 1,5 veces")


func test_las_pruebas_vistas_antes_cuentan_al_entrar_en_la_siguiente_mision() -> void:
	var m := _engine()
	var events := [_event("e1"), _event("e2")]  # el jugador ya había observado lo de la misión B
	m.update(events)
	m.answer(2)
	var later: Array = m.update(events)
	assert_true(m.is_finished(), "explorar por delante no se pierde")
	assert_true(later.size() >= 1)


func test_nivel_y_progreso() -> void:
	var m := _engine()
	assert_eq(m.level(), 1)
	m.xp = 150
	assert_eq(m.level_progress(), 0.5)
	m.xp = 300
	assert_eq(m.level(), 2)


func test_evidencias_se_reunen_al_completar() -> void:
	var m := _engine()
	assert_false(m.evidence_cards()[0]["collected"])
	m.update([_event("e1")])
	assert_true(m.evidence_cards()[0]["collected"])
	assert_eq(m.evidence_cards()[0]["title"], "Prueba 1")


func test_perfil_de_competencias_y_repaso() -> void:
	var m := _engine()
	m.update([_event("e1")])
	assert_eq(m.competency_profile()["uno"], {"solo": 1, "ayuda": 0, "solucion": 0})
	assert_eq(m.review_concepts(), [])
	m.request_hint(2)
	m.answer(2)
	assert_eq(m.competency_profile()["dos"]["ayuda"], 1)
	assert_eq(m.review_concepts(), ["dos"], "lo resuelto con ayuda queda para repasar")


func test_guardar_y_restaurar_el_progreso() -> void:
	var m := _engine()
	m.update([_event("e1")])
	m.request_hint(2)
	var saved = m.to_dict()
	var restored := _engine()
	assert_true(restored.load_dict(JSON.parse_string(JSON.stringify(saved))), "pasa por JSON, como en disco")
	assert_eq(restored.xp, 100)
	assert_eq(restored.status_of("o1"), "done")
	assert_eq(restored.hints_used("q1"), 1)
	assert_true(restored.evidence_cards()[0]["collected"])
	assert_false(MissionEngine.new({"id": "otro", "missions": []}).load_dict(saved), "un guardado de otro libro se rechaza")


func test_guardado_en_disco() -> void:
	var store := SaveStore.new("user://tests_roninshell_save.json")
	store.delete()
	assert_false(store.has_save())
	var m := _engine()
	m.update([_event("e1")])
	assert_true(store.save(m))
	var restored := _engine()
	assert_true(store.load_into(restored))
	assert_eq(restored.xp, 100)
	store.delete()
	assert_false(store.has_save())


# --- Validación del libro ---

func test_el_libro_real_es_valido() -> void:
	var loaded := MissionLoader.load_file(BOOK_PATH)
	assert_eq(loaded["errors"], [])
	assert_true(loaded["book"] != null)
	assert_eq(loaded["book"]["missions"].size(), 4)


func test_validacion_detecta_errores_del_libro() -> void:
	var book := _mini_book()
	book["missions"][0]["objectives"][0]["hints"] = ["solo una"]
	book["missions"][0]["objectives"][1]["question"]["correct"] = 9
	book["missions"][1]["objectives"][0]["requires"] = ["no_existe"]
	book["missions"][1]["objectives"][0]["check"] = {"nada": 1}
	var errors: Array = MissionLoader.validate(book)["errors"]
	var text := " | ".join(errors)
	assert_true("pistas" in text, "pocas pistas")
	assert_true("'correct'" in text, "índice de respuesta fuera de rango")
	assert_true("no_existe" in text, "requisito inexistente")
	assert_true("'check' no es válido" in text, "criterio inválido")
	assert_true(MissionLoader.validate(_mini_book())["book"] != null)


func test_validacion_ids_repetidos_y_objetivo_sin_tipo() -> void:
	var book := _mini_book()
	book["missions"][1]["objectives"][0]["id"] = "o1"
	book["missions"][0]["objectives"][0].erase("check")
	var text := " | ".join(MissionLoader.validate(book)["errors"])
	assert_true("repetido" in text)
	assert_true("'check' o 'question'" in text)


func test_todas_las_preguntas_del_libro_explican_todas_las_opciones() -> void:
	var book: Dictionary = MissionLoader.load_file(BOOK_PATH)["book"]
	for mission: Dictionary in book["missions"]:
		for objective: Dictionary in mission["objectives"]:
			if objective.has("question"):
				for option: Dictionary in objective["question"]["options"]:
					assert_true(str(option["why"]).length() > 20, "%s: cada opción debe explicar por qué" % objective["id"])
				var correct_text: String = objective["question"]["options"][int(objective["question"]["correct"])]["why"]
				assert_true(correct_text.begins_with("Correcto") or correct_text.begins_with("Exacto"), "%s: la opción correcta lo confirma" % objective["id"])


# --- Integración: el laboratorio real, jugado de principio a fin ---

func _game() -> Dictionary:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	var book: Dictionary = MissionLoader.load_file(BOOK_PATH)["book"]
	var engine := MissionEngine.new(book)
	var tracker := MissionTracker.new(engine)
	var session := ShellSession.new(world, CommandSet.create_registry(tracker))
	session.tracker = tracker
	return {"engine": engine, "session": session, "tracker": tracker}


func _play(game: Dictionary, lines: Array) -> Array:
	var notices: Array = []
	for line: String in lines:
		notices.append_array(game["session"].run(line).notices)
	return notices


func test_el_laboratorio_se_puede_completar_de_principio_a_fin() -> void:
	var game := _game()
	var engine: RefCounted = game["engine"]
	_play(game, ["cat nota.txt", "ls -a", "cat .hidden", "cat /etc/passwd", "cat /etc/shadow", "responder 2"])
	assert_eq(engine.mission_index, 1, "misión 1 completada")
	_play(game, ["ping -c 2 web01", "nmap -sn 10.0.0.0/24", "cat /etc/hosts", "responder 2"])
	assert_eq(engine.mission_index, 2, "misión 2 completada")
	_play(game, ["nmap -sV web01", "responder 3", "responder 2", "nmap -Pn 10.0.0.9"])
	assert_eq(engine.mission_index, 3, "misión 3 completada")
	_play(game, ["curl web01/robots.txt", "curl web01/backup/", "curl web01/backup/config.old", "responder 2"])
	assert_true(engine.is_finished(), "laboratorio completado")
	assert_eq(engine.xp, 16 * 100 + 150, "16 objetivos sin pistas (100 c/u) + el de transferencia (150)")
	var collected := 0
	for card: Dictionary in engine.evidence_cards():
		collected += 1 if card["collected"] else 0
	assert_eq(collected, engine.evidence_cards().size(), "todas las evidencias reunidas")
	assert_eq(engine.review_concepts(), [], "sin ayudas no queda nada que repasar")


func test_hay_varias_formas_de_resolver_cada_objetivo() -> void:
	var game := _game()
	_play(game, ["grep -n Red nota.txt"])
	assert_eq(game["engine"].status_of("m1_nota"), "done", "grep también lee la nota: se evalúa lo observado, no el comando")
	var other := _game()
	_play(other, ["head -1 nota.txt"])
	assert_eq(other["engine"].status_of("m1_nota"), "done")
	var by_find := _game()
	_play(by_find, ["find . -name '.h*'", "cat ./.hidden"])
	assert_eq(by_find["engine"].status_of("m1_oculto"), "done")


func test_no_hay_atajos_triviales() -> void:
	var game := _game()
	_play(game, ["ls", "pwd", "whoami", "cat /etc/hosts"])
	assert_eq(game["engine"].status_of("m1_nota"), "pending", "listar no es leer la nota")
	assert_eq(game["engine"].status_of("m1_usuarios"), "pending")
	var skipper := _game()
	var result = skipper["session"].run("responder 2")
	assert_eq(result.exit_code, 1, "no se puede responder preguntas sin haber investigado")
	assert_eq(skipper["engine"].xp, 0)


func test_los_comandos_de_juego_mision_pista_responder() -> void:
	var game := _game()
	var session: RefCounted = game["session"]
	var overview: String = session.run("mision").stdout
	assert_true("MISIÓN 1 de 4: Orientación" in overview)
	assert_true("[>] 1. Localiza y lee la nota" in overview, "el objetivo actual va marcado")
	assert_true("[-] 5." in overview, "la pregunta bloqueada se ve como bloqueada")

	var hint: String = session.run("pista").stdout
	assert_true("PISTA 1/3" in hint and "El prompt te dice dónde estás" in hint)
	assert_true("PISTA 2/3" in session.run("pista 1").stdout)
	assert_true("PISTA 3/3" in session.run("pista 1").stdout)
	assert_true("SOLUCIÓN EXPLICADA" in session.run("pista 1").stdout)
	assert_true("ya está completado" in session.run("pista 99").stderr or "No existe" in session.run("pista 99").stderr)

	var done_notices: Array = session.run("cat nota.txt").notices
	assert_true("[+] Objetivo completado" in done_notices[0])
	assert_true("con la solución" in done_notices[0], "se vio la solución: queda anotado")
	assert_eq(game["engine"].xp, 30)


func test_responder_muestra_la_pregunta_y_comenta_cada_error() -> void:
	var game := _game()
	var session: RefCounted = game["session"]
	_play(game, ["cat /etc/shadow"])
	var question: String = session.run("responder").stdout
	assert_true("PREGUNTA:" in question and "1) El archivo no existe." in question)
	var wrong = session.run("responder 1")
	assert_eq(wrong.exit_code, 1)
	assert_true("Todavía no." in wrong.stdout and "No such file or directory" in wrong.stdout, "explica por qué esa opción no vale")
	var right = session.run("responder b")
	assert_true("Correcto." in right.stdout, "también acepta letras")
	assert_true("[+] Objetivo completado" in right.notices[0])


func test_expediente_y_perfil() -> void:
	var game := _game()
	var session: RefCounted = game["session"]
	assert_true("EXPEDIENTE DE EVIDENCIAS (0/" in session.run("expediente").stdout)
	_play(game, ["cat nota.txt"])
	var dossier: String = session.run("expediente").stdout
	assert_true("[x] nota.txt: Red autorizada: 10.0.0.0/24" in dossier)
	assert_true("[ ] ???" in dossier, "lo que falta se ve como un hueco, sin revelar qué es")
	var profile: String = session.run("perfil").stdout
	assert_true("navegacion" in profile and "por tu cuenta: 1" in profile)


func test_las_ordenes_de_juego_aparecen_en_help_marcadas() -> void:
	var out: String = _game()["session"].run("help").stdout
	for command in ["mision", "pista", "responder", "expediente", "perfil"]:
		assert_true(command in out)
	assert_true("[juego]" in out)


func test_aviso_de_nueva_mision_y_de_nivel() -> void:
	var game := _game()
	var notices := _play(game, ["cat nota.txt", "ls -a", "cat .hidden", "cat /etc/passwd", "cat /etc/shadow", "responder 2"])
	var text := "\n".join(notices)
	assert_true("*** Misión completada: Orientación ***" in text)
	assert_true("Nueva misión: Quién está ahí" in text)
	assert_true("Nivel 2 alcanzado." in text, "500 XP superan los 300 del primer nivel")
