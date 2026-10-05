class_name Creatures
extends Node3D
## Ameaças visíveis: tentáculo gigante ao lado do barco, olhos enormes na névoa
## e o vulto do leviatã. Também cardumes brilhantes no abismo.

var tentacle: Node3D
var tentacle_segments: Array[MeshInstance3D] = []
var eyes: Node3D
var _t := 0.0
var _tent_up := 0.0
var _tent_target := 0.0
var _tent_side := 1.0
var _eyes_on := 0.0
var _eyes_target := 0.0
var _eyes_angle := 0.0
var boat: Node3D


func _ready() -> void:
	tentacle = Node3D.new()
	add_child(tentacle)
	var skin := M3.solid(Color("5a1a2e"), 0.4)
	skin.rim_enabled = true
	var sucker := M3.solid(Color("e8b0c0"), 0.5)
	for i in 18:
		var r := 0.8 - i * 0.035
		var seg := M3.sphere(tentacle, r, Vector3.ZERO, skin, 14)
		tentacle_segments.append(seg)
		if i % 3 == 0:
			M3.sphere(seg, r * 0.28, Vector3(0, 0, r * 0.85), sucker, 8)
	tentacle.visible = false
	eyes = Node3D.new()
	add_child(eyes)
	for sx in [-2.2, 2.2]:
		var e := M3.sphere(eyes, 2.6, Vector3(sx * 1.8, 0, 0), M3.glow(Color("ffcc33"), 5.0), 16)
		var pupil := M3.sphere(e, 1.2, Vector3(0, 0, -1.9), M3.solid(Color("050505"), 0.2), 12)
		pupil.scale = Vector3(0.45, 1.0, 0.5)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffaa33")
	glow.light_energy = 2.0
	glow.omni_range = 18
	eyes.add_child(glow)
	eyes.visible = false


func tentacle_rise(side: float) -> void:
	_tent_side = side
	_tent_target = 1.0
	tentacle.visible = true


func tentacle_hit() -> void:
	for s in tentacle_segments:
		s.scale = Vector3.ONE * 1.25
		create_tween().tween_property(s, "scale", Vector3.ONE, 0.25)


func tentacle_down() -> void:
	_tent_target = 0.0


func show_eyes(angle: float) -> void:
	_eyes_angle = angle
	_eyes_target = 1.0
	eyes.visible = true


func hide_eyes() -> void:
	_eyes_target = 0.0


## Ponto do tentáculo (para saber se o jogador está mirando nele).
func tentacle_point() -> Vector3:
	return tentacle_segments[5].global_position if tentacle.visible else Vector3(INF, INF, INF)


func _process(delta: float) -> void:
	_t += delta
	_tent_up = move_toward(_tent_up, _tent_target, delta * 0.8)
	if boat:
		var side := boat.global_transform.basis.x * _tent_side
		var base := boat.global_position + side * 3.4 + Vector3(0, -2.0, 0)
		tentacle.global_position = base
		for i in tentacle_segments.size():
			var k := float(i) / tentacle_segments.size()
			var h := k * 7.5 * _tent_up
			var sway := sin(_t * 2.0 + k * 3.0) * k * 1.6
			var curl := -side * k * k * 2.4 * _tent_up
			tentacle_segments[i].position = Vector3(0, h, 0) + boat.global_transform.basis.z * sway + curl
		if _tent_up <= 0.01 and _tent_target == 0.0:
			tentacle.visible = false
	_eyes_on = move_toward(_eyes_on, _eyes_target, delta * 0.5)
	if boat and eyes.visible:
		var dir := Vector3(sin(_eyes_angle), 0, cos(_eyes_angle))
		eyes.global_position = boat.global_position + dir * lerpf(55.0, 30.0, _eyes_on) + Vector3(0, 3.0 + sin(_t) * 0.4, 0)
		eyes.look_at(boat.global_position + Vector3(0, 2, 0))
		var blink := 1.0 if fmod(_t, 4.0) > 0.15 else 0.1
		eyes.scale = Vector3(1, blink, 1) * maxf(0.01, _eyes_on)
		if _eyes_on <= 0.01 and _eyes_target == 0.0:
			eyes.visible = false
