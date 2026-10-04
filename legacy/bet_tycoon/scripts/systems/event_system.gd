class_name EventSystem
extends RefCounted
## Eventos aleatórios (data/events.json). Alguns só notificam; outros pedem uma decisão.
## Fraudes e explorações são abstratas: o jogo nunca descreve como executá-las.

var sim: Simulation
var today_count := 0
var last_abs := -9999
var history: Array = []


func _init(s) -> void:
	sim = s


func reset() -> void:
	today_count = 0
	last_abs = -9999
	history = []


func start_day() -> void:
	today_count = 0


func all() -> Array:
	return GameData.list("events", "events")


func _eligible(e: Dictionary) -> bool:
	if e.get("requires_business", false) and not (sim.has_business() and sim.business.is_open()):
		return false
	if e.get("requires_staff", false) and (sim.employees == null or sim.employees.staff.is_empty()):
		return false
	if e.get("requires_casino", false):
		var has := false
		if sim.has_business():
			for it in sim.business.equipment:
				if sim.business.item_data(str(it.id)).has("casino"):
					has = true
		if not has:
			return false
	if sim.has_business() and sim.business.stage < int(e.get("min_stage", 0)):
		return false
	if sim.reputation.value < float(e.get("min_rep", 0)):
		return false
	if sim.progression.level < int(e.get("min_level", 1)):
		return false
	if e.has("hours"):
		var h := sim.time.hour()
		if h < int(e.hours[0]) or h > int(e.hours[1]):
			return false
	return true


func hourly() -> void:
	var cfg: Dictionary = GameData.load_json("events")
	if today_count >= int(cfg.get("max_per_day", 3)):
		return
	if sim.time.abs_minute() - last_abs < 120:
		return
	if sim.rng.randf() > float(cfg.get("chance_per_hour", 0.08)):
		return
	trigger_random()


func trigger_random(force: bool = false) -> void:
	var cands: Array = []
	var total := 0.0
	for e in all():
		if float(e.get("weight", 0)) <= 0.0 or not _eligible(e):
			continue
		cands.append(e)
		total += float(e.weight)
	if cands.is_empty():
		if force:
			sim.notify("Nenhum evento disponível agora (abra sua banca para mais eventos).", "info")
		return
	var r := sim.rng.randf() * total
	for e in cands:
		r -= float(e.weight)
		if r <= 0.0:
			trigger(e)
			return
	trigger(cands[-1])


func trigger_by_id(id: String) -> void:
	var e := GameData.find("events", "events", id)
	if not e.is_empty():
		trigger(e)


func trigger(e: Dictionary) -> void:
	today_count += 1
	last_abs = sim.time.abs_minute()
	history.append({"day": sim.time.day, "title": e.title})
	if history.size() > 30:
		history.pop_front()
	if e.has("options"):
		var ev := e.duplicate(true)
		for o in ev.options:
			if o.has("cost_stage"):
				var cost := float(o.cost_stage) * _stage_mult()
				o["cost"] = cost
				o["label"] = "%s (%s)" % [o.label, Fmt.money(cost)]
		sim.notify(str(e.title), "event")
		sim.request_decision(ev)
	else:
		sim.notify("%s — %s" % [e.title, e.text], "event")
		apply_effects(e.get("effects", {}))
		sim.add_stat("events_survived")
		sim.progression.add_xp(GameData.xp_value("event_survived"))


func _stage_mult() -> float:
	return float(maxi(1, sim.business.stage)) if sim.has_business() else 1.0


## Resolve uma decisão escolhida pelo jogador.
func resolve(ev: Dictionary, index: int) -> void:
	var opts: Array = ev.get("options", [])
	if index < 0 or index >= opts.size():
		return
	var o: Dictionary = opts[index]
	if o.has("cost"):
		if not sim.economy.can_afford(float(o.cost)) and index + 1 < opts.size():
			sim.notify("Sem dinheiro para essa opção.", "error")
			resolve(ev, opts.size() - 1)
			return
		sim.economy.charge(float(o.cost), EconomySystem.EVENTS)
	apply_effects(o.get("effects", {}))
	sim.add_stat("events_survived")
	sim.progression.add_xp(GameData.xp_value("event_survived"))
	sim.after_action()


func request_raise(e: Dictionary) -> void:
	var ev := {"id": "aumento", "title": "PEDIDO DE AUMENTO", "employee": str(e.id),
		"text": "%s subiu de nível e pede um aumento de 15%% (de %s para %s por dia)." % [e.name, Fmt.money(float(e.salary)), Fmt.money(roundf(float(e.salary) * 1.15))],
		"options": [
			{"label": "Dar o aumento", "effects": {"raise": str(e.id)}, "desc": "Funcionário mais satisfeito."},
			{"label": "Recusar", "effects": {"employee_sat": {"id": str(e.id), "delta": -20}}, "desc": "A satisfação dele cai bastante."},
		]}
	sim.request_decision(ev)


