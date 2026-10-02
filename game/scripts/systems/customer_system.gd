class_name CustomerSystem
extends RefCounted
## Clientes com personalidade e fila de atendimento.
## Visita: IDLE → WALKING → ENTERING → WAITING → SERVED → BETTING → EXITING.
## O mundo 3D apenas desenha as visitas (lista `visits`).

const WALK_MIN := 3
const ENTER_MIN := 1
const BET_MIN := 2
const EXIT_MIN := 3

var sim: Simulation
var pool: Dictionary = {}      # id -> perfil persistente
var next_id := 1
var visits: Array = []         # visitas em andamento
var next_vid := 1
var today: Dictionary = {}
var _arrival_acc := 0.0


func _init(s) -> void:
	sim = s


func reset() -> void:
	pool = {}
	next_id = 1
	visits = []
	next_vid = 1
	_arrival_acc = 0.0
	start_day()


func start_day() -> void:
	today = {"served": 0, "abandoned": 0, "turned_away": 0, "new": 0, "lost": 0, "balked": 0, "stakes": 0.0}


func types() -> Array:
	return GameData.list("customers", "types")


func type_data(id: String) -> Dictionary:
	return GameData.find("customers", "types", id)


# --- Consultas para UI/mundo -------------------------------------------------------

func queue_length() -> int:
	var n := 0
	for v in visits:
		if v.state == "waiting":
			n += 1
	return n


func inside_count() -> int:
	var n := 0
	for v in visits:
		if v.state in ["entering", "waiting", "served", "betting"]:
			n += 1
	return n


func active_servers() -> int:
	return _servers().size()


func active_customers() -> int:
	var n := 0
	for id in pool:
		if not pool[id].lost:
			n += 1
	return n


# --- Geração de clientes -----------------------------------------------------------

func _new_profile() -> Dictionary:
	var rep: float = sim.reputation.value
	var st: int = sim.business.stage
	var cands: Array = []
	var total := 0.0
	var vip_bonus := 1.0 + float(sim.business.effects().get("vip", 0.0)) * 2.0
	for t in types():
		if rep < float(t.min_rep) or st < int(t.min_stage):
			continue
		var w := float(t.weight)
		if t.id == "vip":
			w *= vip_bonus * (1.0 + (st - 3) * 0.4)
		if t.id == "novato" and st > 2:
			w *= 0.5
		cands.append([t, w])
		total += w
	var r := sim.rng.randf() * total
	var t: Dictionary = cands[0][0]
	for c in cands:
		r -= c[1]
		if r <= 0.0:
			t = c[0]
			break
	var names: Dictionary = GameData.load_json("customers")
	var fn: Array = names.get("first_names", ["Cliente"])
	var ln: Array = names.get("last_names", [""])
	var sports: Array = names.get("sports", ["futebol"])
	var pat: Array = t.patience
	var id := "C%d" % next_id
	next_id += 1
	var p := {
		"id": id, "name": "%s %s" % [fn[sim.rng.randi_range(0, fn.size() - 1)], ln[sim.rng.randi_range(0, ln.size() - 1)]],
		"type": t.id, "money": sim.rng.randf_range(0.7, 1.4),
		"confidence": 50.0, "risk": sim.rng.randf_range(0.3, 1.0) * (1.4 if t.behavior == "underdog" else 1.0),
		"loyalty": float(t.loyalty) * sim.rng.randf_range(0.7, 1.3), "frequency": float(t.frequency) * sim.rng.randf_range(0.7, 1.3),
		"satisfaction": 60.0, "sport": sports[sim.rng.randi_range(0, sports.size() - 1)],
		"promo": float(t.promo), "odds_sens": float(t.odds_sens),
		"patience": sim.rng.randf_range(float(pat[0]), float(pat[1])),
		"visits": 0, "staked": 0.0, "net": 0.0, "last_day": sim.time.day, "lost": false,
	}
	pool[id] = p
	today.new = int(today.new) + 1
	sim.add_stat("customers_new")
	if pool.size() > int(GameData.balance("customer_pool_max", 220)):
		_trim_pool()
	return p


