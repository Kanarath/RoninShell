extends Control
## Mapa de red dibujado a partir del estado real del laboratorio:
## tu máquina a la izquierda (oro), un router en el centro y el resto de hosts a la derecha.
## Por ahora muestra todo; más adelante los hosts no descubiertos aparecerán en silueta.

const Palette := preload("res://ui/theme/palette.gd")

const NODE_SIZE := Vector2(34, 26)
const LABEL_SIZE := 11

var world: RefCounted = null:
	set(value):
		world = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(0, 90)


func _draw() -> void:
	_draw_grid()
	if world == null:
		return

	var font := ThemeDB.fallback_font
	var router := Vector2(size.x * 0.5, size.y * 0.46)
	var player_ip: String = world.player_host_ip
	var others: Array[String] = []
	for ip in world.host_ips():
		if ip != player_ip:
			others.append(ip)

	var player_pos := Vector2(size.x * 0.14, size.y * 0.46)
	var targets: Array[Vector2] = []
	for i in others.size():
		var y := size.y * (0.5 if others.size() == 1 else lerpf(0.2, 0.72, float(i) / (others.size() - 1)))
		targets.append(Vector2(size.x * 0.86, y))

	# Enlaces primero, para que los nodos queden encima.
	draw_line(player_pos, router, Palette.TEAL_DIM, 1.5, true)
	for target in targets:
		draw_line(router, target, Palette.TEAL_DIM, 1.5, true)

	_draw_node(font, router, "router", Palette.TEAL)
	_draw_node(font, player_pos, world.get_host(player_ip).hostname, Palette.GOLD)
	for i in others.size():
		_draw_node(font, targets[i], world.get_host(others[i]).hostname, Palette.TEAL)


func _draw_grid() -> void:
	var color := Color(Palette.TEAL_DIM, 0.35)
	var step := 20.0
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), color, 1.0)
		x += step
	var y := 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), color, 1.0)
		y += step


func _draw_node(font: Font, center: Vector2, label: String, color: Color) -> void:
	var rect := Rect2(center - NODE_SIZE / 2.0, NODE_SIZE)
	draw_rect(rect, Palette.PANEL_DEEP)
	draw_rect(rect, color, false, 2.0)
	draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(NODE_SIZE.x - 10, 4)), Color(color, 0.6))
	draw_string(font, Vector2(center.x - 40, rect.end.y + 14), label, HORIZONTAL_ALIGNMENT_CENTER, 80, LABEL_SIZE, Palette.TEXT_DIM)
