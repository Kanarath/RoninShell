extends RefCounted
## man y cheatsheet. (help vive en basic_commands y --help se resuelve en la sesión.)

const CommandResult := preload("res://engine/shell/command_result.gd")
const CommandDocs := preload("res://engine/commands/command_docs.gd")
const ConceptDocs := preload("res://engine/commands/concept_docs.gd")


func register_all(registry: RefCounted) -> void:
	registry.register("man", "Ficha completa de un comando (man nmap)", _man)
	registry.register("cheatsheet", "Chuleta de comandos útiles por tema", _cheatsheet)


func _man(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if args.is_empty():
		return CommandResult.error("What manual page do you want?\nFor example, try 'man man'.")
	var name: String = args[0]
	if ConceptDocs.has(name):
		session.record("help_viewed", {"tool": name, "via": "man"})
		return CommandResult.ok(ConceptDocs.page(name))
	if not CommandDocs.has(name):
		return CommandResult.error("No manual entry for %s. Conceptos disponibles: %s" % [name, ", ".join(ConceptDocs.topics())], 16)
	session.record("help_viewed", {"tool": name, "via": "man"})
	return CommandResult.ok(CommandDocs.man_page(name))


func _cheatsheet(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var topic: String = args[0] if not args.is_empty() else ""
	var text := CommandDocs.cheatsheet(topic)
	if text == "":
		return CommandResult.error("cheatsheet: tema desconocido '%s'. Temas: %s" % [topic, ", ".join(CommandDocs.topics())])
	session.record("help_viewed", {"tool": "cheatsheet", "via": "cheatsheet"})
	return CommandResult.ok(text)
