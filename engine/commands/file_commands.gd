extends RefCounted
## Comandos de archivos y texto: cd, ls, cat, head, tail, wc, sort, uniq, grep, find,
## chmod, whoami, id, hostname e history. Todos operan sobre el sistema de archivos
## virtual del host y respetan los permisos Unix del usuario de la sesión.
##
## Límites conocidos (a propósito, para mantener el motor pequeño):
##   - ls imprime un nombre por línea (como "ls -1"), nunca en columnas.
##   - grep usa expresiones regulares de Godot (parecidas a "grep -E"), no BRE.
##   - Sin comodines (*) en rutas: llegarán cuando una misión los necesite.

const CommandResult := preload("res://engine/shell/command_result.gd")
const Vfs := preload("res://engine/vfs.gd")
const ArgParser := preload("res://engine/commands/arg_parser.gd")

const LISTING_DATE := "Oct 29 12:00"  # fecha fija del laboratorio: no depende del reloj de tu PC


func register_all(registry: RefCounted) -> void:
	registry.register("cd", "Cambia de directorio", _cd)
	registry.register("ls", "Lista el contenido de un directorio (-l -a)", _ls)
	registry.register("cat", "Muestra el contenido de archivos", _cat)
	registry.register("head", "Primeras líneas de un archivo (-n N)", _head)
	registry.register("tail", "Últimas líneas de un archivo (-n N)", _tail)
	registry.register("wc", "Cuenta líneas, palabras y bytes (-l -w -c)", _wc)
	registry.register("sort", "Ordena líneas (-r -u -n)", _sort)
	registry.register("uniq", "Quita líneas repetidas consecutivas (-c)", _uniq)
	registry.register("grep", "Busca texto con expresiones regulares (-i -n -v -c -r)", _grep)
	registry.register("find", "Busca archivos (-name, -type f|d)", _find)
	registry.register("chmod", "Cambia permisos (755, u+x...)", _chmod)
	registry.register("whoami", "Muestra tu usuario", _whoami)
	registry.register("id", "Muestra tu identidad y grupos", _id)
	registry.register("hostname", "Muestra el nombre de la máquina", _hostname)
	registry.register("history", "Muestra los comandos escritos", _history)


# --- Utilidades ---------------------------------------------------------------

func _abs(session: RefCounted, path: String) -> String:
	return Vfs.normalize(session.cwd, path)


## Texto -> líneas, sin la línea vacía final que deja el último salto.
func _lines(text: String) -> Array[String]:
	var lines: Array[String] = []
	if text == "":
		return lines
	for line in text.split("\n"):
		lines.append(line)
	if lines[-1] == "":
		lines.pop_back()
	return lines


func _join(lines: Array) -> String:
	return "" if lines.is_empty() else "\n".join(lines) + "\n"


func _fail(result: RefCounted, message: String, code := 1) -> void:
	result.stderr += message + "\n"
	result.exit_code = code


## Lee los archivos indicados (o la entrada estándar si no hay ninguno).
## Devuelve [{name, text}]; los errores se acumulan en result.
func _read_inputs(session: RefCounted, command: String, files: Array, stdin: String, result: RefCounted) -> Array:
	if files.is_empty():
		return [{"name": "-", "text": stdin}]
	var inputs: Array = []
	var fs = session.host.fs
	for file_arg: String in files:
		var path := _abs(session, file_arg)
		if not fs.exists(path):
			_fail(result, "%s: %s: No such file or directory" % [command, file_arg])
		elif fs.is_dir(path):
			_fail(result, "%s: %s: Is a directory" % [command, file_arg])
		elif not fs.check_access(path, session.user, "r"):
			_fail(result, "%s: %s: Permission denied" % [command, file_arg])
		else:
			inputs.append({"name": file_arg, "text": fs.read_file(path)})
	return inputs


# --- Navegación -----------------------------------------------------------------

