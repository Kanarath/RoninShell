extends "res://tests/framework/test_case.gd"

const LabLoader := preload("res://engine/lab_loader.gd")
const LAB_PATH := "res://data/labs/primer_contacto.json"


func _minimal() -> Dictionary:
	return {
		"id": "mini",
		"player_host": "10.0.0.2",
		"hosts": [{"ip": "10.0.0.2", "hostname": "a"}],
	}


func _errors_of(data: Variant) -> Array:
	return LabLoader.load_dict(data)["errors"]


func _has_error_containing(errors: Array, fragment: String) -> bool:
	for error: String in errors:
		if fragment in error:
			return true
	return false


# --- El laboratorio real del MVP ---

func test_el_laboratorio_primer_contacto_carga_sin_errores() -> void:
	var result := LabLoader.load_file(LAB_PATH)
	assert_eq(result["errors"], [])
	assert_true(result["world"] != null)


func test_primer_contacto_tiene_los_hosts_esperados_ordenados() -> void:
	var world = LabLoader.load_file(LAB_PATH)["world"]
	assert_eq(world.host_ips(), ["10.0.0.2", "10.0.0.5", "10.0.0.9"])
	assert_eq(world.player_host().hostname, "ronin-box")
	assert_eq(world.host_by_name("web01").ip, "10.0.0.5")
	assert_true(world.host_by_name("no-existe") == null)


func test_primer_contacto_servicios_y_estados() -> void:
	var world = LabLoader.load_file(LAB_PATH)["world"]
	var web = world.get_host("10.0.0.5")
	assert_eq(web.get_service(80).product, "Apache httpd")
	assert_eq(web.get_service(80).version, "2.4.49")
	assert_eq(web.get_service(8080).state, "filtered")
	assert_true(web.get_service(443) == null, "un puerto no definido no existe como servicio")
	assert_false(world.get_host("10.0.0.9").responds_to_ping, "files01 está vivo pero ignora el ping")
	assert_true(world.get_host("10.0.0.9").up)


func test_primer_contacto_sistema_de_archivos_del_jugador() -> void:
	var world = LabLoader.load_file(LAB_PATH)["world"]
	var fs = world.player_host().fs
	assert_true(fs.is_file("/home/ronin/nota.txt"))
	assert_true("10.0.0.0/24" in fs.read_file("/home/ronin/nota.txt"))
	assert_eq(fs.list_dir("/home/ronin"), [".hidden", "herramientas", "informe", "nota.txt"])
	assert_eq(fs.get_node_info("/home/ronin/.hidden")["mode"], "600")
	assert_true(world.player_host().has_user("ronin"))


# --- Validación: preferimos fallar con un mensaje claro ---

func test_laboratorio_minimo_valido() -> void:
	assert_eq(_errors_of(_minimal()), [])


func test_error_si_no_es_un_objeto() -> void:
	assert_true(LabLoader.load_dict([1, 2])["world"] == null)
	assert_true(_errors_of("texto").size() > 0)


func test_error_si_falta_id_hosts_o_jugador() -> void:
	var errors := _errors_of({})
	assert_true(_has_error_containing(errors, "id"))
	assert_true(_has_error_containing(errors, "hosts"))
	assert_true(_has_error_containing(errors, "player_host"))


func test_error_ip_invalida_o_repetida() -> void:
	var data := _minimal()
	data["hosts"].append({"ip": "10.0.0.300"})
	data["hosts"].append({"ip": "10.0.0.2"})
	var errors := _errors_of(data)
	assert_true(_has_error_containing(errors, "IP inválida"))
	assert_true(_has_error_containing(errors, "IP repetida"))


func test_error_jugador_en_host_inexistente() -> void:
	var data := _minimal()
	data["player_host"] = "10.0.0.99"
	assert_true(_has_error_containing(_errors_of(data), "player_host"))


func test_error_servicio_con_datos_invalidos() -> void:
	var data := _minimal()
	data["hosts"][0]["services"] = [
		{"port": 70000, "state": "open"},
		{"port": 80, "state": "medioabierto"},
		{"port": 22, "proto": "icmp"},
		{"port": 443},
		{"port": 443},
	]
	var errors := _errors_of(data)
	assert_true(_has_error_containing(errors, "fuera de rango"))
	assert_true(_has_error_containing(errors, "estado desconocido"))
	assert_true(_has_error_containing(errors, "protocolo desconocido"))
	assert_true(_has_error_containing(errors, "duplicado"))


func test_error_sistema_de_archivos_incoherente() -> void:
	var data := _minimal()
	data["hosts"][0]["fs"] = {
		"/huerfano/x.txt": {"type": "file"},
		"/ok": {"type": "dir", "mode": "999"},
		"relativa": {"type": "dir"},
		"/raro": {"type": "enlace"},
	}
	var errors := _errors_of(data)
	assert_true(_has_error_containing(errors, "/huerfano/x.txt"))
	assert_true(_has_error_containing(errors, "permisos inválidos"))
	assert_true(_has_error_containing(errors, "relativa"))
	assert_true(_has_error_containing(errors, "tipo desconocido"))


func test_los_padres_se_crean_antes_que_los_hijos_aunque_vengan_desordenados() -> void:
	var data := _minimal()
	data["hosts"][0]["fs"] = {
		"/a/b/c.txt": {"type": "file", "content": "ok"},
		"/a/b": {"type": "dir"},
		"/a": {"type": "dir"},
	}
	var result := LabLoader.load_dict(data)
	assert_eq(result["errors"], [])
	assert_eq(result["world"].player_host().fs.read_file("/a/b/c.txt"), "ok")


func test_archivo_inexistente_y_json_roto() -> void:
	assert_true(_has_error_containing(LabLoader.load_file("res://data/labs/no_existe.json")["errors"], "no existe"))
