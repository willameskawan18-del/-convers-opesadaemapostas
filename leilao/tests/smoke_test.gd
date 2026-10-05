extends Node
## Fluxo com interface: menu → PLAY (você + 3 bots) → partida inteira (humano dando lances,
## comprando melhorias e vendendo) → resultado → revanche → menu.

var fails := 0
var main: Node
var ended := 0


func check(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FALHOU: ", m)


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	Game.match_ended.connect(func(_s): ended += 1)
	Game.phase_changed.connect(_auto)
	Game.auction_changed.connect(_auto_bid)
	await get_tree().create_timer(1.0).timeout
	check(main.ui._current == "menu", "menu")
	Engine.time_scale = 20.0
	Game.request_set_config("days", 2)
	main.ui.quick_play()
	Game.config.days = 2
	await _until(func(): return ended >= 1, 4000.0)
	check(ended == 1, "partida terminou")
	await get_tree().create_timer(2.0).timeout
	check(main.ui.results.get_child_count() > 0, "tela de resultado")
	var me: Dictionary = Game.local_players()[0]
	print("Você terminou com ", Fmt.money(int(me.money)))
	Game.request_rematch()
	await _until(func(): return ended >= 2, 4000.0)
	check(ended == 2, "revanche")
	main.ui.back_to_menu()
	await get_tree().create_timer(1.0).timeout
	check(main.ui._current == "menu", "voltou ao menu")
	Engine.time_scale = 1.0
	check(peek_ok, "lanterna da espiada com todos os itens")
	check(int(Profile.data.units) > 0 and Profile.data.achievements.has("primeiro_galpao"), "carreira registrou galpão")
	check(Profile.data.catalog.size() > 0, "catálogo de itens")
	CareerUi.open_career(main.ui.modal_root)
	check(main.ui.modal_root.get_child_count() > 0, "tela de carreira abre")
	print("LEILAO SMOKE: %s (%d falhas)" % ["OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


var peek_ok := false


func _auto(phase: String, _info: Dictionary) -> void:
	await get_tree().create_timer(0.5).timeout
	for p in Game.local_players():
		var pid := int(p.id)
		match phase:
			"shop": Game.submit_action(pid, {"buy": ["lanterna"]})
			"peek":
				var insp := get_tree().root.find_child("Inspector", true, false) as PeekInspector
				peek_ok = peek_ok or (insp != null and insp.items.size() == int(Game.view.phase_info.get("count", -1)))
				if insp:
					insp._reveal(insp.items.size() - 1)
				Game.submit_action(pid, {"ready": true})
			"sell":
				var priv: Dictionary = Game.private_infos.get(pid, {})
				var ch := {}
				for it in priv.get("items", []):
					ch[str(it.uid)] = ["loja", "online", "guardar", "pech:%d" % int(it.est_lo)][randi() % 4] if not it.mystery else "abrir"
				Game.submit_action(pid, {"choices": ch})


func _auto_bid(a: Dictionary) -> void:
	if float(a.get("ends_in", 0.0)) <= 0.0:
		return
	for p in Game.local_players():
		if int(a.get("leader", -1)) != int(p.id) and int(a.get("next_min", 100)) < 2200 and randf() < 0.5:
			Game.bid(int(p.id), int(a.next_min))


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
