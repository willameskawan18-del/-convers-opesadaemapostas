class_name CareerUi
extends Control
## Carreira do jogador local: avisos de conquista, gatilhos a partir dos eventos da
## partida e a tela de catálogo/conquistas aberta pelo menu.

var toasts: VBoxContainer


func _ready() -> void:
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts = AW.vbox(6)
	toasts.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toasts.offset_left = 18
	toasts.offset_bottom = -18
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)
	Profile.achievement_unlocked.connect(_on_achievement)
	Game.step.connect(_on_step)


func _mine(pid: int) -> bool:
	return Game.local_players().any(func(p): return int(p.id) == pid)


func _on_step(s: Dictionary) -> void:
	var pid := int(s.get("pid", -1))
	if not _mine(pid):
		return
	match str(s.kind):
		"item":
			Profile.register_item(s.item)
		"summary":
			Profile.data.units = int(Profile.data.units) + 1
			var profit := (int(s.est_lo) + int(s.est_hi)) / 2 - int(s.paid)
			Profile.data.profit = int(Profile.data.profit) + profit
			Profile.save_profile()
			Profile.unlock("primeiro_galpao")
			if profit >= 5000:
				Profile.unlock("lucro5k")
			if profit <= -3000:
				Profile.unlock("prejuizo")
		"sales":
			for r in s.rows:
				if str(r[1]).begins_with("PECHINCHA ACEITA"):
					Profile.unlock("pechincha")
				if str(r[1]).contains("VAZIO"):
					Profile.unlock("vazio")
		"collection":
			if str(s.text).begins_with("Coleções completas"):
				Profile.unlock("colecao")


func _on_achievement(_id: String, title: String, desc: String) -> void:
	var p := AW.panel(Color(AW.BG, 0.93), AW.GOLD, 12)
	var v := AW.vbox(0)
	p.add_child(v)
	v.add_child(AW.label("CONQUISTA: " + title, 18, AW.GOLD, "ExtraBold", 3))
	v.add_child(AW.label(desc, 14, AW.TEXT, "Bold", 2))
	toasts.add_child(p)
	AW.fade_in(p, 0.3, 20)
	Audio.play("reveal", -6.0)
	var tw := p.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


## Tela de carreira: título, números, catálogo de itens e conquistas.
static func open_career(host: Control) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	AW.full_rect(dim)
	var pd: Dictionary = Profile.data
	var p := AW.panel(Color(AW.BG, 0.97), AW.GOLD, 22)
	var v := AW.vbox(8)
	p.add_child(v)
	v.add_child(AW.title("CARREIRA", 48, AW.GOLD))
	v.add_child(AW.center(AW.label(Profile.title().to_upper(), 24, AW.CYAN, "ExtraBold", 3)))
	v.add_child(AW.center(AW.label("Partidas: %d  ·  Vitórias: %d  ·  Galpões arrematados: %d  ·  Lucro estimado: %s  ·  Maior fortuna: %s" % [int(pd.matches), int(pd.wins), int(pd.units), Fmt.money(int(pd.profit)), Fmt.money(int(pd.best_money))], 15, AW.TEXT, "Bold")))
	var cat: Dictionary = pd.catalog
	v.add_child(AW.label("CATÁLOGO: %d/%d itens encontrados" % [cat.size(), Profile.catalog_total()], 18, AW.ORANGE, "ExtraBold", 2))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1080, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	v.add_child(scroll)
	var cats: Dictionary = GameData.load_json("items").categories
	for it in GameData.load_json("items").items:
		var found := cat.has(str(it.name))
		var c := AW.panel(Color(AW.PANEL, 0.9), Color(str(it.color)) if found else AW.MUTED, 8)
		c.custom_minimum_size = Vector2(260, 56)
		var cv := AW.vbox(0)
		c.add_child(cv)
		cv.add_child(AW.label(str(it.name) if found else "???", 14, AW.TEXT if found else AW.MUTED, "Bold"))
		cv.add_child(AW.label("%s%s" % [cats.get(it.cat, it.cat), ("  ·  achado %dx" % int(cat[it.name])) if found else ""], 11, AW.MUTED))
		grid.add_child(c)
	var ach: Dictionary = pd.achievements
	v.add_child(AW.label("CONQUISTAS: %d/%d" % [ach.size(), Profile.ACHIEVEMENTS.size()], 18, AW.GOLD, "ExtraBold", 2))
	var ag := GridContainer.new()
	ag.columns = 3
	ag.add_theme_constant_override("h_separation", 18)
	for k in Profile.ACHIEVEMENTS:
		var got := ach.has(k)
		var l := AW.label(("★ " if got else "☆ ") + str(Profile.ACHIEVEMENTS[k][0]) + " — " + str(Profile.ACHIEVEMENTS[k][1]), 12, AW.GOLD if got else AW.MUTED, "Bold")
		l.custom_minimum_size.x = 350
		AW.wrap(l)
		ag.add_child(l)
	v.add_child(ag)
	var h := AW.hbox()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(AW.button("FECHAR", func(): dim.queue_free(), AW.PANEL2, 18, 240))
	v.add_child(h)
	dim.add_child(AW.centered(p))
	host.add_child(dim)
	AW.pop(p, 1.05, 0.25)
	return dim
