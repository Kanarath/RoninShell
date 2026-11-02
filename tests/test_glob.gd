extends "res://tests/framework/test_case.gd"
## Comodines * y ?: coincidencia, expansión sobre el laboratorio, ocultos, permisos y bucles.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const Glob := preload("res://engine/shell/glob.gd")


func _session() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/guardia_logs.json")["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func _out(s: RefCounted, line: String) -> String:
	return s.run(line).stdout


func test_coincidencia_de_patrones() -> void:
	assert_true(Glob.matches("*", "cualquier"))
	assert_true(Glob.matches("*.log", "auth.log"))
	assert_false(Glob.matches("*.log", "auth.txt"))
	assert_true(Glob.matches("a?c", "abc"))
	assert_false(Glob.matches("a?c", "ac"))
	assert_true(Glob.matches("a*b*c", "aXXbYYc"))
	assert_false(Glob.matches("a*b*c", "aXXbYY"))
	assert_true(Glob.matches("*", ""))
	assert_true(Glob.matches("**x", "x"))
	assert_false(Glob.matches("", "x"))


func test_ls_y_echo_con_comodines() -> void:
	var s := _session()
	assert_eq(_out(s, "ls /var/log/*.log"), "/var/log/access.log\n/var/log/auth.log\n")
	assert_eq(_out(s, "echo /var/log/a*"), "/var/log/access.log /var/log/auth.log\n")
	assert_eq(_out(s, "echo /var/log/a?th.log"), "/var/log/auth.log\n")
	s.run("cd /var/log")
	assert_eq(_out(s, "echo *.log"), "access.log auth.log\n")


func test_sin_coincidencias_se_deja_el_patron_como_bash() -> void:
	var s := _session()
	assert_eq(_out(s, "echo /var/log/*.zip"), "/var/log/*.zip\n")


func test_las_comillas_desactivan_el_comodin() -> void:
	var s := _session()
	assert_eq(_out(s, "echo '/var/log/*.log'"), "/var/log/*.log\n")
	assert_eq(_out(s, "echo \"/var/log/*.log\""), "/var/log/*.log\n")
	assert_eq(_out(s, "echo /var/log/\\*.log"), "/var/log/*.log\n")


func test_grep_sobre_varios_archivos() -> void:
	var s := _session()
	var out := _out(s, "grep -c Failed /var/log/*.log")
	assert_true("/var/log/auth.log:9" in out)
	assert_true("/var/log/access.log:0" in out)


func test_un_asterisco_no_enseña_los_ocultos_pero_el_punto_si() -> void:
	var s := _session()
	s.run("echo secreto > .oculto")
	s.run("echo visible > visible.txt")
	assert_false(".oculto" in _out(s, "echo *"))
	assert_true("visible.txt" in _out(s, "echo *"))
	assert_true(".oculto" in _out(s, "echo .o*"))


func test_no_se_entra_en_directorios_sin_permiso() -> void:
	var s := _session()
	s.run("mkdir_no_existe 2>/dev/null")
	s.run("chmod 000 informe")
	assert_eq(_out(s, "echo informe/*"), "informe/*\n", "sin permiso de lectura no se listan sus archivos")


func test_comodin_en_un_directorio_intermedio() -> void:
	var s := _session()
	assert_eq(_out(s, "echo /v*/log/auth.log"), "/var/log/auth.log\n")
	assert_eq(_out(s, "echo informe/*.md"), "informe/borrador.md\n")


func test_comodines_en_bucles_y_el_nombre_del_comando_no_se_expande() -> void:
	var s := _session()
	assert_eq(_out(s, "for f in /var/log/*.log; do echo [$f]; done"), "[/var/log/access.log]\n[/var/log/auth.log]\n")
	assert_true("command not found" in s.run("/var/log/*.log").stderr, "el primer termino es el comando: no se expande")


func test_el_evento_de_expansion_queda_registrado() -> void:
	var s := _session()
	s.run("ls /var/log/*.log")
	var found := false
	for event: Dictionary in s.events:
		if event["type"] == "glob_expanded" and event["count"] == 2:
			found = true
	assert_true(found)


func test_una_variable_con_asterisco_sin_comillas_tambien_se_expande() -> void:
	var s := _session()
	s.run("P='/var/log/*.log'")
	assert_eq(_out(s, "echo $P"), "/var/log/access.log /var/log/auth.log\n")
	assert_eq(_out(s, "echo \"$P\""), "/var/log/*.log\n")
