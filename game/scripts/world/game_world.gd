class_name GameWorld
extends Node3D
## Mundo 3D: cidade, jogador, pedestres, pontos de interação e marcadores.
## Lê o estado da Simulation e chama ações; não guarda regras de negócio.

const LOT_SIGN_COLOR := Color(1.0, 0.85, 0.3)

var city: City
var player: PlayerController
var pedestrians: Pedestrians
var menu_camera: Camera3D
var job_beacon: Beacon
var objective_beacon: Beacon
var lot_views: Dictionary = {}     # imóvel -> Node3D construído
var business_visuals: BusinessVisuals
var establishment: EstablishmentView
var _menu_t := 0.0


func _ready() -> void:
	city = City.new()
	add_child(city)
	pedestrians = Pedestrians.new()
	add_child(pedestrians)
	pedestrians.setup(city)
	_build_interactions()
	business_visuals = BusinessVisuals.new()
	add_child(business_visuals)
	menu_camera = Camera3D.new()
	menu_camera.far = 400.0
	add_child(menu_camera)
	menu_camera.current = true
	job_beacon = Beacon.create(Color(0.3, 0.9, 1.0), "TRABALHO", true)
	add_child(job_beacon)
	job_beacon.visible = false
	job_beacon.reached.connect(_on_job_beacon)
	objective_beacon = Beacon.create(Color(1.0, 0.8, 0.2), "OBJETIVO", false)
	add_child(objective_beacon)
	objective_beacon.visible = false
	Game.session_started.connect(_on_session_started)
	Game.session_ended.connect(_on_session_ended)
	Game.sim.business_changed.connect(refresh_lots)
	Game.sim.job_changed.connect(_update_job_beacon)
	refresh_lots()


func _on_session_started() -> void:
	if player == null:
		player = PlayerController.new()
		add_child(player)
		Game.player = player
	var st: Dictionary = Game.pending_player_state
	var spawn: Vector3 = city.point("spawn")
	if st.has("player_pos"):
		var p: Array = st.player_pos
		spawn = Vector3(float(p[0]), float(p[1]) + 0.3, float(p[2]))
	player.teleport(spawn, 0.0)
	player.rig.camera.current = true
	player.visible = true
	player.set_physics_process(true)
	refresh_lots()
	_update_job_beacon()


func _on_session_ended() -> void:
	if player:
		player.visible = false
		player.set_physics_process(false)
	menu_camera.current = true
	job_beacon.visible = false
	objective_beacon.visible = false


func _process(delta: float) -> void:
	city.day_night.set_time(float(Game.sim.time.minute) if Game.playing else 1110.0)
	if not Game.playing:
		_menu_t += delta * 0.05
		menu_camera.position = Vector3(cos(_menu_t) * 70.0, 32.0, sin(_menu_t) * 70.0)
		menu_camera.look_at(Vector3(0, 0, 0))
		return
	_update_objective_beacon()


# --- Interações fixas da cidade ---------------------------------------------------

func _add_interact(at: Vector3, prompt: String, cb: Callable, radius: float = 1.6) -> Interactable:
	var it := Interactable.create(prompt, cb, radius)
	it.position = at + Vector3(0, 1.0, 0)
	add_child(it)
	return it


func _build_interactions() -> void:
	_add_interact(city.point("casa_jogador"), "Seu apartamento: Dormir / Salvar", func(): Game.request_ui("home"))
	_add_interact(city.point("banco"), "Acessar banco", func(): Game.request_ui("app", "banco"))
	_add_interact(city.point("deposito") + Vector3(3, 0, 0), "Quadro de trabalhos do Depósito", func(): Game.request_ui("jobs", "deposito"))
	_add_interact(city.point("mercado") + Vector3(3, 0, 0), "Quadro de trabalhos do Mercado", func(): Game.request_ui("jobs", "mercado"))
	_add_interact(city.point("loja") + Vector3(-2.5, 0, 0), "Quadro de trabalhos da Loja", func(): Game.request_ui("jobs", "loja"))
	_add_interact(city.point("loja") + Vector3(2.5, 0, 0), "Comprar equipamentos", func(): Game.request_ui("shop", null))
	_add_interact(city.point("lucky"), "Observar concorrente: Lucky Bet", func(): Game.request_ui("competitor", "lucky"))
	_add_interact(city.point("royal"), "Observar concorrente: Royal Apostas", func(): Game.request_ui("competitor", "royal"))
	# Rótulos flutuantes de orientação
	for id in ["deposito", "mercado", "loja"]:
		WorldKit.label(self, "TRABALHOS", city.point(id) + Vector3(3 if id != "loja" else -2.5, 2.6, 0), 40, Color(0.4, 0.9, 1.0), 10, true)


# --- Lotes (imóveis do jogador) ----------------------------------------------------

