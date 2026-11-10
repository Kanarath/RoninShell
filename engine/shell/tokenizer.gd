extends RefCounted
## Primera etapa del intérprete: convierte una línea de texto en tokens.
##
## Soporta lo que un shell necesita para ser creíble:
##   - palabras separadas por espacios
##   - comillas simples (literal) y dobles (con \" y \\ escapados)
##   - barra invertida fuera de comillas para escapar el siguiente carácter
##   - operadores | > >> (con o sin espacios alrededor)
##   - comentarios con # al inicio de una palabra
##
## Con un `env` (la sesión) también expande, respetando las comillas:
##   $VAR  ${VAR}  $?  ~  $(comando)
## Sin comillas, el valor expandido se parte en palabras; entre comillas dobles, no; entre comillas
## simples, nunca se expande. Sin `env` no se expande nada (modo literal).
## Todavía NO soporta comodines (*): llegarán cuando una misión los necesite.
##
## `env` debe ofrecer expand_var(nombre), command_substitution(texto) y arithmetic(expresión), todos -> String.
## $(( expresión )) hace aritmética entera (+ - * / % y paréntesis; los nombres son variables).
##
## Devuelve {"tokens": Array, "error": String}. Cada token es un diccionario:
##   {"type": "word", "text": String}
##   {"type": "pipe"}
##   {"type": "redirect", "mode": "write" | "append"}

static func tokenize(line: String, env: Object = null) -> Dictionary:
	var tokens: Array = []
	var word := ""
	var glob := false      # la palabra lleva un * o ? sin comillas
	var in_word := false  # distingue "" (palabra vacía con comillas) de "no hay palabra"
	var i := 0
	var n := line.length()

	while i < n:
		var c := line[i]

		if c == " " or c == "\t":
			if in_word:
				tokens.append({"type": "word", "text": word, "glob": glob})
				glob = false
				word = ""
				in_word = false
			i += 1

		elif c == "'":
			var close := line.find("'", i + 1)
			if close == -1:
				return _fail("unexpected EOF while looking for matching `''")
			word += line.substr(i + 1, close - i - 1)
			in_word = true
			i = close + 1

		elif c == "\"":
			i += 1
			var closed := false
			while i < n:
				var d := line[i]
				if d == "\"":
					closed = true
					i += 1
					break
				if d == "$" and env != null:
					var inner := _expansion(line, i, env)
					if inner["error"] != "":
						return _fail(inner["error"])
					if inner["consumed"] > 0:
						word += inner["value"]   # entre comillas dobles el valor no se parte
						i += inner["consumed"]
						continue
				if d == "\\" and i + 1 < n and line[i + 1] in ["\"", "\\", "$", "`"]:
					word += line[i + 1]
					i += 2
				else:
					word += d
					i += 1
			if not closed:
				return _fail("unexpected EOF while looking for matching `\"'")
			in_word = true

		elif c == "\\":
			if i + 1 < n:
				word += line[i + 1]
				in_word = true
				i += 2
			else:
				word += "\\"
				in_word = true
				i += 1

		elif c == "#" and not in_word:
			break  # el resto de la línea es un comentario

		elif c == "$" and env != null:
			var outer := _expansion(line, i, env)
			if outer["error"] != "":
				return _fail(outer["error"])
			if outer["consumed"] == 0:
				word += "$"   # un $ suelto es un $ normal
				in_word = true
				i += 1
			else:
				i += outer["consumed"]
				for ch: String in outer["value"]:   # sin comillas el valor se parte en palabras
					if ch == " " or ch == "\t" or ch == "\n":
						if in_word:
							tokens.append({"type": "word", "text": word, "glob": glob})
							glob = false
							word = ""
							in_word = false
					else:
						word += ch
						glob = glob or ch == "*" or ch == "?" or ch == "["
						in_word = true

		elif c == "~" and not in_word and env != null and (i + 1 >= n or line[i + 1] in [" ", "\t", "/", "|", ">"]):
			word += env.expand_var("HOME")
			in_word = true
			i += 1

		elif c == "|" or c == ">":
			if in_word:
				tokens.append({"type": "word", "text": word, "glob": glob})
				glob = false
				word = ""
				in_word = false
			if c == "|":
				tokens.append({"type": "pipe"})
				i += 1
			elif i + 1 < n and line[i + 1] == ">":
				tokens.append({"type": "redirect", "mode": "append"})
				i += 2
			else:
				tokens.append({"type": "redirect", "mode": "write"})
				i += 1

		else:
			word += c
			glob = glob or c == "*" or c == "?" or c == "["
			in_word = true
			i += 1

	if in_word:
		tokens.append({"type": "word", "text": word, "glob": glob})
		glob = false
	return {"tokens": tokens, "error": ""}


