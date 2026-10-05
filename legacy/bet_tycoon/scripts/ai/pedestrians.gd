class_name Pedestrians
extends Node3D
## Pedestres ambientes. Pool fixo de NPCs (sem física) com máquina de estados:
## WALKING → (IDLE | TALKING | VISITING) → WALKING. Entram em comércios e voltam depois.

enum S { WALKING, IDLE, TALKING, VISITING }

const COUNT := 18
const SPEED := 1.5

var city: City
var npcs: Array = []
var rng := RandomNumberGenerator.new()


func setup(p_city: City) -> void:
	city = p_city
	rng.seed = 777
	var shirts := [Color(0.8, 0.2, 0.2), Color(0.2, 0.5, 0.8), Color(0.3, 0.7, 0.4), Color(0.9, 0.9, 0.9), Color(0.5, 0.3, 0.6), Color(0.95, 0.6, 0.2), Color(0.2, 0.2, 0.25)]
	var skins := [Color(0.95, 0.78, 0.65), Color(0.78, 0.58, 0.42), Color(0.55, 0.38, 0.26), Color(0.4, 0.27, 0.18)]
	for i in COUNT:
		var h := Humanoid.new()
		add_child(h)
		h.setup(shirts[i % shirts.size()], Color(0.18, 0.2, 0.28).lightened(rng.randf() * 0.3), skins[i % skins.size()], Color(0.08, 0.06, 0.04).lightened(rng.randf() * 0.4))
		var node := rng.randi_range(0, city.sidewalk_nodes.size() - 1)
		h.position = city.sidewalk_nodes[node]
		npcs.append({"h": h, "node": node, "target": h.position, "state": S.WALKING, "timer": 0.0, "speed": SPEED * rng.randf_range(0.8, 1.25), "next_node": node})
		_pick_next(npcs[-1])


func _pick_next(n: Dictionary) -> void:
	var r := rng.randf()
	if r < 0.12 and city.door_points.size() > 0:
		var door: Vector3 = city.door_points[rng.randi_range(0, city.door_points.size() - 1)]
		if n.h.position.distance_to(door) < 50.0:
			n.target = door + Vector3(0, 0.12, 0)
			n["visit"] = true
			return
	var neigh: Array = city.sidewalk_edges.get(n.node, [])
	if neigh.is_empty():
		return
	n.next_node = neigh[rng.randi_range(0, neigh.size() - 1)]
	var t: Vector3 = city.sidewalk_nodes[n.next_node]
	# Deslocamento lateral para não andarem todos na mesma linha
	t += Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
	n.target = t
	n["visit"] = false


func _process(delta: float) -> void:
	if city == null:
		return
	for n in npcs:
		var h: Humanoid = n.h
		match n.state:
			S.WALKING:
				var to: Vector3 = n.target - h.position
				to.y = 0
				var d := to.length()
				if d < 0.3:
					if n.get("visit", false):
						n.state = S.VISITING
						n.timer = rng.randf_range(8.0, 25.0)
						h.visible = false
					else:
						n.node = n.next_node
						var r := rng.randf()
						if r < 0.15:
							n.state = S.IDLE
							n.timer = rng.randf_range(2.0, 5.0)
						elif r < 0.25:
							n.state = S.TALKING
							n.timer = rng.randf_range(4.0, 8.0)
						else:
							_pick_next(n)
					h.animate(0.0, delta)
				else:
					var step := to / d * minf(d, n.speed * delta)
					h.position += step
					h.rotation.y = lerp_angle(h.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 8.0))
					h.animate(n.speed, delta)
			S.IDLE, S.TALKING:
				n.timer -= delta
				h.animate(0.0, delta)
				if n.state == S.TALKING:
					h.rotation.y += sin(Time.get_ticks_msec() * 0.002 + h.position.x) * delta * 0.5
				if n.timer <= 0.0:
					n.state = S.WALKING
					_pick_next(n)
			S.VISITING:
				n.timer -= delta
				if n.timer <= 0.0:
					h.visible = true
					n.node = city.nearest_node(h.position)
					n.state = S.WALKING
					n.visit = false
					n.next_node = n.node
					n.target = city.sidewalk_nodes[n.node]
