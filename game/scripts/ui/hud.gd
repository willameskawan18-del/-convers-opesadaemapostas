class_name Hud
extends Control
## HUD da partida: rodada, desafio atual, cronômetro e cartões de todos os jogadores.
## Cada mudança de dinheiro gera um número flutuante (+$2.000 verde / -$1.000 vermelho).

var round_lbl: Label
var challenge_lbl: Label
var timer: TimerRing
var jackpot_lbl: Label
var mission_lbl: Label
var cards_box: HBoxContainer
var cards: Dictionary = {}   # pid -> PlayerCard
var float_layer: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AW.full_rect(self)
	var top := AW.hbox(10)
	top.position = Vector2(20, 16)
	add_child(top)
	var logo := AW.label("ALL WIN", 26, AW.GOLD, "ExtraBold", 5)
	logo.add_theme_color_override("font_outline_color", Color("3a0a3f"))
	top.add_child(logo)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", AW.style(Color(AW.PINK, 0.9), 12, Color(0, 0, 0, 0), 0, 12))
	round_lbl = AW.label("", 18, Color.WHITE, "ExtraBold")
	chip.add_child(round_lbl)
	top.add_child(chip)
	challenge_lbl = AW.label("", 18, AW.TEXT, "Bold", 4)
	top.add_child(challenge_lbl)
	var jp := PanelContainer.new()
	jp.add_theme_stylebox_override("panel", AW.glow_style(Color(AW.BG, 0.85), AW.GOLD, 12, 2, 10))
	jackpot_lbl = AW.label("", 18, AW.GOLD, "ExtraBold", 3)
	jp.add_child(jackpot_lbl)
	jp.set_anchors_preset(Control.PRESET_CENTER_TOP)
	jp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	jp.position.y = 14
	jp.name = "Jackpot"
	add_child(jp)
	mission_lbl = AW.label("", 14, AW.GOLD, "Bold", 3)
	mission_lbl.position = Vector2(22, 58)
	mission_lbl.custom_minimum_size.x = 420
	mission_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(mission_lbl)
	Game.mission_received.connect(func(_pid, _t): _update_mission())
	timer = TimerRing.new()
	timer.custom_minimum_size = Vector2(96, 96)
	timer.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	timer.position = Vector2(-120, 14)
	timer.visible = false
	add_child(timer)
	cards_box = AW.hbox(8)
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cards_box.offset_top = -146
	cards_box.offset_bottom = -8
	cards_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cards_box)
	float_layer = Control.new()
	float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	AW.full_rect(float_layer)
	add_child(float_layer)
	Game.money_changed.connect(_on_money)
	Game.view_changed.connect(rebuild)
	Game.submissions_changed.connect(_on_submitted)
	Game.phase_changed.connect(_on_phase)
	rebuild()


func rebuild() -> void:
	var players: Array = Game.view.get("players", [])
	var ids := players.map(func(p): return int(p.id))
	var same := ids.size() == cards.size()
	for id in ids:
		if not cards.has(id):
			same = false
	_update_jackpot()
	if same:
		for p in players:
			cards[int(p.id)].set_money(int(p.money))
			cards[int(p.id)].set_badges(p)
		_refresh_places()
		return
	AW.clear(cards_box)
	cards.clear()
	var my := Game.my_peer()
	for p in players:
		var c := PlayerCard.new()
		c.setup(p, int(p.owner_peer) == my and not bool(p.is_bot))
		cards_box.add_child(c)
		cards[int(p.id)] = c
	_refresh_places()


func _update_jackpot() -> void:
	var jp := int(Game.view.get("jackpot", 0))
	jackpot_lbl.text = "JACKPOT  " + Fmt.money(jp)
	var old: int = int(jackpot_lbl.get_meta("v", 0))
	if jp != int(old):
		jackpot_lbl.set_meta("v", jp)
		AW.pop(jackpot_lbl, 1.5)


## Missão secreta visível só quando há um único humano nesta máquina (senão aparece na cortina).
func _update_mission() -> void:
	var local := Game.local_players()
	if local.size() == 1 and Game.missions.has(int(local[0].id)):
		mission_lbl.text = "MISSÃO SECRETA: " + str(Game.missions[int(local[0].id)])
	else:
		mission_lbl.text = ""


func _refresh_places() -> void:
	for pid in cards:
		cards[pid].set_place(Game.position_in_view(pid))


func _on_phase(phase: String, info: Dictionary) -> void:
	var r := int(Game.view.get("round", 0))
	var tot := int(Game.view.get("total_rounds", 0))
	if phase.begins_with("allwin") or phase == "final":
		round_lbl.text = "RODADA FINAL"
	elif r > 0:
		round_lbl.text = "RODADA %d/%d" % [r, tot]
		if str(info.get("category_name", "")) != "" and phase == "round_intro":
			challenge_lbl.text = "%s  ·  %s" % [info.category_name, info.title]
	else:
		round_lbl.text = "COMEÇANDO"
	if info.has("title") and phase != "round_results" and phase != "intro" and phase != "round_intro":
		challenge_lbl.text = (str(info.get("category_name", "")) + "  ·  " if str(info.get("category_name", "")) != "" else "") + str(info.title)
	timer.visible = phase == "decision" or phase == "allwin_decision"
	if phase == "intro":
		mission_lbl.text = ""
	if phase.begins_with("allwin") or phase == "missions":
		mission_lbl.text = ""
	timer.total = float(info.get("deadline_in", 1.0))
	for c in cards.values():
		c.set_status("")
	if phase == "decision" or phase == "allwin_decision":
		for c in cards.values():
			c.set_status("pensando...", AW.MUTED)


func _on_submitted(submitted: Array) -> void:
	for pid in submitted:
		if cards.has(int(pid)):
			cards[int(pid)].set_status("ESCOLHEU!", AW.GREEN)


func _on_money(pid: int, old_v: int, new_v: int, _reason: String) -> void:
	var c: PlayerCard = cards.get(pid)
	if c == null:
		return
	c.set_money(new_v)
	AW.pop(c, 1.08, 0.3)
	_refresh_places()
	var d := new_v - old_v
	var l := AW.label(Fmt.delta(d), 30, AW.GREEN if d > 0 else AW.RED, "ExtraBold", 6)
	float_layer.add_child(l)
	l.position = c.global_position + Vector2(c.size.x / 2.0 - 50, -30)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 90, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)
	l.scale = Vector2(1.6, 1.6)
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func _process(_delta: float) -> void:
	if timer.visible:
		timer.left = Game.time_left()
		timer.queue_redraw()
