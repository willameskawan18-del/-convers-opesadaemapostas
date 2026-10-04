class_name Dialogs
## Janelas modais: Configurações, Como Jogar, Entrar em partida, Pausa e avisos.


static func modal(parent: Control, title: String, glow: Color = AW.PINK, width: float = 640.0) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	AW.full_rect(dim)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	var p := AW.panel(Color(AW.BG, 0.97), glow, 26)
	p.custom_minimum_size.x = width
	var cc := AW.centered(p)
	dim.add_child(cc)
	var v := AW.vbox(12)
	p.add_child(v)
	v.add_child(AW.title(title, 44, glow.lightened(0.3)))
	AW.slam(p, 1.15, 0.25)
	return [dim, v]


static func close_row(v: VBoxContainer, dim: Control, text: String = "FECHAR") -> void:
	var h := AW.hbox()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var b := AW.button(text, func(): dim.queue_free(), AW.PANEL2, 20, 220)
	h.add_child(b)
	v.add_child(h)
	b.call_deferred("grab_focus")


static func settings(parent: Control) -> Control:
	var r := modal(parent, "CONFIGURAÇÕES", AW.CYAN, 680)
	var dim: Control = r[0]
	var v: VBoxContainer = r[1]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for pair in [["Volume geral", "master_volume"], ["Música", "music_volume"], ["Efeitos", "sfx_volume"], ["Interface", "ui_volume"], ["Sensibilidade", "sensitivity"]]:
		grid.add_child(AW.label(str(pair[0]), 18))
		var s := HSlider.new()
		s.min_value = 0.0 if pair[1] != "sensitivity" else 0.2
		s.max_value = 1.0 if pair[1] != "sensitivity" else 2.0
		s.step = 0.05
		s.value = float(Settings.get_value(pair[1]))
		s.custom_minimum_size = Vector2(320, 26)
		var key: String = pair[1]
		s.value_changed.connect(func(val): Settings.set_value(key, val))
		grid.add_child(s)
	grid.add_child(AW.label("Resolução", 18))
	grid.add_child(_options(Settings.RESOLUTIONS.map(func(r2): return "%dx%d" % [r2.x, r2.y]), int(Settings.get_value("resolution")), func(i): Settings.set_value("resolution", i)))
	grid.add_child(AW.label("Limite de FPS", 18))
	grid.add_child(_options(Settings.FPS_LIMITS.map(func(f): return "Sem limite" if f == 0 else str(f)), int(Settings.get_value("fps_limit")), func(i): Settings.set_value("fps_limit", i)))
	grid.add_child(AW.label("Qualidade", 18))
	grid.add_child(_options(["Baixa", "Média", "Alta"], int(Settings.get_value("quality")), func(i): Settings.set_value("quality", i)))
	grid.add_child(AW.label("Idioma", 18))
	grid.add_child(_options(Settings.LANGUAGES.map(func(l): return l[1]), maxi(0, Settings.LANGUAGES.map(func(l): return l[0]).find(Settings.get_value("language"))), func(i): Settings.set_value("language", Settings.LANGUAGES[i][0])))
	for pair in [["Tela cheia", "fullscreen"], ["VSync", "vsync"], ["Tremer a câmera", "camera_shake"]]:
		grid.add_child(AW.label(str(pair[0]), 18))
		var cb := CheckButton.new()
		cb.button_pressed = bool(Settings.get_value(pair[1]))
		var key2: String = pair[1]
		cb.toggled.connect(func(on): Settings.set_value(key2, on))
		grid.add_child(cb)
	close_row(v, dim)
	return dim


