class_name PlayerController
extends CharacterBody3D
## Personagem controlável: andar, correr, pular, interagir.

signal interact_target_changed(target)

const WALK := 4.2
const RUN := 7.5
const JUMP := 4.6
const GRAVITY := 14.0

var rig: CameraRig
var model: Humanoid
var input_enabled := true
var _nearby: Array = []
var _target = null
var _step_t := 0.0
var _detector: Area3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	model = Humanoid.new()
	add_child(model)
	model.setup(Color(0.95, 0.75, 0.2), Color(0.12, 0.14, 0.22), Color(0.82, 0.6, 0.45), Color(0.08, 0.05, 0.03))
	rig = CameraRig.new()
	add_child(rig)
	rig.exclude(self)
	_detector = Area3D.new()
	_detector.collision_layer = 0
	_detector.collision_mask = 4
	_detector.monitorable = false
	var ds := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.0
	ds.shape = sph
	ds.position.y = 0.9
	_detector.add_child(ds)
	add_child(_detector)
	_detector.area_entered.connect(func(a): if a is Interactable: _nearby.append(a))
	_detector.area_exited.connect(func(a): _nearby.erase(a))


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rig.rotate_by(event.relative)
	elif event.is_action_pressed("camera_toggle"):
		rig.toggle_mode()
		model.visible = rig.mode == CameraRig.Mode.THIRD_PERSON
	elif event.is_action_pressed("interact") and _target != null and is_instance_valid(_target):
		_target.interact()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	var running := false
	if input_enabled:
		var iv := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		dir = (rig.right_flat() * iv.x + rig.forward_flat() * iv.y)
		if dir.length() > 1.0:
			dir = dir.normalized()
		running = Input.is_action_pressed("sprint")
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP
	var spd := RUN if running else WALK
	var target_v := dir * spd
	var accel := 12.0 if is_on_floor() else 3.0
	velocity.x = lerpf(velocity.x, target_v.x, minf(1.0, accel * delta))
	velocity.z = lerpf(velocity.z, target_v.z, minf(1.0, accel * delta))
	velocity.y -= GRAVITY * delta
	move_and_slide()
	if global_position.y < -20.0:
		global_position = Vector3(global_position.x, 2.0, global_position.z)
		velocity = Vector3.ZERO
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.3:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(velocity.x, velocity.z), minf(1.0, 12.0 * delta))
		_step_t -= delta
		if _step_t <= 0.0 and is_on_floor():
			_step_t = 0.42 if not running else 0.3
			Audio.play("step", -14.0, randf_range(0.9, 1.1))
	model.animate(flat.length(), delta)
	_update_target()


func _update_target() -> void:
	var best = null
	var best_d := 999.0
	for a in _nearby:
		if not is_instance_valid(a) or not a.enabled or not a.is_visible_in_tree():
			continue
		var d := global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	if best != _target:
		_target = best
		interact_target_changed.emit(_target)


func current_target():
	return _target if is_instance_valid(_target) else null


func teleport(pos: Vector3, yaw: float = 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	rig.yaw = yaw
	rig.rotate_by(Vector2.ZERO)
