extends Control
## Menú inicial (y de pausa, con F9): continuar, nueva partida, ajustes, pruebas y salir.
## "Nueva partida" pide confirmación cuando hay una partida guardada: borra el progreso.

signal continue_pressed
signal new_game_confirmed
signal settings_pressed
signal debug_pressed
signal quit_pressed

const Palette := preload("res://ui/theme/palette.gd")
const ButtonStyle := preload("res://ui/theme/button_style.gd")

var continue_button := Button.new()
var new_game_button := Button.new()
var settings_button := Button.new()
var debug_button := Button.new()
var quit_button := Button.new()
var confirm_yes := Button.new()
var confirm_no := Button.new()
var summary := Label.new()
var _confirm_box := VBoxContainer.new()
var _buttons := VBoxContainer.new()
var _has_save := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var backdrop := ColorRect.new()
	backdrop.color = Color(Palette.BG, 0.97)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var watermark := Label.new()
	watermark.text = "浪人"
	watermark.add_theme_font_size_override("font_size", 300)
	watermark.add_theme_color_override("font_color", Color(Palette.TEAL, 0.07))
	watermark.set_anchors_preset(Control.PRESET_CENTER)
	watermark.grow_horizontal = Control.GROW_DIRECTION_BOTH
	watermark.grow_vertical = Control.GROW_DIRECTION_BOTH
	watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(watermark)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(360, 0)
	center.add_child(column)

	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 0)
	title.add_child(_label("RONIN", Palette.TEAL, 52))
	title.add_child(_label("SHELL", Palette.GOLD, 52))
	column.add_child(title)
	var subtitle := _label("Aprende pentesting haciendo", Palette.TEXT_DIM, 15)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(_spacer(14))

	summary.add_theme_color_override("font_color", Palette.GOLD)
	summary.add_theme_font_size_override("font_size", 13)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(summary)

	_buttons.add_theme_constant_override("separation", 8)
	column.add_child(_buttons)
	_add_button(continue_button, "Continuar partida", func() -> void: continue_pressed.emit(), Palette.GOLD)
	_add_button(new_game_button, "Nueva partida", _on_new_game)
	_add_button(settings_button, "Ajustes", func() -> void: settings_pressed.emit())
	_add_button(debug_button, "Modo pruebas", func() -> void: debug_pressed.emit(), Palette.TEXT_DIM)
	_add_button(quit_button, "Salir", func() -> void: quit_pressed.emit(), Palette.TEXT_DIM)

	# Confirmación de "Nueva partida": solo aparece si hay algo que borrar.
	_confirm_box.visible = false
	_confirm_box.add_theme_constant_override("separation", 8)
	var warning := _label("Esto borra tu progreso, tus evidencias y tus repasos. No se puede deshacer.", Palette.DANGER, 13)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.custom_minimum_size = Vector2(360, 0)
	_confirm_box.add_child(warning)
	var yes_no := HBoxContainer.new()
	yes_no.add_theme_constant_override("separation", 8)
	confirm_yes.text = "Sí, borrar y empezar"
	confirm_no.text = "Cancelar"
	for button: Button in [confirm_yes, confirm_no]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		yes_no.add_child(button)
	ButtonStyle.apply(confirm_yes, Palette.DANGER)
	ButtonStyle.apply(confirm_no)
	confirm_yes.pressed.connect(_on_confirm_yes)
	confirm_no.pressed.connect(_cancel_confirm)
	_confirm_box.add_child(yes_no)
	column.add_child(_confirm_box)

	column.add_child(_spacer(10))
	var hint := _label("F9 abre este menú en cualquier momento", Palette.TEAL_DIM, 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


## Abre el menú. "can_continue": hay una partida (guardada o en curso) a la que volver.
func open_menu(can_continue: bool, summary_text := "") -> void:
	_has_save = can_continue
	continue_button.disabled = not can_continue
	continue_button.text = "Continuar partida" if can_continue else "Continuar (aún no hay partida)"
	ButtonStyle.apply(continue_button, Palette.GOLD)
	summary.text = summary_text
	_cancel_confirm()
	visible = true
	(continue_button if can_continue else new_game_button).grab_focus.call_deferred()


func close_menu() -> void:
	_cancel_confirm()
	visible = false


func is_open() -> bool:
	return visible


func _on_new_game() -> void:
	if not _has_save:
		new_game_confirmed.emit()   # no hay nada que borrar: se empieza directamente
		return
	_buttons.visible = false
	_confirm_box.visible = true
	confirm_no.grab_focus.call_deferred()


func _on_confirm_yes() -> void:
	_cancel_confirm()
	new_game_confirmed.emit()


func _cancel_confirm() -> void:
	_confirm_box.visible = false
	_buttons.visible = true


func _add_button(button: Button, text: String, action: Callable, accent: Color = Palette.TEAL) -> void:
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 16)
	ButtonStyle.apply(button, accent)
	button.pressed.connect(action)
	_buttons.add_child(button)


func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
