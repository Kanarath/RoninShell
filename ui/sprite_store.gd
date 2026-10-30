extends RefCounted
## Carga los sprites de assets/sprites/ (generados con pxl, ver build_art.cmd) y los guarda en caché.
## Usa la versión importada si existe y, si no (p. ej. antes de abrir el proyecto en el editor),
## lee el PNG directamente. Los sprites son pixel art: se dibujan con filtro "nearest".

const DIR := "res://assets/sprites/"

static var _cache: Dictionary = {}


static func texture(sprite_name: String) -> Texture2D:
	if _cache.has(sprite_name):
		return _cache[sprite_name]
	var path := "%s%s.png" % [DIR, sprite_name]
	var loaded: Texture2D = null
	if ResourceLoader.exists(path):
		loaded = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null:
			loaded = ImageTexture.create_from_image(image)
	_cache[sprite_name] = loaded
	return loaded
