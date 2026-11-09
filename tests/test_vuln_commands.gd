extends "res://tests/framework/test_case.gd"
## El comando `avisos`: exige haber identificado la versión antes, consulta la base de datos local
## (vuln_db.gd) y no inventa nada si no la conoces o si no hay avisos registrados.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const VulnDb := preload("res://engine/commands/vuln_db.gd")


func _session() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/radar.json")["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func _count(s: RefCounted, type: String) -> int:
	var total := 0
	for event: Dictionary in s.events:
		if event["type"] == type:
			total += 1
	return total


func test_sin_version_identificada_no_responde() -> void:
	var s := _session()
	var result: RefCounted = s.run("avisos repositorio 80")
	assert_true("nmap -sV" in result.stderr, "pide identificar la versión primero: %s" % result.stderr)
	assert_eq(_count(s, "advisory_checked"), 0, "sin versión conocida no se registra ninguna consulta")


func test_con_version_identificada_muestra_el_aviso() -> void:
	var s := _session()
	s.run("nmap -sV repositorio")
	var result: RefCounted = s.run("avisos repositorio 80")
	assert_true("SIM-2021-0441" in result.stdout, result.stdout)
	assert_true("CRÍTICO" in result.stdout)
	assert_true("9.8" in result.stdout)
	assert_eq(result.exit_code, 0)
	assert_eq(_count(s, "advisory_checked"), 1)


func test_un_servicio_sin_avisos_lo_dice_con_la_salvedad() -> void:
	var s := _session()
	s.run("nmap -sV basedatos")
	var result: RefCounted = s.run("avisos basedatos 22")   # OpenSSH 8.2p1: sí tiene aviso (bajo)
	assert_true("SIM-2020-1013" in result.stdout)
	# un puerto sin servicio real en esta versión concreta: forzamos uno sin entradas en la BD
	assert_eq(VulnDb.lookup("MariaDB", "99.99"), [], "una versión inventada no tiene avisos")


func test_funciona_con_ip_ademas_de_con_el_nombre() -> void:
	var s := _session()
	s.run("nmap -sV 10.0.15.11")
	var result: RefCounted = s.run("avisos 10.0.15.11 21")
	assert_true("SIM-2016-0092" in result.stdout, result.stdout)


func test_host_o_puerto_desconocidos_dan_error_claro() -> void:
	var s := _session()
	assert_true("no se conoce ese host" in s.run("avisos fantasma 80").stderr)
	assert_true("no es un puerto válido" in s.run("avisos repositorio x").stderr)
	assert_true("usa  avisos" in s.run("avisos repositorio").stderr)


func test_se_puede_combinar_con_grep_y_un_if_como_cualquier_comando() -> void:
	var s := _session()
	s.run("nmap -sV repositorio")
	assert_eq(s.run("avisos repositorio 80 | grep CRÍTICO").exit_code, 0)
	var out: String = s.run("if avisos repositorio 80 | grep CRÍTICO; then echo confirmado; else echo revisar; fi").stdout
	assert_true(out.ends_with("confirmado\n"), out)   # grep también imprime la línea que encontró, como en bash real
	assert_eq(_count(s, "if_ran"), 1)


func test_vuln_db_devuelve_la_gravedad_mas_alta() -> void:
	var advisories := VulnDb.lookup("Apache httpd", "2.4.49")
	assert_eq(advisories.size(), 1)
	assert_eq(VulnDb.worst_severity(advisories), "critico")
	assert_eq(VulnDb.worst_severity([]), "")
	assert_eq(VulnDb.lookup("Producto inventado", "1.0"), [])
