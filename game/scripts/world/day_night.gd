class_name DayNight
extends Node3D
## Ciclo de dia e noite: céu procedural (nuvens, sol, lua, estrelas), luz do sol/lua,
## pós-processamento (AgX, SSAO, SSIL, bloom, névoa) e luzes da cidade.

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color : source_color = vec3(0.18, 0.38, 0.78);
uniform vec3 horizon_color : source_color = vec3(0.65, 0.76, 0.9);
uniform vec3 ground_color : source_color = vec3(0.12, 0.12, 0.14);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.9, 0.75);
uniform float night = 0.0;
uniform float dusk = 0.0;
uniform float cloud_cover = 0.5;

float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.02 + 17.0; a *= 0.5; } return v; }

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.45));
	if (h < 0.0) {
		col = mix(horizon_color * 0.8, ground_color, clamp(-h * 5.0, 0.0, 1.0));
	}
	vec3 sdir = normalize(LIGHT0_DIRECTION);
	float sd = max(dot(d, sdir), 0.0);
	// halo do sol no horizonte
	col += sun_tint * pow(sd, 6.0) * (0.25 + dusk * 0.6) * (1.0 - night);
	// disco do sol / lua
	float disk = smoothstep(0.9993, 0.9997, sd);
	col += mix(sun_tint * 14.0, vec3(0.75, 0.8, 0.9) * 1.6, night) * disk;
	// estrelas
	if (night > 0.01 && h > 0.0) {
		vec2 sp = d.xz / (h + 0.25) * 140.0;
		float st = step(0.9965, hash(floor(sp)));
		float tw = 0.6 + 0.4 * sin(TIME * 2.0 + hash(floor(sp) + 3.0) * 30.0);
		col += vec3(st * tw) * night * smoothstep(0.0, 0.3, h) * 0.9;
	}
	// nuvens (plano projetado)
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 1.3 + vec2(TIME * 0.006, TIME * 0.002);
		float c = fbm(uv);
		float cover = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.35, c);
		cover *= smoothstep(0.0, 0.18, h);
		float shade = fbm(uv * 1.7 + 4.0);
		vec3 lit = mix(vec3(1.0), sun_tint * 1.1, dusk * 0.7);
		vec3 cc = mix(lit * 0.95, lit * 0.6 + horizon_color * 0.2, shade);
		cc = mix(cc, vec3(0.06, 0.07, 0.11), night * 0.92);
		cc += sun_tint * pow(sd, 10.0) * 0.6 * (1.0 - night);
		col = mix(col, cc, cover * 0.92);
	}
	COLOR = col;
}
"""

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var night_factor := 0.0
var _materials_night: Array = []   # [material, energia_noite]
var _lights: Array[Light3D] = []
var _cloud_cover := 0.45


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_blur = 1.5
	sun.light_energy = 1.3
	sun.light_angular_distance = 0.6
	add_child(sun)
	sky_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	sky_mat.shader = sh
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sun_scatter = 0.25
	env.fog_aerial_perspective = 0.4
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	_cloud_cover = randf_range(0.35, 0.6)


func _apply_settings() -> void:
	var q := int(Settings.get_value("quality"))
	sun.shadow_enabled = bool(Settings.get_value("shadows"))
	sun.directional_shadow_mode = [DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS][clampi(q, 0, 2)]
	sun.directional_shadow_max_distance = [60.0, 110.0, 160.0][clampi(q, 0, 2)]
	env.ssao_enabled = q >= 1
	env.ssil_enabled = q >= 2
	env.glow_enabled = true
	env.fog_density = [0.007, 0.0038, 0.0022][clampi(int(Settings.get_value("render_distance")), 0, 2)]
	RenderingServer.directional_shadow_atlas_set_size([2048, 4096, 4096][clampi(q, 0, 2)], true)


## Materiais que acendem à noite (lâmpadas, letreiros).
func register_night_material(m: StandardMaterial3D, energy: float) -> void:
	_materials_night.append([m, energy])


func register_light(l: Light3D) -> void:
	_lights.append(l)


func set_time(minute_of_day: float) -> void:
	var h := minute_of_day / 60.0
	# Sol: nasce às 6h, se põe às 18h30. À noite a mesma luz vira o luar.
	var day_t := clampf((h - 6.0) / 12.5, 0.0, 1.0)
	var elev := sin(day_t * PI)
	var n := 0.0
	if h < 6.0 or h > 19.5:
		n = 1.0
	elif h < 7.0:
		n = 1.0 - (h - 6.0)
	elif h > 18.0:
		n = (h - 18.0) / 1.5
	night_factor = clampf(n, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(h - 18.3) / 1.1, 0.0, 1.0) + clampf(1.0 - absf(h - 6.6) / 0.8, 0.0, 1.0)
	dusk = clampf(dusk, 0.0, 1.0)
	if night_factor < 0.99:
		sun.rotation = Vector3(-deg_to_rad(6.0 + elev * 58.0), deg_to_rad(-35.0 + day_t * 70.0), 0)
	else:
		sun.rotation = Vector3(-deg_to_rad(48.0), deg_to_rad(150.0), 0)
	var sun_col := Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.62, 0.38), dusk)
	sun.light_color = sun_col.lerp(Color(0.55, 0.65, 1.0), night_factor)
	sun.light_energy = lerpf(1.35, 0.22, night_factor) * (1.0 - dusk * 0.25)
	var top := Color(0.16, 0.36, 0.76).lerp(Color(0.25, 0.3, 0.55), dusk * 0.6).lerp(Color(0.02, 0.03, 0.08), night_factor)
	var hor := Color(0.66, 0.77, 0.92).lerp(Color(0.98, 0.6, 0.38), dusk * 0.85).lerp(Color(0.08, 0.1, 0.2), night_factor)
	sky_mat.set_shader_parameter("top_color", Vector3(top.r, top.g, top.b))
	sky_mat.set_shader_parameter("horizon_color", Vector3(hor.r, hor.g, hor.b))
	sky_mat.set_shader_parameter("sun_tint", Vector3(sun_col.r, sun_col.g, sun_col.b))
	sky_mat.set_shader_parameter("night", night_factor)
	sky_mat.set_shader_parameter("dusk", dusk)
	sky_mat.set_shader_parameter("cloud_cover", _cloud_cover)
	env.ambient_light_energy = lerpf(1.0, 0.55, night_factor)
	env.fog_light_color = hor.lerp(Color(0.1, 0.12, 0.2), night_factor * 0.5)
	env.glow_intensity = lerpf(0.45, 1.1, night_factor)
	env.tonemap_exposure = lerpf(1.05, 1.35, night_factor)
	Mats.set_night(night_factor)
	for pair in _materials_night:
		pair[0].emission_energy_multiplier = lerpf(0.15, pair[1], night_factor)
	var lights_on := night_factor > 0.3
	for l in _lights:
		l.visible = lights_on
