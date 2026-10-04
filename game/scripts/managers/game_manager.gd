extends Node
## GameManager (autoload "Game"). Ponte entre a lógica da partida (só no servidor/host)
## e a apresentação (em todas as máquinas).
##
## • Todas as ações dos jogadores entram por request_* / submit_action. No host elas são
##   executadas direto; nos clientes viram RPC para o host, que valida quem é o dono.
## • O host publica eventos (_emit). Cada máquina aplica o evento no seu espelho `view`
##   e dispara os sinais abaixo — a interface só escuta sinais e lê `view`.
## • Jogando sozinho/local, o "host" é esta máquina (OfflineMultiplayerPeer).

signal view_changed
signal phase_changed(phase: String, info: Dictionary)
signal money_changed(pid: int, old_value: int, new_value: int, reason: String)
signal reveal_step(step: Dictionary)
signal private_info_received(pid: int, info: Dictionary)
signal submissions_changed(submitted: Array)
signal match_ended(summary: Dictionary)
signal returned_to_menu
signal error_message(text: String)

const START_MONEY := 1000
const EVENTS := ["view", "phase", "money", "step", "private", "submitted", "ended", "menu", "error"]
const REQUESTS := ["add_player", "remove_player", "set_character", "set_config", "start_match", "submit", "rematch", "to_lobby"]

# --- Espelho (todas as máquinas) ---
var view: Dictionary = {"mode": "menu", "players": [], "phase": "", "phase_info": {}, "round": 0, "total_rounds": 0, "config": {}, "submitted": []}
var private_infos: Dictionary = {}   # pid -> info (só dos jogadores desta máquina)
var last_summary: Dictionary = {}
var clock := 0.0                    # relógio local (escala com Engine.time_scale)
var deadline := -1.0                # fim da decisão atual no relógio local

# --- Modelo (só no host) ---
var pm := PlayerManager.new()
var money := MoneyManager.new(pm)
var mm := MinigameManager.new()
var rounds := RoundManager.new()
var ctx := MatchContext.new()
var config := {"rounds": 8, "decision_time": 20.0}
var challenge: Challenge
var runner: MatchRunner
var token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ctx.pm = pm
	ctx.money = money
	ctx.rng.randomize()
	money.money_changed.connect(func(pid, o, n, reason): _emit("money", [pid, o, n, reason]))
	runner = MatchRunner.new()
	runner.name = "MatchRunner"
	add_child(runner)
	Net.peer_left.connect(_on_peer_left)
	Net.connected_to_host.connect(func(): view = {"mode": "lobby", "players": [], "phase": "", "phase_info": {}, "config": {}, "submitted": []})
	Net.disconnected_from_host.connect(func():
		_local_menu()
		error_message.emit(tr("Conexão com o host perdida.")))


func _process(delta: float) -> void:
	clock += delta
	if is_host():
		runner.tick()


# =============================================================================
# Consultas (todas as máquinas)
# =============================================================================

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
	r.sort_custom(func(a, b):
		if int(a.money) != int(b.money):
			return int(a.money) > int(b.money)
		return int(a.id) < int(b.id))
	return r


func position_in_view(pid: int) -> int:
	var me := player_view(pid)
	var pos := 1
	for p in view.get("players", []):
		if int(p.money) > int(me.get("money", 0)):
			pos += 1
	return pos


func time_left() -> float:
	return maxf(0.0, deadline - clock) if deadline >= 0.0 else 0.0


func has_submitted(pid: int) -> bool:
	return view.get("submitted", []).has(pid)


# =============================================================================
# Ações (qualquer máquina → host)
# =============================================================================

func new_local_session() -> void:
	Net.close()
	_reset_model()
	view = {"mode": "lobby", "players": [], "phase": "", "phase_info": {}, "round": 0, "total_rounds": 0, "config": config.duplicate(), "submitted": []}
	_broadcast_view()


func request_add_player(player_name: String, character: String, is_bot: bool = false) -> void:
	_request("add_player", [player_name, character, is_bot])


func request_remove_player(pid: int) -> void:
	_request("remove_player", [pid])


