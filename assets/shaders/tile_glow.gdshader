// assets/shaders/tile_glow.gdshader
// Borde dorado pulsante para casillas activas (donde está la pieza)
shader_type canvas_item;

uniform float glow_speed: hint_range(0.5, 4.0) = 1.8;
uniform float glow_strength: hint_range(0.0, 1.0) = 0.6;
uniform vec4 glow_color: source_color = vec4(0.788, 0.659, 0.298, 1.0); // #C9A84C
uniform float border_width: hint_range(1.0, 8.0) = 3.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;

	// Detectar si estamos cerca del borde
	float left   = UV.x * size.x;
	float right  = (1.0 - UV.x) * size.x;
	float top    = UV.y * size.y;
	float bottom = (1.0 - UV.y) * size.y;
	float edge   = min(min(left, right), min(top, bottom));
	float border = clamp(1.0 - edge / border_width, 0.0, 1.0);

	// Pulso animado
	float pulse = (sin(TIME * glow_speed) * 0.5 + 0.5) * glow_strength;

	// Mezclar el borde dorado con la textura original
	vec4 final_color = mix(tex, glow_color, border * pulse);
	final_color.a = tex.a;

	COLOR = final_color;
}
