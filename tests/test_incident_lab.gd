extends "res://tests/framework/test_case.gd"
## Quinto laboratorio, "Triaje de un incidente": datos válidos, resoluble solo con comandos y sin atajos.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")

const BOOK := "res://data/missions/incidente.json"
const LAB := "res://data/labs/incidente.json"

const M1 := [
	"cat cliente.txt",
	"cat /var/log/app/security.log",
	"sort ips_origen.txt | uniq -c | sort -r",
	"hallazgo confirmado 'svc-backup falló 3 veces y entró desde 198.51.100.44 a las 03:12'",
	"hallazgo hipotesis 'alguien pudo adivinar o reutilizar la contraseña de svc-backup'",
]
const M2 := [
	"contar() { grep -c \"$1\" /var/log/app/security.log; }",
	"contar failed",
	"contar 198.51.100.44",
	"for e in $(cat eventos.txt); do case $e in login) echo vigilar;; export) echo revisar;; *) echo normal;; esac; done",
	"for e in $(cat eventos.txt); do echo $e; contar $e; done",
]
const M3 := [
	"if grep -c 198.51.100.44 /var/log/app/security.log; then echo presente; else echo ausente; fi",
	"echo 'En nodo-alerta, security.log muestra que svc-backup falló 3 veces y entró desde 198.51.100.44 a las 03:12, y después hubo una exportación de 48210 filas. Riesgo: acceso no autorizado y fuga de datos. No se puede confirmar cómo se obtuvo la contraseña (hipótesis). Medidas: restablecer y rotar la contraseña de svc-backup, bloquear la IP externa y activar doble factor.' >> informe/borrador.md",
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


func test_las_cifras_del_registro_son_las_de_las_pistas() -> void:
	var s: RefCounted = _game()["session"]
	assert_eq(s.run("grep -c failed /var/log/app/security.log").stdout.strip_edges(), "5")
	assert_eq(s.run("grep -c 198.51.100.44 /var/log/app/security.log").stdout.strip_edges(), "5")
	assert_eq(s.run("grep -c WARN /var/log/app/security.log").stdout.strip_edges(), "6")
	var top: String = s.run("sort ips_origen.txt | uniq -c | sort -r").stdout
	assert_true(top.strip_edges().begins_with("5 198.51.100.44"), "la IP externa es la más frecuente: %s" % top)


func test_se_resuelve_solo_con_comandos() -> void:
	var game := _game()
	_play(game, M1)
	assert_eq(game["engine"].mission_index, 1, "misión 1")
	_play(game, M2)
	assert_eq(game["engine"].mission_index, 2, "misión 2")
	_play(game, M3)
	assert_true(game["engine"].is_finished(), "misión 3")
	assert_eq(game["engine"].review_concepts(), [], "sin ayudas no queda nada que repasar")


func test_confundir_hecho_y_suposicion_se_explica() -> void:
	var game := _game()
	_play(game, M1.slice(0, 3))
	_play(game, ["hallazgo hipotesis 'svc-backup entró desde 198.51.100.44'"])
	assert_eq(game["engine"].status_of("i4_hecho"), "pending", "un hecho no es una hipótesis")
	_play(game, ["hallazgo confirmado 'la contraseña de svc-backup fue adivinada'"])
	assert_eq(game["engine"].status_of("i5_causa"), "pending", "no se puede confirmar la causa sin pruebas")


func test_no_valen_los_atajos() -> void:
	var game := _game()
	_play(game, M1.slice(0, 2))
	assert_eq(game["engine"].status_of("i6_funcion"), "pending", "las misiones se juegan en orden")
	_play(game, ["total() { echo hola; }", "total", "total"])
	assert_eq(game["engine"].status_of("i3_resumen"), "pending", "sin sort | uniq no avanza")


func test_un_case_sin_recorrer_eventos_no_basta() -> void:
	var game := _game()
	_play(game, M1)
	_play(game, ["f() { echo x; }", "f", "f", "case a in a) echo 1;; esac", "case b in b) echo 2;; esac", "case c in c) echo 3;; esac"])
	assert_eq(game["engine"].status_of("i8_case"), "pending", "hay que leer eventos.txt")
	_play(game, ["cat eventos.txt"])
	assert_eq(game["engine"].status_of("i8_case"), "done")


func test_el_informe_pide_limites_y_medidas() -> void:
	var game := _game()
	_play(game, M1 + M2)
	_play(game, ["if grep -c 198.51.100.44 /var/log/app/security.log; then echo ok; fi"])
	_play(game, ["echo 'En nodo-alerta, security.log muestra que svc-backup entró desde 198.51.100.44 tras 3 intentos fallidos. La cuenta comprometida exportó datos con riesgo de fuga.' >> informe/borrador.md", "revisar"])
	assert_false(game["engine"].is_finished(), "sin límites ni medidas, y afirmando sin pruebas, no pasa")
