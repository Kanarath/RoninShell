extends "res://tests/framework/test_case.gd"
## `repaso examen`: un reto de cada bloque grande, encadenados, con resumen final.

const Profile := preload("res://engine/profile.gd")


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


## Una solución real para cada bloque del examen (las mismas que ya prueba cada repaso suelto).
const SOLUTIONS := {
	"permisos": ["ls -l /srv", "id"],
	"descubrimiento_hosts": ["ping -c 2 db02", "nmap -Pn db02"],
	"cookies_sesiones": [
		"curl -i -d 'usuario=cliente1&clave=prueba456' portal01:8080/acceso",
		"curl -b 'sid=ses-cli1-77b2' portal01:8080/mi-cuenta",
	],
	"analisis_logs": ["grep ' 500' /var/log/app/access.log | wc -l"],
	"bucles": ["for s in $(cat servicios.txt); do echo $s; grep $s /var/log/app/error.log | wc -l; done"],
	"configuracion_segura": ["echo 'AccesoAnonimo no' > copias/servicio.conf"],
}


func test_los_conceptos_del_examen_tienen_todos_un_reto_de_repaso() -> void:
	var root := _main()
	for concept: String in Profile.EXAM_CONCEPTS:
		assert_false(root.controller.review_mission_for(concept).is_empty(), "falta el reto de repaso de '%s'" % concept)
		assert_true(SOLUTIONS.has(concept), "falta la solución de prueba de '%s'" % concept)
	_dispose(root)


func test_el_examen_encadena_todos_los_bloques_y_resume_al_final() -> void:
	var root := _main()
	var xp_before: int = root.main_engine.xp

	_run(root, ["repaso examen"])
	assert_eq(root.controller.mode, "repaso")
	assert_true(root.controller.exam_active)
	assert_eq(root.controller.exam_queue.size(), Profile.EXAM_CONCEPTS.size() - 1)

	for concept: String in Profile.EXAM_CONCEPTS:
		assert_eq(root.controller.current_review_concept, concept, "bloque esperado: %s" % concept)
		_run(root, SOLUTIONS[concept])

	assert_eq(root.controller.mode, "mision", "al acabar el último bloque se vuelve a la misión")
	assert_false(root.controller.exam_active)
	assert_eq(root.controller.exam_queue.size(), 0)
	assert_eq(root.controller.exam_results.size(), 0, "el resumen se limpia al terminar")
	assert_eq(root.main_engine.xp, xp_before + Profile.EXAM_CONCEPTS.size() * root.REVIEW_XP)
	assert_true("EXAMEN FINAL" in root.terminal.output_text())
	assert_true("%d de %d superados" % [Profile.EXAM_CONCEPTS.size(), Profile.EXAM_CONCEPTS.size()] in root.terminal.output_text())
	for concept: String in Profile.EXAM_CONCEPTS:
		assert_true("[x]" in root.terminal.output_text() and concept.replace("_", " ") in root.terminal.output_text())
	assert_true(root.session == root.main_session, "se recupera tu laboratorio tal como lo dejaste")
	_dispose(root)


func test_salir_a_medias_de_un_examen_lo_deja_sin_terminar() -> void:
	var root := _main()
	_run(root, ["repaso examen"])
	var first: String = root.controller.current_review_concept
	_run(root, SOLUTIONS[first])
	assert_true(root.controller.exam_active, "el examen sigue, quedan más bloques")
	_run(root, ["repaso salir"])
	assert_eq(root.controller.mode, "mision")
	assert_false(root.controller.exam_active)
	assert_eq(root.controller.exam_queue.size(), 0)
	_dispose(root)


func test_un_fallo_con_solucion_no_corta_el_examen() -> void:
	var root := _main()
	_run(root, ["repaso examen"])
	var first: String = root.controller.current_review_concept
	_run(root, ["pista", "pista", "pista"])   # la última pista es la solución explicada
	assert_eq(root.controller.current_review_concept, first)
	_run(root, SOLUTIONS[first])
	assert_true(root.controller.exam_active, "sigue en el examen aunque este bloque se viera con la solución")
	assert_eq(root.controller.exam_results[0]["concept"], first)
	assert_false(root.controller.exam_results[0]["passed"], "viendo la solución no cuenta como superado")
	_dispose(root)


func test_no_se_puede_iniciar_un_examen_dentro_de_otro_repaso() -> void:
	var root := _main()
	_run(root, ["repaso iniciar permisos"])
	var result: RefCounted = root.session.run("repaso examen")
	assert_true("ya estás en un repaso" in result.stderr)
	_dispose(root)
