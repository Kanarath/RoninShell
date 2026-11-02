extends "res://tests/framework/test_case.gd"
## Variables, expansión, ; && ||, bucles for y $( ): sintaxis del shell, siempre dentro del laboratorio.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const Tokenizer := preload("res://engine/shell/tokenizer.gd")
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


# --- Variables ---

func test_asignar_y_usar_una_variable() -> void:
	var s := _session()
	assert_eq(s.run("OBJETIVO=app02").exit_code, 0)
	assert_eq(_out(s, "echo $OBJETIVO"), "app02\n")
	assert_eq(_out(s, "echo ${OBJETIVO}:8000"), "app02:8000\n")
	assert_eq(_count(s, "var_set"), 1)


func test_las_comillas_deciden_si_se_expande() -> void:
	var s := _session()
	s.run("X=hola")
	assert_eq(_out(s, "echo \"$X mundo\""), "hola mundo\n")
	assert_eq(_out(s, "echo '$X mundo'"), "$X mundo\n", "las comillas simples son literales")
	assert_eq(_out(s, "echo \\$X"), "$X\n", "la barra escapa el dolar")
	assert_eq(_out(s, "echo $"), "$\n", "un dolar suelto es un dolar")


func test_una_variable_sin_comillas_se_parte_en_palabras() -> void:
	var s := _session()
	s.run("LISTA=\"a b c\"")
	assert_eq(_out(s, "for x in $LISTA; do echo [$x]; done"), "[a]\n[b]\n[c]\n")
	assert_eq(_out(s, "for x in \"$LISTA\"; do echo [$x]; done"), "[a b c]\n", "entre comillas es un solo elemento")


func test_variables_de_entorno_por_defecto() -> void:
	var s := _session()
	assert_eq(_out(s, "echo $USER"), s.user["name"] + "\n")
	assert_eq(_out(s, "echo $HOME"), s.user["home"] + "\n")
	s.run("cd /")
	assert_eq(_out(s, "echo $PWD"), "/\n")
	assert_eq(_out(s, "echo ~"), s.user["home"] + "\n")
	assert_eq(_out(s, "echo $NO_EXISTE-fin"), "-fin\n", "una variable sin definir es vacía")


func test_tilde_para_ir_a_casa() -> void:
	var s := _session()
	s.run("cd /")
	assert_eq(s.run("cd ~").exit_code, 0)
	assert_eq(s.cwd, s.user["home"])


func test_codigo_de_salida() -> void:
	var s := _session()
	s.run("cat /no/existe")
	assert_eq(_out(s, "echo $?"), "1\n")
	s.run("true")
	assert_eq(_out(s, "echo $?"), "0\n")


func test_asignar_con_comando_delante_se_explica() -> void:
	var s := _session()
	var result = s.run("A=1 echo hola")
	assert_true(result.exit_code != 0)
	assert_true("delante de un comando" in result.stderr)


func test_nombres_invalidos_y_bad_substitution() -> void:
	var s := _session()
	assert_true("bad substitution" in s.run("echo ${1abc}").stderr)
	assert_true("not a valid identifier" in s.run("export 1x=3").stderr)


func test_export_env_y_unset() -> void:
	var s := _session()
	s.run("export OBJETIVO=db02")
	assert_true("OBJETIVO=db02" in _out(s, "env"))
	s.run("SOLO_LOCAL=1")
	assert_false("SOLO_LOCAL" in _out(s, "env"), "una variable sin export no sale en env")
	s.run("unset OBJETIVO")
	assert_false("OBJETIVO" in _out(s, "env"))
	assert_eq(_out(s, "echo [$OBJETIVO]"), "[]\n")


# --- ; && || ---

func test_punto_y_coma_ejecuta_siempre() -> void:
	var s := _session()
	assert_eq(_out(s, "echo uno; false; echo dos"), "uno\ndos\n")


func test_and_solo_continua_si_salio_bien() -> void:
	var s := _session()
	assert_eq(_out(s, "true && echo ok"), "ok\n")
	assert_eq(_out(s, "false && echo ok"), "")
	assert_eq(_out(s, "cat /no/existe && echo ok"), "")
	assert_eq(_count(s, "list_op"), 3)


func test_or_solo_continua_si_fallo() -> void:
	var s := _session()
	assert_eq(_out(s, "false || echo plan B"), "plan B\n")
	assert_eq(_out(s, "true || echo plan B"), "")


func test_cadena_mixta_se_evalua_de_izquierda_a_derecha() -> void:
	var s := _session()
	assert_eq(_out(s, "false && echo a || echo b"), "b\n")
	assert_eq(_out(s, "true && echo a || echo b"), "a\n")


func test_la_asignacion_se_ve_en_el_siguiente_comando_de_la_misma_linea() -> void:
	var s := _session()
	assert_eq(_out(s, "N=7; echo $N && N=8 && echo $N"), "7\n8\n")


