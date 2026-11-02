extends RefCounted
## "¿Qué hago ahora?": un resumen corto y tranquilo de dónde estás y cuál es el siguiente paso pequeño.
## No gasta pistas ni afecta a la puntuación: solo reordena lo que ya está en pantalla.
##
## Devuelve {"title": String, "lines": Array[String]}.

static func build(engine: RefCounted, mode: String, review_concept := "") -> Dictionary:
	if mode == "libre":
		return {"title": "Modo libre", "lines": [
			"Aquí no hay objetivos ni XP: experimenta lo que quieras.",
			"Si estropeas algo, `reiniciar` lo deja como al principio.",
			"Para volver a tu misión escribe `modo mision`.",
		]}
	if engine == null:
		return {"title": "Sin misión", "lines": ["Todavía no hay una misión cargada."]}
	if mode == "repaso":
		var lines := ["Es un repaso corto de «%s». Se hace igual que una misión, sin prisa." % review_concept.replace("_", " ")]
		lines.append_array(_step_lines(engine))
		lines.append("Para salir sin acabar: `repaso salir`. No pasa nada, volverá a tocar más adelante.")
		return {"title": "Repaso", "lines": lines}
	if engine.is_finished():
		return {"title": "Laboratorio completado", "lines": [
			"Has terminado todas las misiones de este laboratorio. ¡Buen trabajo!",
			"`laboratorio` muestra si hay otro disponible, `repaso` lo que toca repasar y F3 tu perfil.",
		]}

	var mission: Dictionary = engine.current_mission()
	var done := 0
	var total := 0
	var last_done := ""
	for objective: Dictionary in engine.objectives():
		if engine.is_optional(objective):
			continue
		total += 1
		if engine.status_of(objective["id"]) == "done":
			done += 1
			last_done = objective.get("short", objective["text"])
	var lines: Array = ["%s  ·  objetivo %d de %d" % [mission["title"], mini(done + 1, total), total]]
	if last_done != "":
		lines.append("Ya has conseguido: %s" % last_done)
	lines.append_array(_step_lines(engine))
	lines.append("Si te atascas: `pista` da una ayuda más concreta cada vez. No resta nada; solo anota qué conviene repasar.")
	return {"title": "Qué hacer ahora", "lines": lines}


static func _step_lines(engine: RefCounted) -> Array:
	var active: Dictionary = engine.active_objective()
	if active.is_empty():
		return ["No queda ningún objetivo pendiente en esta misión."]
	var lines: Array = ["Ahora toca: %s" % active["text"]]
	if active.has("question"):
		lines.append("Paso pequeño: escribe `responder` para ver la pregunta y elige una opción.")
	elif active.has("classify"):
		lines.append("Paso pequeño: piensa si lo has visto tú o lo supones, y anótalo con `hallazgo <tipo> \"texto\"`.")
	elif active.has("report"):
		lines.append("Paso pequeño: escribe una frase por cada punto que pide `revisar`; `nano informe/borrador.md` abre el editor.")
	else:
		lines.append("Paso pequeño: prueba un comando y mira qué responde. Equivocarte no cuesta nada.")
	return lines
