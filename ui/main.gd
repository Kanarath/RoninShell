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
const LabController := preload("res://engine/lab_controller.gd")
const ReviewScheduler := preload("res://engine/review/review_scheduler.gd")
const SaveStore := preload("res://game/save_store.gd")
const Settings := preload("res://game/settings.gd")
const SettingsStore := preload("res://game/settings_store.gd")
const BreakReminder := preload("res://game/break_reminder.gd")
const CheatsheetPanel := preload("res://ui/widgets/cheatsheet_panel.gd")
const SettingsPanel := preload("res://ui/widgets/settings_panel.gd")
const DebugPanel := preload("res://ui/widgets/debug_panel.gd")
const StartMenu := preload("res://ui/widgets/start_menu.gd")
const CrtShader := preload("res://ui/shaders/crt_overlay.gdshader")

const LAB_PATH := "res://data/labs/primer_contacto.json"
const MISSIONS_PATH := "res://data/missions/primer_contacto.json"
const REVIEWS_PATH := "res://data/missions/repaso.json"
const DOSSIER_SLOTS := 4
const REVIEW_XP := 50
## Los laboratorios de la campaña, en el orden en que se desbloquean (cada uno tras completar el anterior).
const CAMPAIGN := [
	{"id": "primer_contacto", "book": "res://data/missions/primer_contacto.json"},
	{"id": "tienda_web", "book": "res://data/missions/tienda_web.json"},
]

## Lo "activo" (el laboratorio, la sesión y el motor que se ven ahora). Durante un repaso apuntan
## al reto; el progreso real vive siempre en main_*.
var world: RefCounted = null
var session: RefCounted = null
var mission_engine: RefCounted = null
var tracker: RefCounted = null
var main_world: RefCounted = null
var main_session: RefCounted = null
var main_engine: RefCounted = null
var main_tracker: RefCounted = null
var controller := LabController.new()
var scheduler := ReviewScheduler.new()
var review_book: Dictionary = {}
## Campaña: un motor de misiones, un seguimiento y (al visitarlo) un laboratorio y una sesión por libro.
var active_book := ""
var engines: Dictionary = {}
var trackers: Dictionary = {}
var books: Dictionary = {}
var worlds: Dictionary = {}
var sessions: Dictionary = {}
var _seen_available: Dictionary = {}
var _review_engine: RefCounted = null
var _review_session: RefCounted = null
var _active_lab_path := LAB_PATH
var terminal := TerminalView.new()
## Si es false no se lee ni se escribe progreso (tests y capturas con --no-save).
var persist := true

var mascot := Mascot.new()
var network_map: Control = null
var settings: RefCounted = Settings.new()
var cheatsheet_panel := CheatsheetPanel.new()
var settings_panel := SettingsPanel.new()
var debug_panel := DebugPanel.new()
var start_menu := StartMenu.new()
var _menu_return := false
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
	var show_menu := persist   # los tests y las capturas (sin guardado) arrancan directos al juego
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--run="):
			demo_commands = arg.trim_prefix("--run=").split("~~")
			show_menu = false
		elif arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
		elif arg == "--no-menu":
			show_menu = false
		elif arg == "--open=cheatsheet":
			cheatsheet_panel.open()
			show_menu = false
		elif arg == "--open=settings":
			settings_panel.open()
			show_menu = false
		elif arg == "--open=debug":
			debug_panel.open()
			show_menu = false
		elif arg == "--open=menu":
			show_menu = true
	for command: String in demo_commands:
		terminal.submit(command)
	if show_menu:
		_open_menu()
	if screenshot_path != "":
		_capture_and_quit(screenshot_path)


## Esc cierra cualquier ventana abierta (se mira antes que los controles, que a veces se lo comen).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _any_window_open():
			for panel in [cheatsheet_panel, settings_panel, debug_panel]:
				panel.close()
			if start_menu.is_open() and start_menu.continue_button.disabled == false:
				start_menu.close_menu()   # Esc en el menú equivale a continuar
				_on_modal_changed()
			get_viewport().set_input_as_handled()


