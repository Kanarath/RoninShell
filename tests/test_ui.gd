extends "res://tests/framework/test_case.gd"
## Pruebas de la interfaz: legibilidad de la paleta y que la pantalla principal se construye.

const Palette := preload("res://ui/theme/palette.gd")


# --- Accesibilidad: el texto debe leerse bien (WCAG AAA = contraste >= 7) ----

func test_contraste_del_texto_de_la_terminal() -> void:
	assert_true(Palette.contrast(Palette.TEXT, Palette.PANEL_DEEP) >= 7.0, "texto principal sobre la terminal")
	assert_true(Palette.contrast(Palette.TEXT, Palette.PANEL) >= 7.0, "texto principal sobre paneles")


func test_contraste_del_texto_secundario_y_titulos() -> void:
	assert_true(Palette.contrast(Palette.TEXT_DIM, Palette.PANEL) >= 4.5, "texto secundario (AA)")
	assert_true(Palette.contrast(Palette.TEXT_TITLE, Palette.PANEL) >= 7.0, "títulos")
	assert_true(Palette.contrast(Palette.INK, Palette.PARCHMENT) >= 7.0, "texto sobre pergamino")


func test_la_funcion_de_contraste_es_correcta() -> void:
	assert_eq(snappedf(Palette.contrast(Color.BLACK, Color.WHITE), 0.1), 21.0)
	assert_eq(snappedf(Palette.contrast(Color.WHITE, Color.WHITE), 0.1), 1.0)


# --- La pantalla principal se construye con sus paneles ---------------------

func test_pantalla_principal_se_construye() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var scene := load("res://scenes/main.tscn") as PackedScene
	var root := scene.instantiate()
	tree.root.add_child(root)  # dispara _ready y construye la interfaz

	for panel_name in ["Terminal", "Objectives", "Map", "Dossier", "NetworkMap", "Overlay"]:
		assert_true(root.find_child(panel_name, true, false) != null, "falta el panel %s" % panel_name)
	assert_true(root.world != null, "debe cargar el laboratorio")

	assert_true(root.session != null, "debe crear la sesión de shell")
	assert_true(root.terminal.output_text().contains("Primer contacto"), "la terminal muestra el laboratorio cargado")
	assert_eq(root.terminal.prompt_label.text, "ronin@ronin-box:~$ ")

	tree.root.remove_child(root)
	root.free()


func test_el_vfx_se_puede_apagar_con_intensidad_cero() -> void:
	var shader := load("res://ui/shaders/crt_overlay.gdshader") as Shader
	assert_true(shader != null)
	assert_true("uniform float intensity" in shader.code, "el VFX debe tener control de intensidad para accesibilidad")
