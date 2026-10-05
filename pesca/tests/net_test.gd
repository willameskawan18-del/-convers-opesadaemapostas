extends Node
## Coop real: godot --headless --path . res://tests/net_test.tscn -- host (e -- client)

const PORT := 7798
var role := "host"
var fails := 0
var states := 0
var poses := 0
var catches := 0


func check(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("[%s] FALHOU: %s" % [role, m])


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "host"
	Game.world_state.connect(func(_s): states += 1)
	Game.pose_received.connect(func(_p, _d): poses += 1)
	Game.catch_announced.connect(func(_p, _f): catches += 1)
	if role == "host":
		Game.new_local_session()
		check(Net.host(PORT) == OK, "abrir sala")
		Game.request("add_player", ["CAPITAO", "rico"])
		await _until(func(): return Game.view.players.size() >= 2, 30.0)
		check(Game.view.players.size() == 2, "marujo entrou")
		Game.request("start")
		Game.request("drive", [true])
		for i in 60:
			Game.send_boat_input(1.0, 0.2)
			Game.send_pose({"p": Vector3(0, 0.6, 0.5), "y": 0.0, "f": "idle", "d": true})
			await get_tree().create_timer(0.05).timeout
		await _until(func(): return catches >= 1, 20.0)
		check(catches >= 1, "recebeu a captura do marujo")
		check(Game.model.cooler.size() >= 1, "peixe do marujo na caixa")
		check(poses > 5, "recebeu poses do marujo (%d)" % poses)
		check(Game.model.distance() > 20.0, "barco andou")
		await get_tree().create_timer(2.0).timeout
	else:
		Net.connected_to_host.connect(func(): Game.request("add_player", ["MARUJO", "maluco"]))
		check(Net.join("127.0.0.1", PORT) == OK, "conectar")
		await _until(func(): return Game.in_run(), 30.0)
		check(Game.in_run(), "expedição começou no cliente")
		await _until(func(): return states > 20, 20.0)
		check(states > 20, "recebe o estado do barco (%d)" % states)
		check(not Game.run_view.is_empty(), "recebe dados da expedição")
		for i in 20:
			Game.send_pose({"p": Vector3(0.5, 0.6, -0.5), "y": 1.0, "f": "reeling", "d": false})
			await get_tree().create_timer(0.07).timeout
		Game.request("catch", [FishDB.roll("raso", 0, false, Game.rng)])
		await _until(func(): return int(Game.run_view.get("cooler_count", 0)) >= 1, 10.0)
		check(int(Game.run_view.get("cooler_count", 0)) >= 1, "caixa atualizada no cliente")
		var s := Game.world_state_cache()
		check(not s.is_empty() and Vector2(s.pos.x, s.pos.z).length() > 18.0, "cliente vê o barco andando")
		await get_tree().create_timer(3.0).timeout
	print("[%s] NET: %s (%d falhas)" % [role, "OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while not cond.call() and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