func _any_window_open() -> bool:
	return cheatsheet_panel.is_open() or settings_panel.is_open() or debug_panel.is_open() or start_menu.is_open()


## F1 chuleta, F9 menú, F10 ajustes, F11 pruebas, F2 efectos.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			settings_panel.close()
			debug_panel.close()
			cheatsheet_panel.toggle()
		KEY_F10:
			cheatsheet_panel.close()
			debug_panel.close()
			settings_panel.toggle()
		KEY_F11:
			cheatsheet_panel.close()
			settings_panel.close()
			debug_panel.toggle()
		KEY_F9:
			if start_menu.is_open():
				start_menu.close_menu()
				_on_modal_changed()
			else:
				_open_menu()
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
	for panel in [cheatsheet_panel, settings_panel, debug_panel]:
		add_child(panel)
		panel.opened.connect(_on_modal_changed)
		panel.closed.connect(_on_modal_changed)
	settings_panel.changed.connect(_on_settings_changed)
	debug_panel.action.connect(_on_debug_action)

	# El menú va el último para quedar por encima. Desde él se abren ajustes y pruebas: se esconde
	# mientras tanto y vuelve cuando se cierran (ver _menu_return).
	add_child(start_menu)
	start_menu.continue_pressed.connect(func() -> void: start_menu.close_menu(); _on_modal_changed())
	start_menu.new_game_confirmed.connect(_new_game)
	start_menu.settings_pressed.connect(func() -> void: _open_from_menu(settings_panel))
	start_menu.debug_pressed.connect(func() -> void: _open_from_menu(debug_panel))
	start_menu.quit_pressed.connect(func() -> void: get_tree().quit())


## Mientras hay una ventana abierta, el teclado es suyo; al cerrarla, vuelve a la terminal.
func _on_modal_changed() -> void:
	var any_open := _any_window_open()
	if _menu_return and not any_open:
		_menu_return = false
		_open_menu()
		return
	terminal.typing_enabled = not any_open
	if any_open:
		terminal.input.release_focus()
	else:
		terminal.focus_input()


func _open_menu() -> void:
	for panel in [cheatsheet_panel, settings_panel, debug_panel]:
		panel.close()
	_menu_return = false
	start_menu.open_menu(_has_progress(), _menu_summary())
	_on_modal_changed()


func _open_from_menu(panel: Control) -> void:
	start_menu.close_menu()
	_menu_return = true
	panel.open()


## ¿Hay una partida a la que volver? (guardada en disco o ya empezada).
func _has_progress() -> bool:
	if persist and _store.has_save():
		return true
	for id: String in engines:
		if engines[id].xp > 0:
			return true
	return false


func _menu_summary() -> String:
	if main_engine == null or not _has_progress():
		return ""
	var where := "%s  ·  " % books[active_book]["title"] if books.has(active_book) else ""
	if main_engine.is_finished():
		return "%sLaboratorio completado  ·  NV %d" % [where, main_engine.level()]
	return "%sMisión %d  ·  NV %d  ·  %d XP" % [where, main_engine.mission_index + 1, main_engine.level(), main_engine.xp]


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



# --- Sesión, modos y repaso ----------------------------------------------------

func _lab_path(lab_id: String) -> String:
	return "res://data/labs/%s.json" % lab_id


func _make_session(lab_world: RefCounted, lab_tracker: RefCounted) -> RefCounted:
	var new_session := ShellSession.new(lab_world, CommandSet.create_registry(lab_tracker, controller))
	new_session.tracker = lab_tracker
	new_session.free_mode = controller.mode == "libre"
	return new_session



