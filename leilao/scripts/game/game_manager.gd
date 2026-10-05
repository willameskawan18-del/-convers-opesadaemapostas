extends Node
## GameManager (autoload "Game"). O host roda a partida (MatchFlow) e publica eventos;
## todas as máquinas aplicam os eventos no espelho `view` e emitem sinais para a interface.

signal view_changed
signal phase_changed(phase: String, info: Dictionary)
signal money_changed(pid: int, old_value: int, new_value: int, reason: String)
signal auction_changed(state: Dictionary)
signal step(data: Dictionary)
signal private_info_received(pid: int, info: Dictionary)
signal submissions_changed(submitted: Array)
signal match_ended(summary: Dictionary)
signal returned_to_menu
signal error_message(text: String)

const START_MONEY := 5000
const EVENTS := ["view", "phase", "money", "auction", "step", "private", "submitted", "ended", "menu", "error"]
const REQUESTS := ["add_player", "remove_player", "set_character", "set_config", "start_match", "bid", "submit", "rematch", "to_lobby"]

var view: Dictionary = {"mode": "menu", "players": [], "phase": "", "phase_info": {}, "config": {}, "submitted": [], "auction": {}}
var private_infos: Dictionary = {}
var last_summary: Dictionary = {}
var clock := 0.0
var deadline := -1.0
var auction_deadline := -1.0

var players := Players.new()
var rng := RandomNumberGenerator.new()
var config := {"days": 5, "units_per_day": 3}
var flow: MatchFlow
var token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	flow = MatchFlow.new()
	flow.name = "MatchFlow"
	add_child(flow)
	Net.peer_left.connect(_on_peer_left)
	Net.connected_to_host.connect(func(): view = {"mode": "lobby", "players": [], "phase": "", "phase_info": {}, "config": {}, "submitted": [], "auction": {}})
	Net.disconnected_from_host.connect(func():
		_local_menu()
		error_message.emit("Conexão com o host perdida."))


func _process(delta: float) -> void:
	clock += delta
	if is_host():
		flow.tick()


# --- Consultas -------------------------------------------------------------------

func is_host() -> bool:
	return Net.is_host()


func my_peer() -> int:
	return Net.my_id()


func player_view(pid: int) -> Dictionary:
	for p in view.get("players", []):
		if int(p.id) == pid:
			return p
	return {}


func local_players() -> Array:
	return view.get("players", []).filter(func(p): return int(p.owner_peer) == my_peer() and not bool(p.is_bot))


func ranking_view() -> Array:
	var r: Array = view.get("players", []).duplicate()
	r.sort_custom(func(a, b): return int(a.money) > int(b.money))
	return r


func time_left() -> float:
	return maxf(0.0, deadline - clock) if deadline >= 0.0 else 0.0


func auction_left() -> float:
	return maxf(0.0, auction_deadline - clock) if auction_deadline >= 0.0 else 0.0


func has_submitted(pid: int) -> bool:
	return view.get("submitted", []).has(pid)


## Incremento mínimo do lance conforme o preço.
static func min_increment(price: int) -> int:
	if price < 2000:
		return 100
	if price < 6000:
		return 250
	return 500


# --- Ações (qualquer máquina → host) ---------------------------------------------

func new_local_session() -> void:
	Net.close()
	_reset_model()
	view = {"mode": "lobby", "players": [], "phase": "", "phase_info": {}, "config": config.duplicate(), "submitted": [], "auction": {}}
	_broadcast_view()


func request_add_player(n: String, c: String, bot: bool = false) -> void:
	_request("add_player", [n, c, bot])


func request_remove_player(pid: int) -> void:
	_request("remove_player", [pid])


func request_set_character(pid: int, c: String) -> void:
	_request("set_character", [pid, c])


func request_set_config(k: String, v: Variant) -> void:
	_request("set_config", [k, v])


func request_start() -> void:
	_request("start_match", [])


func bid(pid: int, amount: int) -> void:
	_request("bid", [pid, amount])


func submit_action(pid: int, action: Dictionary) -> void:
	_request("submit", [pid, action])


func request_rematch() -> void:
	_request("rematch", [])


func request_lobby() -> void:
	_request("to_lobby", [])


func leave_to_menu() -> void:
	if is_host() and Net.is_online():
		_emit("menu", [])
	Net.close()
	_local_menu()


func _local_menu() -> void:
	_reset_model()
	view = {"mode": "menu", "players": [], "phase": "", "phase_info": {}, "config": {}, "submitted": [], "auction": {}}
	private_infos.clear()
	deadline = -1.0
	auction_deadline = -1.0
	returned_to_menu.emit()
	view_changed.emit()


func _request(method: String, args: Array) -> void:
	if is_host():
		_handle(my_peer(), method, args)
	else:
		_rpc_request.rpc_id(1, method, args)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(method: String, args: Array) -> void:
	if is_host():
		_handle(multiplayer.get_remote_sender_id(), method, args)


