extends "res://tests/framework/test_case.gd"

const Tokenizer := preload("res://engine/shell/tokenizer.gd")


## Atajo: tokeniza y devuelve solo los textos de las palabras.
func _words(line: String) -> Array:
	var result := Tokenizer.tokenize(line)
	assert_eq(result["error"], "", "no debería haber error en: %s" % line)
	var words: Array = []
	for token: Dictionary in result["tokens"]:
		words.append(token["text"] if token["type"] == "word" else "<%s>" % token["type"])
	return words


func test_palabras_simples_y_espacios_multiples() -> void:
	assert_eq(_words("ls -la /home"), ["ls", "-la", "/home"])
	assert_eq(_words("  ls    -l\t/tmp  "), ["ls", "-l", "/tmp"])


func test_linea_vacia_y_comentarios() -> void:
	assert_eq(_words(""), [])
	assert_eq(_words("   "), [])
	assert_eq(_words("# solo un comentario"), [])
	assert_eq(_words("ls # lista"), ["ls"])
	assert_eq(_words("echo a#b"), ["echo", "a#b"], "# dentro de una palabra no es comentario")


func test_comillas_simples_son_literales() -> void:
	assert_eq(_words("echo 'hola   mundo'"), ["echo", "hola   mundo"])
	assert_eq(_words("echo 'a | b > c'"), ["echo", "a | b > c"], "los operadores dentro de comillas no operan")
	assert_eq(_words("echo 'a\\b'"), ["echo", "a\\b"])


func test_comillas_dobles_y_escapes() -> void:
	assert_eq(_words("echo \"hola   mundo\""), ["echo", "hola   mundo"])
	assert_eq(_words("echo \"di \\\"hola\\\"\""), ["echo", "di \"hola\""])
	assert_eq(_words("echo \"a\\nb\""), ["echo", "a\\nb"], "en comillas dobles \\n no es un escape")


func test_comillas_vacias_crean_palabra_vacia() -> void:
	assert_eq(_words("echo ''"), ["echo", ""])
	assert_eq(_words("echo \"\" x"), ["echo", "", "x"])


func test_comillas_adyacentes_se_unen() -> void:
	assert_eq(_words("echo a'b c'd\"e f\"g"), ["echo", "ab cde fg"])


func test_barra_invertida_fuera_de_comillas() -> void:
	assert_eq(_words("echo hola\\ mundo"), ["echo", "hola mundo"])
	assert_eq(_words("echo \\| \\>"), ["echo", "|", ">"])


func test_operadores_con_y_sin_espacios() -> void:
	assert_eq(_words("a|b"), ["a", "<pipe>", "b"])
	assert_eq(_words("a | b"), ["a", "<pipe>", "b"])
	assert_eq(_words("a>f"), ["a", "<redirect>", "f"])
	assert_eq(_words("a >> f"), ["a", "<redirect>", "f"])


func test_modo_de_redireccion() -> void:
	var write = Tokenizer.tokenize("a > f")["tokens"]
	var append = Tokenizer.tokenize("a >> f")["tokens"]
	assert_eq(write[1]["mode"], "write")
	assert_eq(append[1]["mode"], "append")


func test_comillas_sin_cerrar_dan_error_como_bash() -> void:
	assert_eq(Tokenizer.tokenize("echo 'hola")["error"], "unexpected EOF while looking for matching `''")
	assert_eq(Tokenizer.tokenize("echo \"hola")["error"], "unexpected EOF while looking for matching `\"'")
