class_name BusinessVisuals
extends Node3D
## Camada visual do negócio: desenha clientes (fila/atendimento) e funcionários a partir
## do estado da simulação, detecta o jogador atrás do balcão e esconde o teto ao entrar.
## Usa pool de NPCs: nada de instanciar/destruir a cada cliente.

const MAX_CUSTOMERS := 26
const NPC_SPEED := 2.6

var view: EstablishmentView
var interact_root: Node3D
var _customers: Array = []         # pool de Humanoid
var _by_vid: Dictionary = {}       # vid -> índice no pool
var _staff_npcs: Dictionary = {}   # id -> Humanoid
var _staff_labels: Dictionary = {}
var _type_colors: Dictionary = {}
var _was_inside := false


func _ready() -> void:
	for t in GameData.list("customers", "types"):
		_type_colors[str(t.id)] = Color(str(t.color))
	var skins := [Color(0.95, 0.78, 0.65), Color(0.78, 0.58, 0.42), Color(0.55, 0.38, 0.26), Color(0.4, 0.27, 0.18)]
	for i in MAX_CUSTOMERS:
		var h := Humanoid.new()
		add_child(h)
		h.setup(Color.WHITE, Color(0.2, 0.22, 0.3), skins[i % skins.size()])
		h.visible = false
		_customers.append({"h": h, "vid": -1, "type": ""})
	Game.sim.staff_changed.connect(_rebuild_staff)


func attach(p_view: EstablishmentView) -> void:
	view = p_view
	for c in _customers:
		c.vid = -1
		c.h.visible = false
	_by_vid.clear()
	_rebuild_staff()


func detach() -> void:
	view = null
	for c in _customers:
		c.h.visible = false
		c.vid = -1
	_by_vid.clear()
	for id in _staff_npcs:
		_staff_npcs[id].queue_free()
	_staff_npcs.clear()
	_staff_labels.clear()


func _process(delta: float) -> void:
	var sim := Game.sim
	if view == null or not is_instance_valid(view) or not sim.has_business():
		sim.player_at_counter = false
		return
	var player: Node3D = Game.player
	if player and is_instance_valid(player) and Game.playing:
		sim.player_at_counter = view.is_behind_counter(player.global_position) and sim.business.is_open()
		var inside := view.is_inside(player.global_position)
		view.roof.visible = not inside
		if player is PlayerController and inside != _was_inside:
			player.rig.set_indoor(inside)
		_was_inside = inside
	_sync_customers(delta)
	_sync_staff(delta)


func _shirt_for(type_id: String) -> Color:
	return _type_colors.get(type_id, Color(0.6, 0.6, 0.6))


func _sync_customers(delta: float) -> void:
	var visits: Array = Game.sim.customers.visits
	var alive := {}
	for v in visits:
		alive[int(v.vid)] = true
	for vid in _by_vid.keys():
		if not alive.has(vid):
			var slot: Dictionary = _customers[_by_vid[vid]]
			slot.vid = -1
			slot.h.visible = false
			_by_vid.erase(vid)
	for v in visits:
		var vid := int(v.vid)
		if not _by_vid.has(vid):
			var free := -1
			for i in _customers.size():
				if _customers[i].vid == -1:
					free = i
					break
			if free < 0:
				continue
			var slot: Dictionary = _customers[free]
			slot.vid = vid
			if slot.type != v.type:
				slot.type = v.type
				slot.h.set_shirt(_shirt_for(str(v.type)))
			slot.h.global_position = _street_point(vid)
			slot.h.visible = true
			_by_vid[vid] = free
		var h: Humanoid = _customers[_by_vid[vid]].h
		var target := _target_for(v)
		var to := target - h.global_position
		to.y = 0
		var dist := to.length()
		if dist > 25.0:
			h.global_position = target
			dist = 0.0
		if dist > 0.05:
			var spd := NPC_SPEED * (1.6 if v.state in ["walking", "exiting"] else 1.0)
			h.global_position += to / dist * minf(dist, spd * delta)
			h.rotation.y = lerp_angle(h.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 10.0))
			h.animate(spd if dist > 0.15 else 0.0, delta)
		else:
			h.animate(0.0, delta)
			if v.state == "served" or v.state == "waiting":
				h.rotation.y = lerp_angle(h.rotation.y, view.global_rotation.y + PI, minf(1.0, delta * 6.0))


func _street_point(vid: int) -> Vector3:
	var side := -1.0 if vid % 2 == 0 else 1.0
	return view.to_global(view.door_outside + Vector3(side * 9.0, 0.02, 0.6))


