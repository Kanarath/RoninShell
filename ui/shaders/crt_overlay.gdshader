shader_type canvas_item;
// VFX mínimo: líneas de escaneo muy suaves, viñeta y una franja que baja despacio.
// Se dibuja encima de todo y NO toca el texto: la legibilidad manda.
// intensity = 0 lo apaga por completo (ajuste de accesibilidad).

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec3 sweep_color : source_color = vec3(0.37, 0.9, 0.81);

void fragment() {
	// Líneas de escaneo: una de cada tres filas de píxeles, muy tenue.
	float line = step(2.0, mod(FRAGCOORD.y, 3.0)) * 0.10;

	// Viñeta: oscurece los bordes.
	vec2 d = UV - vec2(0.5);
	float vignette = smoothstep(0.35, 0.85, length(d * vec2(1.0, 1.15))) * 0.45;

	// Franja suave que recorre la pantalla de arriba abajo cada ~12 s.
	float y = fract(TIME / 12.0);
	float band = smoothstep(0.06, 0.0, abs(UV.y - y)) * 0.035;

	float alpha = clamp(line + vignette, 0.0, 0.6) * intensity;
	vec3 rgb = mix(vec3(0.0), sweep_color, band / max(alpha + band, 0.0001));
	COLOR = vec4(rgb, alpha + band * intensity);
}
