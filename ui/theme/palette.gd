extends RefCounted
## Paleta de RoninShell. Un color, un significado:
##   teal  -> información, navegación, texto de la terminal
##   oro   -> recompensas, marcos de énfasis, progreso
##   rojo  -> errores (poco, apagado)
## Los valores salen del primer concepto visual aprobado (dirección "ronin neón").

const BG := Color("05090b")           # fondo de pantalla
const PANEL := Color("08120f")        # relleno de paneles
const PANEL_DEEP := Color("050c0b")   # interior de la terminal

const TEAL := Color("5ee6cf")         # acento brillante
const TEAL_BORDER := Color("2fbfa8")  # bordes de marcos
const TEAL_DIM := Color("1f6f63")     # líneas secundarias, rejillas

const GOLD := Color("d9a441")         # recompensas y esquinas
const GOLD_DIM := Color("8a6a2c")     # oro apagado (pendiente)

const TEXT := Color("9ff2df")         # texto principal de la terminal
const TEXT_DIM := Color("6fb3a5")     # texto secundario
const TEXT_TITLE := Color("e9d9a6")   # títulos de panel (crema dorado)

const PARCHMENT := Color("d9c9a0")    # tarjetas de evidencia
const INK := Color("2a2418")          # texto sobre pergamino

const DANGER := Color("e0674f")       # errores


## Relación de contraste WCAG entre dos colores (1 a 21). Para legibilidad: >= 7 es AAA.
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	var lighter := maxf(la, lb)
	var darker := minf(la, lb)
	return (lighter + 0.05) / (darker + 0.05)


static func _luminance(c: Color) -> float:
	return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)


static func _channel(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
