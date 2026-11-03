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
##   {"kind": "case", "word", "clauses": [{"patterns", "body": [...]}], "op"}  case X in a|b) ...;; *) ...;; esac
##   {"kind": "funcdef", "name", "body": [...], "op"}                     nombre() { ...; }   /   function nombre { ...; }
## `op` es el conector que precede al elemento: "" (el primero), ";", "&&" o "||".
##
## Los errores imitan los de bash. Lo que aún no existe (select) se dice claro.

const Tokenizer := preload("res://engine/shell/tokenizer.gd")

## Palabras tras las que puede empezar un comando: ahí `case` es la palabra clave y no un argumento.
const CASE_PRECEDERS := ["", "then", "do", "else", "elif", "if", "while", "until", "{"]


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
		if c == "c" and _command_position(cur) and _word_at(line, i, "case"):
			var case_end := _case_end(line, i)
			if case_end == -1:
				return _fail("unexpected EOF while looking for `esac'")
			cur += line.substr(i, case_end - i)
			i = case_end
			continue
		elif c == "'":
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
		if word == "function" or not _function_header(unit["text"]).is_empty():
			word = "function"
		match word:
			"for":
				parsed = _for(state)
			"while", "until":
				parsed = _while(state)
			"if":
				parsed = _if(state, "if")
			"case":
				parsed = _case(state)
			"function":
				parsed = _function(state)
			"then", "elif", "else", "fi", "do", "done", "esac", "}":
				return _err("syntax error near unexpected token `%s'" % word)
			"select":
				return _err("`select' todavía no está disponible en este shell simulado")
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


## case PALABRA in patrón|patrón) comandos;; ... esac
static func _case(state: Dictionary) -> Dictionary:
	var unit: Dictionary = state["units"][state["pos"]]
	var text: String = unit["text"].substr(4).strip_edges()
	var word := _read_word(text)
	var rest: String = text.substr(word.length()).strip_edges()
	if word == "" or not (rest == "in" or rest.begins_with("in ") or rest.begins_with("in\t")):
		return _err("syntax error: usa `case PALABRA in patron) comando;; esac`")
	rest = rest.substr(2).strip_edges()
	if not rest.ends_with("esac"):
		return _err("syntax error: unexpected end of file (falta `esac')")
	var clauses_text: String = rest.substr(0, rest.length() - 4).strip_edges()
	var clauses: Array = []
	for raw: String in _split_clauses(clauses_text):
		var clause := raw.strip_edges()
		if clause == "":
			continue
		var close := _find_unquoted(clause, ")")
		if close == -1:
			return _err("syntax error near unexpected token `%s'" % clause)
		var patterns_text := clause.substr(0, close).strip_edges()
		if patterns_text.begins_with("("):
			patterns_text = patterns_text.substr(1).strip_edges()
		var patterns: Array = []
		for pattern: String in _split_unquoted(patterns_text, "|"):
			if pattern.strip_edges() != "":
				patterns.append(pattern.strip_edges())
		if patterns.is_empty():
			return _err("syntax error near unexpected token `)'")
		var body_text := clause.substr(close + 1).strip_edges()
		var body_items: Array = []
		if body_text != "":
			var parts := split(body_text)
			if parts["error"] != "":
				return _err(parts["error"])
			var built := build(parts["units"])
			if built["error"] != "":
				return _err(built["error"])
			body_items = built["items"]
		clauses.append({"patterns": patterns, "body": body_items})
	state["pos"] += 1
	return {"error": "", "item": {"kind": "case", "word": word, "clauses": clauses, "op": unit["op"]}}


