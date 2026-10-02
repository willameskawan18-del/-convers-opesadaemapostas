extends Node
## Teste de fumaça da cena completa (mundo 3D + UI) em modo headless.
## Executar: godot --headless --path game res://tests/smoke_test.tscn

var main: Node
var errors := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ok(cond: bool, msg: String) -> void:
	if not cond:
		errors += 1
		print("  FALHOU: ", msg)
	else:
		print("  ok: ", msg)


func _run() -> void:
	await _frames(5)
	var ui: UIManager = main.ui
	var world: GameWorld = main.world
	var game = get_node("/root/Game")
	ui._on_new_game("Teste", "Smoke Bet")
	await _frames(10)
	_ok(game.playing, "jogo iniciado")
	_ok(world.player != null, "jogador criado")
	# Fecha modal de boas-vindas
	for c in ui.modal_layer.get_children():
		c.queue_free()
	ui._modal_closed()
	for id in ui.APPS.keys():
		if ResourceLoader.exists(ui.APPS[id]):
			ui.open_app(id, "ze" if id == "apostas" else ("sala_comercio" if id == "lot" else ("lucky" if id == "competitor" else null)))
			await _frames(2)
			_ok(ui.window.visible, "app abre: " + id)
			ui.close_window()
	for tab in ["overview", "finance", "licenses", "bets", "staff", "equipment", "properties", "promotions", "risk", "reputation", "customers", "competition"]:
		ui.open_app("admin:" + tab)
		await _frames(1)
	ui.close_window()
	# Anda até a banca do Zé e interage
	world.player.teleport(world.city.point("ze") + Vector3(0, 0.3, 1.0))
	await _frames(20)
	var t = world.player.current_target()
	_ok(t != null, "interação encontrada perto do Zé: " + (t.get_prompt() if t else "nenhuma"))
	if t:
		t.interact()
		await _frames(2)
		_ok(ui.window.visible, "app de apostas aberto pelo balcão")
		var app = ui.current_app
		var ev: Dictionary = game.sim.betting.open_events()[0]
		app.sel_event = ev.id
		app.sel_outcome = 0
		app.stake = 20
		ui.refresh()
		await _frames(2)
		_ok(game.sim.betting.place_player_bet(ev.id, 0, 20), "aposta pelo app")
		ui.close_window()
	# Trabalho de entrega: aceita e completa caminhando até o marcador
	game.sim.time.minute = 600
	_ok(game.sim.jobs.start("carregar"), "trabalho de carga aceito")
	await _frames(3)
	for i in 4:
		var stop: String = game.sim.jobs.current_stop()
		world.player.teleport(world.city.point(stop) + Vector3(0, 0.5, 0))
		await _frames(15)
	_ok(not game.sim.jobs.is_busy(), "carga concluída caminhando até os marcadores")
	# Turno (tempo acelerado)
	_ok(game.sim.jobs.start("limpeza"), "turno iniciado")
	var guard := 0
	while game.sim.jobs.is_busy() and guard < 2000:
		await get_tree().process_frame
		guard += 1
	_ok(not game.sim.jobs.is_busy(), "turno terminou com o tempo acelerado (%d frames)" % guard)
	# Dorme: encerra o dia e mostra relatório
	var day: int = game.sim.time.day
	game.start_sleep()
	guard = 0
	while game.sim.time.day == day and guard < 3000:
		await get_tree().process_frame
		guard += 1
	_ok(game.sim.time.day == day + 1, "dormir avança para o próximo dia")
	await _frames(3)
	_ok(ui._modal_open != null, "relatório diário exibido")
	# Salvar / carregar
	_ok(game.save_game("smoke"), "salvar")
	var cash: float = game.sim.economy.cash
	game.sim.economy.cash = 1.0
	_ok(game.load_game("smoke"), "carregar")
	_ok(is_equal_approx(game.sim.economy.cash, cash), "caixa restaurado após carregar")
	SaveSystem.delete_save("smoke")
	ui._open_pause()
	await _frames(2)
	_ok(get_tree().paused, "pausa")
	ui._close_pause()
	ui._to_main_menu()
	await _frames(3)
	_ok(not game.playing and ui.main_menu.visible, "voltou ao menu principal")
	print("SMOKE: %s (%d falhas)" % ["OK" if errors == 0 else "FALHOU", errors])
	get_tree().quit(1 if errors > 0 else 0)
