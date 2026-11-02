extends RefCounted
## Cursor del ratón con el estilo del cyberdeck (flecha dorada, mano teal y cursor de texto).
## El arte es de 12x17 px y se amplía x2 sin suavizar para que los píxeles queden nítidos.

const SpriteStore := preload("res://ui/sprite_store.gd")

const SCALE := 2


static func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_load_cursor("cursor_arrow", Input.CURSOR_ARROW, Vector2(2, 2))
	_load_cursor("cursor_link", Input.CURSOR_POINTING_HAND, Vector2(2, 2))
	_load_cursor("cursor_text", Input.CURSOR_IBEAM, Vector2(7, 17))


static func _load_cursor(art_name: String, shape: Input.CursorShape, hotspot_art: Vector2) -> void:
	var texture := SpriteStore.ui_texture(art_name)
	if texture == null:
		return
	var image := texture.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	image.resize(image.get_width() * SCALE, image.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(image), shape, hotspot_art * SCALE)
