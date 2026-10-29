extends RefCounted
## Base mínima para tests. Cada test_*.gd extiende este archivo y define
## métodos que empiezan por "test_". El runner los descubre y los ejecuta.
##
## Se extiende por ruta (no con class_name) para que funcione en un
## proyecto recién clonado, sin necesidad de importar antes en el editor.

var failures: Array[String] = []
## Cuántas comprobaciones se han hecho. Un test con 0 se considera fallo:
## suele significar que abortó antes de comprobar nada.
var assertions: int = 0


func fail(message: String) -> void:
	failures.append(message)


func assert_true(condition: bool, message: String = "se esperaba true") -> void:
	assertions += 1
	if not condition:
		fail(message)


func assert_false(condition: bool, message: String = "se esperaba false") -> void:
	assertions += 1
	if condition:
		fail(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertions += 1
	if actual != expected:
		var prefix := message + ": " if message != "" else ""
		fail("%sse esperaba %s pero fue %s" % [prefix, var_to_str(expected), var_to_str(actual)])
