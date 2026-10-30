extends RefCounted
## Estado y reglas del progreso del jugador: misiones, objetivos, pistas, XP, evidencias
## y perfil de competencias. No sabe nada de la interfaz ni del shell: recibe eventos
## (lo que el jugador ha observado) y devuelve qué ha cambiado.
##
## Filosofía (del documento de diseño):
##   - Se premia entender, no teclear rápido: el XP depende de cuánta ayuda se usó,
##     no del tiempo ni del número de comandos.
##   - Pedir pistas nunca bloquea ni resta: solo queda anotado para el repaso.
##   - Cada objetivo declara qué concepto evalúa, y el perfil refleja lo demostrado.

const ObjectiveCheck := preload("res://engine/missions/objective_check.gd")

const XP_SOLO := 100        # resuelto por cuenta propia
const XP_HELP := 70         # con pistas de orientación
const XP_SOLUTION := 30     # tras ver la solución explicada
const TRANSFER_BONUS := 1.5 # los objetivos de transferencia (otro escenario) valen más
const XP_PER_LEVEL := 300
const OPTIONAL_FACTOR := 0.5 # la autoevaluación opcional da la mitad: es un extra, no un peaje

var book: Dictionary
## Se llama al completar un objetivo con (objetivo, dominio). La usa el repaso espaciado
## para programar el concepto sin que el motor de misiones sepa nada de él.
var on_objective_done: Callable = Callable()
var xp: int = 0
var mission_index: int = 0
var _state: Dictionary = {}     # id de objetivo -> {status, hints_used, attempts, mastery, xp}
var _evidence: Array[String] = []  # ids de las evidencias conseguidas, en orden
var _mission_of: Dictionary = {}   # id de objetivo -> índice de su misión


func _init(mission_book: Dictionary) -> void:
	book = mission_book
	var index := 0
	for mission: Dictionary in book["missions"]:
		for objective: Dictionary in mission["objectives"]:
			_state[objective["id"]] = {"status": "pending", "hints_used": 0, "attempts": 0, "mastery": "", "xp": 0}
			_mission_of[objective["id"]] = index
		index += 1


# --- Consulta -----------------------------------------------------------------

## XP extra concedido desde fuera (p. ej. por superar un repaso).
func award_xp(amount: int) -> void:
	xp += maxi(0, amount)


## Un libro con una sola misión del libro dado, para jugarla aparte (retos de repaso).
static func single_mission_book(source: Dictionary, mission_id: String) -> Dictionary:
	for mission: Dictionary in source["missions"]:
		if mission["id"] == mission_id:
			return {"id": source["id"], "title": source["title"], "lab": source["lab"], "missions": [mission.duplicate(true)]}
	return {}


func is_finished() -> bool:
	return mission_index >= book["missions"].size()


func current_mission() -> Dictionary:
	return {} if is_finished() else book["missions"][mission_index]


func objectives() -> Array:
	return [] if is_finished() else current_mission()["objectives"]


func status_of(objective_id: String) -> String:
	return _state[objective_id]["status"]


func mastery_of(objective_id: String) -> String:
	return _state[objective_id]["mastery"]


func hints_used(objective_id: String) -> int:
	return _state[objective_id]["hints_used"]


func attempts_of(objective_id: String) -> int:
	return _state[objective_id]["attempts"]


## Un objetivo está disponible cuando ya cumpliste todo lo que "requires" exige.
func is_available(objective: Dictionary) -> bool:
	for required: String in objective.get("requires", []):
		if status_of(required) != "done":
			return false
	return true


## El objetivo que toca ahora: el primero pendiente y disponible de la misión actual.
func active_objective() -> Dictionary:
	for objective: Dictionary in objectives():
		if status_of(objective["id"]) == "pending" and is_available(objective):
			return objective
	return {}


## Un objetivo opcional no hace falta para terminar la misión (p. ej. la autoevaluación).
func is_optional(objective: Dictionary) -> bool:
	return objective.get("optional", false)


