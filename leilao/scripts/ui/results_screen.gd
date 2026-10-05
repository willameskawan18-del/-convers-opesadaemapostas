class_name ResultsScreen
extends Control
## Tela final: o MAGNATA DOS GALPÕES, ranking e prêmios.

var ui: Node


func show_summary(s: Dictionary) -> void:
	AW.clear(self)
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rk: Array = s.get("ranking", [])
	if rk.is_empty():
		return
	var w: Dictionary = rk[0]
	var lp := AW.panel(Color(AW.BG, 0.85), AW.GOLD, 20)
	lp.position = Vector2(30, 24)
	add_child(lp)
	var left := AW.vbox(4)
	lp.add_child(left)
	var crown := AW.label("MAGNATA DOS GALPÕES", 46, AW.GOLD, "ExtraBold", 8)
	left.add_child(crown)
	AW.slam(crown, 2.5, 0.5)
	left.add_child(AW.label(str(w.name), 50, GameData.character_color(str(w.character)), "ExtraBold", 8))
	left.add_child(AW.label(Fmt.money(int(w.money)), 60, Color.WHITE, "ExtraBold", 8))
	left.add_child(AW.label("Galpões arrematados: %d  ·  Maior lance: %s" % [int(w.stats.get("units_won", 0)), Fmt.money(int(w.stats.get("biggest_bid", 0)))], 16, AW.MUTED, "Bold"))
	var right := AW.panel(Color(AW.BG, 0.9), AW.ORANGE, 18)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -30
	right.offset_left = -30
	right.offset_top = 24
	right.custom_minimum_size = Vector2(460, 0)
	add_child(right)
	var rv := AW.vbox(6)
	right.add_child(rv)
	rv.add_child(AW.label("RESULTADO FINAL", 26, AW.ORANGE, "ExtraBold", 3))
	for r in rk:
		var h := AW.hbox(8)
		var pl := AW.label("%dº" % int(r.position), 20, AW.place_color(int(r.position)), "ExtraBold", 3)
		pl.custom_minimum_size.x = 44
		h.add_child(pl)
		var n := AW.label(str(r.name), 19, GameData.character_color(str(r.character)), "Bold", 3)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		h.add_child(AW.label(Fmt.money(int(r.money)), 20, Color.WHITE, "ExtraBold", 3))
		rv.add_child(h)
	var aw: Array = s.get("awards", [])
	if aw.size() > 0:
		rv.add_child(HSeparator.new())
		rv.add_child(AW.label("PRÊMIOS", 18, AW.CYAN, "ExtraBold"))
		for a in aw:
			var h := AW.hbox(8)
			var t := AW.label(str(a.title), 13, AW.GOLD, "ExtraBold")
			t.custom_minimum_size.x = 190
			h.add_child(t)
			var nm := AW.label(str(a.name), 13, GameData.character_color(str(a.character)), "Bold")
			nm.custom_minimum_size.x = 90
			h.add_child(nm)
			h.add_child(AW.label(str(a.value), 13, AW.TEXT))
			rv.add_child(h)
	var bar := AW.hbox(14)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_bottom = -40
	add_child(bar)
	if Game.is_host():
		var again := AW.button("JOGAR NOVAMENTE", func(): Game.request_rematch(), AW.GREEN, 24, 300)
		bar.add_child(again)
		again.call_deferred("grab_focus")
		bar.add_child(AW.button("LOBBY", func(): Game.request_lobby(), AW.PURPLE, 24))
	else:
		bar.add_child(AW.label("Aguardando o host...", 18, AW.MUTED))
	bar.add_child(AW.button("MENU", func(): ui.back_to_menu(), AW.PANEL2, 24))
