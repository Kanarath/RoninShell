extends "res://tests/framework/test_case.gd"
## Pruebas de humo: el proyecto está bien configurado y la escena principal carga.


func test_nombre_del_proyecto() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/name"), "RoninShell")


func test_filtro_nearest_para_pixel_art() -> void:
	# 0 = Nearest. Sin esto, el pixel art se vería borroso.
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_escena_principal_carga() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	var scene := load(path) as PackedScene
	assert_true(scene != null, "la escena principal debe existir: %s" % path)
	if scene == null:
		return
	var root := scene.instantiate()
	assert_true(root.has_node("Title"), "la escena debe tener un nodo Title")
	root.free()
