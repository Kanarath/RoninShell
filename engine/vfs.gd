extends RefCounted
## Sistema de archivos virtual de un host. Todo vive en memoria: nada toca el disco real.
##
## Cada nodo es un diccionario: {type: "dir"|"file", content, owner, group, mode}.
## "mode" se guarda como texto octal ("644") igual que lo mostraría chmod.

var _nodes: Dictionary = {}  # ruta absoluta -> nodo


func _init() -> void:
	_nodes["/"] = _make_node("dir", "", "root", "root", "755")


## Convierte una ruta (absoluta o relativa a cwd) en una ruta absoluta limpia.
## Resuelve ".", ".." y barras repetidas, como haría un shell. ".." en la raíz se queda en la raíz.
static func normalize(cwd: String, path: String) -> String:
	if path == "":
		return normalize("/", cwd)
	var raw := path if path.begins_with("/") else cwd + "/" + path
	var parts: Array[String] = []
	for part in raw.split("/", false):
		if part == ".":
			continue
		if part == "..":
			if not parts.is_empty():
				parts.pop_back()
		else:
			parts.append(part)
	return "/" + "/".join(parts)


func add_dir(path: String, owner := "root", group := "root", mode := "755") -> bool:
	return _add(path, _make_node("dir", "", owner, group, mode))


func add_file(path: String, content: String, owner := "root", group := "root", mode := "644") -> bool:
	return _add(path, _make_node("file", content, owner, group, mode))


enum WriteResult { OK, NO_PARENT, NOT_DIR_PARENT, IS_DIR }

const DIR_SIZE := 4096  # tamaño que muestra ls -l para un directorio, como en Linux


## ¿Puede "user" hacer "want" ("r", "w" o "x") sobre "path"?
## user = {name, uid, groups}. Sigue las reglas de Unix:
##   - root (uid 0) puede todo.
##   - se aplica UNA sola clase: dueño, si no grupo, si no "otros".
##   - para llegar a un archivo hace falta permiso "x" en cada directorio del camino.
func check_access(path: String, user: Dictionary, want: String) -> bool:
	if int(user.get("uid", 1000)) == 0:
		return true
	var ancestor := path.get_base_dir()
	while ancestor != "/" and ancestor != "":
		if not _mode_allows(ancestor, user, "x"):
			return false
		ancestor = ancestor.get_base_dir()
	if path != "/" and not _mode_allows("/", user, "x"):
		return false
	return _mode_allows(path, user, want)


func _mode_allows(path: String, user: Dictionary, want: String) -> bool:
	if not _nodes.has(path):
		return false
	var node: Dictionary = _nodes[path]
	var who := 2  # otros
	if node["owner"] == user.get("name", ""):
		who = 0
	elif node["group"] in user.get("groups", [user.get("name", "")]):
		who = 1
	var digit := int(str(node["mode"])[who])
	var bit: int = {"r": 4, "w": 2, "x": 1}[want]
	return (digit & bit) != 0


func set_mode(path: String, mode: String) -> bool:
	if not _nodes.has(path):
		return false
	_nodes[path]["mode"] = mode
	return true


## Permisos en texto, como los muestra ls -l: "drwxr-x---" o "-rw-r--r--".
func mode_string(path: String) -> String:
	if not _nodes.has(path):
		return ""
	var node: Dictionary = _nodes[path]
	var text: String = "d" if node["type"] == "dir" else "-"
	for who in 3:
		var digit := int(str(node["mode"])[who])
		text += "r" if digit & 4 else "-"
		text += "w" if digit & 2 else "-"
		text += "x" if digit & 1 else "-"
	return text


func size_of(path: String) -> int:
	if not _nodes.has(path):
		return 0
	if _nodes[path]["type"] == "dir":
		return DIR_SIZE
	return (_nodes[path]["content"] as String).to_utf8_buffer().size()


## Escribe (o añade a) un archivo, creándolo si no existe. Es lo que usa ">" y ">>".
## Todavía no comprueba permisos: llegarán con los comandos de archivos (paso 4).
func write_file(path: String, content: String, append := false, owner := "root", group := "root") -> WriteResult:
	if is_dir(path):
		return WriteResult.IS_DIR
	var parent := path.get_base_dir()
	if not exists(parent):
		return WriteResult.NO_PARENT
	if not is_dir(parent):
		return WriteResult.NOT_DIR_PARENT
	if is_file(path):
		_nodes[path]["content"] = (_nodes[path]["content"] + content) if append else content
	else:
		add_file(path, content, owner, group, "644")
	return WriteResult.OK


func exists(path: String) -> bool:
	return _nodes.has(path)


func is_dir(path: String) -> bool:
	return _nodes.has(path) and _nodes[path]["type"] == "dir"


func is_file(path: String) -> bool:
	return _nodes.has(path) and _nodes[path]["type"] == "file"


## Copia del nodo (modificarla no altera el sistema de archivos). Vacío si no existe.
func get_node_info(path: String) -> Dictionary:
	if not _nodes.has(path):
		return {}
	return (_nodes[path] as Dictionary).duplicate()


func read_file(path: String) -> String:
	if not is_file(path):
		return ""
	return _nodes[path]["content"]


## Nombres (no rutas) de lo que hay directamente dentro de un directorio, ordenados.
func list_dir(path: String) -> Array[String]:
	var names: Array[String] = []
	if not is_dir(path):
		return names
	for candidate: String in _nodes:
		if candidate != "/" and candidate.get_base_dir() == path:
			names.append(candidate.get_file())
	names.sort()
	return names


func all_paths() -> Array[String]:
	var paths: Array[String] = []
	for path: String in _nodes:
		paths.append(path)
	paths.sort()
	return paths


func _add(path: String, node: Dictionary) -> bool:
	if normalize("/", path) != path or path == "/":
		return false  # solo rutas absolutas ya limpias
	if _nodes.has(path):
		return false
	if not is_dir(path.get_base_dir()):
		return false  # el directorio padre debe existir
	_nodes[path] = node
	return true


static func _make_node(type: String, content: String, owner: String, group: String, mode: String) -> Dictionary:
	return {"type": type, "content": content, "owner": owner, "group": group, "mode": mode}