func test_los_errores_salen_por_stderr_y_el_resto_sigue() -> void:
	var s := _session()
	var result = s.run("cat /no/existe; echo despues")
	assert_true("No such file" in result.stderr)
	assert_eq(result.stdout, "despues\n")
	assert_eq(result.exit_code, 0)


func test_un_error_de_sintaxis_no_ejecuta_nada() -> void:
	var s := _session()
	var result = s.run("echo antes; && echo despues")
	assert_true("syntax error" in result.stderr)
	assert_eq(result.stdout, "")
	assert_eq(result.exit_code, 2)
	assert_true("syntax error" in s.run("echo a &&").stderr)
	assert_true("syntax error" in s.run("echo a ;; echo b").stderr)


func test_los_conectores_dentro_de_comillas_son_texto() -> void:
	var s := _session()
	assert_eq(_out(s, "echo 'a; b && c || d'"), "a; b && c || d\n")
	assert_eq(_out(s, "echo \"x;y\""), "x;y\n")
	assert_eq(_out(s, "echo hola # ; esto es comentario"), "hola\n")


func test_el_ampersand_solo_no_existe() -> void:
	var s := _session()
	assert_true("segundo plano" in s.run("sleep 5 &").stderr)


# --- for ---

func test_bucle_for_basico() -> void:
	var s := _session()
	assert_eq(_out(s, "for h in app02 db02; do echo host $h; done"), "host app02\nhost db02\n")
	assert_eq(_count(s, "loop_ran"), 1)
	var loops: Array = s.events.filter(func(e: Dictionary) -> bool: return e["type"] == "loop_ran")
	assert_eq(loops[0]["count"], 2)


func test_bucle_con_varios_comandos_y_con_and() -> void:
	var s := _session()
	assert_eq(_out(s, "for n in 1 2; do echo a$n; echo b$n; done"), "a1\nb1\na2\nb2\n")
	assert_eq(_out(s, "for n in 1 2; do true && echo ok$n; done"), "ok1\nok2\n")


func test_bucle_con_seq_y_sustitucion() -> void:
	var s := _session()
	assert_eq(_out(s, "for n in $(seq 1 3); do echo n$n; done"), "n1\nn2\nn3\n")


func test_se_puede_encadenar_despues_del_bucle() -> void:
	var s := _session()
	assert_eq(_out(s, "for x in a b; do echo $x; done && echo fin"), "a\nb\nfin\n")


func test_bucle_sobre_las_lineas_de_un_archivo() -> void:
	var s := _session()
	s.run("echo app02 > hosts.txt")
	s.run("echo db02 >> hosts.txt")
	assert_eq(_out(s, "for h in $(cat hosts.txt); do echo [$h]; done"), "[app02]\n[db02]\n")


func test_bucle_mal_formado_se_explica() -> void:
	var s := _session()
	assert_true("done" in s.run("for x in a b; do echo $x").stderr)
	assert_true("syntax error" in s.run("for x in a b; echo $x; done").stderr)
	assert_true("syntax error" in s.run("for in a b; do echo; done").stderr)
	assert_true("syntax error" in s.run("done").stderr)
	assert_true("syntax error" in s.run("for a in 1; do").stderr)
	assert_true("todavía no está disponible" in s.run("case x in x) echo hi; esac").stderr)


func test_limite_de_elementos() -> void:
	var s := _session()
	assert_true("demasiados" in s.run("seq 1 100000").stderr)


# --- $( ) ---

func test_sustitucion_de_comandos() -> void:
	var s := _session()
	assert_eq(_out(s, "echo hoy es $(echo lunes)"), "hoy es lunes\n")
	assert_eq(_out(s, "echo \"[$(echo a b)]\""), "[a b]\n")
	assert_eq(_out(s, "echo '$(echo no)'"), "$(echo no)\n")
	s.run("N=$(echo 42)")
	assert_eq(_out(s, "echo $N"), "42\n")


func test_sustitucion_anidada_y_con_errores() -> void:
	var s := _session()
	assert_eq(_out(s, "echo $(echo $(echo hondo))"), "hondo\n")
	var result = s.run("echo x$(cat /no/existe)y")
	assert_eq(result.stdout, "xy\n")
	assert_true("No such file" in result.stderr)
	assert_true("EOF" in s.run("echo $(echo hola").stderr)


# --- Tuberías ---

func test_las_tuberias_se_registran_con_sus_comandos() -> void:
	var s := _session()
	s.run("cat /etc/hostname | wc -l")
	var found := false
	for event: Dictionary in s.events:
		if event["type"] == "pipeline" and event["cmds"] == "cat|wc":
			found = true
	assert_true(found)


# --- test / seq ---