func request_set_character(pid: int, character: String) -> void:
	_request("set_character", [pid, character])


func request_set_config(key: String, value: Variant) -> void:
	_request("set_config", [key, value])


func request_start() -> void:
	_request("start_match", [])


func submit_action(pid: int, action: Dictionary) -> void:
	_request("submit", [pid, action])


func request_rematch() -> void:
	_request("rematch", [])


func request_lobby() -> void:
	_request("to_lobby", [])


## Sai da partida/lobby e volta ao menu (encerra a conexão).
func leave_to_menu() -> void:
	if is_host() and Net.is_online():
		_emit("menu", [])
	token += 1
	Net.close()
	_local_menu()


func _local_menu() -> void:
	token += 1
	_reset_model()
	view = {"mode": "menu", "players": [], "phase": "", "phase_info": {}, "config": {}, "submitted": []}
	private_infos.clear()
	deadline = -1.0
	returned_to_menu.emit()
	view_changed.emit()


func _request(method: String, args: Array) -> void:
	if is_host():
		_handle_request(my_peer(), method, args)
	else:
		_rpc_request.rpc_id(1, method, args)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(method: String, args: Array) -> void:
	if not is_host():
		return
	_handle_request(multiplayer.get_remote_sender_id(), method, args)


func _handle_request(sender: int, method: String, args: Array) -> void:
	if not REQUESTS.has(method):
		return
	match method:
		"add_player": _srv_add_player(sender, str(args[0]), str(args[1]), bool(args[2]))
		"remove_player": _srv_remove_player(sender, int(args[0]))
		"set_character": _srv_set_character(sender, int(args[0]), str(args[1]))
		"set_config": _srv_set_config(sender, str(args[0]), args[1])
		"start_match": _srv_start(sender)
		"submit": _srv_submit(sender, int(args[0]), args[1] if args[1] is Dictionary else {})
		"rematch": _srv_rematch(sender)
		"to_lobby": _srv_to_lobby(sender)


# =============================================================================
# Host: lobby
# =============================================================================

func _reset_model() -> void:
	token += 1
	pm.clear()
	money.history.clear()
	challenge = null
	view["phase"] = ""


func _in_lobby() -> bool:
	return str(view.get("mode", "")) == "lobby"


func _free_character(preferred: String) -> String:
	var used := pm.used_characters()
	if preferred != "" and not used.has(preferred):
		return preferred
	for c in GameData.characters():
		if not used.has(c.id):
			return c.id
	return preferred if preferred != "" else "sortudo"


func _srv_add_player(sender: int, player_name: String, character: String, is_bot: bool) -> void:
	if not _in_lobby():
		return
	if is_bot and sender != 1:
		return
	if pm.is_full():
		_emit_to(sender, "error", [tr("A partida já tem 8 jogadores.")])
		return
	if is_bot:
		var names := GameData.bot_names().filter(func(n): return not pm.players.any(func(p): return p.name == n))
		player_name = names[ctx.rng.randi_range(0, names.size() - 1)] if names.size() > 0 else "BOT"
	pm.add(player_name, _free_character(character), is_bot, sender)
	_broadcast_view()


func _srv_remove_player(sender: int, pid: int) -> void:
	var p := pm.get_player(pid)
	if p == null or not _in_lobby():
		return
	if sender != 1 and p.owner_peer != sender:
		return
	pm.remove(pid)
	_broadcast_view()


func _srv_set_character(sender: int, pid: int, character: String) -> void:
	var p := pm.get_player(pid)
	if p == null or not _in_lobby() or (sender != 1 and p.owner_peer != sender):
		return
	if pm.used_characters().has(character) and p.character != character:
		# troca com quem estava usando
		for o in pm.players:
			if o.character == character:
				o.character = p.character
	p.character = character
	_broadcast_view()


func _srv_set_config(sender: int, key: String, value: Variant) -> void:
	if sender != 1 or not _in_lobby():
		return
	match key:
		"rounds": config.rounds = clampi(int(value), 3, 15)
		"decision_time": config.decision_time = clampf(float(value), 8.0, 60.0)
	_broadcast_view()


