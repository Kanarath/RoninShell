extends "res://tests/framework/test_case.gd"
## Fichas de conceptos (man dns, man xss...): bien formadas, enlazadas y accesibles desde man.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const CommandDocs := preload("res://engine/commands/command_docs.gd")
const ConceptDocs := preload("res://engine/commands/concept_docs.gd")


func _session() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func test_los_conceptos_disponibles() -> void:
	assert_eq(ConceptDocs.topics(), ["cabeceras", "control_acceso", "cookies", "dns", "escalada_privilegios", "explotacion", "path_traversal", "post_explotacion", "tls", "xss"])


func test_cada_ficha_tiene_lo_necesario_y_es_defensiva() -> void:
	for topic: String in ConceptDocs.CONCEPTS:
		var doc: Dictionary = ConceptDocs.CONCEPTS[topic]
		assert_true(str(doc.get("summary", "")) != "", "%s: resumen" % topic)
		assert_false(doc.get("notes", []).is_empty(), "%s: explica qué es" % topic)
		assert_false(doc.get("dont_conclude", []).is_empty(), "%s: enseña qué NO concluir" % topic)
		assert_false(doc.get("defense", []).is_empty(), "%s: explica cómo se previene" % topic)


func test_los_enlaces_ver_tambien_apuntan_a_algo_que_existe() -> void:
	for topic: String in ConceptDocs.CONCEPTS:
		for see in ConceptDocs.CONCEPTS[topic].get("see_also", []):
			assert_true(ConceptDocs.has(see) or CommandDocs.has(see), "%s enlaza a '%s', que no existe" % [topic, see])


func test_man_muestra_un_concepto_con_sus_secciones() -> void:
	var s := _session()
	var page: String = s.run("man cookies").stdout
	assert_true(page.begins_with("COOKIES (concepto)"))
	for section in ["QUÉ ES Y POR QUÉ PASA", "QUÉ MIRA UN AUDITOR", "QUÉ NO PUEDES CONCLUIR", "CÓMO SE PREVIENE", "VER TAMBIÉN"]:
		assert_true(section in page, "falta %s" % section)
	assert_true("HttpOnly" in page)


func test_man_de_un_comando_sigue_funcionando_y_lo_desconocido_lista_conceptos() -> void:
	var s := _session()
	assert_true(s.run("man nmap").stdout.begins_with("NMAP(1)"))
	var unknown = s.run("man zzz")
	assert_eq(unknown.exit_code, 16)
	assert_true("Conceptos disponibles:" in unknown.stderr and "xss" in unknown.stderr)


func test_ver_un_concepto_queda_registrado() -> void:
	var s := _session()
	s.run("man dns")
	assert_eq(s.events[-1]["tool"], "dns")
	assert_eq(s.events[-1]["type"], "help_viewed")


func test_las_fichas_caben_en_la_terminal() -> void:
	for topic in ConceptDocs.topics():
		for line in ConceptDocs.page(topic).split("\n"):
			assert_true(line.length() <= CommandDocs.WIDTH + 2, "%s: línea demasiado larga (%d): %s" % [topic, line.length(), line])
