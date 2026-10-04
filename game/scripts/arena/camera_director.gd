class_name CameraDirector
extends Camera3D
## Diretor de câmera: planos de TV com transições suaves, leve "câmera na mão" e tremidas.

var arena: Node3D
var _from_pos := Vector3.ZERO
var _from_look := Vector3.ZERO
var _to_pos := Vector3(0, 7, 20)
var _to_look := Vector3(0, 2, 0)
var _blend := 1.0
var _blend_time := 1.0
var _orbit := false
var _orbit_t := 0.0
var _shake := 0.0
var _t := 0.0
var _cur_look := Vector3(0, 2, 0)
var _drift := Vector3.ZERO
var _shot_t := 0.0
var current_shot := ""


func _ready() -> void:
	fov = 50.0
	position = _to_pos
	look_at(_to_look)


func shot(shot_name: String, time: float = 1.2, focus: Vector3 = Vector3.ZERO) -> void:
	current_shot = shot_name
	_orbit = shot_name == "menu"
	_from_pos = position
	_from_look = _cur_look
	_blend = 0.0
	_blend_time = maxf(time, 0.01)
	_drift = Vector3.ZERO
	_shot_t = 0.0
	var p := Vector3(0, 7, 20)
	var l := Vector3(0, 2.2, -2)
	match shot_name:
		"wide":
			p = Vector3(0, 8.5, 21)
			l = Vector3(0, 2.5, -3)
		"players":
			p = Vector3(0, 4.6, 12.5)
			l = Vector3(0, 2.4, -5)
		"stage":
			p = Vector3(0, 3.6, 10)
			l = Vector3(0, 2.0, 0)
		"doors":
			p = Vector3(0, 3.4, 9.5)
			l = Vector3(0, 2.2, 0.5)
		"screen":
			p = Vector3(0, 6.5, 9)
			l = Vector3(0, 7.5, -16)
		"player":
			# personagem no terço esquerdo: os painéis do centro não cobrem o rosto
			p = focus + Vector3(2.0, 2.5, 6.0)
			l = focus + Vector3(2.0, 1.9, 0)
		"winner":
			p = focus + Vector3(0, 2.7, 7.0)
			l = focus + Vector3(0, 2.0, 0)
		"allwin":
			p = Vector3(0, 1.4, 9.0)
			l = Vector3(0, 3.6, -4)
			_drift = Vector3(0, 0.6, -3.0)
		"podium":
			p = Vector3(0, 3.4, 9.5)
			l = Vector3(0, 2.6, 0)
		"menu":
			p = Vector3(0, 6.5, 19)
			l = Vector3(0, 3, -3)
	_to_pos = p
	_to_look = l


func shake(amount: float = 0.3) -> void:
	if Settings.get_value("camera_shake"):
		_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	_t += delta
	_shot_t += delta
	_blend = minf(1.0, _blend + delta / _blend_time)
	var k := ease(_blend, -2.2)   # ease in-out
	var target_pos := _to_pos + _drift * smoothstep(0.0, 14.0, _shot_t)
	if _orbit:
		_orbit_t += delta * 0.08
		target_pos = Vector3(sin(_orbit_t) * 16.0, 6.0 + sin(_orbit_t * 1.7), cos(_orbit_t) * 16.0 + 3.0)
	var pos := _from_pos.lerp(target_pos, k)
	var look := _from_look.lerp(_to_look, k)
	# câmera na mão
	pos += Vector3(sin(_t * 0.7) * 0.06, sin(_t * 0.9) * 0.04, 0)
	if _shake > 0.0:
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.3
		_shake = maxf(0.0, _shake - delta * 1.5)
	position = pos
	_cur_look = look
	if pos.distance_to(look) > 0.01:
		look_at(look)
