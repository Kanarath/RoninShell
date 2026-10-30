extends "res://ui/widgets/modal.gd"
## Perfil (F3): tu árbol de habilidades y tus logros. Muestra lo que has DEMOSTRADO saber hacer.

const SkillTree := preload("res://ui/widgets/skill_tree.gd")
const SealIcon := preload("res://ui/widgets/seal_icon.gd")

var tree := SkillTree.new()
var _summary := Label.new()
var _achievements := VBoxContainer.new()


func _init() -> void:
	super("Perfil", Vector2(1000, 560))
	_summary.add_theme_color_override("font_color", Palette.GOLD)
	_summary.add_theme_font_size_override("font_size", 14)
	content.add_child(_summary)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 28)
	content.add_child(columns)

	var left := VBoxContainer.new()
	left.add_child(_label("ÁRBOL DE HABILIDADES", Palette.TEXT_TITLE, 13))
	left.add_child(tree)
	left.add_child(_label("oro: por tu cuenta   teal: con ayuda   apagado: viendo la solución   candado: sin hacer", Palette.TEXT_DIM, 11))
	columns.add_child(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_label("LOGROS", Palette.TEXT_TITLE, 13))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_achievements.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achievements.add_theme_constant_override("separation", 6)
	scroll.add_child(_achievements)
	right.add_child(scroll)
	columns.add_child(right)

	content.add_child(_label("F3 o Esc para cerrar", Palette.TEXT_DIM, 12))


## summary = línea de resumen; levels/counts = del árbol; achievements = Profile.evaluate().
func refresh(summary_text: String, levels: Dictionary, counts: Dictionary, achievements: Array) -> void:
	_summary.text = summary_text
	tree.show_levels(levels, counts)
	for child in _achievements.get_children():
		_achievements.remove_child(child)
		child.queue_free()
	for item: Dictionary in achievements:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var seal := SealIcon.new()
		seal.state = SealIcon.State.DONE if item["unlocked"] else SealIcon.State.LOCKED
		seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(seal)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		texts.add_child(_label(item["title"], Palette.TEXT if item["unlocked"] else Palette.TEXT_DIM, 14))
		var description := _label(item["description"], Palette.TEXT_DIM, 11)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(description)
		row.add_child(texts)
		_achievements.add_child(row)


## Títulos de los logros mostrados, para los tests.
func shown_achievements() -> Array[String]:
	var titles: Array[String] = []
	for row in _achievements.get_children():
		var texts: Node = row.get_child(1)
		titles.append((texts.get_child(0) as Label).text)
	return titles
