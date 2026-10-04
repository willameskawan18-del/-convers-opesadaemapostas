shader_type spatial;
// Plateia: cada pessoa pula/balança conforme a energia do público.
uniform float energy = 0.3;
varying vec3 col;

void vertex() {
	float id = float(INSTANCE_ID);
	float ph = fract(sin(id * 12.9898) * 43758.5453) * 6.283;
	float jump = max(0.0, sin(TIME * (6.0 + fract(id * 0.37) * 4.0) + ph));
	VERTEX.y += jump * energy * 0.45;
	VERTEX.x += sin(TIME * 1.5 + ph) * 0.05;
	col = COLOR.rgb;
}

void fragment() {
	ALBEDO = col;
	ROUGHNESS = 0.7;
	RIM = 0.4;
}
