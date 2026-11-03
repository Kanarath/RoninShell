extends "res://tests/framework/test_case.gd"
## Séptimo laboratorio (Inventario y exposición) y octavo (Higiene de cuentas): datos válidos,
## resolubles solo con comandos y sin atajos.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")

const INV_BOOK := "res://data/missions/inventario.json"
const INV_LAB := "res://data/labs/inventario.json"
const CUE_BOOK := "res://data/missions/cuentas.json"
const CUE_LAB := "res://data/labs/cuentas.json"

const INV_M1 := [
	"cat cliente.txt",
	"nmap 10.0.11.0/24 | grep -E 'report|open' > actual.txt",
	"cat esperado.txt",
]
const INV_M2 := [
	"diff esperado.txt actual.txt",
	"hallazgo confirmado 'ficheros ofrece 21/tcp (ftp), que no figura en el inventario esperado'",
	"curl 10.0.11.12:8080",
	"hallazgo hipotesis 'el panel de pruebas pudo quedarse activo por olvido tras una prueba de desarrollo'",
]
const INV_M3 := [
	"echo '# Copia de los servicios del servidor ficheros\nssh=on\nftp=off' > config/ficheros_servicios.conf.copia",
	"if grep 'ftp=off' config/ficheros_servicios.conf.copia; then echo cerrado; else echo revisar; fi",
	"echo 'El diff entre el inventario esperado y el escaneo de nmap muestra 21/tcp (ftp) en ficheros (10.0.11.11) y 8080/tcp en base (10.0.11.12), que no figuran. Riesgo: ftp sin cifrar y mayor superficie expuesta. No se puede confirmar por qué el panel de pruebas sigue activo (hipótesis). Medidas: desactivar ftp, retirar o restringir el panel con firewall y actualizar el inventario.' >> informe/borrador.md",
	"revisar",
]

const CUE_M1 := [
	"cat cliente.txt",
	"cat revision/politica.txt",
	"grep -E '2025|2026-0[1-7]' revision/ultimo_acceso.txt | wc -l",
	"hallazgo confirmado 'pruebas, ex-becario y contratista llevan más de 90 días sin acceso'",
	"hallazgo hipotesis 'el ex-becario y el contratista ya no trabajan aquí y nadie cerró sus cuentas'",
]
const CUE_M2 := [
	"echo 'ana=activa\nluis=activa\nmarta=activa\nsvc-backup=activa\npruebas=bloqueada\nex-becario=bloqueada\ncontratista=bloqueada\nsoporte-compartida=activa' > revision/estado.conf.copia",
	"echo '# Copia de la política de contraseñas\nPASS_MIN_LEN 12\nPASS_MAX_DAYS 90\nPASS_WARN_AGE 7' > revision/login.defs.copia",
	"echo 'ana=activa\nluis=activa\nmarta=activa\nsvc-backup=activa\npruebas=bloqueada\nex-becario=bloqueada\ncontratista=bloqueada\nsoporte-compartida=revision' > revision/estado.conf.copia",
]
const CUE_M3 := [
	"if grep 'bloqueada' revision/estado.conf.copia; then echo hecho; else echo revisar; fi",
	"echo 'En cuentas09, ultimo_acceso.txt muestra que pruebas, ex-becario y contratista llevan más de 90 días sin acceso. Riesgo: cuentas olvidadas sin vigilar y posible acceso no autorizado. No se puede confirmar que sus dueños ya no trabajen aquí: hay que confirmar con RR. HH. Medidas: bloquear las tres tras confirmarlo, endurecer la política a 12 caracteres y 90 días, y hacer una revisión periódica.' >> informe/borrador.md",
	"revisar",
]


func _game(book: String, lab: String) -> Dictionary:
	var world = LabLoader.load_file(lab)["world"]
	var engine := MissionEngine.new(MissionLoader.load_file(book)["book"])
	var tracker := MissionTracker.new(engine)
	var session := ShellSession.new(world, CommandSet.create_registry(tracker))
	session.tracker = tracker
	return {"engine": engine, "session": session}


func _play(game: Dictionary, lines: Array) -> void:
	for line: String in lines:
		game["session"].run(line)


# --- Inventario y exposición ---

func test_inventario_datos_validos() -> void:
	assert_eq(MissionLoader.load_file(INV_BOOK)["errors"], [])
	assert_eq(LabLoader.load_file(INV_LAB)["errors"], [])


func test_inventario_el_diff_muestra_solo_lo_que_sobra() -> void:
	var game := _game(INV_BOOK, INV_LAB)
	var s: RefCounted = game["session"]
	s.run("nmap 10.0.11.0/24 | grep -E 'report|open' > actual.txt")
	var diff: String = s.run("diff esperado.txt actual.txt").stdout
	assert_true("> 21/tcp open  ftp" in diff, "sale el ftp: %s" % diff)
	assert_true("> 8080/tcp open  http-proxy" in diff, "sale el 8080")
	assert_eq(diff.count("> "), 2, "solo dos líneas de más: %s" % diff)
	assert_eq(diff.count("< "), 0, "no falta nada de lo esperado")


