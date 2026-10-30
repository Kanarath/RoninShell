extends "res://tests/framework/test_case.gd"
## Comandos de archivos contra el laboratorio real "Primer contacto".

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")


func _s() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func _out(s: RefCounted, line: String) -> String:
	return s.run(line).stdout


# --- cd / pwd ---

func test_cd_navega_y_vuelve_a_casa() -> void:
	var s := _s()
	s.run("cd /etc")
	assert_eq(_out(s, "pwd"), "/etc\n")
	assert_eq(s.prompt(), "ronin@ronin-box:/etc$ ")
	s.run("cd")
	assert_eq(s.cwd, "/home/ronin")
	s.run("cd ..")
	assert_eq(s.cwd, "/home")
	s.run("cd ronin/informe")
	assert_eq(s.prompt(), "ronin@ronin-box:~/informe$ ")


func test_cd_errores_como_bash() -> void:
	var s := _s()
	assert_eq(s.run("cd /nope").stderr, "bash: cd: /nope: No such file or directory\n")
	assert_eq(s.run("cd nota.txt").stderr, "bash: cd: nota.txt: Not a directory\n")
	assert_eq(s.run("cd /root").stderr, "bash: cd: /root: Permission denied\n")
	assert_eq(s.run("cd a b").stderr, "bash: cd: too many arguments\n")
	assert_eq(s.cwd, "/home/ronin", "un cd fallido no mueve al jugador")


# --- ls ---

func test_ls_oculta_los_archivos_con_punto() -> void:
	assert_eq(_out(_s(), "ls"), "herramientas\ninforme\nnota.txt\n")
	assert_eq(_out(_s(), "ls -a"), ".\n..\n.hidden\nherramientas\ninforme\nnota.txt\n")
	assert_eq(_out(_s(), "ls -A"), ".hidden\nherramientas\ninforme\nnota.txt\n")


func test_ls_con_rutas_y_archivos() -> void:
	var s := _s()
	assert_eq(_out(s, "ls /etc"), "hosts\npasswd\nshadow\n")
	assert_eq(_out(s, "ls nota.txt"), "nota.txt\n")
	assert_eq(_out(s, "ls informe"), "borrador.md\n")
	assert_eq(_out(s, "ls /etc informe"), "/etc:\nhosts\npasswd\nshadow\n\ninforme:\nborrador.md\n".replace("/etc:", "/etc:"))


func test_ls_formato_largo_muestra_permisos_dueno_y_tamano() -> void:
	var s := _s()
	var out := _out(s, "ls -la")
	assert_true(out.begins_with("total "), "empieza por la línea total")
	assert_true("-rw------- 1 ronin ronin" in out and ".hidden" in out, "permisos de .hidden")
	assert_true("drwxr-xr-x 2 ronin ronin" in out, "un directorio muestra d y 2 enlaces")
	var size: int = s.host.fs.size_of("/home/ronin/nota.txt")
	assert_true((" %d Oct 29 12:00 nota.txt" % size) in out, "el tamaño coincide con el archivo real")


func test_ls_errores() -> void:
	var s := _s()
	var missing = s.run("ls /nope")
	assert_eq(missing.stderr, "ls: cannot access '/nope': No such file or directory\n")
	assert_eq(missing.exit_code, 2)
	assert_eq(s.run("ls /root").stderr, "ls: cannot open directory '/root': Permission denied\n")
	assert_eq(s.run("ls -z").stderr, "ls: invalid option -- 'z'\n")


# --- cat y permisos ---

func test_cat_lee_archivos_y_concatena() -> void:
	var s := _s()
	assert_true("Red autorizada" in _out(s, "cat nota.txt"))
	assert_eq(_out(s, "cat /etc/hosts").split("\n").size(), 5)
	assert_eq(_out(s, "cat informe/borrador.md nota.txt").begins_with("# Informe"), true)


