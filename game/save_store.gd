extends RefCounted
## Guarda y recupera tu progreso en tu propio equipo (JSON en la carpeta de datos de la app).
## Vive fuera de engine/ a propósito: el motor del laboratorio nunca escribe en disco.
##
## Solo se escribe en rutas "user://" (la carpeta de datos de RoninShell), nunca en otro sitio.

const DEFAULT_PATH := "user://roninshell_save.json"

var path: String


func _init(save_path := DEFAULT_PATH) -> void:
	assert(save_path.begins_with("user://"), "el progreso solo se guarda dentro de user://")
	path = save_path


func has_save() -> bool:
	return FileAccess.file_exists(path)


## Devuelve true si se guardó correctamente.
func save(mission_engine: RefCounted) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar el progreso en %s" % path)
		return false
	file.store_string(JSON.stringify(mission_engine.to_dict(), "\t"))
	return true


## Carga el progreso en el motor. Devuelve false si no hay guardado o no encaja con el libro actual.
func load_into(mission_engine: RefCounted) -> bool:
	if not has_save():
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	return mission_engine.load_dict(json.data)


## Guarda datos arbitrarios (progreso de misiones + repasos). Devuelve true si se guardó.
func save_data(data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("No se pudo guardar el progreso en %s" % path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	return true


## Lee lo guardado: {} si no hay archivo o está dañado.
func load_data() -> Dictionary:
	if not has_save():
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


func delete() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
