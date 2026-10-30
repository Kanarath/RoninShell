extends "res://tests/framework/test_case.gd"
## Autocompletado, historial con flechas y la terminal visual.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const Completer := preload("res://engine/shell/completer.gd")
const HistoryNavigator := preload("res://engine/shell/history_navigator.gd")
const TerminalView := preload("res://ui/widgets/terminal_view.gd")


func _session() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	return ShellSession.new(world, CommandSet.create_registry())


# --- Autocompletado ---

func test_completa_comandos() -> void:
	var s := _session()
	assert_eq(Completer.complete(s, "hel")["line"], "help ")
	assert_eq(Completer.complete(s, "gre")["line"], "grep ")
	var ambiguous := Completer.complete(s, "c")
	assert_eq(ambiguous["line"], "c", "no hay prefijo común más largo")
	assert_true("cat" in ambiguous["options"] and "cd" in ambiguous["options"] and "chmod" in ambiguous["options"])
	assert_eq(Completer.complete(s, "zzz")["line"], "zzz")


func test_completa_rutas_relativas_y_absolutas() -> void:
	var s := _session()
	assert_eq(Completer.complete(s, "cat no")["line"], "cat nota.txt ")
	assert_eq(Completer.complete(s, "cd inf")["line"], "cd informe/", "los directorios terminan en /")
	assert_eq(Completer.complete(s, "ls /et")["line"], "ls /etc/")
	assert_eq(Completer.complete(s, "cat /etc/p")["line"], "cat /etc/passwd ")
	assert_eq(Completer.complete(s, "cat informe/bor")["line"], "cat informe/borrador.md ")


func test_completa_hasta_el_prefijo_comun_y_lista_opciones() -> void:
	var s := _session()
	var result := Completer.complete(s, "cat /etc/")
	assert_eq(result["options"], ["/etc/hosts", "/etc/passwd", "/etc/shadow"])
	assert_eq(result["line"], "cat /etc/")


func test_los_archivos_ocultos_solo_salen_si_empiezas_con_punto() -> void:
	var s := _session()
	assert_false(".hidden" in str(Completer.complete(s, "ls ")["options"]))
	assert_eq(Completer.complete(s, "cat .h")["line"], "cat .hidden ")


func test_no_completa_dentro_de_directorios_sin_permiso() -> void:
	assert_eq(Completer.complete(_session(), "ls /root/")["options"], [])
	assert_eq(Completer.complete(_session(), "ls /root/s")["line"], "ls /root/s")


# --- Historial con flechas ---

func test_flecha_arriba_y_abajo_recorren_el_historial() -> void:
	var nav := HistoryNavigator.new()
	var history := ["uno", "dos", "tres"]
	assert_eq(nav.up(history, "borrador"), "tres")
	assert_eq(nav.up(history, "tres"), "dos")
	assert_eq(nav.up(history, "dos"), "uno")
	assert_eq(nav.up(history, "uno"), "uno", "no pasa del más antiguo")
	assert_eq(nav.down(history, "uno"), "dos")
	assert_eq(nav.down(history, "dos"), "tres")
	assert_eq(nav.down(history, "tres"), "borrador", "al bajar del todo vuelve tu borrador")
	assert_eq(nav.down(history, "borrador"), "borrador")


func test_historial_vacio_no_cambia_el_texto() -> void:
	assert_eq(HistoryNavigator.new().up([], "abc"), "abc")


# --- Terminal visual ---

func _terminal() -> Control:
	var view := TerminalView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	view.setup(_session(), ["Hola laboratorio"])
	return view


func _dispose(view: Control) -> void:
	(Engine.get_main_loop() as SceneTree).root.remove_child(view)
	view.free()


func test_la_terminal_ejecuta_y_muestra_la_salida() -> void:
	var view := _terminal()
	view.submit("echo hola mundo")
	var text: String = view.output_text()
	assert_true("Hola laboratorio" in text, "muestra el banner")
	assert_true("ronin@ronin-box:~$ echo hola mundo" in text, "repite el prompt y el comando")
	assert_true("\nhola mundo" in text, "muestra la salida")
	_dispose(view)


