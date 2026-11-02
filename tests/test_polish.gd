extends "res://tests/framework/test_case.gd"
## Pulido de accesibilidad y ritmo: tutorial, sonidos suaves, "¿qué hago ahora?" y los ajustes nuevos.

const Settings := preload("res://game/settings.gd")
const SoundBank := preload("res://game/sound_bank.gd")
const NowAdvice := preload("res://engine/now_advice.gd")
const TutorialPanel := preload("res://ui/widgets/tutorial_panel.gd")
const MissionLoader := preload("res://engine/missions/mission_loader.gd")
const MissionEngine := preload("res://engine/missions/mission_engine.gd")
const Missions := preload("res://tests/test_missions.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _main() -> Control:
	var root := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_tree().root.add_child(root)
	return root


func _dispose(root: Control) -> void:
	_tree().root.remove_child(root)
	root.free()


func _key(root: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	root._unhandled_input(event)


func _engine() -> RefCounted:
	return MissionEngine.new(MissionLoader.load_file("res://data/missions/primer_contacto.json")["book"])


# --- Ajustes ---

func test_los_ajustes_nuevos_tienen_valores_por_defecto_y_se_corrigen() -> void:
	var defaults := Settings.new()
	assert_true(defaults.sound_enabled)
	assert_eq(defaults.sound_volume, 0.5)
	assert_false(defaults.tutorial_done)
	var broken := Settings.from_dict({"sound_enabled": "si", "sound_volume": 9, "tutorial_done": 1})
	assert_true(broken.sound_enabled, "un tipo raro vuelve al valor por defecto")
	assert_eq(broken.sound_volume, 1.0, "el volumen se limita a 0..1")
	assert_false(broken.tutorial_done)
	var restored := Settings.from_dict(Settings.from_dict({"sound_enabled": false, "sound_volume": 0.2, "tutorial_done": true}).to_dict())
	assert_false(restored.sound_enabled)
	assert_eq(restored.sound_volume, 0.2)
	assert_true(restored.tutorial_done)
	assert_true(Settings.from_dict({}).sound_enabled, "un guardado anterior sin estos campos sigue funcionando")


func test_el_panel_de_ajustes_conserva_el_tutorial_visto() -> void:
	var root := _main()
	root.settings.tutorial_done = true
	root.settings_panel.apply(root.settings)
	assert_true(root.settings_panel.settings_from_controls().tutorial_done, "guardar ajustes no lo borra")
	root.settings_panel.sound_enabled.button_pressed = false
	assert_false(root.settings_panel.settings_from_controls().sound_enabled)
	_dispose(root)


# --- Sonidos ---

func test_los_sonidos_existen_y_son_cortos() -> void:
	assert_true(SoundBank.names().size() >= 3)
	for sound_name: String in SoundBank.names():
		var stream := SoundBank.make(sound_name)
		assert_true(stream != null, sound_name)
		assert_eq(stream.data.size(), SoundBank.sample_count(sound_name) * 2)
		var seconds := float(SoundBank.sample_count(sound_name)) / SoundBank.MIX_RATE
		assert_true(seconds > 0.1 and seconds < 1.0, "%s dura %.2f s" % [sound_name, seconds])
	assert_true(SoundBank.make("no_existe") == null)


func test_los_sonidos_no_saturan_ni_son_silencio() -> void:
	var stream := SoundBank.make("logro")
	var peak := 0
	for i in range(0, stream.data.size(), 2):
		peak = maxi(peak, absi(stream.data.decode_s16(i)))
	assert_true(peak > 3000, "se oye")
	assert_true(peak < 20000, "suave, sin saturar")


func test_un_objetivo_hace_sonar_la_campanilla_y_los_ajustes_la_silencian() -> void:
	var root := _main()
	root.settings.sound_enabled = true
	root._play_sound("objetivo")
	assert_eq(root.last_sound, "objetivo")
	root.last_sound = ""
	root.settings.sound_enabled = false
	root._play_sound("objetivo")
	assert_eq(root.last_sound, "", "con los sonidos apagados no suena")
	root.settings.sound_enabled = true
	root.settings.sound_volume = 0.0
	root._play_sound("objetivo")
	assert_eq(root.last_sound, "", "volumen cero tampoco")
	_dispose(root)


func test_completar_un_objetivo_en_la_terminal_suena() -> void:
	var root := _main()
	root.settings.sound_enabled = true
	root.terminal.submit("pwd")
	root.last_sound = ""
	root.terminal.submit("ls")
	root.terminal.submit("cat nota.txt")
	assert_true(root.last_sound in ["objetivo", "mision", "logro"], "al cumplir un objetivo suena algo (%s)" % root.last_sound)
	_dispose(root)


# --- Qué hago ahora ---

func test_ahora_describe_el_objetivo_actual_sin_gastar_pistas() -> void:
	var engine := _engine()
	var advice := NowAdvice.build(engine, "mision")
	var text := "\n".join(advice["lines"])
	assert_true("objetivo 1 de" in text)
	assert_true("Ahora toca:" in text)
	assert_true("`pista`" in text)
	assert_eq(engine.hints_used_total() if engine.has_method("hints_used_total") else 0, 0)


func test_ahora_en_modo_libre_y_con_el_libro_terminado() -> void:
	assert_true("modo mision" in "\n".join(NowAdvice.build(null, "libre")["lines"]))
	var engine := _engine()
	engine.debug_skip_to(engine.book["missions"].size())
	assert_true(engine.is_finished())
	assert_true("completado" in NowAdvice.build(engine, "mision")["title"].to_lower())
	assert_true("Todavía no" in "\n".join(NowAdvice.build(null, "mision")["lines"]))


func test_f4_y_el_comando_ahora_abren_y_cierran_el_panel() -> void:
	var root := _main()
	_key(root, KEY_F4)
	assert_true(root.now_panel.is_open())
	assert_true(root.now_panel.lines_shown >= 3)
	assert_false(root.terminal.typing_enabled, "con la ventana abierta el teclado es suyo")
	_key(root, KEY_F4)
	assert_false(root.now_panel.is_open())
	root.terminal.submit("ahora")
	assert_true(root.now_panel.is_open())
	_key(root, KEY_F1)
	assert_false(root.now_panel.is_open(), "abrir otra ventana cierra esta")
	assert_true(root.cheatsheet_panel.is_open())
	_dispose(root)


# --- Tutorial ---

func test_el_tutorial_avanza_retrocede_y_termina() -> void:
	var panel := TutorialPanel.new()
	_tree().root.add_child(panel)
	var finished := [0]
	panel.finished.connect(func() -> void: finished[0] += 1)
	panel.open()
	assert_eq(panel.page_index, 0)
	panel.previous()
	assert_eq(panel.page_index, 0, "no retrocede más allá de la primera")
	for i in TutorialPanel.PAGES.size() - 1:
		panel.next()
	assert_eq(panel.page_index, TutorialPanel.PAGES.size() - 1)
	panel.next()
	assert_eq(finished[0], 1)
	assert_false(panel.is_open())
	panel.open()
	assert_eq(panel.page_index, 0, "al reabrirlo empieza desde el principio")
	panel.finish()
	assert_eq(finished[0], 2, "saltarlo también cuenta")
	_tree().root.remove_child(panel)
	panel.free()


func test_el_tutorial_menciona_los_atajos_que_existen() -> void:
	var all_text := ""
	for page: Array in TutorialPanel.PAGES:
		all_text += page[1]
	for shortcut in ["F1", "F3", "F4", "F9", "F10", "Esc", "pista", "tutorial"]:
		assert_true(shortcut in all_text, "el tutorial debe explicar %s" % shortcut)


func test_el_comando_tutorial_lo_abre_y_esc_lo_cierra_marcandolo_visto() -> void:
	var root := _main()
	root.settings.tutorial_done = false
	root.terminal.submit("tutorial")
	assert_true(root.tutorial_panel.is_open())
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root._input(esc)
	assert_false(root.tutorial_panel.is_open())
	assert_true(root.settings.tutorial_done, "saltarlo con Esc lo da por visto")
	_dispose(root)
