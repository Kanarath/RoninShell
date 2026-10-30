extends RefCounted
## La sesión de shell del jugador: dónde está (host, usuario, directorio), qué ha
## escrito (historial) y cómo ejecuta una línea.
##
## Ejecutar una línea = tokenizar -> parsear -> ejecutar cada comando de la tubería
## contra el estado del laboratorio. NADA de lo que escribe el jugador llega al
## sistema operativo real: los comandos solo existen si están en el registro.

const Tokenizer := preload("res://engine/shell/tokenizer.gd")
const Parser := preload("res://engine/shell/parser.gd")
const CommandResult := preload("res://engine/shell/command_result.gd")
const Vfs := preload("res://engine/vfs.gd")

const HISTORY_LIMIT := 500

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
## Seguimiento de misiones (opcional): tras cada comando revisa si se cumplió algún objetivo.
var tracker: RefCounted = null


func record(event_type: String, data := {}) -> void:
	var event: Dictionary = data.duplicate()
	event["type"] = event_type
	event["order"] = events.size()
	events.append(event)


func _init(lab_world: RefCounted, command_registry: RefCounted) -> void:
	world = lab_world
	registry = command_registry
	host = world.player_host()
	if not host.users.is_empty():
		user = host.users[0]
	cwd = user["home"] if host.fs.is_dir(user["home"]) else "/"


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

	var tokenized := Tokenizer.tokenize(line)
	if tokenized["error"] != "":
		return _syntax_error(tokenized["error"])
	var parsed := Parser.parse(tokenized["tokens"])
	if parsed["error"] != "":
		return _syntax_error(parsed["error"])
	if parsed["commands"].is_empty():
		return CommandResult.ok()  # línea vacía: no cambia el código de salida anterior

	var final := CommandResult.new()
	var stdin := ""
	var errors := ""
	for command: Dictionary in parsed["commands"]:
		var result := _run_command(command["argv"], stdin)
		errors += result.stderr
		var output: String = result.stdout
		if command["redirect"] != null:
			var redirect_error := _apply_redirect(command["redirect"], output)
			if redirect_error != "":
				errors += redirect_error
				result.exit_code = 1
			output = ""  # lo redirigido no sigue por la tubería ni se muestra
		stdin = output
		final.exit_code = result.exit_code
		final.notices.append_array(result.notices)

	final.stdout = stdin
	final.stderr = errors
	last_exit_code = final.exit_code
	if tracker != null:
		final.notices.append_array(tracker.after_command(self))
	return final


func _run_command(argv: Array, stdin: String) -> RefCounted:
	var command_name: String = argv[0]
	if not registry.has_command(command_name):
		return CommandResult.error("bash: %s: command not found" % command_name, 127)
	var args := argv.slice(1)
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
	return ""


func _syntax_error(message: String) -> RefCounted:
	var result := CommandResult.error("bash: " + message, 2)
	last_exit_code = 2
	return result
