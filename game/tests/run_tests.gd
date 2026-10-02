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
	# Apostar sempre sem informação deve perder dinheiro no longo prazo (margem da casa).
	var sim := make_sim(11)
	sim.economy.cash = 1_000_000.0
	var staked := 0.0
	for day in 20:
		for ev in sim.betting.open_events(30):
			if sim.betting.player_bets.size() < 200:
				var i := sim.rng.randi_range(0, ev.outcomes.size() - 1)
				if sim.betting.place_player_bet(ev.id, i, 100):
					staked += 100.0
		sim.advance(1440)
	var result := sim.economy.cash - 1_000_000.0
	print("  apostado: %s  resultado: %s  (%.1f%%)" % [Fmt.money(staked), Fmt.money(result), result / maxf(staked, 1.0) * 100.0])
	check(result < staked * 0.05, "a casa tem vantagem no longo prazo")
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
