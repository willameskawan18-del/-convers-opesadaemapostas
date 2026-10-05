class_name EmployeeSystem
extends RefCounted
## Funcionários: candidatos, contratação, salário, eficiência, experiência, nível,
## satisfação, chance de erro e máquina de estados IDLE → MOVING → WORKING ⇄ RESTING / ERROR.

var sim: Simulation
var staff: Array = []
var candidates: Array = []
var next_id := 1
var last_refresh_day := -99


func _init(s) -> void:
	sim = s


func reset() -> void:
	staff = []
	candidates = []
	next_id = 1
	last_refresh_day = -99


func roles() -> Array:
	return GameData.list("employees", "roles")


func role_data(id: String) -> Dictionary:
	return GameData.find("employees", "roles", id)


func role_name(id: String) -> String:
	return str(role_data(id).get("name", id))


func trait_data(id: String) -> Dictionary:
	return GameData.find("employees", "traits", id)


func get_employee(id: String) -> Dictionary:
	for e in staff:
		if str(e.id) == id:
			return e
	return {}


func count_role(role: String) -> int:
	var n := 0
	for e in staff:
		if e.role == role:
			n += 1
	return n


## Funcionários disponíveis (trabalhando) de uma função.
func working(role: String) -> Array:
	return staff.filter(func(e): return e.role == role and e.state == "WORKING")


func _best_eff(role: String) -> float:
	var best := 0.0
	for e in working(role):
		best = maxf(best, float(e.efficiency))
	return best


func cashier_bonus() -> float:
	return 0.12 * _best_eff("caixa")


func manager_bonus() -> float:
	return 0.12 * _best_eff("gerente")


func manager_mult() -> float:
	return 1.0 + manager_bonus()


func security_bonus() -> float:
	var t := 0.0
	for e in working("seguranca"):
		t += 15.0 * float(e.efficiency)
	return t


func analyst_reduction() -> float:
	return clampf(0.35 * _best_eff("analista"), 0.0, 0.6)


func breakdown_mult() -> float:
	return 1.0 - clampf(0.4 * _best_eff("especialista"), 0.0, 0.6)


func maintenance_mult() -> float:
	return 1.0 - clampf(0.2 * _best_eff("especialista"), 0.0, 0.35)


func specialist_casino_mult() -> float:
	return 1.0 + 0.15 * _best_eff("especialista")


# --- Candidatos ------------------------------------------------------------------

func _make_candidate(role: String, star: bool = false) -> Dictionary:
	var d: Dictionary = GameData.load_json("employees")
	var fn: Array = d.first_names
	var ln: Array = d.last_names
	var traits: Array = d.traits
	var tr: Dictionary = traits[sim.rng.randi_range(0, traits.size() - 1)]
	if star:
		tr = trait_data("experiente")
	var eff := clampf(sim.rng.randfn(0.95, 0.22) + float(tr.eff), 0.5, 1.6)
	if star:
		eff = sim.rng.randf_range(1.4, 1.65)
	var exp_lv := 1 if eff < 1.0 else (2 if eff < 1.3 else 3)
	var base := float(role_data(role).base_salary)
	var salary := roundf(base * (0.55 + eff * 0.55) * float(tr.salary_mult) * (0.8 if star else 1.0) / 5.0) * 5.0
	var c := {"id": "F%d" % next_id, "name": "%s %s" % [fn[sim.rng.randi_range(0, fn.size() - 1)], ln[sim.rng.randi_range(0, ln.size() - 1)]],
		"role": role, "salary": salary, "efficiency": snappedf(eff, 0.01), "experience": 0, "level": exp_lv,
		"satisfaction": 70.0 + float(tr.get("satisfaction", 0)), "error_chance": snappedf(0.06 * float(tr.error) / eff, 0.001),
		"trait": tr.id, "state": "IDLE", "days": 0, "absent": false, "shift_offset": sim.rng.randi_range(0, 3), "error_until": 0}
	next_id += 1
	return c


