class_name Mats
## Materiais procedurais (shaders) do jogo. Tudo é gerado por código, sem texturas externas:
## coordenadas de mundo (triplanar simplificado) evitam problemas de UV nas malhas primitivas.
## Os materiais são cacheados e compartilhados; `set_night()` atualiza todos de uma vez.

static var _cache: Dictionary = {}
static var _night_targets: Array[ShaderMaterial] = []

const COMMON := """
varying vec3 wpos;
varying vec3 wnrm;
float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.03; a *= 0.5; } return v; }
// Coordenada 2D da face dominante (paredes usam xy/zy, pisos usam xz)
vec2 face_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	if (a.y > a.x && a.y > a.z) return p.xz;
	if (a.x > a.z) return vec2(p.z, p.y);
	return vec2(p.x, p.y);
}
"""

const VERT := """
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
"""


static func _shader(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s


static func _cached(key: String, builder: Callable) -> Material:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


static func set_night(f: float) -> void:
	for m in _night_targets:
		m.set_shader_parameter("night", f)


# --- Chão -------------------------------------------------------------------

static func asphalt() -> Material:
	return _cached("asphalt", func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + VERT + """
uniform vec3 base : source_color = vec3(0.12, 0.125, 0.14);
void fragment() {
	vec2 p = wpos.xz;
	float n = fbm(p * 0.3);
	float grain = vnoise(p * 9.0);
	float patch_m = smoothstep(0.6, 0.64, fbm(p * 0.07 + 3.1));
	vec3 c = base * (0.82 + 0.35 * n) + (grain - 0.5) * 0.03;
	c = mix(c, c * 0.72, patch_m);
	float crack = smoothstep(0.015, 0.0, abs(fbm(p * 0.5 + 7.0) - 0.5)) * 0.35;
	c *= 1.0 - crack;
	ALBEDO = c;
	ROUGHNESS = 0.82 - 0.2 * patch_m;
	SPECULAR = 0.35;
}
""")
		return m)


static func sidewalk() -> Material:
	return _cached("sidewalk", func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + VERT + """
uniform vec3 base : source_color = vec3(0.66, 0.64, 0.6);
void fragment() {
	vec2 p = face_uv(wpos, wnrm) / 1.1;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float w = 0.035;
	vec2 aa = fwidth(p) * 1.5;
	float grout = 1.0 - smoothstep(w, w + aa.x, f.x) * smoothstep(w, w + aa.y, f.y);
	float tint = hash21(cell) * 0.12;
	vec3 c = base * (0.92 + tint) * (0.9 + 0.12 * fbm(wpos.xz * 1.7));
	c = mix(c, c * 0.62, grout);
	float dirt = smoothstep(0.55, 0.8, fbm(wpos.xz * 0.15));
	c *= 1.0 - dirt * 0.18;
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
""")
		return m)


static func grass() -> Material:
	return _cached("grass", func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + VERT + """
void fragment() {
	vec2 p = wpos.xz;
	float n = fbm(p * 0.25);
	float d = fbm(p * 2.5);
	vec3 a = vec3(0.2, 0.36, 0.14);
	vec3 b = vec3(0.34, 0.5, 0.2);
	vec3 dry = vec3(0.5, 0.48, 0.26);
	vec3 c = mix(a, b, n);
	c = mix(c, dry, smoothstep(0.62, 0.8, fbm(p * 0.05 + 9.0)) * 0.5);
	c *= 0.85 + 0.3 * d;
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
""")
		return m)


static func paving(col: Color) -> Material:
	return _cached("paving" + col.to_html(), func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + VERT + """
uniform vec3 base : source_color;
void fragment() {
	vec2 p = wpos.xz * vec2(1.6, 3.2);
	p.x += step(1.0, mod(floor(p.y), 2.0)) * 0.5;
	vec2 f = fract(p);
	vec2 aa = fwidth(p) * 1.5;
	float g = 1.0 - smoothstep(0.05, 0.05 + aa.x, f.x) * smoothstep(0.08, 0.08 + aa.y, f.y);
	vec3 c = base * (0.88 + 0.2 * hash21(floor(p)));
	ALBEDO = mix(c, c * 0.6, g);
	ROUGHNESS = 0.85;
}
""")
		m.set_shader_parameter("base", Vector3(col.r, col.g, col.b))
		return m)


