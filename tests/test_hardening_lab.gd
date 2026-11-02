extends "res://tests/framework/test_case.gd"
## Laboratorio "Endurecimiento": revisión defensiva de la configuración de un servidor propio.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")

const LAB := "res://data/labs/endurecimiento.json"


func _session() -> RefCounted:
	var world = LabLoader.load_file(LAB)["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func test_el_laboratorio_carga_y_tiene_las_copias_de_trabajo() -> void:
	var s := _session()
	assert_true(s.run("ls revision").stdout.contains("sshd_config.copia"))
	assert_true(s.run("cat revision/sshd_config.copia").stdout.contains("PermitRootLogin yes"))
	assert_true(s.run("ls -l revision").stdout.contains("-rw-r--r--"), "el csv se ve legible por todos")


# --- Misiones ---

const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")

const BOOK := "res://data/missions/endurecimiento.json"

const M1 := [
	"cat cliente.txt",
	"cat revision/sshd_config.copia",
	"hallazgo confirmado 'PermitRootLogin yes: SSH permite entrar directamente como root, contra la practica acordada'",
	"ls -l revision",
]
const M2 := [
	"echo '# Copia de trabajo\nPort 22\nPermitRootLogin no\nPasswordAuthentication yes\nPubkeyAuthentication yes\nMaxAuthTries 6\n' > revision/sshd_config.copia",
	"chmod 600 revision/clientes_backup.csv",
	"echo '# Copia de trabajo\nPort 22\nPermitRootLogin no\nPasswordAuthentication no\nPubkeyAuthentication yes\nMaxAuthTries 3\n' > revision/sshd_config.copia",
]
const M3 := [
	"if grep 'PermitRootLogin no' revision/sshd_config.copia; then echo cumple; else echo revisar; fi",
	"echo 'En srv-interno, sshd_config permitia PermitRootLogin yes y contrasenas, y clientes_backup.csv tenia permisos 644 (rw-r--r--): riesgo de acceso no autorizado y de que cualquier usuario lea datos de clientes. Correccion: PermitRootLogin no, claves publicas en lugar de contraseña (PasswordAuthentication no) y chmod 600 en el CSV.' >> informe/borrador.md",
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


func test_los_datos_de_las_misiones_son_validos() -> void:
	assert_eq(MissionLoader.load_file(BOOK)["errors"], [])


func test_se_resuelve_solo_con_comandos() -> void:
	var game := _game()
	_play(game, M1)
	assert_eq(game["engine"].mission_index, 1, "misión 1")
	_play(game, M2)
	assert_eq(game["engine"].mission_index, 2, "misión 2")
	_play(game, M3)
	assert_true(game["engine"].is_finished(), "misión 3")
	assert_eq(game["engine"].review_concepts(), [])


func test_el_cambio_debe_quedar_realmente_en_el_archivo() -> void:
	var game := _game()
	_play(game, M1)
	_play(game, ["echo 'otra cosa' > notas.txt"])
	assert_eq(game["engine"].status_of("e5_root_no"), "pending", "escribir en otro archivo no cuenta")
	_play(game, ["echo 'PermitRootLogin yes' > revision/sshd_config.copia"])
	assert_eq(game["engine"].status_of("e5_root_no"), "pending", "dejar el valor inseguro no cuenta")
	_play(game, [M2[0]])
	assert_eq(game["engine"].status_of("e5_root_no"), "done")


func test_chmod_debe_dejar_de_ser_legible_por_todos() -> void:
	var game := _game()
	_play(game, M1)
	_play(game, ["chmod 644 revision/clientes_backup.csv"])
	assert_eq(game["engine"].status_of("e6_chmod"), "pending", "644 sigue siendo legible por todos")
	_play(game, ["chmod 600 revision/clientes_backup.csv"])
	assert_eq(game["engine"].status_of("e6_chmod"), "done")


func test_no_basta_con_quitar_contrasenas_sin_la_clave_publica() -> void:
	var game := _game()
	_play(game, M1)
	_play(game, [M2[0]])
	_play(game, ["echo 'PermitRootLogin no\nPasswordAuthentication no\n' > revision/sshd_config.copia"])
	assert_eq(game["engine"].status_of("e7_password_no"), "pending", "sin PubkeyAuthentication yes te quedarías sin acceso")


func test_el_informe_pide_la_correccion() -> void:
	var game := _game()
	_play(game, M1 + M2)
	_play(game, [M3[0]])
	_play(game, ["echo 'En srv-interno, sshd_config tenia PermitRootLogin yes y clientes_backup.csv permisos 644. Sin mas.' >> informe/borrador.md", "revisar"])
	assert_false(game["engine"].is_finished(), "sin riesgo ni corrección el informe no pasa")
