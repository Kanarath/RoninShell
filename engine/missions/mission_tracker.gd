extends RefCounted
## Une el motor de misiones con la sesión de shell: tras cada comando revisa los eventos
## y devuelve los avisos que hay que enseñar ("Objetivo completado", "Nueva misión"...).
## También da formato de texto a todo lo que el jugador lee sobre su progreso.

const MissionEngine := preload("res://engine/missions/mission_engine.gd")

const MASTERY_LABEL := {"solo": "por tu cuenta", "ayuda": "con ayuda", "solucion": "con la solución"}

var engine: RefCounted


func _init(mission_engine: RefCounted) -> void:
	engine = mission_engine


## Llamado por la sesión tras cada línea ejecutada.
func after_command(session: RefCounted) -> Array[String]:
	var level_before: int = engine.level()
	return format_notifications(engine.update(session.events), level_before)


func format_notifications(notifications: Array, level_before: int) -> Array[String]:
	var lines: Array[String] = []
	for item: Dictionary in notifications:
		if item["type"] == "objective":
			lines.append("[+] Objetivo completado: %s  (+%d XP, %s)" % [item["text"], item["xp"], MASTERY_LABEL[item["mastery"]]])
		else:
			lines.append("*** Misión completada: %s ***" % item["title"])
			if engine.is_finished():
				lines.append("Has completado todas las misiones de este laboratorio. Usa `perfil` para ver lo que has demostrado.")
			else:
				var next: Dictionary = engine.current_mission()
				lines.append("Nueva misión: %s" % next["title"])
				lines.append(next["briefing"])
				lines.append("Escribe `mision` para ver tus objetivos.")
	if engine.level() > level_before:
		lines.append("Nivel %d alcanzado." % engine.level())
	# Si lo que acabas de hacer desbloquea una pregunta de autoevaluación, avisa una vez.
	var completed: Array[String] = []
	for item: Dictionary in notifications:
		if item["type"] == "objective":
			completed.append(item["id"])
	var question: Dictionary = engine.active_question()
	if not question.is_empty():
		for required: String in question.get("requires", []):
			if required in completed:
				lines.append("Autoevaluación opcional disponible: escribe `responder` para ver la pregunta (+XP extra, sin presión).")
				break
	return lines


## Texto de la orden `mision`.
func mission_text() -> String:
	if engine.is_finished():
		return "No quedan misiones: has completado todo el laboratorio.\n"
	var mission: Dictionary = engine.current_mission()
	var text := "MISIÓN %d de %d: %s\n%s\n\n" % [engine.mission_index + 1, engine.book["missions"].size(), mission["title"], mission["briefing"]]
	var active: Dictionary = engine.active_objective()
	var number := 0
	for objective: Dictionary in mission["objectives"]:
		number += 1
		var marker := "[ ]"
		var suffix := ""
		if engine.status_of(objective["id"]) == "done":
			marker = "[x]"
			suffix = "  (%s)" % MASTERY_LABEL[engine.mastery_of(objective["id"])]
		elif not engine.is_available(objective):
			marker = "[-]"
			suffix = "  (bloqueado: completa antes los objetivos necesarios)"
		elif objective.has("question"):
			marker = "[?]"
			suffix = "  (autoevaluación opcional: usa `responder`)" if engine.is_optional(objective) else "  (pregunta: usa `responder`)"
		elif not active.is_empty() and active["id"] == objective["id"]:
			marker = "[>]"
		text += "  %s %d. %s%s\n" % [marker, number, objective["text"], suffix]
	text += "\n¿Necesitas ayuda? `pista` te da una pista del objetivo actual; `pista N` la del objetivo N.\n"
	text += "XP: %d  -  Nivel %d\n" % [engine.xp, engine.level()]
	return text


## Texto de la orden `expediente`.
func dossier_text() -> String:
	var cards: Array = engine.evidence_cards()
	var collected := 0
	var lines: Array[String] = []
	for card: Dictionary in cards:
		if card["collected"]:
			collected += 1
			lines.append("  [x] %s: %s" % [card["title"], card["detail"]])
		else:
			lines.append("  [ ] ???")
	return "EXPEDIENTE DE EVIDENCIAS (%d/%d)\n%s\n" % [collected, cards.size(), "\n".join(lines)]


## Texto de la orden `perfil`.
func profile_text() -> String:
	var text := "PERFIL  -  Nivel %d  -  %d XP\n\nCompetencias demostradas:\n" % [engine.level(), engine.xp]
	var profile: Dictionary = engine.competency_profile()
	if profile.is_empty():
		text += "  (todavía ninguna: completa objetivos para llenar tu perfil)\n"
	var concepts: Array = profile.keys()
	concepts.sort()
	for concept: String in concepts:
		var counts: Dictionary = profile[concept]
		text += "  %-26s por tu cuenta: %d   con ayuda: %d   con la solución: %d\n" % [concept.replace("_", " "), counts["solo"], counts["ayuda"], counts["solucion"]]
	var review: Array[String] = engine.review_concepts()
	if not review.is_empty():
		var shown: Array[String] = []
		for concept in review:
			shown.append(concept.replace("_", " "))
		text += "\nPor repasar (los resolviste con ayuda): %s\n" % ", ".join(shown)
	return text
