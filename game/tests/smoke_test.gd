extends Node
## Fluxo completo COM interface: menu → PLAY → partida (humano escolhendo) → resultado →
## jogar novamente → menu → CREATE GAME (lobby com 2 locais + bot) → partida → menu.
## godot --headless --path . res://tests/smoke_test.tscn

var fails := 0
var main: Node
var ended := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FALHOU: ", msg)


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	Game.match_ended.connect(func(_s): ended += 1)
	Game.phase_changed.connect(_auto_play)
	Game.private_info_received.connect(func(_p, _i): _auto_play(str(Game.view.phase), Game.view.phase_info))
	await get_tree().create_timer(1.0).timeout
	check(main.ui._current == "menu", "começa no menu")
	check(main.ui.screen_root.get_child_count() == 1, "menu construído")
	Engine.time_scale = 12.0
	main.ui.quick_play()
	await _until(func(): return ended >= 1, 300.0)
	check(ended == 1, "partida rápida terminou")
	await get_tree().create_timer(2.0).timeout
	check(main.ui.results.get_child_count() > 0, "tela de resultado")
	Game.request_rematch()
	await _until(func(): return ended >= 2, 300.0)
	check(ended == 2, "jogar novamente")
	main.ui.back_to_menu()
	await get_tree().create_timer(1.0).timeout
	check(main.ui._current == "menu", "voltou ao menu")
	main.ui.open_lobby()
	await get_tree().create_timer(1.0).timeout
	check(main.ui._current == "lobby", "abriu lobby")
	Game.request_add_player("ANA", "", false)
	Game.request_add_player("", "", true)
	check(Game.view.players.size() == 3, "lobby com 3")
	Game.request_start()
	await _until(func(): return ended >= 3, 300.0)
	check(ended == 3, "partida com 2 humanos locais (hot-seat)")
	main.ui.back_to_menu()
	await get_tree().create_timer(0.5).timeout
	Engine.time_scale = 1.0
	print("SMOKE: %s (%d falhas)" % ["OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


## Simula os humanos locais clicando: usa o painel de decisão de verdade quando possível.
func _auto_play(phase: String, info: Dictionary) -> void:
	if phase != "decision" and phase != "allwin_decision":
		return
	await get_tree().create_timer(0.3).timeout
	for p in Game.local_players():
		var pid := int(p.id)
		if Game.has_submitted(pid) or not Game.private_infos.has(pid):
			continue
		match str(info.get("input", "")):
			"reaction":
				await get_tree().create_timer(float(info.public.delay) + 0.3).timeout
				Game.submit_action(pid, {"ms": 300})
			"bid":
				Game.submit_action(pid, {"bid": mini(500, int(Game.private_infos[pid].max_bid))})
			_:
				var opts: Array = Game.private_infos[pid].options
				Game.submit_action(pid, {"choice": opts[randi() % opts.size()].id})


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