# --- Construções -----------------------------------------------------------------

## kind: 0 reboco, 1 tijolo, 2 painéis de concreto, 3 metal ondulado
static func facade(col: Color, kind: int = 0) -> Material:
	return _cached("facade%d_%s" % [kind, col.to_html()], func():
		var m := ShaderMaterial.new()
		m.shader = _facade_shader()
		m.set_shader_parameter("base", Vector3(col.r, col.g, col.b))
		m.set_shader_parameter("kind", kind)
		return m)


static var _facade_sh: Shader


static func _facade_shader() -> Shader:
	if _facade_sh:
		return _facade_sh
	_facade_sh = _shader("shader_type spatial;\n" + COMMON + VERT + """
uniform vec3 base : source_color;
uniform int kind = 0;
void fragment() {
	vec2 p = face_uv(wpos, wnrm);
	vec3 c = base;
	float rough = 0.9;
	if (kind == 1) {
		vec2 b = p / vec2(0.5, 0.2);
		b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
		vec2 f = fract(b);
		vec2 aa = fwidth(b) * 1.5;
		float mortar = 1.0 - smoothstep(0.04, 0.04 + aa.x, f.x) * smoothstep(0.1, 0.1 + aa.y, f.y);
		c *= 0.8 + 0.35 * hash21(floor(b));
		c = mix(c, vec3(0.72, 0.7, 0.66), mortar * 0.85);
	} else if (kind == 2) {
		vec2 b = p / vec2(3.0, 1.5);
		vec2 f = fract(b);
		vec2 aa = fwidth(b) * 1.5;
		float seam = 1.0 - smoothstep(0.01, 0.01 + aa.x, f.x) * smoothstep(0.02, 0.02 + aa.y, f.y);
		c *= 0.92 + 0.12 * hash21(floor(b));
		c *= 1.0 - seam * 0.25;
	} else if (kind == 3) {
		float rib = 0.5 + 0.5 * sin(p.x * 18.0);
		c *= 0.85 + 0.2 * rib;
		rough = 0.45;
		METALLIC = 0.55;
	} else {
		c *= 0.9 + 0.14 * fbm(p * 1.4);
	}
	// sujeira perto do chão e manchas de chuva
	float ground = 1.0 - smoothstep(0.0, 1.2, wpos.y);
	c *= 1.0 - ground * 0.28;
	float streak = fbm(vec2(p.x * 3.0, p.y * 0.25)) ;
	c *= 1.0 - smoothstep(0.55, 0.85, streak) * 0.12;
	ALBEDO = c;
	ROUGHNESS = rough;
}
""")
	return _facade_sh


## Vidro de janela. À noite algumas janelas acendem (sorteio por célula).
static func window_glass(lit_ratio: float = 0.55) -> Material:
	return _cached("glass%.2f" % lit_ratio, func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + VERT + """
uniform float night = 0.0;
uniform float lit_ratio = 0.55;
void fragment() {
	vec2 p = face_uv(wpos, wnrm);
	vec2 cell = floor(p / vec2(1.6, 3.0)) + floor(wpos.xz * 0.05) * 13.0;
	float h = hash21(cell);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 sky = mix(vec3(0.18, 0.24, 0.32), vec3(0.55, 0.65, 0.78), clamp(p.y * 0.08, 0.0, 1.0));
	ALBEDO = mix(vec3(0.04, 0.06, 0.08), sky, 0.35 + 0.4 * fres);
	METALLIC = 0.4;
	ROUGHNESS = 0.06;
	float lit = step(1.0 - lit_ratio, h) * night;
	vec3 warm = mix(vec3(1.0, 0.78, 0.45), vec3(0.75, 0.85, 1.0), step(0.85, fract(h * 7.0)));
	// interior simulado: luz mais forte embaixo, cortina em cima
	float curtain = smoothstep(0.65, 0.7, fract(p.y / 3.0 + 0.1));
	EMISSION = warm * lit * (1.6 - curtain * 0.9) * (0.7 + 0.6 * fract(h * 31.0));
}
""")
		m.set_shader_parameter("lit_ratio", lit_ratio)
		_night_targets.append(m)
		return m)


