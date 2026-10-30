extends "res://ui/widgets/modal.gd"
## Chuleta visual de comandos (F1). Lee los mismos datos que el comando `cheatsheet`,
## así que no hay dos listas que mantener ni que se contradigan.

const CommandDocs := preload("res://engine/commands/command_docs.gd")

var _mono := SystemFont.new()


func _init() -> void:
	super("Chuleta de comandos", Vector2(940, 560))
	_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 28)
	content.add_child(columns)

	# Reparte las secciones en dos columnas equilibradas por número de filas.
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for column: VBoxContainer in [left, right]:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 3)
		columns.add_child(column)
	var left_rows := 0
	var right_rows := 0
	for section: Array in CommandDocs.CHEATSHEET:
		var rows: int = section[2].size() + 2
		if left_rows <= right_rows:
			_add_section(left, section)
			left_rows += rows
		else:
			_add_section(right, section)
			right_rows += rows

	content.add_child(_label("F1 o Esc para cerrar   ·   `man <comando>` o `<comando> --help` para más detalle", Palette.TEXT_DIM, 12))


func _add_section(column: VBoxContainer, section: Array) -> void:
	var heading := _label(section[1], Palette.GOLD, 14)
	heading.add_theme_constant_override("line_spacing", 0)
	column.add_child(heading)
	for row: Array in section[2]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var command := _label(row[0], Palette.TEAL, 13)
		command.add_theme_font_override("font", _mono)
		command.custom_minimum_size = Vector2(230, 0)
		line.add_child(command)
		var meaning := _label(row[1], Palette.TEXT_DIM, 12)
		meaning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meaning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(meaning)
		column.add_child(line)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	column.add_child(spacer)
