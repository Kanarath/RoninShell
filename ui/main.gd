extends Control
## Pantalla principal "ronin neón". La interfaz solo muestra: el estado sale del motor
## (engine/) y el progreso del motor de misiones. Aquí no hay reglas de juego.

const Palette := preload("res://ui/theme/palette.gd")
const CutFrame := preload("res://ui/widgets/cut_frame.gd")
const SealIcon := preload("res://ui/widgets/seal_icon.gd")
const NetworkMap := preload("res://ui/widgets/network_map.gd")
const TerminalView := preload("res://ui/widgets/terminal_view.gd")
const Mascot := preload("res://ui/widgets/mascot.gd")
const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const MissionTracker := preload("res://engine/missions/mission_tracker.gd")
const SaveStore := preload("res://game/save_store.gd")
const Settings := preload("res://game/settings.gd")
const SettingsStore := preload("res://game/settings_store.gd")
const BreakReminder := preload("res://game/break_reminder.gd")
const CheatsheetPanel := preload("res://ui/widgets/cheatsheet_panel.gd")
const SettingsPanel := preload("res://ui/widgets/settings_panel.gd")
const CrtShader := preload("res://ui/shaders/crt_overlay.gdshader")

const LAB_PATH := "res://data/labs/primer_contacto.json"
const MISSIONS_PATH := "res://data/missions/primer_contacto.json"
const DOSSIER_SLOTS := 4

var world: RefCounted = null
var session: RefCounted = null
var mission_engine: RefCounted = null
var tracker: RefCounted = null
var terminal := TerminalView.new()
## Si es false no se lee ni se escribe progreso (tests y capturas con --no-save).
var persist := true

var mascot := Mascot.new()
var network_map: Control = null
var settings: RefCounted = Settings.new()
var cheatsheet_panel := CheatsheetPanel.new()
var settings_panel := SettingsPanel.new()
var break_reminder := BreakReminder.new()
var _settings_store := SettingsStore.new()
var _overlay := ColorRect.new()
var _store := SaveStore.new()
var _mission_label := Label.new()
var _level_label := Label.new()
var _xp_bar := ProgressBar.new()
var _objectives_frame: Control = null
var _dossier_frame: Control = null
var _dossier_grid := GridContainer.new()


func _ready() -> void:
	persist = not ("--no-save" in OS.get_cmdline_user_args() or Engine.has_meta("roninshell_no_save"))
	var result := LabLoader.load_file(LAB_PATH)
	if result["world"] == null:
		push_error("No se pudo cargar el laboratorio: %s" % str(result["errors"]))
	world = result["world"]

	if persist:
		settings = _settings_store.load_settings()

	_build_background()
	_build_layout()
	_build_modals()
	_build_overlay()
	_start_session()
	_refresh_missions()
	_apply_settings()

	var demo_commands: Array = []
	var screenshot_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run="):
			demo_commands = arg.trim_prefix("--run=").split("~~")
		elif arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
		elif arg == "--open=cheatsheet":
			cheatsheet_panel.open()
		elif arg == "--open=settings":
			settings_panel.open()
	for command: String in demo_commands:
		terminal.submit(command)
	if screenshot_path != "":
		_capture_and_quit(screenshot_path)


## Esc cierra cualquier ventana abierta (se mira antes que los controles, que a veces se lo comen).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if cheatsheet_panel.is_open() or settings_panel.is_open():
			cheatsheet_panel.close()
			settings_panel.close()
			get_viewport().set_input_as_handled()


## F1 chuleta, F10 ajustes, F2 efectos.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			settings_panel.close()
			cheatsheet_panel.toggle()
		KEY_F10:
			cheatsheet_panel.close()
			settings_panel.toggle()
		KEY_F2:
			settings.vfx_enabled = not settings.vfx_enabled
			settings_panel.apply(settings)
			_apply_settings()
			_save_settings()


## Aviso de descanso: cuenta tiempo de juego y avisa con suavidad, sin bloquear nada.
func _process(delta: float) -> void:
	if break_reminder.tick(delta):
		terminal.print_text("Llevas %d minutos seguidos. Una pausa corta (agua, estirar, mirar lejos) ayuda a seguir con la cabeza clara. Puedes ignorar este aviso o apagarlo con F10." % break_reminder.interval_minutes, Palette.GOLD)
		mascot.react("think", 5.0)


