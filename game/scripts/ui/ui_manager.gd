class_name UIManager
extends CanvasLayer
## Orquestra toda a interface: HUD, notificações, celular, janelas de apps, diálogos,
## menu principal, pausa e configurações. Controla o modo do mouse.

const APPS := {
	"apostas": "res://scripts/ui/apps/bets_app.gd",
	"noticias": "res://scripts/ui/apps/news_app.gd",
	"empregos": "res://scripts/ui/apps/jobs_app.gd",
	"banco": "res://scripts/ui/apps/bank_app.gd",
	"admin": "res://scripts/ui/apps/admin_app.gd",
	"objetivos": "res://scripts/ui/apps/missions_app.gd",
	"mensagens": "res://scripts/ui/apps/messages_app.gd",
	"contatos": "res://scripts/ui/apps/contacts_app.gd",
	"mapa": "res://scripts/ui/apps/map_app.gd",
	"home": "res://scripts/ui/apps/home_app.gd",
	"lot": "res://scripts/ui/apps/lot_app.gd",
	"competitor": "res://scripts/ui/apps/competitor_app.gd",
	"online": "res://scripts/ui/apps/online_app.gd",
	"internet": "res://scripts/ui/apps/internet_app.gd",
	"debug": "res://scripts/ui/apps/debug_app.gd",
	"cassino": "res://scripts/ui/apps/casino_app.gd",
}

var root: Control
var hud: Hud
var notifications: Notifications
var phone: Phone
var window: UiWindow
var main_menu: MainMenu
var settings: SettingsPanel
var modal_layer: Control
var current_app: AppBase
var _pause: Control
var _refresh_t := 0.0
var _modal_queue: Array = []
var _modal_open: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vig_layer := CanvasLayer.new()
	vig_layer.layer = 1
	add_child(vig_layer)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	var vs := Shader.new()
	vs.code = "shader_type canvas_item;\nvoid fragment() { vec2 uv = UV - 0.5; float v = smoothstep(0.85, 0.25, length(uv * vec2(1.0, 0.8))); COLOR = vec4(0.0, 0.0, 0.02, (1.0 - v) * 0.55); }"
	vm.shader = vs
	vig.material = vm
	vig_layer.add_child(vig)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.theme()
	add_child(root)
	hud = Hud.new()
	root.add_child(hud)
	notifications = Notifications.new()
	root.add_child(notifications)
	phone = Phone.new()
	root.add_child(phone)
	phone.visible = false
	phone.app_chosen.connect(func(id):
		var mapped := _map_phone_app(id)
		open_app(mapped, "online" if mapped == "cassino" else null))
	window = UiWindow.new()
	root.add_child(window)
	window.visible = false
	window.closed.connect(close_window)
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_layer)
	main_menu = MainMenu.new()
	root.add_child(main_menu)
	main_menu.new_game_requested.connect(_on_new_game)
	main_menu.continue_requested.connect(func():
		if Game.load_game():
			_enter_game())
	main_menu.settings_requested.connect(open_settings)
	main_menu.quit_requested.connect(func(): get_tree().quit())
	settings = SettingsPanel.new()
	root.add_child(settings)
	settings.visible = false
	settings.closed.connect(func(): settings.visible = false)
	var sim := Game.sim
	sim.day_ended.connect(_on_day_ended)
	sim.decision_requested.connect(_on_decision)
	sim.victory_reached.connect(_on_victory)
	sim.went_bankrupt.connect(_on_bankrupt)
	sim.level_up.connect(func(_l, _t): Audio.play("levelup"))
	Game.ui_request.connect(_on_ui_request)
	_show_menu()


func _map_phone_app(id: String) -> String:
	if id == "cassino":
		return "cassino"
	if id == "mercado":
		return "admin:equipment" if Game.sim.has_business() else "admin:properties"
	return id


# --- Estados -----------------------------------------------------------------------

