extends TextureRect
## La mascota: un ronin con sombrero kasa que reacciona a lo que haces.
##   happy = objetivo completado, alert = algo falló, think = pediste ayuda, idle = en calma.
## Es solo feedback emocional rápido; la información importante siempre va en el texto.

const SpriteStore := preload("res://ui/sprite_store.gd")

const STATES := ["idle", "happy", "think", "alert"]
const SCALE := 2

var state: String = "idle"
var _timer := Timer.new()


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_timer.one_shot = true
	_timer.timeout.connect(func() -> void: _show("idle"))
	add_child(_timer)
	_show("idle")


## Cambia el gesto durante unos segundos y luego vuelve a la calma.
func react(new_state: String, seconds := 2.5) -> void:
	if not new_state in STATES:
		return
	_show(new_state)
	if new_state == "idle":
		_timer.stop()
	else:
		_timer.start(seconds)


func _show(new_state: String) -> void:
	state = new_state
	texture = SpriteStore.texture("ronin_" + new_state)
	if texture != null:
		custom_minimum_size = texture.get_size() * SCALE
