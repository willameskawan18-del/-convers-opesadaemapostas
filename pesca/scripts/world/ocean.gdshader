shader_type spatial;
render_mode cull_disabled;

uniform float t = 0.0;
uniform float depth = 0.0;     // 0 raso → 1 abismo
uniform float amp = 1.0;
varying vec3 wpos;
varying float wh;

float wave(vec2 p, vec2 d, float a, float l, float s) {
	d = normalize(d);
	return a * amp * sin(dot(d, p) * 6.2831853 / l + t * s);
}

float H(vec2 p) {
	return wave(p, vec2(1.0, 0.3), 0.35, 18.0, 1.2) + wave(p, vec2(-0.4, 1.0), 0.22, 11.0, 1.6) + wave(p, vec2(0.7, -0.7), 0.12, 6.0, 2.2);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = H(w.xz);
	VERTEX.y += h;
	float e = 0.25;
	vec3 n = normalize(vec3(H(w.xz - vec2(e, 0.0)) - H(w.xz + vec2(e, 0.0)), 2.0 * e, H(w.xz - vec2(0.0, e)) - H(w.xz + vec2(0.0, e))));
	NORMAL = (inverse(MODEL_MATRIX) * vec4(n, 0.0)).xyz;
	wpos = w;
	wh = h;
}

void fragment() {
	vec3 shallow = vec3(0.02, 0.10, 0.14);
	vec3 deep = vec3(0.005, 0.015, 0.035);
	vec3 base = mix(shallow, deep, clamp(depth, 0.0, 1.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	// pequenas ondulações
	float ripple = sin(wpos.x * 2.3 + t * 2.0) * sin(wpos.z * 1.7 - t * 1.6) * 0.5 + 0.5;
	float foam = smoothstep(0.42 * amp, 0.6 * amp, wh + ripple * 0.12);
	ALBEDO = base + vec3(0.6, 0.7, 0.8) * foam * 0.25;
	ROUGHNESS = 0.06 + ripple * 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = vec3(0.03, 0.06, 0.1) * fres * (1.0 - depth * 0.6);
	// bioluminescência no abismo
	float glow = step(0.996, fract(sin(dot(floor(wpos.xz * 1.5), vec2(12.9898, 78.233))) * 43758.5453)) * (0.5 + 0.5 * sin(t * 3.0 + wpos.x));
	EMISSION += vec3(0.1, 0.9, 1.0) * glow * depth * 1.5;
}
