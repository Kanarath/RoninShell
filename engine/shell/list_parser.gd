extends RefCounted
## Primera etapa sobre la línea completa: la parte en "unidades" separadas por ; && ||
## (respetando comillas, comentarios y $( ... )). Cada unidad es una tubería que se tokeniza
## después, justo antes de ejecutarla, para que `A=1 && echo $A` vea el valor nuevo.
##
## Después `build` agrupa las unidades en una lista de elementos (con anidación):
##   {"kind": "cmd", "text", "op"}
##   {"kind": "for", "header", "body": [elementos], "op"}                 for X in a b c; do ...; done
##   {"kind": "while", "cond": [...], "body": [...], "negate", "op"}      while/until COND; do ...; done
##   {"kind": "if", "cond": [...], "then": [...], "else": [...], "op"}    if COND; then ...; [elif/else ...;] fi
## `op` es el conector que precede al elemento: "" (el primero), ";", "&&" o "||".
##
## Los errores imitan los de bash. Lo que aún no existe (case, function) se dice claro.

const Tokenizer := preload("res://engine/shell/tokenizer.gd")


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


## Agrupa las unidades en elementos (cmd / for / while / if), con anidación. Devuelve {"items": Array, "error": String}.
static func build(units: Array) -> Dictionary:
	var state := {"units": units.duplicate(true), "pos": 0}
	var result := _sequence(state, [])
	return {"items": result["items"] if result["error"] == "" else [], "error": result["error"]}


## Lee elementos hasta una palabra "terminadora" (sin consumirla). Devuelve {items, stop, error}.
static func _sequence(state: Dictionary, terminators: Array) -> Dictionary:
	var items: Array = []
	var units: Array = state["units"]
	while state["pos"] < units.size():
		var unit: Dictionary = units[state["pos"]]
		var word := _first_word(unit["text"])
		if word in terminators:
			return {"items": items, "stop": word, "error": ""}
		var parsed := {}
		match word:
			"for":
				parsed = _for(state)
			"while", "until":
				parsed = _while(state)
			"if":
				parsed = _if(state, "if")
			"then", "elif", "else", "fi", "do", "done":
				return _err("syntax error near unexpected token `%s'" % word)
			"case", "esac", "function", "select":
				return _err("`%s' todavía no está disponible en este shell simulado (de momento: ; && || for while until if)" % word)
			_:
				items.append({"kind": "cmd", "text": unit["text"], "op": unit["op"]})
				state["pos"] += 1
				continue
		if parsed["error"] != "":
			return _err(parsed["error"])
		items.append(parsed["item"])
	if not terminators.is_empty():
		return _err("syntax error: unexpected end of file (falta `%s')" % terminators[terminators.size() - 1])
	return {"items": items, "stop": "", "error": ""}


## Consume la palabra clave de la unidad actual. Lo que le siga en la misma unidad ("do echo hi")
## pasa a ser una unidad nueva; con allow_rest = false no se admite nada detrás (fi, done).
static func _take(state: Dictionary, word: String, allow_rest: bool) -> String:
	var units: Array = state["units"]
	var unit: Dictionary = units[state["pos"]]
	var rest: String = unit["text"].substr(word.length()).strip_edges()
	if rest == "":
		state["pos"] += 1
	elif allow_rest:
		units[state["pos"]] = {"text": rest, "op": ";"}
	else:
		return "syntax error near unexpected token `%s'" % _first_word(rest)
	return ""


## Exige que la unidad actual empiece por `word` y la consume. Devuelve el error o "".
static func _expect(state: Dictionary, word: String, allow_rest: bool) -> String:
	var units: Array = state["units"]
	if state["pos"] >= units.size():
		return "syntax error: unexpected end of file (falta `%s')" % word
	var found := _first_word(units[state["pos"]]["text"])
	if found != word:
		return "syntax error near unexpected token `%s'" % found
	return _take(state, word, allow_rest)


static func _body(state: Dictionary, terminators: Array) -> Dictionary:
	var result := _sequence(state, terminators)
	if result["error"] == "" and result["items"].is_empty():
		return _err("syntax error near unexpected token `%s'" % result["stop"])
	return result


static func _for(state: Dictionary) -> Dictionary:
	var header: Dictionary = state["units"][state["pos"]]
	var words: PackedStringArray = header["text"].split(" ", false)
	if words.size() < 3 or words[2] != "in" or not Tokenizer.is_valid_name(words[1]):
		return _err("syntax error: usa `for VARIABLE in palabras; do comando; done`")
	state["pos"] += 1
	var failure := _expect(state, "do", true)
	if failure != "":
		return _err(failure)
	var body := _body(state, ["done"])
	if body["error"] != "":
		return _err(body["error"])
	failure = _expect(state, "done", false)
	if failure != "":
		return _err(failure)
	return {"error": "", "item": {"kind": "for", "header": header["text"], "body": body["items"], "op": header["op"]}}


static func _while(state: Dictionary) -> Dictionary:
	var unit: Dictionary = state["units"][state["pos"]]
	var keyword := _first_word(unit["text"])
	var failure := _take(state, keyword, true)
	if failure != "":
		return _err(failure)
	var condition := _body(state, ["do"])
	if condition["error"] != "":
		return _err(condition["error"])
	failure = _expect(state, "do", true)
	if failure != "":
		return _err(failure)
	var body := _body(state, ["done"])
	if body["error"] != "":
		return _err(body["error"])
	failure = _expect(state, "done", false)
	if failure != "":
		return _err(failure)
	return {"error": "", "item": {"kind": "while", "cond": condition["items"], "body": body["items"], "negate": keyword == "until", "op": unit["op"]}}


static func _if(state: Dictionary, keyword: String) -> Dictionary:
	var unit: Dictionary = state["units"][state["pos"]]
	var failure := _take(state, keyword, true)
	if failure != "":
		return _err(failure)
	var condition := _body(state, ["then"])
	if condition["error"] != "":
		return _err(condition["error"])
	failure = _expect(state, "then", true)
	if failure != "":
		return _err(failure)
	var then_body := _body(state, ["elif", "else", "fi"])
	if then_body["error"] != "":
		return _err(then_body["error"])
	var else_items: Array = []
	if then_body["stop"] == "elif":
		var nested := _if(state, "elif")   # un elif es un if dentro del else; él consume el fi
		if nested["error"] != "":
			return _err(nested["error"])
		else_items = [nested["item"]]
	else:
		if then_body["stop"] == "else":
			failure = _take(state, "else", true)
			if failure != "":
				return _err(failure)
			var else_body := _body(state, ["fi"])
			if else_body["error"] != "":
				return _err(else_body["error"])
			else_items = else_body["items"]
		failure = _expect(state, "fi", false)
		if failure != "":
			return _err(failure)
	return {"error": "", "item": {"kind": "if", "cond": condition["items"], "then": then_body["items"], "else": else_items, "op": unit["op"] if keyword == "if" else ";"}}


static func _first_word(text: String) -> String:
	var words := text.split(" ", false, 1)
	return words[0] if words.size() > 0 else ""


static func _err(message: String) -> Dictionary:
	return {"items": [], "stop": "", "error": message, "item": null}


static func _fail(message: String) -> Dictionary:
	return {"units": [], "items": [], "error": message}
