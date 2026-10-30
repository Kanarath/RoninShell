extends RefCounted
## Comandos básicos para comprobar el intérprete de punta a punta: echo, pwd y help.
## Los comandos de archivos (ls, cd, cat...) llegan en el paso 4.

const CommandResult := preload("res://engine/shell/command_result.gd")


func register_all(registry: RefCounted) -> void:
	registry.register("echo", "Escribe texto en la salida", _echo)
	registry.register("pwd", "Muestra el directorio actual", _pwd)
	registry.register("help", "Lista los comandos disponibles", _help)
	registry.register("sudo", "Ejecuta algo como otro usuario (no estás autorizado)", _sudo)
	registry.register("su", "Cambia de usuario (necesita contraseña)", _su)


## ronin no figura en sudoers, igual que un usuario normal de un servidor real: la escalada
## de privilegios es un tema de misiones futuras, no un atajo para saltarse los permisos.
func _sudo(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if args.is_empty():
		return CommandResult.error("usage: sudo -h | -K | -k | -V", 1)
	session.record("privilege_attempt", {"tool": "sudo"})
	return CommandResult.error("%s is not in the sudoers file.  This incident will be reported." % session.user["name"], 1)


func _su(session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	session.record("privilege_attempt", {"tool": "su"})
	var result := CommandResult.error("su: Authentication failure", 1)
	result.stdout = "Password: \n"
	return result


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
