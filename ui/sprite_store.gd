extends RefCounted
## Carga los sprites de assets/sprites/ y assets/ui/ (generados con pxl, ver build_art.cmd) y los guarda en caché.
## Usa la versión importada si existe y, si no (p. ej. antes de abrir el proyecto en el editor),
## lee el PNG directamente. Los sprites son pixel art: se dibujan con filtro "nearest".

const DIR := "res://assets/sprites/"
const UI_DIR := "res://assets/ui/"

static var _cache: Dictionary = {}


static func texture(sprite_name: String) -> Texture2D:
	return _load(DIR, sprite_name)


## Arte de la interfaz (cyberdeck, compuertas, cursores).
static func ui_texture(sprite_name: String) -> Texture2D:
	return _load(UI_DIR, sprite_name)


static func _load(dir: String, sprite_name: String) -> Texture2D:
	var key := dir + sprite_name
	if _cache.has(key):
		return _cache[key]
	var path := "%s%s.png" % [dir, sprite_name]
	var loaded: Texture2D = null
	if ResourceLoader.exists(path):
		loaded = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null:
			loaded = ImageTexture.create_from_image(image)
	_cache[key] = loaded
	return loaded
