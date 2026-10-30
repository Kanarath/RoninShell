extends RefCounted
## Primera etapa sobre la línea completa: la parte en "unidades" separadas por ; && ||
## (respetando comillas, comentarios y $( ... )). Cada unidad es una tubería que se tokeniza
## después, justo antes de ejecutarla, para que `A=1 && echo $A` vea el valor nuevo.
##
## Después `build` agrupa las unidades en una lista de elementos:
##   {"kind": "cmd", "text", "op"}
##   {"kind": "for", "header", "body": [elementos cmd], "op"}      (for X in a b c; do ...; done)
## `op` es el conector que precede al elemento: "" (el primero), ";", "&&" o "||".
##
## Los errores imitan los de bash. Lo que aún no existe (if, while, bucles anidados) se dice claro.

const Tokenizer := preload("res://engine/shell/tokenizer.gd")

const UNSUPPORTED := ["if", "then", "elif", "else", "fi", "while", "until", "case", "esac", "function", "select"]


## Devuelve {"units": [{"text", "op"}], "error": String}.
static func split(line: String) -> Dictionary:
	var units: Array = []
	var cur := ""
	var pending_op := ""
	var i := 0
	var n := line.length()
	while i < n:
		var c := line[i]
		var connector := ""
		if c == "'":
			var close := line.find("'", i + 1)
			if close == -1:
				return _fail("unexpected EOF while looking for matching `''")
			cur += line.substr(i, close - i + 1)
			i = close + 1
			continue
		elif c == "\"":
			var j := i + 1
			while j < n and line[j] != "\"":
				if line[j] == "$" and j + 1 < n and line[j + 1] == "(":
					var end := Tokenizer.matching_paren(line, j + 1)
					if end == -1:
						return _fail("unexpected EOF while looking for matching `)'")
					j = end
				elif line[j] == "\\":
					j += 1
				j += 1
			if j >= n:
				return _fail("unexpected EOF while looking for matching `\"'")
			cur += line.substr(i, j - i + 1)
			i = j + 1
			continue
		elif c == "$" and i + 1 < n and line[i + 1] == "(":
			var close_paren := Tokenizer.matching_paren(line, i + 1)
			if close_paren == -1:
				return _fail("unexpected EOF while looking for matching `)'")
			cur += line.substr(i, close_paren - i + 1)
			i = close_paren + 1
			continue
		elif c == "\\":
			cur += line.substr(i, 2)
			i += 2
			continue
		elif c == "#" and (cur.is_empty() or cur[cur.length() - 1] in [" ", "\t"]):
			break
		elif c == ";":
			if i + 1 < n and line[i + 1] == ";":
				return _fail("syntax error near unexpected token `;;'")
			connector = ";"
		elif c == "&":
			if i + 1 < n and line[i + 1] == "&":
				connector = "&&"
			else:
				return _fail("'&' (ejecutar en segundo plano) no está disponible en este shell simulado")
		elif c == "|" and i + 1 < n and line[i + 1] == "|":
			connector = "||"

		if connector == "":
			cur += c
			i += 1
			continue
		if cur.strip_edges().is_empty():
			return _fail("syntax error near unexpected token `%s'" % connector)
		units.append({"text": cur.strip_edges(), "op": pending_op})
		pending_op = connector
		cur = ""
		i += connector.length()

	if cur.strip_edges().is_empty():
		if pending_op == "&&" or pending_op == "||":
			return _fail("syntax error: unexpected end of file")
	else:
		units.append({"text": cur.strip_edges(), "op": pending_op})
	return {"units": units, "error": ""}


## Agrupa las unidades en elementos (cmd / for). Devuelve {"items": Array, "error": String}.
static func build(units: Array) -> Dictionary:
	var items: Array = []
	var i := 0
	while i < units.size():
		var unit: Dictionary = units[i]
		var word := _first_word(unit["text"])
		if word == "for":
			var parsed := _build_for(units, i)
			if parsed["error"] != "":
				return {"items": [], "error": parsed["error"]}
			items.append(parsed["item"])
			i = parsed["next"]
			continue
		if word == "do" or word == "done":
			return _fail("syntax error near unexpected token `%s'" % word)
		if word in UNSUPPORTED:
			return _fail("`%s' todavía no está disponible en este shell simulado (de momento: ; && || y for)" % word)
		items.append({"kind": "cmd", "text": unit["text"], "op": unit["op"]})
		i += 1
	return {"items": items, "error": ""}


static func _build_for(units: Array, start: int) -> Dictionary:
	var header: Dictionary = units[start]
	var words: PackedStringArray = header["text"].split(" ", false)
	if words.size() < 3 or words[2] != "in" or not Tokenizer.is_valid_name(words[1]):
		return {"error": "syntax error: usa `for VARIABLE in palabras; do comando; done`", "item": null, "next": 0}
	if start + 1 >= units.size():
		return {"error": "syntax error: unexpected end of file", "item": null, "next": 0}
	var do_unit: Dictionary = units[start + 1]
	if _first_word(do_unit["text"]) != "do" or do_unit["op"] != ";":
		return {"error": "syntax error near unexpected token `%s'" % _first_word(do_unit["text"]), "item": null, "next": 0}
	var body: Array = []
	var first_text: String = do_unit["text"].substr(2).strip_edges()
	if _first_word(first_text) == "for":
		return {"error": "los bucles anidados todavía no están disponibles en este shell simulado", "item": null, "next": 0}
	if first_text != "":
		body.append({"kind": "cmd", "text": first_text, "op": ";"})
	var j := start + 2
	while j < units.size():
		var unit: Dictionary = units[j]
		var word := _first_word(unit["text"])
		if word == "done" and unit["text"] == "done":
			if body.is_empty():
				return {"error": "syntax error near unexpected token `done'", "item": null, "next": 0}
			return {"error": "", "item": {"kind": "for", "header": header["text"], "body": body, "op": header["op"]}, "next": j + 1}
		if word == "for":
			return {"error": "los bucles anidados todavía no están disponibles en este shell simulado", "item": null, "next": 0}
		if word == "do":
			return {"error": "syntax error near unexpected token `do'", "item": null, "next": 0}
		if word in UNSUPPORTED:
			return {"error": "`%s' todavía no está disponible en este shell simulado (de momento: ; && || y for)" % word, "item": null, "next": 0}
		body.append({"kind": "cmd", "text": unit["text"], "op": unit["op"]})
		j += 1
	return {"error": "syntax error: unexpected end of file (falta `done')", "item": null, "next": 0}


static func _first_word(text: String) -> String:
	var words := text.split(" ", false, 1)
	return words[0] if words.size() > 0 else ""


static func _fail(message: String) -> Dictionary:
	return {"units": [], "items": [], "error": message}
