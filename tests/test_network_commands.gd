extends "res://tests/framework/test_case.gd"
## ping, nmap y curl contra "Primer contacto". Los tests "dorados" fijan la salida exacta
## de los casos clave: si cambia, hay que revisarlo a propósito.

const LabLoader := preload("res://engine/lab_loader.gd")
const ShellSession := preload("res://engine/shell/shell_session.gd")
const CommandSet := preload("res://engine/commands/command_set.gd")

const START := "Starting Nmap 7.94 ( https://nmap.org ) at 2026-10-29 12:00 UTC\n"


func _s() -> RefCounted:
	var world = LabLoader.load_file("res://data/labs/primer_contacto.json")["world"]
	return ShellSession.new(world, CommandSet.create_registry())


func _out(s: RefCounted, line: String) -> String:
	return s.run(line).stdout


# --- ping ---

func test_ping_a_un_host_que_responde() -> void:
	var out := _out(_s(), "ping -c 2 web01")
	assert_true(out.begins_with("PING web01 (10.0.0.5) 56(84) bytes of data.\n"))
	assert_true("64 bytes from web01 (10.0.0.5): icmp_seq=1 ttl=64 time=" in out)
	assert_true("2 packets transmitted, 2 received, 0% packet loss" in out)
	assert_true("rtt min/avg/max/mdev" in out)


func test_ping_es_determinista() -> void:
	assert_eq(_out(_s(), "ping -c 3 10.0.0.5"), _out(_s(), "ping -c 3 10.0.0.5"))


func test_ping_por_defecto_envia_4_paquetes_y_acepta_localhost() -> void:
	assert_true("4 packets transmitted, 4 received" in _out(_s(), "ping web01"))
	assert_true("PING localhost (127.0.0.1)" in _out(_s(), "ping -c 1 localhost"))


func test_ping_distingue_silencio_de_inalcanzable() -> void:
	var s := _s()
	var blocked = s.run("ping -c 2 10.0.0.9")  # encendida pero descarta los sondeos
	assert_eq(blocked.exit_code, 1)
	assert_false("Unreachable" in blocked.stdout, "un firewall que descarta no genera errores, solo silencio")
	assert_true("100% packet loss" in blocked.stdout)
	var dead = s.run("ping -c 2 10.0.0.77")  # no existe
	assert_true("From 10.0.0.2 icmp_seq=1 Destination Host Unreachable" in dead.stdout)
	assert_true("+2 errors" in dead.stdout)


func test_ping_errores_de_uso() -> void:
	var s := _s()
	assert_eq(s.run("ping nope").stderr, "ping: nope: Name or service not known\n")
	assert_eq(s.run("ping").stderr, "ping: usage error: Destination address required\n")
	assert_true("out of range" in s.run("ping -c 0 web01").stderr)


# --- nmap (salidas exactas) ---

func test_nmap_escaneo_por_defecto() -> void:
	assert_eq(_out(_s(), "nmap web01"), START + """Nmap scan report for web01 (10.0.0.5)
Host is up (0.00057s latency).
Not shown: 997 closed tcp ports (reset)
PORT     STATE    SERVICE
22/tcp   open     ssh
80/tcp   open     http
8080/tcp filtered http-proxy

Nmap done: 1 IP address (1 host up) scanned in 0.42 seconds
""")


func test_nmap_sv_muestra_versiones() -> void:
	assert_eq(_out(_s(), "nmap -sV 10.0.0.5"), START + """Nmap scan report for web01 (10.0.0.5)
Host is up (0.00057s latency).
Not shown: 997 closed tcp ports (reset)
PORT     STATE    SERVICE    VERSION
22/tcp   open     ssh        OpenSSH 8.2p1
80/tcp   open     http       Apache httpd 2.4.49
8080/tcp filtered http-proxy

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 6.92 seconds
""")


func test_nmap_host_que_ignora_el_ping_parece_caido() -> void:
	assert_eq(_out(_s(), "nmap 10.0.0.9"), START + """Note: Host seems down. If it is really up, but blocking our ping probes, try -Pn
Nmap done: 1 IP address (0 hosts up) scanned in 3.05 seconds
""")


func test_nmap_pn_encuentra_lo_que_el_descubrimiento_no_vio() -> void:
	assert_eq(_out(_s(), "nmap -Pn -sV 10.0.0.9"), START + """Nmap scan report for files01 (10.0.0.9)
Host is up (0.00022s latency).
Not shown: 999 closed tcp ports (reset)
PORT   STATE SERVICE VERSION
21/tcp open  ftp     vsftpd 3.0.3

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 6.92 seconds
""")


