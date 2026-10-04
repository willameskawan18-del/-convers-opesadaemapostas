extends Node
## Teste de rede real (ENet) com dois processos:
##   godot --headless --path . res://tests/net_test.tscn -- host
##   godot --headless --path . res://tests/net_test.tscn -- client

const PORT := 7791
var role := "host"
var ended := false
var fails := 0


func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("[%s] FALHOU: %s" % [role, msg])


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "host"
	Engine.time_scale = 6.0
	Game.match_ended.connect(func(_s): ended = true)
	Game.phase_changed.connect(_auto)
	Game.private_info_received.connect(func(_p, _i): _auto(str(Game.view.phase), Game.view.phase_info))
	if role == "host":
		Game.new_local_session()
		check(Net.host(PORT) == OK, "abrir sala")
		Game.request_add_player("HOST", "rico", false)
		Game.request_add_player("", "", true)
		Game.request_set_config("rounds", 6)
		await _until(func(): return Game.view.players.size() >= 3, 60.0)
		check(Game.view.players.size() == 3, "cliente entrou no lobby")
		Game.request_start()
	else:
		Net.connected_to_host.connect(func(): Game.request_add_player("CLIENTE", "maluco", false))
		check(Net.join("127.0.0.1", PORT) == OK, "conectar")
	await _until(func(): return ended, 2000.0)
	check(ended, "partida terminou")
	var s := Game.last_summary
	var total := 0
	for r in s.get("ranking", []):
		total += int(r.money)
	var names: Array = s.get("ranking", []).map(func(r): return "%s=%d" % [r.name, int(r.money)])
	# o espelho (view) precisa bater com o resumo final
	var mirror := 0
	for p in Game.view.players:
		mirror += int(p.money)
	check(mirror == total, "espelho igual ao resumo (%d vs %d)" % [mirror, total])
	print("[%s] RESULTADO %s" % [role, ",".join(names)])
	print("[%s] NET: %s (%d falhas)" % [role, "OK" if fails == 0 else "FALHOU", fails])
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(1 if fails else 0)


func _auto(phase: String, info: Dictionary) -> void:
	if phase != "decision" and phase != "allwin_decision":
		return
	await get_tree().create_timer(0.4).timeout
	if str(info.get("input", "")) == "reaction":
		await get_tree().create_timer(float(info.public.delay) + 0.2).timeout
	if str(Game.view.phase) == phase:
		AutoPlayer.play_all(Game.view.phase_info)


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
