extends RefCounted
## Comodines del shell (* y ?) sobre el sistema de archivos del laboratorio.
##
## `matches` compara un patrón con un nombre; `expand` devuelve los caminos que cumplen un patrón
## con barras (p. ej. /var/log/*.log), ordenados. Como en bash, un * no casa con nombres ocultos
## (los que empiezan por punto) salvo que el patrón empiece por punto, y no se entra en directorios
## sin permiso de lectura. Si nada coincide, quien llama deja el patrón tal cual.

const Vfs := preload("res://engine/vfs.gd")

const MAX_MATCHES := 500


static func has_wildcard(text: String) -> bool:
	return "*" in text or "?" in text


## ¿Encaja `text` con el patrón? * = cualquier cosa (incluso nada), ? = un carácter.
static func matches(pattern: String, text: String) -> bool:
	var p := 0
	var t := 0
	var star := -1
	var mark := 0
	while t < text.length():
		if p < pattern.length() and (pattern[p] == "?" or pattern[p] == text[t]) and pattern[p] != "*":
			p += 1
			t += 1
		elif p < pattern.length() and pattern[p] == "*":
			star = p
			mark = t
			p += 1
		elif star != -1:
			p = star + 1
			mark += 1
			t = mark
		else:
			return false
	while p < pattern.length() and pattern[p] == "*":
		p += 1
	return p == pattern.length()


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