func _start_session() -> void:
	if world == null:
		terminal.print_text("No se pudo cargar el laboratorio.", Palette.DANGER)
		return

	# Todos los libros de la campaña, cada uno con su motor de progreso.
	for entry: Dictionary in CAMPAIGN:
		var loaded := MissionLoader.load_file(entry["book"])
		if loaded["book"] == null:
			push_error("No se pudieron cargar las misiones de %s: %s" % [entry["id"], str(loaded["errors"])])
			continue
		var engine := MissionEngine.new(loaded["book"])
		engine.on_objective_done = func(objective: Dictionary, mastery: String) -> void:
			scheduler.schedule(objective["concept"], mastery, controller.now())
		engines[entry["id"]] = engine
		trackers[entry["id"]] = MissionTracker.new(engine)
		books[entry["id"]] = loaded["book"]
	if engines.is_empty():
		terminal.print_text("No se pudieron cargar las misiones.", Palette.DANGER)
		return
	active_book = CAMPAIGN[0]["id"]

	var reviews := MissionLoader.load_file(REVIEWS_PATH)
	if reviews["book"] != null:
		review_book = reviews["book"]
	else:
		push_error("No se pudieron cargar los retos de repaso: %s" % str(reviews["errors"]))
	controller.scheduler = scheduler
	controller.review_book = review_book

	var restored := persist and _load_progress()
	_update_book_states()
	for id: String in controller.book_states:
		if controller.book_states[id] != "bloqueado":
			_seen_available[id] = true   # lo ya disponible al arrancar no se anuncia como novedad

	var loaded_lab := LabLoader.load_file(_lab_path(books[active_book]["lab"]))
	if loaded_lab["world"] == null:
		terminal.print_text("No se pudo cargar el laboratorio: %s" % str(loaded_lab["errors"]), Palette.DANGER)
		return
	main_engine = engines[active_book]
	main_tracker = trackers[active_book]
	mission_engine = main_engine
	tracker = main_tracker
	world = loaded_lab["world"]
	main_world = world
	worlds[active_book] = world
	_active_lab_path = _lab_path(books[active_book]["lab"])

	var banner: Array = ["RoninShell  -  laboratorio \"%s\"" % world.title]
	banner.append("Progreso restaurado. Escribe `mision` para ver dónde estabas." if restored else "Escribe `mision` para ver tu primer objetivo y `help` para ver los comandos. Tab completa.")
	var due := controller.due_reviews()
	if not due.is_empty():
		banner.append("Tienes %d concepto(s) para repasar. Escribe `repaso` cuando quieras: es opcional y nunca resta." % due.size())

	session = _make_session(world, tracker)
	main_session = session
	sessions[active_book] = session
	banner.append("")
	terminal.clear_screen()
	terminal.setup(session, banner)
	if not terminal.command_executed.is_connected(_on_command_executed):
		terminal.command_executed.connect(_on_command_executed)
	network_map.world = world
	network_map.session = session
	network_map.refresh()
	debug_panel.setup(_campaign_info(), controller.review_concepts())


## Los laboratorios y sus misiones, para el panel de pruebas.
func _campaign_info() -> Array:
	var info: Array = []
	for entry: Dictionary in CAMPAIGN:
		var id: String = entry["id"]
		if not books.has(id):
			continue
		var titles: Array = []
		for mission: Dictionary in books[id]["missions"]:
			titles.append(mission["title"])
		info.append({"id": id, "title": books[id]["title"], "missions": titles})
	return info


## Empieza una partida desde cero: borra el progreso guardado y recarga todo.
func _new_game() -> void:
	_reboot(true)
	start_menu.close_menu()
	_on_modal_changed()


func _reboot(delete_saved: bool) -> void:
	engines.clear()
	trackers.clear()
	books.clear()
	worlds.clear()
	sessions.clear()
	_seen_available.clear()
	scheduler = ReviewScheduler.new()
	controller.mode = "mision"
	controller.current_review_concept = ""
	controller.take_requests()
	_review_engine = null
	_review_session = null
	if delete_saved and persist:
		_store.delete()
	_start_session()
	_refresh_missions()
	mascot.react("idle")


# --- Modo pruebas -----------------------------------------------------------------

