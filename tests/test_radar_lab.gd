extends "res://tests/framework/test_case.gd"
## Noveno laboratorio, "Radar de vulnerabilidades": datos válidos, resoluble solo con comandos y sin atajos.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")

const BOOK := "res://data/missions/radar.json"
const LAB := "res://data/labs/radar.json"

const M1 := [
	"cat cliente.txt",
	"nmap -sV 10.0.15.0/24",
	"avisos repositorio 80",
]
const M2 := [
	"avisos repositorio 21",
	"avisos basedatos 3306",
	"hallazgo confirmado 'Apache httpd 2.4.49 en repositorio tiene el aviso SIM-2021-0441, crítico (CVSS 9.8)'",
	"avisos correo 22",
]
const M3 := [
	"if avisos repositorio 80 | grep CRÍTICO; then echo confirmado; else echo revisar; fi",
	"echo 'Apache httpd 2.4.49 en repositorio tiene el aviso SIM-2021-0441, crítico (CVSS 9.8, riesgo de ruta). vsftpd 3.0.3 en repositorio y MariaDB 10.3.29 en basedatos tienen avisos de gravedad media (texto claro y denegación de servicio). OpenSSH 7.9p1 en correo tiene un aviso de gravedad baja. Prioridad: Apache primero, por ser el de mayor gravedad; los demás después. Se recomienda actualizar o parchear cada servicio a la versión corregida.' >> informe/borrador.md",
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


func test_no_valen_los_atajos() -> void:
	var game := _game()
	_play(game, ["cat cliente.txt", "nmap -sn 10.0.15.0/24"])
	assert_eq(game["engine"].status_of("v1_escanear"), "pending", "-sn no identifica versiones")
	_play(game, ["nmap -sV 10.0.15.0/24"])
	assert_eq(game["engine"].status_of("v1_escanear"), "done")
	assert_eq(game["engine"].status_of("v1_consultar"), "pending", "hay que consultar avisos, no solo escanear")
	_play(game, ["avisos repositorio 80"])
	assert_eq(game["engine"].status_of("v1_consultar"), "done")


func test_confundir_hecho_y_suposicion_se_explica() -> void:
	var game := _game()
	_play(game, M1 + [M2[0], M2[1]])
	_play(game, ["hallazgo hipotesis 'Apache 2.4.49 en repositorio tiene un aviso critico'"])
	assert_eq(game["engine"].status_of("v2_hecho"), "pending", "un hecho verificado no es una hipótesis")


func test_el_informe_pide_prioridad_y_medidas() -> void:
	var game := _game()
	_play(game, M1 + M2)
	_play(game, ["if avisos repositorio 80 | grep CRÍTICO; then echo ok; fi"])
	_play(game, ["echo 'Hay varios avisos de seguridad en la red.' >> informe/borrador.md", "revisar"])
	assert_false(game["engine"].is_finished(), "sin prioridad, evidencia ni medidas no pasa")
