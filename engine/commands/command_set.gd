extends RefCounted
## Punto único para construir el registro con todos los comandos del laboratorio.
## Cuando se añada una herramienta nueva (nmap, curl...), se registra aquí.

const CommandRegistry := preload("res://engine/shell/command_registry.gd")
const BasicCommands := preload("res://engine/commands/basic_commands.gd")
const FileCommands := preload("res://engine/commands/file_commands.gd")


static func create_registry() -> RefCounted:
	var registry := CommandRegistry.new()
	BasicCommands.new().register_all(registry)
	FileCommands.new().register_all(registry)
	return registry
