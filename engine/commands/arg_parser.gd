extends RefCounted
## Lector de opciones estilo Unix compartido por los comandos.
##
## Entiende "-l", "-la" (varias juntas), "-n 5" y "-n5" (opciones con valor) y "--".
## Devuelve {"flags": {letra: true}, "values": {letra: texto}, "rest": Array, "error": String}.
## El texto del error imita el de los comandos reales: "invalid option -- 'z'".

static func parse(args: Array, flag_chars: String, value_chars := "") -> Dictionary:
	var flags := {}
	var values := {}
	var rest: Array = []
	var options_done := false
	var i := 0

	while i < args.size():
		var arg: String = args[i]
		if options_done or not arg.begins_with("-") or arg == "-":
			rest.append(arg)
			i += 1
			continue
		if arg == "--":
			options_done = true
			i += 1
			continue

		var j := 1
		while j < arg.length():
			var letter := arg[j]
			if flag_chars.contains(letter):
				flags[letter] = true
				j += 1
			elif value_chars.contains(letter):
				var value := arg.substr(j + 1)
				if value == "":
					i += 1
					if i >= args.size():
						return _result(flags, values, rest, "option requires an argument -- '%s'" % letter)
					value = args[i]
				values[letter] = value
				j = arg.length()
			else:
				return _result(flags, values, rest, "invalid option -- '%s'" % letter)
		i += 1

	return _result(flags, values, rest, "")


static func _result(flags: Dictionary, values: Dictionary, rest: Array, error: String) -> Dictionary:
	return {"flags": flags, "values": values, "rest": rest, "error": error}