## Reconstrói a aparência dos lotes conforme contratos/estágio do negócio.
func refresh_lots() -> void:
	for lot_id in city.lots:
		var info: Dictionary = city.lots[lot_id]
		var key := _lot_state_key(lot_id)
		if lot_views.has(lot_id) and lot_views[lot_id].get_meta("key", "") == key:
			continue
		if lot_views.has(lot_id):
			if establishment and is_instance_valid(establishment) and establishment.get_parent() == lot_views[lot_id]:
				business_visuals.detach()
				establishment = null
			lot_views[lot_id].queue_free()
		var v := Node3D.new()
		v.set_meta("key", key)
		info.node.add_child(v)
		lot_views[lot_id] = v
		_build_lot_view(v, lot_id, info.def)


func _lot_state_key(lot_id: String) -> String:
	var sim := Game.sim
	var contract := ""
	if sim.properties != null:
		contract = str(sim.properties.contracts.get(lot_id, ""))
	var stage := 0
	var eq := 0
	if sim.has_business() and sim.business.property_id == lot_id:
		stage = sim.business.stage
		eq = sim.business.equipment_revision
	return "%s|%d|%d" % [contract, stage, eq]


func _build_lot_view(v: Node3D, lot_id: String, d: Dictionary) -> void:
	if d.get("kind", "") == "house":
		_lot_sign(v, lot_id, city.lots[lot_id].get("sign_pos", city.point(d.id)), float(d.dir))
		return
	var sim := Game.sim
	if sim.has_business() and sim.business.property_id == lot_id:
		build_establishment(v, lot_id, d)
		return
	_empty_lot(v, lot_id, d)


## Constrói o estabelecimento do jogador no lote e liga os NPCs de clientes/funcionários.
func build_establishment(v: Node3D, lot_id: String, d: Dictionary) -> void:
	var sim := Game.sim
	var ev := EstablishmentView.new()
	v.add_child(ev)
	ev.build(d, sim.business.stage, sim.business.equipment, sim.brand_name, sim.business.stage_name(), city)
	establishment = ev
	var n := ev.staff_pos.size()
	_est_interact(ev, ev.staff_pos[0] + Vector3(0, 0, 0.0), "Computador: acessar administração", func(): Game.request_ui("admin", "overview"))
	_est_interact(ev, (ev.staff_pos[n - 1] + ev.counter_pos[n - 1]) / 2.0 + Vector3(0, 0, 0.9), "Balcão: gerenciar atendimento e apostas", func(): Game.request_ui("admin", "bets"))
	_est_interact(ev, ev.staff_pos[0] + Vector3(-1.3, 0, 0.8), "Caixa: consultar finanças", func(): Game.request_ui("admin", "finance"))
	_est_interact(ev, ev.door_inside + Vector3(-1.6, 0, 0), "Quadro: equipamentos e expansão", func(): Game.request_ui("admin", "equipment"))
	_est_interact(ev, ev.door_outside + Vector3(2.4, 0, 0), "Ver propriedade", func(): Game.request_ui("lot", lot_id))
	WorldKit.label(ev, "ATENDA AQUI", ev.staff_pos[0] + Vector3(0, 2.4, 0), 36, Color(0.4, 1, 0.6), 8, true)
	business_visuals.attach(ev)


func _est_interact(ev: Node3D, local_pos: Vector3, prompt: String, cb: Callable) -> void:
	var it := Interactable.create(prompt, cb, 1.0)
	it.position = local_pos + Vector3(0, 1.0, 0)
	ev.add_child(it)


func _empty_lot(v: Node3D, lot_id: String, d: Dictionary) -> void:
	var dir: float = float(d.dir)
	var center := Vector3(float(d.x), 0, float(d.fz) - dir * float(d.d) / 2.0)
	var w: float = d.w
	var h: float = d.h
	if h <= 0.0:
		# Terreno vazio cercado
		WorldKit.box(v, Vector3(w, 0.05, float(d.d)), center + Vector3(0, 0.03, 0), WorldKit.mat(Color(0.45, 0.38, 0.28)), false)
		for side in [-1, 1]:
			WorldKit.solid(v, Vector3(0.15, 1.6, float(d.d)), center + Vector3(side * w / 2, 0.8, 0), WorldKit.mat(Color(0.6, 0.6, 0.62), 0.5, 0.6))
		WorldKit.solid(v, Vector3(w, 1.6, 0.15), center + Vector3(0, 0.8, -dir * float(d.d) / 2), WorldKit.mat(Color(0.6, 0.6, 0.62), 0.5, 0.6))
		for side in [-1, 1]:
			WorldKit.solid(v, Vector3(w / 2 - 3, 1.6, 0.15), center + Vector3(side * (w / 4 + 1.5), 0.8, dir * float(d.d) / 2), WorldKit.mat(Color(0.6, 0.6, 0.62), 0.5, 0.6))
		WorldKit.label(v, "FUTURO EMPREENDIMENTO", center + Vector3(0, 6, 0), 140, LOT_SIGN_COLOR, 20, true)
	else:
		WorldKit.solid(v, Vector3(w, h, float(d.d)), center + Vector3(0, h / 2, 0), WorldKit.mat(d.color))
		WorldKit.box(v, Vector3(w + 0.4, 0.4, float(d.d) + 0.4), center + Vector3(0, h + 0.2, 0), WorldKit.mat(Color(d.color).darkened(0.3)))
		var fz := float(d.fz) + dir * 0.04
		# Porta de aço fechada
		WorldKit.box(v, Vector3(minf(w - 1.0, 6.0), 3.0, 0.08), Vector3(d.x, 1.5, fz), WorldKit.mat(Color(0.5, 0.52, 0.55), 0.4, 0.6), false)
		for i in 8:
			WorldKit.box(v, Vector3(minf(w - 1.0, 6.0), 0.04, 0.1), Vector3(d.x, 0.3 + i * 0.36, fz), WorldKit.mat(Color(0.35, 0.37, 0.4)), false)
	_lot_sign(v, lot_id, Vector3(float(d.x) + minf(w / 2.0 - 0.5, 4.0), 0, float(d.fz) + dir * 1.4), dir)


