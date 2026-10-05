class_name MetaUi
extends Control
## Progressão fora da partida: avisos de conquista e espécie nova, bestiário (TAB),
## objetivos do tutorial e os gatilhos de conquistas que vêm de eventos do jogo.

const TUTORIAL := [
	["cast", "SEGURE e SOLTE o clique para arremessar a linha."],
	["catch", "Quando morder, CLIQUE! Depois segure/solte para manter a tensão no verde."],
	["drive", "Vá ao TIMÃO (E) e pilote para longe da costa: águas fundas = peixes melhores."],
	["sell", "Volte ao PORTO, abra a CAIXA DE PEIXES (E) e VENDA para bater a cota."],
]

var hud: Hud
var toasts: VBoxContainer
var tut_panel: PanelContainer
var tut_lbl: Label
var _step := -1
var _weather := ""


func setup(h: Hud) -> void:
	hud = h
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts = AW.vbox(6)
	toasts.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toasts.offset_right = -18
	toasts.offset_bottom = -90
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)
	tut_panel = AW.panel(Color(AW.BG, 0.8), AW.GREEN, 12)
	tut_panel.position = Vector2(16, 130)
	var tv := AW.vbox(2)
	tut_panel.add_child(tv)
	tv.add_child(AW.label("OBJETIVO", 13, AW.GREEN, "ExtraBold", 2))
	tut_lbl = AW.label("", 16, Color.WHITE, "Bold", 3)
	tut_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_lbl.custom_minimum_size.x = 330
	tv.add_child(tut_lbl)
	tut_panel.visible = false
	add_child(tut_panel)
	Profile.achievement_unlocked.connect(_on_achievement)
	Profile.species_discovered.connect(_on_species)
	Game.catch_announced.connect(_on_catch)
	Game.fx.connect(_on_fx)
	Game.run_changed.connect(_on_run)
	Game.night_ended.connect(_on_night_end)


func start() -> void:
	_step = -1 if bool(Profile.data.get("tutorial_done", false)) else 0
	_refresh_tutorial()


func bind_player(p: PlayerController) -> void:
	p.fishing.state_changed.connect(func(s: String):
		if s == "flying":
			_advance("cast"))


func _process(_d: float) -> void:
	if hud.player and hud.player.driving:
		_advance("drive")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB and Game.in_run():
		if hud.panel_open():
			hud.close_panels()
		else:
			open_bestiary(hud.panel)
		get_viewport().set_input_as_handled()


# --- Tutorial ------------------------------------------------------------------------

func _advance(key: String) -> void:
	if _step < 0 or _step >= TUTORIAL.size() or TUTORIAL[_step][0] != key:
		return
	_step += 1
	Audio.play("click")
	if _step >= TUTORIAL.size():
		_step = -1
		Profile.data.tutorial_done = true
		Profile.save_profile()
		toast("TUTORIAL CONCLUÍDO", "Agora é com você. Cuidado com o que vive no escuro.", AW.GREEN)
	_refresh_tutorial()


func _refresh_tutorial() -> void:
	tut_panel.visible = _step >= 0
	if _step >= 0:
		tut_lbl.text = "%d/%d  %s" % [_step + 1, TUTORIAL.size(), TUTORIAL[_step][1]]
		AW.pop(tut_panel, 1.08, 0.25)


# --- Avisos ------------------------------------------------------------------------

func toast(title: String, desc: String, col: Color) -> void:
	var p := AW.panel(Color(AW.BG, 0.92), col, 12)
	var v := AW.vbox(0)
	p.add_child(v)
	v.add_child(AW.label(title, 18, col, "ExtraBold", 3))
	v.add_child(AW.label(desc, 14, AW.TEXT, "Bold", 2))
	toasts.add_child(p)
	AW.fade_in(p, 0.3, 20)
	var tw := p.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _on_achievement(_id: String, title: String, desc: String) -> void:
	toast("CONQUISTA: " + title, desc, AW.GOLD)
	Audio.play("reveal", -6.0)


func _on_species(id: String) -> void:
	var f := _fish_def(id)
	toast("NOVA ESPÉCIE!", "%s entrou no bestiário (%d/%d). [TAB]" % [f.get("name", id), Profile.bestiary_progress().x, Profile.bestiary_progress().y], AW.CYAN)


