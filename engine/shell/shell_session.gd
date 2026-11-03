extends RefCounted
## La sesión de shell del jugador: dónde está (host, usuario, directorio), qué ha
## escrito (historial) y cómo ejecuta una línea.
##
## Ejecutar una línea = tokenizar -> parsear -> ejecutar cada comando de la tubería
## contra el estado del laboratorio. NADA de lo que escribe el jugador llega al
## sistema operativo real: los comandos solo existen si están en el registro.

const Tokenizer := preload("res://engine/shell/tokenizer.gd")
const Parser := preload("res://engine/shell/parser.gd")
const ListParser := preload("res://engine/shell/list_parser.gd")
const Arithmetic := preload("res://engine/shell/arithmetic.gd")
const Glob := preload("res://engine/shell/glob.gd")
const CommandResult := preload("res://engine/shell/command_result.gd")
const Vfs := preload("res://engine/vfs.gd")
const CommandDocs := preload("res://engine/commands/command_docs.gd")

const HISTORY_LIMIT := 500
const MAX_LOOP_ITERATIONS := 1000
const MAX_SUBSTITUTION_DEPTH := 4
const MAX_CALL_DEPTH := 20             # funciones dentro de funciones (corta la recursión infinita)
const MAX_COMMANDS_PER_LINE := 5000   # tope de seguridad: ningún bucle puede colgar el juego

var world: RefCounted
var registry: RefCounted
var host: RefCounted
var user: Dictionary = {"name": "root", "uid": 0, "home": "/", "groups": ["root"]}
var cwd: String = "/"
var history: Array[String] = []
var last_exit_code: int = 0
## Registro de lo que el jugador ha OBSERVADO en el laboratorio (archivo leído, host
## descubierto, puerto visto...). Las misiones se comprueban sobre estos hechos, no sobre
## el comando exacto escrito: cat, grep o head valen igual para "leer un archivo".
var events: Array[Dictionary] = []
## Cuaderno de hallazgos del jugador: [{type, text}] con type = indicio, hipotesis, confirmado o falso-positivo.
var findings: Array[Dictionary] = []
## Seguimiento de misiones (opcional): tras cada comando revisa si se cumplió algún objetivo.
var tracker: RefCounted = null


## Variables del shell (HOME, USER... y las que cree el jugador) y cuáles están exportadas.
var _vars: Dictionary = {}
var _exported: Dictionary = {}
var _pending_stderr := ""   # errores de $( ) que salen por pantalla junto al resto
var _subst_depth := 0
var _budget := 0           # comandos que aún puede ejecutar la línea en curso
var _aborted := false      # se agotó el presupuesto: se corta todo lo que quede
var _loop_depth := 0       # bucles anidados en ejecución (break/continue solo valen dentro)
var _loop_signal := ""     # "break" o "continue" pendiente de que lo recoja el bucle
var _functions: Dictionary = {}   # funciones definidas por el jugador: nombre -> elementos del cuerpo
var _positional: Array = []       # argumentos de la función en curso ($1, $2...)
var _call_depth := 0
var _return_pending := false      # un return espera a que la función termine


## En modo libre lo que haces se registra marcado como "free": se ve en el mapa, pero no cuenta
## para ningún objetivo ni da XP (ver ObjectiveCheck).
var free_mode: bool = false


func record(event_type: String, data := {}) -> void:
	var event: Dictionary = data.duplicate()
	event["type"] = event_type
	event["order"] = events.size()
	if free_mode:
		event["free"] = true
	events.append(event)


func _init(lab_world: RefCounted, command_registry: RefCounted) -> void:
	world = lab_world
	registry = command_registry
	host = world.player_host()
	if not host.users.is_empty():
		user = host.users[0]
	cwd = user["home"] if host.fs.is_dir(user["home"]) else "/"
	_vars = {
		"HOME": user["home"], "USER": user["name"], "LOGNAME": user["name"], "SHELL": "/bin/bash",
		"HOSTNAME": host.hostname, "PATH": "/usr/local/bin:/usr/bin:/bin", "PWD": cwd,
	}
	for exported_name: String in ["HOME", "USER", "LOGNAME", "SHELL", "PATH", "PWD"]:
		_exported[exported_name] = true