func _build_modals() -> void:
	for panel in [cheatsheet_panel, settings_panel]:
		add_child(panel)
		panel.opened.connect(_on_modal_changed)
		panel.closed.connect(_on_modal_changed)
	settings_panel.changed.connect(_on_settings_changed)


## Mientras hay una ventana abierta, el teclado es suyo; al cerrarla, vuelve a la terminal.
func _on_modal_changed() -> void:
	var any_open: bool = cheatsheet_panel.is_open() or settings_panel.is_open()
	terminal.typing_enabled = not any_open
	if any_open:
		terminal.input.release_focus()
	else:
		terminal.focus_input()


func _on_settings_changed(new_settings: RefCounted) -> void:
	settings = new_settings
	_apply_settings()
	_save_settings()


func _save_settings() -> void:
	if persist:
		_settings_store.save(settings)


func _apply_settings() -> void:
	_overlay.visible = settings.vfx_enabled
	(_overlay.material as ShaderMaterial).set_shader_parameter("intensity", settings.vfx_intensity)
	terminal.set_font_size(settings.font_size)
	terminal.set_high_contrast(settings.high_contrast)
	mascot.visible = settings.mascot_enabled
	break_reminder.enabled = settings.break_enabled
	break_reminder.interval_minutes = settings.break_minutes
	settings_panel.apply(settings)


# --- Sesión y misiones --------------------------------------------------------

func _start_session() -> void:
	if world == null:
		terminal.print_text("No se pudo cargar el laboratorio.", Palette.DANGER)
		return

	var banner: Array = ["RoninShell  -  laboratorio \"%s\"" % world.title]
	var loaded := MissionLoader.load_file(MISSIONS_PATH)
	if loaded["book"] != null:
		mission_engine = MissionEngine.new(loaded["book"])
		tracker = MissionTracker.new(mission_engine)
		if persist and _store.load_into(mission_engine):
			banner.append("Progreso restaurado. Escribe `mision` para ver dónde estabas.")
		else:
			banner.append("Escribe `mision` para ver tu primer objetivo y `help` para ver los comandos. Tab completa.")
	else:
		push_error("No se pudieron cargar las misiones: %s" % str(loaded["errors"]))

	session = ShellSession.new(world, CommandSet.create_registry(tracker))
	session.tracker = tracker
	banner.append("")
	terminal.setup(session, banner)
	terminal.command_executed.connect(_on_command_executed)
	network_map.session = session
	network_map.refresh()


func _on_command_executed(line: String, result: RefCounted) -> void:
	_react(line, result)
	network_map.refresh()
	_refresh_missions()
	if persist and mission_engine != null:
		_store.save(mission_engine)


## La mascota reacciona: celebra los objetivos, se alarma con un error y piensa si pides ayuda.
func _react(line: String, result: RefCounted) -> void:
	var first_word := line.strip_edges().get_slice(" ", 0)
	var completed := false
	for notice: String in result.notices:
		completed = completed or notice.begins_with("[+]") or notice.begins_with("***")
	if completed:
		mascot.react("happy", 3.5)
	elif first_word in ["pista", "man", "help", "cheatsheet"] or " --help" in line:
		mascot.react("think", 3.0)
	elif result.exit_code != 0 or result.stderr != "":
		mascot.react("alert", 2.5)


## Redibuja los paneles que dependen del progreso: misión, objetivos, XP y evidencias.
func _refresh_missions() -> void:
	if mission_engine == null:
		return
	if mission_engine.is_finished():
		_mission_label.text = "LABORATORIO COMPLETADO"
	else:
		_mission_label.text = "MISIÓN %d  ·  %s" % [mission_engine.mission_index + 1, mission_engine.current_mission()["title"].to_upper()]
	_level_label.text = "NV %d" % mission_engine.level()
	_xp_bar.value = mission_engine.level_progress() * 100.0
	_rebuild_objectives()
	_rebuild_dossier()


