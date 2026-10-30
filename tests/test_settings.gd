extends "res://tests/framework/test_case.gd"
## Ajustes, aviso de descanso, panel de chuleta y menú de ajustes.

const Settings := preload("res://game/settings.gd")
const SettingsStore := preload("res://game/settings_store.gd")
const BreakReminder := preload("res://game/break_reminder.gd")
const CheatsheetPanel := preload("res://ui/widgets/cheatsheet_panel.gd")
const SettingsPanel := preload("res://ui/widgets/settings_panel.gd")
const TerminalView := preload("res://ui/widgets/terminal_view.gd")
const CommandDocs := preload("res://engine/commands/command_docs.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _key(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	return event


# --- Modelo de ajustes ---

func test_ajustes_por_defecto() -> void:
	var s := Settings.new()
	assert_true(s.vfx_enabled and s.mascot_enabled and s.break_enabled)
	assert_false(s.high_contrast)
	assert_eq([s.font_size, s.break_minutes, s.vfx_intensity], [17, 45, 1.0])


func test_los_ajustes_se_corrigen_si_estan_fuera_de_rango_o_mal_tipados() -> void:
	var s := Settings.from_dict({"font_size": 999, "break_minutes": 1, "vfx_intensity": 7.5, "vfx_enabled": "no"})
	assert_eq(s.font_size, Settings.FONT_MAX)
	assert_eq(s.break_minutes, Settings.BREAK_MIN)
	assert_eq(s.vfx_intensity, 1.0)
	assert_true(Settings.from_dict("basura").vfx_enabled, "datos inválidos dan los valores por defecto")
	assert_eq(Settings.from_dict({"font_size": -5}).font_size, Settings.FONT_MIN)


func test_ida_y_vuelta_por_diccionario() -> void:
	var original := Settings.new()
	original.font_size = 22
	original.high_contrast = true
	original.break_minutes = 30
	var restored := Settings.from_dict(JSON.parse_string(JSON.stringify(original.to_dict())))
	assert_eq(restored.to_dict(), original.to_dict())


func test_guardado_de_ajustes_en_disco() -> void:
	var store := SettingsStore.new("user://tests_roninshell_settings.json")
	store.delete()
	assert_eq(store.load_settings().font_size, 17, "sin archivo: valores por defecto")
	var s := Settings.new()
	s.font_size = 20
	assert_true(store.save(s))
	assert_eq(store.load_settings().font_size, 20)
	store.delete()


func test_un_archivo_de_ajustes_danado_no_rompe_el_juego() -> void:
	var store := SettingsStore.new("user://tests_roninshell_broken.json")
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string("{ esto no es json")
	file.close()
	assert_eq(store.load_settings().font_size, 17)
	store.delete()


# --- Aviso de descanso ---

func test_el_aviso_de_descanso_salta_una_vez_cada_intervalo() -> void:
	var reminder := BreakReminder.new()
	reminder.interval_minutes = 10
	var fired := 0
	for second in 1250:  # algo más de 20 minutos
		if reminder.tick(1.0):
			fired += 1
	assert_eq(fired, 2, "a los 10 y a los 20 minutos")


func test_el_aviso_se_puede_apagar_y_posponer() -> void:
	var reminder := BreakReminder.new()
	reminder.interval_minutes = 10
	reminder.enabled = false
	assert_false(reminder.tick(10000.0), "apagado nunca avisa")
	reminder.enabled = true
	reminder.tick(500.0)
	assert_eq(reminder.minutes_played(), 8)
	reminder.reset()
	assert_eq(reminder.minutes_played(), 0)


# --- Chuleta ---

func test_el_panel_de_chuleta_muestra_las_mismas_secciones_que_el_comando() -> void:
	var panel := CheatsheetPanel.new()
	_tree().root.add_child(panel)
	assert_false(panel.is_open())
	panel.open()
	assert_true(panel.is_open())
	var text := _all_text(panel)
	for section: Array in CommandDocs.CHEATSHEET:
		assert_true(section[1] in text, "falta la sección %s" % section[1])
		for row: Array in section[2]:
			assert_true(row[0] in text, "falta el comando %s" % row[0])
	panel.close()
	assert_false(panel.is_open())
	_tree().root.remove_child(panel)
	panel.free()


func _all_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += node.text + "\n"
	for child in node.get_children():
		text += _all_text(child)
	return text


func test_las_ventanas_emiten_senales_al_abrir_y_cerrar() -> void:
	var panel := SettingsPanel.new()
	var events: Array = []
	panel.opened.connect(func() -> void: events.append("abre"))
	panel.closed.connect(func() -> void: events.append("cierra"))
	panel.open()
	panel.open()  # abrir otra vez no repite la señal
	panel.close()
	panel.close()
	assert_eq(events, ["abre", "cierra"])
	panel.free()


# --- Menú de ajustes ---

func test_los_controles_reflejan_y_devuelven_los_ajustes() -> void:
	var panel := SettingsPanel.new()
	var s := Settings.new()
	s.font_size = 24
	s.high_contrast = true
	s.break_minutes = 60
	s.vfx_intensity = 0.5
	panel.apply(s)
	assert_eq(panel.font_size.value, 24.0)
	assert_true(panel.high_contrast.button_pressed)
	assert_eq(panel.settings_from_controls().to_dict(), s.to_dict())
	panel.free()


func test_cambiar_un_control_emite_los_ajustes_nuevos_pero_apply_no() -> void:
	var panel := SettingsPanel.new()
	_tree().root.add_child(panel)  # los deslizadores solo emiten dentro del árbol de escenas
	var received: Array = []
	panel.changed.connect(func(settings: RefCounted) -> void: received.append(settings))
	panel.apply(Settings.new())
	assert_eq(received.size(), 0, "cargar ajustes no cuenta como un cambio del jugador")
	panel.font_size.value = 20
	assert_eq(received.size(), 1)
	assert_eq(received[0].font_size, 20)
	panel.high_contrast.button_pressed = true
	assert_true(received[-1].high_contrast)
	_tree().root.remove_child(panel)
	panel.free()


# --- Terminal: tamaño, contraste y teclado cedido a las ventanas ---

func _terminal() -> Control:
	var view := TerminalView.new()
	_tree().root.add_child(view)
	return view


func test_la_terminal_cambia_de_tamano_y_contraste() -> void:
	var view := _terminal()
	view.set_font_size(24)
	assert_eq(view.output.get_theme_font_size("normal_font_size"), 24)
	assert_eq(view.input.get_theme_font_size("font_size"), 24)
	view.set_high_contrast(true)
	assert_eq(view.output.get_theme_color("default_color"), TerminalView.HIGH_CONTRAST_TEXT)
	view.set_high_contrast(false)
	assert_true(view.output.get_theme_color("default_color") != TerminalView.HIGH_CONTRAST_TEXT)
	_tree().root.remove_child(view)
	view.free()


func test_con_una_ventana_abierta_las_teclas_no_van_al_prompt() -> void:
	var LabLoader := preload("res://engine/lab_loader.gd")
	var ShellSession := preload("res://engine/shell/shell_session.gd")
	var CommandSet := preload("res://engine/commands/command_set.gd")
	var view := _terminal()
	view.setup(ShellSession.new(LabLoader.load_file("res://data/labs/primer_contacto.json")["world"], CommandSet.create_registry()))
	view.typing_enabled = false
	var event := InputEventKey.new()
	event.pressed = true
	event.unicode = "x".unicode_at(0)
	event.keycode = KEY_X
	view.input.release_focus()
	view._unhandled_key_input(event)
	assert_eq(view.input.text, "", "con un menú abierto no se escribe en el prompt")
	view.typing_enabled = true
	view._unhandled_key_input(event)
	assert_eq(view.input.text, "x")
	_tree().root.remove_child(view)
	view.free()


# --- Pantalla principal ---

func test_f1_f10_y_esc_abren_y_cierran_las_ventanas() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var root := scene.instantiate()
	_tree().root.add_child(root)

	root._unhandled_input(_key(KEY_F1))
	assert_true(root.cheatsheet_panel.is_open())
	assert_false(root.terminal.typing_enabled, "el teclado es de la ventana")
	root._unhandled_input(_key(KEY_F10))
	assert_true(root.settings_panel.is_open())
	assert_false(root.cheatsheet_panel.is_open(), "solo una ventana a la vez")
	root._input(_key(KEY_ESCAPE))
	assert_false(root.settings_panel.is_open())
	assert_true(root.terminal.typing_enabled, "al cerrar, el teclado vuelve a la terminal")

	root._unhandled_input(_key(KEY_F2))
	assert_false(root.settings.vfx_enabled)
	assert_false(root._overlay.visible)
	root._unhandled_input(_key(KEY_F2))
	assert_true(root._overlay.visible)

	_tree().root.remove_child(root)
	root.free()


func test_aplicar_ajustes_en_la_pantalla_principal() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var root := scene.instantiate()
	_tree().root.add_child(root)
	var s := Settings.new()
	s.font_size = 22
	s.mascot_enabled = false
	s.break_minutes = 20
	s.vfx_intensity = 0.4
	root._on_settings_changed(s)
	assert_eq(root.terminal.font_size, 22)
	assert_false(root.mascot.visible)
	assert_eq(root.break_reminder.interval_minutes, 20)
	assert_eq((root._overlay.material as ShaderMaterial).get_shader_parameter("intensity"), 0.4)
	_tree().root.remove_child(root)
	root.free()
