class_name LobbyScreen
extends Control
## Lobby: jogadores locais, bots, jogadores em rede, personagens e regras da partida.

var ui: Node
var list: VBoxContainer
var side: VBoxContainer
var name_edit: LineEdit
var net_lbl: Label


func _ready() -> void:
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := AW.panel(Color(AW.BG, 0.9), AW.PINK, 18)
	left.position = Vector2(24, 20)
	left.custom_minimum_size = Vector2(560, 0)
	add_child(left)
	var lv := AW.vbox(8)
	left.add_child(lv)
	var head := AW.hbox()
	lv.add_child(head)
	head.add_child(AW.label("COMPETIDORES", 30, AW.GOLD, "ExtraBold", 4))
	head.add_child(AW.spacer())
	var count := AW.label("", 18, AW.MUTED, "Bold")
	count.name = "Count"
	head.add_child(count)
	list = AW.vbox(6)
	lv.add_child(list)
	var add_row := AW.hbox(8)
	lv.add_child(add_row)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Nome do jogador"
	name_edit.max_length = 16
	name_edit.custom_minimum_size.x = 210
	name_edit.text_submitted.connect(func(_t): _add_local())
	add_row.add_child(name_edit)
	add_row.add_child(AW.button("+ JOGADOR", _add_local, AW.GREEN, 18))
	var bot_btn := AW.button("+ BOT", func(): Game.request_add_player("", "", true), AW.PURPLE, 18)
	bot_btn.name = "BotBtn"
	add_row.add_child(bot_btn)
	lv.add_child(AW.label("Vários jogadores no mesmo PC? Adicione todos aqui: as escolhas secretas são feitas em vez (os outros não olham).", 13, AW.MUTED))
	(lv.get_child(lv.get_child_count() - 1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# lado direito: regras, rede, começar
	var right := AW.panel(Color(AW.BG, 0.9), AW.CYAN, 18)
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
	name_edit.text = str(Profile.data.get("last_name", ""))


func _add_local() -> void:
	var n := name_edit.text.strip_edges()
	if n == "":
		n = "JOGADOR %d" % (Game.view.players.size() + 1)
	Game.request_add_player(n.to_upper(), "", false)
	Profile.remember_player(n, str(Profile.data.get("last_character", "sortudo")))
	name_edit.text = ""


func _refresh() -> void:
	if not is_inside_tree() or str(Game.view.get("mode", "")) != "lobby":
		return
	var players: Array = Game.view.get("players", [])
	(find_child("Count", true, false) as Label).text = "%d/8" % players.size()
	(find_child("BotBtn", true, false) as Button).visible = Game.is_host()
	AW.clear(list)
	var chars := GameData.characters()
	for p in players:
		var mine := int(p.owner_peer) == Game.my_peer() or Game.is_host()
		var col := GameData.character_color(str(p.character))
		var row := PanelContainer.new()
		var st := AW.style(Color(col, 0.16), 12, col, 2, 10)
		row.add_theme_stylebox_override("panel", st)
		var h := AW.hbox(8)
		row.add_child(h)
		var nm := AW.label(str(p.name), 20, Color.WHITE, "ExtraBold", 3)
		nm.custom_minimum_size.x = 150
		h.add_child(nm)
		var kind := "BOT" if bool(p.is_bot) else ("LOCAL" if int(p.owner_peer) == Game.my_peer() else "ONLINE")
		h.add_child(AW.label(kind, 12, AW.MUTED, "Bold"))
		h.add_child(AW.spacer())
		var cdata: Dictionary = GameData.character(str(p.character))
		var pid := int(p.id)
		if mine:
			var idx := chars.find(cdata)
			h.add_child(AW.button("<", func(): Game.request_set_character(pid, chars[(idx - 1 + chars.size()) % chars.size()].id), AW.PANEL2, 16))
		var cl := AW.label(str(cdata.name).to_upper(), 18, col.lightened(0.3), "ExtraBold", 3)
		cl.custom_minimum_size.x = 120
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.tooltip_text = str(cdata.tagline)
		cl.mouse_filter = Control.MOUSE_FILTER_PASS
		h.add_child(cl)
		if mine:
			var idx2 := chars.find(cdata)
			h.add_child(AW.button(">", func(): Game.request_set_character(pid, chars[(idx2 + 1) % chars.size()].id), AW.PANEL2, 16))
			h.add_child(AW.button("X", func(): Game.request_remove_player(pid), AW.RED.darkened(0.3), 16))
		list.add_child(row)
	if players.is_empty():
		list.add_child(AW.label("Ninguém ainda. Adicione jogadores e bots!", 18, AW.MUTED))
	_build_side(players)


func _build_side(players: Array) -> void:
	AW.clear(side)
	var cfg: Dictionary = Game.view.get("config", {})
	side.add_child(AW.label("REGRAS", 26, AW.CYAN, "ExtraBold", 4))
	if Game.is_host():
		side.add_child(_option_row("Rodadas", [6, 8, 10, 12], int(cfg.get("rounds", 8)), func(v): Game.request_set_config("rounds", v)))
		side.add_child(_option_row("Tempo p/ decidir", [15, 20, 30], int(cfg.get("decision_time", 20)), func(v): Game.request_set_config("decision_time", v)))
	else:
		side.add_child(AW.label("Rodadas: %d  ·  Tempo: %ds" % [int(cfg.get("rounds", 8)), int(cfg.get("decision_time", 20))], 18))
	side.add_child(AW.label("Todos começam com $1.000 (fictícios).\nNo final: ALL WIN!", 15, AW.MUTED))
	side.add_child(HSeparator.new())
	side.add_child(AW.label("ONLINE (REDE)", 22, AW.CYAN, "ExtraBold", 4))
	net_lbl = AW.label("", 15, AW.TEXT)
	net_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	net_lbl.custom_minimum_size.x = 340
	side.add_child(net_lbl)
	if Game.is_host():
		if Net.is_online():
			var ips := Net.local_addresses()
			net_lbl.text = "SALA ABERTA! Amigos entram em JOIN GAME com o IP:\n%s  (porta %d)\nConectados: %d" % [", ".join(ips) if ips.size() > 0 else "127.0.0.1", Net.DEFAULT_PORT, Net.peers().size()]
		else:
			net_lbl.text = "Abra a sala para amigos na mesma rede (ou com redirecionamento de porta) entrarem."
			side.add_child(AW.button("ABRIR SALA ONLINE", func(): ui.host_online(), AW.CYAN.darkened(0.3), 18))
	else:
		net_lbl.text = "Conectado ao host. Aguarde ele começar a partida."
	side.add_child(HSeparator.new())
	if Game.is_host():
		var start := AW.button("COMEÇAR!", func(): Game.request_start(), AW.GREEN, 30, 340)
		start.disabled = players.size() < 2
		side.add_child(start)
		if players.size() < 2:
			side.add_child(AW.label("Mínimo de 2 jogadores (pode ser bot).", 14, AW.ORANGE))
	side.add_child(AW.button("VOLTAR", func(): ui.back_to_menu(), AW.PANEL2, 18, 340))


func _option_row(label_text: String, values: Array, current: int, cb: Callable) -> HBoxContainer:
	var h := AW.hbox(6)
	var l := AW.label(label_text, 16, AW.TEXT, "Bold")
	l.custom_minimum_size.x = 140
	h.add_child(l)
	for v in values:
		var val: int = v
		var b := AW.button(str(val), func(): cb.call(val), AW.PINK if val == current else AW.PANEL2, 16)
		h.add_child(b)
	return h
