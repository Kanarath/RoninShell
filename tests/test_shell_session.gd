extends "res://tests/framework/test_case.gd"

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandRegistry := preload("res://engine/shell/command_registry.gd")
const CommandResult := preload("res://engine/shell/command_result.gd")
const BasicCommands := preload("res://engine/commands/basic_commands.gd")

var _fakes := _Fakes.new()


## Comandos falsos que solo existen en los tests, para probar tuberías y códigos de salida
## sin depender de los comandos reales (que llegan en el paso 4).
class _Fakes:
	extends RefCounted

	func upper(_s: RefCounted, _args: Array, stdin: String) -> RefCounted:
		return CommandResult.ok(stdin.to_upper())

	func count_lines(_s: RefCounted, _args: Array, stdin: String) -> RefCounted:
		return CommandResult.ok("%d\n" % stdin.split("\n", false).size())

	func fail(_s: RefCounted, _args: Array, _stdin: String) -> RefCounted:
		return CommandResult.error("fail: algo salió mal", 3)

	func lines(_s: RefCounted, _args: Array, _stdin: String) -> RefCounted:
		return CommandResult.ok("uno\ndos\ntres\n")


func _session() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	var registry := CommandRegistry.new()
	BasicCommands.new().register_all(registry)
	registry.register("upper", "test", _fakes.upper)
	registry.register("count_lines", "test", _fakes.count_lines)
	registry.register("fail", "test", _fakes.fail)
	registry.register("lines", "test", _fakes.lines)
	return ShellSession.new(world, registry)


# --- Estado inicial y prompt ---

func test_sesion_empieza_en_la_casa_del_jugador() -> void:
	var s := _session()
	assert_eq(s.cwd, "/home/ronin")
	assert_eq(s.user["name"], "ronin")
	assert_eq(s.prompt(), "ronin@ronin-box:~$ ")


func test_prompt_muestra_la_ruta_relativa_a_home() -> void:
	var s := _session()
	s.cwd = "/home/ronin/docs"
	assert_eq(s.prompt(), "ronin@ronin-box:~/docs$ ")
	s.cwd = "/etc"
	assert_eq(s.prompt(), "ronin@ronin-box:/etc$ ")


# --- Ejecución básica ---

func test_echo_y_pwd() -> void:
	var s := _session()
	assert_eq(s.run("echo hola mundo").stdout, "hola mundo\n")
	assert_eq(s.run("echo -n sin salto").stdout, "sin salto")
	assert_eq(s.run("pwd").stdout, "/home/ronin\n")


func test_comillas_conservan_espacios_en_los_argumentos() -> void:
	assert_eq(_session().run("echo 'a   b'").stdout, "a   b\n")


func test_comando_desconocido_da_127_como_bash() -> void:
	var s := _session()
	var result = s.run("nmapx 10.0.0.5")
	assert_eq(result.stderr, "bash: nmapx: command not found\n")
	assert_eq(result.exit_code, 127)
	assert_eq(result.stdout, "")
	assert_eq(s.last_exit_code, 127)


func test_linea_vacia_no_hace_nada_ni_cambia_el_codigo() -> void:
	var s := _session()
	s.run("fail")
	var result = s.run("   ")
	assert_eq(result.stdout + result.stderr, "")
	assert_eq(s.last_exit_code, 3, "una línea vacía conserva el código anterior")
	assert_eq(s.history.size(), 1, "las líneas vacías no entran en el historial")


func test_help_lista_los_comandos_registrados() -> void:
	var out: String = _session().run("help").stdout
	assert_true("echo" in out and "pwd" in out and "help" in out)


func test_historial_guarda_las_lineas_en_orden() -> void:
	var s := _session()
	s.run("echo uno")
	s.run("pwd")
	s.run("comando_raro")
	assert_eq(s.history, ["echo uno", "pwd", "comando_raro"])


# --- Privilegios: sudo y su existen, pero ronin no puede usarlos ---

func test_sudo_y_su_se_deniegan_como_en_un_usuario_normal() -> void:
	var s := _session()
	var sudo_result = s.run("sudo cat /etc/shadow")
	assert_eq(sudo_result.stderr, "ronin is not in the sudoers file.  This incident will be reported.\n")
	assert_eq(sudo_result.exit_code, 1)
	assert_eq(sudo_result.stdout, "", "no se ejecuta nada")
	var su_result = s.run("su")
	assert_eq(su_result.stderr, "su: Authentication failure\n")
	assert_eq(su_result.exit_code, 1)
	assert_eq(s.run("sudo").stderr, "usage: sudo -h | -K | -k | -V\n")
	var kinds: Array = []
	for event: Dictionary in s.events:
		if event["type"] == "privilege_attempt":
			kinds.append(event["tool"])
	assert_eq(kinds, ["sudo", "su"], "los intentos quedan registrados para evaluar el método")