func _trim_pool() -> void:
	var ids := pool.keys()
	ids.sort_custom(func(a, b): return (0.0 if pool[a].lost else float(pool[a].loyalty)) < (0.0 if pool[b].lost else float(pool[b].loyalty)))
	var visiting := {}
	for v in visits:
		visiting[v.cid] = true
	for id in ids.slice(0, 20):
		if not visiting.has(id):
			pool.erase(id)


func _pick_returning() -> Dictionary:
	var visiting := {}
	for v in visits:
		visiting[v.cid] = true
	var cands: Array = []
	var total := 0.0
	for id in pool:
		var p: Dictionary = pool[id]
		if p.lost or visiting.has(id) or int(p.last_day) == sim.time.day and p.visits > 0 and sim.rng.randf() < 0.7:
			continue
		var w := float(p.loyalty) * float(p.frequency) * (0.5 + float(p.satisfaction) / 100.0)
		cands.append([p, w])
		total += w
	if cands.is_empty():
		return {}
	var r := sim.rng.randf() * total
	for c in cands:
		r -= c[1]
		if r <= 0.0:
			return c[0]
	return cands[-1][0]


## Cria uma visita (chegada de um cliente). Retorna o id da visita ou -1.
func spawn_visit(forced_type: String = "") -> int:
	if not sim.has_business():
		return -1
	var active_n := active_customers()
	var p: Dictionary = {}
	if forced_type == "" and sim.rng.randf() < float(active_n) / float(active_n + 25):
		p = _pick_returning()
	if p.is_empty():
		p = _new_profile()
		if forced_type != "":
			p.type = forced_type
	var t := type_data(str(p.type))
	if not sim.business.can_take_bets():
		today.balked = int(today.balked) + 1
		return -1
	# Cliente desconfiado não entra em banca com reputação baixa
	if sim.reputation.value < float(t.get("trust", 0)):
		today.balked = int(today.balked) + 1
		return -1
	if inside_count() >= sim.business.capacity():
		today.turned_away = int(today.turned_away) + 1
		sim.reputation.add(-0.03, "Estabelecimento lotado")
		return -1
	if queue_length() > int(float(p.patience) / 3.0) + 2:
		today.balked = int(today.balked) + 1
		sim.reputation.add(-0.02, "Fila muito longa")
		return -1
	var v := {"vid": next_vid, "cid": p.id, "type": p.type, "state": "walking", "t": 0, "wait": 0, "progress": 0.0, "station": -1}
	next_vid += 1
	visits.append(v)
	p.visits = int(p.visits) + 1
	p.last_day = sim.time.day
	return int(v.vid)


# --- Simulação minuto a minuto ---------------------------------------------------------

## Estações de atendimento: jogador (se atrás do balcão), atendentes e terminais.
func _servers() -> Array:
	var out: Array = []
	var biz := sim.business
	if not biz.can_take_bets():
		return out
	var counters := biz.count_category("counter", true)
	if sim.player_at_counter:
		out.append({"id": "player", "eff": 1.0})
	for e in sim.employees.working("atendente"):
		if out.size() >= counters:
			break
		out.append({"id": str(e.id), "eff": float(e.efficiency)})
	var term_eff := 0.0
	for e in biz.equipment:
		if not e.broken and biz.item_data(str(e.id)).get("effects", {}).has("station"):
			term_eff = float(biz.item_data(str(e.id)).effects.station)
			out.append({"id": "terminal%d" % int(e.uid), "eff": term_eff})
	return out


