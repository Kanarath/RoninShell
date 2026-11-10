extends RefCounted
## Más herramientas de texto: cut, tr y comm. Complementan a grep/sort/uniq para scripts de una línea
## sobre logs y listas (por ejemplo: `cut -d: -f1 /etc/passwd` o `sort a.txt b.txt | uniq -d`).
##
## Límites conocidos (a propósito): cut no admite -c (por caracteres, solo -f); tr no toca archivos,
## solo la entrada estándar, como el tr real; comm no comprueba que los archivos estén ordenados
## (como el comm real: si no lo están, el resultado no significa nada).

const CommandResult := preload("res://engine/shell/command_result.gd")
const Vfs := preload("res://engine/vfs.gd")
const ArgParser := preload("res://engine/commands/arg_parser.gd")


func register_all(registry: RefCounted) -> void:
	registry.register("cut", "Extrae columnas de cada línea (-d delimitador -f lista)", _cut)
	registry.register("tr", "Traduce o borra caracteres de la entrada (-d borra)", _tr)
	registry.register("comm", "Compara dos archivos YA ordenados, línea a línea (-1 -2 -3 los oculta)", _comm)


func _abs(session: RefCounted, path: String) -> String:
	return Vfs.normalize(session.cwd, path)


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
			session.record("permission_denied", {"path": path, "action": "read"})
		else:
			inputs.append({"name": file_arg, "text": fs.read_file(path)})
			session.record("file_read", {"path": path})
	return inputs


# --- cut --------------------------------------------------------------------

func _cut(session: RefCounted, args: Array, stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "", "df")
	if parsed["error"] != "":
		return CommandResult.error("cut: " + parsed["error"], 2)
	if not parsed["values"].has("f"):
		return CommandResult.error("cut: debes indicar los campos con -f (p. ej. -f 1,3 o -f 1-3)", 2)
	var delim: String = parsed["values"].get("d", "\t")
	if delim.length() != 1:
		return CommandResult.error("cut: el delimitador debe ser un solo carácter", 2)
	var fields := _parse_field_list(parsed["values"]["f"])
	if fields.is_empty():
		return CommandResult.error("cut: lista de campos inválida: '%s'" % parsed["values"]["f"], 2)
	var result := CommandResult.new()
	var out: Array[String] = []
	for input: Dictionary in _read_inputs(session, "cut", parsed["rest"], stdin, result):
		for line: String in _lines(input["text"]):
			if not delim in line:
				out.append(line)   # como el cut real sin -s: una línea sin el delimitador sale entera
				continue
			var parts := line.split(delim)
			var picked: Array[String] = []
			for index in fields:
				if index >= 1 and index <= parts.size():
					picked.append(parts[index - 1])
			out.append(delim.join(picked))
	result.stdout = _join(out)
	return result


## "1,3" -> [1,3]; "1-3" -> [1,2,3]; "3-" -> [3..64] (un tope razonable: no hay líneas con más columnas).
func _parse_field_list(spec: String) -> Array[int]:
	const MAX_FIELD := 64
	var seen := {}
	var fields: Array[int] = []
	for chunk: String in spec.split(","):
		if chunk.is_valid_int():
			seen[int(chunk)] = true
			continue
		var dash := chunk.find("-")
		if dash == -1:
			return []
		var from_text := chunk.substr(0, dash)
		var to_text := chunk.substr(dash + 1)
		if from_text == "" or not from_text.is_valid_int():
			return []
		var from_n := int(from_text)
		var to_n := int(to_text) if to_text.is_valid_int() else MAX_FIELD
		if to_n < from_n:
			return []
		for n in range(from_n, to_n + 1):
			seen[n] = true
	var numbers: Array = seen.keys()
	numbers.sort()
	for n: int in numbers:
		if n >= 1:
			fields.append(n)
	return fields


# --- tr ---------------------------------------------------------------------

