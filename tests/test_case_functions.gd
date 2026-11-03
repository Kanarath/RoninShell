extends "res://tests/framework/test_case.gd"
## case ... esac y funciones nombre() { ...; } del shell simulado, con sus topes de seguridad.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const ListParser := preload("res://engine/shell/list_parser.gd")


func _session() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func _out(s: RefCounted, line: String) -> String:
	return s.run(line).stdout


func _count(s: RefCounted, type: String) -> int:
	var total := 0
	for event: Dictionary in s.events:
		if event["type"] == type:
			total += 1
	return total


# --- case ---

func test_case_elige_la_rama_que_encaja() -> void:
	var s := _session()
	assert_eq(_out(s, "x=b; case $x in a) echo es-a;; b) echo es-b;; esac"), "es-b\n")
	assert_eq(_out(s, "case hola in a) echo uno;; *) echo otro;; esac"), "otro\n")


func test_case_con_varios_patrones_y_comodines() -> void:
	var s := _session()
	assert_eq(_out(s, "case ssh in ssh|telnet) echo remoto;; *) echo local;; esac"), "remoto\n")
	assert_eq(_out(s, "case informe.txt in *.log) echo log;; *.txt) echo texto;; esac"), "texto\n")
	assert_eq(_out(s, "case ab in ?) echo uno;; ??) echo dos;; esac"), "dos\n")


func test_case_sin_coincidencia_no_hace_nada_y_sale_bien() -> void:
	var s := _session()
	assert_eq(_out(s, "case z in a) echo a;; esac"), "")
	assert_eq(s.last_exit_code, 0)
	assert_eq(_count(s, "case_ran"), 1)


func test_case_dentro_de_bucles_y_con_comandos_encadenados() -> void:
	var s := _session()
	var out := _out(s, "for p in 22 80 9999; do case $p in 22) echo ssh;; 80|443) echo web;; *) echo otro;; esac; done")
	assert_eq(out, "ssh\nweb\notro\n")


func test_case_anidado_y_con_cuerpo_de_varios_comandos() -> void:
	var s := _session()
	assert_eq(_out(s, "a=1; case $a in 1) echo uno; case x in x) echo anidado;; esac;; esac"), "uno\nanidado\n")


func test_case_dentro_de_un_if() -> void:
	var s := _session()
	assert_eq(_out(s, "if true; then case a in a) echo ok;; esac; fi"), "ok\n")


func test_echo_case_no_es_la_palabra_clave() -> void:
	var s := _session()
	assert_eq(_out(s, "echo case de estudio"), "case de estudio\n")


func test_case_mal_formado_se_explica() -> void:
	var s := _session()
	assert_true("esac" in s.run("case a in a) echo x;;").stderr, "sin esac")
	assert_true("case PALABRA" in s.run("case in a) echo x;; esac").stderr)
	assert_true("syntax error" in s.run("esac").stderr)


# --- funciones ---

func test_definir_y_llamar_una_funcion() -> void:
	var s := _session()
	assert_eq(_out(s, "saludo() { echo hola; }"), "")
	assert_eq(_out(s, "saludo"), "hola\n", "la función sigue definida en la línea siguiente")
	assert_eq(_count(s, "function_defined"), 1)
	assert_eq(_count(s, "function_called"), 1)


func test_argumentos_posicionales() -> void:
	var s := _session()
	s.run("dime() { echo $1 y $2; echo son $#: $@; }")
	assert_eq(_out(s, "dime uno dos tres"), "uno y dos\nson 3: uno dos tres\n")
	assert_eq(_out(s, "echo [$1]"), "[]\n", "fuera de la función no hay argumentos")


func test_function_palabra_clave_y_return() -> void:
	var s := _session()
	s.run("function chequea { if [ $1 -gt 5 ]; then return 3; fi; echo pequeno; }")
	assert_eq(_out(s, "chequea 2"), "pequeno\n")
	assert_eq(_out(s, "chequea 9; echo $?"), "3\n")


func test_return_dentro_de_un_bucle_corta_la_funcion() -> void:
	var s := _session()
	s.run("primero() { for x in a b c; do echo $x; return 0; done; echo nunca; }")
	assert_eq(_out(s, "primero"), "a\n")


func test_una_funcion_puede_llamar_a_otra_y_a_si_misma_con_limite() -> void:
	var s := _session()
	s.run("dos() { echo dos; }")
	s.run("uno() { echo uno; dos; }")
	assert_eq(_out(s, "uno"), "uno\ndos\n")
	s.run("bucle() { bucle; }")
	var result: RefCounted = s.run("bucle")
	assert_true("recursión infinita" in result.stderr, "se corta la recursión")


func test_la_explosion_de_llamadas_se_detiene() -> void:
	var s := _session()
	s.run("boom() { boom; boom; }")
	var result: RefCounted = s.run("boom")
	assert_true(result.stderr != "", "no se cuelga: se detiene con un aviso")


func test_funciones_con_case_y_codigo_de_salida() -> void:
	var s := _session()
	s.run("tipo() { case $1 in *.log) echo log;; *) echo otro;; esac; }")
	assert_eq(_out(s, "tipo auth.log"), "log\n")
	assert_eq(_out(s, "for f in a.log b.txt; do tipo $f; done"), "log\notro\n")


func test_cabeceras_de_funcion_mal_formadas() -> void:
	var s := _session()
	assert_true("{" in s.run("f()").stderr)
	assert_true("syntax error" in s.run("f() { echo x").stderr)
	assert_true("syntax error" in s.run("}").stderr)
	assert_eq(_out(s, "echo hola"), "hola\n", "un echo normal sigue funcionando")


func test_el_parser_reconoce_las_dos_formas_de_cabecera() -> void:
	assert_eq(ListParser._function_header("f() { echo"), {"name": "f", "rest": "{ echo"})
	assert_eq(ListParser._function_header("function g"), {"name": "g", "rest": ""})
	assert_eq(ListParser._function_header("echo hola"), {})
	assert_eq(ListParser._function_header("ls -l"), {})