func step_minute() -> void:
	var biz := sim.business
	if biz.is_open():
		# Chegadas como processo de Poisson (taxa por minuto)
		var rate := biz.demand_per_hour() / 60.0
		while rate > 1.0:
			rate -= 1.0
			spawn_visit()
		if sim.rng.randf() < rate:
			spawn_visit()
	if visits.is_empty():
		return
	var servers := _servers()
	var busy := {}
	for v in visits:
		if v.state == "served":
			busy[int(v.station)] = true
	var service_min := float(GameData.balance("base_service_minutes", 5.0))
	var speed := biz.service_speed_mult()
	var open := biz.is_open()
	var done: Array = []
	for v in visits:
		v.t = int(v.t) + 1
		match str(v.state):
			"walking":
				if int(v.t) >= WALK_MIN:
					_state(v, "entering")
			"entering":
				if int(v.t) >= ENTER_MIN:
					_state(v, "waiting")
			"waiting":
				v.wait = int(v.wait) + 1
				var p: Dictionary = pool.get(v.cid, {})
				if not open:
					_state(v, "exiting")
					continue
				var free := -1
				for i in servers.size():
					if not busy.has(i):
						free = i
						break
				if free >= 0 and _is_next_in_queue(v):
					busy[free] = true
					v.station = free
					v.server = servers[free].id
					v.progress = 0.0
					_state(v, "served")
				elif float(v.wait) > float(p.get("patience", 15)) * biz.patience_mult():
					_abandon(v, p)
			"served":
				var idx := int(v.station)
				if idx >= servers.size() or str(servers[idx].id) != str(v.get("server", "")):
					# O atendente saiu do guichê: volta para a fila
					v.station = -1
					_state(v, "waiting")
					continue
				v.progress = float(v.progress) + float(servers[idx].eff) * speed
				if float(v.progress) >= service_min:
					busy.erase(idx)
					_complete_service(v)
					_state(v, "betting")
			"betting":
				if int(v.t) >= BET_MIN:
					_state(v, "exiting")
			"exiting":
				if int(v.t) >= EXIT_MIN:
					done.append(v)
	for v in done:
		visits.erase(v)


func _state(v: Dictionary, state: String) -> void:
	v.state = state
	v.t = 0


func _is_next_in_queue(v: Dictionary) -> bool:
	for o in visits:
		if o.state == "waiting":
			return o == v
	return false


func queue_position(v: Dictionary) -> int:
	var i := 0
	for o in visits:
		if o.state == "waiting":
			if o == v:
				return i
			i += 1
	return -1


func _abandon(v: Dictionary, p: Dictionary) -> void:
	_state(v, "exiting")
	today.abandoned = int(today.abandoned) + 1
	sim.add_stat("customers_abandoned")
	sim.reputation.add(-0.22, "Clientes desistiram da fila")
	if not p.is_empty():
		_change_satisfaction(p, -18.0)


func _change_satisfaction(p: Dictionary, d: float) -> void:
	p.satisfaction = clampf(float(p.satisfaction) + d, 0.0, 100.0)
	if float(p.satisfaction) < 20.0 and not p.lost:
		p.lost = true
		today.lost = int(today.lost) + 1
		sim.add_stat("customers_lost")


func _complete_service(v: Dictionary) -> void:
	var p: Dictionary = pool.get(v.cid, {})
	if p.is_empty():
		return
	var t := type_data(str(p.type))
	today.served = int(today.served) + 1
	sim.add_stat("customers_served")
	sim.progression.add_xp(GameData.xp_value("customer_served"))
	var patience := float(p.patience) * sim.business.patience_mult()
	var wait_ratio := clampf(float(v.wait) / maxf(patience, 1.0), 0.0, 1.0)
	var sat := 6.0 - wait_ratio * 14.0 + sim.business.comfort() * 0.15
	var rep := 0.08 - wait_ratio * 0.2
	if str(v.get("server", "")) != "player":
		var emp := sim.employees.get_employee(str(v.server))
		if not emp.is_empty():
			rep += float(sim.employees.trait_data(str(emp.trait)).get("rep", 0.0))
	sim.reputation.add(rep, "Atendimento")
	_change_satisfaction(p, sat)
	_place_bets(p, t)
	# Erro de pagamento/registro (menor com caixa e caixa registradora)
	var err := 0.025 * (1.0 - float(sim.business.effects().get("error_reduction", 0.0))) * (0.4 if sim.employees.count_role("caixa") > 0 else 1.0)
	if sim.rng.randf() < err:
		var cost := roundf(sim.rng.randf_range(20.0, 80.0) * sim.business.stage)
		sim.economy.charge(cost, EconomySystem.OPS)
		sim.reputation.add(-0.6, "Erro no pagamento")
		_change_satisfaction(p, -10.0)
		sim.add_stat("payment_errors")
	# Clientes problemáticos podem causar conflito
	if sim.rng.randf() < float(t.get("trouble", 0.0)) * (1.0 - clampf(sim.business.security_score() / 80.0, 0.0, 0.85)):
		if sim.events != null:
			sim.events.trigger_by_id("conflito")