func _on_debug_action(action_name: String, data: Dictionary) -> void:
	var keep_open := false
	match action_name:
		"jump_mission":
			debug_jump_mission(data["book"], int(data["index"]))
		"mode_free":
			_debug_mode("libre")
		"mode_mision":
			_debug_mode("mision")
		"review":
			_debug_review(data["concept"])
		"review_exit":
			if controller.mode == "repaso":
				_exit_review("[prueba] Has salido del repaso.")
		"open_cheatsheet":
			cheatsheet_panel.open()
		"open_settings":
			settings_panel.open()
		"open_menu":
			_open_menu()
			return
		"give_xp":
			main_engine.award_xp(300)
			terminal.print_text("[prueba] +300 XP", Palette.GOLD)
			keep_open = true
		"overdue_reviews":
			for concept in controller.review_concepts():
				scheduler.schedule(concept, "solucion", controller.now() - 2.0 * 86400.0)
			terminal.print_text("[prueba] Todos los repasos marcados como atrasados. Escribe `repaso`.", Palette.GOLD)
			keep_open = true
		"reset_lab":
			_reset_lab()
		"delete_progress":
			_new_game()
			keep_open = false
	if not keep_open:
		debug_panel.close()
	_update_book_states()
	network_map.refresh()
	_refresh_missions()
	_save_progress()


## Salta a una misión: las anteriores quedan completadas (sin XP) y los laboratorios previos, terminados.
func debug_jump_mission(book_id: String, index: int) -> void:
	if not engines.has(book_id):
		return
	if controller.mode == "repaso":
		_exit_review("[prueba] Repaso cancelado por el salto.")
	controller.mode = "mision"
	session.free_mode = false
	for entry: Dictionary in CAMPAIGN:
		if entry["id"] == book_id:
			break
		engines[entry["id"]].debug_skip_to(engines[entry["id"]].book["missions"].size())
	engines[book_id].debug_skip_to(index)
	_update_book_states()
	if book_id != active_book:
		_switch_book(book_id)
	var missions: Array = books[book_id]["missions"]
	var shown := "libro completado" if index >= missions.size() else "misión %d: %s" % [index + 1, missions[index]["title"]]
	terminal.print_text("[prueba] Saltado a %s (%s)." % [shown, books[book_id]["title"]], Palette.GOLD)


func _debug_mode(mode: String) -> void:
	if controller.mode == "repaso":
		_exit_review("[prueba] Repaso cancelado.")
	controller.mode = mode
	session.free_mode = mode == "libre"
	terminal.print_text("[prueba] Modo %s." % mode, Palette.GOLD)


func _debug_review(concept: String) -> void:
	if controller.mode == "repaso":
		_exit_review("[prueba] Repaso anterior cancelado.")
	controller.mode = "repaso"
	controller.current_review_concept = concept
	_start_review(concept)


## Estado de cada laboratorio de la campaña: se desbloquea al completar el anterior.
func _update_book_states() -> void:
	var previous_done := true
	controller.book_states = {}
	controller.book_titles = {}
	for entry: Dictionary in CAMPAIGN:
		var id: String = entry["id"]
		if not engines.has(id):
			continue
		controller.book_titles[id] = books[id]["title"]
		if engines[id].is_finished():
			controller.book_states[id] = "completado"
		elif previous_done:
			controller.book_states[id] = "disponible"
		else:
			controller.book_states[id] = "bloqueado"
		previous_done = engines[id].is_finished()
	controller.active_book = active_book


## Avisa una sola vez cuando se desbloquea un laboratorio nuevo.
func _announce_unlocks() -> void:
	for id: String in controller.book_states:
		if controller.book_states[id] == "disponible" and not _seen_available.has(id):
			_seen_available[id] = true
			terminal.print_text("Nuevo laboratorio disponible: %s. Escribe `laboratorio` para verlo." % controller.book_titles[id], Palette.GOLD)
			mascot.react("happy", 4.0)


