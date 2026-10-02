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
	# Cassino Estrela: entra e joga numa máquina pelo [E]
	var cas: CornerCasino = world.city.get_node("cassino_estrela")
	world.player.teleport(cas.to_global(Vector3(-CornerCasino.W / 2 + 2.3, 0.4, CornerCasino.D / 2 - 5.0)))
	await _frames(15)
	var ct = world.player.current_target()
	_ok(ct != null and ct.get_prompt().begins_with("Jogar"), "máquina do cassino interativa: " + (ct.get_prompt() if ct else "nenhuma"))
	if ct:
		ct.interact()
		await _frames(3)
		_ok(ui.window.visible and ui.current_app.game != "", "jogo aberto direto pela máquina: " + str(ui.current_app.game))
		ui.close_window()
	_ok(not cas.roof.visible, "teto some dentro do cassino")
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
	# --- Fase 2: abrir a banca e atender clientes ---
	for c in ui.modal_layer.get_children():
		c.queue_free()
	ui._modal_closed()
	var sim = game.sim
	sim.auto_decide = true
	sim.economy.earn(9000, EconomySystem.REWARD)
	sim.progression.add_xp(200)
	_ok(sim.licenses.buy("basica"), "alvará comprado")
	_ok(sim.properties.rent("sala_comercio"), "sala alugada")
	_ok(sim.has_business(), "banca criada")
	_ok(sim.business.buy_equipment("balcao_simples"), "balcão comprado")
	_ok(sim.business.buy_equipment("computador"), "computador comprado")
	sim.business.buy_equipment("cadeiras")
	sim.business.buy_equipment("tv")
	await _frames(5)
	_ok(world.establishment != null, "estabelecimento construído no mundo")
	sim.time.minute = 10 * 60
	var ev_view: EstablishmentView = world.establishment
	world.player.teleport(ev_view.to_global(ev_view.staff_pos[0]) + Vector3(0, 0.3, 0))
	await _frames(10)
	_ok(sim.player_at_counter, "jogador atrás do balcão atende")
	var served0: float = sim.stat("customers_served")
	for i in 120:
		sim.advance(2)
		await get_tree().process_frame
	_ok(sim.stat("customers_served") > served0, "clientes atendidos pelo jogador: %d" % int(sim.stat("customers_served") - served0))
	_ok(sim.betting.book_bets.size() > 0, "apostas de clientes registradas no livro (%d)" % sim.betting.book_bets.size())
	var visible_npcs := 0
	for c in world.business_visuals._customers:
		if c.h.visible:
			visible_npcs += 1
	print("  NPCs de clientes visíveis: ", visible_npcs, "  fila: ", sim.customers.queue_length())
	sim.employees.refresh_candidates(true)
	var cand: Dictionary = sim.employees.candidates[0]
	_ok(sim.employees.hire(str(cand.id)), "atendente contratado")
	world.player.teleport(world.city.point("spawn"))
	await _frames(5)
	served0 = sim.stat("customers_served")
	for i in 120:
		# neutraliza eventos aleatórios que parariam a banca durante o teste
		for e in sim.business.equipment:
			e.broken = false
		sim.business.internet_down_until = 0
		sim.business.equipment_revision += 1
		for e in sim.employees.staff:
			e.absent = false
		sim.advance(2)
		await get_tree().process_frame
	if sim.stat("customers_served") <= served0:
		print("  DEBUG staff=", sim.employees.staff.map(func(e): return [e.role, e.state]), " bets=", sim.business.can_take_bets(), " open=", sim.business.is_open(), " eq=", sim.business.equipment.map(func(e): return [e.id, e.broken]), " min=", sim.time.minute, " visits=", sim.customers.visits.size(), " today=", sim.customers.today)
	_ok(sim.stat("customers_served") > served0, "atendente atende sem o jogador: %d" % int(sim.stat("customers_served") - served0))
	for tab in ["bets", "staff", "equipment", "properties", "risk", "reputation", "customers", "overview", "finance"]:
		ui.open_app("admin:" + tab)
		await _frames(1)
	ui.close_window()
	# --- Cassino: abre cada jogo e aperta o botão principal ---
	sim.economy.earn(100000, EconomySystem.REWARD)
	sim.time.minute = 15 * 60
	ui.open_app("cassino", "royal")
	await _frames(2)
	var app = ui.current_app
	var actions := ["GIRAR", "DAR CARTAS", "DISTRIBUIR", "ROLAR", "REVELAR", "APOSTAR E DECOLAR", "COMEÇAR", "SOLTAR", "SORTEAR", "JOGAR", "COMPRAR RASPADINHA", "GIRAR A RODA", "GIRAR A ROLETA"]
	var cash_before: float = sim.economy.cash
	for gid in CasinoLogic.GAMES.keys():
		app.game = gid
		app.st = {}
		app.bet = 10
		if gid == "keno":
			app.st = {"picks": [1, 2, 3]}
		ui.refresh()
		await _frames(2)
		var pressed := false
		for b in ui.window.body.find_children("*", "Button", true, false):
			for a in actions:
				if b.text.begins_with(a) and not b.disabled:
					b.pressed.emit()
					pressed = true
					break
			if pressed:
				break
		var c0: float = sim.economy.cash
		await _frames(150)
		app.on_close()
		if absf(sim.economy.cash - c0) > 200:
			print("  ALERTA ", gid, " delta ", sim.economy.cash - c0)
		_ok(pressed, "jogo jogado: " + gid)
	ui.close_window()
	print("  rodadas de cassino: ", sim.stat("casino_rounds"), "  resultado: ", Fmt.signed_money(sim.economy.cash - cash_before))
	_ok(sim.stat("casino_rounds") >= 18, "rodadas registradas")
	# Decisão com diálogo real
	sim.auto_decide = false
	sim.time.minute = 14 * 60
	sim.events.trigger_by_id("fraude")
	await _frames(3)
	_ok(sim.paused_for_decision and ui._modal_open != null, "diálogo de decisão exibido e tempo pausado")
	var clicked := false
	for b in ui.modal_layer.find_children("*", "Button", true, false):
		if b.text.begins_with("Bloquear"):
			b.pressed.emit()
			clicked = true
			break
	await _frames(3)
	_ok(clicked and not sim.paused_for_decision, "decisão resolvida pelo botão")
	sim.auto_decide = true
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
