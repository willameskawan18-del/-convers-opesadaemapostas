class_name PlayerController
extends Node3D
## Pescador local em primeira pessoa, andando no convés (coordenadas do barco).
## WASD anda · mouse olha · clique pesca · E interage · F lanterna · no timão WASD pilota.

signal prompt_changed(text: String)

const SPEED := 2.6
const EYE := 1.62
var boat: Boat
var creatures: Creatures
var cam: Camera3D
var fishing: Fishing
var yaw := PI
var pitch := 0.0
var driving := false
var _pose_t := 0.0
var _input_t := 0.0
var _repair_t := 0.0
var _hit_cd := 0.0
var _prompt := ""
var _bob := 0.0
var enabled := true


func _ready() -> void:
	position = Vector3(0, 0.6, 0.6)
	cam = Camera3D.new()
	cam.fov = 75
	cam.near = 0.05
	cam.position = Vector3(0, EYE, 0)
	add_child(cam)
	cam.make_current()
	fishing = Fishing.new()
	add_child(fishing)
	fishing.setup(cam)
	fishing.caught.connect(func(f): Game.request("catch", [f]))
	fishing.landed.connect(_show_landed)


## O peixe sai da água, voa até a sua frente, gira um pouco e vai para a caixa.
func _show_landed(f: Dictionary, from: Vector3) -> void:
	var fish := FishModel.build(f)
	get_tree().root.add_child(fish)
	fish.global_position = from
	FishModel.splash(get_tree().root, from, true)
	var hold := cam.global_position - cam.global_transform.basis.z * 1.3 + Vector3(0, -0.15, 0)
	var tw := fish.create_tween()
	tw.tween_property(fish, "global_position", hold, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(fish, "rotation:y", TAU, 0.55)
	tw.tween_property(fish, "rotation:y", TAU + PI, 1.4)
	tw.tween_property(fish, "global_position", boat.to_global(boat.cooler_pos), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(fish, "scale", Vector3.ONE * 0.1, 0.45)
	tw.tween_callback(fish.queue_free)
	var tail := fish.get_node_or_null("Tail") as Node3D
	if tail:
		var tt := tail.create_tween().set_loops(8)
		tt.tween_property(tail, "rotation:y", 0.6, 0.08)
		tt.tween_property(tail, "rotation:y", -0.6, 0.08)


func sensitivity() -> float:
	return 0.0025 * float(Settings.get_value("sensitivity"))


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity()
		pitch = clampf(pitch - event.relative.y * sensitivity(), -1.35, 1.35)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if driving:
			return
		if event.pressed:
			if _aiming_tentacle() and not fishing.busy():
				_hit_tentacle()
			else:
				fishing.press()
		else:
			fishing.release()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_interact()
			KEY_F:
				Game.request("lantern")
				Audio.play("click")


func _interact() -> void:
	if driving:
		Game.request("drive", [false])
		return
	var target := _target()
	match str(target.get("kind", "")):
		"wheel":
			fishing.cancel()
			Game.request("drive", [true])
		"cooler":
			get_tree().call_group("dock_ui", "open_cooler")


## O que o jogador está olhando: timão, caixa térmica ou um vazamento.
func _target() -> Dictionary:
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var best: Dictionary = {}
	var best_d := INF
	var cands := [
		{"kind": "wheel", "pos": boat.to_global(boat.wheel_pos), "r": 0.6, "text": "[E] PILOTAR O BARCO"},
		{"kind": "cooler", "pos": boat.to_global(boat.cooler_pos), "r": 0.55, "text": "[E] CAIXA DE PEIXES / PORTO"},
	]
	for id in boat.leaks:
		cands.append({"kind": "leak", "id": id, "pos": (boat.leaks[id] as Node3D).global_position, "r": 0.7, "text": "SEGURE [E] PARA CONSERTAR O VAZAMENTO"})
	for c in cands:
		var to: Vector3 = c.pos - origin
		var along := to.dot(dir)
		if along < 0.0 or along > 3.2:
			continue
		var off := (to - dir * along).length()
		if off < float(c.r) and along < best_d:
			best_d = along
			best = c
	return best


func _aiming_tentacle() -> bool:
	var p := creatures.tentacle_point()
	if p.x == INF:
		return false
	var to := p - cam.global_position
	var dir := -cam.global_transform.basis.z
	return to.length() < 12.0 and to.normalized().dot(dir) > 0.85


func _hit_tentacle() -> void:
	if _hit_cd > 0.0:
		return
	_hit_cd = 0.3
	Game.request("hit")
	Audio.play("click", 0.0, 0.6)


func _physics_process(delta: float) -> void:
	_hit_cd = maxf(0.0, _hit_cd - delta)
	var run := Game.run_view
	var am_driver := int(run.get("driver", -1)) == Game.my_pid() and Game.my_pid() >= 0
	if am_driver != driving:
		driving = am_driver
		if driving:
			position = Vector3(0, 0.6, -2.25)
			yaw = PI
	var mv := Vector2.ZERO
	if enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mv = Vector2(Input.get_axis("ui_left", "ui_right") + (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0),
			Input.get_axis("ui_up", "ui_down") + (1.0 if Input.is_key_pressed(KEY_S) else 0.0) - (1.0 if Input.is_key_pressed(KEY_W) else 0.0))
		mv = mv.limit_length(1.0)
	if driving:
		_input_t += delta
		if _input_t > 0.05:
			_input_t = 0.0
			Game.send_boat_input(-mv.y, mv.x)
	else:
		# frente do personagem = -Z local girado pelo yaw
		var f := Vector3(-sin(yaw), 0, -cos(yaw))
		var r := Vector3(cos(yaw), 0, -sin(yaw))
		position += (f * -mv.y + r * mv.x) * SPEED * delta
		position.x = clampf(position.x, -1.0, 1.0)
		position.z = clampf(position.z, -3.0, 2.6)
		if position.z < -1.75 and absf(position.x) > 0.9:
			position.x = signf(position.x) * 0.9
		_bob += delta * mv.length() * 9.0
	rotation.y = yaw
	cam.rotation.x = pitch
	cam.position.y = EYE + sin(_bob) * 0.03
	# consertar vazamento segurando E
	var t := _target()
	var text := str(t.get("text", ""))
	if driving:
		text = "W/S acelerar · A/D virar · [E] largar o timão · [F] lanterna"
	elif fishing.state == "idle" and _aiming_tentacle():
		text = "CLIQUE PARA BATER NO TENTÁCULO!"
	if str(t.get("kind", "")) == "leak" and Input.is_key_pressed(KEY_E) and enabled:
		_repair_t += delta
		if _repair_t > 0.2:
			Game.request("repair", [int(t.id), _repair_t * 0.4])
			_repair_t = 0.0
			Audio.play("tick", -12.0)
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
	_pose_t += delta
	if _pose_t > 0.07:
		_pose_t = 0.0
		Game.send_pose({"p": position, "y": yaw, "f": fishing.state, "d": driving})
