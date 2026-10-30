extends RefCounted
## Utilidades HTTP del laboratorio: codificación de URL, lectura de consultas y formularios,
## cookies (Set-Cookie y archivos de cookies de curl) y selección de la respuesta de un sitio.
##
## Los sitios simulados son datos, no código: cada ruta tiene una o varias "variantes" y se
## devuelve la primera cuya condición "when" encaja con la petición (método, consulta,
## formulario o cookies). Sin "when", la variante sirve de respuesta por defecto.

const COOKIE_JAR_HEADER := "# Netscape HTTP Cookie File"


## "a%20b+c" -> "a b c"
static func url_decode(text: String) -> String:
	return text.replace("+", " ").uri_decode()


## "a b" -> "a%20b"
static func url_encode(text: String) -> String:
	return text.uri_encode()


## "a=1&b=dos%20tres" -> {a: "1", b: "dos tres"}
static func parse_form(raw: String) -> Dictionary:
	var result := {}
	for pair in raw.split("&", false):
		var key := url_decode(pair.get_slice("=", 0))
		var value := url_decode(pair.get_slice("=", 1)) if "=" in pair else ""
		result[key] = value
	return result


## "a=1; b=2" -> {a: "1", b: "2"}
static func parse_cookie_header(raw: String) -> Dictionary:
	var result := {}
	for part in raw.split(";", false):
		var piece := part.strip_edges()
		if "=" in piece:
			result[piece.get_slice("=", 0)] = piece.substr(piece.find("=") + 1)
	return result


## "session=abc; Path=/; HttpOnly" -> {name, value, path, http_only, secure, same_site}
static func parse_set_cookie(raw: String) -> Dictionary:
	var parts := raw.split(";", false)
	var first := parts[0].strip_edges() if parts.size() > 0 else ""
	var cookie := {
		"name": first.get_slice("=", 0), "value": first.substr(first.find("=") + 1) if "=" in first else "",
		"path": "/", "http_only": false, "secure": false, "same_site": "",
	}
	for index in range(1, parts.size()):
		var attribute := parts[index].strip_edges()
		var lowered := attribute.to_lower()
		if lowered == "httponly":
			cookie["http_only"] = true
		elif lowered == "secure":
			cookie["secure"] = true
		elif lowered.begins_with("samesite="):
			cookie["same_site"] = attribute.get_slice("=", 1)
		elif lowered.begins_with("path="):
			cookie["path"] = attribute.get_slice("=", 1)
	return cookie


## Contenido de un archivo de cookies (formato Netscape, el de curl -c).
static func jar_text(host: String, cookies: Array) -> String:
	var text := COOKIE_JAR_HEADER + "\n"
	for cookie: Dictionary in cookies:
		var prefix := "#HttpOnly_" if cookie["http_only"] else ""
		text += "%s%s\tFALSE\t%s\t%s\t0\t%s\t%s\n" % [prefix, host, cookie["path"], "TRUE" if cookie["secure"] else "FALSE", cookie["name"], cookie["value"]]
	return text


## Lee un archivo de cookies y devuelve las que valen para este host: {nombre: valor}.
static func read_jar(text: String, host: String) -> Dictionary:
	var result := {}
	for line in text.split("\n", false):
		var clean := line.trim_prefix("#HttpOnly_")
		if clean.begins_with("#"):
			continue
		var fields := clean.split("\t")
		if fields.size() >= 7 and fields[0] == host:
			result[fields[5]] = fields[6]
	return result


## ¿Encaja la petición con la condición "when" de una variante?
## when = {method, query: {k: v}, form: {k: v}, cookies: {k: v}}; solo se comprueban los campos presentes.
static func matches(when: Dictionary, request: Dictionary) -> bool:
	if when.has("method") and str(when["method"]).to_upper() != request["method"]:
		return false
	for key: String in ["query", "form", "cookies"]:
		var wanted: Dictionary = when.get(key, {})
		var actual: Dictionary = request.get(key, {})
		for name: String in wanted:
			if not actual.has(name) or str(actual[name]) != str(wanted[name]):
				return false
	return true


## La respuesta del sitio para esta petición, o {} si la ruta no existe.
static func respond(site: Dictionary, request: Dictionary) -> Dictionary:
	var variants: Array = site["routes"].get(request["path"], [])
	for variant: Dictionary in variants:
		if matches(variant.get("when", {}), request):
			return variant
	return {}
