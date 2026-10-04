class_name ShowDirector
extends Node
## "Diretor do programa": traduz fases e revelações em câmera, luzes, telão,
## animações dos personagens, portas, confete e sons. Funciona igual em todas as máquinas.

var arena: Arena
var _last_phase := ""


func _ready() -> void:
	Game.phase_changed.connect(_on_phase)
	Game.reveal_step.connect(_on_step)
	Game.money_changed.connect(_on_money)
	Game.view_changed.connect(_on_view)
	Game.submissions_changed.connect(_on_submitted)


func _on_view() -> void:
	var mode := str(Game.view.get("mode", "menu"))
	if mode == "menu":
		return
	var players: Array = Game.view.get("players", [])
	if mode == "lobby":
		var shown := players.map(func(p):
			var q: Dictionary = p.duplicate()
			q.money = Game.START_MONEY
			return q)
		arena.sync_players(shown)
		arena.clear_places()
	else:
		arena.sync_players(players)


func show_menu() -> void:
	var demo := []
	var i := 0
	for c in GameData.characters():
		demo.append({"id": -100 - i, "name": str(c.name).to_upper(), "character": c.id, "money": 1000 * (8 - i)})
		i += 1
	arena.sync_players(demo)
	arena.clear_places()
	arena.set_all_tags("")
	arena.show_doors(false)
	arena.set_mood("menu")
	arena.screen("AO VIVO", "HOJE: QUEM VAI LEVAR TUDO?", AW.PINK)
	arena.camera.shot("menu", 2.0)
	Audio.stop_suspense()
	Audio.play_music("music_menu")


func show_lobby() -> void:
	arena.show_doors(false)
	arena.set_all_tags("")
	arena.set_mood("normal")
	arena.screen("LOBBY", "Entrem, competidores!")
	arena.camera.shot("players", 1.5)
	Audio.play_music("music_menu")
	_on_view()


func _on_phase(phase: String, info: Dictionary) -> void:
	_last_phase = phase
	var cam := arena.camera
	if phase != "reveal" and phase != "allwin_reveal":
		arena.highlight_only(-999)
	match phase:
		"intro":
			Audio.play_music("music_game")
			arena.set_mood("normal")
			arena.set_all_tags("")
			arena.show_doors(false)
			arena.screen("ALL WIN", "BEM-VINDOS, COMPETIDORES!")
			cam.shot("wide", 0.8)
			arena.celebrate(false)
			arena.animate_all("wave")
			Audio.play("crowd_cheer")
			get_tree().create_timer(2.2).timeout.connect(func(): if _last_phase == "intro": cam.shot("players", 1.5))
		"round_intro":
			arena.set_mood("normal")
			arena.set_all_tags("")
			arena.show_doors(str(info.get("id", "")) == "portas")
			arena.screen(str(info.get("title", "")), str(info.get("tagline", "")), Color(str(info.get("color", "#ff2e88"))))
			cam.shot("screen", 1.0)
			Audio.play("whoosh")
			arena.refresh_places(Game.view.players)
		"event_intro":
			arena.set_mood("win")
			arena.screen(str(info.get("public", {}).get("title", "EVENTO")), str(info.get("public", {}).get("text", "")), AW.GOLD)
			cam.shot("screen", 0.8)
			arena.flash()
			Audio.play("whoosh")
		"decision":
			arena.set_mood("allwin" if info.get("high_stakes", false) else "normal")
			arena.set_all_tags("")
			for pid in info.get("deciders", []):
				var pod := arena.podium(int(pid))
				if pod:
					pod.set_tag("?", AW.MUTED)
					pod.model.play("think")
			cam.shot("doors" if str(info.get("id", "")) == "portas" else "players", 1.2)
			if str(info.get("id", "")) == "reacao":
				arena.screen("ESPERE...", "Aperte quando ficar VERDE!", AW.RED)
				get_tree().create_timer(float(info.get("public", {}).get("delay", 3.0))).timeout.connect(func():
					if _last_phase == "decision":
						arena.screen("AGORA!", "", AW.GREEN))
			else:
				var st := str(info.get("stage_title", ""))
				arena.screen(str(info.get("title", "")), st if st != "" else "Façam suas escolhas!", Color(str(info.get("color", "#ff2e88"))))
		"reveal":
			arena.set_all_tags("")
			Audio.play("drumroll", -4.0)
		"round_results":
			arena.set_all_tags("")
			arena.refresh_places(Game.view.players)
			cam.shot("wide", 1.2)
			for pid in info.get("winners", []):
				arena.animate(int(pid), "celebrate")
				var pod := arena.podium(int(pid))
				if pod:
					pod.highlight(true, AW.GOLD)
			arena.screen("PLACAR", _leader_text())
		"missions":
			arena.set_mood("win")
			arena.screen("MISSÕES", "SECRETAS", AW.GOLD)
			cam.shot("wide", 1.0)
			Audio.play("drumroll")
		"allwin_intro":
			arena.set_mood("allwin")
			arena.set_all_tags("")
			arena.show_doors(false)
			arena.screen("ALL WIN", "A ÚLTIMA DECISÃO", AW.RED)
			cam.shot("allwin", 2.5)
			Audio.play_music("music_allwin")
			Audio.start_suspense()
			Audio.play("suspense")
		"allwin_decision":
			arena.set_all_tags("?", AW.GOLD)
			arena.animate_all("think")
			cam.shot("players", 1.5)
			arena.screen("SAFE  ou  ALL WIN?", "Decidam em segredo...", AW.RED)
		"allwin_reveal":
			arena.set_all_tags("")
			arena.screen("TUDO OU NADA", "", AW.RED)
		"final":
			Audio.stop_suspense()
			arena.set_mood("win")
			arena.refresh_places(Game.view.players)
			var rk: Array = info.get("ranking", [])
			if rk.size() > 0:
				arena.screen("ALL WINNER", "%s  %s" % [rk[0].name, Fmt.money(int(rk[0].money))], AW.GOLD)
				var pod := arena.podium(int(rk[0].id))
				if pod:
					pod.highlight(true, AW.GOLD)
					cam.shot("winner", 1.5, pod.global_position)
				arena.animate(int(rk[0].id), "celebrate")
				for i in range(1, rk.size()):
					arena.animate(int(rk[i].id), "sad" if i == rk.size() - 1 else "wave")
			arena.celebrate(true)
			Audio.play("jackpot")
			Audio.play("crowd_cheer")
			Audio.play_music("music_menu")