func _switch_book(id: String) -> void:
	if not engines.has(id) or id == active_book:
		return
	_save_progress()
	if not worlds.has(id):
		var loaded := LabLoader.load_file(_lab_path(books[id]["lab"]))
		if loaded["world"] == null:
			terminal.print_text("No se pudo cargar el laboratorio '%s'." % id, Palette.DANGER)
			return
		worlds[id] = loaded["world"]
		sessions[id] = _make_session(worlds[id], trackers[id])
	active_book = id
	main_engine = engines[id]
	main_tracker = trackers[id]
	main_world = worlds[id]
	main_session = sessions[id]
	mission_engine = main_engine
	tracker = main_tracker
	world = main_world
	session = main_session
	_active_lab_path = _lab_path(books[id]["lab"])
	network_map.world = world
	network_map.session = session
	var lines: Array = ["", "=== LABORATORIO: %s ===" % world.title.to_upper()]
	if not main_engine.is_finished():
		lines.append(main_engine.current_mission()["briefing"])
	lines.append("Escribe `mision` para ver tus objetivos. Tu progreso en cada laboratorio se guarda por separado.")
	lines.append("")
	terminal.replace_session(session, lines)


## Todo el progreso, listo para guardar: un bloque por libro, el libro activo y los repasos.
func campaign_to_dict() -> Dictionary:
	var campaign := {}
	for id: String in engines:
		campaign[id] = engines[id].to_dict()
	return {"campaign": campaign, "active_book": active_book, "reviews": scheduler.to_dict()}