func _handle(sender: int, method: String, args: Array) -> void:
	if not REQUESTS.has(method):
		return
	match method:
		"add_player": _srv_add(sender, str(args[0]), str(args[1]), bool(args[2]))
		"remove_player": _srv_remove(sender, int(args[0]))
		"set_character": _srv_char(sender, int(args[0]), str(args[1]))
		"set_config":
			if sender == 1 and _in_lobby() and str(args[0]) == "days":
				config.days = clampi(int(args[1]), 2, 8)
				_broadcast_view()
		"start_match":
			if sender == 1 and _in_lobby():
				if players.list.size() < 1:
					return
				Net.set_lobby_open(false)
				_begin()
		"bid":
			var p := players.get_p(int(args[0]))
			if p and p.owner_peer == sender and not p.is_bot:
				flow.try_bid(p.id, int(args[1]))
		"submit":
			var p2 := players.get_p(int(args[0]))
			if p2 and p2.owner_peer == sender and not p2.is_bot and args[1] is Dictionary:
				flow.submit(p2.id, args[1])
		"rematch":
			if sender == 1 and str(view.get("phase", "")) == "final":
				_begin()
		"to_lobby":
			if sender == 1:
				token += 1
				view.mode = "lobby"
				view.phase = ""
				Net.set_lobby_open(true)
				_broadcast_view()


func _reset_model() -> void:
	token += 1
	players.clear()


func _in_lobby() -> bool:
	return str(view.get("mode", "")) == "lobby"


func _free_char(pref: String) -> String:
	var used := players.used_characters()
	if pref != "" and not used.has(pref):
		return pref
	for c in GameData.characters():
		if not used.has(c.id):
			return c.id
	return "rico"


func _srv_add(sender: int, n: String, c: String, bot: bool) -> void:
	if not _in_lobby() or (bot and sender != 1):
		return
	if players.list.size() >= Players.MAX:
		_emit_to(sender, "error", ["A partida já tem 6 compradores."])
		return
	if bot:
		var names := ["SEU JORGE", "DONA CIDA", "BARÃO", "TONHÃO", "MARILDA", "ZÉ DO FERRO", "LULU", "DR. SILVA"].filter(func(x): return not players.list.any(func(p): return p.name == x))
		n = names[rng.randi_range(0, names.size() - 1)]
	players.add(n, _free_char(c), bot, sender)
	_broadcast_view()


func _srv_remove(sender: int, pid: int) -> void:
	var p := players.get_p(pid)
	if p and _in_lobby() and (sender == 1 or p.owner_peer == sender):
		players.remove(pid)
		_broadcast_view()


func _srv_char(sender: int, pid: int, c: String) -> void:
	var p := players.get_p(pid)
	if p == null or not _in_lobby() or (sender != 1 and p.owner_peer != sender):
		return
	for o in players.list:
		if o.character == c:
			o.character = p.character
	p.character = c
	_broadcast_view()


func _begin() -> void:
	token += 1
	for p in players.list:
		p.reset()
	view.mode = "match"
	flow.run(token)


func _on_peer_left(peer: int) -> void:
	if not is_host():
		return
	for p in players.owned_by(peer):
		if _in_lobby():
			players.remove(p.id)
		else:
			p.connected = false
	_broadcast_view()


# --- Eventos (host → todos) ------------------------------------------------------

func build_view() -> Dictionary:
	var v := view.duplicate()
	v.players = players.to_array()
	v.config = config.duplicate()
	return v


func _broadcast_view() -> void:
	_emit("view", [build_view()])


func _emit(ev: String, args: Array) -> void:
	_apply(ev, args)
	if Net.is_online():
		_rpc_event.rpc(ev, args)


func _emit_to(peer: int, ev: String, args: Array) -> void:
	if peer == my_peer():
		_apply(ev, args)
	elif Net.is_online() and Net.has_peer(peer):
		_rpc_event.rpc_id(peer, ev, args)


func send_private(pid: int, info: Dictionary) -> void:
	var p := players.get_p(pid)
	if p and not p.is_bot:
		_emit_to(p.owner_peer, "private", [pid, info])


@rpc("authority", "call_remote", "reliable")
func _rpc_event(ev: String, args: Array) -> void:
	if EVENTS.has(ev):
		_apply(ev, args)


func _apply(ev: String, args: Array) -> void:
	match ev:
		"view":
			if is_host():
				view = args[0]
			else:
				view.merge(args[0], true)
			view_changed.emit()
		"phase":
			view.phase = str(args[0])
			view.phase_info = args[1]
			view.submitted = []
			var dl := float(args[1].get("deadline_in", -1.0))
			deadline = clock + dl if dl >= 0.0 else -1.0
			phase_changed.emit(view.phase, view.phase_info)
		"money":
			var pid := int(args[0])
			for p in view.get("players", []):
				if int(p.id) == pid:
					p.money = int(args[2])
			money_changed.emit(pid, int(args[1]), int(args[2]), str(args[3]))
		"auction":
			view.auction = args[0]
			auction_deadline = clock + float(args[0].get("ends_in", 0.0))
			auction_changed.emit(view.auction)
		"step":
			step.emit(args[0])
		"private":
			private_infos[int(args[0])] = args[1]
			private_info_received.emit(int(args[0]), args[1])
		"submitted":
			view.submitted = args[0]
			submissions_changed.emit(view.submitted)
		"ended":
			last_summary = args[0]
			Profile.record_match(last_summary, my_peer())
			match_ended.emit(last_summary)
		"menu":
			Net.close()
			_local_menu()
			error_message.emit("O host encerrou a partida.")
		"error":
			error_message.emit(str(args[0]))
