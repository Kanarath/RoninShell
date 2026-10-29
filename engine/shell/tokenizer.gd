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
## Todavía NO soporta variables ($HOME), comodines (*) ni sustitución de comandos:
## llegarán en fases posteriores, cuando una misión los necesite.
##
## Devuelve {"tokens": Array, "error": String}. Cada token es un diccionario:
##   {"type": "word", "text": String}
##   {"type": "pipe"}
##   {"type": "redirect", "mode": "write" | "append"}

static func tokenize(line: String) -> Dictionary:
	var tokens: Array = []
	var word := ""
	var in_word := false  # distingue "" (palabra vacía con comillas) de "no hay palabra"
	var i := 0
	var n := line.length()

	while i < n:
		var c := line[i]

		if c == " " or c == "\t":
			if in_word:
				tokens.append({"type": "word", "text": word})
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

		elif c == "|" or c == ">":
			if in_word:
				tokens.append({"type": "word", "text": word})
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
			in_word = true
			i += 1

	if in_word:
		tokens.append({"type": "word", "text": word})
	return {"tokens": tokens, "error": ""}


static func _fail(message: String) -> Dictionary:
	return {"tokens": [], "error": message}
