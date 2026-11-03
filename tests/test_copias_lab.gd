extends "res://tests/framework/test_case.gd"
## Sexto laboratorio, "Copias y recuperación": datos válidos, resoluble solo con comandos y sin atajos.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")

const BOOK := "res://data/missions/copias.json"
const LAB := "res://data/labs/copias.json"

const M1 := [
	"cat cliente.txt",
	"mkdir copias",
	"cp servicio/app.conf copias/app.conf.bak",
	"sha256sum servicio/app.conf copias/app.conf.bak",
]
const M2 := [
	"echo '# Configuración del servicio de notas\nmodo=produccion\ndebug=false\nretencion_dias=7' > servicio/app.conf",
	"diff copias/app.conf.bak servicio/app.conf",
	"ls servicio",
	"rm servicio/temporal.tmp",
	"cp servicio/notas.db copias/",
	"sha256sum servicio/notas.db copias/notas.db",
]
const M3 := [
	"cp copias/app.conf.bak servicio/app.conf",
	"if diff -q copias/app.conf.bak servicio/app.conf; then echo igual; else echo distinto; fi",
	"echo 'En archivo06 hice una copia de seguridad de servicio/app.conf en copias/ y verifiqué con sha256sum (misma huella) y diff. Tras el cambio de debug restauré la copia. Riesgo evitado: perder la configuración por sobrescribirla sin copia. Recomendación: copiar y verificar siempre antes de cambiar, guardar copias fuera del servidor y probar la restauración.' >> informe/borrador.md",
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


func test_se_resuelve_solo_con_comandos() -> void:
	var game := _game()
	_play(game, M1)
	assert_eq(game["engine"].mission_index, 1, "misión 1")
	_play(game, M2)
	assert_eq(game["engine"].mission_index, 2, "misión 2")
	_play(game, M3)
	assert_true(game["engine"].is_finished(), "misión 3")
	assert_eq(game["engine"].review_concepts(), [], "sin ayudas no queda nada que repasar")


func test_la_copia_sirve_para_volver_atras() -> void:
	var game := _game()
	var session: RefCounted = game["session"]
	var original: String = session.run("cat servicio/app.conf").stdout
	_play(game, M1)
	session.run("echo 'roto' > servicio/app.conf")
	session.run("cp copias/app.conf.bak servicio/app.conf")
	assert_eq(session.run("cat servicio/app.conf").stdout, original, "se restaura tal cual era")


func test_no_valen_los_atajos() -> void:
	var game := _game()
	_play(game, ["cat cliente.txt", "mkdir copias"])
	assert_eq(game["engine"].status_of("c4_huella"), "pending", "sin copia no hay huella que valga")
	_play(game, ["sha256sum servicio/app.conf servicio/notas.db"])
	assert_eq(game["engine"].status_of("c4_huella"), "pending", "antes hay que copiar app.conf")
	_play(game, ["cp servicio/app.conf copias/app.conf.bak"])
	assert_eq(game["engine"].status_of("c4_huella"), "done")


func test_borrar_otra_cosa_no_cuenta_como_limpiar_el_temporal() -> void:
	var game := _game()
	_play(game, M1)
	_play(game, ["echo 'debug=false' > servicio/app.conf", "rm servicio/notas.db"])
	assert_eq(game["engine"].status_of("c7_temporal"), "pending", "borrar notas.db no es limpiar el temporal")
	_play(game, ["rm servicio/temporal.tmp"])
	assert_eq(game["engine"].status_of("c7_temporal"), "done")


func test_el_informe_pide_verificacion_y_recomendacion() -> void:
	var game := _game()
	_play(game, M1 + M2)
	_play(game, ["cp copias/app.conf.bak servicio/app.conf", "if diff -q copias/app.conf.bak servicio/app.conf; then echo ok; fi"])
	_play(game, ["echo 'En archivo06 hice una copia de seguridad y la restauré.' >> informe/borrador.md", "revisar"])
	assert_false(game["engine"].is_finished(), "sin verificación, riesgo ni recomendación no pasa")
