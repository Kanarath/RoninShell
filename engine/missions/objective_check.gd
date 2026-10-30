extends RefCounted
## Comprueba si un objetivo se ha cumplido, mirando los eventos que el jugador ha
## provocado en el laboratorio (ver ShellSession.record). Los criterios son datos:
##
##   {"event": "file_read", "where": {"path": "/home/ronin/nota.txt"}}
##   {"event": "host_discovered", "distinct": "ip", "min": 2}
##   {"all": [criterio, criterio]}   /   {"any": [criterio, criterio]}
##
## "where" compara campo a campo; si el valor es una lista, basta con que coincida uno.

static func passes(check: Dictionary, events: Array) -> bool:
	if check.has("all"):
		for sub: Dictionary in check["all"]:
			if not passes(sub, events):
				return false
		return true
	if check.has("any"):
		for sub: Dictionary in check["any"]:
			if passes(sub, events):
				return true
		return false

	var where: Dictionary = check.get("where", {})
	var contains: Dictionary = check.get("contains", {})
	var matching: Array = []
	for event: Dictionary in events:
		if event.get("free", false):
			continue  # lo hecho en modo libre no cuenta para los objetivos
		if event["type"] == check.get("event", "") and _matches(event, where) and _contains(event, contains):
			matching.append(event)

	var needed := int(check.get("min", 1))
	var distinct_field: String = check.get("distinct", "")
	if distinct_field == "":
		return matching.size() >= needed
	var seen := {}
	for event: Dictionary in matching:
		seen[event.get(distinct_field)] = true
	return seen.size() >= needed


static func is_valid(check: Variant) -> bool:
	if typeof(check) != TYPE_DICTIONARY:
		return false
	if check.has("all") or check.has("any"):
		var list = check.get("all", check.get("any"))
		if typeof(list) != TYPE_ARRAY or list.is_empty():
			return false
		for sub in list:
			if not is_valid(sub):
				return false
		return true
	return typeof(check.get("event", null)) == TYPE_STRING and check["event"] != ""


## "contains": {"text": ["apache", "2.4"]} exige que el campo contenga TODOS los términos (sin mayúsculas).
static func _contains(event: Dictionary, contains: Dictionary) -> bool:
	for key: String in contains:
		var text := str(event.get(key, "")).to_lower()
		for term in contains[key]:
			if not text.contains(str(term).to_lower()):
				return false
	return true


static func _matches(event: Dictionary, where: Dictionary) -> bool:
	for key: String in where:
		var expected = where[key]
		var actual = event.get(key)
		if typeof(expected) == TYPE_ARRAY:
			if not actual in expected:
				return false
		elif actual != expected:
			return false
	return true
