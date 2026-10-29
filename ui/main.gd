extends Control
## Pantalla principal (maqueta jugable del diseño "ronin neón").
## La interfaz solo muestra; el estado sale del motor (engine/). Todo el contenido
## de terminal y misión de aquí es provisional hasta los pasos de intérprete y misiones.

const Palette := preload("res://ui/theme/palette.gd")
const CutFrame := preload("res://ui/widgets/cut_frame.gd")
const SealIcon := preload("res://ui/widgets/seal_icon.gd")
const NetworkMap := preload("res://ui/widgets/network_map.gd")
const LabLoader := preload("res://engine/lab_loader.gd")
const CrtShader := preload("res://ui/shaders/crt_overlay.gdshader")

const LAB_PATH := "res://data/labs/primer_contacto.json"

var world: RefCounted = null
var _terminal := RichTextLabel.new()
var _terminal_lines: Array[String] = []
var _cursor_on := true
var _overlay := ColorRect.new()
var _mono := SystemFont.new()


func _ready() -> void:
	_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
	var result := LabLoader.load_file(LAB_PATH)
	if result["world"] == null:
		push_error("No se pudo cargar el laboratorio: %s" % str(result["errors"]))
	world = result["world"]

	_build_background()
	_build_layout()
	_build_overlay()
	_fill_terminal()
	_start_cursor_blink()

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_capture_and_quit(arg.trim_prefix("--screenshot="))


func _unhandled_input(event: InputEvent) -> void:
	# F2 apaga o enciende el VFX (ajuste de accesibilidad: más adelante irá en opciones).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		_overlay.visible = not _overlay.visible


# --- Construcción de la interfaz -------------------------------------------

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var watermark := Label.new()
	watermark.text = "浪人"
	watermark.add_theme_font_size_override("font_size", 250)
	watermark.add_theme_color_override("font_color", Color(Palette.TEAL, 0.09))
	watermark.set_anchors_preset(Control.PRESET_CENTER)
	watermark.grow_horizontal = Control.GROW_DIRECTION_BOTH
	watermark.grow_vertical = Control.GROW_DIRECTION_BOTH
	watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(watermark)


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.name = "Layout"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override("margin_top", 10)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(_build_top_bar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)

	body.add_child(_build_terminal_panel())

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.25
	side.add_theme_constant_override("separation", 12)
	body.add_child(side)
	side.add_child(_build_objectives_panel())
	side.add_child(_build_map_panel())
	side.add_child(_build_dossier_panel())


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 62)

	var mission := Label.new()
	mission.text = "MISIÓN 2  ·  QUIÉN ESTÁ AHÍ"
	mission.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mission.add_theme_color_override("font_color", Palette.TEXT_DIM)
	bar.add_child(mission)

	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 4)
	bar.add_child(brand)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 10)
	brand.add_child(title_row)
	title_row.add_child(_build_hanko())
	var words := HBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.add_child(_colored_label("RONIN", Palette.TEAL, 34))
	words.add_child(_colored_label("SHELL", Palette.GOLD, 34))
	title_row.add_child(words)

	brand.add_child(_build_xp_bar())

	var hint := Label.new()
	hint.text = "F2  efectos"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Palette.TEAL_DIM)
	bar.add_child(hint)
	return bar


func _build_hanko() -> Control:
	var seal := PanelContainer.new()
	seal.custom_minimum_size = Vector2(40, 40)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.GOLD, 0.15)
	style.border_color = Palette.GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	seal.add_theme_stylebox_override("panel", style)
	var glyph := _colored_label("浪", Palette.GOLD, 22)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_child(glyph)
	return seal


func _build_xp_bar() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.add_child(_colored_label("XP", Palette.TEXT_DIM, 12))

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(340, 8)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.value = 38.0
	var back := StyleBoxFlat.new()
	back.bg_color = Palette.PANEL_DEEP
	back.border_color = Palette.TEAL_DIM
	back.set_border_width_all(1)
	back.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.GOLD
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return row


func _build_terminal_panel() -> Control:
	var frame := CutFrame.new()
	frame.name = "Terminal"
	frame.title = "Terminal"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 3.0

	_terminal.bbcode_enabled = true
	_terminal.scroll_following = true
	_terminal.selection_enabled = true
	_terminal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_terminal.add_theme_font_override("normal_font", _mono)
	_terminal.add_theme_font_override("bold_font", _mono)
	_terminal.add_theme_font_size_override("normal_font_size", 17)
	_terminal.add_theme_font_size_override("bold_font_size", 17)
	_terminal.add_theme_color_override("default_color", Palette.TEXT)
	frame.content.add_child(_terminal)
	return frame


