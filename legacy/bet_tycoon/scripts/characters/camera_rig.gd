class_name CameraRig
extends Node3D
## Câmera em terceira pessoa com SpringArm (evita atravessar paredes).
## Estruturada para suportar primeira pessoa (tecla V).

enum Mode { THIRD_PERSON, FIRST_PERSON }

const THIRD_LENGTH := 4.2
const HEIGHT := 1.55

var mode := Mode.THIRD_PERSON
var indoor := false
var yaw := 0.0
var pitch := -0.25
var camera: Camera3D
var _yaw_node: Node3D
var _pitch_node: Node3D
var _arm: SpringArm3D


func _ready() -> void:
	position = Vector3(0, HEIGHT, 0)
	_yaw_node = Node3D.new()
	add_child(_yaw_node)
	_pitch_node = Node3D.new()
	_yaw_node.add_child(_pitch_node)
	_arm = SpringArm3D.new()
	_arm.spring_length = THIRD_LENGTH
	_arm.margin = 0.2
	_arm.collision_mask = 1
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	_arm.shape = shape
	_pitch_node.add_child(_arm)
	_arm.position = Vector3(0.45, 0.15, 0)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.far = Settings.far_distance()
	_arm.add_child(camera)
	Settings.changed.connect(func(): camera.far = Settings.far_distance())
	_apply()


func exclude(body: CollisionObject3D) -> void:
	_arm.add_excluded_object(body.get_rid())


func rotate_by(rel: Vector2) -> void:
	var sens := float(Settings.get_value("mouse_sensitivity")) * 0.01
	yaw -= rel.x * sens
	var inv := -1.0 if Settings.get_value("invert_y") else 1.0
	pitch = clampf(pitch - rel.y * sens * inv, -1.3, 0.9)
	_apply()


func toggle_mode() -> void:
	mode = Mode.FIRST_PERSON if mode == Mode.THIRD_PERSON else Mode.THIRD_PERSON
	_apply()


func _apply() -> void:
	if not _yaw_node:
		return
	_yaw_node.rotation.y = yaw
	_pitch_node.rotation.x = pitch
	if mode == Mode.FIRST_PERSON:
		_arm.spring_length = 0.0
		_arm.position = Vector3(0, 0.12, -0.1)
	else:
		_arm.spring_length = 2.6 if indoor else THIRD_LENGTH
		_arm.position = Vector3(0.35, 0.25, 0) if indoor else Vector3(0.45, 0.15, 0)


func set_indoor(v: bool) -> void:
	if v == indoor:
		return
	indoor = v
	if v:
		pitch = minf(pitch, -0.45)
	_apply()


func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func right_flat() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))
