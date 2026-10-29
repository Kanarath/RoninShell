extends RefCounted
## Carga un laboratorio desde un archivo de datos (JSON) y lo valida.
##
## Devuelve siempre {"world": WorldState | null, "errors": Array}.
## Si hay errores, world es null: preferimos fallar con un mensaje claro
## a jugar un laboratorio incoherente.

const WorldState := preload("res://engine/world_state.gd")
const Host := preload("res://engine/host.gd")


static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"world": null, "errors": ["no existe el archivo %s" % path]}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"world": null, "errors": ["JSON inválido en %s (línea %d): %s" % [path, json.get_error_line(), json.get_error_message()]]}
	return load_dict(json.data)


static func load_dict(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {"world": null, "errors": ["el laboratorio debe ser un objeto JSON"]}

	var errors: Array = []
	var world := WorldState.new()
	world.id = str(data.get("id", ""))
	world.title = str(data.get("title", ""))
	world.cidr = str(data.get("cidr", ""))
	world.player_host_ip = str(data.get("player_host", ""))
	if world.id == "":
		errors.append("falta 'id'")

	var hosts_data = data.get("hosts", [])
	if typeof(hosts_data) != TYPE_ARRAY or hosts_data.is_empty():
		errors.append("'hosts' debe ser una lista con al menos un host")
	else:
		for host_data in hosts_data:
			var host = Host.from_dict(host_data, errors)
			if host == null:
				continue
			if world.hosts.has(host.ip):
				errors.append("IP repetida: %s" % host.ip)
				continue
			world.hosts[host.ip] = host

	if world.get_host(world.player_host_ip) == null:
		errors.append("'player_host' (%s) no coincide con ningún host" % world.player_host_ip)

	return {"world": world if errors.is_empty() else null, "errors": errors}