func _build_objectives_panel() -> Control:
	var frame := CutFrame.new()
	frame.name = "Objectives"
	frame.title = "Objetivos de misión"

	var objectives := [
		["Localiza la nota de la misión", "COMPLETADO", SealIcon.State.DONE],
		["Descubre los hosts activos", "EN CURSO", SealIcon.State.ACTIVE],
		["Identifica el servicio web", "PENDIENTE", SealIcon.State.PENDING],
	]
	for objective in objectives:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var seal := SealIcon.new()
		seal.state = objective[2]
		seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(seal)

		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", 0)
		var done: bool = objective[2] == SealIcon.State.DONE
		texts.add_child(_colored_label(objective[0], Palette.TEXT if not done else Palette.TEXT_DIM, 14))
		var tag_color := Palette.GOLD if done else (Palette.TEAL if objective[2] == SealIcon.State.ACTIVE else Palette.GOLD_DIM)
		texts.add_child(_colored_label("[%s]" % objective[1], tag_color, 11))
		row.add_child(texts)
		frame.content.add_child(row)
	return frame


func _build_map_panel() -> Control:
	var frame := CutFrame.new()
	frame.name = "Map"
	frame.title = "Mapa de red"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var map := NetworkMap.new()
	map.name = "NetworkMap"
	map.world = world
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.content.add_child(map)
	return frame


func _build_dossier_panel() -> Control:
	var frame := CutFrame.new()
	frame.name = "Dossier"
	frame.title = "Expediente de evidencias"

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	frame.content.add_child(grid)

	var cards: Array = [["nota.txt", true], ["web01 · puertos", true], ["?", false], ["?", false]]
	for card_data in cards:
		grid.add_child(_evidence_card(card_data[0], card_data[1]))
	return frame


func _evidence_card(label: String, collected: bool) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 34)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	if collected:
		style.bg_color = Palette.PARCHMENT
	else:
		style.bg_color = Color(Palette.TEAL_DIM, 0.12)
		style.border_color = Palette.TEAL_DIM
		style.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", style)
	var text := _colored_label(label, Palette.INK if collected else Palette.TEAL_DIM, 13)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(text)
	return card


func _build_overlay() -> void:
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = CrtShader
	_overlay.material = material
	add_child(_overlay)


# --- Contenido provisional de la terminal ----------------------------------

func _fill_terminal() -> void:
	_terminal_lines.clear()
	if world == null:
		_terminal_lines.append("[color=#e0674f]No se pudo cargar el laboratorio.[/color]")
		_refresh_terminal()
		return
	var target = world.host_by_name("web01")
	_terminal_lines.append("[color=#d9a441]>[/color] nmap -sV %s" % target.ip)
	_terminal_lines.append("")
	_terminal_lines.append("Nmap scan report for %s (%s)" % [target.hostname, target.ip])
	_terminal_lines.append("PORT      STATE     SERVICE     VERSION")
	for service in target.services:
		_terminal_lines.append("%-9s %-9s %-11s %s %s" % [
			"%d/%s" % [service.port, service.proto], service.state, service.name,
			service.product, service.version,
		])
	_terminal_lines.append("")
	_terminal_lines.append("[color=#6fb3a5]Maqueta: esta salida se genera ya desde el estado del laboratorio, pero aún no hay intérprete (paso 3).[/color]")
	_terminal_lines.append("")
	_refresh_terminal()


func _refresh_terminal() -> void:
	var cursor := "█" if _cursor_on else " "
	var prompt := "[color=#d9a441]ronin@ronin-box[/color]:~$ %s" % cursor
	_terminal.text = "\n".join(_terminal_lines) + prompt


func _start_cursor_blink() -> void:
	var timer := Timer.new()
	timer.wait_time = 0.55
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		_cursor_on = not _cursor_on
		_refresh_terminal())
	add_child(timer)


# --- Utilidades -------------------------------------------------------------

func _colored_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _capture_and_quit(path: String) -> void:
	await get_tree().create_timer(1.0).timeout
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	get_tree().quit()
