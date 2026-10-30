extends RefCounted
## Autocompletado con Tab, como en bash: completa comandos en la primera palabra
## y rutas en las demás. Solo mira lo que el usuario puede ver en el laboratorio.
##
## Devuelve {"line": String, "options": Array[String]}:
##   - un único candidato: "line" ya lo trae completo (con espacio, o "/" si es directorio)
##   - varios: "line" avanza hasta el prefijo común y "options" lista las alternativas

const Vfs := preload("res://engine/vfs.gd")


static func complete(session: RefCounted, line: String) -> Dictionary:
	var split_at := maxi(line.rfind(" "), line.rfind("\t"))
	var head := line.substr(0, split_at + 1)   # todo lo anterior a la palabra actual
	var word := line.substr(split_at + 1)
	var candidates: Array[String] = []
	var is_command := head.strip_edges() == ""

	if is_command:
		for command_name in session.registry.names():
			if command_name.begins_with(word):
				candidates.append(command_name)
	else:
		candidates = _path_candidates(session, word)

	if candidates.is_empty():
		return {"line": line, "options": []}
	candidates.sort()
	if candidates.size() == 1:
		var only := candidates[0]
		var suffix := "" if only.ends_with("/") else " "
		return {"line": head + only + suffix, "options": []}

	var common := _common_prefix(candidates)
	return {"line": head + common, "options": candidates}


static func _path_candidates(session: RefCounted, word: String) -> Array[String]:
	var slash := word.rfind("/")
	var dir_part := word.substr(0, slash + 1)       # "informe/" o "/etc/" o ""
	var name_part := word.substr(slash + 1)
	var dir_path := Vfs.normalize(session.cwd, dir_part if dir_part != "" else ".")
	var fs = session.host.fs
	var found: Array[String] = []
	if not fs.is_dir(dir_path) or not fs.check_access(dir_path, session.user, "r"):
		return found
	for entry_name: String in fs.list_dir(dir_path):
		if not entry_name.begins_with(name_part):
			continue
		if entry_name.begins_with(".") and not name_part.begins_with("."):
			continue
		var shown := dir_part + entry_name
		if fs.is_dir(dir_path.path_join(entry_name)):
			shown += "/"
		found.append(shown)
	return found


static func _common_prefix(items: Array[String]) -> String:
	var prefix := items[0]
	for item in items:
		while not item.begins_with(prefix):
			prefix = prefix.substr(0, prefix.length() - 1)
	return prefix
