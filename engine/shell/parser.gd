extends RefCounted
## Segunda etapa: ordena los tokens en una "tubería" de comandos.
##
## Resultado: {"commands": Array, "error": String}. Cada comando es:
##   {"argv": Array[String], "redirect": null | {"mode": "write"|"append", "path": String}}
##
## Los mensajes de error imitan los de bash, para que equivocarse enseñe
## lo mismo que enseñaría una terminal real.

static func parse(tokens: Array) -> Dictionary:
	var commands: Array = []
	var argv: Array = []
	var redirect = null
	var pending_mode := ""  # modo de la redirección que espera su destino

	for token: Dictionary in tokens:
		match token["type"]:
			"word":
				if pending_mode != "":
					redirect = {"mode": pending_mode, "path": token["text"]}
					pending_mode = ""
				else:
					argv.append(token["text"])
			"redirect":
				if pending_mode != "":
					return _fail(">" if token["mode"] == "write" else ">>")
				if redirect != null:
					return _fail(">" if token["mode"] == "write" else ">>")  # una sola redirección por comando
				pending_mode = token["mode"]
			"pipe":
				if pending_mode != "":
					return _fail("|")
				if argv.is_empty():
					return _fail("|")
				commands.append({"argv": argv, "redirect": redirect})
				argv = []
				redirect = null

	if pending_mode != "":
		return _fail("newline")
	if argv.is_empty():
		if commands.is_empty() and redirect == null:
			return {"commands": [], "error": ""}  # línea vacía o solo un comentario
		if not commands.is_empty():
			return {"commands": [], "error": "syntax error: unexpected end of file"}
		return _fail(">" if redirect["mode"] == "write" else ">>")
	commands.append({"argv": argv, "redirect": redirect})
	return {"commands": commands, "error": ""}


static func _fail(token: String) -> Dictionary:
	return {"commands": [], "error": "syntax error near unexpected token `%s'" % token}