func test_inventario_se_resuelve_solo_con_comandos() -> void:
	var game := _game(INV_BOOK, INV_LAB)
	_play(game, INV_M1)
	assert_eq(game["engine"].mission_index, 1, "misión 1")
	_play(game, INV_M2)
	assert_eq(game["engine"].mission_index, 2, "misión 2")
	_play(game, INV_M3)
	assert_true(game["engine"].is_finished(), "misión 3")
	assert_eq(game["engine"].review_concepts(), [], "sin ayudas no queda nada que repasar")


func test_inventario_no_valen_los_atajos() -> void:
	var game := _game(INV_BOOK, INV_LAB)
	_play(game, ["cat cliente.txt", "nmap 10.0.11.0/24 > actual.txt"])
	assert_eq(game["engine"].status_of("v3_guardar"), "pending", "el volcado completo no está filtrado: sin 'open' y 'report' con grep no vale")
	_play(game, ["nmap 10.0.11.0/24 | grep -E 'report|open' > actual.txt"])
	assert_eq(game["engine"].status_of("v3_guardar"), "done")


func test_inventario_confundir_hecho_y_suposicion_se_explica() -> void:
	var game := _game(INV_BOOK, INV_LAB)
	_play(game, INV_M1)
	_play(game, ["diff esperado.txt actual.txt", "hallazgo hipotesis 'el puerto 21 de ficheros no esta en el inventario'"])
	assert_eq(game["engine"].status_of("v6_hecho"), "pending", "un hecho no es una hipótesis")
	_play(game, ["curl 10.0.11.12:8080", "hallazgo confirmado 'el panel sigue activo por olvido de desarrollo'"])
	assert_eq(game["engine"].status_of("v8_causa"), "pending", "no se puede confirmar la causa")


func test_inventario_el_informe_pide_limites_y_medidas() -> void:
	var game := _game(INV_BOOK, INV_LAB)
	_play(game, INV_M1 + INV_M2)
	_play(game, ["echo 'ftp y 8080 sobran' > config/ficheros_servicios.conf.copia", "if grep ftp config/ficheros_servicios.conf.copia; then echo x; fi"])
	_play(game, ["echo 'El escaneo de nmap muestra ftp y 8080 en ficheros y base, expuesto, un riesgo.' >> informe/borrador.md", "revisar"])
	assert_false(game["engine"].is_finished(), "sin límites ni medidas no pasa")


# --- Higiene de cuentas ---

func test_cuentas_datos_validos() -> void:
	assert_eq(MissionLoader.load_file(CUE_BOOK)["errors"], [])
	assert_eq(LabLoader.load_file(CUE_LAB)["errors"], [])


func test_cuentas_las_cifras_son_las_de_las_pistas() -> void:
	var s: RefCounted = _game(CUE_BOOK, CUE_LAB)["session"]
	assert_eq(s.run("grep -E '2025|2026-0[1-7]' revision/ultimo_acceso.txt | wc -l").stdout.strip_edges(), "3")


func test_cuentas_se_resuelve_solo_con_comandos() -> void:
	var game := _game(CUE_BOOK, CUE_LAB)
	_play(game, CUE_M1)
	assert_eq(game["engine"].mission_index, 1, "misión 1")
	_play(game, CUE_M2)
	assert_eq(game["engine"].mission_index, 2, "misión 2")
	_play(game, CUE_M3)
	assert_true(game["engine"].is_finished(), "misión 3")
	assert_eq(game["engine"].review_concepts(), [], "sin ayudas no queda nada que repasar")


func test_cuentas_bloquear_de_mas_no_vale() -> void:
	var game := _game(CUE_BOOK, CUE_LAB)
	_play(game, CUE_M1)
	_play(game, ["echo 'ana=bloqueada\nluis=bloqueada\nmarta=bloqueada\nsvc-backup=bloqueada\npruebas=bloqueada\nex-becario=bloqueada\ncontratista=bloqueada\nsoporte-compartida=bloqueada' > revision/estado.conf.copia"])
	assert_eq(game["engine"].status_of("a6_bloquear"), "pending", "bloquear a todo el mundo no es aplicar la política")


func test_cuentas_la_compartida_va_a_revision_no_se_bloquea() -> void:
	var game := _game(CUE_BOOK, CUE_LAB)
	_play(game, CUE_M1)
	_play(game, [CUE_M2[0], CUE_M2[1]])
	assert_eq(game["engine"].status_of("a8_transfer"), "pending")
	_play(game, [CUE_M2[2]])
	assert_eq(game["engine"].status_of("a8_transfer"), "done")


func test_cuentas_el_informe_pide_limites_y_medidas() -> void:
	var game := _game(CUE_BOOK, CUE_LAB)
	_play(game, CUE_M1 + CUE_M2)
	_play(game, ["if grep 'bloqueada' revision/estado.conf.copia; then echo ok; fi"])
	_play(game, ["echo 'En cuentas09 las cuentas pruebas, ex-becario y contratista llevan más de 90 días sin acceso y la cuenta comprometida es un riesgo.' >> informe/borrador.md", "revisar"])
	assert_false(game["engine"].is_finished(), "sin límites ni medidas, y afirmando sin pruebas, no pasa")
