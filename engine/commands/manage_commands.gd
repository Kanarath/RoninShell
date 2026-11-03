extends RefCounted
## Gestión de archivos del laboratorio: mkdir, touch, cp, mv, rm, sha256sum y diff.
## Todo ocurre sobre el sistema de archivos virtual del host (nada toca el disco real) y respeta
## los permisos Unix del usuario: para crear, copiar, mover o borrar hace falta poder escribir en el directorio.
##
## Límites conocidos (a propósito): sin -i/-v/-p de cp ni -u de diff; diff compara línea a línea por posición
## (no calcula el mínimo de cambios); sha256sum calcula el hash real del texto del archivo.

const CommandResult := preload("res://engine/shell/command_result.gd")
const Vfs := preload("res://engine/vfs.gd")
const ArgParser := preload("res://engine/commands/arg_parser.gd")


func register_all(registry: RefCounted) -> void:
	registry.register("mkdir", "Crea directorios (-p)", _mkdir)
	registry.register("touch", "Crea un archivo vacío (si no existe)", _touch)
	registry.register("cp", "Copia archivos o directorios (-r)", _cp)
	registry.register("mv", "Mueve o renombra archivos y directorios", _mv)
	registry.register("rm", "Borra archivos o directorios (-r -f)", _rm)
	registry.register("sha256sum", "Calcula la huella SHA-256 de archivos", _sha256sum)
	registry.register("diff", "Compara dos archivos línea a línea (-q)", _diff)


# --- Utilidades ---------------------------------------------------------------

func _abs(session: RefCounted, path: String) -> String:
	return Vfs.normalize(session.cwd, path)


func _fail(result: RefCounted, message: String, code := 1) -> void:
	result.stderr += message + "\n"
	result.exit_code = code


## ¿Puede el usuario crear o quitar cosas dentro de este directorio? (escritura y paso)
func _can_modify_dir(session: RefCounted, dir: String) -> bool:
	return session.host.fs.is_dir(dir) and session.host.fs.check_access(dir, session.user, "w") and session.host.fs.check_access(dir, session.user, "x")


## Si el destino es un directorio existente, el elemento va dentro con su nombre; si no, el destino es la ruta final.
func _final_target(session: RefCounted, source: String, target_arg: String) -> String:
	var target := _abs(session, target_arg)
	if session.host.fs.is_dir(target):
		return target.path_join(source.get_file())
	return target


# --- mkdir / touch --------------------------------------------------------------

func _mkdir(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "p")
	if parsed["error"] != "":
		return CommandResult.error("mkdir: " + parsed["error"])
	if parsed["rest"].is_empty():
		return CommandResult.error("mkdir: missing operand")
	var fs = session.host.fs
	var result := CommandResult.new()
	for dir_arg: String in parsed["rest"]:
		var path := _abs(session, dir_arg)
		if fs.exists(path):
			if not (parsed["flags"].has("p") and fs.is_dir(path)):
				_fail(result, "mkdir: cannot create directory '%s': File exists" % dir_arg)
			continue
		# Con -p se crean también los directorios intermedios que falten.
		var chain: Array[String] = [path]
		var parent := path.get_base_dir()
		while parsed["flags"].has("p") and not fs.exists(parent) and parent != "/":
			chain.push_front(parent)
			parent = parent.get_base_dir()
		if not fs.exists(parent):
			_fail(result, "mkdir: cannot create directory '%s': No such file or directory" % dir_arg)
			continue
		if not _can_modify_dir(session, parent):
			_fail(result, "mkdir: cannot create directory '%s': Permission denied" % dir_arg)
			session.record("permission_denied", {"path": parent, "action": "write"})
			continue
		for step in chain:
			fs.add_dir(step, session.user["name"], session.user["name"], "755")
			session.record("dir_created", {"path": step})
	return result


