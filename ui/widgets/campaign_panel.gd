extends "res://ui/widgets/modal.gd"
## Resumen de campaña (F5): los laboratorios de un vistazo, con su estado y tu progreso en cada uno.
## Cambiar de laboratorio sigue siendo cosa del comando `laboratorio <id>`: esto es solo para mirar.

const SealIcon := preload("res://ui/widgets/seal_icon.gd")

signal lab_chosen(id: String)

var _rows := VBoxContainer.new()
var _summary := Label.new()


func _init() -> void:
	super("Campaña", Vector2(760, 520))
	_summary.add_theme_color_override("font_color", Palette.GOLD)
	_summary.add_theme_font_size_override("font_size", 14)
	content.add_child(_summary)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)
	content.add_child(scroll)

	content.add_child(_label("oro: completado   teal: el que juegas ahora   candado: bloqueado   F5 o Esc para cerrar", Palette.TEXT_DIM, 12))


## entries = [{id, title, state, active, missions_done, missions_total, xp}], en el orden de la campaña.
func refresh(entries: Array) -> void:
	var done := 0
	for entry: Dictionary in entries:
		done += 1 if entry["state"] == "completado" else 0
	_summary.text = "%d de %d laboratorios completados" % [done, entries.size()]
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for entry: Dictionary in entries:
		_rows.add_child(_row(entry))


func _row(entry: Dictionary) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)

	var seal := SealIcon.new()
	seal.state = _seal_state(entry)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(seal)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	var title_color: Color = Palette.TEXT_DIM if entry["state"] == "bloqueado" else (Palette.TEAL if entry["active"] else Palette.TEXT)
	var title := _label(str(entry["title"]).to_upper() + ("  (activo)" if entry["active"] else ""), title_color, 14)
	texts.add_child(title)
	texts.add_child(_label(_progress_text(entry), Palette.TEXT_DIM, 12))
	box.add_child(texts)
	return box


func _seal_state(entry: Dictionary) -> SealIcon.State:
	match str(entry["state"]):
		"completado":
			return SealIcon.State.DONE
		"bloqueado":
			return SealIcon.State.LOCKED
		_:
			return SealIcon.State.ACTIVE if entry["active"] else SealIcon.State.PENDING


func _progress_text(entry: Dictionary) -> String:
	if entry["state"] == "bloqueado":
		return "Bloqueado: completa antes el laboratorio anterior"
	if entry["state"] == "completado":
		return "Completado  ·  %d XP" % entry["xp"]
	return "Misión %d de %d  ·  %d XP" % [entry["missions_done"] + 1, entry["missions_total"], entry["xp"]]
