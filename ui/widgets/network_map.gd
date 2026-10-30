extends Control
## Mapa de red que se va revelando según lo que descubres:
##   - tu máquina (oro) y el router siempre se ven;
##   - el resto de hosts son una silueta con "?" hasta que los descubres (ping, nmap...);
##   - bajo cada host aparecen las puertas de los puertos que has visto en un escaneo:
##     abierta (luz), filtrada (niebla) o cerrada.
## Lee el registro de eventos de la sesión: no inventa nada.

const Palette := preload("res://ui/theme/palette.gd")
const SpriteStore := preload("res://ui/sprite_store.gd")

const SCALE := 2
const LABEL_SIZE := 11
const MAX_DOORS := 4
const DOOR_SPRITES := {"open": "door_open", "filtered": "door_filtered", "closed": "door_closed"}

var world: RefCounted = null:
	set(value):
		world = value
		queue_redraw()
var session: RefCounted = null


func _init() -> void:
	custom_minimum_size = Vector2(0, 120)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Vuelve a dibujar con los últimos eventos de la sesión.
func refresh() -> void:
	queue_redraw()


## IPs de los hosts que ya conoces (los que has descubierto o de los que has visto algo).
func discovered_ips() -> Array[String]:
	var found: Array[String] = []
	if session == null:
		return found
	for event: Dictionary in session.events:
		var ip := str(event.get("ip", ""))
		if ip != "" and event["type"] in ["host_discovered", "port_found", "ping_reply", "http_response", "service_version"] and not ip in found:
			found.append(ip)
	return found


## Puertos vistos de un host: {puerto: estado}, del escaneo más reciente que lo mostró.
func ports_seen(ip: String) -> Dictionary:
	var seen := {}
	if session == null:
		return seen
	for event: Dictionary in session.events:
		if event["type"] == "port_found" and event.get("ip") == ip:
			seen[int(event["port"])] = str(event["state"])
	return seen


func _draw() -> void:
	_draw_grid()
	if world == null:
		return
	var font := ThemeDB.fallback_font
	var player_ip: String = world.player_host_ip
	var known := discovered_ips()
	var others: Array[String] = []
	for ip in world.host_ips():
		if ip != player_ip:
			others.append(ip)

	# Una sola fila, como una red local: tú, el router y el resto de hosts, unidos por un bus.
	var count := 2 + others.size()
	var row_y := size.y * 0.30
	var positions: Array[Vector2] = []
	for i in count:
		var t := 0.5 if count == 1 else float(i) / (count - 1)
		positions.append(Vector2(size.x * lerpf(0.10, 0.90, t), row_y))

	# El bus va primero, para que los nodos queden encima. Los tramos hacia hosts sin descubrir, más tenues.
	for i in range(1, count):
		var reached := i < 2 or others[i - 2] in known
		draw_line(positions[i - 1], positions[i], Palette.TEAL_DIM if reached else Color(Palette.TEAL_DIM, 0.35), 2.0, true)

	_draw_node(font, "host_you", positions[0], world.get_host(player_ip).hostname, Palette.GOLD)
	_draw_node(font, "host_router", positions[1], "router", Palette.TEXT_DIM)
	for i in others.size():
		var host: RefCounted = world.get_host(others[i])
		var spot := positions[i + 2]
		if others[i] in known:
			_draw_node(font, _sprite_for(host), spot, host.hostname, Palette.TEXT)
			_draw_doors(spot, ports_seen(others[i]), font)
		else:
			_draw_node(font, "host_ghost", spot, "???", Palette.TEAL_DIM)


func _sprite_for(host: RefCounted) -> String:
	for service in host.services:
		if service.name in ["http", "https", "ftp", "ssh"]:
			return "host_server"
	return "host_pc"


func _draw_node(font: Font, sprite_name: String, center: Vector2, label: String, color: Color) -> void:
	var texture := SpriteStore.texture(sprite_name)
	var half_height := 0.0
	if texture != null:
		var drawn := texture.get_size() * SCALE
		half_height = drawn.y / 2.0
		draw_texture_rect(texture, Rect2((center - drawn / 2.0).round(), drawn), false)
	draw_string(font, center + Vector2(-50, half_height + 12), label, HORIZONTAL_ALIGNMENT_CENTER, 100, LABEL_SIZE, color)


func _draw_doors(center: Vector2, seen: Dictionary, _font: Font) -> void:
	var ports: Array = seen.keys()
	ports.sort()
	ports = ports.slice(0, MAX_DOORS)
	if ports.is_empty():
		return
	var gap := 4.0
	var door_size := Vector2(16, 18)
	var total_width := ports.size() * door_size.x + (ports.size() - 1) * gap
	var start := Vector2(center.x - total_width / 2.0, center.y + 38)
	for i in ports.size():
		var texture := SpriteStore.texture(DOOR_SPRITES.get(seen[ports[i]], "door_closed"))
		if texture != null:
			draw_texture(texture, (start + Vector2(i * (door_size.x + gap), 0)).round())


func _draw_grid() -> void:
	var color := Color(Palette.TEAL_DIM, 0.28)
	var step := 20.0
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), color, 1.0)
		x += step
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), color, 1.0)
		y += step
