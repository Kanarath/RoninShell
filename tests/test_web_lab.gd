extends "res://tests/framework/test_case.gd"
## Laboratorio de la tienda web: curl con métodos, cabeceras, formularios y cookies,
## contra un sitio definido solo con datos (variantes con condiciones).

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")
const HttpSim := preload("res://engine/web/http_sim.gd")

const LAB := "res://data/labs/tienda_web.json"
const TOKEN := "tok-demo-3f9a1c"


func _s() -> RefCounted:
	var world = LabLoader.load_file(LAB)["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func _out(s: RefCounted, line: String) -> String:
	return s.run(line).stdout


# --- Utilidades HTTP ---

func test_codificacion_de_url_y_formularios() -> void:
	assert_eq(HttpSim.url_encode("a b&c"), "a%20b%26c")
	assert_eq(HttpSim.url_decode("a%20b+c"), "a b c")
	assert_eq(HttpSim.parse_form("usuario=demo&clave=a%20b&vacio"), {"usuario": "demo", "clave": "a b", "vacio": ""})
	assert_eq(HttpSim.parse_cookie_header("a=1; b=2"), {"a": "1", "b": "2"})


func test_set_cookie_con_sus_banderas() -> void:
	var cookie := HttpSim.parse_set_cookie("session=abc; Path=/app; HttpOnly; Secure; SameSite=Lax")
	assert_eq([cookie["name"], cookie["value"], cookie["path"]], ["session", "abc", "/app"])
	assert_true(cookie["http_only"] and cookie["secure"])
	assert_eq(cookie["same_site"], "Lax")
	var plain := HttpSim.parse_set_cookie("session=abc; Path=/")
	assert_false(plain["http_only"] or plain["secure"])


func test_archivo_de_cookies_ida_y_vuelta() -> void:
	var jar := HttpSim.jar_text("10.0.2.10", [HttpSim.parse_set_cookie("session=abc; Path=/; HttpOnly"), HttpSim.parse_set_cookie("rol=usuario; Path=/")])
	assert_true(jar.begins_with("# Netscape HTTP Cookie File"))
	assert_eq(HttpSim.read_jar(jar, "10.0.2.10"), {"session": "abc", "rol": "usuario"})
	assert_eq(HttpSim.read_jar(jar, "otro"), {}, "solo las cookies de ese host")


func test_el_laboratorio_web_es_valido() -> void:
	assert_eq(LabLoader.load_file(LAB)["errors"], [])


# --- Cabeceras ---

func test_las_cabeceras_muestran_lo_que_el_servidor_cuenta_y_lo_que_falta() -> void:
	var out := _out(_s(), "curl -I shop01")
	assert_true(out.begins_with("HTTP/1.1 200 OK"))
	assert_true("Server: nginx/1.18.0" in out and "X-Powered-By: PHP/7.2.34" in out, "filtra versiones")
	for missing in ["Content-Security-Policy", "X-Frame-Options", "Strict-Transport-Security"]:
		assert_false(missing in out, "%s no está en las cabeceras del laboratorio" % missing)


# --- Formularios y sesión ---

func test_login_correcto_da_redireccion_y_cookies_sin_banderas() -> void:
	var out := _out(_s(), "curl -i -d 'usuario=demo&clave=demo123' shop01/login")
	assert_true(out.begins_with("HTTP/1.1 302 Found"))
	assert_true("Location: /perfil" in out)
	assert_true("Set-Cookie: session=%s; Path=/" % TOKEN in out)
	assert_false("HttpOnly" in out or "Secure" in out, "la cookie de sesión no lleva banderas de seguridad")


func test_login_incorrecto_y_formulario() -> void:
	var s := _s()
	assert_true(_out(s, "curl -i -d 'usuario=demo&clave=mala' shop01/login").begins_with("HTTP/1.1 401"))
	assert_true("<form" in _out(s, "curl shop01/login"), "un GET devuelve el formulario")
	assert_true(_out(s, "curl -X POST shop01/login").contains("incorrectos"), "POST sin datos también falla")


func test_el_metodo_se_deduce_de_los_datos_y_se_puede_forzar() -> void:
	var s := _s()
	var verbose: String = s.run("curl -v -d 'a=1' shop01/login").stderr
	assert_true("> POST /login HTTP/1.1" in verbose and "> Content-Length: 3" in verbose)
	assert_true("> Content-Type: application/x-www-form-urlencoded" in verbose)
	assert_true("> GET /login HTTP/1.1" in s.run("curl -v shop01/login").stderr)
	assert_true("> PUT /login HTTP/1.1" in s.run("curl -v -X PUT shop01/login").stderr)


func test_datos_en_la_url_con_g_y_data_urlencode() -> void:
	var s := _s()
	assert_true("> GET /pedido?id=15 HTTP/1.1" in s.run("curl -v -G -d id=15 shop01/pedido").stderr)
	assert_true("> GET /pedido?q=a%20b HTTP/1.1" in s.run("curl -v -G --data-urlencode 'q=a b' shop01/pedido").stderr)
	var long_form: String = s.run("curl -v --data 'x=1' --request POST shop01/login").stderr
	assert_true("> POST /login HTTP/1.1" in long_form, "las opciones largas también valen")


# --- Cookies ---

func test_la_sesion_se_acepta_con_la_cookie_correcta_y_no_sin_ella() -> void:
	var s := _s()
	assert_true(_out(s, "curl -i shop01/perfil").begins_with("HTTP/1.1 302 Found"), "sin sesión: a /login")
	assert_true("Perfil de demo" in _out(s, "curl -b 'session=%s' shop01/perfil" % TOKEN))
	assert_true(_out(s, "curl -i -b 'session=otra' shop01/perfil").begins_with("HTTP/1.1 302"), "una cookie inventada no vale")
	assert_true("Perfil de demo" in _out(s, "curl -H 'Cookie: session=%s' shop01/perfil" % TOKEN), "también como cabecera")


func test_el_archivo_de_cookies_guarda_y_reutiliza_la_sesion() -> void:
	var s := _s()
	s.run("curl -s -c jar.txt -d 'usuario=demo&clave=demo123' shop01/login")
	var jar: String = s.host.fs.read_file("/home/ronin/jar.txt")
	assert_true("Netscape HTTP Cookie File" in jar and TOKEN in jar)
	assert_true("Perfil de demo" in _out(s, "curl -b jar.txt shop01/perfil"), "-b lee el archivo")
	assert_true("Perfil de demo" in _out(s, "curl -b jar.txt -c jar.txt shop01/perfil"))


func test_con_l_las_cookies_viajan_por_la_redireccion() -> void:
	var out := _out(_s(), "curl -L -c jar.txt -d 'usuario=demo&clave=demo123' shop01/login")
	assert_true("Perfil de demo" in out, "el login redirige a /perfil y la cookie recién recibida ya vale")


func test_errores_de_cookies_y_de_archivos() -> void:
	var s := _s()
	assert_true("(23)" in s.run("curl -c /etc/jar.txt shop01/").stderr, "no se puede escribir donde no hay permiso")
	assert_true("Perfil" not in _out(s, "curl -b noexiste.txt shop01/perfil"), "un archivo de cookies inexistente se ignora")
	assert_true("is unknown" in s.run("curl --nada shop01").stderr)
	assert_true("requires parameter" in s.run("curl -H").stderr)


# --- Control de acceso (el sitio lo decide con datos, no con código) ---

func test_pedidos_con_sesion() -> void:
	var s := _s()
	assert_true("Pedido 15 (demo)" in _out(s, "curl -b 'session=%s' 'shop01/pedido?id=15'" % TOKEN))
	assert_true("Pedido no encontrado" in _out(s, "curl -b 'session=%s' 'shop01/pedido?id=99'" % TOKEN))
	assert_true(_out(s, "curl -i 'shop01/pedido?id=15'").begins_with("HTTP/1.1 302"), "sin sesión no se ve nada")


func test_el_sitio_confia_en_un_dato_que_controla_el_cliente() -> void:
	var s := _s()
	assert_true(_out(s, "curl -i shop01/admin").begins_with("HTTP/1.1 403"))
	assert_true(_out(s, "curl -i -b 'rol=usuario' shop01/admin").begins_with("HTTP/1.1 403"))
	assert_true("Panel de administración" in _out(s, "curl -b 'rol=admin' shop01/admin"))


# --- Eventos para las misiones ---

func test_los_eventos_registran_metodo_consulta_cookies_y_cabeceras_vistas() -> void:
	var s := _s()
	s.run("curl -I shop01")
	s.run("curl -i -d 'usuario=demo&clave=demo123' shop01/login")
	s.run("curl -b 'session=%s' 'shop01/pedido?id=16'" % TOKEN)
	var kinds := {}
	for event: Dictionary in s.events:
		kinds[event["type"]] = event
	assert_true(kinds.has("headers_seen"))
	assert_eq([kinds["cookie_set"]["name"], kinds["cookie_set"]["http_only"], kinds["cookie_set"]["secure"]], ["rol", false, false])
	var responses: Array = s.events.filter(func(e: Dictionary) -> bool: return e["type"] == "http_response")
	assert_eq(responses[1]["method"], "POST")
	assert_eq(responses[2]["query"], "id=16")
	assert_true(responses[2]["with_cookie"])
	assert_false(responses[0]["with_cookie"])