func _show_menu() -> void:
	hud.visible = false
	phone.visible = false
	window.visible = false
	main_menu.visible = true
	main_menu.refresh()
	Audio.play_music()
	Audio.stop_ambient()


func _on_new_game(p_name: String, brand: String) -> void:
	Game.new_game(p_name, brand)
	_enter_game()
	_queue_modal(func(): return Dialogs.message(modal_layer, "BEM-VINDO À CIDADE", [
		"Você tem R$ 100 no bolso. Nada de banca, nada de clientes — ainda.",
		"Aposte com cuidado, faça trabalhos e junte capital para abrir sua primeira banca.",
		"WASD andar  |  SHIFT correr  |  E interagir  |  TAB celular  |  T velocidade do tempo",
		"Siga o feixe de luz dourado: ele aponta para o seu objetivo."], "VAMOS LÁ", func(): _modal_closed(), UiKit.GOLD, 28))


func _enter_game() -> void:
	main_menu.visible = false
	hud.visible = true
	Audio.play_ambient()


func _to_main_menu() -> void:
	get_tree().paused = false
	_close_pause()
	close_window()
	for c in modal_layer.get_children():
		c.queue_free()
	_modal_queue.clear()
	_modal_open = null
	Game.end_session()
	_show_menu()


# --- Apps --------------------------------------------------------------------------

func open_app(id: String, arg: Variant = null) -> void:
	var tab := ""
	if ":" in id:
		tab = id.split(":")[1]
		id = id.split(":")[0]
	if not APPS.has(id) or not ResourceLoader.exists(APPS[id]):
		Game.sim.notify("Este aplicativo estará disponível em uma próxima atualização.", "warning")
		return
	phone.visible = false
	var app: AppBase = load(APPS[id]).new()
	app.ui = self
	app.arg = arg if tab == "" else tab
	current_app = app
	window.visible = true
	refresh()
	window.layout(app.window_size())


var _refreshing := false
var _refresh_again := false


func refresh() -> void:
	if current_app == null:
		return
	if _refreshing:
		_refresh_again = true
		return
	_refreshing = true
	var scroll_v := window.scroll.scroll_vertical
	window.set_title(current_app.title(), current_app.subtitle())
	window.clear_body()
	if current_app:
		current_app.build(window.body)
	_refreshing = false
	if _refresh_again:
		_refresh_again = false
		refresh.call_deferred()
		return
	await get_tree().process_frame
	if is_instance_valid(window):
		window.scroll.scroll_vertical = scroll_v


func close_window() -> void:
	var app := current_app
	window.visible = false
	current_app = null
	if app:
		app.on_close()
	window.clear_body()


func open_settings() -> void:
	settings.visible = true
	settings.layout(Vector2(620, 560))


func _on_ui_request(kind: String, arg: Variant) -> void:
	match kind:
		"bet_shop": open_app("apostas", "ze")
		"jobs": open_app("empregos", arg)
		"app": open_app(str(arg))
		"home": open_app("home")
		"lot": open_app("lot", arg)
		"competitor": open_app("competitor", arg)
		"casino_hall": open_app("cassino", arg)
		"shop": open_app("admin:equipment")
		"admin": open_app("admin", arg)
		_: open_app(kind, arg)


# --- Modais ------------------------------------------------------------------------

func _queue_modal(builder: Callable) -> void:
	_modal_queue.append(builder)
	_next_modal()


func _next_modal() -> void:
	if _modal_open != null or _modal_queue.is_empty():
		return
	var b: Callable = _modal_queue.pop_front()
	Game.hold("modal", true)
	_modal_open = b.call()


func _modal_closed() -> void:
	_modal_open = null
	Game.hold("modal", false)
	_next_modal()


func _on_day_ended(r: Dictionary) -> void:
	Game.stop_sleep()
	_queue_modal(func(): return Dialogs.daily_report(modal_layer, r, func():
		_modal_closed()
		if Settings.get_value("autosave") != false:
			Game.save_game()))


