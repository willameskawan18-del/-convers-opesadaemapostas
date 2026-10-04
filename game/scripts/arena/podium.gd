class_name Podium
extends Node3D
## Púlpito de um jogador: personagem em cima, nome, dinheiro (com contagem animada),
## posição e uma etiqueta acima da cabeça (escolha, "PRONTO", etc.).

var pid := -1
var model: CharacterModel
var name_lbl: Label3D
var money_lbl: Label3D
var place_lbl: Label3D
var tag_lbl: Label3D
var crown: Node3D
var badge_lbl: Label3D
var ring: MeshInstance3D
var _shown_money := 0.0
var _target_money := 0
var _ring_mat: StandardMaterial3D
var _color := Color.WHITE


func setup(player: Dictionary) -> void:
	pid = int(player.id)
	var ch := str(player.character)
	_color = GameData.character_color(ch)
	var base_mat := M3.solid(Color("1a0b33"), 0.25, 0.4)
	M3.cylinder(self, 0.85, 1.0, 1.0, Vector3(0, 0.5, 0), base_mat, 32)
	M3.cylinder(self, 0.9, 0.9, 0.08, Vector3(0, 1.0, 0), M3.solid(Color("2a1257"), 0.2, 0.6), 32)
	M3.torus(self, 0.86, 0.95, Vector3(0, 1.02, 0), M3.glow(_color, 2.2))
	M3.torus(self, 0.98, 1.04, Vector3(0, 0.08, 0), M3.glow(_color, 1.2))
	# painel frontal
	var front := M3.box(self, Vector3(1.3, 0.62, 0.06), Vector3(0, 0.55, 0.9), M3.solid(Color("0d0420"), 0.2, 0.3))
	front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	M3.box(self, Vector3(1.3, 0.04, 0.07), Vector3(0, 0.88, 0.9), M3.glow(_color, 2.5), false)
	name_lbl = M3.label(self, str(player.name), Vector3(0, 0.7, 0.94), 26, _color.lightened(0.3), 6)
	money_lbl = M3.label(self, Fmt.money(int(player.money)), Vector3(0, 0.45, 0.94), 38, AW.GOLD, 8)
	place_lbl = M3.label(self, "", Vector3(0.0, 3.05, 0.0), 54, AW.GOLD, 12, true)
	tag_lbl = M3.label(self, "", Vector3(0, 2.62, 0.0), 40, Color.WHITE, 12, true)
	tag_lbl.visible = false
	ring = M3.torus(self, 1.15, 1.3, Vector3(0, 0.02, 0), null)
	_ring_mat = M3.glow(AW.GOLD, 3.0).duplicate()
	ring.material_override = _ring_mat
	ring.visible = false
	crown = Node3D.new()
	crown.position = Vector3(0, 3.0, 0)
	crown.visible = false
	add_child(crown)
	var gold := M3.glow(AW.GOLD, 2.0)
	M3.cylinder(crown, 0.3, 0.3, 0.16, Vector3.ZERO, gold, 16)
	for i in 5:
		var a := i * TAU / 5.0
		M3.cylinder(crown, 0.0, 0.07, 0.22, Vector3(cos(a) * 0.26, 0.18, sin(a) * 0.26), gold, 6)
	badge_lbl = M3.label(self, "", Vector3(0, -0.05, 0.94), 22, AW.CYAN, 6)
	model = CharacterModel.create(ch)
	model.position = Vector3(0, 1.04, 0)
	add_child(model)
	_shown_money = float(player.money)
	_target_money = int(player.money)


func set_money(v: int) -> void:
	_target_money = v


func set_flags(p: Dictionary) -> void:
	var flags: Dictionary = p.get("flags", {})
	crown.visible = flags.get("king", false)
	var b := []
	if flags.get("traitor", false):
		b.append("TRAIDOR")
	if flags.get("comeback", false):
		b.append("VIRADA")
	var sh := int(p.get("items", {}).get("shield", 0))
	if sh > 0:
		b.append("SAFE x%d" % sh)
	badge_lbl.text = "  ".join(b)


func set_place(pos: int) -> void:
	place_lbl.text = Fmt.place(pos) if pos > 0 else ""
	place_lbl.modulate = AW.place_color(pos)
	place_lbl.font_size = 54 if pos == 1 else 40


func set_tag(text: String, col: Color = Color.WHITE) -> void:
	tag_lbl.visible = text != ""
	tag_lbl.text = text
	tag_lbl.modulate = col
	if text != "":
		tag_lbl.scale = Vector3.ONE * 1.6
		create_tween().tween_property(tag_lbl, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func highlight(on: bool, col: Color = AW.GOLD) -> void:
	ring.visible = on
	_ring_mat.albedo_color = col
	_ring_mat.emission = col


func _process(delta: float) -> void:
	if absf(_shown_money - _target_money) > 0.5:
		_shown_money = move_toward(_shown_money, _target_money, maxf(absf(_target_money - _shown_money) * delta * 4.0, 400.0 * delta))
		money_lbl.text = Fmt.money(_shown_money)
		money_lbl.modulate = AW.GREEN if _target_money > _shown_money else AW.RED
	else:
		money_lbl.modulate = AW.GOLD
	if crown.visible:
		crown.rotation.y += delta * 1.2
		crown.position.y = 3.55 + sin(Time.get_ticks_msec() * 0.003) * 0.08
	if ring.visible:
		ring.rotation.y += delta * 1.5
		var s := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.04
		ring.scale = Vector3(s, 1.0, s)
