extends RefCounted
## Punto único para construir el registro con todos los comandos del laboratorio.
## Cuando se añada una herramienta nueva, se registra aquí.

const CommandRegistry := preload("res://engine/shell/command_registry.gd")
const BasicCommands := preload("res://engine/commands/basic_commands.gd")
const FileCommands := preload("res://engine/commands/file_commands.gd")
const NetworkCommands := preload("res://engine/commands/network_commands.gd")
const MissionCommands := preload("res://engine/commands/mission_commands.gd")


## Si se pasa un seguimiento de misiones, se añaden también las órdenes de juego.
static func create_registry(mission_tracker: RefCounted = null) -> RefCounted:
	var registry := CommandRegistry.new()
	BasicCommands.new().register_all(registry)
	FileCommands.new().register_all(registry)
	NetworkCommands.new().register_all(registry)
	if mission_tracker != null:
		MissionCommands.new(mission_tracker).register_all(registry)
	return registry
