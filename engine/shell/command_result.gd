extends RefCounted
## Lo que devuelve un comando: salida normal, salida de error y código de salida.
## Igual que en Unix: 0 = éxito, distinto de 0 = fallo.

var stdout: String = ""
var stderr: String = ""
var exit_code: int = 0


static func ok(output := "") -> RefCounted:
	var result := new()
	result.stdout = output
	return result


static func error(message: String, code := 1) -> RefCounted:
	var result := new()
	result.stderr = message if message.ends_with("\n") else message + "\n"
	result.exit_code = code
	return result