func _srv_start(sender: int) -> void:
	if sender != 1 or not _in_lobby() or pm.count() < PlayerManager.MIN_PLAYERS:
		if sender == 1 and pm.count() < PlayerManager.MIN_PLAYERS:
			_emit_to(sender, "error", [tr("São necessários pelo menos 2 jogadores.")])
		return
	Net.set_lobby_open(false)
	_begin_match()


func _begin_match() -> void:
	token += 1
	for p in pm.players:
		p.money = 0
		p.reset_stats()
	money.history.clear()
	ctx.total_rounds = int(config.rounds)
	ctx.decision_time = float(config.decision_time)
	ctx.round_index = 1
	rounds.setup(int(config.rounds), mm, ctx.rng)
	view.mode = "match"
	runner.run(token)


func _srv_rematch(sender: int) -> void:
	if sender != 1 or str(view.get("phase", "")) != "final":
		return
	_begin_match()


func _srv_to_lobby(sender: int) -> void:
	if sender != 1:
		return
	token += 1
	challenge = null
	view.mode = "lobby"
	view.phase = ""
	Net.set_lobby_open(true)
	_broadcast_view()


func _on_peer_left(peer: int) -> void:
	if not is_host():
		return
	for p in pm.owned_by(peer):
		if _in_lobby():
			pm.remove(p.id)
		else:
			p.connected = false   # passa a jogar no automático
			runner.on_player_disconnected(p.id)
	_broadcast_view()


# =============================================================================
# Host: decisões
# =============================================================================

func _srv_submit(sender: int, pid: int, action: Dictionary) -> void:
	var p := pm.get_player(pid)
	if p == null or challenge == null or not runner.accepting:
		return
	if p.owner_peer != sender or p.is_bot:
		return
	if challenge.submit(pid, action):
		_emit("submitted", [challenge.actions.keys()])
	else:
		_emit_to(sender, "error", [tr("Escolha inválida.")])


# =============================================================================
# Eventos (host → todos)
# =============================================================================

func build_view() -> Dictionary:
	var v := view.duplicate()
	v.players = pm.to_array()
	v.config = config.duplicate()
	v.round = rounds.current
	v.total_rounds = rounds.total
	return v


func _broadcast_view() -> void:
	_emit("view", [build_view()])


func _emit(ev: String, args: Array) -> void:
	_apply_event(ev, args)
	if Net.is_online():
		_rpc_event.rpc(ev, args)


func _emit_to(peer: int, ev: String, args: Array) -> void:
	if peer == my_peer():
		_apply_event(ev, args)
	elif Net.is_online() and Net.has_peer(peer):
		_rpc_event.rpc_id(peer, ev, args)


## Envia informação privada só para a máquina dona do jogador.
func send_private(pid: int, info: Dictionary) -> void:
	var p := pm.get_player(pid)
	if p and not p.is_bot:
		_emit_to(p.owner_peer, "private", [pid, info])


@rpc("authority", "call_remote", "reliable")
func _rpc_event(ev: String, args: Array) -> void:
	if EVENTS.has(ev):
		_apply_event(ev, args)


func _apply_event(ev: String, args: Array) -> void:
	match ev:
		"view":
			var v: Dictionary = args[0]
			if is_host():
				view = v
			else:
				view.merge(v, true)
			view_changed.emit()
		"phase":
			view.phase = str(args[0])
			view.phase_info = args[1]
			view.round = int(args[2])
			view.total_rounds = int(args[3])
			view.submitted = []
			var dl := float(args[1].get("deadline_in", -1.0))
			deadline = clock + dl if dl >= 0.0 else -1.0
			if view.phase == "round_intro" or view.phase == "intro":
				private_infos.clear()
			phase_changed.emit(view.phase, view.phase_info)
		"money":
			var pid := int(args[0])
			for p in view.get("players", []):
				if int(p.id) == pid:
					p.money = int(args[2])
			money_changed.emit(pid, int(args[1]), int(args[2]), str(args[3]))
		"step":
			reveal_step.emit(args[0])
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
			error_message.emit(tr("O host encerrou a partida."))
		"error":
			error_message.emit(str(args[0]))