func _rebuild_objectives() -> void:
	var content: VBoxContainer = _objectives_frame.content
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if mission_engine.is_finished():
		content.add_child(_colored_label("Has completado todas las misiones.", Palette.GOLD, 14))
		return

	var active: Dictionary = mission_engine.active_objective()
	for objective: Dictionary in mission_engine.objectives():
		if mission_engine.is_optional(objective):
			continue  # la autoevaluación opcional no ocupa sitio: se avisa con una línea aparte
		# El sello ya cuenta el estado; solo el objetivo actual lleva una etiqueta de texto.
		var state := SealIcon.State.PENDING
		var tag := ""
		if mission_engine.status_of(objective["id"]) == "done":
			state = SealIcon.State.DONE
		elif not mission_engine.is_available(objective):
			state = SealIcon.State.LOCKED
		elif not active.is_empty() and active["id"] == objective["id"]:
			state = SealIcon.State.ACTIVE
			tag = "PREGUNTA: escribe  responder" if objective.has("question") else "EN CURSO"

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var seal := SealIcon.new()
		seal.state = state
		seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(seal)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		var title_color: Color = Palette.TEXT_DIM if state in [SealIcon.State.DONE, SealIcon.State.LOCKED] else Palette.TEXT
		var title := _colored_label(objective.get("short", objective["text"]), title_color, 13)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(title)
		if tag != "":
			texts.add_child(_colored_label("[%s]" % tag, Palette.TEAL, 10))
		row.add_child(texts)
		content.add_child(row)

	if not mission_engine.active_question().is_empty():
		content.add_child(_colored_label("+ Autoevaluación opcional: escribe  responder", Palette.TEAL_DIM, 11))


func _rebuild_dossier() -> void:
	for child in _dossier_grid.get_children():
		_dossier_grid.remove_child(child)
		child.queue_free()
	var collected: Array = []
	for card: Dictionary in mission_engine.evidence_cards():
		if card["collected"]:
			collected.append(card)
	var shown: Array = collected.slice(maxi(0, collected.size() - DOSSIER_SLOTS))
	for slot in DOSSIER_SLOTS:
		if slot < shown.size():
			_dossier_grid.add_child(_evidence_card(shown[slot]["title"], true))
		else:
			_dossier_grid.add_child(_evidence_card("?", false))


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
	_objectives_frame = _build_objectives_panel()
	side.add_child(_objectives_frame)
	side.add_child(_build_map_panel())
	_dossier_frame = _build_dossier_panel()
	side.add_child(_dossier_frame)


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 70)

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	bar.add_child(left)
	mascot.name = "Mascot"
	mascot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(mascot)
	_mission_label.name = "MissionLabel"
	_mission_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mission_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	left.add_child(_mission_label)

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
	hint.text = "F1  chuleta   F10  ajustes   F2  efectos"
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
	_level_label.text = "NV 1"
	_level_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_level_label.add_theme_font_size_override("font_size", 12)
	row.add_child(_level_label)

	_xp_bar.custom_minimum_size = Vector2(340, 8)
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.show_percentage = false
	_xp_bar.value = 0.0
	var back := StyleBoxFlat.new()
	back.bg_color = Palette.PANEL_DEEP
	back.border_color = Palette.TEAL_DIM
	back.set_border_width_all(1)
	back.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.GOLD
	fill.set_corner_radius_all(4)
	_xp_bar.add_theme_stylebox_override("background", back)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	row.add_child(_xp_bar)
	return row


func _build_terminal_panel() -> Control:
	var frame := CutFrame.new()
	frame.name = "Terminal"
	frame.title = "Terminal"
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 3.0
	terminal.name = "TerminalView"
	frame.content.add_child(terminal)
	return frame


func _build_objectives_panel() -> Control:
	var frame := CutFrame.new()
	frame.name = "Objectives"
	frame.title = "Objetivos de misión"
	frame.content.add_theme_constant_override("separation", 4)
	return frame


func _build_map_panel() -> Control:
	var frame := CutFrame.new()
	frame.name = "Map"
	frame.title = "Mapa de red"
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	network_map = NetworkMap.new()
	network_map.name = "NetworkMap"
	network_map.world = world
	network_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.content.add_child(network_map)
	return frame


func _build_dossier_panel() -> Control:
	var frame := CutFrame.new()
	frame.name = "Dossier"
	frame.title = "Expediente de evidencias"
	_dossier_grid.columns = 2
	_dossier_grid.add_theme_constant_override("h_separation", 10)
	_dossier_grid.add_theme_constant_override("v_separation", 6)
	frame.content.add_child(_dossier_grid)
	return frame


func _evidence_card(label: String, collected: bool) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 28)
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
