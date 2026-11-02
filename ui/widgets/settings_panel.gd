extends "res://ui/widgets/modal.gd"
## Menú de ajustes (F10). Cada cambio se aplica al instante y se emite con "changed".

signal changed(settings: RefCounted)

const Settings := preload("res://game/settings.gd")

var vfx_enabled := CheckButton.new()
var vfx_intensity := HSlider.new()
var font_size := HSlider.new()
var high_contrast := CheckButton.new()
var mascot_enabled := CheckButton.new()
var break_enabled := CheckButton.new()
var break_minutes := HSlider.new()
var _font_value := Label.new()
var _break_value := Label.new()
var _vfx_value := Label.new()
var sound_enabled := CheckButton.new()
var sound_volume := HSlider.new()
var _sound_value := Label.new()
var _tutorial_done := false   # no tiene control: solo se conserva para no perderlo al guardar
var _loading := false


func _init() -> void:
	super("Ajustes", Vector2(620, 440))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	content.add_child(grid)

	_toggle_row(grid, "Efectos visuales (líneas de escaneo, viñeta)", vfx_enabled)
	_slider_row(grid, "Intensidad de los efectos", vfx_intensity, 0.0, 1.0, 0.05, _vfx_value)
	_slider_row(grid, "Tamaño de letra de la terminal", font_size, Settings.FONT_MIN, Settings.FONT_MAX, 1.0, _font_value)
	_toggle_row(grid, "Alto contraste en la terminal", high_contrast)
	_toggle_row(grid, "Mostrar la mascota", mascot_enabled)
	_toggle_row(grid, "Sonidos suaves al lograr algo", sound_enabled)
	_slider_row(grid, "Volumen de los sonidos", sound_volume, 0.0, 1.0, 0.05, _sound_value)
	_toggle_row(grid, "Aviso suave de descanso", break_enabled)
	_slider_row(grid, "Minutos entre avisos de descanso", break_minutes, Settings.BREAK_MIN, Settings.BREAK_MAX, 5.0, _break_value)

	var reset := Button.new()
	reset.text = "Restablecer valores"
	reset.pressed.connect(func() -> void:
		var defaults: RefCounted = Settings.new()
		defaults.tutorial_done = _tutorial_done   # restablecer ajustes no vuelve a mostrar el tutorial
		apply(defaults)
		changed.emit(settings_from_controls()))
	content.add_child(reset)
	content.add_child(_label("F10 o Esc para cerrar. Los cambios se guardan solos.", Palette.TEXT_DIM, 12))
	apply(Settings.new())


## Pone los controles con estos ajustes, sin emitir "changed".
func apply(settings: RefCounted) -> void:
	_loading = true
	vfx_enabled.button_pressed = settings.vfx_enabled
	vfx_intensity.value = settings.vfx_intensity
	font_size.value = settings.font_size
	high_contrast.button_pressed = settings.high_contrast
	mascot_enabled.button_pressed = settings.mascot_enabled
	break_enabled.button_pressed = settings.break_enabled
	break_minutes.value = settings.break_minutes
	sound_enabled.button_pressed = settings.sound_enabled
	sound_volume.value = settings.sound_volume
	_tutorial_done = settings.tutorial_done
	_refresh_values()
	_loading = false


func settings_from_controls() -> RefCounted:
	return Settings.from_dict({
		"vfx_enabled": vfx_enabled.button_pressed, "vfx_intensity": vfx_intensity.value,
		"font_size": int(font_size.value), "high_contrast": high_contrast.button_pressed,
		"mascot_enabled": mascot_enabled.button_pressed, "break_enabled": break_enabled.button_pressed,
		"break_minutes": int(break_minutes.value),
		"sound_enabled": sound_enabled.button_pressed, "sound_volume": sound_volume.value, "tutorial_done": _tutorial_done,
	})


func _toggle_row(grid: GridContainer, text: String, control: CheckButton) -> void:
	grid.add_child(_label(text, Palette.TEXT, 14))
	grid.add_child(control)
	grid.add_child(Control.new())
	control.toggled.connect(func(_on: bool) -> void: _on_changed())


func _slider_row(grid: GridContainer, text: String, slider: HSlider, low: float, high: float, step: float, value_label: Label) -> void:
	grid.add_child(_label(text, Palette.TEXT, 14))
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(170, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(_v: float) -> void: _on_changed())
	grid.add_child(slider)
	value_label.add_theme_color_override("font_color", Palette.GOLD)
	value_label.custom_minimum_size = Vector2(50, 0)
	grid.add_child(value_label)


func _on_changed() -> void:
	_refresh_values()
	if not _loading:
		changed.emit(settings_from_controls())


func _refresh_values() -> void:
	_vfx_value.text = "%d %%" % int(round(vfx_intensity.value * 100.0))
	_font_value.text = "%d px" % int(font_size.value)
	_break_value.text = "%d min" % int(break_minutes.value)
	_sound_value.text = "%d %%" % int(round(sound_volume.value * 100.0))
