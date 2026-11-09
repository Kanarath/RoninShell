extends RefCounted
## Punto único para construir el registro con todos los comandos del laboratorio.
## Cuando se añada una herramienta nueva, se registra aquí.

const CommandRegistry := preload("res://engine/shell/command_registry.gd")
const BasicCommands := preload("res://engine/commands/basic_commands.gd")
const FileCommands := preload("res://engine/commands/file_commands.gd")
const ShellCommands := preload("res://engine/commands/shell_commands.gd")
const ManageCommands := preload("res://engine/commands/manage_commands.gd")
const VulnCommands := preload("res://engine/commands/vuln_commands.gd")
const NetworkCommands := preload("res://engine/commands/network_commands.gd")
const HelpCommands := preload("res://engine/commands/help_commands.gd")
const MissionCommands := preload("res://engine/commands/mission_commands.gd")
const LabCommands := preload("res://engine/commands/lab_commands.gd")


## Con un seguimiento de misiones se añaden las órdenes de juego; con un controlador de
## laboratorio, también modo, reiniciar y repaso.
static func create_registry(mission_tracker: RefCounted = null, lab_controller: RefCounted = null) -> RefCounted:
	var registry := CommandRegistry.new()
	BasicCommands.new().register_all(registry)
	FileCommands.new().register_all(registry)
	ShellCommands.new().register_all(registry)
	ManageCommands.new().register_all(registry)
	VulnCommands.new().register_all(registry)
	NetworkCommands.new().register_all(registry)
	HelpCommands.new().register_all(registry)
	if mission_tracker != null:
		MissionCommands.new(mission_tracker, lab_controller).register_all(registry)
	if lab_controller != null:
		LabCommands.new(lab_controller).register_all(registry)
	return registry
