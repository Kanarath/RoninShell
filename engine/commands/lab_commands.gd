extends RefCounted
## Órdenes de la capa de juego sobre el laboratorio: modo, reiniciar y repaso.

const CommandResult := preload("res://engine/shell/command_result.gd")

var controller: RefCounted


func _init(lab_controller: RefCounted) -> void:
	controller = lab_controller


func register_all(registry: RefCounted) -> void:
	registry.register("modo", "[juego] Cambia de modo: libre, mision (modo sin argumentos lo muestra)", _modo)
	registry.register("reiniciar", "[juego] Restaura el laboratorio a su estado inicial", _reiniciar)
	registry.register("repaso", "[juego] Repaso espaciado: qué toca repasar y retos nuevos", _repaso)


func _modo(_session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if args.is_empty():
		var text := "Modo actual: %s\n" % controller.mode.to_upper()
		text += "  mision   objetivos, pistas y XP\n  libre    laboratorio sin objetivos para experimentar (usa `reiniciar` si lo estropeas)\n"
		text += "  repaso   se entra con `repaso iniciar`\n"
		return CommandResult.ok(text)
	var wanted: String = str(args[0]).to_lower()
	if not wanted in ["libre", "mision", "misión"]:
		return CommandResult.error("modo: modo desconocido '%s' (usa libre o mision)" % args[0])
	if controller.mode == "repaso":
		return CommandResult.error("modo: estás en un repaso. Usa `repaso salir` antes de cambiar de modo.")
	wanted = "mision" if wanted.begins_with("mis") else "libre"
	if wanted == controller.mode:
		return CommandResult.ok("Ya estás en modo %s.\n" % wanted.to_upper())
	controller.mode = wanted
	controller.request("mode", {"mode": wanted})
	if wanted == "libre":
		return CommandResult.ok("MODO LIBRE: sin objetivos ni XP. Experimenta sin miedo; `reiniciar` restaura el laboratorio y `modo mision` te devuelve a tu misión.\n")
	return CommandResult.ok("De vuelta a la misión. `mision` te recuerda dónde estabas.\n")


func _reiniciar(_session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	controller.request("reset")
	return CommandResult.ok("Reiniciando el laboratorio...\n")


func _repaso(_session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if controller.scheduler == null or controller.review_book.is_empty():
		return CommandResult.error("repaso: no hay retos de repaso disponibles.")
	if args.is_empty():
		return CommandResult.ok(_overview())

	match str(args[0]).to_lower():
		"iniciar":
			return _start(args.slice(1))
		"salir":
			if controller.mode != "repaso":
				return CommandResult.error("repaso: no estás en ningún repaso.")
			controller.request("review_exit")
			return CommandResult.ok("Saliendo del repaso...\n")
		_:
			return CommandResult.error("repaso: uso: repaso | repaso iniciar [concepto] | repaso salir")


func _overview() -> String:
	var now: float = controller.now()
	var available: Array = controller.review_concepts()
	var text := "REPASO ESPACIADO\n"
	var due: Array[String] = controller.due_reviews()
	if due.is_empty():
		text += "Ahora mismo no tienes nada atrasado.\n"
	else:
		text += "Toca repasar ahora:\n"
		for concept in due:
			text += "  [!] %s\n" % concept.replace("_", " ")
	var rows: Array = controller.scheduler.overview(now)
	var upcoming := ""
	for row: Dictionary in rows:
		if row["days"] > 0.0:
			upcoming += "  [ ] %-28s dentro de %.1f días%s\n" % [str(row["concept"]).replace("_", " "), row["days"], "" if row["concept"] in available else "  (sin reto todavía)"]
	if upcoming != "":
		text += "Programados:\n" + upcoming
	if rows.is_empty():
		text += "Aún no hay nada programado: los conceptos se programan solos al completar objetivos (con ayuda vuelven antes).\n"
	text += "\nRetos disponibles: %s\n" % ", ".join(available).replace("_", " ")
	text += "`repaso iniciar` repasa lo más atrasado; `repaso iniciar <concepto>` elige uno (sin guion bajo: 'permisos', 'puertos servicios'...).\n"
	return text


func _start(args: Array) -> RefCounted:
	if controller.mode == "repaso":
		return CommandResult.error("repaso: ya estás en un repaso. Termínalo o usa `repaso salir`.")
	if controller.mode == "libre":
		return CommandResult.error("repaso: estás en modo libre. Escribe `modo mision` y luego `repaso iniciar`.")
	var concept := ""
	if args.is_empty():
		var due: Array[String] = controller.due_reviews()
		if due.is_empty():
			return CommandResult.error("repaso: no hay nada atrasado. Puedes practicar uno igualmente con `repaso iniciar <concepto>`. Conceptos: %s" % ", ".join(controller.review_concepts()).replace("_", " "))
		concept = due[0]
	else:
		concept = " ".join(args).strip_edges().to_lower().replace(" ", "_")
	if controller.review_mission_for(concept).is_empty():
		return CommandResult.error("repaso: no hay un reto para '%s'. Conceptos: %s" % [concept.replace("_", " "), ", ".join(controller.review_concepts()).replace("_", " ")])
	controller.mode = "repaso"
	controller.current_review_concept = concept
	controller.request("review", {"concept": concept})
	return CommandResult.ok("Preparando el reto de repaso: %s...\n" % concept.replace("_", " "))
