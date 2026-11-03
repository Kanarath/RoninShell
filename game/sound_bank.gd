extends RefCounted
## Sonidos suaves de micro-victoria, generados por código (sin archivos de audio).
## Son campanillas cortas y agradables; no hay ningún sonido de error ni de castigo.

const MIX_RATE := 22050
const AMPLITUDE := 0.4

## Cada sonido es una lista de notas [frecuencia en Hz, duración en ms].
const SOUNDS := {
	"objetivo": [[659.0, 90], [880.0, 170]],
	"mision": [[523.0, 90], [659.0, 90], [784.0, 90], [1047.0, 280]],
	"logro": [[784.0, 90], [1047.0, 90], [1319.0, 300]],
	# Sonidos del cyberdeck: interruptor, compuertas y subida de nivel (todos suaves y cortos).
	"clic": [[1500.0, 22], [900.0, 30]],
	"encendido": [[587.0, 60]],
	"compuerta": [[110.0, 150], [82.0, 260]],
	"nivel": [[523.0, 80], [659.0, 80], [784.0, 80], [1047.0, 80], [1319.0, 360]],
}


static func names() -> Array:
	return SOUNDS.keys()


## Número de muestras de un sonido (para comprobar su duración).
static func sample_count(sound_name: String) -> int:
	var total := 0
	for note: Array in SOUNDS.get(sound_name, []):
		total += int(MIX_RATE * float(note[1]) / 1000.0)
	return total


## Devuelve el sonido listo para reproducir, o null si no existe.
static func make(sound_name: String) -> AudioStreamWAV:
	if not SOUNDS.has(sound_name):
		return null
	var data := PackedByteArray()
	data.resize(sample_count(sound_name) * 2)
	var offset := 0
	for note: Array in SOUNDS[sound_name]:
		var frequency: float = note[0]
		var length := int(MIX_RATE * float(note[1]) / 1000.0)
		for i in length:
			var t := float(i) / MIX_RATE
			var attack := minf(1.0, float(i) / (MIX_RATE * 0.005))   # entrada suave: sin "clics"
			var envelope := attack * exp(-3.0 * float(i) / length)
			var wave := sin(TAU * frequency * t) + 0.25 * sin(TAU * 2.0 * frequency * t)
			data.encode_s16(offset, clampi(int(wave * envelope * AMPLITUDE * 32767.0), -32768, 32767))
			offset += 2
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
