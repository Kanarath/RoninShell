extends RefCounted
## Carga y valida un libro de misiones (JSON). Devuelve {"book": Dictionary | null, "errors": Array}.
##
## Cada objetivo es o bien una "check" (se cumple al observar algo en el laboratorio)
## o bien una "question" (pregunta de interpretación). Las pistas van de la más suave a
## la solución explicada: 3 o 4 niveles, y el último es siempre la solución.

const ObjectiveCheck := preload("res://engine/missions/objective_check.gd")

const MIN_HINTS := 3
const MAX_HINTS := 4


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"book": null, "errors": ["no existe el archivo %s" % path]}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"book": null, "errors": ["JSON inválido en %s (línea %d): %s" % [path, json.get_error_line(), json.get_error_message()]]}
	return validate(json.data)


static func validate(data: Variant) -> Dictionary:
	var errors: Array = []
	if typeof(data) != TYPE_DICTIONARY:
		return {"book": null, "errors": ["el libro de misiones debe ser un objeto"]}
	for key in ["id", "title", "lab"]:
		if str(data.get(key, "")) == "":
			errors.append("falta '%s'" % key)
	var missions = data.get("missions", [])
	if typeof(missions) != TYPE_ARRAY or missions.is_empty():
		errors.append("'missions' debe ser una lista con al menos una misión")
		return {"book": null, "errors": errors}

	var seen_ids := {}
	for mission: Dictionary in missions:
		var mission_id := str(mission.get("id", ""))
		if mission_id == "" or str(mission.get("title", "")) == "":
			errors.append("cada misión necesita 'id' y 'title'")
			continue
		var objectives = mission.get("objectives", [])
		if typeof(objectives) != TYPE_ARRAY or objectives.is_empty():
			errors.append("la misión %s necesita objetivos" % mission_id)
			continue
		for objective: Dictionary in objectives:
			_validate_objective(objective, mission_id, seen_ids, errors)
	for mission: Dictionary in missions:
		for objective: Dictionary in mission.get("objectives", []):
			for required: String in objective.get("requires", []):
				if not seen_ids.has(required):
					errors.append("%s requiere '%s', que no existe" % [objective.get("id", "?"), required])
	return {"book": data if errors.is_empty() else null, "errors": errors}


static func _validate_objective(objective: Dictionary, mission_id: String, seen_ids: Dictionary, errors: Array) -> void:
	var objective_id := str(objective.get("id", ""))
	var context := "%s/%s" % [mission_id, objective_id]
	if objective_id == "":
		errors.append("%s: falta el id de un objetivo" % mission_id)
		return
	if seen_ids.has(objective_id):
		errors.append("%s: id de objetivo repetido" % context)
	seen_ids[objective_id] = true
	for key in ["text", "concept"]:
		if str(objective.get(key, "")) == "":
			errors.append("%s: falta '%s'" % [context, key])

	var has_check := objective.has("check")
	var has_question := objective.has("question")
	if has_check == has_question:
		errors.append("%s: debe tener 'check' o 'question', pero no ambos" % context)
	elif has_check and not ObjectiveCheck.is_valid(objective["check"]):
		errors.append("%s: 'check' no es válido" % context)
	elif has_question:
		_validate_question(objective["question"], context, errors)
	if objective.has("classify"):
		_validate_classify(objective["classify"], context, errors)
	if objective.has("report"):
		_validate_report(objective["report"], context, errors)

	var hints = objective.get("hints", [])
	if typeof(hints) != TYPE_ARRAY or hints.size() < MIN_HINTS or hints.size() > MAX_HINTS:
		errors.append("%s: necesita entre %d y %d pistas (la última es la solución)" % [context, MIN_HINTS, MAX_HINTS])
	else:
		for hint in hints:
			if str(hint) == "":
				errors.append("%s: hay una pista vacía" % context)
	if objective.has("evidence"):
		var evidence = objective["evidence"]
		if typeof(evidence) != TYPE_DICTIONARY or str(evidence.get("id", "")) == "" or str(evidence.get("title", "")) == "":
			errors.append("%s: la evidencia necesita 'id' y 'title'" % context)


const CLASSIFICATIONS := ["indicio", "hipotesis", "confirmado", "falso-positivo"]


## "classify": qué clasificación se espera para un hallazgo y qué se le dice al jugador si se equivoca.
static func _validate_classify(classify: Variant, context: String, errors: Array) -> void:
	if typeof(classify) != TYPE_DICTIONARY:
		errors.append("%s: 'classify' debe ser un objeto" % context)
		return
	var keywords = classify.get("keywords", [])
	if typeof(keywords) != TYPE_ARRAY or keywords.is_empty():
		errors.append("%s: 'classify' necesita 'keywords'" % context)
	var accepted = classify.get("accepted", [])
	if typeof(accepted) != TYPE_ARRAY or accepted.is_empty():
		errors.append("%s: 'classify' necesita 'accepted'" % context)
	else:
		for kind in accepted:
			if not str(kind) in CLASSIFICATIONS:
				errors.append("%s: clasificación desconocida '%s'" % [context, kind])
	if str(classify.get("ok", "")) == "":
		errors.append("%s: 'classify' necesita el mensaje 'ok'" % context)
	var feedback = classify.get("feedback", {})
	if typeof(feedback) != TYPE_DICTIONARY:
		errors.append("%s: 'feedback' debe ser un objeto tipo -> explicación" % context)
	else:
		for kind in CLASSIFICATIONS:
			if not kind in accepted and str(feedback.get(kind, "")) == "":
				errors.append("%s: falta explicar por qué '%s' no es la clasificación correcta" % [context, kind])


## "report": archivo a revisar y lista de comprobación.
static func _validate_report(report: Variant, context: String, errors: Array) -> void:
	if typeof(report) != TYPE_DICTIONARY or not str(report.get("path", "")).begins_with("/"):
		errors.append("%s: 'report' necesita 'path' absoluto" % context)
		return
	var elements = report.get("elements", [])
	if typeof(elements) != TYPE_ARRAY or elements.is_empty():
		errors.append("%s: 'report' necesita 'elements'" % context)
		return
	for element in elements:
		if typeof(element) != TYPE_DICTIONARY or str(element.get("label", "")) == "" or typeof(element.get("any", null)) != TYPE_ARRAY or element["any"].is_empty():
			errors.append("%s: cada elemento del informe necesita 'label' y 'any'" % context)


static func _validate_question(question: Variant, context: String, errors: Array) -> void:
	if typeof(question) != TYPE_DICTIONARY or str(question.get("prompt", "")) == "":
		errors.append("%s: la pregunta necesita 'prompt'" % context)
		return
	var options = question.get("options", [])
	if typeof(options) != TYPE_ARRAY or options.size() < 2 or options.size() > 6:
		errors.append("%s: la pregunta necesita entre 2 y 6 opciones" % context)
		return
	for option in options:
		if typeof(option) != TYPE_DICTIONARY or str(option.get("text", "")) == "" or str(option.get("why", "")) == "":
			errors.append("%s: cada opción necesita 'text' y 'why' (por qué es o no correcta)" % context)
	var correct = question.get("correct", -1)
	if typeof(correct) != TYPE_FLOAT and typeof(correct) != TYPE_INT or int(correct) < 0 or int(correct) >= options.size():
		errors.append("%s: 'correct' debe ser el índice (desde 0) de una opción" % context)
