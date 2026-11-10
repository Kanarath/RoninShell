extends RefCounted
## Órdenes de la capa de juego sobre el laboratorio: modo, reiniciar y repaso.

const CommandResult := preload("res://engine/shell/command_result.gd")
const Vfs := preload("res://engine/vfs.gd")
const Profile := preload("res://engine/profile.gd")

var controller: RefCounted


func _init(lab_controller: RefCounted) -> void:
	controller = lab_controller


func register_all(registry: RefCounted) -> void:
	registry.register("modo", "[juego] Cambia de modo: libre, mision (modo sin argumentos lo muestra)", _modo)
	registry.register("reiniciar", "[juego] Restaura el laboratorio a su estado inicial", _reiniciar)
	registry.register("laboratorio", "[juego] Lista los laboratorios y cambia de uno a otro", _laboratorio)
	registry.register("nano", "Abre un editor de texto sencillo (Ctrl+S guarda, Esc cierra)", _nano)
	registry.register("repaso", "[juego] Repaso espaciado: qué toca repasar y retos nuevos", _repaso)
	registry.register("ahora", "[juego] ¿Qué hago ahora? Resumen y siguiente paso (también F4)", _ahora)
	registry.register("tutorial", "[juego] Vuelve a ver el tutorial inicial", _tutorial)


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


## nano abre una ventana de edición (la interfaz la atiende, como el resto de peticiones).
## Los permisos se comprueban aquí al abrir y otra vez al guardar.
func _nano(session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	if args.is_empty():
		return CommandResult.error("nano: falta el nombre del archivo. Uso: nano <archivo>")
	if args.size() > 1:
		return CommandResult.error("nano: solo se puede editar un archivo a la vez")
	var shown: String = args[0]
	var path := Vfs.normalize(session.cwd, shown)
	var fs = session.host.fs
	if fs.is_dir(path):
		return CommandResult.error("nano: %s: Is a directory" % shown)
	if fs.exists(path):
		if not fs.check_access(path, session.user, "r"):
			return CommandResult.error("nano: %s: Permission denied" % shown)
	else:
		var parent: String = path.get_base_dir()
		if not fs.is_dir(parent):
			return CommandResult.error("nano: %s: No such file or directory" % shown)
		if not fs.check_access(parent, session.user, "w"):
			return CommandResult.error("nano: %s: Permission denied" % shown)
	session.record("editor_opened", {"path": path})
	controller.request("edit", {"path": path, "shown": shown})
	return CommandResult.ok("Abriendo el editor... (Ctrl+S guarda, Esc cierra)\n")


func _ahora(_session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	controller.request("now")
	return CommandResult.ok("Abriendo «¿qué hago ahora?»...\n")


func _tutorial(_session: RefCounted, _args: Array, _stdin: String) -> RefCounted:
	controller.request("tutorial")
	return CommandResult.ok("Abriendo el tutorial...\n")


func _laboratorio(_session: RefCounted, args: Array, _stdin: String) -> RefCounted:
	var states: Dictionary = controller.book_states
	if states.is_empty():
		return CommandResult.error("laboratorio: no hay laboratorios disponibles.")
	if args.is_empty():
		var text := "LABORATORIOS\n"
		for id: String in states:
			var marker := "[x]" if states[id] == "completado" else ("[ ]" if states[id] == "disponible" else "[-]")
			text += "  %s %-18s %-30s %s%s\n" % [marker, id, controller.book_titles.get(id, id), states[id], "  (activo)" if id == controller.active_book else ""]
		return CommandResult.ok(text + "Cambia con `laboratorio <id>`. Se desbloquea al completar el anterior; tu progreso en cada uno se guarda por separado.\n")
	var wanted := str(args[0])
	if not states.has(wanted):
		return CommandResult.error("laboratorio: no existe '%s'. Usa `laboratorio` para ver la lista." % wanted)
	if states[wanted] == "bloqueado":
		return CommandResult.error("laboratorio: '%s' está bloqueado: completa antes el laboratorio anterior." % wanted)
	if controller.mode != "mision":
		return CommandResult.error("laboratorio: solo se puede cambiar desde el modo misión (sal del modo libre o del repaso).")
	if wanted == controller.active_book:
		return CommandResult.ok("Ya estás en el laboratorio '%s'.\n" % wanted)
	controller.request("lab", {"book": wanted})
	return CommandResult.ok("Cambiando al laboratorio '%s'...\n" % wanted)


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
		"examen":
			return _start_exam()
		"salir":
			if controller.mode != "repaso":
				return CommandResult.error("repaso: no estás en ningún repaso.")
			controller.request("review_exit")
			return CommandResult.ok("Saliendo del repaso...\n")
		_:
			return CommandResult.error("repaso: uso: repaso | repaso iniciar [concepto] | repaso examen | repaso salir")


## Un reto de cada bloque grande del temario, uno tras otro (solo los que ya tienen reto creado).
func _start_exam() -> RefCounted:
	if controller.mode == "repaso":
		return CommandResult.error("repaso: ya estás en un repaso. Termínalo o usa `repaso salir`.")
	if controller.mode == "libre":
		return CommandResult.error("repaso: estás en modo libre. Escribe `modo mision` y luego `repaso examen`.")
	var concepts: Array[String] = []
	for concept: String in Profile.EXAM_CONCEPTS:
		if not controller.review_mission_for(concept).is_empty():
			concepts.append(concept)
	if concepts.size() < 2:
		return CommandResult.error("repaso: todavía no tienes suficientes retos de repaso distintos para un examen.")
	controller.start_exam(concepts)
	var first: String = controller.exam_pop_next()
	controller.mode = "repaso"
	controller.current_review_concept = first
	controller.request("review", {"concept": first})
	return CommandResult.ok("EXAMEN FINAL: %d retos de bloques distintos, uno tras otro. `repaso salir` lo deja a medias en cualquier momento.\nEmpezando por: %s...\n" % [concepts.size(), first.replace("_", " ")])


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
