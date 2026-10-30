extends RefCounted
## Guarda y lee los ajustes en tu equipo (user://), igual que el progreso.

const Settings := preload("res://game/settings.gd")
const DEFAULT_PATH := "user://roninshell_settings.json"

var path: String


func _init(settings_path := DEFAULT_PATH) -> void:
	assert(settings_path.begins_with("user://"), "los ajustes solo se guardan dentro de user://")
	path = settings_path


func has_file() -> bool:
	return FileAccess.file_exists(path)


## Devuelve los ajustes guardados o los de por defecto si no hay archivo o está dañado.
func load_settings() -> RefCounted:
	if not has_file():
		return Settings.new()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return Settings.new()
	return Settings.from_dict(json.data)


func save(settings: RefCounted) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(settings.to_dict(), "\t"))
	return true


func delete() -> void:
	if has_file():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
