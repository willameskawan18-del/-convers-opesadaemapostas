class_name Hud
extends Control
## HUD: dinheiro, dia/hora, reputação, nível/XP, objetivo atual, prompt de interação
## e painel compacto da banca quando o jogador tem um negócio.

var money_label: Label
var money_delta: Label
var clock_label: Label
var speed_label: Label
var rep_bar: ProgressBar
var rep_label: Label
var level_label: Label
var xp_bar: ProgressBar
var obj_title: Label
var obj_text: Label
var obj_hint: Label
var obj_bar: ProgressBar
var prompt_panel: PanelContainer
var prompt_label: Label
var biz_panel: PanelContainer
var biz_box: VBoxContainer
var work_panel: PanelContainer
var work_label: Label
var work_bar: ProgressBar
var status_label: Label
var _last_cash := 0.0
var _delta_t := 0.0
var _tick := 0.0


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_left()
	_build_objective()
	_build_prompt()
	_build_business()
	_build_work()
	var help := UiKit.label("[TAB] Celular   [E] Interagir   [SHIFT] Correr   [T] Velocidade   [V] Câmera   [ESC] Pausa", 13, Color(1, 1, 1, 0.55))
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(16, -28)
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_top = -30
	help.offset_left = 16
	add_child(help)
	Game.sim.cash_changed.connect(_on_cash)
	_last_cash = Game.sim.economy.cash


func _panel(pos: Vector2, min_w: float) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.style(Color(0.05, 0.08, 0.15, 0.82), 12, Color(1, 1, 1, 0.07), 1, 12))
	p.position = pos
	p.custom_minimum_size.x = min_w
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	var v := UiKit.vbox(4)
	p.add_child(v)
	return v


func _build_top_left() -> void:
	var v := _panel(Vector2(16, 16), 270)
	var h := UiKit.hbox()
	v.add_child(h)
	money_label = UiKit.label("R$ 0", 30, UiKit.GOLD)
	h.add_child(money_label)
	money_delta = UiKit.label("", 16, UiKit.GREEN)
	h.add_child(money_delta)
	var h2 := UiKit.hbox()
	v.add_child(h2)
	clock_label = UiKit.label("Dia 1", 16)
	h2.add_child(UiKit.expand(clock_label))
	speed_label = UiKit.label("x1", 14, UiKit.MUTED)
	h2.add_child(speed_label)
	rep_label = UiKit.label("Reputação", 13, UiKit.MUTED)
	v.add_child(rep_label)
	rep_bar = UiKit.bar(50, 100, UiKit.BLUE, 6)
	v.add_child(rep_bar)
	level_label = UiKit.label("Nível 1", 13, UiKit.MUTED)
	v.add_child(level_label)
	xp_bar = UiKit.bar(0, 1, UiKit.GOLD, 6)
	v.add_child(xp_bar)
	status_label = UiKit.label("", 13, UiKit.ORANGE)
	v.add_child(status_label)


func _build_objective() -> void:
	var v := _panel(Vector2(16, 230), 300)
	obj_title = UiKit.label("", 13, UiKit.GOLD)
	v.add_child(obj_title)
	obj_text = UiKit.label("", 17, UiKit.TEXT, true)
	obj_text.custom_minimum_size.x = 280
	v.add_child(obj_text)
	obj_bar = UiKit.bar(0, 1, UiKit.GREEN, 6)
	v.add_child(obj_bar)
	obj_hint = UiKit.label("", 13, UiKit.MUTED, true)
	obj_hint.custom_minimum_size.x = 280
	v.add_child(obj_hint)


func _build_prompt() -> void:
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", UiKit.style(Color(0.05, 0.08, 0.15, 0.9), 10, UiKit.GOLD.darkened(0.2), 1, 12))
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_panel)
	prompt_label = UiKit.label("", 18)
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false


func _build_business() -> void:
	biz_panel = PanelContainer.new()
	biz_panel.add_theme_stylebox_override("panel", UiKit.style(Color(0.05, 0.08, 0.15, 0.82), 12, Color(1, 1, 1, 0.07), 1, 12))
	biz_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	biz_panel.custom_minimum_size.x = 250
	add_child(biz_panel)
	biz_box = UiKit.vbox(3)
	biz_panel.add_child(biz_box)
	biz_panel.visible = false


func _build_work() -> void:
	work_panel = PanelContainer.new()
	work_panel.add_theme_stylebox_override("panel", UiKit.style(Color(0.05, 0.08, 0.15, 0.92), 12, UiKit.BLUE, 1, 16))
	work_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(work_panel)
	var v := UiKit.vbox(6)
	work_panel.add_child(v)
	work_label = UiKit.label("", 20, UiKit.TEXT)
	v.add_child(work_label)
	work_bar = UiKit.bar(0, 1, UiKit.BLUE, 12)
	work_bar.custom_minimum_size.x = 360
	v.add_child(work_bar)
	work_panel.visible = false


func _on_cash(c: float) -> void:
	var d := c - _last_cash
	_last_cash = c
	if absf(d) < 0.5:
		return
	money_delta.text = Fmt.signed_money(d)
	money_delta.add_theme_color_override("font_color", UiKit.money_color(d))
	_delta_t = 2.0


