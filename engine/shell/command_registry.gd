extends RefCounted
## Catálogo de comandos que existen en el laboratorio.
##
## Un comando es un Callable con la forma:
##     func(session, args: Array, stdin: String) -> CommandResult
## donde "args" no incluye el nombre del comando. Si un nombre no está registrado,
## la sesión responde "command not found": este registro ES el límite de lo que
## el jugador puede ejecutar. No existe ninguna vía hacia el sistema real.

var _commands: Dictionary = {}  # nombre -> {"run": Callable, "description": String}
# Un Callable no mantiene vivo a su objeto: si el objeto que define el comando se libera,
# el comando queda apuntando a nada. Guardamos una referencia para evitarlo.
var _owners: Array = []


func register(command_name: String, description: String, run: Callable) -> void:
	var owner := run.get_object()
	if owner is RefCounted and not _owners.has(owner):
		_owners.append(owner)
	_commands[command_name] = {"run": run, "description": description}


func has_command(command_name: String) -> bool:
	return _commands.has(command_name)


func get_callable(command_name: String) -> Callable:
	return _commands[command_name]["run"]


func description_of(command_name: String) -> String:
	return _commands[command_name]["description"] if _commands.has(command_name) else ""


func names() -> Array[String]:
	var result: Array[String] = []
	for command_name: String in _commands:
		result.append(command_name)
	result.sort()
	return result