func _on_decision(ev: Dictionary) -> void:
	_queue_modal(func(): return Dialogs.decision(modal_layer, ev, func(i):
		_modal_closed()
		Game.sim.resolve_decision(ev, i)))


func _on_victory() -> void:
	var s := Game.sim
	_queue_modal(func(): return Dialogs.message(modal_layer, "IMPÉRIO CONSTRUÍDO", [
		"Você começou com R$ 100.",
		"Agora administra um império de entretenimento.",
		"Patrimônio: %s  |  Dia %d  |  Nível %d" % [Fmt.money(s.economy.net_worth()), s.time.day, s.progression.level],
		"A campanha terminou, mas a cidade continua. Continue crescendo no modo pós-campanha."], "CONTINUAR JOGANDO", func(): _modal_closed(), UiKit.GOLD, 40))


func _on_bankrupt(info: Dictionary) -> void:
	_queue_modal(func(): return Dialogs.message(modal_layer, "FALÊNCIA", [
		"Seu caixa ficou negativo por tempo demais.",
		"Ativos liquidados: %s. Dívida renegociada: %s." % [Fmt.money(float(info.recovered)), Fmt.money(float(info.remaining_debt))],
		"MODO RECUPERAÇÃO: trabalhos pagam bônus. Você mantém seu nível e sua experiência.",
		"Junte capital e reabra sua banca."], "RECOMEÇAR", func(): _modal_closed(), UiKit.RED))


# --- Pausa ------------------------------------------------------------------------

func _open_pause() -> void:
	if _pause:
		return
	get_tree().paused = true
	_pause = Dialogs.pause_menu(modal_layer, {
		"Continuar": _close_pause,
		"Salvar jogo": func(): Game.save_game(),
		"Carregar jogo": func():
			_close_pause()
			close_window()
			if Game.load_game():
				_enter_game(),
		"Configurações": open_settings,
		"Menu principal": _to_main_menu,
		"Sair do jogo": func(): get_tree().quit(),
	})


func _close_pause() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
	get_tree().paused = false


# --- Entrada e atualização ---------------------------------------------------------

func is_ui_open() -> bool:
	return main_menu.visible or phone.visible or window.visible or settings.visible or _pause != null or _modal_open != null


func _unhandled_input(event: InputEvent) -> void:
	if not Game.playing or main_menu.visible:
		return
	if event.is_action_pressed("pause"):
		if settings.visible:
			settings.visible = false
		elif window.visible:
			close_window()
		elif phone.visible:
			phone.visible = false
		elif _pause:
			_close_pause()
		elif _modal_open == null:
			_open_pause()
		get_viewport().set_input_as_handled()
	elif _pause or _modal_open:
		return
	elif event.is_action_pressed("phone"):
		if window.visible:
			close_window()
		phone.visible = not phone.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("time_speed"):
		Game.cycle_speed()
		Game.sim.notify("Velocidade do tempo: x%d" % int(Game.time_speed()), "info")
	elif event.is_action_pressed("quick_save"):
		Game.save_game()
	elif event.is_action_pressed("quick_load"):
		close_window()
		if Game.load_game():
			_enter_game()
	elif event.is_action_pressed("admin"):
		open_app("admin")
	elif event.is_action_pressed("debug") and Game.debug_enabled():
		open_app("debug")


func _process(delta: float) -> void:
	var want_capture := Game.playing and not is_ui_open()
	var mode := Input.MOUSE_MODE_CAPTURED if want_capture else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode and DisplayServer.get_name() != "headless":
		Input.mouse_mode = mode
	if Game.player and is_instance_valid(Game.player):
		Game.player.input_enabled = want_capture and not Game.sim.jobs.is_shift() and not Game.sleeping
		var t = Game.player.current_target()
		hud.set_prompt(t.get_prompt() if t and want_capture else "")
	if current_app and window.visible and current_app.live():
		_refresh_t -= delta
		if _refresh_t <= 0.0:
			_refresh_t = 1.0
			refresh()
