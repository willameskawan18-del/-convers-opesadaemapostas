extends Challenge
## MATEMÁTICA — 3 contas rápidas (12 s cada) com dinheiro do show. Acertar rende; errar custa.

const COUNT := 3
var qs: Array = []   # {q, a:[4], c}


func start() -> void:
	for i in COUNT:
		qs.append(_make(i))


func _make(level: int) -> Dictionary:
	var r := ctx.rng
	var q := ""
	var ans := 0
	match r.randi_range(0, 4):
		0:
			var base := r.randi_range(2, 20) * 1000
			var pct: int = [10, 20, 25, 50, 75][r.randi_range(0, 4)]
			q = "Você tem %s e ganha %d%%. Quanto terá?" % [Fmt.money(base), pct]
			ans = base + base * pct / 100
		1:
			var base := r.randi_range(4, 40) * 500
			var pct: int = [10, 20, 25, 50][r.randi_range(0, 3)]
			q = "Você tem %s e perde %d%%. Quanto sobra?" % [Fmt.money(base), pct]
			ans = base - base * pct / 100
		2:
			var a := r.randi_range(6, 19 + level * 5)
			var b := r.randi_range(3, 12)
			q = "Quanto é %d x %d?" % [a, b]
			ans = a * b
		3:
			var a := r.randi_range(120, 900)
			var b := r.randi_range(45, 480)
			q = "Quanto é %d + %d?" % [a, b]
			ans = a + b
		_:
			var stake := r.randi_range(2, 9) * 500
			var m := r.randi_range(2, 5)
			q = "Você aposta %s numa porta x%d e acerta. Quanto recebe no total?" % [Fmt.money(stake), m]
			ans = stake * m
	var opts := [ans]
	var tries := 0
	while opts.size() < 4 and tries < 50:
		tries += 1
		var delta: int = [10, 50, 100, 250, 500, 1000][r.randi_range(0, 5)] * (1 if r.randf() < 0.5 else -1)
		if ans < 300:
			delta = r.randi_range(1, 12) * (1 if r.randf() < 0.5 else -1)
		var w: int = ans + delta
		if w > 0 and not opts.has(w):
			opts.append(w)
	while opts.size() < 4:
		opts.append(ans + opts.size() * 7)
	opts.shuffle()
	var is_money := q.contains("$")
	return {"q": q, "a": opts.map(func(v): return Fmt.money(v) if is_money else str(v)), "c": opts.find(ans)}


func stage_title() -> String:
	return "CONTA %d DE %d" % [stage, COUNT]


func time_limit() -> float:
	return 12.0


func options(_pid: int) -> Array:
	var q: Dictionary = qs[stage - 1]
	var out := []
	for i in 4:
		out.append({"id": str(i), "label": str(q.a[i]), "desc": "", "color": [Pal.PINK, Pal.CYAN, Pal.GOLD, Pal.GREEN][i]})
	return out


func private_info(_pid: int) -> Dictionary:
	return {"prompt": str(qs[stage - 1].q), "lines": ["Certo: %s (mais rápido: +%s)  ·  Errado: %s" % [Fmt.delta(ctx.scaled(700)), Fmt.money(ctx.scaled(500)), Fmt.delta(-ctx.scaled(300))]], "layout": "grid", "timed": true}


func validate(pid: int, action: Dictionary) -> bool:
	return str(action.get("choice", "")) == "-1" or super.validate(pid, action)


func bot_action(pid: int) -> Dictionary:
	var sk := ctx.bot_skill(pid, "knowledge")
	var q: Dictionary = qs[stage - 1]
	var c := int(q.c) if ctx.rng.randf() < 0.5 + sk * 0.4 else (int(q.c) + ctx.rng.randi_range(1, 3)) % 4
	return {"choice": str(c), "ms": int(ctx.rng.randf_range(2500.0, 9000.0) - sk * 1500.0)}


func bot_delay(_pid: int, action: Dictionary) -> float:
	return float(action.get("ms", 4000)) / 1000.0


func default_action(_pid: int) -> Dictionary:
	return {"choice": "-1", "ms": 99999}


func has_next_stage() -> bool:
	return stage < COUNT


func resolve() -> Array:
	var q: Dictionary = qs[stage - 1]
	var money := []
	var stat := []
	var rows := []
	var right := participants.filter(func(pid): return str(actions[pid].get("choice", "")) == str(int(q.c)))
	right.sort_custom(func(a, b): return int(actions[a].get("ms", 99999)) < int(actions[b].get("ms", 99999)))
	for pid in participants:
		stat.append([pid, "answered", 1])
		var ok := right.has(pid)
		var d := ctx.scaled(700) + (ctx.scaled(500) if right.size() > 0 and right[0] == pid else 0) if ok else -ctx.scaled(300)
		if str(actions[pid].get("choice", "-1")) == "-1" and not ok:
			d = -ctx.scaled(300)
		if ok:
			stat.append([pid, "correct", 1])
		money.append([pid, d, "Matemática"])
		rows.append([pname(pid), ("CERTO " if ok else "ERRADO ") + Fmt.delta(d), pcolor(pid), Pal.GREEN if ok else Pal.RED])
	return [Challenge.list_step("%s = %s" % [q.q, q.a[int(q.c)]], rows, 2.8, {"money": money, "stat": stat})]