func _target_for(v: Dictionary) -> Vector3:
	var sim := Game.sim
	var local := Vector3.ZERO
	match str(v.state):
		"walking":
			local = view.door_outside
		"entering":
			local = view.door_inside
		"waiting":
			local = view.queue_point(maxi(0, sim.customers.queue_position(v)))
		"served":
			local = _service_point(v)
		"betting":
			local = view.lounge_pos[int(v.vid) % view.lounge_pos.size()] + Vector3(0.6, 0, 0)
		"exiting":
			if int(v.t) == 0:
				local = view.door_inside
			else:
				return _street_point(int(v.vid) + 1)
	return view.to_global(local)


func _service_point(v: Dictionary) -> Vector3:
	var server := str(v.get("server", ""))
	if server.begins_with("terminal"):
		var k := int(v.station) % maxi(1, view.terminal_pos.size())
		if view.terminal_pos.size() > 0:
			return view.terminal_pos[k]
	var idx := _counter_for_server(server)
	return view.counter_pos[clampi(idx, 0, view.counter_pos.size() - 1)]


## Atendentes ocupam os guichês da direita para a esquerda; o jogador usa o mais próximo.
func _counter_for_server(server: String) -> int:
	var n := view.counter_pos.size()
	if server == "player":
		var best := 0
		var bd := INF
		if Game.player:
			for i in n:
				var dd := view.to_global(view.staff_pos[i]).distance_to(Game.player.global_position)
				if dd < bd:
					bd = dd
					best = i
		return best
	var k := 0
	for e in Game.sim.employees.staff:
		if e.role == "atendente":
			if str(e.id) == server:
				return n - 1 - (k % n)
			k += 1
	return 0


# --- Funcionários -------------------------------------------------------------------

func _rebuild_staff() -> void:
	for id in _staff_npcs:
		_staff_npcs[id].queue_free()
	_staff_npcs.clear()
	_staff_labels.clear()
	if view == null:
		return
	var role_colors := {"atendente": Color(0.95, 0.75, 0.2), "caixa": Color(0.2, 0.6, 0.3), "seguranca": Color(0.1, 0.1, 0.12),
		"analista": Color(0.3, 0.4, 0.8), "gerente": Color(0.6, 0.15, 0.2), "especialista": Color(0.95, 0.5, 0.1)}
	for e in Game.sim.employees.staff:
		var h := Humanoid.new()
		add_child(h)
		h.setup(role_colors.get(e.role, Color.GRAY), Color(0.1, 0.1, 0.14))
		var lbl := WorldKit.label(h, "", Vector3(0, 2.15, 0), 36, Color.WHITE, 8, true)
		_staff_labels[str(e.id)] = lbl
		var it := Interactable.create("Gerenciar funcionário: " + str(e.name), func(): Game.request_ui("admin", "staff"), 1.0)
		it.position = Vector3(0, 1.0, 0)
		h.add_child(it)
		_staff_npcs[str(e.id)] = h
		h.global_position = view.to_global(view.door_inside)


func _staff_target(e: Dictionary) -> Vector3:
	var st := str(e.state)
	if st == "RESTING":
		return view.to_global(view.role_pos.rest)
	if e.role == "atendente":
		return view.to_global(view.staff_pos[_counter_for_server(str(e.id))])
	if e.role == "gerente":
		var t := Time.get_ticks_msec() * 0.0004 + float(str(e.id).hash() % 10)
		return view.to_global(view.role_pos.gerente + Vector3(sin(t) * 1.5, 0, cos(t * 0.7) * 1.5))
	return view.to_global(view.role_pos.get(str(e.role), view.door_inside))


func _sync_staff(delta: float) -> void:
	var state_txt := {"WORKING": "", "RESTING": "PAUSA", "ERROR": "ERRO!", "MOVING": "", "IDLE": ""}
	for e in Game.sim.employees.staff:
		var h: Humanoid = _staff_npcs.get(str(e.id))
		if h == null:
			continue
		h.visible = e.state != "IDLE"
		if not h.visible:
			continue
		var target := _staff_target(e)
		var to := target - h.global_position
		to.y = 0
		var dist := to.length()
		if dist > 30.0:
			h.global_position = target
		elif dist > 0.08:
			h.global_position += to / dist * minf(dist, NPC_SPEED * delta)
			h.rotation.y = lerp_angle(h.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 10.0))
			h.animate(NPC_SPEED, delta)
		else:
			h.animate(0.0, delta)
			h.rotation.y = lerp_angle(h.rotation.y, view.global_rotation.y, minf(1.0, delta * 6.0))
		var lbl: Label3D = _staff_labels.get(str(e.id))
		if lbl:
			lbl.text = state_txt.get(str(e.state), "")
			lbl.modulate = Color(1, 0.3, 0.3) if e.state == "ERROR" else Color(0.7, 0.85, 1.0)
