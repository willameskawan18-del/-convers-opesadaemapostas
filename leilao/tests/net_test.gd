extends Node
## Rede real: godot --headless --path . res://tests/net_test.tscn -- host   (e -- client)

const PORT := 7792
var role := "host"
var ended := false
var fails := 0


func check(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("[%s] FALHOU: %s" % [role, m])


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "host"
	Engine.time_scale = 6.0
	Game.match_ended.connect(func(_s): ended = true)
	Game.phase_changed.connect(_auto)
	Game.auction_changed.connect(_bid)
	if role == "host":
		Game.new_local_session()
		Game.config.days = 1
		check(Net.host(PORT) == OK, "abrir sala")
		Game.request_add_player("HOST", "rico", false)
		Game.request_add_player("", "", true)
		await _until(func(): return Game.view.players.size() >= 3, 60.0)
		check(Game.view.players.size() == 3, "cliente entrou")
		Game.request_start()
	else:
		Net.connected_to_host.connect(func(): Game.request_add_player("CLIENTE", "maluco", false))
		check(Net.join("127.0.0.1", PORT) == OK, "conectar")
	await _until(func(): return ended, 3000.0)
	check(ended, "partida terminou")
	var names: Array = Game.last_summary.get("ranking", []).map(func(r): return "%s=%d" % [r.name, int(r.money)])
	var mirror := 0
	for p in Game.view.players:
		mirror += int(p.money)
	var total := 0
	for r in Game.last_summary.get("ranking", []):
		total += int(r.money)
	check(mirror == total, "espelho igual ao resumo")
	print("[%s] RESULTADO %s" % [role, ",".join(names)])
	print("[%s] NET: %s (%d falhas)" % [role, "OK" if fails == 0 else "FALHOU", fails])
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(1 if fails else 0)


func _auto(phase: String, _i: Dictionary) -> void:
	await get_tree().create_timer(0.6).timeout
	for p in Game.local_players():
		var pid := int(p.id)
		match phase:
			"peek": Game.submit_action(pid, {"ready": true})
			"sell":
				var ch := {}
				for it in Game.private_infos.get(pid, {}).get("items", []):
					ch[str(it.uid)] = "loja"
				Game.submit_action(pid, {"choices": ch})


func _bid(a: Dictionary) -> void:
	if float(a.get("ends_in", 0.0)) <= 0.0:
		return
	for p in Game.local_players():
		if int(a.get("leader", -1)) != int(p.id) and int(a.get("next_min", 100)) < 1500 and randf() < 0.6:
			Game.bid(int(p.id), int(a.next_min))


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
