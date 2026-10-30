extends VBoxContainer
## Terminal interactiva: salida con scroll arriba, prompt y línea de entrada abajo.
## Solo presenta: ejecutar es cosa de la sesión de shell (engine/).
##
## Teclas: Enter ejecuta, flechas arriba/abajo recorren el historial,
## Tab autocompleta, Ctrl+L limpia la pantalla. "clear" también la limpia.

signal command_executed(line: String, result: RefCounted)

const Palette := preload("res://ui/theme/palette.gd")
const Completer := preload("res://engine/shell/completer.gd")
const HistoryNavigator := preload("res://engine/shell/history_navigator.gd")

const FONT_SIZE := 17
const HIGH_CONTRAST_TEXT := Color("f4fffb")

var session: RefCounted = null
## Si es false, las teclas no se desvían a la línea de comandos (p. ej. mientras hay un menú abierto).
var typing_enabled := true
var font_size := FONT_SIZE
var output := RichTextLabel.new()
var input := LineEdit.new()
var prompt_label := Label.new()
var _navigator := HistoryNavigator.new()
var _mono := SystemFont.new()


func _init() -> void:
	_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)

	output.bbcode_enabled = true
	output.scroll_following = true
	output.selection_enabled = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.add_theme_font_override("normal_font", _mono)
	output.add_theme_font_override("bold_font", _mono)
	output.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	output.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	output.add_theme_color_override("default_color", Palette.TEXT)
	output.gui_input.connect(_on_output_gui_input)
	add_child(output)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	add_child(row)

	prompt_label.add_theme_font_override("font", _mono)
	prompt_label.add_theme_font_size_override("font_size", FONT_SIZE)
	prompt_label.add_theme_color_override("font_color", Palette.GOLD)
	row.add_child(prompt_label)

	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.caret_blink = true
	# Sin esto, tras pulsar Enter el campo sale del modo edición y hay que pulsar Enter otra
	# vez antes de poder escribir: una terminal de verdad siempre está lista para teclear.
	input.keep_editing_on_text_submit = true
	input.context_menu_enabled = false
	input.add_theme_font_override("font", _mono)
	input.add_theme_font_size_override("font_size", FONT_SIZE)
	input.add_theme_color_override("font_color", Palette.TEXT)
	input.add_theme_color_override("caret_color", Palette.GOLD)
	input.add_theme_color_override("selection_color", Color(Palette.TEAL, 0.3))
	for state in ["normal", "focus", "read_only"]:
		input.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	input.text_submitted.connect(_on_text_submitted)
	input.gui_input.connect(_on_input_gui_input)
	row.add_child(input)


## Conecta la terminal con una sesión de shell y muestra el mensaje de bienvenida.
func setup(shell_session: RefCounted, banner: Array = []) -> void:
	session = shell_session
	for line: String in banner:
		print_text(line, Palette.TEXT_DIM)
	_update_prompt()
	focus_input.call_deferred()


## Cambia a otra sesión (reinicio del laboratorio, repaso...) sin borrar lo que ya hay en pantalla.
func replace_session(new_session: RefCounted, lines: Array = []) -> void:
	session = new_session
	_navigator.reset()
	for line: String in lines:
		print_text(line, Palette.TEXT_DIM if line != "" else Palette.TEXT)
	_update_prompt()
	focus_input.call_deferred()


## Ejecuta una línea como si el jugador la hubiera escrito y pulsado Enter.
func submit(line: String) -> void:
	if session == null:
		return
	_navigator.reset()
	_append_bbcode("[color=#%s]%s[/color]%s" % [Palette.GOLD.to_html(false), _escape(session.prompt()), _escape(line)])

	if line.strip_edges() == "clear":
		clear_screen()
		_update_prompt()
		return

	var result: RefCounted = session.run(line)
	if result.stdout != "":
		print_text(result.stdout.trim_suffix("\n"), Palette.TEXT)
	if result.stderr != "":
		print_text(result.stderr.trim_suffix("\n"), Palette.DANGER)
	for notice in result.notices:
		print_text(notice, Palette.GOLD)
	_update_prompt()
	command_executed.emit(line, result)


## Pone el cursor en la línea de comandos, listo para escribir.
func focus_input() -> void:
	if not typing_enabled:
		return
	input.grab_focus()
	input.edit()


## Cambia el tamaño de letra de toda la terminal (salida, prompt y línea de entrada).
func set_font_size(new_size: int) -> void:
	font_size = new_size
	output.add_theme_font_size_override("normal_font_size", new_size)
	output.add_theme_font_size_override("bold_font_size", new_size)
	prompt_label.add_theme_font_size_override("font_size", new_size)
	input.add_theme_font_size_override("font_size", new_size)


## Alto contraste: texto casi blanco, para quien necesita más diferencia con el fondo.
func set_high_contrast(enabled: bool) -> void:
	var color: Color = HIGH_CONTRAST_TEXT if enabled else Palette.TEXT
	output.add_theme_color_override("default_color", color)
	input.add_theme_color_override("font_color", color)


## Cualquier tecla que no haya consumido otro control va a la línea de comandos, como en una
## terminal real: no hace falta hacer clic ni pulsar Enter antes de escribir.
func _unhandled_key_input(event: InputEvent) -> void:
	if session == null or not typing_enabled or not (event is InputEventKey) or not event.pressed or input.has_focus():
		return
	var key := event as InputEventKey
	var is_text := key.unicode >= 32 and key.unicode != 127 and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed
	var is_navigation := key.keycode in [KEY_UP, KEY_DOWN, KEY_TAB, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER]
	if not is_text and not is_navigation:
		return
	focus_input()
	if is_text:
		input.insert_text_at_caret(char(key.unicode))
	elif key.keycode == KEY_BACKSPACE:
		input.delete_char_at_caret()
	elif key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		var line := input.text
		input.clear()
		submit(line)
	else:
		_on_input_gui_input(key)
	get_viewport().set_input_as_handled()


func print_text(text: String, color: Color) -> void:
	_append_bbcode("[color=#%s]%s[/color]" % [color.to_html(false), _escape(text)])


func clear_screen() -> void:
	output.clear()


## Texto visible de la salida, sin formato (para tests y para misiones).
func output_text() -> String:
	return output.get_parsed_text()


func history_up() -> void:
	input.text = _navigator.up(session.history, input.text)
	input.caret_column = input.text.length()


func history_down() -> void:
	input.text = _navigator.down(session.history, input.text)
	input.caret_column = input.text.length()


func complete_input() -> void:
	var result := Completer.complete(session, input.text)
	var changed: bool = result["line"] != input.text
	input.text = result["line"]
	input.caret_column = input.text.length()
	if result["options"].size() > 1 and not changed:
		print_text("  ".join(result["options"]), Palette.TEXT_DIM)


## Un clic en la pantalla de la terminal devuelve el cursor a la línea de comandos
## (salvo que estés seleccionando texto para copiarlo).
func _on_output_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if output.get_selected_text() == "":
			focus_input.call_deferred()


func _on_text_submitted(text: String) -> void:
	input.clear()
	submit(text)
	focus_input.call_deferred()


func _on_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_UP:
			history_up()
		KEY_DOWN:
			history_down()
		KEY_TAB:
			complete_input()
		KEY_L:
			if not event.ctrl_pressed:
				return
			clear_screen()
		_:
			return
	input.accept_event()


func _update_prompt() -> void:
	prompt_label.text = session.prompt() if session != null else ""


func _append_bbcode(bbcode: String) -> void:
	output.append_text(bbcode + "\n")


## Evita que "[" en la salida se interprete como una etiqueta de formato.
func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