func test_test_comprueba_archivos_y_numeros() -> void:
	var s := _session()
	assert_eq(s.run("test -d /etc").exit_code, 0)
	assert_eq(s.run("test -f /etc").exit_code, 1)
	assert_eq(s.run("test -e /nada").exit_code, 1)
	assert_eq(s.run("test ! -e /nada").exit_code, 0)
	assert_eq(s.run("test 3 -lt 10").exit_code, 0)
	assert_eq(s.run("test a = b").exit_code, 1)
	assert_eq(s.run("test -z ''").exit_code, 0)
	assert_eq(s.run("test 3 -lt abc").exit_code, 2)
	assert_eq(s.run("test -d /etc").stderr, "", "test no escribe nada")
	assert_eq(_out(s, "test -d /etc && echo hay"), "hay\n")


func test_seq_variantes() -> void:
	var s := _session()
	assert_eq(_out(s, "seq 3"), "1\n2\n3\n")
	assert_eq(_out(s, "seq 2 4"), "2\n3\n4\n")
	assert_eq(_out(s, "seq 2 2 8"), "2\n4\n6\n8\n")
	assert_eq(_out(s, "seq 3 -1 1"), "3\n2\n1\n")
	assert_true("invalid" in s.run("seq a").stderr)


# --- Compatibilidad ---

func test_el_tokenizador_sin_entorno_sigue_siendo_literal() -> void:
	var tokens: Array = Tokenizer.tokenize("echo $HOME ~")["tokens"]
	assert_eq(tokens[1]["text"], "$HOME")
	assert_eq(tokens[2]["text"], "~")


func test_el_separador_de_listas() -> void:
	var split := ListParser.split("a && b || c; d")
	assert_eq(split["units"].size(), 4)
	assert_eq(split["units"][1]["op"], "&&")
	assert_eq(split["units"][2]["op"], "||")
	assert_eq(split["units"][3]["op"], ";")
	assert_eq(ListParser.split("")["units"], [])
	assert_eq(ListParser.split("echo a;")["error"], "", "un punto y coma final es válido")


func test_redirecciones_y_variables_juntas() -> void:
	var s := _session()
	s.run("F=nota.txt")
	s.run("echo hola > $F && cat $F")
	assert_eq(_out(s, "cat $F"), "hola\n")
	s.run("for n in 1 2; do echo l$n >> $F; done")
	assert_eq(_out(s, "wc -l $F").strip_edges().split(" ")[0], "3")


# --- if / while / until / anidación / aritmética ---

func test_if_then_else_segun_el_codigo_de_salida() -> void:
	var s := _session()
	assert_eq(_out(s, "if true; then echo si; else echo no; fi"), "si\n")
	assert_eq(_out(s, "if false; then echo si; else echo no; fi"), "no\n")
	assert_eq(_out(s, "if false; then echo si; fi"), "", "sin rama que se cumpla no escribe nada")
	assert_eq(s.run("if false; then echo si; fi").exit_code, 0, "y sale con éxito, como bash")
	assert_eq(_out(s, "if test -d /etc; then echo hay; fi"), "hay\n")


func test_if_con_corchetes_elif_y_condicion_compuesta() -> void:
	var s := _session()
	assert_eq(_out(s, "if [ -d /etc ]; then echo dir; fi"), "dir\n")
	assert_eq(_out(s, "if [ 5 -lt 3 ]; then echo a; elif [ 5 -gt 3 ]; then echo b; else echo c; fi"), "b\n")
	assert_eq(_out(s, "if [ 1 -eq 2 ]; then echo a; elif [ 2 -eq 3 ]; then echo b; else echo c; fi"), "c\n")
	assert_eq(_out(s, "if test -d /etc && test -d /var; then echo ambos; fi"), "ambos\n")
	assert_true("missing" in s.run("[ -d /etc").stderr)
	assert_eq(_count(s, "if_ran"), 6, "cada if evaluado cuenta; un elif es un if dentro del else")


func test_if_con_comandos_reales_como_condicion() -> void:
	var s := _session()
	s.run("echo 'Failed password' > log.txt")
	assert_eq(_out(s, "if grep Failed log.txt; then echo hay fallos; fi"), "Failed password\nhay fallos\n")
	assert_eq(_out(s, "if grep Nada log.txt; then echo x; else echo limpio; fi"), "limpio\n")


func test_while_con_contador_aritmetico() -> void:
	var s := _session()
	assert_eq(_out(s, "n=0; while [ $n -lt 3 ]; do echo n=$n; n=$((n+1)); done"), "n=0\nn=1\nn=2\n")
	assert_eq(_out(s, "echo $n"), "3\n")
	var loops: Array = s.events.filter(func(e: Dictionary) -> bool: return e["type"] == "loop_ran" and e["variable"] == "while")
	assert_eq(loops.size(), 1)
	assert_eq(loops[0]["count"], 3)