## Cabecera de una función: "nombre()", "nombre() {...", "function nombre" o "function nombre()".
## Devuelve {"name", "rest"} (rest = lo que sigue a la cabecera) o {} si no lo es.
static func _function_header(text: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile("^(function\\s+)?([A-Za-z_][A-Za-z0-9_]*)(\\s*\\(\\))?\\s*(.*)$")
	var found := regex.search(text)
	if found == null:
		return {}
	if found.get_string(1) == "" and found.get_string(3) == "":
		return {}
	return {"name": found.get_string(2), "rest": found.get_string(4).strip_edges()}


static func _function(state: Dictionary) -> Dictionary:
	var units: Array = state["units"]
	var unit: Dictionary = units[state["pos"]]
	var header := _function_header(unit["text"])
	if header.is_empty():
		return _err("syntax error: usa `nombre() { comandos; }`")
	var rest: String = header["rest"]
	if rest == "" and state["pos"] + 1 < units.size() and units[state["pos"] + 1]["text"].begins_with("{"):
		state["pos"] += 1
		rest = units[state["pos"]]["text"]
	if not rest.begins_with("{"):
		return _err("syntax error: falta `{' tras `%s()'" % header["name"])
	var remaining := rest.substr(1).strip_edges()
	if remaining == "":
		state["pos"] += 1
	else:
		units[state["pos"]] = {"text": remaining, "op": ";"}
	var body := _body(state, ["}"])
	if body["error"] != "":
		return _err(body["error"])
	var failure := _expect(state, "}", false)
	if failure != "":
		return _err(failure)
	return {"error": "", "item": {"kind": "funcdef", "name": header["name"], "body": body["items"], "op": unit["op"]}}


## ¿Va a empezar un comando tras este texto? (inicio, o tras then/do/else/{ ...): ahí `case` es palabra clave.
static func _command_position(cur: String) -> bool:
	var text := cur.strip_edges()
	return text.ends_with("{") or text.get_slice(" ", text.get_slice_count(" ") - 1) in CASE_PRECEDERS


## ¿Empieza la palabra `word` en line[at] y termina ahí?
static func _word_at(line: String, at: int, word: String) -> bool:
	if line.substr(at, word.length()) != word:
		return false
	var after := at + word.length()
	return after >= line.length() or not (line[after].is_valid_identifier() or line[after].is_valid_int())


static func _is_boundary(text: String, i: int) -> bool:
	return i == 0 or text[i - 1] in [" ", "\t", ";", "(", ")", "|", "&", "{"]


## Índice justo después del esac que cierra el case que empieza en line[start] (-1 si no cierra).
static func _case_end(line: String, start: int) -> int:
	var depth := 0
	var i := start
	var n := line.length()
	while i < n:
		var c := line[i]
		if c == "'":
			var close := line.find("'", i + 1)
			if close == -1:
				return -1
			i = close + 1
			continue
		if c == "\"":
			var j := i + 1
			while j < n and line[j] != "\"":
				if line[j] == "\\":
					j += 1
				j += 1
			i = j + 1
			continue
		if _is_boundary(line, i) and _word_at(line, i, "case"):
			depth += 1
			i += 4
			continue
		if _is_boundary(line, i) and _word_at(line, i, "esac"):
			depth -= 1
			i += 4
			if depth == 0:
				return i
			continue
		i += 1
	return -1


## Trozos separados por ;; a nivel superior (sin contar los de comillas ni los de case anidados).
static func _split_clauses(text: String) -> Array:
	var parts: Array = []
	var cur := ""
	var depth := 0
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if c == "'" or c == "\"":
			var close := text.find(c, i + 1)
			if close == -1:
				close = n - 1
			cur += text.substr(i, close - i + 1)
			i = close + 1
			continue
		if _is_boundary(text, i) and _word_at(text, i, "case"):
			depth += 1
		elif _is_boundary(text, i) and _word_at(text, i, "esac"):
			depth -= 1
		if depth == 0 and c == ";" and i + 1 < n and text[i + 1] == ";":
			parts.append(cur)
			cur = ""
			i += 2
			continue
		cur += c
		i += 1
	parts.append(cur)
	return parts


## Primera palabra de un texto, respetando comillas ("a b" cuenta como una).
static func _read_word(text: String) -> String:
	if text == "":
		return ""
	if text[0] == "'" or text[0] == "\"":
		var close := text.find(text[0], 1)
		return text.substr(0, close + 1) if close != -1 else ""
	var i := 0
	while i < text.length() and not text[i] in [" ", "\t"]:
		i += 1
	return text.substr(0, i)


static func _find_unquoted(text: String, target: String) -> int:
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == "'" or c == "\"":
			var close := text.find(c, i + 1)
			if close == -1:
				return -1
			i = close + 1
			continue
		if c == target:
			return i
		i += 1
	return -1


static func _split_unquoted(text: String, separator: String) -> Array:
	var parts: Array = []
	var cur := ""
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == "'" or c == "\"":
			var close := text.find(c, i + 1)
			if close == -1:
				close = text.length() - 1
			cur += text.substr(i, close - i + 1)
			i = close + 1
			continue
		if c == separator:
			parts.append(cur)
			cur = ""
		else:
			cur += c
		i += 1
	parts.append(cur)
	return parts


static func _first_word(text: String) -> String:
	var words := text.split(" ", false, 1)
	return words[0] if words.size() > 0 else ""


static func _err(message: String) -> Dictionary:
	return {"items": [], "stop": "", "error": message, "item": null}


static func _fail(message: String) -> Dictionary:
	return {"units": [], "items": [], "error": message}
