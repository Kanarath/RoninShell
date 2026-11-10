extends "res://tests/framework/test_case.gd"
## `formacion` y las fichas de lo que RoninShell NO simula a propósito (explotación, escalada,
## post-explotación): solo información y enlaces a recursos reales, nada ejecutable.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const ConceptDocs := preload("res://engine/commands/concept_docs.gd")


func _session() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func test_formacion_explica_que_falta_y_da_recursos_reales() -> void:
	var s := _session()
	var out: String = s.run("formacion").stdout
	assert_true("FORMACIÓN" in out)
	for topic in ["Explotacion", "Escalada Privilegios", "Post Explotacion"]:
		assert_true(topic in out, "falta mencionar: %s" % topic)
	for resource in ["TryHackMe", "OverTheWire", "PortSwigger", "Hack The Box", "Kali"]:
		assert_true(resource in out, "falta el recurso: %s" % resource)
	assert_true("ilegal" in out.to_lower(), "deja claro que sin autorización es ilegal")


func test_formacion_no_ejecuta_nada_y_queda_registrado() -> void:
	var s := _session()
	var before: int = s.events.size()
	s.run("formacion")
	assert_eq(s.events.size(), before + 1, "solo el registro de ayuda vista, nada más")
	assert_eq(s.events[-1]["type"], "help_viewed")
	assert_eq(s.events[-1]["tool"], "formacion")


func test_los_temas_que_faltan_tienen_su_propia_ficha() -> void:
	for topic in ["explotacion", "escalada_privilegios", "post_explotacion"]:
		assert_true(ConceptDocs.has(topic), "falta la ficha de %s" % topic)
		var doc: Dictionary = ConceptDocs.CONCEPTS[topic]
		assert_true("NO lo simula" in doc["summary"], "%s: deja claro que no se simula" % topic)


func test_man_de_un_tema_que_falta_funciona_y_enlaza_a_formacion() -> void:
	var s := _session()
	var page: String = s.run("man explotacion").stdout
	assert_true(page.begins_with("EXPLOTACION (concepto)"))
	assert_true("formacion" in page)
	assert_true("QUÉ NO PUEDES CONCLUIR" in page and "CÓMO SE PREVIENE" in page)


func test_completar_toda_la_campana_apunta_a_formacion() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var root := scene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	for entry: Dictionary in root.CAMPAIGN:
		root.engines[entry["id"]].debug_skip_to(99)
	root._check_achievements()
	assert_true("formacion" in root.terminal.output_text())
	(Engine.get_main_loop() as SceneTree).root.remove_child(root)
	root.free()
