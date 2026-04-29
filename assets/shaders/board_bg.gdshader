// assets/shaders/board_bg.gdshader
// Fondo del tablero: pergamino oscuro con viñeta y textura procedural
shader_type canvas_item;

uniform float vignette_strength: hint_range(0.0, 2.0) = 0.8;
uniform float grain_strength: hint_range(0.0, 0.1) = 0.025;
uniform vec4 base_color: source_color = vec4(0.05, 0.04, 0.015, 1.0);
uniform vec4 vignette_color: source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float time_scale: hint_range(0.0, 1.0) = 0.15;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = rand(i);
	float b = rand(i + vec2(1.0, 0.0));
	float c = rand(i + vec2(0.0, 1.0));
	float d = rand(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;

	// Textura de pergamino procedural
	float n1 = noise(uv * 8.0);
	float n2 = noise(uv * 16.0 + 0.5);
	float grain = (n1 * 0.6 + n2 * 0.4) * grain_strength;

	// Viñeta
	vec2 center = uv - 0.5;
	float vignette = 1.0 - dot(center, center) * vignette_strength * 2.5;
	vignette = clamp(vignette, 0.0, 1.0);

	// Variación de color sutil (efecto pergamino envejecido)
	vec4 parchment = base_color + vec4(grain, grain * 0.8, grain * 0.3, 0.0);

	COLOR = mix(vignette_color, parchment, vignette);
	COLOR.a = 1.0;
}