func test_nmap_sn_descubre_hosts_sin_escanear_puertos() -> void:
	assert_eq(_out(_s(), "nmap -sn 10.0.0.0/24"), START + """Nmap scan report for ronin-box (10.0.0.2)
Host is up (0.00036s latency).
Nmap scan report for web01 (10.0.0.5)
Host is up (0.00057s latency).
Nmap done: 256 IP addresses (2 hosts up) scanned in 2.55 seconds
""")


# --- nmap (comportamiento) ---

func test_nmap_pocos_puertos_se_listan_todos_incluso_los_cerrados() -> void:
	var out := _out(_s(), "nmap -p 20-24 10.0.0.5")
	assert_false("Not shown" in out, "con 25 puertos o menos no se resume nada")
	assert_true("20/tcp closed ftp-data" in out and "22/tcp open   ssh" in out)


func test_nmap_todos_los_puertos_encuentra_lo_que_el_escaneo_normal_no() -> void:
	var out := _out(_s(), "nmap -p- 10.0.0.5")
	assert_true("Not shown: 65532 closed tcp ports (reset)" in out)


func test_nmap_puertos_especificos() -> void:
	assert_true("80/tcp   open  http" in _out(_s(), "nmap -p 80,443 web01") or "80/tcp" in _out(_s(), "nmap -p80 web01"))
	assert_true("Your port specifications are illegal" in _s().run("nmap -p abc web01").stderr)
	assert_true("between 0 and 65535" in _s().run("nmap -p 70000 web01").stderr)


func test_nmap_host_propio_sin_servicios() -> void:
	var out := _out(_s(), "nmap 10.0.0.2")
	assert_true("All 1000 scanned ports on ronin-box (10.0.0.2) are in ignored states." in out)


func test_nmap_pn_sobre_un_host_inexistente_lo_da_por_vivo_con_todo_filtrado() -> void:
	var out := _out(_s(), "nmap -Pn 10.0.0.77")
	assert_true("Host is up." in out)
	assert_true("Not shown: 1000 filtered tcp ports (no-response)" in out)


func test_nmap_errores_de_uso() -> void:
	var s := _s()
	assert_true("Usage: nmap" in _out(s, "nmap"))
	assert_true("Failed to resolve \"nope\"." in _out(s, "nmap nope"))
	assert_true("does not simulate the option '-O'" in s.run("nmap -O web01").stderr)
	assert_true("invalid option -- 'x'" in s.run("nmap -x web01").stderr)
	assert_true("not simulated" in s.run("nmap -Pn 10.0.0.0/24").stderr)


func test_nmap_acepta_opciones_inofensivas() -> void:
	assert_eq(_out(_s(), "nmap -sS -T4 -n -v web01"), _out(_s(), "nmap web01"))


# --- curl ---

func test_curl_devuelve_el_cuerpo_de_la_pagina() -> void:
	var out := _out(_s(), "curl 10.0.0.5")
	assert_true("<title>Intranet de ejemplo</title>" in out)
	assert_true("quitar /backup/" in out, "el comentario HTML con la pista está en la página")
	assert_eq(_out(_s(), "curl http://web01/robots.txt"), "User-agent: *\nDisallow: /backup/\nDisallow: /admin/\n")


func test_curl_cabeceras() -> void:
	var out := _out(_s(), "curl -I web01/robots.txt")
	assert_true(out.begins_with("HTTP/1.1 200 OK\n"))
	assert_true("Server: Apache/2.4.49 (Unix)" in out)
	assert_true("Content-Length: 51" in out)
	assert_false("User-agent" in out, "-I no muestra el cuerpo")
	var with_body := _out(_s(), "curl -i web01/robots.txt")
	assert_true("Content-Type: text/plain" in with_body and "Disallow: /admin/" in with_body)


func test_curl_codigos_de_estado() -> void:
	var s := _s()
	assert_true(_out(s, "curl -i web01/admin").begins_with("HTTP/1.1 403 Forbidden"))
	assert_true(_out(s, "curl -i web01/no-existe").begins_with("HTTP/1.1 404 Not Found"))
	assert_true("404 Not Found" in _out(s, "curl web01/no-existe"))
	assert_true("config.old" in _out(s, "curl web01/backup/"))
	assert_eq(_out(s, "curl web01/backup/config.old"), "db_user=app\ndb_pass=EjemploNoReal123\n")
	assert_true(_out(s, "curl 'web01/robots.txt?x=1'").begins_with("User-agent"), "la query no cambia la ruta")