func refresh_candidates(force: bool = false) -> void:
	if not force and sim.time.day - last_refresh_day < 3 and candidates.size() > 0:
		return
	last_refresh_day = sim.time.day
	candidates = []
	var avail: Array = roles().filter(func(r): return role_available(str(r.id)) == "")
	if avail.is_empty():
		avail = [role_data("atendente")]
	for i in 5:
		var r: Dictionary = avail[sim.rng.randi_range(0, avail.size() - 1)]
		if i == 0:
			r = role_data("atendente")
		candidates.append(_make_candidate(str(r.id)))


func add_star_candidate() -> void:
	var avail: Array = roles().filter(func(r): return role_available(str(r.id)) == "")
	if avail.is_empty():
		return
	var r: Dictionary = avail[sim.rng.randi_range(0, avail.size() - 1)]
	candidates.push_front(_make_candidate(str(r.id), true))


func role_available(role: String) -> String:
	var r := role_data(role)
	if not sim.has_business():
		return "Requer uma banca"
	if sim.business.stage < int(r.get("min_stage", 1)):
		return "Requer estágio %d" % int(r.min_stage)
	if sim.progression.level < int(r.get("min_level", 1)):
		return "Requer nível %d" % int(r.min_level)
	return ""


func hire_block_reason(c: Dictionary) -> String:
	var why := role_available(str(c.role))
	if why != "":
		return why
	if staff.size() >= sim.business.max_staff():
		return "Equipe no limite do estágio (%d)" % sim.business.max_staff()
	if not sim.economy.can_afford(float(c.salary)):
		return "Taxa de contratação: " + Fmt.money(float(c.salary))
	return ""


func hire(cand_id: String) -> bool:
	for c in candidates:
		if str(c.id) == cand_id:
			var why := hire_block_reason(c)
			if why != "":
				sim.notify(why, "error")
				return false
			if not sim.economy.spend(float(c.salary), EconomySystem.OPS):
				return false
			candidates.erase(c)
			c.state = "MOVING"
			staff.append(c)
			sim.progression.add_xp(GameData.xp_value("hire"))
			sim.notify("Contratado(a): %s — %s" % [c.name, role_name(str(c.role))], "cash")
			sim.add_message(str(c.name), "Obrigado pela oportunidade! Começo agora mesmo.")
			_update_states()
			sim.staff_changed.emit()
			sim.after_action()
			return true
	return false


func fire(emp_id: String) -> void:
	var e := get_employee(emp_id)
	if e.is_empty():
		return
	var severance := float(e.salary) * 2.0
	sim.economy.charge(severance, EconomySystem.SALARY)
	staff.erase(e)
	for o in staff:
		o.satisfaction = maxf(0.0, float(o.satisfaction) - 4.0)
	sim.notify("%s foi demitido(a). Rescisão: %s" % [e.name, Fmt.money(severance)], "warning")
	sim.staff_changed.emit()


func train_cost(e: Dictionary) -> float:
	return float(e.salary) * 3.0


func train(emp_id: String) -> bool:
	var e := get_employee(emp_id)
	if e.is_empty() or not sim.economy.spend(train_cost(e), EconomySystem.OPS):
		return false
	_gain_xp(e, 60)
	e.satisfaction = minf(100.0, float(e.satisfaction) + 8.0)
	e.error_chance = snappedf(float(e.error_chance) * 0.85, 0.001)
	sim.notify("%s concluiu um treinamento." % e.name, "cash")
	sim.staff_changed.emit()
	return true


func raise_salary(emp_id: String, pct: float = 0.15) -> void:
	var e := get_employee(emp_id)
	if e.is_empty():
		return
	e.salary = roundf(float(e.salary) * (1.0 + pct))
	e.satisfaction = minf(100.0, float(e.satisfaction) + 20.0)
	sim.notify("%s recebeu aumento: %s/dia" % [e.name, Fmt.money(float(e.salary))], "info")
	sim.staff_changed.emit()


func _gain_xp(e: Dictionary, amount: int) -> void:
	var mult := float(trait_data(str(e.trait)).get("xp_mult", 1.0))
	e.experience = int(e.experience) + int(amount * mult)
	var need := 100 * int(e.level)
	if int(e.experience) >= need and int(e.level) < 5:
		e.experience = int(e.experience) - need
		e.level = int(e.level) + 1
		e.efficiency = snappedf(minf(1.9, float(e.efficiency) + 0.08), 0.01)
		e.error_chance = snappedf(float(e.error_chance) * 0.8, 0.001)
		sim.notify("%s subiu para o nível %d!" % [e.name, int(e.level)], "level")
		if sim.events != null:
			sim.events.request_raise(e)


