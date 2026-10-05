class_name Ocean
extends MeshInstance3D
## Mar noturno: malha que acompanha o barco + shader com ondas. Ocean.height() repete a
## mesma fórmula do shader para o barco e a boia balançarem certinho.

const WAVES := [
	[Vector2(1.0, 0.3), 0.35, 18.0, 1.2],
	[Vector2(-0.4, 1.0), 0.22, 11.0, 1.6],
	[Vector2(0.7, -0.7), 0.12, 6.0, 2.2],
]

static var time := 0.0
static var amp := 1.0
var mat: ShaderMaterial


static func height(x: float, z: float) -> float:
	var h := 0.0
	for w in WAVES:
		var d: Vector2 = (w[0] as Vector2).normalized()
		h += float(w[1]) * amp * sin((d.x * x + d.y * z) * TAU / float(w[2]) + time * float(w[3]))
	return h


func _ready() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(320, 320)
	pm.subdivide_width = 180
	pm.subdivide_depth = 180
	mesh = pm
	mat = ShaderMaterial.new()
	mat.shader = load("res://scripts/world/ocean.gdshader")
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0


func follow(p: Vector3) -> void:
	global_position = Vector3(snappedf(p.x, 2.0), 0, snappedf(p.z, 2.0))


func set_depth(k: float) -> void:
	mat.set_shader_parameter("depth", k)


func _process(delta: float) -> void:
	time += delta
	mat.set_shader_parameter("t", time)
	mat.set_shader_parameter("amp", amp)
