extends Node
## Partida completa só com bots (acelerada), duas vezes seguidas (testa "jogar novamente").
## godot --headless --path . res://tests/match_test.tscn

var phases: Array = []
var ended := 0
var money_events := 0
var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	Engine.time_scale = 30.0
	Game.phase_changed.connect(func(p, _i): phases.append(p))
	Game.money_changed.connect(func(_a, _b, _c, _d): money_events += 1)
	Game.match_ended.connect(func(_s): ended += 1)
	Game.new_local_session()
	for i in 6:
		Game.request_add_player("", "", true)
	Game.request_set_config("rounds", 6)
	check(Game.view.players.size() == 6, "6 bots no lobby")
	var chars := {}
	for p in Game.view.players:
		chars[p.character] = true
	check(chars.size() == 6, "personagens diferentes")
	Game.request_start()
	await _until(func(): return ended >= 1, 400.0)
	check(ended == 1, "partida terminou")
	for ph in ["intro", "round_intro", "decision", "reveal", "round_results", "event_intro", "allwin_intro", "allwin_decision", "allwin_reveal", "final"]:
		check(phases.has(ph), "fase " + ph)
	check(phases.count("round_intro") == 6, "6 rodadas (%d)" % phases.count("round_intro"))
	check(phases.count("event_intro") == 2, "2 eventos")
	var s: Dictionary = Game.last_summary
	check(s.ranking.size() == 6, "ranking final com todos")
	for i in range(1, s.ranking.size()):
		check(int(s.ranking[i - 1].money) >= int(s.ranking[i].money), "ranking ordenado")
	check(money_events > 20, "dinheiro mudou várias vezes (%d)" % money_events)
	print("Vencedor: %s com %s" % [s.ranking[0].name, Fmt.money(s.ranking[0].money)])
	for r in s.ranking:
		print("  %dº %s (%s) %s  desafios:%d  mult:%s  risco:%s" % [r.position, r.name, r.character, Fmt.money(r.money), r.stats.challenges_won, r.stats.best_mult, Fmt.money(r.stats.max_risk)])
	# Jogar novamente
	phases.clear()
	Game.request_rematch()
	await _until(func(): return ended >= 2, 400.0)
	check(ended == 2, "revanche terminou")
	check(phases.has("intro") and phases.has("final"), "revanche completa")
	# Voltar ao lobby e ao menu
	Game.request_lobby()
	check(Game.view.mode == "lobby", "voltou ao lobby")
	Game.leave_to_menu()
	check(Game.view.mode == "menu", "voltou ao menu")
	print("MATCH TEST: %s (%d falhas)" % ["OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
