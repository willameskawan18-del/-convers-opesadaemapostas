class_name Hud
extends Control
## HUD da expedição: noite/relógio, zona, cota, dinheiro, caixa de peixes, casco, mira,
## dica de interação, minigame da pesca, cartão de captura, porto e resumos.

var ui: Node
var player: PlayerController
var top_lbl: Label
var zone_lbl: Label
var money_lbl: Label
var quota_bar: ProgressBar
var quota_lbl: Label
var cooler_lbl: Label
var hull_bar: ProgressBar
var hull_lbl: Label
var prompt_lbl: Label
var sonar_lbl: Label
var cross: Label
var notes: VBoxContainer
var fish_ui: Control
var charge_bar: ProgressBar
var bite_lbl: Label
var reel_box: Control
var reel_draw: Control
var catch_card: PanelContainer
var panel: Control
var _run: Dictionary = {}
var meta: MetaUi


func _ready() -> void:
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("dock_ui")
	# topo esquerdo
	var tl := AW.panel(Color(AW.BG, 0.75), AW.CYAN, 12)
	tl.position = Vector2(16, 14)
	var tv := AW.vbox(0)
	tl.add_child(tv)
	top_lbl = AW.label("", 22, Color.WHITE, "ExtraBold", 3)
	tv.add_child(top_lbl)
	zone_lbl = AW.label("", 15, AW.CYAN, "Bold", 2)
	tv.add_child(zone_lbl)
	sonar_lbl = AW.label("", 13, AW.MUTED, "Bold")
	tv.add_child(sonar_lbl)
	add_child(tl)
	# topo direito
	var tr := AW.panel(Color(AW.BG, 0.75), AW.GOLD, 12)
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.offset_right = -16
	tr.offset_left = -16
	tr.offset_top = 14
	var rv := AW.vbox(2)
	tr.add_child(rv)
	money_lbl = AW.label("", 26, AW.GOLD, "ExtraBold", 3)
	rv.add_child(money_lbl)
	quota_lbl = AW.label("", 13, AW.TEXT, "Bold")
	rv.add_child(quota_lbl)
	quota_bar = ProgressBar.new()
	quota_bar.show_percentage = false
	quota_bar.custom_minimum_size = Vector2(260, 10)
	rv.add_child(quota_bar)
	cooler_lbl = AW.label("", 14, AW.CYAN, "Bold")
	rv.add_child(cooler_lbl)
	add_child(tr)
	# casco
	var hb := AW.vbox(2)
	hb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hb.position = Vector2(18, -64)
	hull_lbl = AW.label("CASCO", 14, AW.TEXT, "Bold", 2)
	hb.add_child(hull_lbl)
	hull_bar = ProgressBar.new()
	hull_bar.show_percentage = false
	hull_bar.custom_minimum_size = Vector2(260, 14)
	hb.add_child(hull_bar)
	add_child(hb)
	hb.name = "Hull"
	# mira e dica
	cross = AW.center(AW.label("+", 26, Color(1, 1, 1, 0.7), "Bold"))
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(cross)
	prompt_lbl = AW.center(AW.label("", 18, AW.GOLD, "ExtraBold", 4))
	prompt_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	prompt_lbl.position.y += 40
	prompt_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(prompt_lbl)
	# avisos
	notes = AW.vbox(6)
	notes.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notes.position = Vector2(-300, 90)
	notes.custom_minimum_size.x = 600
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notes)
	_build_fishing_ui()
	panel = Control.new()
	AW.full_rect(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	Game.run_changed.connect(_on_run)
	Game.notify.connect(func(t, c): note(t, c))
	Game.catch_announced.connect(_on_catch)
	Game.night_ended.connect(_on_night_end)
	Game.game_over.connect(_on_game_over)
	Game.fx.connect(_on_fx)
	meta = MetaUi.new()
	add_child(meta)
	meta.setup(self)


func start() -> void:
	close_panels()
	AW.clear(notes)
	meta.start()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	note("Clique na tela para olhar. SEGURE e SOLTE o clique para arremessar. Vá ao TIMÃO (E) para pilotar.", AW.CYAN)


func bind_player(p: PlayerController) -> void:
	player = p
	p.prompt_changed.connect(func(t): prompt_lbl.text = t)
	p.fishing.state_changed.connect(_on_fish_state)
	p.fishing.message.connect(func(t, c): note(t, c))
	meta.bind_player(p)


func note(text: String, col: Color = AW.TEXT) -> void:
	var p := AW.panel(Color(AW.BG, 0.85), col, 10)
	var l := AW.label(text, 17, col.lightened(0.2), "Bold", 3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 560
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	notes.add_child(p)
	AW.pop(p, 1.15, 0.25)
	while notes.get_child_count() > 3:
		notes.get_child(0).queue_free()
		notes.remove_child(notes.get_child(0))
	var tw := p.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _on_run(r: Dictionary) -> void:
	_run = r
	top_lbl.text = "NOITE %d  ·  %s" % [int(r.night), str(r.clock)]
	zone_lbl.text = "%s  (%s)%s" % [r.zone, r.depth, "  ·  NO PORTO" if r.docked else ""]
	money_lbl.text = Fmt.money(int(r.money))
	quota_lbl.text = "COTA: %s / %s  ·  %d noite(s) restante(s)" % [Fmt.money(int(r.sold_cycle)), Fmt.money(int(r.quota)), int(r.nights_left)]
	quota_bar.max_value = float(r.quota)
	quota_bar.value = float(r.sold_cycle)
	cooler_lbl.text = "Na caixa: %d peixes (%s)  ·  Lanterna [F]: %s" % [int(r.cooler_count), Fmt.money(int(r.cooler_value)), "ACESA" if r.lantern else "APAGADA"]
	hull_bar.max_value = float(r.hull_max)
	if panel.get_child_count() > 0 and panel.get_child(0).name == "Dock":
		open_cooler()


func _process(_d: float) -> void:
	if not visible:
		return
	if Game.in_run():
		var st := Game.world_state_cache()
		if not st.is_empty():
			hull_bar.value = float(st.get("hull", 0.0))
			hull_lbl.text = "CASCO %d%%%s" % [int(100.0 * float(st.hull) / maxf(1.0, float(_run.get("hull_max", 100)))), "  —  VAZANDO!" if st.leaks.size() > 0 else ""]
			hull_lbl.add_theme_color_override("font_color", AW.RED if st.leaks.size() > 0 else AW.TEXT)
			var mins := int(float(st.minute)) + 20 * 60
			top_lbl.text = "NOITE %d  ·  %02d:%02d" % [int(_run.get("night", 1)), (mins / 60) % 24, mins % 60]
			if int(_run.get("upgrades", {}).get("sonar", 0)) > 0:
				var d := float(st.get("dread", 0.0))
				sonar_lbl.text = "SONAR: perigo %s" % ("ALTO!" if d > 60 else ("médio" if d > 30 else "baixo"))
				sonar_lbl.add_theme_color_override("font_color", AW.RED if d > 60 else (AW.ORANGE if d > 30 else AW.GREEN))
			else:
				sonar_lbl.text = ""
	if player and fish_ui.visible:
		var f := player.fishing
		charge_bar.value = f.charge
		reel_draw.queue_redraw()


# --- Pesca ------------------------------------------------------------------------

func _build_fishing_ui() -> void:
	fish_ui = Control.new()
	AW.full_rect(fish_ui)
	fish_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fish_ui)
	charge_bar = ProgressBar.new()
	charge_bar.show_percentage = false
	charge_bar.max_value = 1.0
	charge_bar.custom_minimum_size = Vector2(240, 12)
	charge_bar.set_anchors_preset(Control.PRESET_CENTER)
	charge_bar.position = Vector2(-120, 70)
	charge_bar.visible = false
	fish_ui.add_child(charge_bar)
	bite_lbl = AW.title("!", 90, AW.RED)
	bite_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	bite_lbl.position.y -= 120
	bite_lbl.visible = false
	fish_ui.add_child(bite_lbl)
	reel_box = AW.panel(Color(AW.BG, 0.85), AW.CYAN, 14)
	reel_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	reel_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	reel_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	reel_box.offset_bottom = -90
	var rv := AW.vbox(6)
	reel_box.add_child(rv)
	rv.add_child(AW.center(AW.label("SEGURE o clique para puxar · mantenha a TENSÃO na faixa verde", 15, AW.TEXT, "Bold")))
	reel_draw = Control.new()
	reel_draw.custom_minimum_size = Vector2(560, 64)
	reel_draw.draw.connect(_draw_reel)
	rv.add_child(reel_draw)
	reel_box.visible = false
	fish_ui.add_child(reel_box)


func _on_fish_state(s: String) -> void:
	charge_bar.visible = s == "charging"
	bite_lbl.visible = s == "bite"
	reel_box.visible = s == "reeling"
	if s == "bite":
		AW.pop(bite_lbl, 2.0, 0.2)


func _draw_reel() -> void:
	if player == null:
		return
	var f := player.fishing
	var w := reel_draw.size.x
	var y := 4.0
	reel_draw.draw_rect(Rect2(0, y, w, 22), Color(1, 1, 1, 0.08))
	reel_draw.draw_rect(Rect2(f.zone_lo * w, y, (f.zone_hi - f.zone_lo) * w, 22), Color(AW.GREEN, 0.55))
	reel_draw.draw_rect(Rect2(w * 0.92, y, w * 0.08, 22), Color(AW.RED, 0.5))
	var x := clampf(f.tension, 0.0, 1.0) * w
	reel_draw.draw_rect(Rect2(x - 4, y - 4, 8, 30), Color.WHITE)
	var font := AW.font("Bold")
	reel_draw.draw_string(font, Vector2(0, y + 46), "TENSÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AW.MUTED)
	reel_draw.draw_rect(Rect2(70, y + 34, w - 70, 14), Color(1, 1, 1, 0.08))
	reel_draw.draw_rect(Rect2(70, y + 34, (w - 70) * f.progress, 14), AW.GOLD)
	reel_draw.draw_string(font, Vector2(w - 60, y + 46), "%d%%" % int(f.progress * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, AW.GOLD)


func _on_catch(pid: int, f: Dictionary) -> void:
	var rr: Dictionary = FishDB.rarity(str(f.rarity))
	var col := Color(str(rr.color))
	if pid != Game.my_pid():
		note("%s pescou: %s (%s) %s" % [Game.player_view(pid).get("name", "?"), f.name, rr.name, Fmt.money(int(f.value))], col)
		return
	if catch_card and is_instance_valid(catch_card):
		catch_card.queue_free()
	catch_card = AW.panel(Color(AW.BG, 0.92), col, 18)
	var v := AW.vbox(2)
	catch_card.add_child(v)
	v.add_child(AW.center(AW.label(str(rr.name), 18, col, "ExtraBold", 3)))
	v.add_child(AW.title(str(f.name), 44, col.lightened(0.2)))
	v.add_child(AW.center(AW.label("%.1f kg  ·  vale %s" % [float(f.kg), Fmt.money(int(f.value))], 22, Color.WHITE, "Bold", 3)))
	var preview := FishPreview.new()
	preview.setup(f)
	var cc := CenterContainer.new()
	cc.add_child(preview)
	v.add_child(cc)
	catch_card.set_anchors_preset(Control.PRESET_CENTER)
	catch_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	catch_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(catch_card)
	AW.slam(catch_card, 1.6, 0.35)
	var card := catch_card
	var tw := card.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(card.queue_free)


func _on_fx(kind: String, data: Dictionary) -> void:
	match kind:
		"tentacle_smash":
			if int(data.get("victim", -1)) == Game.my_pid():
				note("O TENTÁCULO TE AGARROU! Você derrubou o que tinha na mão.", AW.RED)
				if player:
					player.fishing.cancel()
				_flash(Color(0.4, 0, 0, 0.8))
		"sink":
			_flash(Color(0, 0.05, 0.15, 1.0))
		"leviathan":
			_flash(Color(0.3, 0, 0, 0.7))
		"sold":
			Audio.play("money_gain")


func _flash(c: Color) -> void:
	var r := ColorRect.new()
	r.color = c
	AW.full_rect(r)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.0, 1.6)
	tw.tween_callback(r.queue_free)


# --- Porto / caixa de peixes --------------------------------------------------------

func panel_open() -> bool:
	return panel.get_child_count() > 0


func _lock_player() -> void:
	if player:
		player.enabled = false


func close_panels() -> void:
	AW.clear(panel)
	if Game.in_run():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player:
		player.enabled = true


func open_cooler() -> void:
	AW.clear(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player:
		player.enabled = false
	var docked := bool(_run.get("docked", false))
	var p := AW.panel(Color(AW.BG, 0.95), AW.CYAN, 22)
	p.name = "Dock"
	p.custom_minimum_size.x = 820
	var v := AW.vbox(8)
	p.add_child(v)
	v.add_child(AW.title("PORTO" if docked else "CAIXA DE PEIXES", 44, AW.CYAN))
	v.add_child(AW.center(AW.label("Dinheiro: %s  ·  Na caixa: %d peixes = %s" % [Fmt.money(int(_run.get("money", 0))), int(_run.get("cooler_count", 0)), Fmt.money(int(_run.get("cooler_value", 0)))], 18, AW.GOLD, "Bold", 3)))
	if docked:
		var h := AW.hbox()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		var sell := AW.button("VENDER TUDO (%s)" % Fmt.money(int(_run.get("cooler_value", 0))), func(): Game.request("sell"), AW.GREEN, 24, 360)
		sell.disabled = int(_run.get("cooler_count", 0)) == 0
		h.add_child(sell)
		v.add_child(h)
		v.add_child(HSeparator.new())
		v.add_child(AW.label("MELHORIAS (para toda a tripulação)", 20, AW.GOLD, "ExtraBold"))
		var ups: Dictionary = _run.get("upgrades", {})
		for k in RunModel.UPGRADES:
			var u: Dictionary = RunModel.UPGRADES[k]
			var lv := int(ups.get(k, 0))
			var costs: Array = u.costs
			var row := AW.hbox(10)
			var nm := AW.label("%s  (nível %d/%d)" % [u.name, lv, costs.size()], 16, AW.TEXT, "Bold")
			nm.custom_minimum_size.x = 300
			row.add_child(nm)
			var d := AW.label(str(u.desc), 13, AW.MUTED)
			d.custom_minimum_size.x = 260
			row.add_child(d)
			var key: String = k
			if lv < costs.size():
				var b := AW.button("COMPRAR " + Fmt.money(int(costs[lv])), func(): Game.request("buy", [key]), AW.PURPLE, 15)
				b.disabled = int(_run.get("money", 0)) < int(costs[lv])
				row.add_child(b)
			else:
				row.add_child(AW.label("MÁXIMO", 15, AW.GREEN, "ExtraBold"))
			v.add_child(row)
	else:
		var t := AW.label("Volte ao PORTO (perto do farol e da peixaria) para vender e comprar melhorias.\nAntes das 05:00! Quem fica no mar perde metade da pesca.", 16, AW.MUTED)
		AW.wrap(t)
		t.custom_minimum_size.x = 760
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
	var hc := AW.hbox()
	hc.alignment = BoxContainer.ALIGNMENT_CENTER
	hc.add_child(AW.button("FECHAR (ESC)", close_panels, AW.PANEL2, 18, 240))
	v.add_child(hc)
	panel.add_child(AW.centered(p))
	p.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_night_end(s: Dictionary) -> void:
	AW.clear(panel)
	var p := AW.panel(Color(AW.BG, 0.95), AW.GOLD, 24)
	var v := AW.vbox(8)
	p.add_child(v)
	v.add_child(AW.title("O SOL NASCEU", 54, AW.GOLD))
	v.add_child(AW.center(AW.label("Fim da noite %d" % int(s.night), 22, AW.TEXT, "Bold")))
	v.add_child(AW.center(AW.label("Vendido ao amanhecer: %s" % Fmt.money(int(s.sold)), 20, AW.GREEN, "Bold")))
	if int(s.lost) > 0:
		v.add_child(AW.center(AW.label("Perdido por ficar no mar: %s" % Fmt.money(int(s.lost)), 20, AW.RED, "Bold")))
	if s.get("quota_check", false):
		v.add_child(AW.title("COTA BATIDA!", 40, AW.GREEN))
	v.add_child(AW.center(AW.label("Próxima cota: %s" % Fmt.money(int(s.get("next_quota", 0))), 18, AW.CYAN, "Bold")))
	panel.add_child(AW.centered(p))
	p.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
	AW.slam(p, 1.4, 0.4)
	Audio.play("reveal")
	var tw := p.create_tween()
	tw.tween_interval(5.5)
	tw.tween_callback(func():
		if is_instance_valid(p):
			AW.clear(panel))


func _on_game_over(s: Dictionary) -> void:
	AW.clear(panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player:
		player.enabled = false
	var p := AW.panel(Color(AW.BG, 0.97), AW.RED, 26)
	var v := AW.vbox(8)
	p.add_child(v)
	v.add_child(AW.title("FIM DA EXPEDIÇÃO", 54, AW.RED))
	v.add_child(AW.center(AW.label("A cota de %s não foi batida (vendido: %s)." % [Fmt.money(int(s.quota)), Fmt.money(int(s.sold_cycle))], 20, AW.TEXT, "Bold")))
	var st: Dictionary = s.stats
	v.add_child(AW.center(AW.label("Noites sobrevividas: %d" % int(s.nights), 22, AW.GOLD, "ExtraBold", 3)))
	v.add_child(AW.center(AW.label("Total vendido: %s  ·  Peixes: %d  ·  Naufrágios: %d" % [Fmt.money(int(st.earned)), int(st.caught), int(st.sinks)], 18, AW.TEXT, "Bold")))
	if str(st.best_name) != "":
		v.add_child(AW.center(AW.label("Melhor captura: %s (%s)" % [st.best_name, Fmt.money(int(st.best_value))], 18, AW.CYAN, "Bold")))
	if str(st.biggest_name) != "":
		v.add_child(AW.center(AW.label("Maior peixe: %s (%.1f kg)" % [st.biggest_name, float(st.biggest_kg)], 18, AW.CYAN, "Bold")))
	var h := AW.hbox(14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if Game.is_host():
		h.add_child(AW.button("NOVA EXPEDIÇÃO", func():
			close_panels()
			Game.request("rematch"), AW.GREEN, 22, 280))
	h.add_child(AW.button("MENU", func(): ui.back_to_menu(), AW.PANEL2, 22, 200))
	v.add_child(h)
	panel.add_child(AW.centered(p))
	AW.slam(p, 1.3, 0.4)
	Audio.play("lose")
