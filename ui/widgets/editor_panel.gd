extends "res://ui/widgets/modal.gd"
## Editor de texto sencillo (nano). Edita un archivo del laboratorio, nunca del sistema real.
## Ctrl+S guarda; Esc cierra (si hay cambios sin guardar, avisa y hace falta pulsar Esc otra vez).

signal saved

const ButtonStyle := preload("res://ui/theme/button_style.gd")
const Vfs := preload("res://engine/vfs.gd")

var text_edit := TextEdit.new()
var session: RefCounted = null
var path: String = ""
var shown: String = ""
var dirty := false
var _status := Label.new()
var _loaded_text := ""
var _warned_discard := false
var _mono := SystemFont.new()


func _init() -> void:
	super("Editor", Vector2(900, 520))
	_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])

	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.add_theme_font_override("font", _mono)
	text_edit.add_theme_font_size_override("font_size", 16)
	text_edit.add_theme_color_override("font_color", Palette.TEXT)
	text_edit.add_theme_color_override("background_color", Palette.PANEL_DEEP)
	text_edit.add_theme_color_override("caret_color", Palette.GOLD)
	text_edit.add_theme_color_override("selection_color", Color(Palette.TEAL, 0.3))
	text_edit.add_theme_color_override("current_line_color", Color(Palette.TEAL, 0.06))
	text_edit.text_changed.connect(_on_text_changed)
	content.add_child(text_edit)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	content.add_child(bar)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_status.add_theme_font_size_override("font_size", 13)
	bar.add_child(_status)
	var save_button := Button.new()
	save_button.text = "Guardar (Ctrl+S)"
	ButtonStyle.apply(save_button, Palette.GOLD)
	save_button.pressed.connect(func() -> void: save())
	bar.add_child(save_button)
	var close_button := Button.new()
	close_button.text = "Cerrar (Esc)"
	ButtonStyle.apply(close_button)
	close_button.pressed.connect(func() -> void: request_close())
	bar.add_child(close_button)


## Abre un archivo de la sesión (o uno nuevo, vacío, si no existe).
func open_file(lab_session: RefCounted, file_path: String, shown_name: String) -> void:
	session = lab_session
	path = file_path
	shown = shown_name
	_loaded_text = session.host.fs.read_file(path) if session.host.fs.is_file(path) else ""
	text_edit.text = _loaded_text
	text_edit.set_caret_line(text_edit.get_line_count() - 1)
	text_edit.set_caret_column(text_edit.get_line(text_edit.get_line_count() - 1).length())
	dirty = false
	_warned_discard = false
	frame.title = "nano  ·  %s" % shown
	_status.text = "Ctrl+S guarda  ·  Esc cierra"
	open()
	text_edit.grab_focus.call_deferred()


## Guarda en el laboratorio comprobando permisos. Devuelve {ok, message}.
func save() -> Dictionary:
	if session == null:
		return {"ok": false, "message": "No hay ningún archivo abierto."}
	var fs = session.host.fs
	var user: Dictionary = session.user
	var target := path if fs.exists(path) else path.get_base_dir()
	if not fs.check_access(target, user, "w"):
		_status.text = "No se puede guardar: Permission denied"
		_status.add_theme_color_override("font_color", Palette.DANGER)
		return {"ok": false, "message": "Permission denied"}
	var outcome: int = fs.write_file(path, text_edit.text, false, user["name"], user["name"])
	if outcome != Vfs.WriteResult.OK:
		_status.text = "No se puede guardar: ruta no válida"
		_status.add_theme_color_override("font_color", Palette.DANGER)
		return {"ok": false, "message": "ruta no válida"}
	session.record("file_edited", {"path": path})
	_loaded_text = text_edit.text
	dirty = false
	_warned_discard = false
	_status.text = "Guardado."
	_status.add_theme_color_override("font_color", Palette.GOLD)
	saved.emit()
	return {"ok": true, "message": "Guardado."}


## Esc: cierra. Con cambios sin guardar avisa primero y cierra a la segunda.
## Devuelve true si se cerró.
func request_close() -> bool:
	if dirty and not _warned_discard:
		_warned_discard = true
		_status.text = "Hay cambios sin guardar: Ctrl+S los guarda, Esc otra vez los descarta."
		_status.add_theme_color_override("font_color", Palette.DANGER)
		return false
	close()
	return true


func _on_text_changed() -> void:
	dirty = text_edit.text != _loaded_text
	_warned_discard = false
	if dirty:
		_status.text = "Modificado (sin guardar)"
		_status.add_theme_color_override("font_color", Palette.TEXT_DIM)


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S and event.ctrl_pressed:
		save()
		get_viewport().set_input_as_handled()