## Restaura el progreso. Acepta también los formatos antiguos (solo el primer libro).
func load_campaign(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var first: String = CAMPAIGN[0]["id"]
	if data.has("campaign"):
		for id: String in data["campaign"]:
			if engines.has(id):
				engines[id].load_dict(data["campaign"][id])
		var saved_active := str(data.get("active_book", first))
		active_book = saved_active if engines.has(saved_active) else first
		scheduler.load_dict(data.get("reviews", {}))
	elif data.has("progress"):
		engines[first].load_dict(data["progress"])
		scheduler.load_dict(data.get("reviews", {}))
	else:
		engines[first].load_dict(data)
	return true


func _load_progress() -> bool:
	return load_campaign(_store.load_data())


func _save_progress() -> void:
	if persist and not engines.is_empty():
		_store.save_data(campaign_to_dict())


func _on_command_executed(line: String, result: RefCounted) -> void:
	_react(line, result)
	_process_requests()
	if controller.mode == "repaso":
		_check_review_finished()
	_update_book_states()
	_announce_unlocks()
	network_map.refresh()
	_refresh_missions()
	_save_progress()


## Atiende lo que han pedido los comandos (modo, reiniciar, repaso): ellos no pueden reconstruir el laboratorio.
func _process_requests() -> void:
	for request: Dictionary in controller.take_requests():
		match request["type"]:
			"reset":
				_reset_lab()
			"mode":
				session.free_mode = request["mode"] == "libre"
			"lab":
				_switch_book(request["book"])
			"review":
				_start_review(request["concept"])
			"review_exit":
				_exit_review("Has salido del repaso. Volverá a tocar más adelante.")


func _reset_lab() -> void:
	var loaded := LabLoader.load_file(_active_lab_path)
	if loaded["world"] == null:
		terminal.print_text("No se pudo reiniciar el laboratorio: %s" % str(loaded["errors"]), Palette.DANGER)
		return
	_switch_to(loaded["world"], tracker, ["Laboratorio reiniciado: archivos, permisos y descubrimientos como al principio. Tu progreso sigue intacto."])
	if controller.mode == "repaso":
		_review_session = session
	else:
		main_session = session
		sessions[active_book] = session
		worlds[active_book] = world


## Cambia a otro mundo y sesión, manteniendo lo escrito en pantalla.
func _switch_to(new_world: RefCounted, new_tracker: RefCounted, lines: Array) -> void:
	world = new_world
	tracker = new_tracker
	session = _make_session(world, tracker)
	network_map.world = world
	network_map.session = session
	terminal.replace_session(session, lines)


func _start_review(concept: String) -> void:
	var mission: Dictionary = controller.review_mission_for(concept)
	var single := MissionEngine.single_mission_book(review_book, mission.get("id", ""))
	var review_lab: String = mission.get("lab", review_book.get("lab", ""))   # cada reto puede usar su propio laboratorio
	var loaded := LabLoader.load_file(_lab_path(review_lab))
	if single.is_empty() or loaded["world"] == null:
		controller.mode = "mision"
		terminal.print_text("No se pudo preparar el reto de repaso.", Palette.DANGER)
		return
	_review_engine = MissionEngine.new(single)
	mission_engine = _review_engine
	_active_lab_path = _lab_path(review_lab)
	var review_tracker := MissionTracker.new(_review_engine)
	review_tracker.quiet_mission_end = true
	_switch_to(loaded["world"], review_tracker, [
		"",
		"=== REPASO: %s ===" % concept.replace("_", " ").to_upper(),
		mission["briefing"],
		"Otra red y otros equipos: repetir lo que hiciste antes no sirve, hay que razonarlo de nuevo. `mision` te recuerda el objetivo y `repaso salir` abandona.",
		"",
	])
	_review_session = session


func _check_review_finished() -> void:
	if _review_engine == null or not _review_engine.is_finished():
		return
	var concept := controller.current_review_concept
	var used_solution := false
	for objective: Dictionary in _review_engine.book["missions"][0]["objectives"]:
		used_solution = used_solution or _review_engine.mastery_of(objective["id"]) == "solucion"
	scheduler.record_result(concept, not used_solution, controller.now())
	if used_solution:
		_exit_review("Repaso completado viendo la solución: no pasa nada, vuelve pronto para practicarlo de nuevo.")
	else:
		main_engine.award_xp(REVIEW_XP)
		_exit_review("Repaso superado: +%d XP. Este concepto tardará más en volver a tocar." % REVIEW_XP)
		mascot.react("happy", 4.0)


func _exit_review(message: String) -> void:
	controller.mode = "mision"
	controller.current_review_concept = ""
	_review_engine = null
	mission_engine = main_engine
	tracker = main_tracker
	world = main_world
	session = main_session
	session.free_mode = false
	_active_lab_path = LAB_PATH
	network_map.world = world
	network_map.session = session
	terminal.replace_session(session, ["", message, ""])


## La mascota reacciona: celebra los objetivos, se alarma con un error y piensa si pides ayuda.
func _react(line: String, result: RefCounted) -> void:
	var first_word := line.strip_edges().get_slice(" ", 0)
	var completed := false
	for notice: String in result.notices:
		completed = completed or notice.begins_with("[+]") or notice.begins_with("***")
	if completed:
		mascot.react("happy", 3.5)
	elif first_word in ["pista", "man", "help", "cheatsheet", "repaso"] or " --help" in line:
		mascot.react("think", 3.0)
	elif result.exit_code != 0 or result.stderr != "":
		mascot.react("alert", 2.5)


## Redibuja los paneles que dependen del progreso: misión, objetivos, XP y evidencias.
func _refresh_missions() -> void:
	if mission_engine == null:
		return
	match controller.mode:
		"libre":
			_mission_label.text = "MODO LIBRE"
		"repaso":
			_mission_label.text = "REPASO  ·  %s" % controller.current_review_concept.replace("_", " ").to_upper()
		_:
			if mission_engine.is_finished():
				_mission_label.text = "LABORATORIO COMPLETADO"
			else:
				_mission_label.text = "MISIÓN %d  ·  %s" % [mission_engine.mission_index + 1, mission_engine.current_mission()["title"].to_upper()]
	# El nivel y el XP son siempre los de tu progreso real, también durante un repaso.
	_level_label.text = "NV %d" % main_engine.level()
	_xp_bar.value = main_engine.level_progress() * 100.0
	_rebuild_objectives()
	_rebuild_dossier()


func _rebuild_objectives() -> void:
	var content: VBoxContainer = _objectives_frame.content
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if controller.mode == "libre":
		var note := _colored_label("Laboratorio libre: experimenta sin objetivos ni XP. Si lo estropeas, escribe  reiniciar.  Para volver:  modo mision", Palette.TEXT_DIM, 13)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(note)
		return
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
	for card: Dictionary in main_engine.evidence_cards():
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
	hint.text = "F1  chuleta   F9  menú   F10  ajustes   F11  pruebas"
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
