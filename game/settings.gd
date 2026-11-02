extends RefCounted
## Ajustes del jugador: efectos visuales, tamaño de letra, contraste, mascota y aviso de descanso.
## Pensados para que la experiencia se adapte a ti (sesiones largas, vista cansada, poca concentración),
## nunca para penalizar. Valores siempre dentro de rangos seguros.

const FONT_MIN := 12
const FONT_MAX := 28
const BREAK_MIN := 10
const BREAK_MAX := 120

var vfx_enabled: bool = true
var vfx_intensity: float = 1.0     # 0..1; 0 equivale a apagarlo
var font_size: int = 17            # tamaño de letra de la terminal
var high_contrast: bool = false    # texto de la terminal casi blanco
var mascot_enabled: bool = true
var break_enabled: bool = true     # aviso suave de descanso
var break_minutes: int = 45
var sound_enabled: bool = true     # campanillas suaves al lograr algo
var sound_volume: float = 0.5      # 0..1
var tutorial_done: bool = false    # el tutorial inicial solo se abre solo la primera vez


func to_dict() -> Dictionary:
	return {
		"vfx_enabled": vfx_enabled, "vfx_intensity": vfx_intensity, "font_size": font_size,
		"high_contrast": high_contrast, "mascot_enabled": mascot_enabled,
		"break_enabled": break_enabled, "break_minutes": break_minutes,
		"sound_enabled": sound_enabled, "sound_volume": sound_volume, "tutorial_done": tutorial_done,
	}


## Construye ajustes desde datos guardados, corrigiendo lo que esté fuera de rango o mal tipado.
static func from_dict(data: Variant) -> RefCounted:
	var settings := new()
	if typeof(data) != TYPE_DICTIONARY:
		return settings
	settings.vfx_enabled = _as_bool(data.get("vfx_enabled"), true)
	settings.vfx_intensity = clampf(_as_number(data.get("vfx_intensity"), 1.0), 0.0, 1.0)
	settings.font_size = clampi(int(_as_number(data.get("font_size"), 17.0)), FONT_MIN, FONT_MAX)
	settings.high_contrast = _as_bool(data.get("high_contrast"), false)
	settings.mascot_enabled = _as_bool(data.get("mascot_enabled"), true)
	settings.break_enabled = _as_bool(data.get("break_enabled"), true)
	settings.break_minutes = clampi(int(_as_number(data.get("break_minutes"), 45.0)), BREAK_MIN, BREAK_MAX)
	settings.sound_enabled = _as_bool(data.get("sound_enabled"), true)
	settings.sound_volume = clampf(_as_number(data.get("sound_volume"), 0.5), 0.0, 1.0)
	settings.tutorial_done = _as_bool(data.get("tutorial_done"), false)
	return settings


## Un archivo dañado o editado a mano puede traer cualquier tipo: nunca debe romper el juego.
static func _as_bool(value: Variant, fallback: bool) -> bool:
	return value if typeof(value) == TYPE_BOOL else fallback


static func _as_number(value: Variant, fallback: float) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	return fallback
