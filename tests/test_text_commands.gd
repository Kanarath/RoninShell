extends "res://tests/framework/test_case.gd"
## cut, tr y comm: columnas, traducción de caracteres y comparación de archivos ordenados.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")


func _session() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func _out(s: RefCounted, line: String) -> String:
	return s.run(line).stdout


func _err(s: RefCounted, line: String) -> String:
	return s.run(line).stderr


# --- cut ---

func test_cut_extrae_un_campo() -> void:
	var s := _session()
	assert_eq(_out(s, "cut -d: -f1 /etc/passwd"), "root\nronin\nwww-data\n")
	assert_eq(_out(s, "cut -d: -f7 /etc/passwd"), "/bin/bash\n/bin/bash\n/usr/sbin/nologin\n")


func test_cut_varios_campos_y_rangos() -> void:
	var s := _session()
	assert_eq(_out(s, "cut -d: -f1,3 /etc/passwd"), "root:0\nronin:1000\nwww-data:33\n")
	assert_eq(_out(s, "cut -d: -f1-3 /etc/passwd"), "root:x:0\nronin:x:1000\nwww-data:x:33\n")
	assert_eq(_out(s, "cut -d: -f6- /etc/passwd"), "/root:/bin/bash\n/home/ronin:/bin/bash\n/var/www:/usr/sbin/nologin\n")


func test_cut_con_tuberia_y_sin_delimitador_en_la_linea() -> void:
	var s := _session()
	assert_eq(_out(s, "cat /etc/passwd | cut -d: -f1"), "root\nronin\nwww-data\n")
	assert_eq(_out(s, "echo sin_delimitador | cut -d: -f1"), "sin_delimitador\n", "una línea sin el delimitador sale entera")


func test_cut_pide_los_campos() -> void:
	var s := _session()
	assert_true("-f" in _err(s, "cut -d: /etc/passwd"))


# --- tr ---

func test_tr_traduce_mayusculas_y_minusculas() -> void:
	var s := _session()
	assert_eq(_out(s, "echo hola | tr 'a-z' 'A-Z'"), "HOLA\n")
	assert_eq(_out(s, "echo HOLA | tr 'A-Z' 'a-z'"), "hola\n")


func test_tr_borra_caracteres() -> void:
	var s := _session()
	assert_eq(_out(s, "echo 'a b c' | tr -d ' '"), "abc\n")
	assert_eq(_out(s, "echo abc123 | tr -d '0-9'"), "abc\n")


func test_tr_repite_el_ultimo_caracter_si_el_segundo_conjunto_es_mas_corto() -> void:
	var s := _session()
	assert_eq(_out(s, "echo abc | tr 'abc' 'x'"), "xxx\n")


func test_tr_no_toca_archivos() -> void:
	var s := _session()
	var result: RefCounted = s.run("tr 'a-z' 'A-Z' /etc/passwd")
	assert_true(result.exit_code != 0, "tr solo lee la entrada estándar, no un archivo por nombre")


# --- comm ---

func test_comm_tres_columnas() -> void:
	var s := _session()
	s.run("echo 'ana\nluis\nmarta' > a.txt")
	s.run("echo 'ana\nluis\npedro' > b.txt")
	var out := _out(s, "comm a.txt b.txt")
	assert_true("marta" in out and not "\tmarta" in out, "solo en a.txt: sin sangrar")
	assert_true("\tpedro" in out, "solo en b.txt: con una tabulación")
	assert_true("\t\tana" in out and "\t\tluis" in out, "en los dos: con dos tabulaciones")


func test_comm_oculta_columnas_con_flags() -> void:
	var s := _session()
	s.run("echo 'ana\nluis\nmarta' > a.txt")
	s.run("echo 'ana\nluis\npedro' > b.txt")
	assert_eq(_out(s, "comm -12 a.txt b.txt"), "\t\tana\n\t\tluis\n", "-1 y -2 juntas: solo lo común (su sangría no cambia)")
	assert_eq(_out(s, "comm -3 a.txt b.txt"), "marta\n\tpedro\n")
	assert_eq(_out(s, "comm -23 a.txt b.txt"), "marta\n", "solo lo exclusivo del primero, sin sangría")


func test_comm_archivos_iguales_no_muestra_columnas_exclusivas() -> void:
	var s := _session()
	s.run("echo 'ana\nluis' > a.txt")
	s.run("echo 'ana\nluis' > b.txt")
	var out := _out(s, "comm a.txt b.txt")
	assert_eq(out, "\t\tana\n\t\tluis\n")