## La pregunta que se puede contestar ahora. Incluye las opcionales de misiones anteriores:
## que hayas avanzado no te quita la oportunidad de autoevaluarte.
func active_question() -> Dictionary:
	var newest := mini(mission_index, book["missions"].size() - 1)
	for index in range(newest, -1, -1):
		for objective: Dictionary in book["missions"][index]["objectives"]:
			if objective.has("question") and status_of(objective["id"]) == "pending" and is_available(objective):
				return objective
	return {}


## Evalúa la clasificación de un hallazgo contra los objetivos "classify" de la misión actual.
## Devuelve {matched, accepted, message}; matched = false si ningún objetivo trata de ese tema.
func classify(kind: String, text: String) -> Dictionary:
	var lowered := text.to_lower()
	for objective: Dictionary in objectives():
		if not objective.has("classify") or status_of(objective["id"]) == "done":
			continue
		var spec: Dictionary = objective["classify"]
		var topic_found := true
		for keyword in spec["keywords"]:
			if not lowered.contains(str(keyword).to_lower()):
				topic_found = false
		if not topic_found:
			continue
		if kind in spec["accepted"]:
			return {"matched": true, "accepted": true, "message": spec["ok"]}
		return {"matched": true, "accepted": false, "message": spec["feedback"].get(kind, "Esa clasificación no encaja con lo que has demostrado.")}
	return {"matched": false, "accepted": false, "message": ""}


## El informe que hay que revisar ahora (objetivo con "report" pendiente y disponible), o {}.
func report_spec() -> Dictionary:
	for objective: Dictionary in objectives():
		if objective.has("report") and status_of(objective["id"]) == "pending" and is_available(objective):
			return objective["report"]
	return {}


func level() -> int:
	return xp / XP_PER_LEVEL + 1


func level_progress() -> float:
	return float(xp % XP_PER_LEVEL) / XP_PER_LEVEL


## Evidencias de todo el libro: [{id, title, detail, collected}], en el orden del libro.
func evidence_cards() -> Array:
	var cards: Array = []
	for mission: Dictionary in book["missions"]:
		for objective: Dictionary in mission["objectives"]:
			if objective.has("evidence"):
				var card: Dictionary = (objective["evidence"] as Dictionary).duplicate()
				card["collected"] = _evidence.has(card["id"])
				cards.append(card)
	return cards


## Perfil: concepto -> {solo, ayuda, solucion}. Refleja lo que has DEMOSTRADO saber hacer.
func competency_profile() -> Dictionary:
	var profile := {}
	for mission: Dictionary in book["missions"]:
		for objective: Dictionary in mission["objectives"]:
			var state: Dictionary = _state[objective["id"]]
			if state["status"] != "done":
				continue
			var concept: String = objective["concept"]
			if not profile.has(concept):
				profile[concept] = {"solo": 0, "ayuda": 0, "solucion": 0}
			profile[concept][state["mastery"]] += 1
	return profile


## Conceptos que conviene repasar: los que alguna vez se resolvieron con ayuda o viendo la solución.
func review_concepts() -> Array[String]:
	var result: Array[String] = []
	var profile := competency_profile()
	for concept: String in profile:
		if profile[concept]["ayuda"] > 0 or profile[concept]["solucion"] > 0:
			result.append(concept)
	result.sort()
	return result


# --- Progreso -------------------------------------------------------------------

## Revisa los eventos y completa los objetivos que ya se cumplen. Devuelve lo ocurrido:
## [{type: "objective", id, text, xp, mastery}, {type: "mission", id, title}, ...]
func update(events: Array) -> Array:
	var notifications: Array = []
	var changed := true
	while changed and not is_finished():
		changed = false
		for objective: Dictionary in objectives():
			if objective.has("check") and status_of(objective["id"]) == "pending" \
					and is_available(objective) and ObjectiveCheck.passes(objective["check"], events):
				notifications.append_array(_complete(objective))
				changed = true
				break
	return notifications