## Texto del prompt, p. ej. "ronin@ronin-box:~$ ".
func prompt() -> String:
	var home: String = user["home"]
	var shown := cwd
	if cwd == home:
		shown = "~"
	elif home != "/" and cwd.begins_with(home + "/"):
		shown = "~" + cwd.trim_prefix(home)
	return "%s@%s:%s$ " % [user["name"], host.hostname, shown]


## Ejecuta una línea escrita por el jugador y devuelve el resultado final.
func run(line: String) -> RefCounted:
	if line.strip_edges() != "":
		history.append(line)
		if history.size() > HISTORY_LIMIT:
			history.pop_front()

	# Bash lee la línea entera antes de ejecutar nada: un error de sintaxis no ejecuta ni la primera parte.
	var split := ListParser.split(line)
	if split["error"] != "":
		return _syntax_error(split["error"])
	var built := ListParser.build(split["units"])
	if built["error"] != "":
		return _syntax_error(built["error"])
	if built["items"].is_empty():
		return CommandResult.ok()  # línea vacía o solo un comentario: no cambia el código de salida anterior

	_vars["PWD"] = cwd
	var out := {"stdout": "", "stderr": "", "notices": []}
	_pending_stderr = ""
	_budget = MAX_COMMANDS_PER_LINE
	_aborted = false
	_loop_depth = 0
	_loop_signal = ""
	_call_depth = 0
	_return_pending = false
	_positional = []
	_exec_items(built["items"], out)
	var final := CommandResult.new()
	final.stdout = out["stdout"]
	final.stderr = _pending_stderr + out["stderr"]
	final.exit_code = last_exit_code
	final.notices.append_array(out["notices"])
	if tracker != null:
		final.notices.append_array(tracker.after_command(self))
	return final


## Lo que usa el tokenizador para expandir $VAR, $? y ~.
func expand_var(name: String) -> String:
	match name:
		"?":
			return str(last_exit_code)
		"PWD":
			return cwd
		"#":
			return str(_positional.size())
		"@", "*":
			return " ".join(_positional)
		"0":
			return "bash"
	if name.is_valid_int():
		var index := int(name) - 1
		return str(_positional[index]) if index >= 0 and index < _positional.size() else ""
	return str(_vars.get(name, ""))


## $( ... ): ejecuta el comando dentro del laboratorio y devuelve su salida sin el salto final.
func command_substitution(text: String) -> String:
	if _subst_depth >= MAX_SUBSTITUTION_DEPTH:
		_pending_stderr += "bash: demasiadas sustituciones $( ) anidadas\n"
		return ""
	var split := ListParser.split(text)
	var built := ListParser.build(split["units"]) if split["error"] == "" else split
	var message: String = split["error"] if split["error"] != "" else built["error"]
	if message != "":
		_pending_stderr += "bash: %s\n" % message
		return ""
	_subst_depth += 1
	var inner := {"stdout": "", "stderr": "", "notices": []}
	_exec_items(built["items"], inner)
	_subst_depth -= 1
	_pending_stderr += inner["stderr"]   # los errores del interior se ven, como en bash
	return inner["stdout"].rstrip("\n")


## $(( ... )): solo números, variables y + - * / % ( ). Cualquier otra cosa se rechaza antes de evaluar.
func arithmetic(expression: String) -> String:
	var cleaned := ""
	var i := 0
	while i < expression.length():
		var c := expression[i]
		if c == "$":
			i += 1
		elif Tokenizer.is_valid_name(c):
			var j := i
			while j < expression.length() and (Tokenizer.is_valid_name(expression[j]) or expression[j].is_valid_int()):
				j += 1
			var value := expand_var(expression.substr(i, j - i))
			cleaned += str(int(value)) if value.is_valid_int() else "0"
			i = j
		elif c in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "+", "-", "*", "/", "%", "(", ")", " ", "\t"]:
			cleaned += c
			i += 1
		else:
			_pending_stderr += "bash: %s: error de sintaxis en la expresión aritmética (solo + - * / % y paréntesis)\n" % expression.strip_edges()
			return ""
	var result := Arithmetic.evaluate(cleaned)
	if not result["ok"]:
		_pending_stderr += "bash: %s: %s\n" % [expression.strip_edges(), result["error"]]
		return ""
	return str(result["value"])


func set_var(name: String, value: String) -> void:
	_vars[name] = value
	record("var_set", {"name": name})


