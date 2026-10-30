extends "res://tests/framework/test_case.gd"
## Perfil de competencias, árbol de habilidades y logros.

const Profile := preload("res://engine/profile.gd")
const SkillTree := preload("res://ui/widgets/skill_tree.gd")
const ProfilePanel := preload("res://ui/widgets/profile_panel.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const Missions := preload("res://tests/test_missions.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _engines() -> Dictionary:
	return {
		"primer_contacto": MissionEngine.new(MissionLoader.load_file("res://data/missions/primer_contacto.json")["book"]),
		"tienda_web": MissionEngine.new(MissionLoader.load_file("res://data/missions/tienda_web.json")["book"]),
	}


func _event(type: String, data := {}) -> Dictionary:
	var event: Dictionary = data.duplicate()
	event["type"] = type
	return event


func _achieved(engines: Dictionary, stats := {}) -> Array[String]:
	return Profile.unlocked_ids(Profile.evaluate(engines, stats))


func _main() -> Control:
	var root := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_tree().root.add_child(root)
	return root


func _dispose(root: Control) -> void:
	_tree().root.remove_child(root)
	root.free()


# --- Árbol de habilidades ---

func test_el_arbol_cubre_los_conceptos_de_todas_las_misiones() -> void:
	var in_tree := {}
	for group: Dictionary in Profile.TREE:
		for concept: Array in group["concepts"]:
			in_tree[concept[0]] = true
	var engines := _engines()
	for engine: RefCounted in engines.values():
		for mission: Dictionary in engine.book["missions"]:
			for objective: Dictionary in mission["objectives"]:
				assert_true(in_tree.has(objective["concept"]), "el concepto '%s' no aparece en el árbol de habilidades" % objective["concept"])


func test_los_niveles_de_concepto_siguen_la_peor_ayuda() -> void:
	var engines := _engines()
	assert_eq(Profile.concept_levels(engines), {}, "sin progreso no hay nada iluminado")
	engines["primer_contacto"].update([_event("file_read", {"path": "/home/ronin/nota.txt"})])
	assert_eq(Profile.concept_levels(engines)["navegacion"], "solo")
	engines["primer_contacto"].request_hint(2)
	engines["primer_contacto"].update([_event("file_read", {"path": "/home/ronin/.hidden"})])
	assert_eq(Profile.concept_levels(engines)["archivos_ocultos"], "ayuda")
	for i in 4:   # las 4 pistas, la última es la solución explicada
		engines["primer_contacto"].request_hint(3)
	engines["primer_contacto"].update([_event("file_read", {"path": "/etc/passwd"})])
	assert_eq(Profile.concept_levels(engines)["usuarios"], "solucion")
	assert_eq(Profile.concept_counts(engines)["navegacion"], 1)


func test_un_concepto_con_varios_objetivos_muestra_el_peor_resultado() -> void:
	var engines := _engines()
	var engine: RefCounted = engines["primer_contacto"]
	engine.update([_event("file_read", {"path": "/home/ronin/nota.txt"}), _event("permission_denied", {"path": "/etc/shadow"})])
	assert_eq(Profile.concept_levels(engines)["permisos"], "solo")
	engine.request_hint(5)
	engine.update([_event("file_stat", {"path": "/etc/shadow"}), _event("identity_checked")])
	assert_true(Profile.concept_levels(engines).has("permisos"))


func test_el_arbol_dibuja_con_y_sin_progreso() -> void:
	var tree := SkillTree.new()
	_tree().root.add_child(tree)
	tree.size = Vector2(520, 380)
	tree.notification(CanvasItem.NOTIFICATION_DRAW)
	tree.show_levels({"navegacion": "solo", "permisos": "ayuda", "http": "solucion"}, {"navegacion": 2})
	tree.notification(CanvasItem.NOTIFICATION_DRAW)
	assert_eq(tree.level_of("navegacion"), "solo")
	assert_eq(tree.level_of("informe"), "", "lo que no has hecho está sin iluminar")
	_tree().root.remove_child(tree)
	tree.free()


# --- Logros ---

func test_sin_progreso_no_hay_logros() -> void:
	assert_eq(_achieved(_engines()), [])


func test_primer_paso_y_por_tu_cuenta() -> void:
	var engines := _engines()
	engines["primer_contacto"].update([_event("file_read", {"path": "/home/ronin/nota.txt"})])
	assert_eq(_achieved(engines), ["primer_paso"])
	engines["primer_contacto"].update([_event("file_read", {"path": "/home/ronin/nota.txt"}), _event("file_read", {"path": "/home/ronin/.hidden"}),
			_event("file_read", {"path": "/etc/passwd"}), _event("permission_denied", {"path": "/etc/shadow"}),
			_event("file_stat", {"path": "/etc/shadow"}), _event("identity_checked")])
	assert_true("por_tu_cuenta" in _achieved(engines), "5 objetivos sin ayuda")


func test_mision_limpia_exige_no_usar_ayuda() -> void:
	var engines := _engines()
	engines["primer_contacto"].debug_skip_to(1)   # misión 1 completada "por tu cuenta"
	assert_true("mision_limpia" in _achieved(engines))
	var helped := _engines()
	helped["primer_contacto"].request_hint(1)
	helped["primer_contacto"].debug_skip_to(1)
	helped["primer_contacto"].request_hint(1)
	assert_true("mision_limpia" in _achieved(helped), "el salto de prueba marca todo como 'solo'")
	var real := _engines()
	var m: RefCounted = real["primer_contacto"]
	m.request_hint(1)
	m.update([_event("file_read", {"path": "/home/ronin/nota.txt"}), _event("file_read", {"path": "/home/ronin/.hidden"}),
			_event("file_read", {"path": "/etc/passwd"}), _event("permission_denied", {"path": "/etc/shadow"}),
			_event("file_stat", {"path": "/etc/shadow"}), _event("identity_checked"),
			_event("mode_changed", {"path": "/home/ronin/nota.txt", "owner_read": false}), _event("permission_denied", {"path": "/home/ronin/nota.txt"})])
	assert_eq(m.mission_index, 1, "la misión 1 está completa")
	assert_false("mision_limpia" in _achieved(real), "pedir una pista rompe el logro")


func test_transferencia_y_sin_miedo_a_equivocarte() -> void:
	var engines := _engines()
	var m: RefCounted = engines["primer_contacto"]
	m.update([_event("file_read", {"path": "/home/ronin/nota.txt"}), _event("file_read", {"path": "/home/ronin/.hidden"}),
			_event("file_read", {"path": "/etc/passwd"}), _event("permission_denied", {"path": "/etc/shadow"}),
			_event("file_stat", {"path": "/etc/shadow"}), _event("identity_checked")])
	assert_false("transferencia" in _achieved(engines))
	m.update([_event("file_read", {"path": "/home/ronin/nota.txt"}), _event("mode_changed", {"path": "/home/ronin/nota.txt", "owner_read": false}),
			_event("permission_denied", {"path": "/home/ronin/nota.txt"})])
	assert_true("transferencia" in _achieved(engines))
	assert_false("sin_miedo" in _achieved(engines))
	m.answer(1)                                   # respuesta equivocada (la autoevaluación está disponible)
	assert_eq(m.attempts_of("m1_q_shadow"), 1)
	m.answer(2)
	assert_true("sin_miedo" in _achieved(engines), "completar tras fallar cuenta")
	assert_false("cabeza_fria" in _achieved(engines), "no se acertó a la primera")


func test_cabeza_fria_acierta_a_la_primera() -> void:
	var engines := _engines()
	var m: RefCounted = engines["primer_contacto"]
	m.update([_event("permission_denied", {"path": "/etc/shadow"})])
	m.answer(2)
	assert_true("cabeza_fria" in _achieved(engines))
	assert_false("sin_miedo" in _achieved(engines))


func test_laboratorios_completados_y_nivel() -> void:
	var engines := _engines()
	engines["primer_contacto"].debug_skip_to(99)
	assert_true("primer_laboratorio" in _achieved(engines))
	assert_false("auditoria_completa" in _achieved(engines))
	engines["tienda_web"].debug_skip_to(99)
	assert_true("auditoria_completa" in _achieved(engines))
	assert_false("nivel_5" in _achieved(engines))
	engines["primer_contacto"].award_xp(1200)
	assert_true("nivel_5" in _achieved(engines), "el nivel cuenta el XP de todos los laboratorios")


func test_detective_y_memoria_de_acero() -> void:
	var engines := _engines()
	engines["primer_contacto"].debug_skip_to(99)
	assert_true("detective" in _achieved(engines), "con todas las evidencias del primer laboratorio hay más de 10")
	assert_false("memoria" in _achieved(engines, {"review_passes": 2}))
	assert_true("memoria" in _achieved(engines, {"review_passes": 3}))


func test_todos_los_logros_tienen_titulo_y_descripcion() -> void:
	var ids := {}
	for item: Dictionary in Profile.evaluate(_engines(), {}):
		assert_true(str(item["title"]) != "" and str(item["description"]) != "")
		assert_false(ids.has(item["id"]), "id repetido")
		ids[item["id"]] = true
	assert_eq(ids.size(), Profile.ACHIEVEMENTS.size())


# --- Panel de perfil ---

func test_el_panel_muestra_resumen_y_todos_los_logros() -> void:
	var panel := ProfilePanel.new()
	_tree().root.add_child(panel)
	var engines := _engines()
	panel.refresh("NV 1 · 0 XP", Profile.concept_levels(engines), Profile.concept_counts(engines), Profile.evaluate(engines, {}))
	assert_eq(panel.shown_achievements().size(), Profile.ACHIEVEMENTS.size())
	assert_true("Primer paso" in panel.shown_achievements())
	panel.open()
	assert_true(panel.is_open())
	_tree().root.remove_child(panel)
	panel.free()


# --- Integrado en el juego ---

func test_f3_abre_el_perfil_con_el_progreso_real() -> void:
	var root := _main()
	root.terminal.submit("cat nota.txt")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_F3
	root._unhandled_input(key)
	assert_true(root.profile_panel.is_open())
	assert_false(root.terminal.typing_enabled)
	assert_eq(root.profile_panel.tree.level_of("navegacion"), "solo")
	root._input(_escape())
	assert_false(root.profile_panel.is_open())
	assert_true(root.terminal.typing_enabled)
	_dispose(root)


func _escape() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	return event


func test_un_logro_se_anuncia_una_sola_vez() -> void:
	var root := _main()
	root.terminal.submit("cat nota.txt")
	var out: String = root.terminal.output_text()
	assert_true("Logro desbloqueado: Primer paso" in out)
	root.terminal.submit("pwd")
	root.terminal.submit("ls")
	assert_eq(root.terminal.output_text().count("Logro desbloqueado: Primer paso"), 1)
	assert_true("primer_paso" in root._unlocked)
	_dispose(root)


func test_los_logros_y_las_estadisticas_se_guardan_y_se_restauran() -> void:
	var root := _main()
	root.terminal.submit("cat nota.txt")
	root._stats["review_passes"] = 2
	var saved: Dictionary = JSON.parse_string(JSON.stringify(root.campaign_to_dict()))
	assert_true("primer_paso" in saved["achievements"])
	assert_eq(saved["stats"]["review_passes"], 2)
	var other := _main()
	other.load_campaign(saved)
	assert_true("primer_paso" in other._unlocked)
	assert_eq(other._stats["review_passes"], 2)
	other.terminal.submit("cat nota.txt")
	assert_false("Logro desbloqueado: Primer paso" in other.terminal.output_text(), "lo ya conseguido no se vuelve a anunciar")
	_dispose(root)
	_dispose(other)


func test_un_guardado_anterior_a_los_logros_no_los_anuncia_de_golpe() -> void:
	var root := _main()
	var data: Dictionary = root.engines["primer_contacto"].to_dict()
	root.engines["primer_contacto"].debug_skip_to(2)
	data = {"campaign": {"primer_contacto": root.engines["primer_contacto"].to_dict()}, "active_book": "primer_contacto"}
	var other := _main()
	other.load_campaign(data)
	assert_true(other._unlocked.size() >= 2, "lo ya cumplido queda registrado en silencio")
	assert_false("Logro desbloqueado" in other.terminal.output_text())
	_dispose(root)
	_dispose(other)


func test_aprobar_un_repaso_suma_a_las_estadisticas_y_un_salto_de_prueba_no_anuncia() -> void:
	var root := _main()
	root.debug_panel.press("Misión 2: Quién está ahí")
	assert_false("Logro desbloqueado" in root.terminal.output_text(), "saltar no es conseguirlo")
	assert_true("primer_paso" in root._unlocked)
	root.debug_panel.press("Repaso: permisos")
	root.terminal.submit("ls -l /srv")
	root.terminal.submit("id")
	assert_eq(root._stats["review_passes"], 1)
	_dispose(root)


func test_nueva_partida_borra_logros_y_estadisticas() -> void:
	var root := _main()
	root.terminal.submit("cat nota.txt")
	root._stats["review_passes"] = 3
	root._new_game()
	assert_eq(root._unlocked, [])
	assert_eq(root._stats["review_passes"], 0)
	_dispose(root)
