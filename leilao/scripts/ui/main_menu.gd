class_name MainMenu
extends Control
## Menu principal: PLAY, CREATE GAME, JOIN GAME, HOW TO PLAY, SETTINGS, EXIT.

var ui: Node
var logo: Label
var _t := 0.0


func _ready() -> void:
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# degradê lateral para destacar os botões
	var shade := TextureRect.new()
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(AW.BG, 0.92), Color(AW.BG, 0.0)])
	g.gradient = gr
	g.fill_to = Vector2(1, 0)
	shade.texture = g
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 760
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var v := AW.vbox(9)
	v.position = Vector2(70, 34)
	add_child(v)
	logo = AW.title("LEILÃO DE GARAGEM", 64, AW.GOLD)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(logo)
	var sub := AW.label("COMPRE ÀS CEGAS · ABRA · REVENDA  ·  1 A 6 JOGADORES", 20, AW.CYAN, "Bold", 4)
	v.add_child(sub)
	v.add_child(AW.spacer(4, true))
	var buttons := [
		["PLAY", func(): ui.quick_play(), AW.PINK],
		["CREATE GAME", func(): ui.open_lobby(), AW.PURPLE],
		["JOIN GAME", func(): ui.open_join(), AW.CYAN.darkened(0.2)],
		["HOW TO PLAY", func(): ui.open_how_to(), AW.ORANGE.darkened(0.15)],
		["SETTINGS", func(): ui.open_settings(), AW.PANEL2.lightened(0.2)],
		["EXIT", func(): get_tree().quit(), AW.RED.darkened(0.3)],
	]
	var i := 0
	for b in buttons:
		var btn := AW.button(str(b[0]), b[1], b[2], 21, 360)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(btn)
		btn.modulate.a = 0.0
		var tw := btn.create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(btn, "modulate:a", 1.0, 0.25)
		if i == 0:
			btn.call_deferred("grab_focus")
		i += 1
	var pd: Dictionary = Profile.data
	var stats := AW.label("Partidas: %d   ·   Vitórias: %d   ·   Maior fortuna: %s" % [int(pd.matches), int(pd.wins), Fmt.money(int(pd.best_money))], 15, AW.MUTED, "SemiBold", 3)
	stats.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	stats.position = Vector2(72, -46)
	add_child(stats)
	var note := AW.label("Dinheiro 100% fictício.", 13, Color(AW.MUTED, 0.7))
	note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	note.position = Vector2(-330, -40)
	add_child(note)
	AW.slam(logo, 2.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	logo.rotation = sin(_t * 1.3) * 0.015
	var s := 1.0 + sin(_t * 2.6) * 0.015
	logo.pivot_offset = logo.size / 2.0
	logo.scale = Vector2(s, s)
	logo.add_theme_color_override("font_shadow_color", Color(AW.PINK.lerp(AW.CYAN, sin(_t) * 0.5 + 0.5), 0.7))