## Lee la expansión que empieza en line[i] == "$". Devuelve {"consumed", "value", "error"};
## consumed 0 = no es una expansión (un $ suelto).
static func _expansion(line: String, i: int, env: Object) -> Dictionary:
	var n := line.length()
	if i + 1 >= n:
		return {"consumed": 0, "value": "", "error": ""}
	var next := line[i + 1]
	if next == "?":
		return {"consumed": 2, "value": env.expand_var("?"), "error": ""}
	if next == "(":
		var close := matching_paren(line, i + 1)
		if close == -1:
			return {"consumed": 0, "value": "", "error": "unexpected EOF while looking for matching `)'"}
		var inner := line.substr(i + 2, close - i - 2)
		if inner.begins_with("(") and inner.ends_with(")"):   # $(( expresión )): aritmética entera
			return {"consumed": close - i + 1, "value": env.arithmetic(inner.substr(1, inner.length() - 2)), "error": ""}
		return {"consumed": close - i + 1, "value": env.command_substitution(inner), "error": ""}
	if next == "{":
		var end := line.find("}", i + 2)
		if end == -1:
			return {"consumed": 0, "value": "", "error": "unexpected EOF while looking for matching `}'"}
		var name := line.substr(i + 2, end - i - 2)
		if not is_valid_name(name):
			return {"consumed": 0, "value": "", "error": "${%s}: bad substitution" % name}
		return {"consumed": end - i + 1, "value": env.expand_var(name), "error": ""}
	if _is_name_start(next):
		var j := i + 1
		while j < n and (_is_name_start(line[j]) or line[j].is_valid_int()):
			j += 1
		return {"consumed": j - i, "value": env.expand_var(line.substr(i + 1, j - i - 1)), "error": ""}
	if next.is_valid_int() or next == "#" or next == "@" or next == "*":
		return {"consumed": 2, "value": env.expand_var(next), "error": ""}   # $1 $2 ... $# $@ $*: argumentos de la función
	return {"consumed": 0, "value": "", "error": ""}


static func _is_name_start(c: String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


static func is_valid_name(name: String) -> bool:
	if name.is_empty() or not _is_name_start(name[0]):
		return false
	for ch: String in name:
		if not (_is_name_start(ch) or ch.is_valid_int()):
			return false
	return true


## Dado line[open] == "(", devuelve el índice del ")" que la cierra (respetando comillas y anidación) o -1.
static func matching_paren(line: String, open: int) -> int:
	var depth := 0
	var j := open
	var n := line.length()
	while j < n:
		var c := line[j]
		if c == "'":
			var q := line.find("'", j + 1)
			if q == -1:
				return -1
			j = q
		elif c == "\"":
			j += 1
			while j < n and line[j] != "\"":
				j += 2 if line[j] == "\\" else 1
		elif c == "\\":
			j += 1
		elif c == "(":
			depth += 1
		elif c == ")":
			depth -= 1
			if depth == 0:
				return j
		j += 1
	return -1


static func _fail(message: String) -> Dictionary:
	return {"tokens": [], "error": message}
