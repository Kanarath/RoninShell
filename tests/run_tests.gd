extends SceneTree
## Runner de tests en modo consola.
##
## Uso:  godot --headless --path . --script res://tests/run_tests.gd
## (o simplemente  .\run_tests.ps1 )
##
## Descubre tests/test_*.gd, ejecuta cada método test_* y sale con código 1
## si algo falla, para que se pueda usar en automatizaciones.

const TESTS_DIR := "res://tests"


## Los tests se ejecutan en el primer fotograma (y no en _init): hasta entonces el
## árbol de escenas no está activo y los nodos añadidos al root no reciben _ready.
func _initialize() -> void:
	# Los tests nunca leen ni escriben tu progreso real.
	Engine.set_meta("roninshell_no_save", true)
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func _run_all() -> void:
	var total := 0
	var failed := 0

	for file_name in _find_test_files():
		var script: GDScript = load("%s/%s" % [TESTS_DIR, file_name])
		# Un script con error de sintaxis se carga pero no se puede instanciar:
		# lo contamos como fallo en vez de dejar el runner colgado.
		if script == null or not script.can_instantiate():
			print("  FALLO %s (no se pudo cargar: revisa errores de sintaxis)" % file_name)
			total += 1
			failed += 1
			continue

		var probe = script.new()
		for method in probe.get_method_list():
			var test_name: String = method["name"]
			if not test_name.begins_with("test_"):
				continue

			# Instancia nueva por test: ningún test hereda estado de otro.
			var test_case = script.new()
			total += 1
			test_case.call(test_name)

			if test_case.assertions == 0:
				test_case.fail("el test no hizo ninguna comprobación (¿abortó por un error?)")

			if test_case.failures.is_empty():
				print("  ok    %s::%s" % [file_name, test_name])
			else:
				failed += 1
				print("  FALLO %s::%s" % [file_name, test_name])
				for message in test_case.failures:
					print("        - %s" % message)

	print("")
	if failed == 0:
		print("%d tests, todo correcto." % total)
	else:
		print("%d tests, %d con fallos." % [total, failed])
	quit(1 if failed > 0 else 0)


func _find_test_files() -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		return files
	for file_name in dir.get_files():
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			files.append(file_name)
	files.sort()
	return files