# --- Ciclo ---------------------------------------------------------------------

func _update_states() -> void:
	var open := sim.has_business() and sim.business.is_open()
	var h: int = sim.time.hour()
	var now: int = sim.time.abs_minute()
	for e in staff:
		if e.absent:
			e.state = "IDLE"
		elif not open:
			e.state = "IDLE"
		elif int(e.get("error_until", 0)) > now:
			e.state = "ERROR"
		elif (h + int(e.shift_offset)) % 5 == 0 and staff.size() > 1:
			e.state = "RESTING"
		elif e.state == "IDLE":
			e.state = "MOVING"
		else:
			e.state = "WORKING"


func hourly() -> void:
	_update_states()
	var now: int = sim.time.abs_minute()
	for e in staff:
		if e.state != "WORKING":
			continue
		if sim.rng.randf() < float(e.error_chance) / 12.0:
			e.state = "ERROR"
			e.error_until = now + 40
			if e.role in ["atendente", "caixa"]:
				var cost := roundf(sim.rng.randf_range(30.0, 120.0) * sim.business.stage)
				sim.economy.charge(cost, EconomySystem.OPS)
				sim.reputation.add(-0.5, "Erro de funcionário")
				sim.notify("%s cometeu um erro no caixa (-%s)." % [e.name, Fmt.money(cost)], "warning")
				sim.add_stat("employee_errors")


func start_day() -> void:
	for e in staff:
		e.absent = false
	_update_states()


func daily() -> void:
	var quit: Array = []
	var queue_pressure := float(sim.customers.today.get("abandoned", 0)) if sim.customers != null else 0.0
	for e in staff:
		e.days = int(e.days) + 1
		_gain_xp(e, 12)
		var expected := float(role_data(str(e.role)).base_salary) * (0.55 + float(e.efficiency) * 0.55)
		var pay_ratio := float(e.salary) / maxf(expected, 1.0)
		var d := (pay_ratio - 1.0) * 10.0 + manager_bonus() * 20.0 - minf(queue_pressure, 10.0) * 0.4 + sim.rng.randf_range(-1.5, 1.5)
		e.satisfaction = clampf(float(e.satisfaction) + d, 0.0, 100.0)
		if float(e.satisfaction) < 20.0 and sim.rng.randf() < 0.5:
			quit.append(e)
	for e in quit:
		staff.erase(e)
		sim.notify("%s pediu demissão (insatisfeito)." % e.name, "warning")
		sim.add_message(str(e.name), "Desculpe, mas encontrei um lugar que me valoriza mais.")
	if quit.size() > 0:
		sim.staff_changed.emit()
	refresh_candidates()


func collect_daily_costs(costs: Dictionary, _apply: bool = true) -> void:
	var t := 0.0
	for e in staff:
		t += float(e.salary)
	if t > 0.0:
		costs[EconomySystem.SALARY] = float(costs.get(EconomySystem.SALARY, 0.0)) + t


func dismiss_all() -> void:
	staff = []
	candidates = []
	sim.staff_changed.emit()


func mark_random_absent() -> String:
	var avail: Array = staff.filter(func(e): return not e.absent)
	if avail.is_empty():
		return ""
	var e: Dictionary = avail[sim.rng.randi_range(0, avail.size() - 1)]
	e.absent = true
	e.state = "IDLE"
	sim.staff_changed.emit()
	return str(e.name)


func to_dict() -> Dictionary:
	return {"staff": staff, "candidates": candidates, "next_id": next_id, "last_refresh_day": last_refresh_day}


func from_dict(d: Dictionary) -> void:
	staff = d.get("staff", [])
	candidates = d.get("candidates", [])
	for e in staff + candidates:
		e.level = int(e.level)
		e.experience = int(e.experience)
		e.days = int(e.get("days", 0))
		e.shift_offset = int(e.get("shift_offset", 0))
		e.error_until = int(e.get("error_until", 0))
		e.absent = bool(e.get("absent", false))
	next_id = int(d.get("next_id", 1))
	last_refresh_day = int(d.get("last_refresh_day", -99))
