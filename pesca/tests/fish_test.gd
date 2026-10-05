extends Node
## Testa o minigame de pesca com um "jogador" automático que segura/solta o clique
## para manter a tensão na faixa verde. Mede quantos peixes consegue pegar.

var caught := 0
var lost := 0


func _ready() -> void:
	Game.new_local_session()
	Game.request("add_player", ["T", "sortudo"])
	Game.request("start")
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 2, 0)
	var f := Fishing.new()
	add_child(f)
	f.setup(cam)
	f.caught.connect(func(_fi): caught += 1)
	f.message.connect(func(t, _c): if "escapou" in t or "ARREBENTOU" in t or "soltou" in t or "fugiu" in t: lost += 1)
	await get_tree().process_frame
	Engine.time_scale = 4.0
	var zones := ["raso", "fundo", "abismo"]
	for attempt in 18:
		Game.model.pos = Vector3(0, 0, [60.0, 220.0, 400.0][attempt % 3])
		Game._send_run()
		f.press()
		await get_tree().create_timer(0.5).timeout
		f.release()
		var t := 0.0
		while f.state != "bite" and t < 30.0:
			await get_tree().process_frame
			t += get_process_delta_time()
		if f.state != "bite":
			continue
		await get_tree().create_timer(0.2).timeout
		f.press()
		var holding := false
		while f.state == "reeling":
			var want := f.tension < (f.zone_lo + f.zone_hi) / 2.0
			if want != holding:
				holding = want
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = holding
				Input.parse_input_event(ev)
			await get_tree().process_frame
		if holding:
			var ev2 := InputEventMouseButton.new()
			ev2.button_index = MOUSE_BUTTON_LEFT
			ev2.pressed = false
			Input.parse_input_event(ev2)
	print("PEIXES PEGOS: %d  ·  perdidos: %d  ·  na caixa: %d (%s)" % [caught, lost, Game.model.cooler.size(), Fmt.money(Game.model.cooler_value())])
	print("FISH TEST: %s" % ("OK" if caught >= 8 else "FALHOU"))
	get_tree().quit(0 if caught >= 8 else 1)
