class_name DayNight
extends Node3D
## Ciclo de dia e noite ligado ao relógio da simulação.

var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var night_factor := 0.0
var _materials_night: Array = []   # [material, energy_noite]
var _lights: Array[Light3D] = []


func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.light_energy = 1.2
	add_child(sun)
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.75, 0.85)
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	sun.shadow_enabled = bool(Settings.get_value("shadows"))
	var q := int(Settings.get_value("quality"))
	env.ssao_enabled = q >= 2
	env.glow_enabled = q >= 1
	env.fog_density = [0.012, 0.0065, 0.0035][clampi(int(Settings.get_value("render_distance")), 0, 2)]
	sun.directional_shadow_max_distance = [50.0, 90.0, 140.0][clampi(q, 0, 2)]


## Materiais que acendem à noite (janelas, lâmpadas, letreiros).
func register_night_material(m: StandardMaterial3D, energy: float) -> void:
	_materials_night.append([m, energy])


func register_light(l: Light3D) -> void:
	_lights.append(l)


func set_time(minute_of_day: float) -> void:
	var h := minute_of_day / 60.0
	# Sol: nasce às 6h, se põe às 18h30
	var day_t := clampf((h - 6.0) / 12.5, 0.0, 1.0)
	var elev := sin(day_t * PI)
	sun.rotation = Vector3(-deg_to_rad(8.0 + elev * 62.0), deg_to_rad(-40.0 + day_t * 80.0), 0)
	var n := 0.0
	if h < 6.0 or h > 19.5:
		n = 1.0
	elif h < 7.0:
		n = 1.0 - (h - 6.0)
	elif h > 18.0:
		n = (h - 18.0) / 1.5
	night_factor = clampf(n, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(h - 18.4) / 1.2, 0.0, 1.0) + clampf(1.0 - absf(h - 6.5) / 0.8, 0.0, 1.0)
	sun.light_energy = lerpf(1.25, 0.05, night_factor)
	sun.light_color = Color(1.0, 0.95, 0.88).lerp(Color(1.0, 0.6, 0.35), clampf(dusk, 0.0, 1.0))
	sky_mat.sky_top_color = Color(0.25, 0.45, 0.8).lerp(Color(0.02, 0.03, 0.08), night_factor)
	sky_mat.sky_horizon_color = Color(0.7, 0.78, 0.9).lerp(Color(0.95, 0.55, 0.35), clampf(dusk, 0.0, 1.0) * 0.8).lerp(Color(0.06, 0.07, 0.14), night_factor)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.12)
	env.ambient_light_energy = lerpf(0.9, 0.35, night_factor)
	env.fog_light_color = sky_mat.sky_horizon_color
	for pair in _materials_night:
		pair[0].emission_energy_multiplier = lerpf(0.05, pair[1], night_factor)
	var lights_on := night_factor > 0.35
	for l in _lights:
		l.visible = lights_on