# --- Tuberías ---

func test_tuberia_pasa_stdout_como_stdin() -> void:
	var s := _session()
	assert_eq(s.run("echo hola | upper").stdout, "HOLA\n")
	assert_eq(s.run("lines | count_lines").stdout, "3\n")
	assert_eq(s.run("lines | upper | count_lines").stdout, "3\n")


func test_el_codigo_de_salida_es_el_del_ultimo_comando() -> void:
	var s := _session()
	assert_eq(s.run("fail | echo ok").exit_code, 0)
	assert_eq(s.run("echo ok | fail").exit_code, 3)


func test_stderr_no_viaja_por_la_tuberia_pero_se_muestra() -> void:
	var result = _session().run("fail | upper")
	assert_eq(result.stdout, "", "lo que sale por stderr no entra en el siguiente comando")
	assert_true("algo salió mal" in result.stderr)


func test_comando_desconocido_en_mitad_de_la_tuberia() -> void:
	var result = _session().run("echo hola | nope | upper")
	assert_true("nope: command not found" in result.stderr)
	assert_eq(result.stdout, "", "el comando que falla no produce salida para el siguiente")


# --- Redirecciones ---

func test_redireccion_escribe_un_archivo_y_no_muestra_nada() -> void:
	var s := _session()
	var result = s.run("echo hola > saludo.txt")
	assert_eq(result.stdout, "")
	assert_eq(result.stderr, "")
	assert_eq(s.host.fs.read_file("/home/ronin/saludo.txt"), "hola\n")
	assert_eq(s.host.fs.get_node_info("/home/ronin/saludo.txt")["owner"], "ronin")


func test_redireccion_sobrescribe_y_append_anade() -> void:
	var s := _session()
	s.run("echo uno > f.txt")
	s.run("echo dos > f.txt")
	assert_eq(s.host.fs.read_file("/home/ronin/f.txt"), "dos\n")
	s.run("echo tres >> f.txt")
	assert_eq(s.host.fs.read_file("/home/ronin/f.txt"), "dos\ntres\n")


func test_redireccion_con_rutas_relativas_y_absolutas() -> void:
	var s := _session()
	s.run("echo a > ./x.txt")
	s.run("echo b > /home/ronin/../ronin/y.txt")
	assert_eq(s.host.fs.read_file("/home/ronin/x.txt"), "a\n")
	assert_eq(s.host.fs.read_file("/home/ronin/y.txt"), "b\n")


func test_redireccion_al_final_de_una_tuberia() -> void:
	var s := _session()
	s.run("echo hola | upper > out.txt")
	assert_eq(s.host.fs.read_file("/home/ronin/out.txt"), "HOLA\n")


func test_errores_de_redireccion_como_bash() -> void:
	var s := _session()
	var missing = s.run("echo x > /no/existe/f.txt")
	assert_eq(missing.stderr, "bash: /no/existe/f.txt: No such file or directory\n")
	assert_eq(missing.exit_code, 1)
	assert_eq(s.run("echo x > /home").stderr, "bash: /home: Is a directory\n")
	assert_eq(s.run("echo x > nota.txt/algo").stderr, "bash: nota.txt/algo: Not a directory\n", "colgar algo de un archivo")


func test_redirigir_sobre_un_archivo_existente_conserva_sus_metadatos() -> void:
	var s := _session()
	s.run("echo nuevo > nota.txt")
	assert_eq(s.host.fs.read_file("/home/ronin/nota.txt"), "nuevo\n")
	assert_eq(s.host.fs.get_node_info("/home/ronin/nota.txt")["mode"], "644")


# --- Errores de sintaxis ---

func test_errores_de_sintaxis_dan_codigo_2_y_no_ejecutan_nada() -> void:
	var s := _session()
	var result = s.run("echo hola | | upper")
	assert_eq(result.exit_code, 2)
	assert_eq(result.stderr, "bash: syntax error near unexpected token `|'\n")
	assert_eq(s.run("echo 'sin cerrar").stderr, "bash: unexpected EOF while looking for matching `''\n")
	assert_eq(s.run("echo x >").exit_code, 2)
	assert_eq(s.host.fs.exists("/home/ronin/x"), false)
