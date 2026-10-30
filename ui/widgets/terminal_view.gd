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

var session: RefCounted = null
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
	input.call_deferred("grab_focus")


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
	_update_prompt()
	command_executed.emit(line, result)


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


func _on_text_submitted(text: String) -> void:
	input.clear()
	submit(text)


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