func test_curl_redirecciones() -> void:
	var s := _s()
	var no_follow := _out(s, "curl -i web01/old")
	assert_true(no_follow.begins_with("HTTP/1.1 301 Moved Permanently") and "Location: /" in no_follow)
	assert_false("Intranet" in no_follow, "sin -L no se sigue la redirección")
	assert_true("Intranet de ejemplo" in _out(s, "curl -L web01/old"))


func test_curl_errores_de_conexion_distintos_segun_el_puerto() -> void:
	var s := _s()
	assert_eq(s.run("curl web01:81").exit_code, 7)
	assert_true("Connection refused" in s.run("curl web01:81").stderr, "cerrado = rechazado")
	assert_eq(s.run("curl web01:8080").exit_code, 28)
	assert_true("Connection timed out" in s.run("curl web01:8080").stderr, "filtrado = sin respuesta")
	assert_eq(s.run("curl web01:22").exit_code, 52, "abierto pero no habla HTTP")
	assert_eq(s.run("curl http://nope/").exit_code, 6)
	assert_eq(s.run("curl ftp://files01").exit_code, 1)
	assert_eq(s.run("curl https://web01").exit_code, 7, "no hay servicio en el 443")


func test_curl_a_host_inexistente_agota_el_tiempo() -> void:
	assert_eq(_s().run("curl 10.0.0.77").exit_code, 28)


func test_curl_guarda_en_un_archivo_con_o() -> void:
	var s := _s()
	var result = s.run("curl -o robots.txt web01/robots.txt")
	assert_eq(result.stdout, "")
	assert_eq(s.host.fs.read_file("/home/ronin/robots.txt"), "User-agent: *\nDisallow: /backup/\nDisallow: /admin/\n")
	assert_true("(23)" in s.run("curl -o /etc/x web01/").stderr, "no se puede escribir donde no hay permiso")


func test_curl_verbose_va_a_stderr() -> void:
	var result = _s().run("curl -v web01/admin")
	assert_true("403 Forbidden" in result.stdout)
	assert_true("> GET /admin HTTP/1.1" in result.stderr and "< HTTP/1.1 403 Forbidden" in result.stderr)


func test_curl_silencioso_y_opciones_no_soportadas() -> void:
	var s := _s()
	assert_eq(s.run("curl -s web01:81").stderr, "", "-s oculta el mensaje de error")
	assert_eq(s.run("curl -s web01:81").exit_code, 7, "pero el código de salida sigue ahí")
	assert_true("not supported by this lab" in s.run("curl -H x web01").stderr)
	assert_true("no URL specified" in s.run("curl").stderr)


# --- Coherencia entre comandos: la prueba de que el mundo es uno solo ---

func test_lo_que_nmap_ve_abierto_curl_lo_confirma() -> void:
	var s := _s()
	var web = s.world.get_host("10.0.0.5")
	for service in web.services:
		var curl_exit: int = s.run("curl http://10.0.0.5:%d/" % service.port).exit_code
		match service.state:
			"open":
				if web.sites.has(service.port):
					assert_eq(curl_exit, 0, "puerto %d abierto con web" % service.port)
				else:
					assert_eq(curl_exit, 52, "puerto %d abierto sin web" % service.port)
			"filtered":
				assert_eq(curl_exit, 28, "puerto %d filtrado" % service.port)
			"closed":
				assert_eq(curl_exit, 7, "puerto %d cerrado" % service.port)


func test_todos_los_hosts_de_etc_hosts_existen_en_la_red() -> void:
	var s := _s()
	for line in s.host.fs.read_file("/etc/hosts").split("\n", false):
		var parts: PackedStringArray = line.split(" ", false)
		if parts[0] == "127.0.0.1":
			continue
		assert_true(s.world.get_host(parts[0]) != null, "%s está en /etc/hosts" % parts[0])
		assert_eq(s.world.get_host(parts[0]).hostname, parts[1], "el nombre coincide con el del laboratorio")


func test_el_host_que_ignora_el_ping_coincide_en_ping_y_nmap() -> void:
	var s := _s()
	assert_eq(s.run("ping -c 1 files01").exit_code, 1)
	assert_true("seems down" in _out(s, "nmap files01"))
	assert_true("21/tcp open" in _out(s, "nmap -Pn files01"), "pero el puerto 21 existe")