func test_cat_respeta_permisos_y_errores() -> void:
	var s := _s()
	assert_eq(s.run("cat /etc/shadow").stderr, "cat: /etc/shadow: Permission denied\n")
	assert_eq(s.run("cat /root/secreto.txt").stderr, "cat: /root/secreto.txt: Permission denied\n", "no se llega a un archivo si no se puede entrar al directorio")
	assert_eq(s.run("cat /home").stderr, "cat: /home: Is a directory\n")
	var partial = s.run("cat /nope /etc/hosts")
	assert_eq(partial.stderr, "cat: /nope: No such file or directory\n")
	assert_true("localhost" in partial.stdout, "cat sigue con los demás archivos")
	assert_eq(partial.exit_code, 1)


func test_cat_sin_argumentos_lee_la_entrada() -> void:
	assert_eq(_out(_s(), "echo hola | cat"), "hola\n")


# --- head, tail, wc, sort, uniq ---

func test_head_y_tail() -> void:
	var s := _s()
	assert_eq(_out(s, "head -n 2 /etc/hosts"), "127.0.0.1 localhost\n10.0.0.2 ronin-box\n")
	assert_eq(_out(s, "tail -1 /etc/hosts"), "10.0.0.9 files01\n")
	assert_eq(_out(s, "cat /etc/hosts | head -2 | tail -n 1"), "10.0.0.2 ronin-box\n")
	assert_eq(s.run("head -n x /etc/hosts").stderr, "head: invalid number of lines: 'x'\n")


func test_wc() -> void:
	var s := _s()
	assert_eq(_out(s, "cat /etc/hosts | wc -l"), "4\n")
	assert_eq(_out(s, "wc -l /etc/hosts"), "4 /etc/hosts\n")
	assert_eq(_out(s, "echo uno dos tres | wc -w"), "3\n")
	assert_eq(_out(s, "echo hola | wc"), "      1       1       5\n")


func test_sort_y_uniq() -> void:
	var s := _s()
	assert_eq(_out(s, "sort /etc/hosts").split("\n")[0], "10.0.0.2 ronin-box")
	assert_eq(_out(s, "sort -r /etc/hosts").split("\n")[0], "127.0.0.1 localhost")
	s.run("echo a > t.txt")
	s.run("echo a >> t.txt")
	s.run("echo b >> t.txt")
	assert_eq(_out(s, "uniq t.txt"), "a\nb\n")
	assert_eq(_out(s, "uniq -c t.txt"), "      2 a\n      1 b\n")
	assert_eq(_out(s, "sort -u t.txt"), "a\nb\n")


# --- grep ---

func test_grep_basico_con_tuberias() -> void:
	var s := _s()
	assert_eq(_out(s, "cat /etc/passwd | grep ronin"), "ronin:x:1000:1000:Ronin:/home/ronin:/bin/bash\n")
	assert_eq(_out(s, "grep -c bash /etc/passwd"), "2\n")
	assert_eq(_out(s, "grep -n www /etc/passwd"), "3:www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin\n")
	assert_eq(_out(s, "grep -v bash /etc/passwd"), "www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin\n")
	assert_eq(_out(s, "grep -i RONIN-BOX /etc/hosts"), "10.0.0.2 ronin-box\n")


func test_grep_codigos_de_salida_y_errores() -> void:
	var s := _s()
	assert_eq(s.run("grep zzz /etc/hosts").exit_code, 1, "sin coincidencias = 1")
	assert_eq(s.run("grep localhost /etc/hosts").exit_code, 0)
	assert_eq(s.run("grep x /nope").stderr, "grep: /nope: No such file or directory\n")
	assert_eq(s.run("grep x /nope").exit_code, 2)
	assert_eq(s.run("grep x /etc/shadow").stderr, "grep: /etc/shadow: Permission denied\n")
	assert_eq(s.run("grep x /home").stderr, "grep: /home: Is a directory\n")
	assert_eq(s.run("grep '(' /etc/hosts").stderr, "grep: Invalid regular expression\n")


func test_grep_varios_archivos_y_recursivo() -> void:
	var s := _s()
	assert_eq(_out(s, "grep localhost /etc/hosts /etc/passwd"), "/etc/hosts:127.0.0.1 localhost\n")
	assert_eq(_out(s, "grep -rn Pendiente ."), "./informe/borrador.md:3:Pendiente de completar.\n")
	assert_true("hosts" in _out(s, "grep -r web01 /etc"))


# --- find ---

