class_name ResultsScreen
extends Control
## Tela final: ALL WINNER, pódio 1º/2º/3º e estatísticas de todos.

var ui: Node


func show_summary(s: Dictionary) -> void:
	AW.clear(self)
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rk: Array = s.get("ranking", [])
	if rk.is_empty():
		return
	var w: Dictionary = rk[0]
	var wcol := GameData.character_color(str(w.character))
	# vencedor (esquerda)
	var lp := AW.panel(Color(AW.BG, 0.82), AW.GOLD, 20)
	lp.position = Vector2(30, 24)
	add_child(lp)
	var left := AW.vbox(4)
	lp.add_child(left)
	var crown := AW.label("ALL WINNER", 72, AW.GOLD, "ExtraBold", 10)
	crown.add_theme_color_override("font_outline_color", Color("3a0a3f"))
	left.add_child(crown)
	AW.slam(crown, 3.0, 0.6)
	left.add_child(AW.label(str(w.name), 54, wcol, "ExtraBold", 8))
	left.add_child(AW.label(str(GameData.character(str(w.character)).name).to_upper(), 20, wcol.lightened(0.3), "Bold", 4))
	left.add_child(AW.label(Fmt.money(int(w.money)), 64, Color.WHITE, "ExtraBold", 8))
	var st: Dictionary = w.get("stats", {})
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	left.add_child(grid)
	var wins := "-"
	if int(w.owner_peer) == Game.my_peer() and not bool(w.is_bot):
		wins = str(int(Profile.data.get("wins", 0)))
	for pair in [["Vitórias na carreira", wins], ["Desafios ganhos", str(int(st.get("challenges_won", 0)))],
			["Maior multiplicador", Fmt.mult(float(st.get("best_mult", 0.0))) if float(st.get("best_mult", 0.0)) > 0 else "-"],
			["Maior risco assumido", Fmt.money(int(st.get("max_risk", 0)))], ["Pico de patrimônio", Fmt.money(int(st.get("peak_money", 0)))]]:
		grid.add_child(AW.label(str(pair[0]), 17, AW.MUTED, "SemiBold", 3))
		grid.add_child(AW.label(str(pair[1]), 19, AW.GOLD, "ExtraBold", 3))
	# ranking (direita)
	var right := AW.panel(Color(AW.BG, 0.9), AW.GOLD, 18)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -30
	right.offset_left = -30
	right.offset_top = 30
	right.custom_minimum_size = Vector2(440, 0)
	add_child(right)
	var rv := AW.vbox(6)
	right.add_child(rv)
	rv.add_child(AW.label("RESULTADO FINAL", 28, AW.GOLD, "ExtraBold", 4))
	var medals := ["1º OURO", "2º PRATA", "3º BRONZE"]
	for i in rk.size():
		var r: Dictionary = rk[i]
		var pos := int(r.position)
		var row := AW.hbox(8)
		var pl := AW.label(medals[pos - 1] if pos <= 3 else Fmt.place(pos), 18, AW.place_color(pos), "ExtraBold", 3)
		pl.custom_minimum_size.x = 110
		row.add_child(pl)
		var nl := AW.label(str(r.name), 19, GameData.character_color(str(r.character)), "Bold", 3)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		row.add_child(AW.label(Fmt.money(int(r.money)), 20, Color.WHITE, "ExtraBold", 3))
		rv.add_child(row)
		var rs: Dictionary = r.get("stats", {})
		var ms := str(r.get("mission", ""))
		rv.add_child(AW.label("   rodadas %d · mult. %s · risco %s%s" % [int(rs.get("challenges_won", 0)), Fmt.mult(float(rs.get("best_mult", 0.0))), Fmt.money(int(rs.get("max_risk", 0))), ("  · missão: " + ms) if ms != "" and i < 3 else ""], 12, AW.MUTED))
	var awards: Array = s.get("awards", [])
	if not awards.is_empty():
		rv.add_child(HSeparator.new())
		rv.add_child(AW.label("PRÊMIOS DA NOITE", 20, AW.CYAN, "ExtraBold", 3))
		for a in awards:
			var ar := AW.hbox(8)
			var t := AW.label(str(a.title), 14, AW.GOLD, "ExtraBold", 2)
			t.custom_minimum_size.x = 170
			ar.add_child(t)
			var nm := AW.label(str(a.name), 14, GameData.character_color(str(a.character)), "Bold", 2)
			nm.custom_minimum_size.x = 100
			ar.add_child(nm)
			ar.add_child(AW.label(str(a.value), 13, AW.TEXT, "SemiBold"))
			rv.add_child(ar)
	var bg: Dictionary = s.get("biggest_gain", {})
	var bl: Dictionary = s.get("biggest_loss", {})
	if not bg.is_empty() and int(bg.get("delta", 0)) > 0:
		rv.add_child(AW.label("Maior ganho: %s %s (%s)" % [Game.player_view(int(bg.pid)).get("name", "?"), Fmt.delta(int(bg.delta)), bg.reason], 14, AW.GREEN))
	if not bl.is_empty() and int(bl.get("delta", 0)) < 0:
		rv.add_child(AW.label("Maior perda: %s %s (%s)" % [Game.player_view(int(bl.pid)).get("name", "?"), Fmt.delta(int(bl.delta)), bl.reason], 14, AW.RED))
	# botões
	var bar := AW.hbox(14)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.position.y = -100
	add_child(bar)
	if Game.is_host():
		var again := AW.button("JOGAR NOVAMENTE", func(): Game.request_rematch(), AW.GREEN, 24, 300)
		bar.add_child(again)
		again.call_deferred("grab_focus")
		bar.add_child(AW.button("LOBBY", func(): Game.request_lobby(), AW.PURPLE, 24))
	else:
		bar.add_child(AW.label("Aguardando o host...", 18, AW.MUTED))
	bar.add_child(AW.button("MENU", func(): ui.back_to_menu(), AW.PANEL2, 24))
