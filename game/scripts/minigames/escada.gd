extends Challenge
## ESCADA DO RISCO — 5 degraus: +500, +1.000, +2.000, +4.000, +8.000.
## Em cada etapa: SUBIR (chance de cair aumenta) ou PARAR e levar o valor do degrau.
## Caiu? Perde tudo que acumulou na escada.

const LEVELS := [500, 1000, 2000, 4000, 8000]
const CHANCE := [0.9, 0.8, 0.68, 0.55, 0.42]
var level: Dictionary = {}    # pid -> degrau atual (0 = chão)
var active: Array[int] = []


func start() -> void:
	for pid in participants:
		level[pid] = 0
	active = participants.duplicate()


func deciders() -> Array[int]:
	return active


func stage_title() -> String:
	return "DEGRAU %d" % stage


func time_limit() -> float:
	return 14.0


func value_at(lv: int) -> int:
	return 0 if lv <= 0 else ctx.scaled(LEVELS[lv - 1])


func options(pid: int) -> Array:
	var lv := int(level.get(pid, 0))
	var nxt := lv + 1
	return [
		{"id": "up", "label": "SUBIR", "desc": "%d%% de chance → %s" % [int(CHANCE[nxt - 1] * 100), Fmt.money(value_at(nxt))], "color": Pal.PINK},
		{"id": "stop", "label": "PARAR" if lv > 0 else "NÃO SUBIR", "desc": "Leva " + Fmt.money(value_at(lv)), "color": Pal.GREEN},
	]


func public_info() -> Dictionary:
	return {"levels": LEVELS.map(func(v): return ctx.scaled(v)), "chances": CHANCE}


func private_info(pid: int) -> Dictionary:
	var lines := []
	for i in range(LEVELS.size() - 1, -1, -1):
		var mark := "  ◄ VOCÊ" if int(level.get(pid, 0)) == i + 1 else ""
		lines.append("Degrau %d: %s (%d%%)%s" % [i + 1, Fmt.money(value_at(i + 1)), int(CHANCE[i] * 100), mark])
	var others_txt := []
	for o in participants:
		if o != pid:
			others_txt.append("%s: %s" % [pname(o), ("degrau %d" % int(level[o])) if active.has(o) else "fora"])
	lines.append("Rivais → " + ", ".join(others_txt))
	return {"prompt": "Você está no degrau %d com %s" % [int(level.get(pid, 0)), Fmt.money(value_at(int(level.get(pid, 0))))], "lines": lines, "small_lines": true}


func bot_action(pid: int) -> Dictionary:
	var lv := int(level[pid])
	var appetite := ctx.risk_appetite(pid)
	var go: bool = ctx.rng.randf() < CHANCE[lv] * (0.55 + appetite * 0.7) - (0.05 * lv)
	return {"choice": "up" if go or lv == 0 and ctx.rng.randf() < 0.9 else "stop"}


func default_action(_pid: int) -> Dictionary:
	return {"choice": "stop"}


func has_next_stage() -> bool:
	return not active.is_empty() and stage < LEVELS.size()


func resolve() -> Array:
	var rows := []
	var money := []
	var stat := []
	var risk := []
	for pid in active.duplicate():
		var lv := int(level[pid])
		if str(actions[pid].choice) == "stop":
			if lv > 0:
				money.append([pid, value_at(lv), "Escada: degrau %d" % lv])
			rows.append([pname(pid), "PAROU no degrau %d: %s" % [lv, Fmt.delta(value_at(lv))], pcolor(pid), Pal.GREEN])
			active.erase(pid)
			continue
		if lv > 0:
			stat.append([pid, "continues", 1])
			risk.append([pid, value_at(lv)])
		if ctx.rng.randf() < CHANCE[lv]:
			level[pid] = lv + 1
			if lv + 1 >= LEVELS.size():
				money.append([pid, value_at(lv + 1), "Escada: TOPO!"])
				rows.append([pname(pid), "CHEGOU AO TOPO! %s" % Fmt.delta(value_at(lv + 1)), pcolor(pid), Pal.GOLD])
				active.erase(pid)
			else:
				rows.append([pname(pid), "SUBIU → degrau %d (%s)" % [lv + 1, Fmt.money(value_at(lv + 1))], pcolor(pid), Pal.CYAN])
		else:
			rows.append([pname(pid), "CAIU! perdeu %s" % Fmt.money(value_at(lv)), pcolor(pid), Pal.RED])
			stat.append([pid, "risk_total", value_at(lv)])
			level[pid] = 0
			active.erase(pid)
	if stage >= LEVELS.size():
		for pid in active.duplicate():
			money.append([pid, value_at(int(level[pid])), "Escada"])
			active.erase(pid)
	var fx := "lose" if rows.any(func(r): return str(r[1]).begins_with("CAIU")) else "win"
	return [Challenge.list_step("ESCADA DO RISCO — DEGRAU %d" % stage, rows, 3.0, {"money": money, "stat": stat, "risk": risk, "fx": fx, "camera": "players"})]