static func _options(items: Array, sel: int, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(clampi(sel, 0, items.size() - 1))
	o.item_selected.connect(func(i): cb.call(i))
	o.custom_minimum_size.x = 320
	return o


static func how_to(parent: Control) -> Control:
	var r := modal(parent, "COMO JOGAR", AW.ORANGE, 820)
	var dim: Control = r[0]
	var v: VBoxContainer = r[1]
	var text := """[b][color=#ffcc33]OBJETIVO:[/color][/b] terminar a partida com o MAIOR patrimônio. Todos começam com $1.000 fictícios.

[b][color=#ff4d6d]AS PORTAS[/color][/b] — escolha A, B ou C. Uma multiplica sua aposta por 5, outra por 2 e outra zera.
[b][color=#ff9f1c]RISCO[/color][/b] — SAFE ganha pouco, garantido. RISK é cara ou coroa: ganha muito ou perde muito.
[b][color=#3ddc97]REAÇÃO[/color][/b] — espere o VERDE e aperte o mais rápido possível. Apertou antes? Queimou!
[b][color=#4dabf7]LEILÃO[/color][/b] — lance secreto por um prêmio misterioso. O maior lance paga e leva... pode ser fortuna ou caixa vazia.
[b][color=#b072ff]BLUFF[/color][/b] — você recebe uma oferta SECRETA. PEGAR garante; DOBRAR pode render o dobro ou uma perda pesada.
[b][color=#ffd43b]EVENTOS[/color][/b] — no meio da partida, algo inesperado sacode o placar (imposto do líder, Robin Hood, chuva de dinheiro...).

[b][color=#ffcc33]ALL WIN[/color][/b] — a decisão final. SAFE guarda 90%. ALL WIN coloca tudo na roleta: JACKPOT x4, DOBROU x2 ou PERDE quase tudo.

[b]Zerou?[/b] Você continua jogando com fichas de resgate. Sempre dá para virar o jogo!
[b]Mesmo PC:[/b] adicione vários jogadores no lobby — as escolhas secretas são feitas uma pessoa por vez.
[b]Online:[/b] o host abre a sala e os amigos entram em JOIN GAME com o IP mostrado no lobby."""
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.text = text
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(760, 0)
	rt.add_theme_font_size_override("normal_font_size", 17)
	rt.add_theme_font_size_override("bold_font_size", 17)
	rt.add_theme_font_override("bold_font", AW.font("ExtraBold"))
	v.add_child(rt)
	close_row(v, dim, "ENTENDI!")
	return dim


static func join(parent: Control, on_join: Callable) -> Control:
	var r := modal(parent, "JOIN GAME", AW.CYAN, 560)
	var dim: Control = r[0]
	var v: VBoxContainer = r[1]
	v.add_child(AW.label("Seu nome", 16, AW.MUTED))
	var name_e := LineEdit.new()
	name_e.max_length = 16
	name_e.text = str(Profile.data.get("last_name", ""))
	name_e.placeholder_text = "Nome"
	v.add_child(name_e)
	v.add_child(AW.label("IP do host (aparece no lobby dele)", 16, AW.MUTED))
	var ip := LineEdit.new()
	ip.placeholder_text = "ex.: 192.168.0.10"
	ip.text = "127.0.0.1"
	v.add_child(ip)
	var status := AW.label("", 16, AW.ORANGE)
	status.name = "Status"
	v.add_child(status)
	var h := AW.hbox()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(AW.button("ENTRAR", func():
		status.text = "Conectando..."
		on_join.call(ip.text, name_e.text), AW.GREEN, 22, 200))
	h.add_child(AW.button("CANCELAR", func(): dim.queue_free(), AW.PANEL2, 22))
	v.add_child(h)
	return dim


static func pause(parent: Control, on_resume: Callable, on_menu: Callable, on_settings: Callable) -> Control:
	var r := modal(parent, "PAUSA", AW.PURPLE, 460)
	var dim: Control = r[0]
	var v: VBoxContainer = r[1]
	v.add_child(AW.center(AW.label("A partida continua rolando para os outros!", 15, AW.MUTED)))
	for b in [["CONTINUAR", on_resume, AW.GREEN], ["CONFIGURAÇÕES", on_settings, AW.CYAN.darkened(0.3)], ["SAIR PARA O MENU", on_menu, AW.RED.darkened(0.3)]]:
		var btn := AW.button(str(b[0]), b[1], b[2], 22, 380)
		v.add_child(btn)
	return dim


static func toast(parent: Control, text: String, col: Color = AW.ORANGE) -> void:
	var p := AW.panel(Color(AW.BG, 0.95), col, 14)
	p.add_child(AW.label(text, 18, Color.WHITE, "Bold"))
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.position.y = 20
	parent.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