func test_la_terminal_muestra_errores_y_actualiza_el_prompt() -> void:
	var view := _terminal()
	view.submit("cat /etc/shadow")
	assert_true("cat: /etc/shadow: Permission denied" in view.output_text())
	view.submit("cd informe")
	assert_eq(view.prompt_label.text, "ronin@ronin-box:~/informe$ ")
	_dispose(view)


func test_los_corchetes_de_la_salida_no_se_interpretan_como_formato() -> void:
	var view := _terminal()
	view.submit("echo '[color=red]peligro[/color] [b]x[/b]'")
	assert_true("[color=red]peligro[/color] [b]x[/b]" in view.output_text(), "se ve tal cual, sin colorear")
	_dispose(view)


func test_clear_limpia_la_pantalla() -> void:
	var view := _terminal()
	view.submit("echo uno")
	view.submit("clear")
	assert_false("uno" in view.output_text())
	view.submit("echo dos")
	assert_true("dos" in view.output_text())
	_dispose(view)


func test_la_terminal_emite_una_senal_por_comando() -> void:
	var view := _terminal()
	var seen: Array = []
	view.command_executed.connect(func(line: String, result: RefCounted) -> void: seen.append([line, result.exit_code]))
	view.submit("pwd")
	view.submit("nope")
	assert_eq(seen, [["pwd", 0], ["nope", 127]])
	_dispose(view)


func _key(unicode: int, keycode: int, ctrl := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.unicode = unicode
	event.keycode = keycode
	event.ctrl_pressed = ctrl
	return event


## Simula una tecla pulsada cuando el foco NO está en el campo (el caso que había que arreglar).
func _press(view: Control, event: InputEventKey) -> void:
	view.input.release_focus()
	view._unhandled_key_input(event)


func test_el_campo_sigue_en_modo_edicion_tras_enter() -> void:
	var view := _terminal()
	assert_true(view.input.keep_editing_on_text_submit, "sin esto habría que pulsar Enter antes de cada comando")
	_dispose(view)


func test_escribir_una_letra_sin_foco_la_envia_a_la_linea_de_comandos() -> void:
	var view := _terminal()
	assert_false(view.input.has_focus(), "partimos sin foco en el campo")
	_press(view, _key("l".unicode_at(0), KEY_L))
	_press(view, _key("s".unicode_at(0), KEY_S))
	assert_eq(view.input.text, "ls", "las teclas llegan solas al prompt")
	_dispose(view)


func test_enter_backspace_y_tab_funcionan_sin_foco() -> void:
	var view := _terminal()
	for letter in "pwdx":
		_press(view, _key(letter.unicode_at(0), KEY_A))
	_press(view, _key(0, KEY_BACKSPACE))
	assert_eq(view.input.text, "pwd")
	_press(view, _key(0, KEY_ENTER))
	assert_eq(view.input.text, "", "Enter ejecuta y limpia la línea")
	assert_true("/home/ronin" in view.output_text(), "se ejecutó pwd")
	for letter in "cat no":
		_press(view, _key(letter.unicode_at(0), KEY_A))
	_press(view, _key(0, KEY_TAB))
	assert_eq(view.input.text, "cat nota.txt ")
	_dispose(view)


func test_las_combinaciones_con_ctrl_no_se_escriben_como_texto() -> void:
	var view := _terminal()
	_press(view, _key("c".unicode_at(0), KEY_C, true))
	assert_eq(view.input.text, "")
	_press(view, _key(0, KEY_F2))
	assert_eq(view.input.text, "", "las teclas de función no escriben nada")
	_dispose(view)


func test_flechas_e_input_de_la_terminal() -> void:
	var view := _terminal()
	view.submit("pwd")
	view.submit("whoami")
	view.input.text = "bor"
	view.history_up()
	assert_eq(view.input.text, "whoami")
	view.history_up()
	assert_eq(view.input.text, "pwd")
	view.history_down()
	view.history_down()
	assert_eq(view.input.text, "bor")
	view.input.text = "cat no"
	view.complete_input()
	assert_eq(view.input.text, "cat nota.txt ")
	_dispose(view)
