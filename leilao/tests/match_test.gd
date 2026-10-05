extends Node
## Partida só com bots (acelerada): godot --headless --path . res://tests/match_test.tscn

var fails := 0
var ended := 0
var phases := []
var bids := 0


func check(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FALHOU: ", m)


func _ready() -> void:
	Engine.time_scale = 30.0
	Game.phase_changed.connect(func(p, _i): phases.append(p))
	Game.auction_changed.connect(func(s): if s.history.size() > 0: bids += 1)
	Game.match_ended.connect(func(_s): ended += 1)
	Game.new_local_session()
	for i in 5:
		Game.request_add_player("", "", true)
	Game.request_set_config("days", 3)
	check(Game.view.players.size() == 5, "5 bots")
	Game.request_start()
	await _until(func(): return ended >= 1, 3000.0)
	check(ended == 1, "partida terminou")
	for ph in ["intro", "shop", "peek", "auction", "open", "sell", "sell_results", "day_end", "final"]:
		check(phases.has(ph), "fase " + ph)
	check(phases.count("auction") == 9, "9 leilões (%d)" % phases.count("auction"))
	check(bids > 10, "bots deram lances (%d)" % bids)
	var s: Dictionary = Game.last_summary
	check(s.ranking.size() == 5, "ranking com todos")
	for r in s.ranking:
		check(int(r.money) >= 0, "dinheiro não negativo")
		print("  %dº %s (%s) %s  galpões:%d  maior lance:%s" % [r.position, r.name, r.character, Fmt.money(r.money), r.stats.units_won, Fmt.money(r.stats.biggest_bid)])
	for a in s.awards:
		print("  PRÊMIO %s: %s — %s" % [a.title, a.name, a.value])
	var won := 0
	for u in Game.flow.unit_log:
		if int(u.winner) >= 0:
			won += 1
			print("  galpão %d (%s): pago %s, valor real %s" % [u.number, u.name, Fmt.money(u.paid), Fmt.money(u.total)])
	check(won >= 5, "maioria dos galpões vendida (%d)" % won)
	Game.request_rematch()
	await _until(func(): return ended >= 2, 3000.0)
	check(ended == 2, "revanche")
	Game.leave_to_menu()
	print("LEILAO MATCH: %s (%d falhas)" % ["OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
