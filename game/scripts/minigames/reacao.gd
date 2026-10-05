extends Challenge
## REFLEXO — um botão aparece depois de um tempo aleatório. Quem apertar antes queima a largada.

var delay := 3.0
var prizes: Array = []
var false_start_penalty := 0


func start() -> void:
	delay = ctx.rng.randf_range(2.0, 5.0)
	prizes = [ctx.scaled(3000), ctx.scaled(2000), ctx.scaled(1000)]
	false_start_penalty = ctx.scaled(500)


func time_limit() -> float:
	return delay + 4.0


func public_info() -> Dictionary:
	return {"delay": delay, "prizes": prizes, "penalty": false_start_penalty}


func validate(_pid: int, action: Dictionary) -> bool:
	return action.has("ms") or action.has("false_start")


func bot_action(pid: int) -> Dictionary:
	var p := ctx.pm.get_player(pid)
	var speed := float(GameData.character(p.character if p else "").get("speed", 0.5))
	if ctx.rng.randf() < 0.05:
		return {"false_start": true}
	return {"ms": int(ctx.rng.randf_range(230.0, 520.0) - speed * 70.0 + ctx.rng.randf_range(0, 150))}


func default_action(_pid: int) -> Dictionary:
	return {"ms": 99999, "miss": true}


func resolve() -> Array:
	var steps := []
	var valid := []
	var burned := []
	for pid in participants:
		var a: Dictionary = actions[pid]
		if a.get("false_start", false):
			burned.append(pid)
		elif not a.get("miss", false):
			valid.append(pid)
	valid.sort_custom(func(a, b): return int(actions[a].ms) < int(actions[b].ms))
	var board := []
	for pid in valid:
		board.append([pid, int(actions[pid].ms)])
	for pid in burned:
		board.append([pid, -1])
	for pid in participants:
		if not valid.has(pid) and not burned.has(pid):
			board.append([pid, -2])
	var stat := []
	for pid in valid:
		stat.append([pid, "skill_sum", clampf(1.0 - (int(actions[pid].ms) - 200) / 600.0, 0.0, 1.0)])
		stat.append([pid, "skill_n", 1])
	if valid.size() > 0:
		stat.append([valid[0], "skill_wins", 1])
	steps.append(Challenge.step("reaction_board", 3.0, {"title": "TEMPOS DE REAÇÃO", "board": board, "fx": "reveal", "camera": "screen", "stat": stat}))
	if not burned.is_empty():
		var money := []
		for pid in burned:
			money.append([pid, -false_start_penalty, "Queimou a largada"])
		steps.append(Challenge.step("banner", 2.0, {"title": "QUEIMARAM A LARGADA!", "text": ", ".join(burned.map(func(p): return pname(p))) + "  " + Fmt.delta(-false_start_penalty), "money": money, "fx": "lose"}))
	var n := mini(prizes.size(), valid.size())
	for k in range(n - 1, -1, -1):
		var pid: int = valid[k]
		steps.append(Challenge.step("player_result", 2.0 if k > 0 else 2.8, {"title": "%dº LUGAR: %s" % [k + 1, pname(pid)], "text": "%d ms   %s" % [int(actions[pid].ms), Fmt.delta(prizes[k])],
			"pid": pid, "money": [[pid, prizes[k], "Reação %dº" % (k + 1)]], "fx": "jackpot" if k == 0 else "win", "camera": "player"}))
	return steps
