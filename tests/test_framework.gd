extends "res://tests/framework/test_case.gd"
## Comprueba que el propio marco de pruebas detecta fallos.
## Si esto fallara, los demás tests no serían de fiar.

const TestCase := preload("res://tests/framework/test_case.gd")


func test_assert_eq_pasa_si_son_iguales() -> void:
	var t := TestCase.new()
	t.assert_eq(2 + 2, 4)
	assert_eq(t.failures.size(), 0)


func test_assert_eq_registra_fallo_si_difieren() -> void:
	var t := TestCase.new()
	t.assert_eq(1, 2, "suma")
	assert_eq(t.failures.size(), 1)
	assert_true("suma" in t.failures[0], "el mensaje debe incluir el contexto")


func test_assert_true_y_false() -> void:
	var t := TestCase.new()
	t.assert_true(false)
	t.assert_false(true)
	assert_eq(t.failures.size(), 2)
