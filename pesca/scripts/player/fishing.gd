class_name Fishing
extends Node3D
## Vara de pesca em primeira pessoa: arremessar (segurar e soltar), esperar a mordida,
## fisgar no tempo certo e puxar controlando a TENSÃO da linha.

signal state_changed(state: String)
signal caught(fish: Dictionary)
signal message(text: String, color: Color)

const BITE_WINDOW := 1.0
const REEL_TIMEOUT := 30.0

var state := "idle"     # idle, charging, flying, waiting, bite, reeling
var charge := 0.0
var tension := 0.0
var progress := 0.0
var zone_lo := 0.32
var zone_hi := 0.78
var fish: Dictionary = {}
var cam: Camera3D
var rod: Node3D
var tip: Node3D
var bobber: Node3D
var line: MeshInstance3D
var _im: ImmediateMesh
var _t := 0.0
var _wait := 0.0
var _burst := 0.0
var _burst_t := 0.0
var _reel_time := 0.0
var _land := Vector3.ZERO
var _fly_t := 0.0
var _fly_from := Vector3.ZERO
var rng := RandomNumberGenerator.new()


func setup(camera: Camera3D) -> void:
	cam = camera
	rng.randomize()
	rod = Node3D.new()
	rod.position = Vector3(0.36, -0.36, -0.62)
	rod.rotation = Vector3(0.9, 0.05, 0.0)
	cam.add_child(rod)
	var pole := M3.cylinder(rod, 0.006, 0.014, 1.4, Vector3(0, 0.7, 0), M3.solid(Color("3a2a1a"), 0.5), 6)
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	M3.cylinder(rod, 0.03, 0.03, 0.05, Vector3(0.035, 0.2, 0), M3.solid(Color("888888"), 0.3, 0.8), 10).rotation.z = PI / 2
	tip = Node3D.new()
	tip.position = Vector3(0, 1.4, 0)
	rod.add_child(tip)
	bobber = Node3D.new()
	var b1 := M3.sphere(bobber, 0.09, Vector3(0, 0.05, 0), M3.solid(Color("ff3b30"), 0.4), 10)
	b1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	M3.sphere(bobber, 0.07, Vector3(0, 0.13, 0), M3.glow(Color("ffffff"), 1.5), 8)
	bobber.visible = false
	get_tree().root.add_child.call_deferred(bobber)
	_im = ImmediateMesh.new()
	line = MeshInstance3D.new()
	line.mesh = _im
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.9, 0.95, 1.0, 0.8)
	line.material_override = lm
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().root.add_child.call_deferred(line)


func _exit_tree() -> void:
	if is_instance_valid(bobber):
		bobber.queue_free()
	if is_instance_valid(line):
		line.queue_free()


func _state(s: String) -> void:
	state = s
	state_changed.emit(s)


func busy() -> bool:
	return state != "idle"


func cancel() -> void:
	bobber.visible = false
	_state("idle")


## Botão do mouse pressionado/solto (o PlayerController encaminha).
func press() -> void:
	match state:
		"idle":
			charge = 0.0
			_state("charging")
		"bite":
			_start_reel()
		"waiting", "flying":
			cancel()
			message.emit("Linha recolhida.", Color("b9a8d9"))


func release() -> void:
	if state == "charging":
		_cast()


func _cast() -> void:
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var dist := 4.0 + charge * 12.0
	var p := cam.global_position + fwd * dist
	_land = Vector3(p.x, Ocean.height(p.x, p.z), p.z)
	_fly_from = tip.global_position
	_fly_t = 0.0
	bobber.visible = true
	bobber.global_position = _fly_from
	Audio.play("whoosh", -6.0)
	_state("flying")


func _start_wait() -> void:
	var run := Game.run_view
	var isca := int(run.get("upgrades", {}).get("isca", 0))
	var zid := str(run.get("zone_id", "raso"))
	_wait = rng.randf_range(3.0, 10.0) * (1.0 - 0.15 * isca) * (1.2 if zid == "abismo" else 1.0)
	if bool(run.get("docked", false)):
		_wait *= 2.5
	Audio.play("splash", -4.0)
	_state("waiting")


