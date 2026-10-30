extends RefCounted
## Repetición espaciada por conceptos (sistema de cajas de Leitner).
##
## Cada concepto está en una caja de 0 a 5; cuanto más alta, más tarde vuelve a tocar repasarlo.
## Lo que resuelves por tu cuenta entra en una caja alta; con ayuda, en una baja; viendo la
## solución, toca repasarlo ya. Acertar un repaso sube de caja; fallarlo vuelve a la 0.
## Nunca hay penalización de XP ni bloqueo: solo decide qué te conviene practicar.
##
## El tiempo se pasa como parámetro ("now", segundos Unix) para poder probarlo sin esperar días.

const DAY := 86400.0
const INTERVAL_DAYS := [0.0, 1.0, 3.0, 7.0, 14.0, 30.0]  # espera por caja
const BOX_BY_MASTERY := {"solo": 2, "ayuda": 1, "solucion": 0}
const MAX_BOX := 5

var _items: Dictionary = {}   # concepto -> {box: int, due: float}


## Un concepto se acaba de resolver en una misión con este dominio ("solo", "ayuda", "solucion").
## Si ya estaba programado, manda el peor resultado: un concepto no está dominado hasta que lo está en todo.
func schedule(concept: String, mastery: String, now: float) -> void:
	var box: int = BOX_BY_MASTERY[mastery]
	if _items.has(concept):
		box = mini(box, _items[concept]["box"])
	_put(concept, box, now)


## Resultado de un reto de repaso: acierto sube de caja, fallo vuelve a la 0.
func record_result(concept: String, success: bool, now: float) -> void:
	var box: int = _items[concept]["box"] if _items.has(concept) else 0
	_put(concept, mini(box + 1, MAX_BOX) if success else 0, now)


func has_concept(concept: String) -> bool:
	return _items.has(concept)


func box_of(concept: String) -> int:
	return _items[concept]["box"] if _items.has(concept) else -1


func due_at(concept: String) -> float:
	return _items[concept]["due"] if _items.has(concept) else INF


## Conceptos que ya toca repasar, del más atrasado al menos.
func due(now: float) -> Array[String]:
	var result: Array[String] = []
	for concept: String in _items:
		if _items[concept]["due"] <= now:
			result.append(concept)
	result.sort_custom(func(a: String, b: String) -> bool: return _items[a]["due"] < _items[b]["due"])
	return result


## Todos los conceptos programados con cuánto falta (negativo o 0 = toca ya), en días.
func overview(now: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for concept: String in _items:
		rows.append({"concept": concept, "box": _items[concept]["box"], "days": (_items[concept]["due"] - now) / DAY})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["days"] < b["days"])
	return rows


func to_dict() -> Dictionary:
	return _items.duplicate(true)


func load_dict(data: Variant) -> void:
	_items.clear()
	if typeof(data) != TYPE_DICTIONARY:
		return
	for concept: String in data:
		var entry = data[concept]
		if typeof(entry) == TYPE_DICTIONARY and entry.has("box") and entry.has("due"):
			_items[concept] = {"box": clampi(int(entry["box"]), 0, MAX_BOX), "due": float(entry["due"])}


func _put(concept: String, box: int, now: float) -> void:
	_items[concept] = {"box": box, "due": now + INTERVAL_DAYS[box] * DAY}
