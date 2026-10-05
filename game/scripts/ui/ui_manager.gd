class_name UIManager
extends Control
## Troca de telas (menu → lobby → partida → resultado) e janelas modais.

var arena: Arena
var director: ShowDirector
var screen_root: Control
var hud: Hud
var overlay: PhaseOverlay
var decision: DecisionPanel
var results: ResultsScreen
var modal_root: Control
var fade: ColorRect
var _current := ""
var _pause_dlg: Control
var _join_dlg: Control
var _pending_join_name := ""


func _ready() -> void:
	theme = AW.theme()
	AW.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_root = Control.new()
	AW.full_rect(screen_root)
	screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_root)
	overlay = PhaseOverlay.new()
	add_child(overlay)
	hud = Hud.new()
	add_child(hud)
	decision = DecisionPanel.new()
	add_child(decision)
	results = ResultsScreen.new()
	results.ui = self
	add_child(results)
	modal_root = Control.new()
	AW.full_rect(modal_root)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_root)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	AW.full_rect(fade)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	Game.view_changed.connect(_sync_mode)
	Game.returned_to_menu.connect(func(): _show("menu"))
	Game.phase_changed.connect(_on_phase)
	Game.error_message.connect(func(t): Dialogs.toast(modal_root, t))
	Net.connected_to_host.connect(_on_connected)
	Net.upnp_finished.connect(func(ok: bool, ip: String):
		if ok:
			Dialogs.toast(modal_root, "Porta aberta! IP para seu amigo: " + ip, AW.GREEN)
		else:
			Dialogs.toast(modal_root, "O roteador não abriu a porta. Use a Radmin VPN (veja o LEIA-ME).", AW.ORANGE))
	Net.connection_failed.connect(func():
		Dialogs.toast(modal_root, "Não foi possível conectar ao host.", AW.RED)
		if _join_dlg and is_instance_valid(_join_dlg):
			var st := _join_dlg.find_child("Status", true, false) as Label
			if st:
				st.text = "Falhou. Confira o IP e se o host abriu a sala.")
	_show("menu")
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.8)


func _transition(cb: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.18)
	tw.tween_callback(cb)
	tw.tween_property(fade, "color:a", 0.0, 0.3)


func _show(screen_name: String) -> void:
	if _current == screen_name and screen_name != "menu":
		return
	_current = screen_name
	_transition(func(): _build(screen_name))


func _build(screen_name: String) -> void:
	AW.clear(screen_root)
	AW.clear(results)
	overlay.clear()
	hud.visible = screen_name == "match"
	decision.visible = false
	match screen_name:
		"menu":
			var m := MainMenu.new()
			m.ui = self
			screen_root.add_child(m)
			director.show_menu()
		"lobby":
			var l := LobbyScreen.new()
			l.ui = self
			screen_root.add_child(l)
			director.show_lobby()
		"match":
			hud.rebuild()


func _sync_mode() -> void:
	var mode := str(Game.view.get("mode", "menu"))
	if mode == "lobby" and _current != "lobby":
		_show("lobby")
	elif mode == "match" and _current != "match":
		_show("match")


func _on_phase(phase: String, info: Dictionary) -> void:
	if _current != "match":
		_current = "match"
		_build("match")
	hud.visible = phase != "final"
	if phase == "final":
		results.show_summary(info)
	else:
		AW.clear(results)


# --- Ações do menu ---------------------------------------------------------------

func quick_play() -> void:
	Game.new_local_session()
	var nm := str(Profile.data.get("last_name", ""))
	Game.request_add_player(nm.to_upper() if nm != "" else "VOCÊ", str(Profile.data.get("last_character", "sortudo")), false)
	for i in 3:
		Game.request_add_player("", "", true)
	Game.request_start()


func open_lobby() -> void:
	Game.new_local_session()
	var nm := str(Profile.data.get("last_name", ""))
	Game.request_add_player(nm.to_upper() if nm != "" else "JOGADOR 1", str(Profile.data.get("last_character", "sortudo")), false)


func host_online() -> void:
	var err := Net.host()
	if err != OK:
		Dialogs.toast(modal_root, "Não foi possível abrir a sala (porta %d em uso?)." % Net.DEFAULT_PORT, AW.RED)
		return
	# os jogadores locais continuam como dono = host (peer 1)
	Game._broadcast_view()
	Dialogs.toast(modal_root, "Sala aberta! Passe o IP para seus amigos.", AW.GREEN)


func open_join() -> void:
	_join_dlg = Dialogs.join(modal_root, func(ip: String, nm: String):
		_pending_join_name = nm.strip_edges().to_upper()
		if _pending_join_name == "":
			_pending_join_name = "CONVIDADO"
		Profile.remember_player(nm, str(Profile.data.get("last_character", "sortudo")))
		if Net.join(ip) != OK:
			Dialogs.toast(modal_root, "Endereço inválido.", AW.RED))


func _on_connected() -> void:
	if _join_dlg and is_instance_valid(_join_dlg):
		_join_dlg.queue_free()
	Game.request_add_player(_pending_join_name, str(Profile.data.get("last_character", "sortudo")), false)


func open_how_to() -> void:
	Dialogs.how_to(modal_root)


func open_settings() -> void:
	Dialogs.settings(modal_root)


func back_to_menu() -> void:
	if _pause_dlg and is_instance_valid(_pause_dlg):
		_pause_dlg.queue_free()
	Game.leave_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if modal_root.get_child_count() > 0:
			var last := modal_root.get_child(modal_root.get_child_count() - 1)
			if last is ColorRect:
				last.queue_free()
				get_viewport().set_input_as_handled()
				return
		if _current == "match":
			_pause_dlg = Dialogs.pause(modal_root, func(): _pause_dlg.queue_free(), back_to_menu, open_settings)
			get_viewport().set_input_as_handled()
		elif _current == "lobby":
			back_to_menu()
