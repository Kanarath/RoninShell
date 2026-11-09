extends "res://tests/framework/test_case.gd"
## Décimo laboratorio, "Auditoría de cabeceras web": datos válidos, resoluble solo con comandos y sin atajos.
## Todo es observación (GET/HEAD): nada de formularios ni de intentos de acceso.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")

const BOOK := "res://data/missions/cabeceras.json"
const LAB := "res://data/labs/cabeceras.json"

const M1 := [
	"cat cliente.txt",
	"curl -I portal",
	"curl -I portal/legacy",
	"hallazgo confirmado '/legacy no tiene Content-Security-Policy ni Strict-Transport-Security, a diferencia de /'",
]
const M2 := [
	"curl portal/robots.txt",
	"curl portal/legacy/export",
	"hallazgo confirmado '/legacy/export responde 200 sin estar enlazada ni requerir sesión'",
	"hallazgo hipotesis 'el panel heredado se olvidó retirar al migrar al nuevo portal'",
]
const M3 := [
	"if curl -I portal/legacy | grep Content-Security-Policy; then echo presente; else echo ausente; fi",
	"echo 'La ruta /legacy no tiene Content-Security-Policy ni Strict-Transport-Security, a diferencia de /. Además, /legacy/export responde 200 sin estar enlazada ni requerir sesión, según robots.txt y curl. Riesgo: información interna accesible sin control. Prioridad: cerrar o proteger /legacy/export primero, por ser una ruta entera expuesta, y después añadir las cabeceras que faltan. Se recomienda requerir sesión en /legacy/export, configurar las cabeceras de seguridad y retirar el panel heredado si ya no se usa.' >> informe/borrador.md",
	"revisar",
]


func _game() -> Dictionary:
	var world = LabLoader.load_file(LAB)["world"]
	var engine := MissionEngine.new(MissionLoader.load_file(BOOK)["book"])
	var tracker := MissionTracker.new(engine)
	var session := ShellSession.new(world, CommandSet.create_registry(tracker))
	session.tracker = tracker
	return {"engine": engine, "session": session}


func _play(game: Dictionary, lines: Array) -> void:
	for line: String in lines:
		game["session"].run(line)


func test_los_datos_son_validos() -> void:
	assert_eq(MissionLoader.load_file(BOOK)["errors"], [])
	assert_eq(LabLoader.load_file(LAB)["errors"], [])


func test_las_cabeceras_son_las_de_las_pistas() -> void:
	var s: RefCounted = _game()["session"]
	var ok: String = s.run("curl -I portal").stdout
	for header in ["Content-Security-Policy", "X-Frame-Options", "X-Content-Type-Options", "Strict-Transport-Security"]:
		assert_true(header in ok, "falta %s en /: %s" % [header, ok])
	var legacy: String = s.run("curl -I portal/legacy").stdout
	for header in ["Content-Security-Policy", "X-Frame-Options", "X-Content-Type-Options", "Strict-Transport-Security"]:
		assert_false(header in legacy, "/legacy no debería tener %s: %s" % [header, legacy])
	assert_eq(s.run("curl portal/legacy/export").exit_code, 0)


func test_se_resuelve_solo_con_comandos() -> void:
	var game := _game()
	_play(game, M1)
	assert_eq(game["engine"].mission_index, 1, "misión 1")
	_play(game, M2)
	assert_eq(game["engine"].mission_index, 2, "misión 2")
	_play(game, M3)
	assert_true(game["engine"].is_finished(), "misión 3")
	assert_eq(game["engine"].review_concepts(), [], "sin ayudas no queda nada que repasar")


func test_no_valen_los_atajos() -> void:
	var game := _game()
	_play(game, ["cat cliente.txt", "curl -I portal"])
	assert_eq(game["engine"].status_of("h3_legacy"), "pending", "las misiones se juegan en orden")
	_play(game, ["curl -I portal/legacy"])
	assert_eq(game["engine"].status_of("h3_legacy"), "done")


func test_confundir_hecho_y_suposicion_se_explica() -> void:
	var game := _game()
	_play(game, M1 + [M2[0], M2[1], M2[2]])
	_play(game, ["hallazgo confirmado 'el panel heredado se olvido retirar'"])
	assert_eq(game["engine"].status_of("h8_transfer"), "pending", "la causa no está confirmada por ninguna respuesta")


func test_el_informe_pide_prioridad_y_medidas() -> void:
	var game := _game()
	_play(game, M1 + M2)
	_play(game, ["if curl -I portal/legacy | grep Content-Security-Policy; then echo ok; else echo no; fi"])
	_play(game, ["echo 'Al panel heredado le faltan cabeceras.' >> informe/borrador.md", "revisar"])
	assert_false(game["engine"].is_finished(), "sin prioridad, evidencia ni medidas no pasa")