func apply_effects(fx: Dictionary) -> void:
	var sm := _stage_mult()
	var result := str(fx.get("result", ""))
	if fx.has("cash"):
		_cash(float(fx.cash))
	if fx.has("cash_stage"):
		_cash(float(fx.cash_stage) * sm)
	if fx.has("rep"):
		sim.reputation.add(float(fx.rep), "Eventos")
	if fx.has("xp"):
		sim.progression.add_xp(int(fx.xp))
	if fx.has("stat"):
		sim.add_stat(str(fx.stat))
	if fx.has("boost") and sim.has_business():
		var b: Dictionary = fx.boost
		sim.business.boosts.append({"mult": float(b.mult), "until": sim.time.abs_minute() + int(float(b.hours) * 60.0), "label": str(b.get("label", ""))})
	if fx.has("break_equipment") and sim.has_business():
		if sim.business.break_random(str(fx.break_equipment)):
			sim.notify("Conserte em Administração > Equipamentos.", "warning")
	if fx.has("internet_down") and sim.has_business():
		sim.business.internet_down_until = sim.time.abs_minute() + int(float(fx.internet_down) * 60.0)
	if fx.has("employee_absent") and sim.employees != null:
		var n := sim.employees.mark_random_absent()
		if n != "":
			sim.notify("%s não vem trabalhar hoje." % n, "warning")
	if fx.has("star_candidate") and sim.employees != null:
		sim.employees.add_star_candidate()
	if fx.has("inspection"):
		_inspection()
	if fx.has("competitor_promo") and sim.competition != null:
		var nm := sim.competition.force_promotion()
		if nm != "":
			sim.notify("%s está com odds turbinadas por 3 dias." % nm, "competitor")
	if fx.has("vip_visit") and sim.customers != null:
		sim.customers.spawn_visit("vip")
	if fx.has("cost_increase") and sim.has_business():
		var ci: Dictionary = fx.cost_increase
		sim.business.cost_mods.append({"category": str(ci.category), "mult": float(ci.mult), "until_day": sim.time.day + int(ci.days)})
	if fx.has("property_discount") and sim.properties != null:
		var pd: Dictionary = fx.property_discount
		var nm2 := sim.properties.add_discount(float(pd.pct), int(pd.days))
		if nm2 != "":
			sim.notify("Desconto de %s em: %s" % [Fmt.pct(float(pd.pct), 0), nm2], "cash")
	if fx.has("supplier_discount") and sim.has_business():
		var sd: Dictionary = fx.supplier_discount
		sim.business.supplier_discount = {"pct": float(sd.pct), "until": sim.time.abs_minute() + int(float(sd.hours) * 60.0)}
	if fx.has("stakes_loss_pct"):
		_cash(-float(sim.betting.book_today.stakes) * float(fx.stakes_loss_pct))
	if fx.has("robbery"):
		_robbery()
	if fx.has("raise") and sim.employees != null:
		sim.employees.raise_salary(str(fx.raise))
	if fx.has("employee_sat") and sim.employees != null:
		var e := sim.employees.get_employee(str(fx.employee_sat.id))
		if not e.is_empty():
			e.satisfaction = clampf(float(e.satisfaction) + float(fx.employee_sat.delta), 0.0, 100.0)
	if fx.has("chance"):
		var ch: Dictionary = fx.chance
		var p := float(ch.p)
		if ch.get("security", false) and sim.has_business():
			p += clampf(sim.business.security_score() / 100.0, 0.0, 0.45)
		if sim.rng.randf() < p:
			apply_effects(ch.get("success", {}))
		else:
			apply_effects(ch.get("fail", {}))
	if result != "":
		sim.notify(result, "event")


func _cash(v: float) -> void:
	if v > 0.0:
		sim.economy.earn(v, EconomySystem.EVENTS_IN)
	elif v < 0.0:
		sim.economy.charge(-v, EconomySystem.EVENTS)


func _inspection() -> void:
	var sec := sim.business.security_score() if sim.has_business() else 0.0
	var ok := sim.licenses.has("basica") and sec >= 12.0
	if sim.has_business() and sim.business.stage >= 3:
		ok = ok and sim.licenses.has("comercial")
	if ok:
		sim.reputation.add(2.0, "Fiscalização aprovada")
		sim.notify("Fiscalização aprovada! Tudo em ordem.", "cash")
	else:
		var fine := 400.0 * _stage_mult()
		_cash(-fine)
		sim.reputation.add(-2.0, "Fiscalização")
		sim.notify("Fiscalização encontrou problemas (segurança/licenças). Multa de %s." % Fmt.money(fine), "error")


func _robbery() -> void:
	var sec := sim.business.security_score() if sim.has_business() else 0.0
	if sim.rng.randf() < clampf(sec / 60.0, 0.0, 0.9):
		sim.add_stat("frauds_blocked")
		sim.reputation.add(1.0, "Segurança")
		sim.notify("Tentativa de roubo frustrada pela sua segurança!", "cash")
	else:
		var loss := minf(maxf(sim.economy.cash, 0.0) * 0.08, 1500.0 * _stage_mult())
		_cash(-loss)
		sim.reputation.add(-1.5, "Roubo")
		sim.notify("Roubo! Levaram %s do caixa. Invista em câmeras e seguranças." % Fmt.money(loss), "error")


func to_dict() -> Dictionary:
	return {"today_count": today_count, "last_abs": last_abs, "history": history}


func from_dict(d: Dictionary) -> void:
	today_count = int(d.get("today_count", 0))
	last_abs = int(d.get("last_abs", -9999))
	history = d.get("history", [])
