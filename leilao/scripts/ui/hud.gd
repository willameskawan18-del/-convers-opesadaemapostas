class_name Hud
extends Control
## HUD: dia/galpão, placar dos compradores e o seu dinheiro.

var top_lbl: Label
var board: VBoxContainer
var me_lbl: Label
var me_sub: Label


func _ready() -> void:
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", AW.style(Color(AW.ORANGE, 0.92), 12, Color(0, 0, 0, 0), 0, 14))
	chip.position = Vector2(18, 14)
	top_lbl = AW.label("", 20, Color("1a0f05"), "ExtraBold")
	chip.add_child(top_lbl)
	add_child(chip)
	var bp := AW.panel(Color(AW.BG, 0.8), AW.ORANGE, 12)
	bp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bp.offset_right = -16
	bp.offset_left = -16
	bp.offset_top = 14
	board = AW.vbox(2)
	bp.add_child(board)
	add_child(bp)
	var mp := AW.panel(Color(AW.BG, 0.85), AW.GOLD, 14)
	mp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	mp.offset_left = 16
	mp.offset_bottom = -16
	mp.offset_top = -16
	var mv := AW.vbox(0)
	mp.add_child(mv)
	me_lbl = AW.label("", 32, AW.GOLD, "ExtraBold", 4)
	mv.add_child(me_lbl)
	me_sub = AW.label("", 14, AW.MUTED, "Bold")
	mv.add_child(me_sub)
	add_child(mp)
	mp.name = "Me"
	Game.view_changed.connect(rebuild)
	Game.money_changed.connect(func(_a, _b, _c, _d): rebuild())
	Game.phase_changed.connect(func(_p, _i): rebuild())
	rebuild()


func rebuild() -> void:
	var info: Dictionary = Game.view.get("phase_info", {})
	var d := int(info.get("day", 1))
	var ds := int(info.get("days", Game.view.get("config", {}).get("days", 5)))
	top_lbl.text = "DIA %d/%d" % [d, ds] + (("  ·  GALPÃO %d" % int(info.unit)) if info.has("unit") else "")
	AW.clear(board)
	board.add_child(AW.label("PLACAR", 16, AW.ORANGE, "ExtraBold"))
	var pos := 0
	for p in Game.ranking_view():
		pos += 1
		var h := AW.hbox(10)
		var n := AW.label("%dº %s" % [pos, p.name], 15, GameData.character_color(str(p.character)), "Bold", 2)
		n.custom_minimum_size.x = 150
		h.add_child(n)
		var m := AW.label(Fmt.money(int(p.money)), 15, Color.WHITE, "ExtraBold", 2)
		m.custom_minimum_size.x = 80
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(m)
		board.add_child(h)
	var local := Game.local_players()
	var me_panel := get_node("Me") as Control
	me_panel.visible = local.size() > 0
	if local.size() > 0:
		var p: Dictionary = local[0]
		me_lbl.text = Fmt.money(int(p.money))
		var ups := []
		for k in p.get("upgrades", {}):
			ups.append(str(k).to_upper())
		me_sub.text = "%s  ·  itens: %d  ·  coleção: %d%s" % [p.name, int(p.get("items", 0)), int(p.get("kept", 0)), ("  ·  " + ", ".join(ups)) if ups.size() > 0 else ""]