func _leader_text() -> String:
	var r := Game.ranking_view()
	return ("Líder: %s com %s" % [r[0].name, Fmt.money(int(r[0].money))]) if r.size() > 0 else ""


func _on_submitted(submitted: Array) -> void:
	for pid in submitted:
		var pod := arena.podium(int(pid))
		if pod:
			pod.set_tag("OK!", AW.GREEN)


func _on_step(s: Dictionary) -> void:
	var cam := arena.camera
	var fx := str(s.get("fx", ""))
	var pid := int(s.get("pid", -1))
	match str(s.camera):
		"player":
			var pod := arena.podium(pid)
			if pod:
				cam.shot("player", 0.8, pod.global_position)
				arena.highlight_only(pid, AW.GOLD if fx != "lose" else AW.RED)
		"wide", "stage", "doors", "players", "screen":
			cam.shot(str(s.camera), 0.9)
	match str(s.kind):
		"door_picks":
			var picks: Dictionary = s.picks
			for i in 3:
				var names := []
				for k in picks:
					if int(picks[k]) == i:
						names.append(str(Game.player_view(int(k)).get("name", "")))
						var pod := arena.podium(int(k))
						if pod:
							pod.set_tag(["A", "B", "C"][i], arena.doors[i].color)
				arena.set_door_picks(i, "\n".join(names))
		"door_open":
			arena.open_door(int(s.door), float(s.door_mult))
			Audio.play("door")
		"choices", "allwin_choices":
			var ch: Dictionary = s.choices
			for k in ch:
				var pod := arena.podium(int(k))
				if pod:
					var t := str(ch[k])
					pod.set_tag(t, AW.GREEN if t == "SAFE" else (AW.GOLD if t == "ALL WIN" else AW.PINK))
		"allwin_spin":
			cam.shot("allwin", 1.0)
			Audio.play("drumroll", 0.0)
			arena.flash()
		"allwin_result":
			Audio.stop_suspense()
			cam.shot("players", 0.6)
			var res: Dictionary = s.results
			for k in res:
				arena.animate(int(k), "celebrate" if str(res[k]) != "lose" else "sad")
				var pod := arena.podium(int(k))
				if pod:
					pod.set_tag({"jackpot": "JACKPOT!", "double": "x2!", "lose": "PERDEU"}.get(str(res[k]), ""), {"jackpot": AW.GOLD, "double": AW.GREEN, "lose": AW.RED}.get(str(res[k]), Color.WHITE))
		"event_intro":
			arena.flash()
		"race":
			arena.screen("CORRIDA!", "", AW.GREEN)
	for sp in s.get("shielded", []):
		var pod := arena.podium(int(sp))
		if pod:
			pod.set_tag("SAFE CARD!", AW.CYAN)
			pod.model.play("celebrate")
	if not s.get("shielded", []).is_empty():
		Audio.play("reveal")
	# som e efeitos
	match fx:
		"win":
			Audio.play("win")
			arena.celebrate(false)
		"jackpot":
			Audio.play("jackpot")
			Audio.play("crowd_cheer", -4.0)
			arena.celebrate(true)
			arena.flash()
		"lose":
			Audio.play("lose")
			Audio.play("crowd_aww", -6.0)
			arena.boo()
			cam.shake(0.15)
		"drumroll":
			Audio.play("drumroll")
		"suspense":
			Audio.play("suspense")
		"reveal":
			Audio.play("reveal")
	if pid >= 0 and str(s.kind) == "player_result":
		arena.animate(pid, "sad" if fx == "lose" else "celebrate")


func _on_money(pid: int, old_v: int, new_v: int, _r: String) -> void:
	var pod := arena.podium(pid)
	if pod:
		pod.set_money(new_v)
	if new_v > old_v:
		Audio.play("money_gain", -4.0)
		if str(Game.view.get("phase", "")) in ["reveal", "allwin_reveal"]:
			arena.animate(pid, "celebrate")
	elif new_v < old_v:
		Audio.play("money_loss", -4.0)
		if str(Game.view.get("phase", "")) in ["reveal", "allwin_reveal"]:
			arena.animate(pid, "shock")