func _touch(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if args.is_empty():
		return CommandResult.error("touch: missing file operand")
	var fs = session.host.fs
	var result := CommandResult.new()
	for file_arg: String in args:
		var path := _abs(session, file_arg)
		if fs.exists(path):
			continue   # solo cambiaría la fecha, que en este laboratorio es fija
		var parent := path.get_base_dir()
		if not fs.exists(parent):
			_fail(result, "touch: cannot touch '%s': No such file or directory" % file_arg)
		elif not _can_modify_dir(session, parent):
			_fail(result, "touch: cannot touch '%s': Permission denied" % file_arg)
			session.record("permission_denied", {"path": parent, "action": "write"})
		else:
			fs.add_file(path, "", session.user["name"], session.user["name"], "644")
			session.record("file_created", {"path": path})
	return result


# --- cp / mv --------------------------------------------------------------------

func _cp(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "rR")
	if parsed["error"] != "":
		return CommandResult.error("cp: " + parsed["error"])
	var recursive: bool = parsed["flags"].has("r") or parsed["flags"].has("R")
	var operands: Array = parsed["rest"]
	if operands.size() < 2:
		return CommandResult.error("cp: missing destination file operand after '%s'" % (operands[0] if operands.size() == 1 else ""))
	var fs = session.host.fs
	var destination_arg: String = operands[-1]
	var result := CommandResult.new()
	if operands.size() > 2 and not fs.is_dir(_abs(session, destination_arg)):
		return CommandResult.error("cp: target '%s' is not a directory" % destination_arg)
	for source_arg: String in operands.slice(0, operands.size() - 1):
		var source := _abs(session, source_arg)
		if not fs.exists(source):
			_fail(result, "cp: cannot stat '%s': No such file or directory" % source_arg)
			continue
		if fs.is_dir(source) and not recursive:
			_fail(result, "cp: -r not specified; omitting directory '%s'" % source_arg)
			continue
		var target := _final_target(session, source, destination_arg)
		if target == source:
			_fail(result, "cp: '%s' and '%s' are the same file" % [source_arg, destination_arg])
			continue
		if not fs.check_access(source, session.user, "r"):
			_fail(result, "cp: cannot open '%s' for reading: Permission denied" % source_arg)
			session.record("permission_denied", {"path": source, "action": "read"})
			continue
		var parent := target.get_base_dir()
		if not fs.exists(parent):
			_fail(result, "cp: cannot create regular file '%s': No such file or directory" % destination_arg)
			continue
		if fs.is_dir(source):
			if fs.exists(target):
				_fail(result, "cp: cannot overwrite '%s': already exists" % target)
			elif not _can_modify_dir(session, parent):
				_fail(result, "cp: cannot create directory '%s': Permission denied" % destination_arg)
			elif fs.copy_tree(source, target, session.user["name"], session.user["name"]) == 0:
				_fail(result, "cp: cannot copy a directory, '%s', into itself, '%s'" % [source_arg, destination_arg])
			else:
				session.record("file_copied", {"src": source, "dst": target, "directory": true})
			continue
		if fs.exists(target):
			if fs.is_dir(target) or not fs.check_access(target, session.user, "w"):
				_fail(result, "cp: cannot create regular file '%s': Permission denied" % destination_arg)
				continue
			fs.write_file(target, fs.read_file(source), false, session.user["name"], session.user["name"])
		elif not _can_modify_dir(session, parent):
			_fail(result, "cp: cannot create regular file '%s': Permission denied" % destination_arg)
			session.record("permission_denied", {"path": parent, "action": "write"})
			continue
		else:
			fs.copy_file(source, target, session.user["name"], session.user["name"])
		session.record("file_read", {"path": source})
		session.record("file_copied", {"src": source, "dst": target, "directory": false})
	return result


func _mv(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "")
	if parsed["error"] != "":
		return CommandResult.error("mv: " + parsed["error"])
	var operands: Array = parsed["rest"]
	if operands.size() < 2:
		return CommandResult.error("mv: missing destination file operand after '%s'" % (operands[0] if operands.size() == 1 else ""))
	var fs = session.host.fs
	var destination_arg: String = operands[-1]
	var result := CommandResult.new()
	if operands.size() > 2 and not fs.is_dir(_abs(session, destination_arg)):
		return CommandResult.error("mv: target '%s' is not a directory" % destination_arg)
	for source_arg: String in operands.slice(0, operands.size() - 1):
		var source := _abs(session, source_arg)
		if not fs.exists(source) or source == "/":
			_fail(result, "mv: cannot stat '%s': No such file or directory" % source_arg)
			continue
		var target := _final_target(session, source, destination_arg)
		if target == source:
			_fail(result, "mv: '%s' and '%s' are the same file" % [source_arg, destination_arg])
			continue
		if not fs.is_dir(target.get_base_dir()):
			_fail(result, "mv: cannot move '%s' to '%s': No such file or directory" % [source_arg, destination_arg])
			continue
		if not _can_modify_dir(session, source.get_base_dir()) or not _can_modify_dir(session, target.get_base_dir()):
			_fail(result, "mv: cannot move '%s' to '%s': Permission denied" % [source_arg, destination_arg])
			session.record("permission_denied", {"path": source, "action": "write"})
			continue
		if fs.exists(target):
			if fs.is_dir(source) or fs.is_dir(target):
				_fail(result, "mv: cannot overwrite '%s': already exists" % target)
				continue
			fs.remove(target)   # un archivo se puede sobrescribir con otro
		if fs.move(source, target):
			session.record("file_moved", {"src": source, "dst": target})
		else:
			_fail(result, "mv: cannot move '%s' to a subdirectory of itself, '%s'" % [source_arg, destination_arg])
	return result


# --- rm -------------------------------------------------------------------------

func _rm(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "rRf")
	if parsed["error"] != "":
		return CommandResult.error("rm: " + parsed["error"])
	var force: bool = parsed["flags"].has("f")
	var recursive: bool = parsed["flags"].has("r") or parsed["flags"].has("R")
	if parsed["rest"].is_empty():
		return CommandResult.new() if force else CommandResult.error("rm: missing operand")
	var fs = session.host.fs
	var result := CommandResult.new()
	for file_arg: String in parsed["rest"]:
		var path := _abs(session, file_arg)
		if file_arg in [".", ".."] or file_arg.ends_with("/.") or file_arg.ends_with("/.."):
			_fail(result, "rm: refusing to remove '.' or '..' directory: skipping '%s'" % file_arg)
			continue
		if path == "/":
			_fail(result, "rm: it is dangerous to operate recursively on '/' (la raíz no se toca en este laboratorio)")
			continue
		if not fs.exists(path):
			if not force:
				_fail(result, "rm: cannot remove '%s': No such file or directory" % file_arg)
			continue
		if fs.is_dir(path) and not recursive:
			_fail(result, "rm: cannot remove '%s': Is a directory" % file_arg)
			continue
		if not _can_modify_dir(session, path.get_base_dir()):
			_fail(result, "rm: cannot remove '%s': Permission denied" % file_arg)
			session.record("permission_denied", {"path": path.get_base_dir(), "action": "write"})
			continue
		if fs.is_dir(path):
			var count: int = fs.remove_tree(path)
			session.record("file_removed", {"path": path, "directory": true, "count": count})
		else:
			fs.remove(path)
			session.record("file_removed", {"path": path, "directory": false, "count": 1})
	return result


# --- sha256sum / diff -------------------------------------------------------------

func _sha256sum(session: RefCounted, args: Array, stdin: String) -> RefCounted:
	var result := CommandResult.new()
	var fs = session.host.fs
	if args.is_empty():
		result.stdout = "%s  -\n" % stdin.sha256_text()
		return result
	for file_arg: String in args:
		var path := _abs(session, file_arg)
		if not fs.exists(path):
			_fail(result, "sha256sum: %s: No such file or directory" % file_arg)
		elif fs.is_dir(path):
			_fail(result, "sha256sum: %s: Is a directory" % file_arg)
		elif not fs.check_access(path, session.user, "r"):
			_fail(result, "sha256sum: %s: Permission denied" % file_arg)
			session.record("permission_denied", {"path": path, "action": "read"})
		else:
			var hash_text: String = fs.read_file(path).sha256_text()
			result.stdout += "%s  %s\n" % [hash_text, file_arg]
			session.record("file_read", {"path": path})
			session.record("hash_computed", {"path": path, "hash": hash_text})
	return result


func _diff(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "q")
	if parsed["error"] != "":
		return CommandResult.error("diff: " + parsed["error"], 2)
	if parsed["rest"].size() != 2:
		return CommandResult.error("diff: usa diff [-q] archivo1 archivo2", 2)
	var fs = session.host.fs
	var texts: Array = []
	for file_arg: String in parsed["rest"]:
		var path := _abs(session, file_arg)
		if not fs.exists(path):
			return CommandResult.error("diff: %s: No such file or directory" % file_arg, 2)
		if fs.is_dir(path):
			return CommandResult.error("diff: %s: Is a directory (solo se comparan archivos)" % file_arg, 2)
		if not fs.check_access(path, session.user, "r"):
			session.record("permission_denied", {"path": path, "action": "read"})
			return CommandResult.error("diff: %s: Permission denied" % file_arg, 2)
		texts.append(fs.read_file(path))
		session.record("file_read", {"path": path})
	var first_lines := _split_lines(texts[0])
	var second_lines := _split_lines(texts[1])
	var out := ""
	for i in maxi(first_lines.size(), second_lines.size()):
		var a: String = first_lines[i] if i < first_lines.size() else ""
		var b: String = second_lines[i] if i < second_lines.size() else ""
		if i < first_lines.size() and i < second_lines.size():
			if a != b:
				out += "%dc%d\n< %s\n---\n> %s\n" % [i + 1, i + 1, a, b]
		elif i < first_lines.size():
			out += "%dd%d\n< %s\n" % [i + 1, i, a]
		else:
			out += "%da%d\n> %s\n" % [i, i + 1, b]
	var same := out == ""
	session.record("files_compared", {"a": _abs(session, parsed["rest"][0]), "b": _abs(session, parsed["rest"][1]), "same": same})
	var result := CommandResult.new()
	if same:
		return result
	result.exit_code = 1
	result.stdout = ("Files %s and %s differ\n" % [parsed["rest"][0], parsed["rest"][1]]) if parsed["flags"].has("q") else out
	return result


func _split_lines(text: String) -> Array:
	var lines: Array = []
	if text == "":
		return lines
	for line in text.split("\n"):
		lines.append(line)
	if lines[-1] == "":
		lines.pop_back()
	return lines