## Vitrine de loja: reflexo de dia e interior iluminado (suave) à noite.
static func storefront() -> Material:
	return _cached("storefront", func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + VERT + """
uniform float night = 0.0;
void fragment() {
	vec2 p = face_uv(wpos, wnrm);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 sky = mix(vec3(0.2, 0.26, 0.33), vec3(0.6, 0.7, 0.8), 0.5 + 0.5 * fres);
	ALBEDO = mix(vec3(0.05, 0.07, 0.09), sky, 0.3 + 0.4 * fres);
	METALLIC = 0.35;
	ROUGHNESS = 0.05;
	float shelf = 0.75 + 0.25 * step(0.5, fract(p.y * 1.2));
	float lamp = 0.6 + 0.4 * smoothstep(0.0, 1.0, fract(p.x * 0.35));
	EMISSION = vec3(1.0, 0.8, 0.55) * night * 0.28 * shelf * lamp;
}
""")
		_night_targets.append(m)
		return m)


## Carpete estampado de cassino.
static func carpet(base: Color, accent: Color) -> Material:
	return _cached("carpet%s%s" % [base.to_html(), accent.to_html()], func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + VERT + """
uniform vec3 base : source_color;
uniform vec3 accent : source_color;
void fragment() {
	vec2 p = wpos.xz / 1.4;
	vec2 f = fract(p) - 0.5;
	float diamond = smoothstep(0.32, 0.28, abs(f.x) + abs(f.y));
	float ring = smoothstep(0.03, 0.0, abs(length(f) - 0.18));
	float dots = smoothstep(0.06, 0.03, length(fract(p * 2.0 + 0.25) - 0.5));
	vec3 c = mix(base, base * 1.35, diamond);
	c = mix(c, accent, ring * 0.9 + dots * 0.35);
	c *= 0.9 + 0.15 * vnoise(wpos.xz * 6.0);
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
""")
		m.set_shader_parameter("base", Vector3(base.r, base.g, base.b))
		m.set_shader_parameter("accent", Vector3(accent.r, accent.g, accent.b))
		return m)


static func roof() -> Material:
	return _cached("roof", func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + VERT + """
void fragment() {
	vec2 p = wpos.xz;
	vec3 c = vec3(0.32, 0.32, 0.34) * (0.8 + 0.3 * fbm(p * 0.6));
	c *= 1.0 - smoothstep(0.6, 0.8, fbm(p * 0.2)) * 0.2;
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
""")
		return m)


## Telhas cerâmicas para casas.
static func tiles(col: Color) -> Material:
	return _cached("tiles" + col.to_html(), func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + VERT + """
uniform vec3 base : source_color;
void fragment() {
	vec3 a = abs(wnrm);
	vec2 p = (a.x > a.z) ? vec2(wpos.z, wpos.y * 2.2 + wpos.x) : vec2(wpos.x, wpos.y * 2.2 + wpos.z);
	vec2 b = p / vec2(0.35, 0.28);
	b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
	vec2 f = fract(b);
	float shade = 0.75 + 0.25 * smoothstep(0.0, 0.8, f.y);
	vec3 c = base * shade * (0.85 + 0.25 * hash21(floor(b)));
	ALBEDO = c;
	ROUGHNESS = 0.7;
}
""")
		m.set_shader_parameter("base", Vector3(col.r, col.g, col.b))
		return m)


