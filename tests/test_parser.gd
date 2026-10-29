extends "res://tests/framework/test_case.gd"

const Tokenizer := preload("res://engine/shell/tokenizer.gd")
const Parser := preload("res://engine/shell/parser.gd")


func _parse(line: String) -> Dictionary:
	return Parser.parse(Tokenizer.tokenize(line)["tokens"])


func test_comando_simple() -> void:
	var result := _parse("ls -la /home")
	assert_eq(result["error"], "")
	assert_eq(result["commands"].size(), 1)
	assert_eq(result["commands"][0]["argv"], ["ls", "-la", "/home"])
	assert_eq(result["commands"][0]["redirect"], null)


func test_linea_vacia_no_es_un_error() -> void:
	var result := _parse("   # nada")
	assert_eq(result["error"], "")
	assert_eq(result["commands"], [])


func test_tuberia_de_tres_comandos() -> void:
	var commands: Array = _parse("cat f | grep x | wc -l")["commands"]
	assert_eq(commands.size(), 3)
	assert_eq(commands[1]["argv"], ["grep", "x"])
	assert_eq(commands[2]["argv"], ["wc", "-l"])


func test_redireccion_se_asocia_al_comando() -> void:
	var commands: Array = _parse("echo hola > out.txt")["commands"]
	assert_eq(commands[0]["argv"], ["echo", "hola"])
	assert_eq(commands[0]["redirect"], {"mode": "write", "path": "out.txt"})
	var append: Array = _parse("echo hola >> out.txt")["commands"]
	assert_eq(append[0]["redirect"]["mode"], "append")


func test_redireccion_antes_de_los_argumentos() -> void:
	var commands: Array = _parse("echo > out.txt hola")["commands"]
	assert_eq(commands[0]["argv"], ["echo", "hola"])
	assert_eq(commands[0]["redirect"]["path"], "out.txt")


func test_tuberia_con_redireccion_al_final() -> void:
	var commands: Array = _parse("cat a | sort > b")["commands"]
	assert_eq(commands.size(), 2)
	assert_eq(commands[1]["redirect"]["path"], "b")


func test_errores_de_sintaxis_como_bash() -> void:
	assert_eq(_parse("| ls")["error"], "syntax error near unexpected token `|'")
	assert_eq(_parse("ls | | wc")["error"], "syntax error near unexpected token `|'")
	assert_eq(_parse("ls >")["error"], "syntax error near unexpected token `newline'")
	assert_eq(_parse("ls > > f")["error"], "syntax error near unexpected token `>'")
	assert_eq(_parse("ls > a > b")["error"], "syntax error near unexpected token `>'")
	assert_eq(_parse("ls |")["error"], "syntax error: unexpected end of file")
	assert_eq(_parse("> f")["error"], "syntax error near unexpected token `>'")
