extends Control
## Sello circular para los objetivos de misión: completado, en curso o pendiente.

const Palette := preload("res://ui/theme/palette.gd")

enum State { PENDING, ACTIVE, DONE }

var state: State = State.PENDING:
	set(value):
		state = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(24, 24)


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 2.0
	match state:
		State.DONE:
			draw_circle(center, radius, Color(Palette.GOLD, 0.25))
			draw_arc(center, radius, 0.0, TAU, 32, Palette.GOLD, 2.0, true)
			draw_polyline(PackedVector2Array([
				center + Vector2(-5, 0), center + Vector2(-1.5, 4), center + Vector2(5, -4),
			]), Palette.GOLD, 2.5, true)
		State.ACTIVE:
			draw_arc(center, radius, 0.0, TAU, 32, Palette.TEAL, 2.0, true)
			draw_circle(center, 3.0, Palette.TEAL)
		State.PENDING:
			draw_arc(center, radius, 0.0, TAU, 32, Palette.GOLD_DIM, 1.5, true)
