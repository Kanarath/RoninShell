extends RefCounted
## curl simulado: cliente HTTP contra los sitios del laboratorio. Todo se calcula a partir de
## los datos del sitio (ver engine/web/http_sim.gd): no hay red real.
##
## Soporta: -i -I -v -s -S -k -L, -o archivo, -X método, -d / --data-urlencode / -G (datos de
## formulario), -H cabecera, -b cookies (cadena o archivo), -c archivo de cookies y -A agente.
## HTTP y HTTPS sin TLS real. No soporta subida de archivos, autenticación ni proxies.

const CommandResult := preload("res://engine/shell/command_result.gd")
const Network := preload("res://engine/network.gd")
const Host := preload("res://engine/host.gd")
const Vfs := preload("res://engine/vfs.gd")
const ArgParser := preload("res://engine/commands/arg_parser.gd")
const HttpSim := preload("res://engine/web/http_sim.gd")

const HTTP_DATE := "Thu, 29 Oct 2026 12:00:00 GMT"
const MAX_REDIRECTS := 10
const STATUS_TEXT := {
	200: "OK", 301: "Moved Permanently", 302: "Found", 303: "See Other", 307: "Temporary Redirect",
	308: "Permanent Redirect", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden",
	404: "Not Found", 405: "Method Not Allowed", 500: "Internal Server Error",
}
const NOT_FOUND_BODY := "<!DOCTYPE HTML PUBLIC \"-//IETF//DTD HTML 2.0//EN\">\n<html><head>\n<title>404 Not Found</title>\n</head><body>\n<h1>Not Found</h1>\n<p>The requested URL was not found on this server.</p>\n</body></html>\n"
const LONG_OPTIONS := {
	"--header": "-H", "--data": "-d", "--data-raw": "-d", "--data-urlencode": "-E", "--request": "-X",
	"--cookie": "-b", "--cookie-jar": "-c", "--user-agent": "-A", "--output": "-o", "--get": "-G",
	"--include": "-i", "--head": "-I", "--location": "-L", "--silent": "-s", "--show-error": "-S",
	"--verbose": "-v", "--insecure": "-k",
}
const REPEATABLE := ["-H", "-d", "-E"]


