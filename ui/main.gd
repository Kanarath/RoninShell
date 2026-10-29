extends Control
## Pantalla principal provisional. La interfaz solo muestra; la lógica vive en engine/.

const GAME_NAME := "RoninShell"


func _ready() -> void:
	$Title.text = "%s  -  paso 1: esqueleto" % GAME_NAME
	$Title.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55))