func test_find_por_nombre_y_tipo() -> void:
	var s := _s()
	assert_eq(_out(s, "find /home/ronin -name '*.md'"), "/home/ronin/informe/borrador.md\n")
	assert_eq(_out(s, "find . -type d"), ".\n./herramientas\n./informe\n")
	assert_eq(_out(s, "find . -name nota.txt"), "./nota.txt\n")
	assert_eq(_out(s, "find /etc -type f -name 'p*'"), "/etc/passwd\n")
	assert_eq(_out(s, "find /etc -name 'sh?dow'"), "/etc/shadow\n")


func test_find_errores_y_permisos() -> void:
	var s := _s()
	var denied = s.run("find /root")
	assert_true("Permission denied" in denied.stderr)
	assert_eq(denied.stdout, "/root\n", "find imprime el directorio y luego se queja")
	assert_true("No such file" in s.run("find /nope").stderr)
	assert_eq(s.run("find . -foo").stderr, "find: unknown predicate `-foo'\n")


# --- chmod ---

func test_chmod_simbolico_y_octal() -> void:
	var s := _s()
	var script := "/home/ronin/herramientas/escaneo.sh"
	assert_eq(s.host.fs.mode_string(script), "-rw-r--r--")
	s.run("chmod +x herramientas/escaneo.sh")
	assert_eq(s.host.fs.mode_string(script), "-rwxr-xr-x")
	s.run("chmod 600 herramientas/escaneo.sh")
	assert_eq(s.host.fs.mode_string(script), "-rw-------")
	s.run("chmod u+x,g=r herramientas/escaneo.sh")
	assert_eq(s.host.fs.mode_string(script), "-rwxr-----")
	s.run("chmod go-r,o+w nota.txt")
	assert_eq(s.host.fs.mode_string("/home/ronin/nota.txt"), "-rw-----w-", "644 -> go-r = 600 -> o+w = 602")


func test_chmod_errores() -> void:
	var s := _s()
	assert_eq(s.run("chmod 644 /etc/hosts").stderr, "chmod: changing permissions of '/etc/hosts': Operation not permitted\n")
	assert_eq(s.run("chmod 644 /nope").stderr, "chmod: cannot access '/nope': No such file or directory\n")
	assert_eq(s.run("chmod 999 nota.txt").stderr, "chmod: invalid mode: ‘999’\n")
	assert_eq(s.run("chmod 644").stderr, "chmod: missing operand\n")


func test_quitar_permiso_de_lectura_bloquea_al_propio_dueno() -> void:
	var s := _s()
	s.run("chmod 000 nota.txt")
	assert_eq(s.run("cat nota.txt").stderr, "cat: nota.txt: Permission denied\n")
	s.run("chmod u+r nota.txt")
	assert_true("Red autorizada" in _out(s, "cat nota.txt"))


# --- Redirecciones y permisos ---

func test_redirecciones_respetan_permisos() -> void:
	var s := _s()
	assert_eq(s.run("echo x > /etc/hosts").stderr, "bash: /etc/hosts: Permission denied\n")
	assert_eq(s.run("echo x > /etc/nuevo").stderr, "bash: /etc/nuevo: Permission denied\n")
	assert_eq(s.run("echo x > /root/a").stderr, "bash: /root/a: Permission denied\n")
	assert_true("localhost" in s.host.fs.read_file("/etc/hosts"), "el archivo no cambió")


# --- Identidad e historial ---

func test_whoami_id_hostname() -> void:
	var s := _s()
	assert_eq(_out(s, "whoami"), "ronin\n")
	assert_eq(_out(s, "id"), "uid=1000(ronin) gid=1000(ronin) groups=1000(ronin)\n")
	assert_eq(_out(s, "hostname"), "ronin-box\n")


func test_history_numera_los_comandos() -> void:
	var s := _s()
	s.run("pwd")
	s.run("whoami")
	assert_eq(_out(s, "history"), "    1  pwd\n    2  whoami\n    3  history\n")


func test_help_incluye_los_comandos_de_archivos() -> void:
	var out := _out(_s(), "help")
	for command in ["ls", "cd", "cat", "grep", "find", "chmod"]:
		assert_true(command in out, "help debe listar %s" % command)
