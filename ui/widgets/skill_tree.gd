extends Control
## Árbol de habilidades: un nodo por concepto, agrupados por tema y unidos en el orden en que se aprenden.
##   oro = lo hiciste por tu cuenta, teal = con ayuda, apagado = viendo la solución, candado = sin hacer.
## Se ilumina con lo que has DEMOSTRADO, no con lo que has leído.

const Palette := preload("res://ui/theme/palette.gd")
const SpriteStore := preload("res://ui/sprite_store.gd")
const Profile := preload("res://engine/profile.gd")

const SCALE := 2
const SPRITE_BY_LEVEL := {"solo": "seal_done", "ayuda": "seal_active", "solucion": "seal_pending", "": "seal_locked"}

var levels: Dictionary = {}    # concepto -> "solo" | "ayuda" | "solucion"
var counts: Dictionary = {}    # concepto -> objetivos completados


func _init() -> void:
	custom_minimum_size = Vector2(520, 440)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func show_levels(new_levels: Dictionary, new_counts: Dictionary) -> void:
	levels = new_levels
	counts = new_counts
	queue_redraw()


## Estado de un concepto para dibujarlo ("" = sin hacer).
func level_of(concept: String) -> String:
	return levels.get(concept, "")


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var row_height := size.y / Profile.TREE.size()
	for row in Profile.TREE.size():
		var group: Dictionary = Profile.TREE[row]
		var top := row * row_height
		draw_string(font, Vector2(4, top + 16), str(group["title"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.GOLD)
		var concepts: Array = group["concepts"]
		var step := size.x / 5.0   # hasta cinco conceptos por fila
		var y := top + row_height * 0.52
		# Líneas primero, para que los nodos queden encima.
		for i in range(1, concepts.size()):
			var learned: bool = level_of(concepts[i][0]) != ""
			draw_line(Vector2(step * (i - 1) + step / 2.0, y), Vector2(step * i + step / 2.0, y), Palette.TEAL_BORDER if learned else Palette.TEAL_DIM, 2.0, true)
		for i in concepts.size():
			var concept: String = concepts[i][0]
			var center := Vector2(step * i + step / 2.0, y)
			var level := level_of(concept)
			var texture := SpriteStore.texture(SPRITE_BY_LEVEL[level])
			if texture != null:
				var drawn := texture.get_size() * SCALE
				draw_texture_rect(texture, Rect2((center - drawn / 2.0).round(), drawn), false)
			var color := Palette.TEXT if level == "solo" else (Palette.TEAL if level == "ayuda" else Palette.TEXT_DIM)
			draw_string(font, center + Vector2(-step / 2.0, 27), concepts[i][1], HORIZONTAL_ALIGNMENT_CENTER, step, 12, color)
			if counts.get(concept, 0) > 0:
				draw_string(font, center + Vector2(18, -8), "×%d" % counts[concept], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.GOLD_DIM)   # junto al sello: no gasta altura