func _start_reel() -> void:
	var run := Game.run_view
	fish = FishDB.roll(str(run.get("zone_id", "raso")), int(run.get("upgrades", {}).get("isca", 0)), str(run.get("zone_id", "")) == "abismo" and bool(run.get("lantern", false)), rng)
	var vara := int(run.get("upgrades", {}).get("vara", 0))
	var width := 0.38 + 0.06 * vara - float(fish.strength) * 0.08
	zone_lo = 0.55 - width / 2.0
	zone_hi = 0.55 + width / 2.0
	tension = 0.4
	progress = 0.15
	_reel_time = 0.0
	_burst_t = rng.randf_range(0.5, 1.2)
	Audio.play("confirm")
	_state("reeling")


func _process(delta: float) -> void:
	_t += delta
	match state:
		"charging":
			charge = minf(1.0, charge + delta * 0.8)
		"flying":
			_fly_t = minf(1.0, _fly_t + delta * 1.6)
			var p := _fly_from.lerp(_land, _fly_t)
			p.y += sin(_fly_t * PI) * 3.0
			bobber.global_position = p
			if _fly_t >= 1.0:
				_start_wait()
		"waiting":
			_float_bobber(0.0)
			_wait -= delta
			if _wait <= 0.0:
				_wait = BITE_WINDOW
				Audio.play("bite")
				_state("bite")
		"bite":
			_float_bobber(-0.18 + sin(_t * 30.0) * 0.06)
			_wait -= delta
			if _wait <= 0.0:
				message.emit("O peixe fugiu! Fisgue mais rápido.", Color("ff9f1c"))
				_start_wait()
		"reeling":
			_float_bobber(-0.1 + sin(_t * 18.0) * 0.05)
			_reel(delta)
	_check_line()
	_draw_line()
	if rod:
		var bend := 0.0
		if state == "reeling":
			bend = tension * 0.5
		elif state == "charging":
			bend = -charge * 0.6
		rod.rotation.x = lerpf(rod.rotation.x, 0.9 - bend, minf(1.0, delta * 10.0))


func _float_bobber(off: float) -> void:
	var p := bobber.global_position
	bobber.global_position = Vector3(p.x, Ocean.height(p.x, p.z) + off, p.z)


func _reel(delta: float) -> void:
	var holding := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var s := float(fish.strength)
	_reel_time += delta
	_burst_t -= delta
	if _burst_t <= 0.0:
		_burst = s * rng.randf_range(0.6, 1.2)
		_burst_t = rng.randf_range(0.6, 1.5) / (0.6 + s)
	var pull := _burst * delta * 2.2
	_burst = maxf(0.0, _burst - delta * 2.0)
	if holding:
		tension += (0.75 + s * 0.35) * delta
	else:
		tension -= 0.85 * delta
	tension += pull
	tension = clampf(tension, 0.0, 1.05)
	var in_zone := tension >= zone_lo and tension <= zone_hi
	if holding and in_zone:
		var vara := int(Game.run_view.get("upgrades", {}).get("vara", 0))
		progress += (0.2 - s * 0.07) * (1.0 + 0.12 * vara) * delta
	elif tension < zone_lo:
		progress -= 0.07 * delta
	progress = clampf(progress, 0.0, 1.0)
	if tension >= 1.0:
		Audio.play("error")
		message.emit("A LINHA ARREBENTOU! (%s escapou)" % fish.name, Color("ff4d6d"))
		cancel()
	elif progress <= 0.0 and _reel_time > 2.0:
		message.emit("O peixe se soltou...", Color("ff9f1c"))
		cancel()
	elif progress >= 1.0:
		Audio.play("jackpot" if str(fish.rarity) in ["epico", "lendario"] else "win")
		caught.emit(fish)
		cancel()
	elif _reel_time > REEL_TIMEOUT:
		message.emit("Cansou... o peixe escapou.", Color("ff9f1c"))
		cancel()


func _check_line() -> void:
	if state in ["waiting", "bite", "reeling"] and tip and bobber.global_position.distance_to(tip.global_position) > 30.0:
		message.emit("Linha esticou demais e soltou!", Color("ff9f1c"))
		cancel()


func _draw_line() -> void:
	_im.clear_surfaces()
	if not bobber.visible or tip == null:
		return
	var a := tip.global_position
	var b := bobber.global_position
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 13:
		var k := i / 12.0
		var p := a.lerp(b, k)
		p.y -= sin(k * PI) * (0.6 if state != "reeling" else 0.15)
		_im.surface_add_vertex(p)
	_im.surface_end()
