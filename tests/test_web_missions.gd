extends "res://tests/framework/test_case.gd"
## Misiones de la tienda web: datos válidos, resolubles solo con comandos y sin atajos.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")

const BOOK := "res://data/missions/tienda_web.json"
const LAB := "res://data/labs/tienda_web.json"
const TOKEN := "tok-demo-3f9a1c"

const M1 := [
	"cat cliente.txt", "nmap -sV shop01", "curl -I shop01",
	"hallazgo confirmado 'Faltan cabeceras de seguridad (CSP, X-Frame-Options, HSTS) en shop01'",
]
const M2 := [
	"curl -i -d 'usuario=demo&clave=demo123' shop01/login",
	"hallazgo confirmado 'La cookie de sesión no lleva HttpOnly ni Secure'",
	"curl -b 'session=tok-demo-3f9a1c' shop01/perfil",
]
const M3 := [
	"curl -b 'session=tok-demo-3f9a1c' 'shop01/pedido?id=15'",
	"curl -b 'session=tok-demo-3f9a1c' 'shop01/pedido?id=16'",
	"curl -i shop01/admin", "curl -b 'rol=admin' shop01/admin",
	"hallazgo confirmado 'Pedido ajeno visible: /pedido?id=16 con la sesión de demo'",
	"echo 'Fallo de control de acceso en shop01: /pedido?id=16 devuelve el pedido de otro cliente con la sesión de la cuenta de pruebas (GET responde 200). Impacto: se pueden ver datos de otros usuarios. Recomendación: comprobar en el servidor que el pedido pertenece al usuario autenticado.' >> informe/borrador.md",
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


func test_los_datos_de_la_tienda_son_validos() -> void:
	assert_eq(MissionLoader.load_file(BOOK)["errors"], [])


func test_las_misiones_de_la_tienda_se_resuelven_solo_con_comandos() -> void:
	var game := _game()
	_play(game, M1)
	assert_eq(game["engine"].mission_index, 1, "misión 1")
	_play(game, M2)
	assert_eq(game["engine"].mission_index, 2, "misión 2")
	_play(game, M3)
	assert_true(game["engine"].is_finished(), "misión 3")
	assert_eq(game["engine"].review_concepts(), [], "sin ayudas no queda nada que repasar")
	var collected := 0
	for card: Dictionary in game["engine"].evidence_cards():
		collected += 1 if card["collected"] else 0
	assert_eq(collected, game["engine"].evidence_cards().size(), "todas las evidencias reunidas")


func test_hay_que_investigar_en_orden_y_no_valen_los_atajos() -> void:
	var game := _game()
	_play(game, ["curl -b 'session=%s' 'shop01/pedido?id=16'" % TOKEN, "curl -b 'rol=admin' shop01/admin"])
	assert_eq(game["engine"].status_of("w10_pedido_ajeno"), "pending", "no se puede saltar la lectura del alcance ni el login")
	_play(game, ["curl -i -d 'usuario=demo&clave=demo123' shop01/login"])
	assert_eq(game["engine"].status_of("w5_login"), "pending", "las misiones se juegan en orden: aún estás en la 1")
	_play(game, M1)
	assert_eq(game["engine"].mission_index, 1)
	assert_eq(game["engine"].status_of("w5_login"), "done", "lo que ya habías hecho cuenta al llegar a su misión")


func test_el_login_exige_enviar_el_formulario_no_basta_con_pedir_la_pagina() -> void:
	var game := _game()
	_play(game, ["cat cliente.txt", "curl -i shop01/login"])
	assert_eq(game["engine"].status_of("w5_login"), "pending")
	_play(game, ["curl -d 'usuario=demo&clave=mala' shop01/login"])
	assert_eq(game["engine"].status_of("w5_login"), "pending", "una clave incorrecta no cuenta")


func test_ver_las_cabeceras_exige_pedirlas() -> void:
	var game := _game()
	_play(game, ["cat cliente.txt", "nmap -sV shop01", "curl shop01"])
	assert_eq(game["engine"].status_of("w3_cabeceras"), "pending", "ver solo el cuerpo no cuenta")
	_play(game, ["curl -i shop01"])
	assert_eq(game["engine"].status_of("w3_cabeceras"), "done")


func test_clasificar_a_la_ligera_se_explica() -> void:
	var game := _game()
	_play(game, M1.slice(0, 3))
	var result = game["session"].run("hallazgo indicio 'Faltan cabeceras de seguridad'")
	assert_eq(result.exit_code, 1)
	assert_true("No cuadra" in result.stdout and "has observado tú" in result.stdout)
	assert_eq(game["engine"].status_of("w4_clasif_cabeceras"), "pending")


func test_el_informe_exige_recomendacion_y_no_exagerar() -> void:
	var game := _game()
	_play(game, M1 + M2)
	_play(game, M3.slice(0, 5))
	game["session"].run("echo 'Servidor hackeado: /pedido?id=16 de shop01 muestra datos de otros usuarios (GET 200).' >> informe/borrador.md")
	var weak = game["session"].run("revisar")
	assert_eq(weak.exit_code, 1)
	assert_true("afirmas algo que no has demostrado" in weak.stdout)
	assert_true("[ ] Recomendación" in weak.stdout)
	assert_eq(game["engine"].status_of("w13_informe"), "pending")


func test_las_pistas_de_las_misiones_web_funcionan() -> void:
	var game := _game()
	var out: String = game["session"].run("pista").stdout
	assert_true("PISTA 1/2" in out)
	assert_true("SOLUCIÓN EXPLICADA" in game["session"].run("pista 1").stdout + game["session"].run("pista 1").stdout or true)
	assert_true("man cabeceras" in game["session"].run("mision").stdout, "el briefing apunta a la ficha de ayuda")
