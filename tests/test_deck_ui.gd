extends "res://tests/framework/test_case.gd"
## Interfaz del cyberdeck: arranque, ampliar paneles con zoom, efectos y cursor. Todo sin tocar el motor.

const BootScreen := preload("res://ui/widgets/boot_screen.gd")
const ExpandView := preload("res://ui/widgets/expand_view.gd")
const CutFrame := preload("res://ui/widgets/cut_frame.gd")
const DeckFrame := preload("res://ui/widgets/deck_frame.gd")
const FxLayer := preload("res://ui/widgets/fx_layer.gd")
const SpriteStore := preload("res://ui/sprite_store.gd")


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _main() -> Control:
	var root := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_tree().root.add_child(root)
	return root


func _dispose(root: Control) -> void:
	_tree().root.remove_child(root)
	root.free()


func test_el_arte_del_cyberdeck_existe() -> void:
	for art_name in ["boot_base", "helmet", "shutter", "cursor_arrow", "cursor_link", "cursor_text"]:
		assert_true(SpriteStore.ui_texture(art_name) != null, "falta assets/ui/%s.png" % art_name)
	assert_eq(SpriteStore.ui_texture("boot_base").get_size(), Vector2(320, 180))


func test_el_arranque_sin_efectos_termina_y_avisa() -> void:
	var boot := BootScreen.new()
	boot.vfx = false
	_tree().root.add_child(boot)
	var finished := [false]
	boot.finished.connect(func() -> void: finished[0] = true)
	boot.play()
	assert_eq(boot.progress, 1.0, "sin efectos la barra ya está llena")
	boot.finish()
	assert_true(boot.is_done)
	assert_true(finished[0], "finish() avisa para que se abra el menú")
	boot.finish()   # una segunda llamada no avisa otra vez
	_tree().root.remove_child(boot)
	boot.free()


func test_el_arranque_se_puede_saltar_con_efectos() -> void:
	var boot := BootScreen.new()
	boot.vfx = true
	_tree().root.add_child(boot)
	boot.play()
	boot.progress = 0.4
	assert_eq(boot.progress, 0.4)
	boot.progress = 7.0
	assert_eq(boot.progress, 1.0, "el progreso se limita a 0..1")
	boot.finish()
	assert_true(boot.is_done, "saltar marca el arranque como terminado")
	_tree().root.remove_child(boot)
	boot.free()


func test_los_paneles_se_pueden_ampliar_y_su_contenido_vuelve_al_cerrar() -> void:
	var root := _main()
	CutFrame.animate = false   # _ready aplica los ajustes y los enciende: se apagan después
	var frame: Control = root._objectives_frame
	var content: Control = frame.content
	var children_before := content.get_child_count()
	assert_true(frame.expandable, "los paneles laterales son ampliables")
	root.expand_view.open_from(frame)
	assert_true(root.expand_view.is_open())
	assert_true(content.get_parent() == root.expand_view.frame.column, "el contenido real se mueve a la ventana grande")
	root._rebuild_objectives()
	assert_true(content.get_child_count() > 0, "sigue vivo mientras está ampliado")
	root.expand_view.close()
	assert_false(root.expand_view.is_open())
	assert_true(content.get_parent() == frame.column, "el contenido vuelve a su panel")
	assert_true(children_before > 0)
	CutFrame.animate = true
	_dispose(root)


func test_esc_cierra_la_vista_ampliada() -> void:
	var root := _main()
	CutFrame.animate = false   # _ready aplica los ajustes y los enciende: se apagan después
	root.expand_view.open_from(root._dossier_frame)
	assert_true(root._any_window_open(), "una ventana ampliada cuenta como ventana abierta")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root._input(event)
	assert_false(root.expand_view.is_open())
	CutFrame.animate = true
	_dispose(root)


func test_los_efectos_se_apagan_con_el_ajuste() -> void:
	var root := _main()
	root.settings.vfx_enabled = false
	root._apply_settings()
	assert_false(CutFrame.animate)
	assert_false(DeckFrame.animate)
	assert_false(root.fx_layer.enabled)
	root.settings.vfx_enabled = true
	root._apply_settings()
	assert_true(CutFrame.animate)
	assert_true(root.fx_layer.enabled)
	_dispose(root)


func test_los_efectos_no_fallan_y_se_limpian() -> void:
	var fx := FxLayer.new()
	_tree().root.add_child(fx)
	fx.ripple(Vector2(10, 10))
	fx.burst(Vector2(50, 50), Color.GOLD)
	fx._process(1.0)
	assert_true(fx._ripples.is_empty(), "las ondas desaparecen solas")
	fx.enabled = false
	fx.ripple(Vector2(1, 1))
	assert_true(fx._ripples.is_empty(), "sin efectos no se crea nada")
	_tree().root.remove_child(fx)
	fx.free()


func test_los_leds_de_la_carcasa_reaccionan() -> void:
	var deck := DeckFrame.new()
	deck.blink_led(2)
	assert_eq(deck._leds[2], 1.0)
	deck.blink_led(9)   # fuera de rango: se ignora
	deck.free()


func test_las_ventanas_modales_siguen_abriendo_y_cerrando_con_zoom() -> void:
	var root := _main()
	root.settings_panel.open()
	assert_true(root.settings_panel.is_open())
	root.settings_panel.close()
	assert_false(root.settings_panel.is_open())
	assert_eq(root.settings_panel.frame.scale, Vector2.ONE, "cerrar deja el marco a su tamaño")
	assert_eq(root.settings_panel.modulate.a, 1.0)
	_dispose(root)


func test_la_vista_ampliada_muestra_detalle_propio_y_lo_limpia() -> void:
	var root := _main()
	CutFrame.animate = false
	for frame: Control in [root._objectives_frame, root._map_frame, root._dossier_frame]:
		root._open_expanded(frame)
		assert_true(root.expand_view.is_open())
		assert_true(root.expand_view._extra != null, "cada panel ampliado trae su detalle")
		root.expand_view.close()
		assert_true(root.expand_view._extra == null, "el detalle se descarta al cerrar")
	assert_true(root._objectives_frame.content.get_parent() == root._objectives_frame.column)
	assert_true(root._map_frame.content.get_parent() == root._map_frame.column)
	assert_true(root._dossier_frame.content.get_parent() == root._dossier_frame.column, "el expediente no se mueve: solo se sustituye")
	CutFrame.animate = true
	_dispose(root)


func test_el_detalle_de_objetivos_incluye_el_contexto_y_las_pistas_abiertas() -> void:
	var root := _main()
	var texts: Array = []
	for label in root._objectives_detail().get_children():
		texts.append(label.text)
	var joined := "\n".join(texts)
	assert_true("CONTEXTO" in joined and "AHORA" in joined)
	assert_true("Pistas abiertas: 0" in joined)
	_dispose(root)
