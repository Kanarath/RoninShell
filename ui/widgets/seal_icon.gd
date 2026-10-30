extends Control
## Sello de un objetivo de misión: completado, en curso, pendiente o bloqueado.
## Dibuja los sprites seal_* (pixel art generado con pxl).

const SpriteStore := preload("res://ui/sprite_store.gd")

enum State { PENDING, ACTIVE, DONE, LOCKED }

const SPRITES := {
	State.PENDING: "seal_pending",
	State.ACTIVE: "seal_active",
	State.DONE: "seal_done",
	State.LOCKED: "seal_locked",
}

var state: State = State.PENDING:
	set(value):
		state = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(22, 22)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var texture := SpriteStore.texture(SPRITES[state])
	if texture != null:
		draw_texture(texture, Vector2.ZERO)