func _place_bets(p: Dictionary, t: Dictionary) -> void:
	var evs := sim.betting.open_events(8)
	if evs.is_empty():
		_change_satisfaction(p, -4.0)
		return
	var bets_range: Array = t.bets
	var n := sim.rng.randi_range(int(bets_range[0]), int(bets_range[1]))
	var stake_range: Array = t.stake
	var promo_m: float = 1.0 + ((sim.promotions.stake_bonus() * float(p.promo)) if sim.promotions != null else 0.0)
	var stage_m := float(sim.business.stage_data().get("stake_mult", 1.0))
	var odds_m := clampf(pow(sim.market_margin() / maxf(sim.business.margin, 0.01), float(p.odds_sens)), 0.5, 1.6)
	for k in n:
		var ev := _pick_event(evs, str(p.sport))
		var i := _pick_outcome(ev, str(t.behavior))
		if i < 0:
			continue
		var stake: float = sim.rng.randf_range(float(stake_range[0]), float(stake_range[1])) * float(p.money) * stage_m * promo_m * odds_m * (0.85 + float(ev.hype) * 0.15)
		if str(t.behavior) == "value" and i >= 0:
			var value := float(ev.true_p[i]) * sim.betting.shop_odds(ev, i)
			if value < 0.98:
				if sim.rng.randf() < 0.6:
					continue
				stake *= 0.4
		if stake > sim.business.max_stake:
			if str(p.type) == "vip":
				_change_satisfaction(p, -6.0)
			stake = sim.business.max_stake
		stake = maxf(5.0, roundf(stake))
		sim.betting.place_book_bet(str(p.id), ev, i, stake)
		p.staked = float(p.staked) + stake
		today.stakes = float(today.stakes) + stake


func _pick_event(evs: Array, sport: String) -> Dictionary:
	var total := 0.0
	var ws: Array = []
	for e in evs:
		var w := float(e.hype) * (2.5 if e.sport == sport else 1.0)
		ws.append(w)
		total += w
	var r := sim.rng.randf() * total
	for i in evs.size():
		r -= ws[i]
		if r <= 0.0:
			return evs[i]
	return evs[0]


func _pick_outcome(ev: Dictionary, behavior: String) -> int:
	var n: int = ev.outcomes.size()
	var weights: Array = []
	for i in n:
		var mp := float(ev.market_p[i])
		var w := mp
		match behavior:
			"favorite": w = mp * mp
			"favorite_strong": w = pow(mp, 4.0)
			"underdog": w = pow(1.0 - mp, 2.0)
			"value": w = pow(maxf(0.01, float(ev.true_p[i]) * sim.betting.shop_odds(ev, i)), 8.0)
			"random": w = 1.0
		if ev.suspended[i]:
			w = 0.0
		weights.append(w)
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return -1
	var r := sim.rng.randf() * total
	for i in n:
		r -= weights[i]
		if r <= 0.0:
			return i
	return n - 1


## Resultado de uma aposta do cliente (chamado pelo BettingSystem).
func on_bet_result(cid: String, won: bool, net: float) -> void:
	var p: Dictionary = pool.get(cid, {})
	if p.is_empty():
		return
	p.net = float(p.net) + net
	if won:
		_change_satisfaction(p, 8.0)
		p.loyalty = minf(1.5, float(p.loyalty) + 0.03)
		if net > 500.0:
			sim.reputation.add(0.25, "Prêmios pagos em dia")
	else:
		_change_satisfaction(p, -2.0)


func daily() -> void:
	for id in pool:
		var p: Dictionary = pool[id]
		if sim.time.day - int(p.last_day) > 7:
			p.loyalty = maxf(0.05, float(p.loyalty) * 0.95)
		if sim.promotions != null and sim.promotions.loyalty_active():
			p.loyalty = minf(1.5, float(p.loyalty) + 0.01)
	visits = visits.filter(func(v): return v.state != "exiting")


func to_dict() -> Dictionary:
	return {"pool": pool, "next_id": next_id, "visits": visits, "next_vid": next_vid, "today": today}


func from_dict(d: Dictionary) -> void:
	pool = d.get("pool", {})
	next_id = int(d.get("next_id", 1))
	visits = d.get("visits", [])
	for v in visits:
		v.vid = int(v.vid)
		v.t = int(v.t)
		v.wait = int(v.wait)
		v.station = int(v.station)
	next_vid = int(d.get("next_vid", 1))
	today = d.get("today", today)