func set_prompt(text: String) -> void:
	prompt_panel.visible = text != ""
	if text != "":
		prompt_label.text = "[E]  " + text


func _process(delta: float) -> void:
	var sim := Game.sim
	money_label.text = Fmt.money(sim.economy.cash)
	money_label.add_theme_color_override("font_color", UiKit.GOLD if sim.economy.cash >= 0 else UiKit.RED)
	if _delta_t > 0.0:
		_delta_t -= delta
		money_delta.modulate.a = clampf(_delta_t, 0.0, 1.0)
	clock_label.text = "Dia %d (%s)  %s" % [sim.time.day, sim.time.weekday_name(), sim.time.clock_text()]
	speed_label.text = "TRABALHANDO" if sim.jobs.is_shift() else ("DORMINDO" if Game.sleeping else "x%d" % int(Game.time_speed()))
	var vs := get_viewport_rect().size
	prompt_panel.position = Vector2((vs.x - prompt_panel.size.x) / 2.0, vs.y - 120)
	work_panel.position = Vector2((vs.x - work_panel.size.x) / 2.0, vs.y * 0.3)
	biz_panel.position = Vector2(vs.x - biz_panel.size.x - 16, vs.y - biz_panel.size.y - 40)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	rep_bar.value = sim.reputation.value
	rep_label.text = "Reputação: %d (%s)" % [int(sim.reputation.value), sim.reputation.label()]
	level_label.text = "Nível %d — %s   (%d/%d XP)" % [sim.progression.level, sim.progression.title(), sim.progression.xp, sim.progression.xp_to_next()]
	xp_bar.max_value = sim.progression.xp_to_next()
	xp_bar.value = sim.progression.xp
	var st := ""
	if sim.recovery_mode:
		st = "MODO RECUPERAÇÃO"
	if sim.loans.total_debt() > 0:
		st += ("   " if st != "" else "") + "Dívida: " + Fmt.money(sim.loans.total_debt())
	status_label.text = st
	status_label.visible = st != ""
	_update_objective()
	_update_work()
	_update_business()


func _update_objective() -> void:
	var sim := Game.sim
	var ch := sim.missions.chapter()
	if sim.missions.is_campaign_over():
		obj_title.text = "PÓS-CAMPANHA"
		obj_text.text = "Continue expandindo seu império."
		obj_bar.visible = false
		obj_hint.visible = false
		return
	obj_title.text = str(ch.get("title", "")).to_upper()
	var o := sim.missions.current_objective()
	if o.is_empty():
		return
	obj_text.text = "OBJETIVO: " + str(o.text)
	var p := sim.missions.progress(o)
	obj_bar.visible = float(p[1]) > 1.0
	obj_bar.max_value = maxf(float(p[1]), 0.001)
	obj_bar.value = clampf(float(p[0]), 0.0, float(p[1]))
	obj_hint.visible = sim.missions.hints_enabled and o.has("hint")
	obj_hint.text = str(o.get("hint", ""))


func _update_work() -> void:
	var sim := Game.sim
	var a: Dictionary = sim.jobs.active
	if a.is_empty() or a.type != "shift":
		work_panel.visible = false
		return
	work_panel.visible = true
	var total := float(int(a.end) - int(a.started))
	var done := float(sim.time.abs_minute() - int(a.started))
	work_label.text = "Trabalhando: %s   (+%s)" % [a.name, Fmt.money(float(a.reward))]
	work_bar.max_value = maxf(total, 1.0)
	work_bar.value = done


func _update_business() -> void:
	var sim := Game.sim
	if not sim.has_business():
		biz_panel.visible = false
		return
	biz_panel.visible = true
	for c in biz_box.get_children():
		c.queue_free()
	var b = sim.business
	biz_box.add_child(UiKit.label(sim.brand_name.to_upper(), 15, UiKit.GOLD))
	var open_txt := "ABERTA" if b.is_open() else "FECHADA"
	if b.is_open() and not b.can_take_bets():
		open_txt = "SEM SISTEMA"
	UiKit.kv(biz_box, "Status", open_txt, UiKit.GREEN if open_txt == "ABERTA" else UiKit.RED)
	UiKit.kv(biz_box, "Fila / no local", "%d / %d (máx %d)" % [sim.customers.queue_length(), sim.customers.inside_count(), b.capacity()])
	UiKit.kv(biz_box, "Atendendo", "%d guichê(s)%s" % [sim.customers.active_servers(), "  + VOCÊ" if sim.player_at_counter else ""])
	var ex := sim.betting.total_exposure()
	var risk := sim.betting.risk_level(ex.worst_net)
	UiKit.kv(biz_box, "Exposição", Fmt.money(ex.worst_net))
	UiKit.kv(biz_box, "Risco", risk, UiKit.risk_color(risk))
	UiKit.kv(biz_box, "Lucro hoje", Fmt.money(sim.economy.business_profit_today()), UiKit.money_color(sim.economy.business_profit_today()))
