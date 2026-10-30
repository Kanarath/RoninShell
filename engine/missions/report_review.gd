extends RefCounted
## Revisor de informes: comprueba un texto contra una lista de comprobación definida en los
## datos de la misión. No juzga la calidad de la redacción (eso no se puede automatizar bien):
## comprueba que el informe contiene los elementos de un buen hallazgo y que no afirma más
## de lo que se ha probado. Es deliberadamente tolerante con cómo lo escribas.
##
## spec = {
##   "min_chars": 80,
##   "elements": [{"id", "label", "any": [palabras clave]}],
##   "forbidden": [palabras que indican exagerar, p. ej. "hackead"]
## }
## Devuelve {"elements": [{label, ok}], "warnings": [String], "complete": bool}.

static func review(text: String, spec: Dictionary) -> Dictionary:
	var lowered := text.to_lower()
	var elements: Array = []
	var all_ok := true
	for element: Dictionary in spec.get("elements", []):
		var found := false
		for keyword in element.get("any", []):
			if lowered.contains(str(keyword).to_lower()):
				found = true
				break
		elements.append({"label": element["label"], "ok": found})
		all_ok = all_ok and found

	var warnings: Array[String] = []
	var min_chars := int(spec.get("min_chars", 0))
	if text.strip_edges().length() < min_chars:
		warnings.append("El texto es demasiado corto: un hallazgo necesita explicarse (al menos %d caracteres)." % min_chars)
	for word in spec.get("forbidden", []):
		if lowered.contains(str(word).to_lower()):
			warnings.append("Cuidado: afirmas algo que no has demostrado (aparece '%s'). Describe lo que probaste, no lo que supones." % word)

	return {"elements": elements, "warnings": warnings, "complete": all_ok and warnings.is_empty()}
