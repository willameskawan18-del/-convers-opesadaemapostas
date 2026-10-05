extends Node
## Testa a expedição (host, sem interface): pilotar, zonas, perigos, captura, venda,
## conserto, tentáculo, fim de noite, cota e fim de jogo.
## godot --headless --path . res://tests/run_test.tscn

var fails := 0
var fx_seen := {}
var nights := 0
var over := false


func check(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FALHOU: ", m)


func _ready() -> void:
	Game.fx.connect(func(k, _d): fx_seen[k] = true)
	Game.night_ended.connect(func(_s): nights += 1)
	Game.game_over.connect(func(_s): over = true)
	Game.new_local_session()
	Game.request("add_player", ["TESTE", "sortudo"])
	Game.request("start")
	check(Game.in_run(), "expedição começou")
	var m: RunModel = Game.model
	check(m.quota == 700 and m.night == 1, "cota inicial 700")
	# pilotar
	Game.request("drive", [true])
	check(m.driver == Game.my_pid(), "assumiu o timão")
	Engine.time_scale = 10.0
	for i in 800:
		Game.send_boat_input(1.0, 0.0)
		await get_tree().create_timer(0.05).timeout
		if m.distance() > 380.0:
			break
	check(m.distance() > 330.0, "barco chegou longe (%.0f m)" % m.distance())
	check(str(m.zone().id) == "abismo", "chegou no abismo")
	check(not Game.world_state_cache().is_empty(), "estado do mundo enviado")
	# parar e esperar perigos
	Game.send_boat_input(0.0, 0.0)
	m.dread = 90.0
	var t := 0.0
	while t < 60.0 and not (fx_seen.has("thump") or fx_seen.has("tentacle_rise") or fx_seen.has("eyes")):
		await get_tree().process_frame
		t += get_process_delta_time()
		if m.dread < 60.0:
			m.dread = 90.0
	check(fx_seen.has("thump") or fx_seen.has("tentacle_rise") or fx_seen.has("eyes"), "aconteceu um perigo no abismo")
	# tentáculo: bater até recuar
	m.tentacle = {"side": 1.0, "hp": 3, "t": 50.0}
	for i in 3:
		Game.request("hit")
	check(m.tentacle.is_empty(), "tentáculo recuou com 3 golpes")
	# vazamento: consertar
	m.add_leak(Game.rng)
	var lid := int(m.leaks[0].id)
	Game.request("repair", [lid, 1.2])
	check(m.leaks.filter(func(l): return int(l.id) == lid).is_empty(), "vazamento consertado")
	# capturas
	var f := FishDB.roll("abismo", 0, false, Game.rng)
	Game.request("catch", [f])
	check(m.cooler.size() == 1, "peixe na caixa")
	var cheat := f.duplicate()
	cheat.value = 999999
	Game.request("catch", [cheat])
	check(m.cooler.size() == 1, "captura impossível recusada")
	# vender só no porto
	Game.request("sell")
	check(m.cooler.size() == 1, "não vende longe do porto")
	m.pos = Vector3(0, 0, 10)
	m.speed = 0.0
	Game.request("sell")
	check(m.cooler.is_empty() and m.money == int(f.value) and m.sold_cycle == int(f.value), "vendeu no porto")
	# comprar melhoria
	m.money += 500
	var before := m.money
	Game.request("buy", ["vara"])
	check(int(m.upgrades.vara) == 1 and m.money == before - 150, "comprou vara")
	# naufrágio
	m.pos = Vector3(0, 0, 200)
	Game.request("catch", [FishDB.roll("fundo", 0, false, Game.rng)])
	m.hull = 0.5
	m.add_leak(Game.rng)
	await get_tree().create_timer(1.0).timeout
	check(fx_seen.has("sink") and m.cooler.is_empty() and m.distance() < 30.0, "naufrágio: perdeu a pesca e voltou ao porto")
	# fim das noites e cota não batida (zera as vendas para garantir)
	m.sold_cycle = 0
	for n in 3:
		m.minute = RunModel.NIGHT_MINUTES - 1.0
		await get_tree().create_timer(2.0).timeout
		if over:
			break
		await get_tree().create_timer(7.0).timeout
	check(nights >= 2, "noites terminaram (%d)" % nights)
	check(over, "fim de jogo por não bater a cota")
	Engine.time_scale = 1.0
	Game.leave_to_menu()
	check(not Game.in_run(), "voltou ao menu")
	print("PESCA RUN: %s (%d falhas)" % ["OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)
