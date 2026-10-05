class_name LobbyScreen
extends Control
## Lobby cooperativo: pescadores (até 4), personagem, duração da noite e sala online.

var ui: Node
var list: VBoxContainer
var side: VBoxContainer


func _ready() -> void:
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := AW.panel(Color(AW.BG, 0.9), AW.CYAN, 18)
	left.position = Vector2(24, 20)
	left.custom_minimum_size = Vector2(520, 0)
	add_child(left)
	var lv := AW.vbox(8)
	left.add_child(lv)
	lv.add_child(AW.label("TRIPULAÇÃO", 30, AW.CYAN, "ExtraBold", 4))
	list = AW.vbox(6)
	lv.add_child(list)
	var tip := AW.label("Cada pescador joga no próprio computador. Chame os amigos: ABRIR SALA ONLINE → eles entram em JOIN GAME.", 14, AW.MUTED)
	AW.wrap(tip)
	tip.custom_minimum_size.x = 480
	lv.add_child(tip)
	var right := AW.panel(Color(AW.BG, 0.9), AW.GOLD, 18)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -24
	right.offset_left = -24
	right.offset_top = 20
	right.custom_minimum_size = Vector2(380, 0)
	add_child(right)
	side = AW.vbox(10)
	right.add_child(side)
	Game.view_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if not is_inside_tree() or str(Game.view.get("mode", "")) != "lobby":
		return
	AW.clear(list)
	var chars := GameData.characters()
	for p in Game.view.get("players", []):
		var col := GameData.character_color(str(p.character))
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", AW.style(Color(col, 0.16), 12, col, 2, 10))
		var h := AW.hbox(8)
		row.add_child(h)
		var nm := AW.label(str(p.name), 20, Color.WHITE, "ExtraBold", 3)
		nm.custom_minimum_size.x = 170
		h.add_child(nm)
		h.add_child(AW.spacer())
		var mine := int(p.owner_peer) == Game.my_peer()
		var cdata: Dictionary = GameData.character(str(p.character))
		var idx := chars.find(cdata)
		if mine:
			h.add_child(AW.button("<", func(): Game.request("set_character", [chars[(idx - 1 + chars.size()) % chars.size()].id]), AW.PANEL2, 16))
		var cl := AW.label(str(cdata.name).to_upper(), 18, col.lightened(0.3), "ExtraBold", 3)
		cl.custom_minimum_size.x = 120
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(cl)
		if mine:
			h.add_child(AW.button(">", func(): Game.request("set_character", [chars[(idx + 1) % chars.size()].id]), AW.PANEL2, 16))
		list.add_child(row)
	AW.clear(side)
	side.add_child(AW.label("EXPEDIÇÃO", 26, AW.GOLD, "ExtraBold", 4))
	var cfg: Dictionary = Game.view.get("config", {})
	if Game.is_host():
		var h := AW.hbox(6)
		h.add_child(AW.label("Noite (min)", 16, AW.TEXT, "Bold"))
		for v in [4, 6, 8]:
			var val: int = v
			h.add_child(AW.button(str(val), func(): Game.request("set_config", ["night_minutes", val]), AW.PINK if val == int(cfg.get("night_minutes", 6)) else AW.PANEL2, 16))
		side.add_child(h)
	var info := AW.label("Pesquem e vendam no porto. A cada 3 noites existe uma COTA de vendas. Não bateu a cota? Fim da expedição.", 14, AW.MUTED)
	AW.wrap(info)
	info.custom_minimum_size.x = 340
	side.add_child(info)
	side.add_child(HSeparator.new())
	side.add_child(AW.label("ONLINE (REDE)", 20, AW.CYAN, "ExtraBold", 3))
	var net := AW.label("", 14, AW.TEXT)
	AW.wrap(net)
	net.custom_minimum_size.x = 340
	side.add_child(net)
	if Game.is_host():
		if Net.is_online():
			var t := "SALA ABERTA! Tripulantes: %d\\n" % Net.peers().size()
			match Net.upnp_status:
				"procurando": t += "INTERNET: abrindo a porta no roteador...\\n"
				"ok": t += "INTERNET: IP para os amigos: %s\\n" % Net.external_ip
				"falhou": t += "INTERNET: o roteador não abriu a porta. Use Radmin VPN.\\n"
			t += "MESMA REDE / VPN: %s" % ", ".join(Net.local_addresses())
			net.text = t.replace("\\n", "\n")
			if Net.upnp_status == "ok":
				var ip := Net.external_ip
				side.add_child(AW.button("COPIAR IP", func(): DisplayServer.clipboard_set(ip), AW.GOLD.darkened(0.3), 16))
		else:
			net.text = "Abra a sala para amigos entrarem (porta %d)." % Net.DEFAULT_PORT
			side.add_child(AW.button("ABRIR SALA ONLINE", func(): ui.host_online(), AW.CYAN.darkened(0.3), 18))
		side.add_child(HSeparator.new())
		side.add_child(AW.button("ZARPAR!", func(): Game.request("start"), AW.GREEN, 30, 340))
		if Profile.has_expedition():
			side.add_child(AW.button("CONTINUAR EXPEDIÇÃO (NOITE %d)" % int(Profile.load_expedition().get("night", 1)), func(): Game.request("start", [true]), AW.GREEN.darkened(0.3), 16, 340))
	else:
		net.text = "Conectado. Aguarde o capitão zarpar."
	side.add_child(AW.button("VOLTAR", func(): ui.back_to_menu(), AW.PANEL2, 18, 340))