func _lot_sign(v: Node3D, lot_id: String, pos: Vector3, dir: float) -> void:
	var sim := Game.sim
	var pdata := GameData.find("properties", "properties", lot_id)
	var contract := ""
	if sim.properties != null:
		contract = str(sim.properties.contracts.get(lot_id, ""))
	var text := "ALUGA-SE" if pdata.get("rent", 0) else "VENDE-SE"
	var col := LOT_SIGN_COLOR
	if contract == "rented":
		text = "ALUGADO POR VOCÊ"
		col = Color(0.4, 1.0, 0.5)
	elif contract == "owned":
		text = "PROPRIEDADE SUA"
		col = Color(0.4, 1.0, 0.5)
	WorldKit.cylinder(v, 0.06, 2.2, pos + Vector3(0, 1.1, 0), WorldKit.mat(Color(0.3, 0.3, 0.3)), 6)
	WorldKit.box(v, Vector3(1.8, 0.9, 0.08), pos + Vector3(0, 2.4, 0), WorldKit.mat(Color(0.12, 0.12, 0.14)), false)
	var l := WorldKit.label(v, text, pos + Vector3(0, 2.45, dir * 0.06), 36, col, 6)
	if dir < 0:
		l.rotation.y = PI
	var pname := str(pdata.get("name", lot_id))
	var it := Interactable.create("Ver imóvel: " + pname, func(): Game.request_ui("lot", lot_id), 1.6)
	it.position = pos + Vector3(0, 1.0, 0)
	v.add_child(it)


# --- Marcadores ------------------------------------------------------------------

func _update_job_beacon() -> void:
	var stop: String = Game.sim.jobs.current_stop()
	if stop == "" or not Game.playing:
		job_beacon.visible = false
		return
	job_beacon.position = city.point(stop)
	var a: Dictionary = Game.sim.jobs.active
	job_beacon.set_text("%s (%d/%d)" % [a.name, int(a.step) + 1, a.stops.size()])
	job_beacon.visible = true


func _on_job_beacon() -> void:
	var stop: String = Game.sim.jobs.current_stop()
	if stop != "":
		Audio.play("cash", -6.0)
		Game.sim.jobs.reach_stop(stop)
		_update_job_beacon()


## Converte o objetivo atual da campanha em um local da cidade (quando faz sentido).
func objective_point() -> Variant:
	var sim := Game.sim
	if sim.jobs.is_busy():
		return null
	var o: Dictionary = sim.missions.current_objective()
	if o.is_empty():
		return null
	match str(o.type):
		"bets_placed":
			return city.point("ze")
		"jobs_done":
			var best: Vector3 = city.point("deposito")
			for id in ["mercado", "loja", "deposito"]:
				if player and player.global_position.distance_to(city.point(id)) < player.global_position.distance_to(best):
					best = city.point(id)
			return best
		"property_contract":
			return city.point("lot_sala")
		"equipment_category", "business_open", "customers_served":
			if sim.has_business():
				return _business_door()
			return city.point("loja")
		"stage":
			if int(o.target) == 3:
				return city.point("lot_salao")
			if int(o.target) == 5:
				return city.point("lot_galpao")
			if int(o.target) == 6:
				return city.point("lot_terreno")
	return null


func _business_door() -> Vector3:
	var pid: String = Game.sim.business.property_id
	for id in ["lot_sala", "lot_salao", "lot_galpao", "lot_terreno"]:
		var d: Dictionary = city.lots.get(pid, {}).get("def", {})
		if d.get("id", "") == id:
			return city.point(id)
	return city.point("lot_sala")


func _update_objective_beacon() -> void:
	var p = objective_point()
	if p == null or player == null:
		objective_beacon.visible = false
		return
	var pos: Vector3 = p
	objective_beacon.position = pos
	var dist := player.global_position.distance_to(pos)
	objective_beacon.visible = dist > 4.0
	objective_beacon.set_text("OBJETIVO  %dm" % int(dist))
