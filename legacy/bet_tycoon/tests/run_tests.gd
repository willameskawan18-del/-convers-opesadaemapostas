extends SceneTree
## Testes automáticos da simulação (sem gráficos).
## Executar: godot --headless --path game -s res://tests/run_tests.gd

var failures := 0
var checks := 0


func _init() -> void:
	print("=== BET TYCOON — testes automáticos ===")
	for t in get_method_list():
		var n: String = t.name
		if n.begins_with("test_"):
			print("\n> ", n)
			call(n)
	print("\n=== %d verificações, %d falhas ===" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		print("  FALHOU: ", msg)


func make_sim(seed_value: int = 42) -> Simulation:
	var sim := Simulation.new()
	sim.auto_decide = true
	sim.new_game("Teste", "Teste Bet", seed_value)
	return sim


func test_economy_basics() -> void:
	var sim := make_sim()
	check(is_equal_approx(sim.economy.cash, 100.0), "caixa inicial = 100")
	check(not sim.economy.spend(500, EconomySystem.EQUIP, true), "não gasta além do caixa")
	check(is_equal_approx(sim.economy.cash, 100.0), "caixa intacto após gasto negado")
	sim.economy.earn(50, EconomySystem.JOBS)
	check(is_equal_approx(sim.economy.cash, 150.0), "earn soma")
	sim.economy.earn(-10, EconomySystem.JOBS)
	check(is_equal_approx(sim.economy.cash, 150.0), "earn ignora negativo")
	check(Fmt.money(1234567) == "R$ 1.234.567", "formatação de moeda: " + Fmt.money(1234567))
	sim.free()


func test_betting_probabilities() -> void:
	var sim := make_sim(7)
	check(sim.betting.events.size() > 10, "eventos gerados para hoje e amanhã")
	for e in sim.betting.events:
		var t := 0.0
		for p in e.true_p:
			t += float(p)
			check(float(p) > 0.0 and float(p) < 1.0, "probabilidade válida")
		check(absf(t - 1.0) < 0.001, "probabilidades somam 1")
		for i in e.outcomes.size():
			check(sim.betting.market_odds(e, i) >= 1.02, "odds mínimas")
	sim.free()


func test_player_bet_settlement() -> void:
	var sim := make_sim(3)
	var ev: Dictionary = sim.betting.open_events()[0]
	check(sim.betting.place_player_bet(ev.id, 0, 50), "aposta aceita")
	check(is_equal_approx(sim.economy.cash, 50.0), "stake debitado")
	check(not sim.betting.place_player_bet(ev.id, 0, 1000), "aposta acima do caixa recusada")
	check(not sim.betting.place_player_bet(ev.id, 0, 1), "aposta abaixo do mínimo recusada")
	var guard := 0
	while ev.status != "finished" and guard < 3000:
		sim.advance(1)
		guard += 1
	check(ev.status == "finished", "evento encerrado")
	check(sim.betting.player_bets.is_empty(), "aposta liquidada")
	var rec: Dictionary = sim.betting.player_history[-1]
	if rec.won:
		check(sim.economy.cash >= 50.0 + 50.0 * float(rec.odds) - 0.01 - 0.0, "prêmio pago")
	check(sim.stat("bets_placed") == 1.0, "estatística de apostas")
	sim.free()


func test_odds_fairness_long_run() -> void:
	# Valor esperado de apostar sem informação deve ser negativo (margem da casa),
	# tanto nas odds do mercado quanto nas odds da banca do jogador.
	var sim := make_sim(11)
	var ev_market := 0.0
	var n := 0
	for day in 10:
		for ev in sim.betting.events:
			for i in ev.outcomes.size():
				ev_market += float(ev.market_p[i]) * sim.betting.market_odds(ev, i) - 1.0
				n += 1
		sim.advance(1440)
	print("  EV médio por R$1 (odds do mercado, prob. de mercado): %.3f" % (ev_market / n))
	check(ev_market / n < -0.05, "margem do mercado ~9%")
	sim.free()


func test_jobs() -> void:
	var sim := make_sim()
	sim.time.minute = 9 * 60
	check(sim.jobs.start("limpeza"), "turno iniciado")
	check(not sim.jobs.start("entrega"), "não inicia dois trabalhos")
	sim.advance(121)
	check(not sim.jobs.is_busy(), "turno concluído")
	check(sim.economy.cash >= 180.0, "turno pago")
	check(sim.jobs.availability(sim.jobs.job_data("limpeza")) != "", "cooldown ativo")
	check(sim.jobs.start("carregar"), "entrega iniciada")
	for stop in sim.jobs.active.stops.duplicate():
		sim.jobs.reach_stop(stop)
	check(sim.stat("jobs_done") == 2.0, "dois trabalhos concluídos")
	sim.free()


func test_loans() -> void:
	var sim := make_sim()
	check(sim.loans.take("micro"), "microcrédito aprovado")
	check(not sim.loans.take("micro"), "não pega o mesmo empréstimo duas vezes")
	check(sim.loans.max_active_loans() == 1, "só um empréstimo por vez no começo")
	check(is_equal_approx(sim.economy.cash, 1600.0), "principal creditado")
	var debt := sim.loans.total_debt()
	check(debt > 1500.0, "dívida inclui juros")
	sim.advance(1440)
	check(sim.loans.total_debt() < debt, "parcela cobrada no fechamento do dia")
	sim.economy.earn(2000, EconomySystem.JOBS)
	check(sim.loans.pay_off(1), "quitação antecipada")
	check(sim.loans.total_debt() == 0.0, "sem dívida após quitação")
	sim.free()


func test_missions_and_xp() -> void:
	var sim := make_sim()
	check(sim.missions.chapter_index == 0, "começa no capítulo 1")
	var ev: Dictionary = sim.betting.open_events()[0]
	sim.betting.place_player_bet(ev.id, 0, 10)
	sim.after_action()
	check(sim.missions.done[0], "objetivo de aposta concluído")
	sim.progression.add_xp(10000)
	check(sim.progression.level > 3, "subiu de nível")
	sim.free()


func test_save_load_roundtrip() -> void:
	var sim := make_sim(99)
	sim.economy.earn(1234, EconomySystem.JOBS)
	sim.advance(600)
	var ev: Dictionary = sim.betting.open_events()[0]
	sim.betting.place_player_bet(ev.id, 1, 20)
	var d := sim.to_dict()
	check(SaveSystem.save_game({"sim": d, "timestamp": "teste"}, "test_slot"), "save gravado")
	var loaded := SaveSystem.load_game("test_slot")
	check(not loaded.is_empty(), "save lido")
	var sim2 := Simulation.new()
	sim2.from_dict(loaded.sim)
	check(is_equal_approx(sim2.economy.cash, sim.economy.cash), "caixa restaurado")
	check(sim2.time.abs_minute() == sim.time.abs_minute(), "tempo restaurado")
	check(sim2.betting.player_bets.size() == 1, "aposta aberta restaurada")
	check(sim2.missions.chapter_index == sim.missions.chapter_index, "campanha restaurada")
	# corrupção: arquivo principal danificado deve cair no backup
	SaveSystem.save_game({"sim": d, "timestamp": "teste2"}, "test_slot")
	var p := ProjectSettings.globalize_path("user://saves/test_slot.json")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string("{lixo")
	f.close()
	check(not SaveSystem.load_game("test_slot").is_empty(), "backup usado quando save corrompe")
	SaveSystem.delete_save("test_slot")
	sim.free()
	sim2.free()


## Opera uma banca de estágio 1 por 10 dias com o jogador atendendo das 10h às 22h.
func test_business_stage1_economy() -> void:
	var sim := make_sim(5)
	sim.economy.cash = 8000.0
	sim.progression.add_xp(200)
	check(sim.licenses.buy("basica"), "alvará")
	check(sim.properties.rent("sala_comercio"), "aluguel")
	check(sim.business.buy_equipment("balcao_simples"), "balcão")
	check(sim.business.buy_equipment("computador"), "computador")
	sim.business.buy_equipment("cadeiras")
	var start_cash := sim.economy.cash
	for day in 10:
		while sim.time.day == day + 1:
			sim.player_at_counter = sim.time.minute >= 600 and sim.time.minute < 1320
			for e in sim.business.equipment:
				if e.broken:
					sim.business.repair(int(e.uid))
			sim.advance(10)
		var r := sim.last_report
		print("  dia %2d: atendidos %3d | receita %s | despesas %s | lucro banca %s | caixa %s | rep %d" % [int(r.day), int(r.served), Fmt.money(float(r.revenue)), Fmt.money(float(r.expenses)), Fmt.money(float(r.biz_profit)), Fmt.money(float(r.cash)), int(r.rep_to)])
	check(sim.economy.cash > start_cash, "banca pequena dá lucro em 10 dias")
	check(sim.stat("customers_served") > 100, "atendeu clientes")
	check(not is_nan(sim.economy.cash), "caixa válido")
	sim.free()


func test_casino_rtp() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var n := 200000
	var rtps := {}
	var t := 0.0
	for i in n: t += CasinoLogic.slot_spin(rng).mult
	rtps["caca_niquel"] = t / n
	t = 0.0
	for i in n: t += CasinoLogic.video_slot_spin(rng).mult
	rtps["video_slot"] = t / n
	t = 0.0
	for i in n: t += CasinoLogic.roulette_payout("vermelho", rng.randi_range(0, 36))
	rtps["roleta"] = t / n
	t = 0.0
	for i in n / 2: t += CasinoLogic.baccarat_payout("banca", CasinoLogic.baccarat_deal(rng).winner)
	rtps["bacara_banca"] = t / (n / 2)
	t = 0.0
	for i in n: t += CasinoLogic.bac_dice_payout("jogador", CasinoLogic.bac_dice(rng).winner)
	rtps["bac_dados"] = t / n
	t = 0.0
	for i in n: t += CasinoLogic.dragon_tiger_payout("dragao", CasinoLogic.dragon_tiger(rng).winner)
	rtps["dragao_tigre"] = t / n
	t = 0.0
	for i in n: t += CasinoLogic.sic_bo_payout("grande", CasinoLogic.sic_bo_roll(rng))
	rtps["sic_bo"] = t / n
	t = 0.0
	for i in n: t += 2.0 if CasinoLogic.crash_point(rng) >= 2.0 else 0.0
	rtps["aviaozinho_2x"] = t / n
	t = 0.0
	for i in n:
		var p := CasinoLogic.plinko_drop(rng)
		t += CasinoLogic.PLINKO_MULTS[p.reduce(func(a, b): return a + b, 0)]
	rtps["plinko"] = t / n
	t = 0.0
	for i in n: t += CasinoLogic.scratch(rng).mult
	rtps["raspadinha"] = t / n
	t = 0.0
	for i in n / 4: t += CasinoLogic.keno_payout([3, 17, 22], CasinoLogic.keno_draw(rng))
	rtps["keno_3"] = t / (n / 4)
	t = 0.0
	for i in n / 4:
		var p2 := [CasinoLogic.draw(rng), CasinoLogic.draw(rng)]
		var d := [CasinoLogic.draw(rng), CasinoLogic.draw(rng)]
		while CasinoLogic.bj_value(p2) < 17: p2.append(CasinoLogic.draw(rng))
		CasinoLogic.bj_dealer_play(rng, d)
		t += CasinoLogic.bj_settle(p2, d)
	rtps["blackjack_simples"] = t / (n / 4)
	t = 0.0
	var cnt := 0
	for i in n / 10:
		var card := CasinoLogic.bingo_card(rng)
		var balls := CasinoLogic.bingo_balls(rng)
		t += float(CasinoLogic.BINGO_PAY.get(card.filter(func(x): return x in balls).size(), 0.0))
		cnt += 1
	rtps["bingo"] = t / cnt
	t = 0.0
	for i in n / 4:
		var deck := CasinoLogic.shuffled_deck(rng)
		t += float(CasinoLogic.VP_PAY.get(CasinoLogic.vp_evaluate(deck.slice(0, 5)), 0.0))
	rtps["video_poker_sem_troca"] = t / (n / 4)
	for k in rtps:
		print("  RTP %-22s %.3f" % [k, rtps[k]])
		check(rtps[k] < 1.0 and rtps[k] > 0.25, "RTP de %s abaixo de 100%%" % k)
	check(CasinoLogic.vp_evaluate([0, 12, 11, 10, 9]) == "Royal Flush", "royal flush reconhecido")
	check(CasinoLogic.vp_evaluate([0, 13, 1, 14, 5]) == "Dois Pares", "dois pares reconhecido")
	check(CasinoLogic.bj_value([0, 12]) == 21 and CasinoLogic.bj_value([0, 0, 8]) == 21, "valores do 21")
	check(absf(CasinoLogic.mines_multiplier(3, 1) - 0.97 / (22.0 / 25.0)) < 0.02, "multiplicador do campo minado")


func test_competition_and_events() -> void:
	var sim := make_sim(8)
	sim.economy.cash = 50000.0
	sim.progression.add_xp(200)
	sim.licenses.buy("basica")
	sim.properties.rent("sala_comercio")
	sim.business.buy_equipment("balcao_simples")
	sim.business.buy_equipment("computador")
	sim.time.minute = 12 * 60
	var share := sim.competition.player_share()
	print("  participação inicial: ", Fmt.pct(share))
	check(share > 0.05 and share < 0.95, "participação de mercado válida")
	for d in 15:
		sim.player_at_counter = true
		sim.advance(1440)
	for c in sim.competition.comps:
		print("  %s: capital %s, rep %d, estado %s, status %s" % [c.name, Fmt.money(float(c.capital)), int(c.reputation), c.state, c.status])
		check(not is_nan(float(c.capital)), "capital válido")
	sim.economy.cash = 10000000.0
	sim.progression.add_xp(20000)
	var ze := sim.competition.get_comp("ze")
	if ze.status == "active":
		check(sim.competition.acquire("ze"), "aquisição do Zé")
	var cash := sim.economy.cash
	sim.advance(1440)
	check(sim.economy.today_income.has(EconomySystem.BRANCHES) or sim.economy.history[-1].revenue > 0, "filial gera renda")
	# Eventos: dispara todos e resolve
	sim.time.minute = 14 * 60
	for e in GameData.list("events", "events"):
		sim.events.trigger(e)
	check(sim.stat("events_survived") > 10, "eventos resolvidos: %d" % int(sim.stat("events_survived")))
	check(not is_nan(sim.economy.cash), "caixa válido após eventos")
	check(sim.promotions.launch("panfletos"), "promoção lançada")
	check(sim.promotions.arrival_mult() > 1.0, "promoção aumenta clientes")
	sim.free()
