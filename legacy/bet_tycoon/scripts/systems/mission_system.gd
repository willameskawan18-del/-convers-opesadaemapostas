class_name MissionSystem
extends RefCounted
## Campanha (capítulos com objetivos) e objetivos secundários, definidos em data/missions.json.

var sim: Simulation
var chapter_index := 0
var done: Array = []          # bools dos objetivos do capítulo atual
var secondary_done: Array = []
var hints_enabled := true


func _init(s) -> void:
	sim = s


func reset() -> void:
	chapter_index = 0
	secondary_done = []
	_reset_objectives()


func chapters() -> Array:
	return GameData.list("missions", "chapters")


func chapter() -> Dictionary:
	var c := chapters()
	if chapter_index < c.size():
		return c[chapter_index]
	return {}


func is_campaign_over() -> bool:
	return chapter_index >= chapters().size()


func _reset_objectives() -> void:
	done = []
	for o in chapter().get("objectives", []):
		done.append(false)


## Valor atual e meta de um objetivo (para barras de progresso).
func progress(o: Dictionary) -> Array:
	var target := float(o.get("target", 1))
	var cur := 0.0
	match str(o.type):
		"cash": cur = sim.economy.cash
		"net_worth": cur = sim.economy.net_worth()
		"bets_placed", "bets_won", "jobs_done", "customers_served", "profitable_days", "frauds_blocked", "competitors_defeated":
			cur = float(sim.stat(str(o.type)))
		"license": cur = 1.0 if sim.licenses.has(str(o.id)) else 0.0
		"reputation": cur = sim.reputation.value
		"level": cur = sim.progression.level
		"property_contract": cur = 1.0 if sim.properties != null and sim.properties.has_business_contract() else 0.0
		"own_property": cur = float(sim.properties.owned_count()) if sim.properties != null else 0.0
		"own_investment": cur = float(sim.properties.owned_count("investment")) if sim.properties != null else 0.0
		"equipment_category": cur = float(sim.business.count_category(str(o.id))) if sim.has_business() else 0.0
		"business_open": cur = 1.0 if sim.has_business() and sim.business.has_required_equipment() else 0.0
		"staff_count": cur = float(sim.employees.staff.size()) if sim.employees != null else 0.0
		"staff_role": cur = float(sim.employees.count_role(str(o.id))) if sim.employees != null else 0.0
		"stage": cur = float(sim.business.stage) if sim.has_business() else 0.0
		"market_share": cur = sim.competition.player_share() if sim.competition != null and sim.has_business() else 0.0
		"online_open": cur = 1.0 if sim.online != null and sim.online.open else 0.0
		"online_users": cur = sim.online.users if sim.online != null else 0.0
	return [cur, target]


func is_met(o: Dictionary) -> bool:
	var p := progress(o)
	return float(p[0]) >= float(p[1]) - 0.0001


func evaluate() -> void:
	if is_campaign_over():
		_evaluate_secondary()
		return
	var ch := chapter()
	var objs: Array = ch.get("objectives", [])
	var changed := false
	if done.size() != objs.size():
		_reset_objectives()
	for i in objs.size():
		if done[i]:
			continue
		if ch.get("ordered", false) and i > 0 and not done[i - 1]:
			break
		if is_met(objs[i]):
			done[i] = true
			changed = true
			sim.progression.add_xp(GameData.xp_value("objective"))
			sim.notify("Objetivo concluído: " + str(objs[i].text), "objective")
	if not done.has(false):
		_complete_chapter(ch)
		changed = true
	_evaluate_secondary()
	if changed:
		sim.mission_changed.emit()


func _complete_chapter(ch: Dictionary) -> void:
	var reward := float(ch.get("reward_cash", 0))
	if reward > 0:
		sim.economy.earn(reward, EconomySystem.REWARD)
	sim.progression.add_xp(GameData.xp_value("chapter"))
	sim.notify("%s CONCLUÍDO!%s" % [ch.title, (" Recompensa: " + Fmt.money(reward)) if reward > 0 else ""], "chapter")
	chapter_index += 1
	_reset_objectives()
	if ch.get("final", false) or is_campaign_over():
		sim.trigger_victory()
	else:
		var nxt := chapter()
		sim.add_message("Mentor", str(nxt.get("intro", "")))
		if chapter_index >= 4:
			hints_enabled = false


func _evaluate_secondary() -> void:
	for s in GameData.list("missions", "secondary"):
		if s.id in secondary_done:
			continue
		if is_met(s):
			secondary_done.append(s.id)
			var r := float(s.get("reward_cash", 0))
			sim.economy.earn(r, EconomySystem.REWARD)
			sim.progression.add_xp(GameData.xp_value("objective"))
			sim.notify("Objetivo secundário: %s (+%s)" % [s.text, Fmt.money(r)], "objective")


## Primeiro objetivo pendente do capítulo atual (para o HUD).
func current_objective() -> Dictionary:
	var objs: Array = chapter().get("objectives", [])
	for i in mini(objs.size(), done.size()):
		if not done[i]:
			return objs[i]
	return {}


## Volta a campanha para um capítulo anterior (usado na falência).
func rollback_to(chapter_id: String) -> void:
	var c := chapters()
	for i in c.size():
		if c[i].id == chapter_id and i < chapter_index:
			chapter_index = i
			_reset_objectives()
			sim.mission_changed.emit()
			return


func complete_current_objective() -> void:
	for i in done.size():
		if not done[i]:
			done[i] = true
			break
	if not done.has(false):
		_complete_chapter(chapter())
	sim.mission_changed.emit()


func to_dict() -> Dictionary:
	return {"chapter_index": chapter_index, "done": done, "secondary_done": secondary_done, "hints_enabled": hints_enabled}


func from_dict(d: Dictionary) -> void:
	chapter_index = int(d.get("chapter_index", 0))
	secondary_done = d.get("secondary_done", [])
	hints_enabled = bool(d.get("hints_enabled", true))
	_reset_objectives()
	var saved: Array = d.get("done", [])
	for i in mini(saved.size(), done.size()):
		done[i] = bool(saved[i])
