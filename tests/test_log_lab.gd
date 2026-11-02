extends "res://tests/framework/test_case.gd"
## Laboratorio "Guardia de logs": datos válidos, resoluble solo con comandos y sin atajos.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")

const BOOK := "res://data/missions/guardia_logs.json"
const LAB := "res://data/labs/guardia_logs.json"

const M1 := [
	"cat cliente.txt",
	"cat /var/log/auth.log",
	"grep 'Failed password' /var/log/auth.log | wc -l",
	"hallazgo confirmado '6 intentos fallidos de contraseña desde 203.0.113.7 en 14 segundos'",
]
const M2 := [
	"IP=203.0.113.7",
	"for ip in $(cat vigilar.txt); do echo $ip; grep \"Failed password.*$ip\" /var/log/auth.log | wc -l; done",
	"hallazgo falso-positivo '192.168.1.5: un fallo y acceso aceptado después, parece un despiste'",
]
const M3 := [
	"test -f /var/log/auth.log && grep -c Failed /var/log/auth.log",
	"test -f /var/log/noexiste || echo falta el log",
	"grep -c Failed /var/log/*.log",
	"grep ' 404 ' /var/log/access.log | wc -l",
	"echo 'En /var/log/auth.log de log-box hay 9 intentos fallidos de contraseña; 6 vienen de 203.0.113.7 en 14 segundos, un patrón compatible con fuerza bruta. Riesgo: adivinar una contraseña y lograr acceso no autorizado. Recomendación: usar claves públicas, desactivar el acceso con contraseña y bloquear la IP con fail2ban.' >> informe/borrador.md",
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
	assert_true(LabLoader.load_file(LAB)["world"] != null)


func test_las_cifras_del_laboratorio_son_las_de_las_pistas() -> void:
	var s: RefCounted = _game()["session"]
	assert_eq(s.run("grep 'Failed password' /var/log/auth.log | wc -l").stdout.strip_edges(), "9")
	assert_eq(s.run("grep 'Failed password.*203.0.113.7' /var/log/auth.log | wc -l").stdout.strip_edges(), "6")
	assert_eq(s.run("grep ' 404 ' /var/log/access.log | wc -l").stdout.strip_edges(), "3")


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
	_play(game, ["IP=1", "true && true"])
	assert_eq(game["engine"].status_of("g5_variable"), "pending", "las misiones se juegan en orden")
	_play(game, M1)
	assert_eq(game["engine"].status_of("g5_variable"), "done", "lo ya hecho cuenta al llegar a su misión")


func test_un_bucle_sin_leer_la_lista_no_basta() -> void:
	var game := _game()
	_play(game, M1)
	_play(game, ["IP=1", "for ip in a b c; do echo $ip | wc -l; done"])
	assert_eq(game["engine"].status_of("g6_bucle"), "pending", "hay que usar vigilar.txt y grep con wc")


func test_confirmar_una_interpretacion_no_cuenta() -> void:
	var game := _game()
	_play(game, M1)
	_play(game, ["IP=1", "hallazgo confirmado '192.168.1.5 es inofensiva'"])
	assert_eq(game["engine"].status_of("g7_clasif_normal"), "pending")


func test_el_informe_pide_medidas_defensivas() -> void:
	var game := _game()
	_play(game, M1 + M2)
	_play(game, ["test -f /var/log/auth.log && echo ok", "test -f /nada || echo no", "grep ' 404 ' /var/log/access.log | wc -l"])
	_play(game, ["echo 'Hay 9 intentos fallidos en /var/log/auth.log de log-box, 6 desde 203.0.113.7, compatible con fuerza bruta. Sin más.' >> informe/borrador.md", "revisar"])
	assert_false(game["engine"].is_finished(), "sin recomendación el informe no pasa")
