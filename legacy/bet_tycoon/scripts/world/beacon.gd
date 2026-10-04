class_name Beacon
extends Node3D
## Marcador vertical de luz (objetivo / trabalho). Opcionalmente detecta a chegada do jogador.

signal reached

var _label: Label3D
var _area: Area3D
var _t := 0.0


static func create(color: Color, text: String, detect: bool) -> Beacon:
	var b := Beacon.new()
	b._build(color, text, detect)
	return b


func _build(color: Color, text: String, detect: bool) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cyl := WorldKit.cylinder(self, 0.7, 30.0, Vector3(0, 15.0, 0), m, 16)
	cyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := WorldKit.cylinder(self, 1.3, 0.05, Vector3(0, 0.15, 0), m, 24)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label = WorldKit.label(self, text, Vector3(0, 3.2, 0), 72, color.lightened(0.4), 14, true)
	_label.no_depth_test = true
	_label.fixed_size = false
	if detect:
		_area = Area3D.new()
		_area.collision_layer = 0
		_area.collision_mask = 2
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 1.6
		sh.height = 4.0
		cs.shape = sh
		cs.position.y = 2.0
		_area.add_child(cs)
		add_child(_area)
		_area.body_entered.connect(func(_b): reached.emit())


func set_text(t: String) -> void:
	_label.text = t


func _process(delta: float) -> void:
	_t += delta
	_label.position.y = 3.2 + sin(_t * 2.0) * 0.25
