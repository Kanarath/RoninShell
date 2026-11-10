extends RefCounted
## Comodines del shell (*, ? y [...]) sobre el sistema de archivos del laboratorio.
##
## `matches` compara un patrón con un nombre; `expand` devuelve los caminos que cumplen un patrón
## con barras (p. ej. /var/log/*.log), ordenados. Como en bash, un * no casa con nombres ocultos
## (los que empiezan por punto) salvo que el patrón empiece por punto, y no se entra en directorios
## sin permiso de lectura. Si nada coincide, quien llama deja el patrón tal cual.
##
## [...] es una clase de un carácter: [0-9] un dígito, [a-z] una minúscula, [abc] una de esas tres,
## y [!...] o [^...] la niegan (cualquier carácter que NO esté en la clase). Un '[' sin un ']' que
## lo cierre es un carácter literal, como en bash.

const Vfs := preload("res://engine/vfs.gd")

const MAX_MATCHES := 500


static func has_wildcard(text: String) -> bool:
	return "*" in text or "?" in text or "[" in text


## Convierte el patrón en una lista de elementos: literal, "any" (?), "star" (*) o "class" ([...]).
static func _parse(pattern: String) -> Array:
	var tokens: Array = []
	var i := 0
	var n := pattern.length()
	while i < n:
		var c := pattern[i]
		if c == "*":
			tokens.append({"type": "star"})
			i += 1
		elif c == "?":
			tokens.append({"type": "any"})
			i += 1
		elif c == "[":
			var close := pattern.find("]", i + 2)   # un "]" justo al abrir no cierra: es literal dentro de la clase
			if close == -1:
				tokens.append({"type": "lit", "char": c})
				i += 1
				continue
			var body := pattern.substr(i + 1, close - i - 1)
			var negate := body.begins_with("!") or body.begins_with("^")
			if negate:
				body = body.substr(1)
			var singles := {}
			var ranges: Array = []
			var j := 0
			while j < body.length():
				if j + 2 < body.length() and body[j + 1] == "-":
					ranges.append([body[j], body[j + 2]])
					j += 3
				else:
					singles[body[j]] = true
					j += 1
			tokens.append({"type": "class", "negate": negate, "singles": singles, "ranges": ranges})
			i = close + 1
		else:
			tokens.append({"type": "lit", "char": c})
			i += 1
	return tokens


static func _token_matches(token: Dictionary, ch: String) -> bool:
	match token["type"]:
		"any":
			return true
		"lit":
			return token["char"] == ch
		"class":
			var hit: bool = token["singles"].has(ch)
			if not hit:
				for pair: Array in token["ranges"]:
					if ch >= pair[0] and ch <= pair[1]:
						hit = true
						break
			return hit != token["negate"]
	return false


## ¿Encaja `text` con el patrón? * = cualquier cosa (incluso nada); ?, una clase y un literal
## encajan exactamente un carácter cada uno (el mismo algoritmo de siempre, sobre tokens en vez de letras).
static func matches(pattern: String, text: String) -> bool:
	var tokens := _parse(pattern)
	var p := 0
	var t := 0
	var star := -1
	var mark := 0
	while t < text.length():
		if p < tokens.size() and tokens[p]["type"] != "star" and _token_matches(tokens[p], text[t]):
			p += 1
			t += 1
		elif p < tokens.size() and tokens[p]["type"] == "star":
			star = p
			mark = t
			p += 1
		elif star != -1:
			p = star + 1
			mark += 1
			t = mark
		else:
			return false
	while p < tokens.size() and tokens[p]["type"] == "star":
		p += 1
	return p == tokens.size()


## Caminos (escritos como el patrón: relativos o absolutos) que cumplen el patrón, ordenados.
static func expand(fs: RefCounted, user: Dictionary, cwd: String, pattern: String) -> Array:
	var absolute := pattern.begins_with("/")
	var parts: PackedStringArray = pattern.split("/", false)
	var found: Array = []
	_walk(fs, user, "/" if absolute else cwd, "/" if absolute else "", parts, 0, found)
	found.sort()
	return found.slice(0, MAX_MATCHES)


static func _walk(fs: RefCounted, user: Dictionary, real_dir: String, shown_prefix: String, parts: PackedStringArray, index: int, found: Array) -> void:
	if found.size() >= MAX_MATCHES:
		return
	var part := parts[index]
	var last := index == parts.size() - 1
	var names: Array = []
	if has_wildcard(part):
		if not fs.is_dir(real_dir) or not fs.check_access(real_dir, user, "r"):
			return
		for name: String in fs.list_dir(real_dir):
			if name.begins_with(".") and not part.begins_with("."):
				continue   # los ocultos no se cuelan con un *
			if matches(part, name):
				names.append(name)
	elif part == "." or part == "..":
		names.append(part)
	elif fs.exists(Vfs.normalize(real_dir, part)):
		names.append(part)
	for name: String in names:
		var next_real := Vfs.normalize(real_dir, name)
		var shown := shown_prefix + name
		if last:
			found.append(shown)
		elif fs.is_dir(next_real) and fs.check_access(next_real, user, "x"):
			_walk(fs, user, next_real, shown + "/", parts, index + 1, found)