func unset_var(name: String) -> void:
	_vars.erase(name)
	_exported.erase(name)


func export_var(name: String) -> void:
	_exported[name] = true


## Variables exportadas (las que muestra `env`), ordenadas por nombre.
func exported_vars() -> Dictionary:
	var result := {}
	var names: Array = _exported.keys()
	names.sort()
	for name: String in names:
		result[name] = expand_var(name)
	return result


## Ejecuta una lista de elementos respetando ; && || (el estado de salida decide qué corre).
func _exec_items(items: Array, out: Dictionary) -> void:
	for item: Dictionary in items:
		var op: String = item["op"]
		if op == "&&" and last_exit_code != 0:
			record("list_op", {"op": op, "ran": false})
			continue
		if op == "||" and last_exit_code == 0:
			record("list_op", {"op": op, "ran": false})
			continue
		if op != "" and op != ";":
			record("list_op", {"op": op, "ran": true})
		match item["kind"]:
			"for":
				_run_for(item, out)
			"while":
				_run_while(item, out)
			"if":
				_run_if(item, out)
			"case":
				_run_case(item, out)
			"funcdef":
				_functions[item["name"]] = item["body"]
				last_exit_code = 0
				record("function_defined", {"name": item["name"]})
			_:
				_run_simple(item["text"], out)
		if _aborted or _loop_signal != "" or _return_pending:
			return


## Un comando suelto: break/continue/return (solo valen donde toca), una llamada a función o una tubería normal.
func _run_simple(text: String, out: Dictionary) -> void:
	var word := text.strip_edges()
	var name := word.get_slice(" ", 0)
	if _loop_depth > 0 and (word == "break" or word == "continue"):
		_loop_signal = word
		last_exit_code = 0
		record("loop_control", {"kind": word})
		return
	if _call_depth > 0 and name == "return":
		var code := word.substr(6).strip_edges()
		last_exit_code = clampi(int(code), 0, 255) if code.is_valid_int() else last_exit_code
		_return_pending = true
		return
	if _functions.has(name):
		var tokenized := Tokenizer.tokenize(text, self)
		if tokenized["error"] == "":
			var args: Array = []
			var plain := true
			for token: Dictionary in tokenized["tokens"]:
				if token["type"] == "word":
					args.append(token["text"])
				else:
					plain = false
			if plain:
				_call_function(name, args.slice(1), out)
				return
	_run_pipeline(text, out)


## Llama a una función del jugador con sus argumentos ($1, $2, $#, $@). Con tope de profundidad y de comandos.
func _call_function(name: String, args: Array, out: Dictionary) -> void:
	if _call_depth >= MAX_CALL_DEPTH:
		_fail_into(out, "%s: demasiadas llamadas anidadas (máximo %d): parece una recursión infinita" % [name, MAX_CALL_DEPTH])
		return
	_budget -= 1
	if _budget < 0:
		if not _aborted:
			_fail_into(out, "demasiados comandos en una sola línea: se detiene (límite de seguridad del simulador)")
		_aborted = true
		return
	var saved_args := _positional
	_positional = args
	_call_depth += 1
	last_exit_code = 0
	_exec_items(_functions[name], out)
	_call_depth -= 1
	_return_pending = false
	_positional = saved_args
	record("function_called", {"name": name, "args": args.size()})


## case PALABRA in patrón) ...;; esac: ejecuta la primera rama cuyo patrón encaje (* y ? como en las rutas).
func _run_case(item: Dictionary, out: Dictionary) -> void:
	var word := _expand_word(item["word"], out)
	var matched := ""
	var found := false
	for clause: Dictionary in item["clauses"]:
		for pattern: String in clause["patterns"]:
			if Glob.matches(_expand_word(pattern, out), word):
				matched = pattern
				found = true
				break
		if found:
			last_exit_code = 0
			_exec_items(clause["body"], out)
			break
	if not found:
		last_exit_code = 0
	record("case_ran", {"pattern": matched, "matched": found})


## Expande variables y comillas de una palabra suelta (la palabra de case y sus patrones).
func _expand_word(text: String, out: Dictionary) -> String:
	var tokenized := Tokenizer.tokenize(text, self)
	if tokenized["error"] != "":
		_fail_into(out, tokenized["error"])
		return ""
	var parts: Array = []
	for token: Dictionary in tokenized["tokens"]:
		if token["type"] == "word":
			parts.append(token["text"])
	return " ".join(parts)


