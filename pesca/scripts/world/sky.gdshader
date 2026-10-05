shader_type sky;
// Céu noturno com estrelas, lua e brilho no horizonte.
uniform vec3 moon_dir = vec3(0.4, 0.45, -0.8);
uniform float gloom = 0.0;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = clamp(d.y, -1.0, 1.0);
	vec3 top = mix(vec3(0.01, 0.015, 0.045), vec3(0.0, 0.0, 0.01), gloom);
	vec3 hor = mix(vec3(0.05, 0.08, 0.14), vec3(0.02, 0.02, 0.04), gloom);
	vec3 col = mix(hor, top, smoothstep(-0.05, 0.5, up));
	vec3 cell = floor(d * 220.0);
	float s = hash(cell);
	float star = step(0.9975, s) * smoothstep(0.0, 0.2, up) * (0.6 + 0.4 * sin(TIME * 2.0 + s * 100.0));
	col += vec3(0.9, 0.95, 1.0) * star * (1.0 - gloom * 0.8);
	vec3 md = normalize(moon_dir);
	float m = dot(d, md);
	col += vec3(0.9, 0.95, 1.0) * smoothstep(0.9993, 0.9997, m) * (1.0 - gloom * 0.7);
	col += vec3(0.25, 0.3, 0.45) * pow(max(m, 0.0), 60.0) * 0.6 * (1.0 - gloom);
	COLOR = col;
}