func _tr(_session: RefCounted, args: Array, stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "d")
	if parsed["error"] != "":
		return CommandResult.error("tr: " + parsed["error"], 2)
	var operands: Array = parsed["rest"]
	var result := CommandResult.new()
	if parsed["flags"].has("d"):
		if operands.size() != 1:
			return CommandResult.error("tr: usa  tr -d CONJUNTO  (lee de la entrada estándar)", 2)
		var doomed := _expand_set(operands[0])
		var kept := ""
		for ch in stdin:
			if not doomed.contains(ch):
				kept += ch
		result.stdout = kept
		return result
	if operands.size() != 2:
		return CommandResult.error("tr: usa  tr CONJUNTO1 CONJUNTO2  (lee de la entrada estándar)", 2)
	var from_set := _expand_set(operands[0])
	var to_set := _expand_set(operands[1])
	if from_set == "" or to_set == "":
		return CommandResult.error("tr: los conjuntos no pueden estar vacíos", 2)
	var out := ""
	for ch in stdin:
		var index := from_set.find(ch)
		if index == -1:
			out += ch
		else:
			out += to_set[mini(index, to_set.length() - 1)]   # si CONJUNTO2 es más corto, repite su último carácter
	result.stdout = out
	return result


## "a-z" -> "abc...z"; varios trozos se concatenan: "a-zA-Z" -> minúsculas y luego mayúsculas.
func _expand_set(spec: String) -> String:
	var out := ""
	var i := 0
	while i < spec.length():
		if i + 2 < spec.length() and spec[i + 1] == "-":
			var from_code := spec.unicode_at(i)
			var to_code := spec.unicode_at(i + 2)
			if to_code >= from_code:
				for code in range(from_code, to_code + 1):
					out += char(code)
			i += 3
		else:
			out += spec[i]
			i += 1
	return out


# --- comm ---------------------------------------------------------------------

func _comm(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var parsed := ArgParser.parse(args, "123")
	if parsed["error"] != "":
		return CommandResult.error("comm: " + parsed["error"], 2)
	if parsed["rest"].size() != 2:
		return CommandResult.error("comm: usa  comm [-1] [-2] [-3] archivo1 archivo2  (los dos archivos ya ordenados)", 2)
	var fs = session.host.fs
	var texts: Array = []
	for file_arg: String in parsed["rest"]:
		var path := _abs(session, file_arg)
		if not fs.exists(path):
			return CommandResult.error("comm: %s: No such file or directory" % file_arg)
		if fs.is_dir(path):
			return CommandResult.error("comm: %s: Is a directory" % file_arg)
		if not fs.check_access(path, session.user, "r"):
			session.record("permission_denied", {"path": path, "action": "read"})
			return CommandResult.error("comm: %s: Permission denied" % file_arg)
		texts.append(fs.read_file(path))
		session.record("file_read", {"path": path})
	var left := _lines(texts[0])
	var right := _lines(texts[1])
	var show1: bool = not parsed["flags"].has("1")
	var show2: bool = not parsed["flags"].has("2")
	var show3: bool = not parsed["flags"].has("3")
	var out: Array[String] = []
	var i := 0
	var j := 0
	while i < left.size() and j < right.size():
		if left[i] == right[j]:
			if show3:
				out.append("\t\t%s" % left[i])
			i += 1
			j += 1
		elif left[i] < right[j]:
			if show1:
				out.append(left[i])
			i += 1
		else:
			if show2:
				out.append("\t%s" % right[j])
			j += 1
	while i < left.size():
		if show1:
			out.append(left[i])
		i += 1
	while j < right.size():
		if show2:
			out.append("\t%s" % right[j])
		j += 1
	session.record("files_compared", {"a": _abs(session, parsed["rest"][0]), "b": _abs(session, parsed["rest"][1]), "same": out.is_empty() and show3})
	var result := CommandResult.new()
	result.stdout = _join(out)
	return result