## if COND; then A; [else B;] fi: la condición es un comando y cuenta su código de salida.
func _run_if(item: Dictionary, out: Dictionary) -> void:
	_exec_items(item["cond"], out)
	if _aborted:
		return
	var branch := "then"
	if last_exit_code == 0:
		_exec_items(item["then"], out)
	elif not item["else"].is_empty():
		branch = "else"
		_exec_items(item["else"], out)
	else:
		branch = "none"
		last_exit_code = 0   # un if sin rama que se cumpla sale con éxito, como en bash
	record("if_ran", {"branch": branch})


## while COND; do ...; done (until es lo mismo con la condición invertida). Con tope de vueltas.
func _run_while(item: Dictionary, out: Dictionary) -> void:
	var rounds := 0
	_loop_depth += 1
	while not _aborted:
		_exec_items(item["cond"], out)
		if _aborted or (last_exit_code == 0) == item["negate"]:
			break
		if rounds >= MAX_LOOP_ITERATIONS:
			_fail_into(out, "bucle detenido tras %d vueltas: parece infinito (límite de seguridad del simulador)" % MAX_LOOP_ITERATIONS)
			break
		rounds += 1
		_exec_items(item["body"], out)
		var signal_seen := _loop_signal
		_loop_signal = ""
		if signal_seen == "break" or _return_pending:
			break
	_loop_depth -= 1
	record("loop_ran", {"variable": "while", "count": rounds})


func _run_for(item: Dictionary, out: Dictionary) -> void:
	var tokenized := Tokenizer.tokenize(item["header"], self)
	if tokenized["error"] != "":
		_fail_into(out, tokenized["error"])
		return
	var words: Array = []
	for token: Dictionary in tokenized["tokens"]:
		if token["type"] != "word":
			_fail_into(out, "syntax error near unexpected token `%s'" % ("|" if token["type"] == "pipe" else ">"))
			return
		var matches: Array = []
		if token.get("glob", false) and words.size() >= 3:
			matches = Glob.expand(host.fs, user, cwd, token["text"])
		if matches.is_empty():
			words.append(token["text"])
		else:
			words.append_array(matches)
			record("glob_expanded", {"pattern": token["text"], "count": matches.size()})
	var variable: String = words[1]
	var values: Array = words.slice(3)
	if values.size() > MAX_LOOP_ITERATIONS:
		_fail_into(out, "for: demasiados elementos (máximo %d)" % MAX_LOOP_ITERATIONS)
		return
	last_exit_code = 0
	_loop_depth += 1
	for value: String in values:
		if _aborted:
			break
		_vars[variable] = value
		_exec_items(item["body"], out)
		var signal_seen := _loop_signal
		_loop_signal = ""
		if signal_seen == "break" or _return_pending:
			break
	_loop_depth -= 1
	record("loop_ran", {"variable": variable, "count": values.size()})


func _fail_into(out: Dictionary, message: String) -> void:
	out["stderr"] += "bash: %s\n" % message
	last_exit_code = 2


## Una tubería: tokeniza (ahora, con las variables al día), parsea y ejecuta sus comandos.
func _run_pipeline(text: String, out: Dictionary) -> void:
	_budget -= 1
	if _budget < 0:
		if not _aborted:
			_fail_into(out, "demasiados comandos en una sola línea: se detiene (límite de seguridad del simulador)")
		_aborted = true
		return
	var tokenized := Tokenizer.tokenize(text, self)
	if tokenized["error"] != "":
		_fail_into(out, tokenized["error"])
		return
	var parsed := Parser.parse(tokenized["tokens"])
	if parsed["error"] != "":
		_fail_into(out, parsed["error"])
		return
	if parsed["commands"].is_empty():
		return
	if _is_assignment_line(text):
		_run_assignments(parsed["commands"][0], out)
		return

	var stdin := ""
	var names: Array[String] = []
	for command: Dictionary in parsed["commands"]:
		var argv := _expand_globs(command)
		names.append(argv[0])
		var result := _run_command(argv, stdin)
		out["stderr"] += result.stderr
		var output: String = result.stdout
		if command["redirect"] != null:
			var redirect_error := _apply_redirect(command["redirect"], output)
			if redirect_error != "":
				out["stderr"] += redirect_error
				result.exit_code = 1
			output = ""  # lo redirigido no sigue por la tubería ni se muestra
		stdin = output
		last_exit_code = result.exit_code
		out["notices"].append_array(result.notices)
	out["stdout"] += stdin
	if names.size() > 1:
		record("pipeline", {"cmds": "|".join(names)})


