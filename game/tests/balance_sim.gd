extends SceneTree
## Simula muitas partidas só com a lógica (bots) e mostra a distribuição do dinheiro final.
## godot --headless --path . -s res://tests/balance_sim.gd

func _init() -> void:
	var mm := MinigameManager.new()
	var finals := []
	var winners := []
	var before_allwin := []
	var per_id := {}
	for m in 120:
		var pm := PlayerManager.new()
		var chars := ["sortudo", "azarado", "rico", "trapaceiro", "apostador", "genio", "medroso", "maluco"]
		var n := 4 + m % 5
		for i in n:
			pm.add("P%d" % i, chars[(i + m) % 8], true)
		var ctx := MatchContext.new()
		ctx.pm = pm
		ctx.money = MoneyManager.new(pm)
		ctx.rng.seed = m * 7 + 3
		ctx.money.set_all(1000, "inicial")
		var rm := RoundManager.new()
		rm.setup(9, mm, ctx.rng, [])
		while rm.has_next():
			var id := rm.next(ctx.rng)
			ctx.round_index = rm.current
			ctx.high_stakes = 2.0 if rm.category() == "grande_risco" else 1.0
			var before := ctx.money.total()
			_play(mm, ctx, id)
			per_id[id] = per_id.get(id, []) + [float(ctx.money.total() - before) / n]
			ctx.high_stakes = 1.0
			if ctx.jackpot_won:
				ctx.jackpot = MatchContext.JACKPOT_BASE
				ctx.jackpot_won = false
			else:
				ctx.jackpot = mini(MatchContext.JACKPOT_CAP, int(roundf(ctx.jackpot * MatchContext.JACKPOT_GROWTH / 500.0) * 500.0))
			if rm.event_now():
				_play(mm, ctx, "evento")
		for p in pm.players:
			before_allwin.append(p.money)
		_play(mm, ctx, "allwin")
		for p in pm.players:
			finals.append(p.money)
		winners.append(pm.leader().money)
	finals.sort()
	winners.sort()
	before_allwin.sort()
	print("Antes do ALL WIN: mediana %d  p10 %d  p90 %d" % [before_allwin[before_allwin.size() / 2], before_allwin[before_allwin.size() / 10], before_allwin[before_allwin.size() * 9 / 10]])
	print("Final (todos):     mediana %d  p10 %d  p90 %d  min %d  max %d" % [finals[finals.size() / 2], finals[finals.size() / 10], finals[finals.size() * 9 / 10], finals[0], finals[-1]])
	print("Vencedores:        mediana %d  p10 %d  p90 %d" % [winners[winners.size() / 2], winners[winners.size() / 10], winners[winners.size() * 9 / 10]])
	for id in per_id:
		var arr: Array = per_id[id]
		var s := 0.0
		for v in arr:
			s += v
		print("  %-11s média por jogador %+.0f  (%d vezes)" % [id, s / arr.size(), arr.size()])
	quit()


func _play(mm: MinigameManager, ctx: MatchContext, id: String) -> void:
	var c := mm.create(id, ctx)
	while true:
		if c.needs_decision():
			for pid in c.deciders():
				c.submit(pid, c.bot_action(pid))
			c.fill_defaults()
		for s in c.resolve():
			for x in s.get("money", []):
				ctx.money.change(int(x[0]), int(x[1]), str(x[2]))
		if c.has_next_stage():
			c.next_stage()
		else:
			break
