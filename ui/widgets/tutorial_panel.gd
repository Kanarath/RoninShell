extends "res://ui/widgets/modal.gd"
## Tutorial inicial de unas pocas pantallas cortas. Se puede saltar en cualquier momento y
## volver a ver con el comando `tutorial`.

signal finished

const ButtonStyle := preload("res://ui/theme/button_style.gd")

const PAGES := [
	["Bienvenido, ronin", "RoninShell se aprende haciendo: escribes comandos en una terminal simulada y ves qué pasa.\n\nTodo ocurre en laboratorios ficticios y autorizados, dentro de tu ordenador. Nada sale de aquí y no puedes romper nada de verdad."],
	["La terminal", "Escribe directamente, no hace falta hacer clic. Enter ejecuta; Tab completa; las flechas ↑ ↓ repiten comandos.\n\nPrueba ahora con `ls` para ver qué hay en tu carpeta."],
	["Misiones cortas", "A la derecha ves la misión y sus objetivos, uno por uno. Cada objetivo es una victoria pequeña.\n\nNo hay temporizadores ni vidas: equivocarte no resta nada."],
	["Pistas sin penalización", "¿Atascado? Escribe `pista`: cada vez te da una ayuda más concreta, hasta la solución explicada. Es parte del aprendizaje, no un fallo.\n\nTambién tienes `<comando> --help`, `man <comando>` y la chuleta (F1)."],
	["Atajos", "F1 chuleta  ·  F3 perfil y logros  ·  F4 «¿qué hago ahora?»  ·  F5 resumen de campaña  ·  F9 menú  ·  F10 ajustes  ·  Esc cierra cualquier ventana.\n\nSi en algún momento no sabes por dónde seguir, F4 te lo dice sin gastar pistas."],
	["A tu ritmo", "El juego te recordará con suavidad que hagas pausas, y puedes apagar esos avisos, los sonidos y los efectos en F10.\n\nEl modo libre (`modo libre`) es un laboratorio sin objetivos para experimentar. Para ver este tutorial otra vez: `tutorial`."],
]

var page_index := 0
var _title := Label.new()
var _text := Label.new()
var _counter := Label.new()
var _previous := Button.new()
var _next := Button.new()
var _skip := Button.new()


func _init() -> void:
	super("Tutorial", Vector2(620, 340))
	_title.add_theme_color_override("font_color", Palette.GOLD)
	_title.add_theme_font_size_override("font_size", 20)
	content.add_child(_title)
	_text.add_theme_color_override("font_color", Palette.TEXT)
	_text.add_theme_font_size_override("font_size", 15)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(560, 0)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_text)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	content.add_child(bar)
	_counter.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_counter)
	for button: Button in [_skip, _previous, _next]:
		ButtonStyle.apply(button, Palette.GOLD if button == _next else Palette.TEAL)
		bar.add_child(button)
	_skip.text = "Saltar"
	_previous.text = "Anterior"
	_skip.pressed.connect(func() -> void: finish())
	_previous.pressed.connect(func() -> void: previous())
	_next.pressed.connect(func() -> void: next())
	go(0)


func open() -> void:
	go(0)
	super.open()


func go(index: int) -> void:
	page_index = clampi(index, 0, PAGES.size() - 1)
	_title.text = PAGES[page_index][0]
	_text.text = PAGES[page_index][1]
	_counter.text = "%d / %d" % [page_index + 1, PAGES.size()]
	_previous.disabled = page_index == 0
	_next.text = "Empezar" if page_index == PAGES.size() - 1 else "Siguiente"


func next() -> void:
	if page_index >= PAGES.size() - 1:
		finish()
	else:
		go(page_index + 1)


func previous() -> void:
	go(page_index - 1)


## Cerrar (terminar o saltar) cuenta como "ya visto".
func finish() -> void:
	close()
	finished.emit()
