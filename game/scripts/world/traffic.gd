class_name Traffic
extends Node3D
## Trânsito ambiente na avenida: carros em duas faixas que param no sinal vermelho,
## atrás de outros carros e diante do jogador. Sem física (barato).

const LANES := [{"z": -2.6, "dir": 1.0}, {"z": 2.6, "dir": -1.0}]
const LIMIT := 112.0
const SPEED := 9.0
const LIGHT_X := [-40.0, 40.0]
const GREEN_TIME := 14.0
const RED_TIME := 8.0

var cars: Array = []
var lights: Array = []   # [Node3D de cada semáforo, materiais]
var _t := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 99
	for lane in LANES:
		for i in 4:
			var col: Color = CarModel.COLORS[rng.randi_range(0, CarModel.COLORS.size() - 1)]
			var node := CarModel.build(col, false, rng.randf() < 0.2)
			add_child(node)
			var x := -LIMIT + i * (LIMIT * 2.0 / 4.0) + rng.randf_range(0, 20)
			node.position = Vector3(x, 0.02, lane.z)
			node.rotation.y = 0.0 if lane.dir > 0 else PI
			cars.append({"node": node, "lane": lane, "speed": SPEED * rng.randf_range(0.8, 1.1), "v": 0.0})
	for x in LIGHT_X:
		for side in [-1.0, 1.0]:
			_build_light(Vector3(x - side * 6.5, 0, side * 7.6), side)


func _build_light(pos: Vector3, side: float) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var pole := Mats.metal(Color(0.15, 0.16, 0.18), 0.5)
	WorldKit.cylinder(n, 0.08, 4.2, Vector3(0, 2.1, 0), pole, 8)
	WorldKit.box(n, Vector3(0.1, 0.1, 2.4), Vector3(0, 4.1, -side * 1.2), pole)
	var housing := WorldKit.box(n, Vector3(0.35, 1.0, 0.35), Vector3(0, 3.6, -side * 2.3), Mats.plastic(Color(0.08, 0.08, 0.09)))
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mats := []
	var cols := [Color(1, 0.1, 0.05), Color(1, 0.75, 0.1), Color(0.1, 1, 0.35)]
	for i in 3:
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i].darkened(0.7)
		m.emission_enabled = true
		m.emission = cols[i]
		m.emission_energy_multiplier = 0.0
		WorldKit.sphere(n, 0.11, Vector3(0.18 * (1 if side > 0 else -1) * 0.0 + 0.19, 3.9 - i * 0.3, -side * 2.3), m)
		mats.append(m)
	lights.append(mats)


## Estado do sinal da avenida: "green", "yellow" ou "red".
func signal_state() -> String:
	var cyc := fmod(_t, GREEN_TIME + RED_TIME)
	if cyc < GREEN_TIME - 2.5:
		return "green"
	if cyc < GREEN_TIME:
		return "yellow"
	return "red"


func _process(delta: float) -> void:
	_t += delta
	var stt := signal_state()
	for mats in lights:
		mats[0].emission_energy_multiplier = 3.0 if stt == "red" else 0.0
		mats[1].emission_energy_multiplier = 3.0 if stt == "yellow" else 0.0
		mats[2].emission_energy_multiplier = 3.0 if stt == "green" else 0.0
	var player: Node3D = Game.player if Game.playing and is_instance_valid(Game.player) else null
	for c in cars:
		var node: Node3D = c.node
		var dir: float = c.lane.dir
		var x := node.position.x
		var target_v: float = c.speed
		# Carro da frente
		for o in cars:
			if o == c or o.lane != c.lane:
				continue
			var gap: float = (o.node.position.x - x) * dir
			if gap > 0.0 and gap < 9.0:
				target_v = minf(target_v, maxf(0.0, (gap - 5.5) * 2.0))
		# Semáforo
		if stt != "green":
			for lx in LIGHT_X:
				var stop_x: float = lx - dir * 8.5
				var dist: float = (stop_x - x) * dir
				if dist > 0.0 and dist < 14.0:
					target_v = minf(target_v, maxf(0.0, dist - 1.0) * 1.2)
		# Jogador na pista
		if player:
			var dz: float = absf(player.global_position.z - c.lane.z)
			var dx: float = (player.global_position.x - x) * dir
			if dz < 2.2 and dx > 0.0 and dx < 10.0:
				target_v = minf(target_v, maxf(0.0, dx - 4.0))
		c.v = move_toward(float(c.v), target_v, delta * (6.0 if target_v < c.v else 3.0))
		x += float(c.v) * dir * delta
		if x * dir > LIMIT:
			x = -LIMIT * dir
		node.position.x = x
		for w in node.get_meta("wheels"):
			w.rotation.z -= float(c.v) * delta / 0.36 * dir * (1.0 if dir > 0 else -1.0)
