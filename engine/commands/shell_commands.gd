extends RefCounted
## Utilidades del propio shell para scripts de una línea: variables (export, env, unset),
## códigos de salida (true, false, test) y secuencias (seq). Todo ocurre dentro del laboratorio.

const CommandResult := preload("res://engine/shell/command_result.gd")
const Tokenizer := preload("res://engine/shell/tokenizer.gd")
const Vfs := preload("res://engine/vfs.gd")

const MAX_SEQ := 1000


func register_all(registry: RefCounted) -> void:
	registry.register("true", "No hace nada y sale con éxito (código 0)", _true)
	registry.register("false", "No hace nada y sale con fallo (código 1)", _false)
	registry.register("export", "Marca variables para que las vea `env` (export NOMBRE=valor)", _export)
	registry.register("unset", "Borra una variable (unset NOMBRE)", _unset)
	registry.register("env", "Muestra las variables exportadas", _env)
	registry.register("seq", "Escribe una secuencia de números (seq 1 5)", _seq)
	registry.register("test", "Comprueba una condición y sale con 0 si es cierta (test -f archivo)", _test)


func _true(_session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	return CommandResult.ok()


func _false(_session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	return _exit(1)


func _export(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if args.is_empty():
		return _env(session, [], "")
	for arg: String in args:
		var eq := arg.find("=")
		var variable := arg if eq == -1 else arg.substr(0, eq)
		if not Tokenizer.is_valid_name(variable):
			return CommandResult.error("bash: export: `%s': not a valid identifier" % arg)
		if eq != -1:
			session.set_var(variable, arg.substr(eq + 1))
		session.export_var(variable)
	return CommandResult.ok()


func _unset(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	for arg: String in args:
		if not Tokenizer.is_valid_name(arg):
			return CommandResult.error("bash: unset: `%s': not a valid identifier" % arg)
		session.unset_var(arg)
	return CommandResult.ok()


func _env(session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	var text := ""
	var values: Dictionary = session.exported_vars()
	for variable: String in values:
		text += "%s=%s\n" % [variable, values[variable]]
	return CommandResult.ok(text)


func _seq(_session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if args.is_empty() or args.size() > 3:
		return CommandResult.error("seq: uso: seq ÚLTIMO | seq PRIMERO ÚLTIMO | seq PRIMERO PASO ÚLTIMO")
	for arg: String in args:
		if not arg.is_valid_int():
			return CommandResult.error("seq: invalid argument: '%s' (solo números enteros)" % arg)
	var first := 1
	var step := 1
	var last: int = int(args[-1])
	if args.size() == 2:
		first = int(args[0])
	elif args.size() == 3:
		first = int(args[0])
		step = int(args[1])
	if step == 0:
		return CommandResult.error("seq: invalid zero increment")
	var count: int = (last - first) / step + 1
	if count > MAX_SEQ:
		return CommandResult.error("seq: demasiados elementos (máximo %d)" % MAX_SEQ)
	var text := ""
	var value := first
	while (step > 0 and value <= last) or (step < 0 and value >= last):
		text += "%d\n" % value
		value += step
	return CommandResult.ok(text)


## test: solo lo imprescindible. El resultado va por el código de salida, sin escribir nada.
func _test(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var negate := false
	if not args.is_empty() and args[0] == "!":
		negate = true
		args = args.slice(1)
	var outcome := _evaluate(session, args)
	if outcome == -1:
		return CommandResult.error("bash: test: expresión no válida (admite -e -f -d -r -w -x -z -n, = != y -eq -ne -lt -le -gt -ge)", 2)
	var truth := outcome == 1
	if negate:
		truth = not truth
	return CommandResult.ok() if truth else _exit(1)


## 1 = cierta, 0 = falsa, -1 = expresión mal formada.
func _evaluate(session: RefCounted, args: Array) -> int:
	var fs = session.host.fs
	if args.size() == 1:
		return 1 if str(args[0]) != "" else 0
	if args.size() == 2:
		var target := Vfs.normalize(session.cwd, str(args[1]))
		match args[0]:
			"-z":
				return 1 if str(args[1]) == "" else 0
			"-n":
				return 1 if str(args[1]) != "" else 0
			"-e":
				return 1 if fs.exists(target) else 0
			"-f":
				return 1 if fs.is_file(target) else 0
			"-d":
				return 1 if fs.is_dir(target) else 0
			"-r":
				return 1 if fs.exists(target) and fs.check_access(target, session.user, "r") else 0
			"-w":
				return 1 if fs.exists(target) and fs.check_access(target, session.user, "w") else 0
			"-x":
				return 1 if fs.exists(target) and fs.check_access(target, session.user, "x") else 0
		return -1
	if args.size() == 3:
		var left := str(args[0])
		var right := str(args[2])
		match args[1]:
			"=", "==":
				return 1 if left == right else 0
			"!=":
				return 1 if left != right else 0
			"-eq", "-ne", "-lt", "-le", "-gt", "-ge":
				if not left.is_valid_int() or not right.is_valid_int():
					return -1
				var a := int(left)
				var b := int(right)
				match args[1]:
					"-eq":
						return 1 if a == b else 0
					"-ne":
						return 1 if a != b else 0
					"-lt":
						return 1 if a < b else 0
					"-le":
						return 1 if a <= b else 0
					"-gt":
						return 1 if a > b else 0
					_:
						return 1 if a >= b else 0
		return -1
	return -1


## Salida silenciosa con un código (false, test): el resultado va solo en el código de salida.
func _exit(code: int) -> RefCounted:
	var result := CommandResult.new()
	result.exit_code = code
	return result
