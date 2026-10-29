extends RefCounted
## Una máquina del laboratorio: su red, sus servicios, sus usuarios y sus archivos.

const Service := preload("res://engine/service.gd")
const Vfs := preload("res://engine/vfs.gd")

var ip: String = ""
var hostname: String = ""
var os_name: String = "Linux"
var up: bool = true                  # ¿está encendida?
var responds_to_ping: bool = true    # una máquina viva puede ignorar el ping (firewall)
var services: Array = []             # de Service
var users: Array = []                # de {name, uid, home}
var fs: RefCounted = Vfs.new()


static func is_valid_ip(text: String) -> bool:
	var octets := text.split(".")
	if octets.size() != 4:
		return false
	for octet in octets:
		if not octet.is_valid_int():
			return false
		var value := int(octet)
		if value < 0 or value > 255 or str(value) != octet:
			return false
	return true


func get_service(port: int, proto := "tcp") -> RefCounted:
	for service in services:
		if service.port == port and service.proto == proto:
			return service
	return null


func has_user(user_name: String) -> bool:
	for user in users:
		if user["name"] == user_name:
			return true
	return false


## Construye un host desde datos. Añade los problemas a "errors" y devuelve null si es inutilizable.
static func from_dict(data: Variant, errors: Array) -> RefCounted:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("cada host debe ser un objeto")
		return null
	var host := new()
	host.ip = str(data.get("ip", ""))
	if not is_valid_ip(host.ip):
		errors.append("host con IP inválida: '%s'" % host.ip)
		return null
	var context := "host %s" % host.ip
	host.hostname = str(data.get("hostname", ""))
	host.os_name = str(data.get("os", "Linux"))
	host.up = bool(data.get("up", true))
	host.responds_to_ping = bool(data.get("responds_to_ping", true))

	for service_data in data.get("services", []):
		var service = Service.from_dict(service_data, errors, context)
		if service == null:
			continue
		if host.get_service(service.port, service.proto) != null:
			errors.append("%s: puerto %d/%s duplicado" % [context, service.port, service.proto])
			continue
		host.services.append(service)

	for user_data in data.get("users", []):
		if typeof(user_data) != TYPE_DICTIONARY or str(user_data.get("name", "")) == "":
			errors.append("%s: cada usuario necesita 'name'" % context)
			continue
		host.users.append({
			"name": str(user_data["name"]),
			"uid": int(user_data.get("uid", 1000)),
			"home": str(user_data.get("home", "/home/" + str(user_data["name"]))),
		})

	_load_filesystem(host, data.get("fs", {}), errors, context)
	return host


static func _load_filesystem(host: RefCounted, fs_data: Variant, errors: Array, context: String) -> void:
	if typeof(fs_data) != TYPE_DICTIONARY:
		errors.append("%s: 'fs' debe ser un objeto de ruta -> definición" % context)
		return
	# Padres antes que hijos: ordenamos por profundidad y luego alfabéticamente.
	var paths: Array = fs_data.keys()
	paths.sort_custom(func(a: String, b: String) -> bool:
		var depth_a := a.count("/")
		var depth_b := b.count("/")
		return depth_a < depth_b or (depth_a == depth_b and a < b))
	var mode_pattern := RegEx.create_from_string("^[0-7]{3}$")
	for path: String in paths:
		var spec = fs_data[path]
		if typeof(spec) != TYPE_DICTIONARY:
			errors.append("%s: '%s' debe ser un objeto" % [context, path])
			continue
		var type := str(spec.get("type", "file"))
		var owner := str(spec.get("owner", "root"))
		var group := str(spec.get("group", owner))
		var default_mode := "755" if type == "dir" else "644"
		var mode := str(spec.get("mode", default_mode))
		if mode_pattern.search(mode) == null:
			errors.append("%s: permisos inválidos '%s' en %s" % [context, mode, path])
			continue
		var added := false
		if type == "dir":
			added = host.fs.add_dir(path, owner, group, mode)
		elif type == "file":
			added = host.fs.add_file(path, str(spec.get("content", "")), owner, group, mode)
		else:
			errors.append("%s: tipo desconocido '%s' en %s" % [context, type, path])
			continue
		if not added:
			errors.append("%s: no se pudo crear %s (¿falta el directorio padre, ruta repetida o no es absoluta?)" % [context, path])
