class_name UIManager
extends Control
## Telas: menu → lobby → expedição (HUD, pesca, porto, resumos) e janelas.

var director: Node
var screen_root: Control
var hud: Hud
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
	hud = Hud.new()
	hud.ui = self
	add_child(hud)
	hud.visible = false
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
	Game.error_message.connect(func(t): Dialogs.toast(modal_root, t))
	Net.connected_to_host.connect(_on_connected)
	Net.connection_failed.connect(func(): Dialogs.toast(modal_root, "Não foi possível conectar ao host.", AW.RED))
	Net.upnp_finished.connect(func(ok: bool, ip: String):
		Dialogs.toast(modal_root, ("Porta aberta! IP: " + ip) if ok else "O roteador não abriu a porta. Use a Radmin VPN.", AW.GREEN if ok else AW.ORANGE))
	_show("menu")
	create_tween().tween_property(fade, "color:a", 0.0, 0.8)


func _show(screen_name: String) -> void:
	if _current == screen_name and screen_name != "menu":
		return
	_current = screen_name
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.18)
	tw.tween_callback(func(): _build(screen_name))
	tw.tween_property(fade, "color:a", 0.0, 0.35)


func _build(screen_name: String) -> void:
	AW.clear(screen_root)
	hud.visible = screen_name == "run"
	match screen_name:
		"menu":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var m := MainMenu.new()
			m.ui = self
			screen_root.add_child(m)
			director.show_menu()
		"lobby":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			var l := LobbyScreen.new()
			l.ui = self
			screen_root.add_child(l)
			director.show_menu()
		"run":
			director.start_run()
			hud.start()


func _sync_mode() -> void:
	var mode := str(Game.view.get("mode", "menu"))
	if mode == "lobby" and _current != "lobby":
		_show("lobby")
	elif mode == "run" and _current != "run":
		_show("run")


func quick_play(continue_run: bool = false) -> void:
	Game.new_local_session()
	var nm := str(Profile.data.get("last_name", ""))
	Game.request("add_player", [nm.to_upper() if nm != "" else "CAPITÃO", str(Profile.data.get("last_character", "sortudo"))])
	Game.request("start", [continue_run])


func open_bestiary() -> void:
	var holder := Control.new()
	AW.full_rect(holder)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	AW.full_rect(dim)
	modal_root.add_child(dim)
	modal_root.add_child(holder)
	holder.tree_exited.connect(func():
		if is_instance_valid(dim):
			dim.queue_free())
	MetaUi.open_bestiary(holder)


func open_lobby() -> void:
	Game.new_local_session()
	var nm := str(Profile.data.get("last_name", ""))
	Game.request("add_player", [nm.to_upper() if nm != "" else "CAPITÃO", str(Profile.data.get("last_character", "sortudo"))])


func host_online() -> void:
	if Net.host() != OK:
		Dialogs.toast(modal_root, "Não foi possível abrir a sala (porta %d em uso?)." % Net.DEFAULT_PORT, AW.RED)
		return
	Game._broadcast_view()


func open_join() -> void:
	_join_dlg = Dialogs.join(modal_root, func(ip: String, nm: String):
		_pending_join_name = nm.strip_edges().to_upper()
		if _pending_join_name == "":
			_pending_join_name = "MARUJO"
		Profile.remember_player(nm, str(Profile.data.get("last_character", "sortudo")))
		if Net.join(ip) != OK:
			Dialogs.toast(modal_root, "Endereço inválido.", AW.RED))


func _on_connected() -> void:
	if _join_dlg and is_instance_valid(_join_dlg):
		_join_dlg.queue_free()
	Game.request("add_player", [_pending_join_name, str(Profile.data.get("last_character", "sortudo"))])


func open_how_to() -> void:
	Dialogs.how_to(modal_root)


func open_settings() -> void:
	Dialogs.settings(modal_root)


func back_to_menu() -> void:
	if _pause_dlg and is_instance_valid(_pause_dlg):
		_pause_dlg.queue_free()
	Game.leave_to_menu()


func modal_open() -> bool:
	return modal_root.get_child_count() > 0 or hud.panel_open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if hud.panel_open():
			hud.close_panels()
			get_viewport().set_input_as_handled()
			return
		if modal_root.get_child_count() > 0:
			modal_root.get_child(modal_root.get_child_count() - 1).queue_free()
			if _current == "run":
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
		if _current == "run":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_pause_dlg = Dialogs.pause(modal_root, func():
				_pause_dlg.queue_free()
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED, back_to_menu, open_settings)
			get_viewport().set_input_as_handled()
		elif _current == "lobby":
			back_to_menu()
