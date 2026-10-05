class_name PlayerCard
extends PanelContainer
## Cartão do jogador no HUD: nome, dinheiro (animado), posição e status da decisão.

var pid := -1
var _shown := 0.0
var _target := 0
var name_lbl: Label
var money_lbl: Label
var place_lbl: Label
var status_lbl: Label
var char_lbl: Label
var badge_lbl: Label
var col := Color.WHITE
var is_local := false


func setup(p: Dictionary, local: bool) -> void:
	pid = int(p.id)
	is_local = local
	col = GameData.character_color(str(p.character))
	custom_minimum_size = Vector2(150, 0)
	var st := AW.glow_style(Color(AW.BG, 0.88), col if not local else AW.GOLD, 14, 3 if local else 2, 10)
	st.border_width_top = 6
	st.border_color = col
	add_theme_stylebox_override("panel", st)
	var v := AW.vbox(0)
	add_child(v)
	var top := AW.hbox(4)
	v.add_child(top)
	char_lbl = AW.label(str(GameData.character(str(p.character)).name).to_upper(), 11, col.lightened(0.2), "Bold")
	top.add_child(char_lbl)
	top.add_child(AW.spacer())
	place_lbl = AW.label("", 16, AW.GOLD, "ExtraBold", 3)
	top.add_child(place_lbl)
	name_lbl = AW.label(str(p.name) + ("  (VOCÊ)" if local and Game.local_players().size() == 1 and str(p.name) != "VOCÊ" else ""), 15, AW.TEXT, "Bold")
	name_lbl.clip_text = true
	v.add_child(name_lbl)
	money_lbl = AW.label(Fmt.money(int(p.money)), 24, AW.GOLD, "ExtraBold", 3)
	v.add_child(money_lbl)
	badge_lbl = AW.label("", 12, AW.GOLD, "ExtraBold", 2)
	v.add_child(badge_lbl)
	status_lbl = AW.label("", 12, AW.GREEN, "Bold")
	v.add_child(status_lbl)
	set_badges(p)
	_shown = float(p.money)
	_target = int(p.money)


func set_money(v: int) -> void:
	_target = v


## Selos: KING (líder), VIRADA (bônus de recuperação), TRAIDOR e SAFE CARDs.
func set_badges(p: Dictionary) -> void:
	var b := []
	var flags: Dictionary = p.get("flags", {})
	if flags.get("king", false):
		b.append("KING")
	if flags.get("comeback", false):
		b.append("VIRADA +50%")
	if flags.get("traitor", false):
		b.append("TRAIDOR")
	var sh := int(p.get("items", {}).get("shield", 0))
	if sh > 0:
		b.append("SAFE x%d" % sh)
	badge_lbl.text = "  ".join(b)
	badge_lbl.add_theme_color_override("font_color", AW.GOLD if flags.get("king", false) else (AW.RED if flags.get("traitor", false) else AW.CYAN))


func set_place(pos: int) -> void:
	var old := place_lbl.text
	place_lbl.text = Fmt.place(pos)
	place_lbl.add_theme_color_override("font_color", AW.place_color(pos))
	if old != "" and old != place_lbl.text:
		AW.pop(place_lbl, 1.8)


func set_status(text: String, c: Color = AW.GREEN) -> void:
	status_lbl.text = text
	status_lbl.add_theme_color_override("font_color", c)


func _process(delta: float) -> void:
	if absf(_shown - _target) > 0.5:
		_shown = move_toward(_shown, _target, maxf(absf(_target - _shown) * delta * 4.0, 300.0 * delta))
		money_lbl.text = Fmt.money(_shown)
		money_lbl.add_theme_color_override("font_color", AW.GREEN if _target > _shown else AW.RED)
	else:
		money_lbl.add_theme_color_override("font_color", AW.GOLD if _target >= 0 else AW.RED)
