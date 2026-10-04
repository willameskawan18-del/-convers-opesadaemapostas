shader_type spatial;
render_mode unshaded;
// Lâmpadas "correndo" (letreiro de cassino/game show).
uniform vec4 color_a : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.18, 0.53, 1.0);
varying float on;

void vertex() {
	float id = float(INSTANCE_ID);
	on = step(0.5, fract(id / 4.0 - TIME * 1.5));
}

void fragment() {
	ALBEDO = mix(color_b.rgb * 0.3, color_a.rgb * 3.0, on);
}
