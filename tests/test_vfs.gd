extends "res://tests/framework/test_case.gd"

const Vfs := preload("res://engine/vfs.gd")


func _sample() -> RefCounted:
	var fs := Vfs.new()
	fs.add_dir("/home")
	fs.add_dir("/home/ronin", "ronin", "ronin", "750")
	fs.add_file("/home/ronin/nota.txt", "hola\n", "ronin", "ronin", "644")
	fs.add_file("/home/ronin/a.txt", "a")
	return fs


func test_normalize_rutas_relativas_y_absolutas() -> void:
	assert_eq(Vfs.normalize("/home/ronin", "nota.txt"), "/home/ronin/nota.txt")
	assert_eq(Vfs.normalize("/home/ronin", "/etc"), "/etc")
	assert_eq(Vfs.normalize("/home/ronin", ".."), "/home")
	assert_eq(Vfs.normalize("/home/ronin", "../../.."), "/", "no se sale de la raíz")
	assert_eq(Vfs.normalize("/home", "./ronin//docs/"), "/home/ronin/docs")
	assert_eq(Vfs.normalize("/home/ronin", ""), "/home/ronin")


func test_la_raiz_existe_desde_el_principio() -> void:
	var fs := Vfs.new()
	assert_true(fs.is_dir("/"))
	assert_eq(fs.list_dir("/").size(), 0)


func test_no_se_crea_sin_directorio_padre() -> void:
	var fs := Vfs.new()
	assert_false(fs.add_file("/no/existe/x.txt", "x"))
	assert_false(fs.exists("/no/existe/x.txt"))


func test_no_se_permiten_rutas_relativas_ni_sucias_ni_repetidas() -> void:
	var fs := Vfs.new()
	assert_false(fs.add_dir("relativa"))
	assert_false(fs.add_dir("/a/../b"))
	assert_true(fs.add_dir("/a"))
	assert_false(fs.add_dir("/a"), "no se puede crear dos veces")


func test_lectura_de_archivos() -> void:
	var fs := _sample()
	assert_eq(fs.read_file("/home/ronin/nota.txt"), "hola\n")
	assert_eq(fs.read_file("/home/ronin"), "", "un directorio no se lee como archivo")
	assert_eq(fs.read_file("/nada"), "")
	assert_true(fs.is_file("/home/ronin/nota.txt"))
	assert_false(fs.is_file("/home/ronin"))


func test_listado_ordenado_y_solo_hijos_directos() -> void:
	var fs := _sample()
	assert_eq(fs.list_dir("/home/ronin"), ["a.txt", "nota.txt"])
	assert_eq(fs.list_dir("/home"), ["ronin"])
	assert_eq(fs.list_dir("/"), ["home"])
	assert_eq(fs.list_dir("/home/ronin/a.txt"), [], "un archivo no se lista")


func test_metadatos_y_copia_defensiva() -> void:
	var fs := _sample()
	var info: Dictionary = fs.get_node_info("/home/ronin")
	assert_eq(info["owner"], "ronin")
	assert_eq(info["mode"], "750")
	info["owner"] = "otro"
	assert_eq(fs.get_node_info("/home/ronin")["owner"], "ronin", "modificar la copia no altera el sistema de archivos")
	assert_eq(fs.get_node_info("/nada"), {})
