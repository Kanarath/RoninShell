extends RefCounted
## Comandos básicos para comprobar el intérprete de punta a punta: echo, pwd y help.
## Los comandos de archivos (ls, cd, cat...) llegan en el paso 4.

const CommandResult := preload("res://engine/shell/command_result.gd")


func register_all(registry: RefCounted) -> void:
	registry.register("echo", "Escribe texto en la salida", _echo)
	registry.register("pwd", "Muestra el directorio actual", _pwd)
	registry.register("help", "Lista los comandos disponibles", _help)


func _echo(_session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var newline := true
	if not args.is_empty() and args[0] == "-n":
		newline = false
		args = args.slice(1)
	var text := " ".join(args)
	return CommandResult.ok(text + ("\n" if newline else ""))


func _pwd(session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	return CommandResult.ok(session.cwd + "\n")


func _help(session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	var lines: Array[String] = ["Comandos disponibles:"]
	for command_name in session.registry.names():
		lines.append("  %-10s %s" % [command_name, session.registry.description_of(command_name)])
	return CommandResult.ok("\n".join(lines) + "\n")
