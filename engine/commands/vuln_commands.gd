extends RefCounted
## "avisos": consulta la base de datos local de avisos de seguridad (vuln_db.gd) para un servicio
## cuya versión YA conoces (con `nmap -sV`). No escanea nada por su cuenta: es una búsqueda, como
## lo sería en una base de datos de avisos real, sobre lo que ya has detectado.
##
## Enseña a razonar, no a explotar: la ficha de cada aviso dice la CLASE de fallo y su gravedad,
## nunca cómo aprovecharlo. Y si no hay avisos, lo dice con la salvedad de que eso no es garantía
## de nada: la base de datos de este laboratorio es pequeña y no sustituye a una revisión real.

const CommandResult := preload("res://engine/shell/command_result.gd")
const Host := preload("res://engine/host.gd")
const VulnDb := preload("res://engine/commands/vuln_db.gd")

const SEVERITY_LABEL := {"bajo": "BAJO", "medio": "MEDIO", "alto": "ALTO", "critico": "CRÍTICO"}


func register_all(registry: RefCounted) -> void:
	registry.register("avisos", "Busca avisos de seguridad conocidos para un servicio ya identificado (IP PUERTO)", _avisos)


func _avisos(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if args.size() != 2:
		return CommandResult.error("avisos: usa  avisos <host> <puerto>  (primero identifica la versión con nmap -sV)", 2)
	var target: String = args[0]
	var ip := _resolve(session, target)
	if ip == "":
		return CommandResult.error("avisos: %s: no se conoce ese host en esta red" % target)
	if not args[1].is_valid_int():
		return CommandResult.error("avisos: «%s» no es un puerto válido" % args[1], 2)
	var port := int(args[1])

	var known := _known_service(session, ip, port)
	if known.is_empty():
		return CommandResult.error("avisos: todavía no sabes qué versión ofrece %s:%d. Usa  nmap -sV %s  primero." % [target, port, target])

	var product: String = known["product"]
	var version: String = known["version"]
	var advisories := VulnDb.lookup(product, version)
	session.record("advisory_checked", {"ip": ip, "port": port, "product": product, "version": version, "found": not advisories.is_empty(), "count": advisories.size()})

	var result := CommandResult.new()
	var header := "%s %s (%s:%d)\n" % [product, version, target, port]
	if advisories.is_empty():
		result.stdout = header + "Sin avisos conocidos en esta base de datos local.\n" \
			+ "Eso no significa que sea invulnerable: esta base es pequeña y solo recoge lo que el laboratorio conoce.\n"
		return result
	var lines: Array[String] = [header]
	for advisory: Dictionary in advisories:
		lines.append("%s  %s  (CVSS %.1f)" % [advisory["id"], SEVERITY_LABEL.get(advisory["severity"], advisory["severity"]), advisory["cvss"]])
		lines.append("  %s" % advisory["summary"])
		lines.append("  Corregido en: %s" % advisory["fixed_in"])
	result.stdout = "\n".join(lines) + "\n"
	return result


## El producto y la versión que YA detectaste (con nmap -sV) para ip:puerto, o {} si no lo sabes.
## Mira tus propios eventos, no el mundo: no te da nada que no hayas comprobado tú mismo.
func _known_service(session: RefCounted, ip: String, port: int) -> Dictionary:
	for event: Dictionary in session.events:
		if event["type"] == "service_version" and event.get("ip") == ip and int(event.get("port", -1)) == port:
			return {"product": event.get("product", ""), "version": event.get("version", "")}
	return {}


func _resolve(session: RefCounted, target: String) -> String:
	var world = session.world
	if Host.is_valid_ip(target) and world.hosts.has(target):
		return target
	var host = world.host_by_name(target)
	return host.ip if host != null else ""
