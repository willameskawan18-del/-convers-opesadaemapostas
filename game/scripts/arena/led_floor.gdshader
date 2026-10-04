shader_type spatial;
// Piso de LED do palco: anéis concêntricos animados e grade sutil.
uniform vec4 color_a : source_color = vec4(1.0, 0.18, 0.53, 1.0);
uniform vec4 color_b : source_color = vec4(0.15, 0.88, 1.0, 1.0);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz - vec2(0.0, -4.0);
	float r = length(p);
	float rings = smoothstep(0.92, 1.0, sin(r * 2.2 - TIME * 2.0) * 0.5 + 0.5);
	vec2 g = abs(fract(wpos.xz * 0.5) - 0.5);
	float grid = smoothstep(0.47, 0.5, max(g.x, g.y));
	float ang = atan(p.y, p.x);
	vec3 col = mix(color_a.rgb, color_b.rgb, sin(ang * 3.0 + TIME * 0.5) * 0.5 + 0.5);
	ALBEDO = vec3(0.03, 0.015, 0.06);
	ROUGHNESS = 0.15;
	METALLIC = 0.4;
	EMISSION = col * (rings * 1.4 + grid * 0.25) * (0.6 + 0.4 * smoothstep(13.0, 4.0, r));
}