func test_until_es_un_while_invertido() -> void:
	var s := _session()
	assert_eq(_out(s, "n=0; until [ $n -ge 2 ]; do echo $n; n=$((n+1)); done"), "0\n1\n")


func test_un_bucle_infinito_se_detiene_sin_colgar_el_juego() -> void:
	var s := _session()
	var result = s.run("while true; do true; done")
	assert_true("infinito" in result.stderr or "límite" in result.stderr)
	assert_true(result.exit_code != 0 or result.stderr != "")
	var again = s.run("echo sigo vivo")
	assert_eq(again.stdout, "sigo vivo\n", "la sesión sigue funcionando")


func test_el_tope_de_comandos_corta_los_bucles_anidados() -> void:
	var s := _session()
	var result = s.run("for a in $(seq 1 100); do for b in $(seq 1 100); do true; done; done")
	assert_true("límite de seguridad" in result.stderr)
	assert_eq(_out(s, "echo ok"), "ok\n")


func test_bucles_e_ifs_anidados() -> void:
	var s := _session()
	assert_eq(_out(s, "for a in 1 2; do for b in x y; do echo $a$b; done; done"), "1x\n1y\n2x\n2y\n")
	assert_eq(_out(s, "for n in 1 2 3; do if [ $n -eq 2 ]; then echo dos; else echo otro; fi; done"), "otro\ndos\notro\n")


func test_if_y_bucles_se_pueden_encadenar_con_conectores() -> void:
	var s := _session()
	assert_eq(_out(s, "if true; then echo a; fi && echo b"), "a\nb\n")
	assert_eq(_out(s, "if false; then echo a; fi || echo b"), "", "un if sin rama sale con 0, así que || no corre")


func test_estructuras_mal_formadas_se_explican() -> void:
	var s := _session()
	assert_true("fi" in s.run("if true; then echo x").stderr)
	assert_true("syntax error" in s.run("if true; echo x; fi").stderr)
	assert_true("syntax error" in s.run("if true; then; fi").stderr)
	assert_true("syntax error" in s.run("fi").stderr)
	assert_true("syntax error" in s.run("else echo x").stderr)
	assert_true("syntax error" in s.run("while true; do echo; done extra").stderr)
	assert_true("syntax error" in s.run("while; do echo; done").stderr)
	assert_eq(s.run("if true; then echo x").stdout, "", "un error de sintaxis no ejecuta nada")


func test_aritmetica_entera() -> void:
	var s := _session()
	assert_eq(_out(s, "echo $((2+3*4))"), "14\n")
	assert_eq(_out(s, "echo $(( (2+3) * 4 ))"), "20\n")
	assert_eq(_out(s, "echo $((7/2)) $((7%3)) $((-5+2))"), "3 1 -3\n")
	s.run("a=6")
	assert_eq(_out(s, "echo $((a*2)) $(($a+1))"), "12 7\n")
	assert_eq(_out(s, "echo $((sin))"), "0\n", "una variable sin definir vale 0")
	assert_true("división entre 0" in s.run("echo $((1/0))").stderr)
	assert_true("aritmética" in s.run("echo $((1+x.y))").stderr)
	assert_true("paréntesis" in s.run("echo $((2*(3+4))").stderr or "EOF" in s.run("echo $((2*(3+4))").stderr)


func test_el_evaluador_aritmetico_solo_entiende_numeros() -> void:
	var Arithmetic := preload("res://engine/shell/arithmetic.gd")
	assert_eq(Arithmetic.evaluate("1 + 2 * 3")["value"], 7)
	assert_true(Arithmetic.evaluate("")["ok"] == false)
	assert_true(Arithmetic.evaluate("2 +")["ok"] == false)
	assert_true(Arithmetic.evaluate("OS.execute")["ok"] == false)
	assert_true(Arithmetic.evaluate("(1+2")["ok"] == false)
	assert_true(Arithmetic.evaluate("1 2")["ok"] == false)


func test_break_y_continue_dentro_de_bucles() -> void:
	var s := _session()
	assert_eq(_out(s, "for i in 1 2 3 4; do if [ $i -eq 3 ]; then break; fi; echo $i; done"), "1\n2\n")
	assert_eq(_out(s, "for i in 1 2 3 4; do if [ $i -eq 2 ]; then continue; fi; echo $i; done"), "1\n3\n4\n")
	assert_eq(_out(s, "n=0; while true; do n=$((n+1)); if [ $n -ge 3 ]; then break; fi; done; echo $n"), "3\n")
	assert_eq(_out(s, "for a in 1 2; do for b in x y; do echo $a$b; break; done; done"), "1x\n2x\n")
	assert_true("not found" in s.run("break").stderr or "no encontrad" in s.run("break").stderr, "fuera de un bucle no es un comando")