# --- Gatilhos ------------------------------------------------------------------------

func _on_catch(pid: int, f: Dictionary) -> void:
	if pid != Game.my_pid():
		return
	Profile.register_catch(f)
	if _weather == "tempestade":
		Profile.unlock("tempestade")
	_advance("catch")


func _on_fx(kind: String, _data: Dictionary) -> void:
	match kind:
		"tentacle_gone":
			Profile.unlock("tentaculo")
		"eyes_gone":
			Profile.unlock("olhos")
		"sink":
			Profile.unlock("naufragio")
		"sold":
			_advance("sell")


func _on_run(r: Dictionary) -> void:
	_weather = str(r.get("weather", ""))
	if str(r.get("zone_id", "")) == "abismo":
		Profile.unlock("abismo")


func _on_night_end(s: Dictionary) -> void:
	if int(s.get("quotas_met", 0)) >= 3:
		Profile.unlock("cota3")
	if int(s.get("earned", 0)) >= 10000:
		Profile.unlock("rico")


# --- Bestiário -----------------------------------------------------------------------

static func _fish_def(id: String) -> Dictionary:
	for f in GameData.load_json("fish").fish:
		if str(f.id) == id:
			return f
	return {}


## Monta o bestiário dentro de `host` (painel do HUD ou modal do menu).
static func open_bestiary(host: Control) -> void:
	AW.clear(host)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	host.get_tree().call_group("dock_ui", "_lock_player")
	var prog := Profile.bestiary_progress()
	var p := AW.panel(Color(AW.BG, 0.96), AW.CYAN, 22)
	p.name = "Bestiary"
	var v := AW.vbox(8)
	p.add_child(v)
	v.add_child(AW.title("BESTIÁRIO", 46, AW.CYAN))
	var ach: Dictionary = Profile.data.achievements
	v.add_child(AW.center(AW.label("Espécies: %d/%d  ·  Peixes pescados: %d  ·  Conquistas: %d/%d" % [prog.x, prog.y, int(Profile.data.total_caught), ach.size(), Profile.ACHIEVEMENTS.size()], 17, AW.GOLD, "Bold", 2)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1060, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	v.add_child(scroll)
	var zones := {"raso": "Águas rasas", "fundo": "Mar fundo", "abismo": "Abismo", "any": "Qualquer lugar"}
	for f in GameData.load_json("fish").fish:
		var e: Dictionary = Profile.data.bestiary.get(str(f.id), {})
		var known := not e.is_empty()
		var rr: Dictionary = FishDB.rarity(str(f.rarity))
		var col := Color(str(rr.color)) if known else AW.MUTED
		var card := AW.panel(Color(AW.PANEL, 0.9), col, 10)
		card.custom_minimum_size = Vector2(250, 92)
		var cv := AW.vbox(0)
		card.add_child(cv)
		cv.add_child(AW.label(str(f.name) if known else "???", 17, col.lightened(0.2), "ExtraBold", 2))
		cv.add_child(AW.label("%s  ·  %s" % [rr.name, zones.get(str(f.zone), "")], 12, col, "Bold"))
		if known:
			cv.add_child(AW.label("Pescados: %d  ·  Recorde: %.1f kg" % [int(e.count), float(e.best_kg)], 12, AW.TEXT, "Bold"))
		else:
			cv.add_child(AW.label("Ainda não pescado.", 12, AW.MUTED))
		grid.add_child(card)
	var achs := AW.label("", 13, AW.TEXT, "Bold")
	var parts: Array[String] = []
	for k in Profile.ACHIEVEMENTS:
		parts.append(("★ " if ach.has(k) else "☆ ") + str(Profile.ACHIEVEMENTS[k][0]))
	achs.text = "   ".join(parts)
	AW.wrap(achs)
	achs.custom_minimum_size.x = 1060
	v.add_child(achs)
	v.add_child(AW.center(AW.label("[TAB] ou [ESC] para fechar", 14, AW.MUTED, "Bold")))
	host.add_child(AW.centered(p))
	p.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
	AW.pop(p, 1.05, 0.25)
