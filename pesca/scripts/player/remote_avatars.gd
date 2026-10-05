class_name RemoteAvatars
extends Node3D
## Os outros pescadores (bonecos cartoon) no convés, interpolando as poses recebidas.

var avatars: Dictionary = {}    # pid -> {model, target_p, target_y, label}


func _ready() -> void:
	Game.pose_received.connect(_on_pose)
	Game.view_changed.connect(_sync)


func _sync() -> void:
	var ids := {}
	for p in Game.view.get("players", []):
		ids[int(p.id)] = p
	for pid in avatars.keys():
		if not ids.has(pid) or pid == Game.my_pid():
			avatars[pid].model.queue_free()
			avatars.erase(pid)


func _on_pose(pid: int, pose: Dictionary) -> void:
	if pid == Game.my_pid():
		return
	if not avatars.has(pid):
		var pv := Game.player_view(pid)
		if pv.is_empty():
			return
		var m := CharacterModel.create(str(pv.character))
		m.scale = Vector3.ONE * 0.95
		add_child(m)
		M3.label(m, str(pv.name), Vector3(0, 2.3, 0), 26, GameData.character_color(str(pv.character)).lightened(0.3), 8, true)
		avatars[pid] = {"model": m, "p": pose.p, "y": float(pose.y)}
	avatars[pid].p = pose.p
	avatars[pid].y = float(pose.y)
	var m2: CharacterModel = avatars[pid].model
	if str(pose.get("f", "")) == "reeling":
		m2.play("shock")


func _process(delta: float) -> void:
	for pid in avatars:
		var a: Dictionary = avatars[pid]
		var m: CharacterModel = a.model
		m.position = m.position.lerp(a.p, minf(1.0, delta * 12.0))
		m.rotation.y = lerp_angle(m.rotation.y, float(a.y) + PI, minf(1.0, delta * 12.0))
