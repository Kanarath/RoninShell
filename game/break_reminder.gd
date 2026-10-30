extends RefCounted
## Aviso suave de descanso. Cuenta solo el tiempo de juego activo y avisa una vez cada
## "interval_minutes". Nunca bloquea nada: es una sugerencia que puedes ignorar o apagar.
## Aviso de descanso: cuando estás concentrado se pasa el tiempo sin notarlo.

var enabled: bool = true
var interval_minutes: int = 45
var _active_seconds: float = 0.0


## Suma tiempo de juego. Devuelve true cuando toca avisar (y reinicia la cuenta).
func tick(delta_seconds: float) -> bool:
	if not enabled:
		return false
	_active_seconds += delta_seconds
	if _active_seconds >= interval_minutes * 60.0:
		_active_seconds = 0.0
		return true
	return false


## Posponer: vuelve a contar desde cero.
func reset() -> void:
	_active_seconds = 0.0


func minutes_played() -> int:
	return int(_active_seconds / 60.0)
