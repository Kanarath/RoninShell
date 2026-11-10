extends RefCounted
## man y cheatsheet. (help vive en basic_commands y --help se resuelve en la sesión.)

const CommandResult := preload("res://engine/shell/command_result.gd")
const CommandDocs := preload("res://engine/commands/command_docs.gd")
const ConceptDocs := preload("res://engine/commands/concept_docs.gd")


func register_all(registry: RefCounted) -> void:
	registry.register("man", "Ficha completa de un comando (man nmap)", _man)
	registry.register("cheatsheet", "Chuleta de comandos útiles por tema", _cheatsheet)
	registry.register("formacion", "[juego] Qué NO enseña RoninShell a propósito, y dónde seguir aprendiendo", _formacion)


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


## No ejecuta nada ni mira el laboratorio: es solo texto, para que al terminar no te quedes sin
## saber por dónde seguir. Los temas que "faltan" tienen su propia ficha (man explotacion...).
func _formacion(session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	session.record("help_viewed", {"tool": "formacion", "via": "formacion"})
	var w := CommandDocs.WIDTH
	var text := "FORMACIÓN: SEGUIR APRENDIENDO\n"
	text += CommandDocs._wrap_lines("RoninShell enseña reconocimiento, análisis, scripts y defensa: la base real de una auditoría. A propósito NO simula estas fases (cada una tiene su ficha: man <tema>):", w, 0) + "\n"
	for topic in ["explotacion", "escalada_privilegios", "post_explotacion"]:
		text += CommandDocs._bullet("-", "%s  ->  man %s" % [topic.replace("_", " ").capitalize(), topic])
	text += "\nPARA PRACTICAR ESO, CON AUTORIZACIÓN Y SIN RIESGO\n"
	var resources := [
		["TryHackMe (tryhackme.com)", "rutas guiadas 'Pre Security' y 'Jr Penetration Tester': el mejor siguiente paso."],
		["OverTheWire: Bandit (overthewire.org)", "practicar Linux y la terminal con retos, gratis."],
		["PortSwigger Web Security Academy (portswigger.net/web-security)", "el mejor recurso gratuito de seguridad web."],
		["Hack The Box Academy (academy.hackthebox.com)", "más técnico, con módulos gratuitos y de pago."],
		["DVWA / OWASP Juice Shop", "apps vulnerables A PROPÓSITO, para tu propia máquina."],
		["Una VM con Kali Linux", "las herramientas reales (nmap, Burp, Metasploit) en tu propio laboratorio."],
	]
	for resource: Array in resources:
		text += CommandDocs._bullet("-", "%s: %s" % [resource[0], resource[1]])
	text += "\n" + CommandDocs._wrap_lines("Todo esto es legal y gratis (o con plan gratuito) en tu propia máquina o en esas plataformas. Practicar sin autorización en un sistema que no es tuyo es ilegal, aunque sea \"solo para aprender\".", w, 0) + "\n"
	return CommandResult.ok(text)


func _cheatsheet(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var topic: String = args[0] if not args.is_empty() else ""
	var text := CommandDocs.cheatsheet(topic)
	if text == "":
		return CommandResult.error("cheatsheet: tema desconocido '%s'. Temas: %s" % [topic, ", ".join(CommandDocs.topics())])
	session.record("help_viewed", {"tool": "cheatsheet", "via": "cheatsheet"})
	return CommandResult.ok(text)