func _cd(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if args.size() > 1:
		return CommandResult.error("bash: cd: too many arguments")
	var shown: String = args[0] if not args.is_empty() else session.user["home"]
	var target := _abs(session, shown)
	var fs = session.host.fs
	if not fs.exists(target):
		return CommandResult.error("bash: cd: %s: No such file or directory" % shown)
	if not fs.is_dir(target):
		return CommandResult.error("bash: cd: %s: Not a directory" % shown)
	if not fs.check_access(target, session.user, "x"):
		return CommandResult.error("bash: cd: %s: Permission denied" % shown)
	session.cwd = target
	return CommandResult.ok()


func _ls(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "laA1")
	if parsed["error"] != "":
		return CommandResult.error("ls: " + parsed["error"], 2)
	var long_format: bool = parsed["flags"].has("l")
	var show_dots: bool = parsed["flags"].has("a")
	var show_hidden: bool = show_dots or parsed["flags"].has("A")
	var targets: Array = parsed["rest"] if not parsed["rest"].is_empty() else ["."]
	var fs = session.host.fs
	var result := CommandResult.new()

	var file_targets: Array = []
	var dir_targets: Array = []
	for target: String in targets:
		var path := _abs(session, target)
		if not fs.exists(path):
			_fail(result, "ls: cannot access '%s': No such file or directory" % target, 2)
		elif fs.is_dir(path):
			dir_targets.append(target)
		else:
			file_targets.append(target)

	var blocks: Array[String] = []
	if not file_targets.is_empty():
		var entries: Array = []
		for target: String in file_targets:
			entries.append({"label": target, "path": _abs(session, target)})
		blocks.append(_format_entries(fs, entries, long_format, false))

	for target: String in dir_targets:
		var dir_path := _abs(session, target)
		if not fs.check_access(dir_path, session.user, "r"):
			_fail(result, "ls: cannot open directory '%s': Permission denied" % target, 2)
			continue
		var names: Array = []
		if show_dots:
			names.append(".")
			names.append("..")
		for name in fs.list_dir(dir_path):
			if show_hidden or not name.begins_with("."):
				names.append(name)
		var entries: Array = []
		for name: String in names:
			var entry_path := dir_path if name == "." else (dir_path.get_base_dir() if name == ".." else dir_path.path_join(name))
			entries.append({"label": name, "path": entry_path})
		var body := _format_entries(fs, entries, long_format, true)
		if targets.size() > 1:
			body = "%s:\n%s" % [target, body]
		blocks.append(body)

	result.stdout = "\n".join(blocks)
	return result


func _format_entries(fs: RefCounted, entries: Array, long_format: bool, with_total: bool) -> String:
	if not long_format:
		var names: Array = []
		for entry: Dictionary in entries:
			names.append(entry["label"])
		return _join(names)

	var owner_width := 0
	var group_width := 0
	var size_width := 0
	var total_blocks := 0
	for entry: Dictionary in entries:
		var info: Dictionary = fs.get_node_info(entry["path"])
		owner_width = maxi(owner_width, str(info["owner"]).length())
		group_width = maxi(group_width, str(info["group"]).length())
		size_width = maxi(size_width, str(fs.size_of(entry["path"])).length())
		total_blocks += maxi(4, int(ceil(fs.size_of(entry["path"]) / 4096.0)) * 4)

	var lines: Array[String] = []
	if with_total:
		lines.append("total %d" % total_blocks)
	for entry: Dictionary in entries:
		var info: Dictionary = fs.get_node_info(entry["path"])
		var links := 2 if info["type"] == "dir" else 1
		lines.append("%s %d %s %s %s %s %s" % [
			fs.mode_string(entry["path"]), links,
			str(info["owner"]).rpad(owner_width), str(info["group"]).rpad(group_width),
			str(fs.size_of(entry["path"])).lpad(size_width), LISTING_DATE, entry["label"],
		])
	return _join(lines)


# --- Lectura de texto ---------------------------------------------------------------

func _cat(session: RefCounted, args: Array, stdin: String) -> RefCounted:
	var result := CommandResult.new()
	for input: Dictionary in _read_inputs(session, "cat", args, stdin, result):
		result.stdout += input["text"]
	return result


func _count_args(args: Array) -> Array:
	# Permite la forma antigua "-5" como atajo de "-n 5".
	var converted: Array = []
	for arg: String in args:
		if arg.length() > 1 and arg.begins_with("-") and arg.substr(1).is_valid_int():
			converted.append("-n")
			converted.append(arg.substr(1))
		else:
			converted.append(arg)
	return converted


func _head(session: RefCounted, args: Array, stdin: String) -> RefCounted:
	return _head_or_tail(session, args, stdin, "head", true)


func _tail(session: RefCounted, args: Array, stdin: String) -> RefCounted:
	return _head_or_tail(session, args, stdin, "tail", false)


func _head_or_tail(session: RefCounted, args: Array, stdin: String, command: String, from_start: bool) -> RefCounted:
	var parsed := ArgParser.parse(_count_args(args), "", "n")
	if parsed["error"] != "":
		return CommandResult.error("%s: %s" % [command, parsed["error"]], 1)
	var count_text: String = parsed["values"].get("n", "10")
	if not count_text.is_valid_int() or int(count_text) < 0:
		return CommandResult.error("%s: invalid number of lines: '%s'" % [command, count_text])
	var count := int(count_text)

	var result := CommandResult.new()
	var inputs := _read_inputs(session, command, parsed["rest"], stdin, result)
	for index in inputs.size():
		var lines := _lines(inputs[index]["text"])
		var chosen: Array = lines.slice(0, count) if from_start else lines.slice(maxi(0, lines.size() - count))
		if inputs.size() > 1:
			result.stdout += ("\n" if index > 0 else "") + "==> %s <==\n" % inputs[index]["name"]
		result.stdout += _join(chosen)
	return result


func _wc(session: RefCounted, args: Array, stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "lwc")
	if parsed["error"] != "":
		return CommandResult.error("wc: " + parsed["error"])
	var flags: Dictionary = parsed["flags"]
	if flags.is_empty():
		flags = {"l": true, "w": true, "c": true}

	var result := CommandResult.new()
	var rows: Array = []
	var totals := [0, 0, 0]
	var inputs := _read_inputs(session, "wc", parsed["rest"], stdin, result)
	for input: Dictionary in inputs:
		var text: String = input["text"]
		var counts := [text.count("\n"), _word_count(text), text.to_utf8_buffer().size()]
		for i in 3:
			totals[i] += counts[i]
		rows.append({"name": input["name"], "counts": counts})
	if inputs.size() > 1:
		rows.append({"name": "total", "counts": totals})

	var selected: Array[int] = []
	if flags.has("l"):
		selected.append(0)
	if flags.has("w"):
		selected.append(1)
	if flags.has("c"):
		selected.append(2)
	for row: Dictionary in rows:
		var cells: Array[String] = []
		for index in selected:
			cells.append(str(row["counts"][index]) if selected.size() == 1 else str(row["counts"][index]).lpad(7))
		var line := " ".join(cells)
		if row["name"] != "-":
			line += " " + row["name"]
		result.stdout += line + "\n"
	return result


func _word_count(text: String) -> int:
	var count := 0
	for chunk in text.split(" ", false):
		for part in chunk.split("\n", false):
			if part.strip_edges() != "":
				count += 1
	return count


func _sort(session: RefCounted, args: Array, stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "run")
	if parsed["error"] != "":
		return CommandResult.error("sort: " + parsed["error"], 2)
	var numeric: bool = parsed["flags"].has("n")
	var result := CommandResult.new()
	var lines: Array = []
	for input: Dictionary in _read_inputs(session, "sort", parsed["rest"], stdin, result):
		lines.append_array(_lines(input["text"]))
	if numeric:
		lines.sort_custom(func(a: String, b: String) -> bool: return float(a.split(" ")[0]) < float(b.split(" ")[0]))
	else:
		lines.sort()
	if parsed["flags"].has("r"):
		lines.reverse()
	if parsed["flags"].has("u"):
		var unique: Array = []
		for line in lines:
			if unique.is_empty() or unique[-1] != line:
				unique.append(line)
		lines = unique
	result.stdout = _join(lines)
	return result


func _uniq(session: RefCounted, args: Array, stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "c")
	if parsed["error"] != "":
		return CommandResult.error("uniq: " + parsed["error"])
	var result := CommandResult.new()
	var lines: Array = []
	for input: Dictionary in _read_inputs(session, "uniq", parsed["rest"], stdin, result):
		lines.append_array(_lines(input["text"]))
	var output: Array[String] = []
	var index := 0
	while index < lines.size():
		var run_length := 1
		while index + run_length < lines.size() and lines[index + run_length] == lines[index]:
			run_length += 1
		output.append(("%7d %s" % [run_length, lines[index]]) if parsed["flags"].has("c") else lines[index])
		index += run_length
	result.stdout = _join(output)
	return result


# --- Búsqueda ----------------------------------------------------------------------

func _grep(session: RefCounted, args: Array, stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "invcrEe")
	if parsed["error"] != "":
		return CommandResult.error("grep: " + parsed["error"], 2)
	if parsed["rest"].is_empty():
		return CommandResult.error("Usage: grep [OPTION]... PATTERNS [FILE]...", 2)
	var flags: Dictionary = parsed["flags"]
	var pattern: String = parsed["rest"][0]
	var files: Array = parsed["rest"].slice(1)

	var regex := RegEx.create_from_string(("(?i)" if flags.has("i") else "") + pattern)
	if regex == null or not regex.is_valid():
		return CommandResult.error("grep: Invalid regular expression", 2)

	var fs = session.host.fs
	var result := CommandResult.new()
	var sources: Array = []  # [{label, text}]
	if files.is_empty():
		if flags.has("r"):
			files = ["."]
		else:
			sources.append({"label": "(standard input)", "text": stdin})
	for file_arg: String in files:
		var path := _abs(session, file_arg)
		if not fs.exists(path):
			_fail(result, "grep: %s: No such file or directory" % file_arg, 2)
		elif fs.is_dir(path):
			if flags.has("r"):
				_collect_files(session, path, file_arg, sources, result)
			else:
				_fail(result, "grep: %s: Is a directory" % file_arg, 2)
		elif not fs.check_access(path, session.user, "r"):
			_fail(result, "grep: %s: Permission denied" % file_arg, 2)
		else:
			sources.append({"label": file_arg, "text": fs.read_file(path)})

	var show_name: bool = sources.size() > 1 or flags.has("r")
	var any_match := false
	for source: Dictionary in sources:
		var matched := 0
		var lines := _lines(source["text"])
		for number in lines.size():
			var hit := regex.search(lines[number]) != null
			if hit == flags.has("v"):
				continue
			matched += 1
			any_match = true
			if flags.has("c"):
				continue
			var prefix := ("%s:" % source["label"]) if show_name else ""
			if flags.has("n"):
				prefix += "%d:" % (number + 1)
			result.stdout += prefix + lines[number] + "\n"
		if flags.has("c"):
			result.stdout += (("%s:" % source["label"]) if show_name else "") + "%d\n" % matched

	if result.exit_code == 0 and not any_match:
		result.exit_code = 1
	return result


## Reúne los archivos legibles bajo un directorio (para grep -r).
func _collect_files(session: RefCounted, dir_path: String, shown: String, sources: Array, result: RefCounted) -> void:
	var fs = session.host.fs
	if not fs.check_access(dir_path, session.user, "r"):
		_fail(result, "grep: %s: Permission denied" % shown, 2)
		return
	for name in fs.list_dir(dir_path):
		var child := dir_path.path_join(name)
		var child_shown: String = shown.trim_suffix("/") + "/" + name
		if fs.is_dir(child):
			_collect_files(session, child, child_shown, sources, result)
		elif fs.check_access(child, session.user, "r"):
			sources.append({"label": child_shown, "text": fs.read_file(child)})
		else:
			_fail(result, "grep: %s: Permission denied" % child_shown, 2)


func _find(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var starts: Array = []
	var name_pattern := ""
	var type_filter := ""
	var index := 0
	while index < args.size() and not str(args[index]).begins_with("-"):
		starts.append(args[index])
		index += 1
	while index < args.size():
		var option: String = args[index]
		if option == "-name" or option == "-type":
			if index + 1 >= args.size():
				return CommandResult.error("find: missing argument to `%s'" % option)
			if option == "-name":
				name_pattern = args[index + 1]
			else:
				type_filter = args[index + 1]
				if not type_filter in ["f", "d"]:
					return CommandResult.error("find: Unknown argument to -type: %s" % type_filter)
			index += 2
		else:
			return CommandResult.error("find: unknown predicate `%s'" % option)
	if starts.is_empty():
		starts = ["."]

	var name_regex: RegEx = null
	if name_pattern != "":
		name_regex = RegEx.create_from_string("^" + _glob_to_regex(name_pattern) + "$")

	var fs = session.host.fs
	var result := CommandResult.new()
	for start: String in starts:
		var path := _abs(session, start)
		if not fs.exists(path):
			_fail(result, "find: ‘%s’: No such file or directory" % start)
			continue
		_find_walk(session, path, start, name_regex, type_filter, result)
	return result


func _find_walk(session: RefCounted, path: String, shown: String, name_regex: RegEx, type_filter: String, result: RefCounted) -> void:
	var fs = session.host.fs
	var is_dir: bool = fs.is_dir(path)
	var type_ok := type_filter == "" or (type_filter == "d") == is_dir
	var name_ok := name_regex == null or name_regex.search(path.get_file() if path != "/" else "/") != null
	if type_ok and name_ok:
		result.stdout += shown + "\n"
	if not is_dir:
		return
	if not fs.check_access(path, session.user, "r"):
		_fail(result, "find: ‘%s’: Permission denied" % shown)
		return
	for name in fs.list_dir(path):
		_find_walk(session, path.path_join(name), shown.trim_suffix("/") + "/" + name, name_regex, type_filter, result)


func _glob_to_regex(glob: String) -> String:
	var regex := ""
	for letter in glob:
		match letter:
			"*":
				regex += ".*"
			"?":
				regex += "."
			".", "+", "(", ")", "[", "]", "{", "}", "^", "$", "|", "\\":
				regex += "\\" + letter
			_:
				regex += letter
	return regex


# --- Permisos e identidad ----------------------------------------------------------------

func _chmod(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if args.size() < 2:
		return CommandResult.error("chmod: missing operand")
	var spec: String = args[0]
	var fs = session.host.fs
	var result := CommandResult.new()
	for file_arg: String in args.slice(1):
		var path := _abs(session, file_arg)
		if not fs.exists(path):
			_fail(result, "chmod: cannot access '%s': No such file or directory" % file_arg)
			continue
		var info: Dictionary = fs.get_node_info(path)
		if int(session.user["uid"]) != 0 and info["owner"] != session.user["name"]:
			_fail(result, "chmod: changing permissions of '%s': Operation not permitted" % file_arg)
			continue
		var new_mode := _apply_mode_spec(str(info["mode"]), spec)
		if new_mode == "":
			return CommandResult.error("chmod: invalid mode: ‘%s’" % spec)
		fs.set_mode(path, new_mode)
	return result


## Calcula el nuevo modo octal a partir de "755" o de formas simbólicas como "u+x,go-w".
## Devuelve "" si la especificación no es válida.
func _apply_mode_spec(current: String, spec: String) -> String:
	if RegEx.create_from_string("^[0-7]{3,4}$").search(spec) != null:
		return spec.substr(spec.length() - 3)
	var digits: Array = [int(current[0]), int(current[1]), int(current[2])]
	var symbolic := RegEx.create_from_string("^([ugoa]*)([+\\-=])([rwx]*)$")
	for clause in spec.split(","):
		var match_ := symbolic.search(clause)
		if match_ == null:
			return ""
		var who: String = match_.get_string(1)
		if who == "" or who.contains("a"):
			who = "ugo"
		var bits := 0
		for permission in match_.get_string(3):
			bits |= {"r": 4, "w": 2, "x": 1}[permission]
		for letter in who:
			var slot: int = "ugo".find(letter)
			match match_.get_string(2):
				"+":
					digits[slot] = digits[slot] | bits
				"-":
					digits[slot] = digits[slot] & ~bits
				"=":
					digits[slot] = bits
	return "%d%d%d" % digits


func _whoami(session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	return CommandResult.ok(session.user["name"] + "\n")


func _id(session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	var uid: int = session.user["uid"]
	var groups: Array[String] = []
	for group_name in session.user["groups"]:
		groups.append("%d(%s)" % [uid, group_name])
	return CommandResult.ok("uid=%d(%s) gid=%d(%s) groups=%s\n" % [
		uid, session.user["name"], uid, session.user["name"], ",".join(groups),
	])


func _hostname(session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	return CommandResult.ok(session.host.hostname + "\n")


func _history(session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	var lines: Array[String] = []
	for index in session.history.size():
		lines.append("%5d  %s" % [index + 1, session.history[index]])
	return CommandResult.ok(_join(lines))
