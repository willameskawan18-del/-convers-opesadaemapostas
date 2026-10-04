class_name LicenseSystem
extends RefCounted
## Licenças fictícias que liberam etapas da progressão.

var sim: Simulation
var owned: Array = []


func _init(s) -> void:
	sim = s


func reset() -> void:
	owned = []


func all() -> Array:
	return GameData.list("licenses", "licenses")


func data(id: String) -> Dictionary:
	return GameData.find("licenses", "licenses", id)


func has(id: String) -> bool:
	return id == "" or id in owned


## Retorna a lista de requisitos com status, para a UI mostrar o que falta.
func requirements(id: String) -> Array:
	var l := data(id)
	var out: Array = []
	if l.is_empty():
		return out
	out.append({"text": "Custo: " + Fmt.money(float(l.cost)), "ok": sim.economy.can_afford(float(l.cost))})
	if int(l.get("min_level", 1)) > 1:
		out.append({"text": "Nível %d" % int(l.min_level), "ok": sim.progression.level >= int(l.min_level)})
	if float(l.get("min_rep", 0)) > 0:
		out.append({"text": "Reputação %d" % int(l.min_rep), "ok": sim.reputation.value >= float(l.min_rep)})
	if int(l.get("min_stage", 0)) > 0:
		var st := int(l.min_stage)
		out.append({"text": "Estabelecimento estágio %d" % st, "ok": sim.has_business() and sim.business.stage >= st})
	for req in l.get("requires", []):
		out.append({"text": "Licença: " + str(data(str(req)).get("name", req)), "ok": has(str(req))})
	for cat in l.get("equipment", []):
		var ok: bool = sim.has_business() and sim.business.count_category(str(cat)) > 0
		out.append({"text": "Equipamento: " + str(cat).capitalize(), "ok": ok})
	return out


func can_buy(id: String) -> bool:
	if has(id):
		return false
	for r in requirements(id):
		if not r.ok:
			return false
	return true


func buy(id: String) -> bool:
	if has(id):
		return false
	if not can_buy(id):
		sim.notify("Requisitos da licença não atendidos.", "error")
		return false
	var l := data(id)
	if not sim.economy.spend(float(l.cost), EconomySystem.LICENSE_BUY):
		return false
	owned.append(id)
	sim.progression.add_xp(GameData.xp_value("license"))
	sim.notify("Licença obtida: " + str(l.name), "unlock")
	sim.after_action()
	return true


func collect_daily_costs(costs: Dictionary, _apply: bool = true) -> void:
	for id in owned:
		var fee := float(data(id).get("daily_fee", 0))
		if fee > 0:
			costs[EconomySystem.LICENSE] = float(costs.get(EconomySystem.LICENSE, 0.0)) + fee


func to_dict() -> Dictionary:
	return {"owned": owned}


func from_dict(d: Dictionary) -> void:
	owned = d.get("owned", [])