## Sustituye las palabras con * o ? por los archivos que cumplen el patrón (ordenados). Si no hay
## ninguno se deja el patrón tal cual, como bash. El nombre del comando no se expande.
func _expand_globs(command: Dictionary) -> Array:
	if not command.has("globs"):
		return command["argv"]
	var argv: Array = []
	var marks: Array = command["globs"]
	for i in command["argv"].size():
		var word: String = command["argv"][i]
		if i > 0 and marks[i]:
			var matches := Glob.expand(host.fs, user, cwd, word)
			if not matches.is_empty():
				argv.append_array(matches)
				record("glob_expanded", {"pattern": word, "count": matches.size()})
				continue
		argv.append(word)
	return argv


func _is_assignment_line(text: String) -> bool:
	var eq := text.find("=")
	return eq > 0 and Tokenizer.is_valid_name(text.substr(0, eq))


## NOMBRE=valor [NOMBRE2=valor2 ...] sin comando: solo asigna. (VAR=x comando no está soportado.)
func _run_assignments(command: Dictionary, out: Dictionary) -> void:
	for word: String in command["argv"]:
		var eq := word.find("=")
		if eq <= 0 or not Tokenizer.is_valid_name(word.substr(0, eq)):
			_fail_into(out, "%s: no se puede usar VAR=valor delante de un comando; asigna en una línea y ejecuta el comando después (o usa `;`)" % word)
			return
	for word: String in command["argv"]:
		var eq := word.find("=")
		set_var(word.substr(0, eq), word.substr(eq + 1))
	last_exit_code = 0


func _run_command(argv: Array, stdin: String) -> RefCounted:
	var command_name: String = argv[0]
	if not registry.has_command(command_name):
		return CommandResult.error("bash: %s: command not found" % command_name, 127)
	var args := argv.slice(1)
	# `--help` funciona en cualquier herramienta; `-h` solo donde en la realidad también es ayuda
	# (en otras, como ls, -h es una opción distinta y no debemos pisarla). echo lo escribe tal cual.
	if command_name != "echo" and CommandDocs.has(command_name):
		if "--help" in args or ("-h" in args and CommandDocs.short_h_is_help(command_name)):
			record("help_viewed", {"tool": command_name, "via": "help-flag"})
			return CommandResult.ok(CommandDocs.short_help(command_name))
	return registry.get_callable(command_name).call(self, args, stdin)


## Devuelve "" si todo fue bien, o el mensaje de error estilo bash.
func _apply_redirect(redirect: Dictionary, content: String) -> String:
	var path: String = redirect["path"]
	var absolute := Vfs.normalize(cwd, path)
	if host.fs.is_dir(absolute):
		return "bash: %s: Is a directory\n" % path  # bash lo dice antes de mirar permisos
	# Crear un archivo exige poder escribir en su directorio; sobrescribirlo, poder escribir en él.
	var target_for_check := absolute if host.fs.exists(absolute) else absolute.get_base_dir()
	if host.fs.exists(target_for_check) and not host.fs.check_access(target_for_check, user, "w"):
		return "bash: %s: Permission denied\n" % path
	var outcome: int = host.fs.write_file(absolute, content, redirect["mode"] == "append", user["name"], user["name"])
	match outcome:
		Vfs.WriteResult.NO_PARENT:
			return "bash: %s: No such file or directory\n" % path
		Vfs.WriteResult.NOT_DIR_PARENT:
			return "bash: %s: Not a directory\n" % path
		Vfs.WriteResult.IS_DIR:
			return "bash: %s: Is a directory\n" % path
	record("file_written", {"path": absolute, "text": host.fs.read_file(absolute)})   # lo que queda en el archivo, para objetivos de configuración
	return ""


func _syntax_error(message: String) -> RefCounted:
	var result := CommandResult.error("bash: " + message, 2)
	last_exit_code = 2
	return result
