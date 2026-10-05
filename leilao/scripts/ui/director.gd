class_name Director
extends Node
## Diretor: traduz fases e eventos em câmera, porta, itens, animações e sons no pátio 3D.

var yard: Yard
var _last_leader := -1
var _last_call := ""


func _ready() -> void:
	Game.phase_changed.connect(_on_phase)
	Game.step.connect(_on_step)
	Game.auction_changed.connect(_on_auction)
	Game.view_changed.connect(_on_view)
	Game.money_changed.connect(func(_pid, o, n, _r):
		yard.sync_bidders(Game.view.get("players", []))
		Audio.play("money_gain" if n > o else "money_loss", -8.0))


func _on_view() -> void:
	if str(Game.view.get("mode", "")) != "menu":
		yard.sync_bidders(Game.view.get("players", []))


func show_menu() -> void:
	var demo := []
	var i := 0
	for c in GameData.characters().slice(0, 5):
		demo.append({"id": -10 - i, "name": str(c.name).to_upper(), "character": c.id, "money": 5000})
		i += 1
	yard.sync_bidders(demo)
	yard.load_unit(104)
	yard.set_door(0.0)
	yard.shot("menu", 1.0)
	Audio.play_music("music_menu")


func show_lobby() -> void:
	yard.sync_bidders(Game.view.get("players", []))
	yard.shot("bidders", 1.2)
	Audio.play_music("music_menu")


func _on_phase(phase: String, info: Dictionary) -> void:
	match phase:
		"intro":
			Audio.play_music("music_game")
			yard.shot("wide", 1.0)
			yard.all_anim("wave")
			Audio.play("crowd_cheer", -6.0)
		"shop", "sell", "sell_results", "day_end", "collections":
			yard.set_door(0.0)
			yard.shot("wide", 1.2)
		"peek":
			yard.load_unit(int(info.get("unit", 100)))
			var vis: Array = info.get("visible_public", [])
			yard.fill(vis, int(info.get("count", 6)), vis.size())
			yard.set_door(0.38)
			yard.peek_lights()
			yard.shot("door", 1.4)
			Audio.play("door")
		"auction":
			_last_leader = -1
			_last_call = ""
			yard.shot("bidders", 1.0)
			Audio.play("countdown_go")
		"open":
			yard.set_door(1.0)
			yard.open_lights()
			yard.shot("inside", 1.6)
			Audio.play("door")
			Audio.play("drumroll", -4.0)
		"final":
			var rk: Array = info.get("ranking", [])
			if rk.size() > 0:
				yard.bidder_anim(int(rk[0].id), "celebrate")
				yard.shot("bidder", 1.5, yard.bidder_pos(int(rk[0].id)))
			Audio.play("jackpot")
			Audio.play("crowd_cheer")


func _on_auction(a: Dictionary) -> void:
	var leader := int(a.get("leader", -1))
	if leader >= 0 and leader != _last_leader:
		_last_leader = leader
		yard.bidder_anim(leader, "wave")
		Audio.play("coin", -2.0)
	var call := str(a.get("call", ""))
	if call != _last_call:
		_last_call = call
		match call:
			"DOU-LHE UMA...":
				Audio.play("tick", 0.0, 0.9)
			"DOU-LHE DUAS...":
				Audio.play("tick", 0.0, 1.2)
			"VENDIDO!":
				Audio.play("reveal")
				if leader >= 0:
					yard.bidder_anim(leader, "celebrate")
					yard.shot("bidder", 0.8, yard.bidder_pos(leader))
			"SEM LANCES!":
				Audio.play("crowd_aww")


func _on_step(s: Dictionary) -> void:
	match str(s.kind):
		"item":
			yard.reveal_item(int(s.get("index", 0)), s.item, bool(s.big))
			if s.big:
				yard.all_anim("shock")
		"summary":
			var good := (int(s.est_lo) + int(s.est_hi)) / 2 > int(s.paid)
			if int(s.get("pid", -1)) >= 0:
				yard.bidder_anim(int(s.pid), "celebrate" if good else "sad")
				yard.shot("bidder", 1.0, yard.bidder_pos(int(s.pid)))
			Audio.play("win" if good else "lose")
		"sales":
			yard.bidder_anim(int(s.pid), "celebrate")
		"collection":
			yard.bidder_anim(int(s.pid), "celebrate")
			Audio.play("jackpot", -4.0)
