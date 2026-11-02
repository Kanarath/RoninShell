extends RefCounted
## Aritmética entera para $(( ... )): números, + - * / % , menos unario y paréntesis.
## Evaluador propio (descenso recursivo): no ejecuta código, solo reconoce esos símbolos.
##
## evaluate(texto) -> {"ok": bool, "value": int, "error": String}

const MAX_LENGTH := 200

var _chars: String = ""
var _pos := 0
var _failure := ""


static func evaluate(text: String) -> Dictionary:
	var calculator := new()
	return calculator._run(text)


func _run(text: String) -> Dictionary:
	if text.length() > MAX_LENGTH:
		return _fail("expresión demasiado larga")
	_chars = text
	_pos = 0
	_failure = ""
	_skip_spaces()
	if _pos >= _chars.length():
		return _fail("expresión vacía")
	var value := _sum()
	_skip_spaces()
	if _failure == "" and _pos < _chars.length():
		_failure = "símbolo inesperado `%s'" % _chars[_pos]
	if _failure != "":
		return _fail(_failure)
	return {"ok": true, "value": value, "error": ""}


func _fail(message: String) -> Dictionary:
	return {"ok": false, "value": 0, "error": message}


func _skip_spaces() -> void:
	while _pos < _chars.length() and (_chars[_pos] == " " or _chars[_pos] == "\t"):
		_pos += 1


func _sum() -> int:
	var total := _product()
	while _failure == "":
		_skip_spaces()
		if _pos >= _chars.length() or not _chars[_pos] in ["+", "-"]:
			break
		var op := _chars[_pos]
		_pos += 1
		var right := _product()
		total = total + right if op == "+" else total - right
	return total


func _product() -> int:
	var total := _unary()
	while _failure == "":
		_skip_spaces()
		if _pos >= _chars.length() or not _chars[_pos] in ["*", "/", "%"]:
			break
		var op := _chars[_pos]
		_pos += 1
		var right := _unary()
		if _failure != "":
			break
		if op == "*":
			total = total * right
		elif right == 0:
			_failure = "división entre 0"
		elif op == "/":
			total = total / right
		else:
			total = total % right
	return total


func _unary() -> int:
	_skip_spaces()
	if _pos < _chars.length() and _chars[_pos] == "-":
		_pos += 1
		return -_unary()
	if _pos < _chars.length() and _chars[_pos] == "+":
		_pos += 1
		return _unary()
	return _atom()


func _atom() -> int:
	_skip_spaces()
	if _pos >= _chars.length():
		_failure = "falta un número"
		return 0
	if _chars[_pos] == "(":
		_pos += 1
		var inner := _sum()
		_skip_spaces()
		if _failure == "" and (_pos >= _chars.length() or _chars[_pos] != ")"):
			_failure = "falta cerrar un paréntesis"
		_pos += 1
		return inner
	var start := _pos
	while _pos < _chars.length() and _chars[_pos].is_valid_int():
		_pos += 1
	if start == _pos:
		_failure = "símbolo inesperado `%s'" % _chars[_pos]
		return 0
	return int(_chars.substr(start, _pos - start))