static func awning(a: Color, b: Color) -> Material:
	return _cached("awning%s%s" % [a.to_html(), b.to_html()], func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\nrender_mode cull_disabled;\n" + COMMON + VERT + """
uniform vec3 ca : source_color;
uniform vec3 cb : source_color;
void fragment() {
	vec3 an = abs(wnrm);
	float coord = (an.x > an.z) ? wpos.z : wpos.x;
	float s = step(0.5, fract(coord / 0.9));
	ALBEDO = mix(ca, cb, s) * (0.9 + 0.1 * vnoise(wpos.xz * 4.0));
	ROUGHNESS = 0.8;
}
""")
		m.set_shader_parameter("ca", Vector3(a.r, a.g, a.b))
		m.set_shader_parameter("cb", Vector3(b.r, b.g, b.b))
		return m)


# --- Natureza ----------------------------------------------------------------------

static func leaves(col: Color) -> Material:
	return _cached("leaves" + col.to_html(), func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + """
uniform vec3 base : source_color;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float sway = sin(TIME * 1.3 + wpos.x * 0.4 + wpos.z * 0.3) * 0.06 + sin(TIME * 3.1 + wpos.y * 2.0) * 0.02;
	VERTEX.x += sway * max(VERTEX.y + 0.5, 0.0);
	VERTEX.z += sway * 0.6 * max(VERTEX.y + 0.5, 0.0);
}
void fragment() {
	float n = fbm(wpos.xz * 2.2 + wpos.y * 1.5);
	float clump = vnoise(wpos.xy * 6.0 + wpos.z * 4.0);
	vec3 c = base * (0.65 + 0.5 * n) * (0.85 + 0.25 * clump);
	c += vec3(0.08, 0.1, 0.0) * smoothstep(0.3, 1.0, wnrm.y);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.25, 0.35, 0.1);
}
""")
		m.set_shader_parameter("base", Vector3(col.r, col.g, col.b))
		return m)


static func bark() -> Material:
	return _cached("bark", func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + VERT + """
void fragment() {
	float n = vnoise(vec2(atan(wnrm.z, wnrm.x) * 3.0, wpos.y * 9.0));
	ALBEDO = vec3(0.32, 0.22, 0.14) * (0.65 + 0.5 * n);
	ROUGHNESS = 0.95;
}
""")
		return m)


static func water() -> Material:
	return _cached("water", func():
		var m := ShaderMaterial.new()
		m.shader = _shader("shader_type spatial;\n" + COMMON + VERT + """
void fragment() {
	vec2 p = wpos.xz;
	float w = vnoise(p * 3.0 + TIME * 0.6) * 0.5 + vnoise(p * 7.0 - TIME * 0.9) * 0.5;
	ALBEDO = mix(vec3(0.05, 0.22, 0.32), vec3(0.2, 0.5, 0.6), w * 0.5);
	METALLIC = 0.2;
	ROUGHNESS = 0.05 + w * 0.1;
	NORMAL_MAP = normalize(vec3(w - 0.5, (vnoise(p * 5.0 + TIME) - 0.5), 1.0)) * 0.5 + 0.5;
}
""")
		return m)


# --- Objetos -------------------------------------------------------------------------

static func car_paint(col: Color) -> Material:
	return _cached("car" + col.to_html(), func():
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.metallic = 0.55
		m.roughness = 0.22
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.clearcoat_roughness = 0.05
		return m)


static func metal(col: Color = Color(0.6, 0.62, 0.65), rough: float = 0.35) -> Material:
	return _cached("metal%s%.2f" % [col.to_html(), rough], func():
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.metallic = 0.85
		m.roughness = rough
		return m)


static func plastic(col: Color, rough: float = 0.55) -> Material:
	return _cached("plastic%s%.2f" % [col.to_html(), rough], func():
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		return m)


static func glow(col: Color, energy: float = 3.0) -> Material:
	return _cached("glow%s%.1f" % [col.to_html(), energy], func():
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = energy
		return m)


static func skin(col: Color) -> Material:
	return _cached("skin" + col.to_html(), func():
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.6
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.35
		m.rim_enabled = true
		m.rim = 0.25
		m.rim_tint = 0.6
		return m)


static func cloth(col: Color) -> Material:
	return _cached("cloth" + col.to_html(), func():
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.88
		m.rim_enabled = true
		m.rim = 0.2
		m.rim_tint = 0.5
		return m)
