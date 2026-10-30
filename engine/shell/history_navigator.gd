extends RefCounted
## Navegación por el historial con las flechas arriba/abajo, como en bash.
## Al subir guarda lo que estabas escribiendo ("borrador") y lo devuelve al bajar del todo.

var _position: int = -1   # -1 = no estamos navegando
var _draft: String = ""


## Flecha arriba: devuelve el comando anterior (o el más antiguo si ya estás en él).
func up(history: Array, current_text: String) -> String:
	if history.is_empty():
		return current_text
	if _position == -1:
		_draft = current_text
		_position = history.size()
	_position = maxi(0, _position - 1)
	return history[_position]


## Flecha abajo: devuelve el siguiente comando o, al pasar el último, tu borrador.
func down(history: Array, current_text: String) -> String:
	if _position == -1:
		return current_text
	_position += 1
	if _position >= history.size():
		_position = -1
		return _draft
	return history[_position]


## Se llama al ejecutar una línea: la próxima flecha arriba vuelve a empezar por el final.
func reset() -> void:
	_position = -1
	_draft = ""