func run(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var prepared := _prepare(args)
	if prepared["error"] != "":
		return CommandResult.error(prepared["error"], 2)
	var parsed := ArgParser.parse(prepared["rest"], "iIsSvLkG", "XbcAo")
	if parsed["error"] != "":
		var letter: String = parsed["error"].get_slice("'", 1)
		return CommandResult.error("curl: option -%s: is not supported by this lab\ncurl: try 'curl --help' for more information" % letter, 2)
	if parsed["rest"].is_empty():
		return CommandResult.error("curl: no URL specified\ncurl: try 'curl --help' for more information", 2)

	var flags: Dictionary = parsed["flags"]
	var values: Dictionary = parsed["values"]
	var url: String = parsed["rest"][0]

	# --- Construcción de la petición ---
	var pieces: Array = prepared["data"]
	var body := "&".join(pieces)
	var method := str(values.get("X", "")).to_upper()
	if method == "":
		method = "HEAD" if flags.has("I") else ("POST" if not pieces.is_empty() and not flags.has("G") else "GET")
	if flags.has("G") and not pieces.is_empty():
		url += ("&" if "?" in url else "?") + body
		body = ""

	var headers: Dictionary = prepared["headers"]
	var cookies := {}
	if values.has("b"):
		cookies = _initial_cookies(session, str(values["b"]), url)
	if headers.has("cookie"):
		cookies.merge(HttpSim.parse_cookie_header(headers["cookie"]), true)
		headers.erase("cookie")
	var use_cookie_engine := values.has("b") or values.has("c")
	if values.has("A"):
		headers["user-agent"] = str(values["A"])
	if body != "" and not headers.has("content-type"):
		headers["content-type"] = "application/x-www-form-urlencoded"

	var result := CommandResult.new()
	var collected: Array = []      # cookies recibidas (para -c)
	var last_response: Dictionary = {}
	var hops := 0

	while true:
		var request := {"method": method, "body": body, "headers": headers, "cookies": cookies}
		var fetched := _fetch(session, url, request, flags.has("v"))
		result.stderr += fetched["verbose"]
		if fetched["error"] != "":
			if fetched["code"] == 7:
				session.record("connection_refused", {"ip": fetched.get("ip", ""), "port": fetched.get("port", 0)})
			elif fetched["code"] == 28:
				session.record("connection_timeout", {"ip": fetched.get("ip", ""), "port": fetched.get("port", 0)})
			if not flags.has("s") or flags.has("S"):
				result.stderr += fetched["error"] + "\n"
			result.exit_code = fetched["code"]
			return result

		last_response = fetched
		session.record("http_response", {
			"ip": fetched["ip"], "port": fetched["port"], "path": fetched["path"], "status": fetched["status"],
			"method": method, "with_cookie": not cookies.is_empty(), "query": fetched["query"],
		})
		for raw: String in fetched["set_cookies"]:
			var cookie := HttpSim.parse_set_cookie(raw)
			session.record("cookie_set", {"ip": fetched["ip"], "name": cookie["name"], "http_only": cookie["http_only"], "secure": cookie["secure"]})
			if use_cookie_engine:
				cookies[cookie["name"]] = cookie["value"]
				collected.append(cookie)
		if flags.has("i") or flags.has("I") or flags.has("v"):
			session.record("headers_seen", {"ip": fetched["ip"], "port": fetched["port"], "path": fetched["path"]})
		if flags.has("i") or flags.has("I"):
			result.stdout += _header_block(fetched)

		var is_redirect: bool = fetched["status"] in [301, 302, 303, 307, 308] and fetched["headers"].has("Location")
		if flags.has("L") and is_redirect and hops < MAX_REDIRECTS:
			hops += 1
			url = _absolute_location(fetched, str(fetched["headers"]["Location"]))
			if fetched["status"] in [301, 302, 303] and method != "HEAD":
				method = "GET"    # como curl: tras estas redirecciones se vuelve a GET sin cuerpo
				body = ""
			continue
		break

	if values.has("c") and not _write_jar(session, str(values["c"]), last_response["ip"], collected, result):
		return result
	if flags.has("I"):
		return result
	if values.has("o"):
		var target: String = Vfs.normalize(session.cwd, values["o"])
		var fs = session.host.fs
		var allowed: bool = fs.is_dir(target.get_base_dir()) and fs.check_access(target.get_base_dir(), session.user, "w") and not fs.is_dir(target)
		if not allowed:
			result.stderr += "curl: (23) Failure writing output to destination\n"
			result.exit_code = 23
			return result
		fs.write_file(target, last_response["body"], false, session.user["name"], session.user["name"])
		return result
	result.stdout += last_response["body"]
	return result


## Convierte las opciones largas en cortas y separa las que se pueden repetir (-H, -d, --data-urlencode).
func _prepare(args: Array) -> Dictionary:
	var rest: Array = []
	var headers := {}
	var data: Array = []
	var index := 0
	while index < args.size():
		var token: String = args[index]
		if token.begins_with("--"):
			var long_name := token.get_slice("=", 0)
			if not LONG_OPTIONS.has(long_name):
				return {"error": "curl: option %s: is unknown\ncurl: try 'curl --help' for more information" % long_name, "rest": [], "headers": {}, "data": []}
			token = LONG_OPTIONS[long_name]
			if "=" in args[index]:
				token += args[index].substr(args[index].find("=") + 1)
		if token.length() >= 2 and token.substr(0, 2) in REPEATABLE:
			var letter := token.substr(0, 2)
			var value := token.substr(2)
			if value == "":
				index += 1
				if index >= args.size():
					return {"error": "curl: option %s: requires parameter" % letter, "rest": [], "headers": {}, "data": []}
				value = args[index]
			match letter:
				"-H":
					if ":" in value:
						headers[value.get_slice(":", 0).strip_edges().to_lower()] = value.substr(value.find(":") + 1).strip_edges()
				"-d":
					data.append(value)
				"-E":
					if "=" in value:
						data.append(value.get_slice("=", 0) + "=" + HttpSim.url_encode(value.substr(value.find("=") + 1)))
					else:
						data.append(HttpSim.url_encode(value))
		else:
			rest.append(token)
		index += 1
	return {"error": "", "rest": rest, "headers": headers, "data": data}


## Cookies de -b: una cadena "a=1; b=2" o un archivo de cookies.
func _initial_cookies(session: RefCounted, source: String, url: String) -> Dictionary:
	if "=" in source:
		return HttpSim.parse_cookie_header(source)
	var fs = session.host.fs
	var path := Vfs.normalize(session.cwd, source)
	if not fs.is_file(path) or not fs.check_access(path, session.user, "r"):
		return {}
	var host_part := url.trim_prefix("http://").trim_prefix("https://").get_slice("/", 0).get_slice(":", 0)
	var resolved = Network.resolve(session.world, host_part)
	return HttpSim.read_jar(fs.read_file(path), resolved.ip if resolved != null else host_part)


func _write_jar(session: RefCounted, shown: String, ip: String, cookies: Array, result: RefCounted) -> bool:
	var fs = session.host.fs
	var path := Vfs.normalize(session.cwd, shown)
	var parent_ok: bool = fs.is_dir(path.get_base_dir()) and fs.check_access(path.get_base_dir(), session.user, "w") and not fs.is_dir(path)
	if not parent_ok:
		result.stderr += "curl: (23) Failure writing output to destination\n"
		result.exit_code = 23
		return false
	fs.write_file(path, HttpSim.jar_text(ip, cookies), false, session.user["name"], session.user["name"])
	return true


## Hace una petición simulada. Devuelve {error, code, status, headers, set_cookies, body, ...}.
func _fetch(session: RefCounted, url: String, request: Dictionary, verbose: bool) -> Dictionary:
	var failure := {"error": "", "code": 0, "verbose": ""}
	var pattern := RegEx.create_from_string("^(?:([a-zA-Z][a-zA-Z0-9+.\\-]*)://)?([^/:?#]+)(?::(\\d+))?([/?][^#]*)?(?:#.*)?$")
	var found := pattern.search(url)
	if found == null:
		failure["error"] = "curl: (3) URL rejected: Bad hostname"
		failure["code"] = 3
		return failure
	var scheme: String = found.get_string(1) if found.get_string(1) != "" else "http"
	if not scheme in ["http", "https"]:
		failure["error"] = "curl: (1) Protocol \"%s\" not supported or disabled in libcurl" % scheme
		failure["code"] = 1
		return failure
	var host_text: String = found.get_string(2)
	var port := int(found.get_string(3)) if found.get_string(3) != "" else (443 if scheme == "https" else 80)
	var path_and_query: String = found.get_string(4) if found.get_string(4) != "" else "/"
	if path_and_query.begins_with("?"):
		path_and_query = "/" + path_and_query
	var path: String = path_and_query.get_slice("?", 0)
	var query: Dictionary = HttpSim.parse_form(path_and_query.substr(path_and_query.find("?") + 1)) if "?" in path_and_query else {}

	var host = Network.resolve(session.world, host_text)
	if host == null and not Host.is_valid_ip(host_text):
		failure["error"] = "curl: (6) Could not resolve host: %s" % host_text
		failure["code"] = 6
		return failure
	var ip: String = host.ip if host != null else host_text
	if host_text == "localhost":
		ip = Network.LOCALHOST_IP

	failure["ip"] = ip
	failure["port"] = port
	if verbose:
		failure["verbose"] += "*   Trying %s:%d...\n" % [ip, port]
	var service = host.get_service(port) if host != null else null
	if host == null or not host.up or (service != null and service.state == "filtered"):
		failure["error"] = "curl: (28) Failed to connect to %s port %d after 129114 ms: Connection timed out" % [host_text, port]
		failure["code"] = 28
		return failure
	if service == null or service.state == "closed":
		failure["error"] = "curl: (7) Failed to connect to %s port %d after 0 ms: Connection refused" % [host_text, port]
		failure["code"] = 7
		return failure
	if verbose:
		failure["verbose"] += "* Connected to %s (%s) port %d\n" % [host_text, ip, port]
	if scheme == "https" and service.name != "https":
		failure["error"] = "curl: (35) error:0A00010B:SSL routines::wrong version number"
		failure["code"] = 35
		return failure
	if not host.sites.has(port):
		failure["error"] = "curl: (52) Empty reply from server"
		failure["code"] = 52
		return failure

	var site: Dictionary = host.sites[port]
	var request_view := {
		"method": request["method"], "path": path, "query": query,
		"form": HttpSim.parse_form(request["body"]) if request["body"] != "" else {}, "cookies": request["cookies"],
	}
	var variant: Dictionary = HttpSim.respond(site, request_view)
	var status: int = variant.get("status", 404)
	var response_headers: Dictionary = (variant.get("headers", {"Content-Type": "text/html; charset=iso-8859-1"}) as Dictionary).duplicate()
	var body: String = variant.get("body", NOT_FOUND_BODY)
	var response := {
		"error": "", "code": 0, "status": status, "headers": response_headers, "body": body,
		"set_cookies": variant.get("set_cookies", []), "server": site["server"], "host": host_text, "port": port,
		"scheme": scheme, "verbose": failure["verbose"], "ip": ip, "path": path,
		"query": path_and_query.substr(path_and_query.find("?") + 1) if "?" in path_and_query else "",
	}
	if verbose:
		response["verbose"] += _verbose_request(request, host_text, path_and_query)
		response["verbose"] += _header_block(response).replace("\n", "\n< ").insert(0, "< ").trim_suffix("< ")
	return response


func _verbose_request(request: Dictionary, host_text: String, path_and_query: String) -> String:
	var text := "> %s %s HTTP/1.1\n> Host: %s\n" % [request["method"], path_and_query, host_text]
	text += "> User-Agent: %s\n> Accept: */*\n" % request["headers"].get("user-agent", "curl/8.5.0")
	if not request["cookies"].is_empty():
		var parts: Array[String] = []
		for name: String in request["cookies"]:
			parts.append("%s=%s" % [name, request["cookies"][name]])
		text += "> Cookie: %s\n" % "; ".join(parts)
	for name: String in request["headers"]:
		if name != "user-agent":
			text += "> %s: %s\n" % [_title_case(name), request["headers"][name]]
	if request["body"] != "":
		text += "> Content-Length: %d\n" % (request["body"] as String).to_utf8_buffer().size()
	return text + ">\n"


## "content-type" -> "Content-Type" (las cabeceras se guardan en minúsculas).
func _title_case(header_name: String) -> String:
	var parts: Array[String] = []
	for part in header_name.split("-"):
		parts.append(part.capitalize())
	return "-".join(parts)


func _header_block(response: Dictionary) -> String:
	var status: int = response["status"]
	var text := "HTTP/1.1 %d %s\nDate: %s\n" % [status, STATUS_TEXT.get(status, ""), HTTP_DATE]
	if response["server"] != "":
		text += "Server: %s\n" % response["server"]
	for header_name: String in response["headers"]:
		text += "%s: %s\n" % [header_name, response["headers"][header_name]]
	for cookie: String in response["set_cookies"]:
		text += "Set-Cookie: %s\n" % cookie
	if not response["headers"].has("Content-Length"):
		text += "Content-Length: %d\n" % (response["body"] as String).to_utf8_buffer().size()
	return text + "\n"


func _absolute_location(response: Dictionary, location: String) -> String:
	if location.begins_with("http://") or location.begins_with("https://"):
		return location
	var port_part := "" if int(response["port"]) in [80, 443] else ":%d" % int(response["port"])
	return "%s://%s%s%s" % [response["scheme"], response["host"], port_part, location]