## Pide la siguiente pista del objetivo "number" (1 = el primero de la misión actual).
## Devuelve {ok, text, level, total, is_solution, objective_id} o {ok: false, message}.
func request_hint(number: int) -> Dictionary:
	var list := objectives()
	if number < 1 or number > list.size():
		return {"ok": false, "message": "No existe el objetivo %d en esta misión." % number}
	var objective: Dictionary = list[number - 1]
	var id: String = objective["id"]
	if status_of(id) == "done":
		return {"ok": false, "message": "Ese objetivo ya está completado."}
	if not is_available(objective):
		return {"ok": false, "message": "Ese objetivo todavía no está disponible: completa antes los anteriores."}
	var hints: Array = objective["hints"]
	var level_used: int = mini(_state[id]["hints_used"] + 1, hints.size())
	_state[id]["hints_used"] = level_used
	return {
		"ok": true, "text": hints[level_used - 1], "level": level_used, "total": hints.size(),
		"is_solution": level_used == hints.size(), "objective_id": id,
	}


## Responde a la pregunta activa con la opción "choice" (1 = primera). Devuelve
## {ok, correct, message, notifications}. Un fallo no penaliza: solo suma un intento.
func answer(choice: int) -> Dictionary:
	var objective := active_question()
	if objective.is_empty():
		return {"ok": false, "correct": false, "message": "Ahora mismo no hay ninguna pregunta pendiente.", "notifications": []}
	var question: Dictionary = objective["question"]
	var options: Array = question["options"]
	if choice < 1 or choice > options.size():
		return {"ok": false, "correct": false, "message": "Elige una opción entre 1 y %d." % options.size(), "notifications": []}
	var picked: Dictionary = options[choice - 1]
	if choice - 1 == int(question["correct"]):
		return {"ok": true, "correct": true, "message": picked["why"], "notifications": _complete(objective)}
	_state[objective["id"]]["attempts"] += 1
	return {"ok": true, "correct": false, "message": picked["why"], "notifications": []}


func _complete(objective: Dictionary) -> Array:
	var id: String = objective["id"]
	var state: Dictionary = _state[id]
	var total_hints: int = objective["hints"].size()
	var mastery := "solo"
	var base := XP_SOLO
	if state["hints_used"] >= total_hints:
		mastery = "solucion"
		base = XP_SOLUTION
	elif state["hints_used"] > 0:
		mastery = "ayuda"
		base = XP_HELP
	var multiplier := TRANSFER_BONUS if objective.get("transfer", false) else 1.0
	if is_optional(objective):
		multiplier = OPTIONAL_FACTOR
	var earned := int(base * multiplier)

	state["status"] = "done"
	state["mastery"] = mastery
	state["xp"] = earned
	xp += earned
	if on_objective_done.is_valid():
		on_objective_done.call(objective, mastery)
	if objective.has("evidence") and not _evidence.has(objective["evidence"]["id"]):
		_evidence.append(objective["evidence"]["id"])

	var notifications: Array = [{"type": "objective", "id": id, "text": objective["text"], "xp": earned, "mastery": mastery}]
	# La misión a la que pertenece el objetivo (puede ser una anterior, si era opcional).
	var owner_index: int = _mission_of[id]
	var mission: Dictionary = book["missions"][owner_index]
	var required_done := true
	for other: Dictionary in mission["objectives"]:
		if not is_optional(other) and status_of(other["id"]) != "done":
			required_done = false
	if required_done and owner_index == mission_index:
		notifications.append({"type": "mission", "id": mission["id"], "title": mission["title"]})
		mission_index += 1
	return notifications


# --- Guardado ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"book_id": book["id"], "xp": xp, "mission_index": mission_index, "state": _state.duplicate(true), "evidence": _evidence.duplicate()}


## Restaura un progreso guardado. Ignora lo que no encaje con el libro actual.
func load_dict(data: Dictionary) -> bool:
	if data.get("book_id", "") != book["id"]:
		return false
	xp = int(data.get("xp", 0))
	mission_index = clampi(int(data.get("mission_index", 0)), 0, book["missions"].size())
	var saved_state: Dictionary = data.get("state", {})
	for id: String in saved_state:
		if _state.has(id):
			var entry: Dictionary = saved_state[id]
			_state[id] = {
				"status": str(entry.get("status", "pending")), "hints_used": int(entry.get("hints_used", 0)),
				"attempts": int(entry.get("attempts", 0)), "mastery": str(entry.get("mastery", "")), "xp": int(entry.get("xp", 0)),
			}
	_evidence.clear()
	for evidence_id in data.get("evidence", []):
		_evidence.append(str(evidence_id))
	return true
