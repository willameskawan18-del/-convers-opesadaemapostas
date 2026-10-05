extends Node
## GameManager (autoload "Game"). Host simula a expedição (RunModel) e envia o estado;
## cada máquina controla o próprio pescador em primeira pessoa.

signal view_changed
signal run_changed(run: Dictionary)
signal world_state(state: Dictionary)
signal notify(text: String, color: Color)
signal fx(kind: String, data: Dictionary)
signal catch_announced(pid: int, fish: Dictionary)
signal pose_received(pid: int, pose: Dictionary)
signal night_ended(summary: Dictionary)
signal game_over(summary: Dictionary)
signal returned_to_menu
signal error_message(text: String)

const EVENTS := ["view", "run", "notify", "fx", "catch", "night_end", "gameover", "menu", "error"]
const REQUESTS := ["add_player", "remove_player", "set_character", "set_config", "start", "drive", "catch", "sell", "buy", "lantern", "repair", "hit", "rematch", "to_lobby"]
const NIGHT_SECONDS := {4: 240.0, 6: 360.0, 8: 480.0}

var view: Dictionary = {"mode": "menu", "players": [], "config": {}}
var run_view: Dictionary = {}
var clock := 0.0
var players := []               # host: [{id, name, character, owner_peer}]
var config := {"night_minutes": 6}
var model := RunModel.new()
var rng := RandomNumberGenerator.new()
var paused_for_summary := false
var _next_id := 1
var _send_t := 0.0
var _event_t := 0.0
var _boat_input := Vector2.ZERO
var _last_state: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	Net.peer_left.connect(_on_peer_left)
	Net.connected_to_host.connect(func(): view = {"mode": "lobby", "players": [], "config": {}})
	Net.disconnected_from_host.connect(func():
		_local_menu()
		error_message.emit("Conexão com o host perdida."))


# --- Consultas -------------------------------------------------------------------

func is_host() -> bool:
	return Net.is_host()


func my_peer() -> int:
	return Net.my_id()


func local_player() -> Dictionary:
	for p in view.get("players", []):
		if int(p.owner_peer) == my_peer():
			return p
	return {}


func my_pid() -> int:
	return int(local_player().get("id", -1))


func player_view(pid: int) -> Dictionary:
	for p in view.get("players", []):
		if int(p.id) == pid:
			return p
	return {}


func world_state_cache() -> Dictionary:
	return _last_state


func in_run() -> bool:
	return str(view.get("mode", "")) == "run"


# --- Lobby -----------------------------------------------------------------------

func new_local_session() -> void:
	Net.close()
	players.clear()
	_next_id = 1
	view = {"mode": "lobby", "players": [], "config": config.duplicate()}
	_broadcast_view()


func request(method: String, args: Array = []) -> void:
	if is_host():
		_handle(my_peer(), method, args)
	else:
		_rpc_request.rpc_id(1, method, args)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(method: String, args: Array) -> void:
	if is_host():
		_handle(multiplayer.get_remote_sender_id(), method, args)


func leave_to_menu() -> void:
	if is_host() and Net.is_online():
		_emit("menu", [])
	Net.close()
	_local_menu()


func _local_menu() -> void:
	players.clear()
	view = {"mode": "menu", "players": [], "config": {}}
	run_view = {}
	paused_for_summary = false
	returned_to_menu.emit()
	view_changed.emit()


func _handle(sender: int, method: String, args: Array) -> void:
	if not REQUESTS.has(method):
		return
	var pid := _pid_of(sender)
	match method:
		"add_player":
			if str(view.mode) != "lobby" or players.size() >= 4 or pid >= 0:
				return
			var c := str(args[1])
			var used := players.map(func(p): return p.character)
			if used.has(c) or c == "":
				for ch in GameData.characters():
					if not used.has(ch.id):
						c = ch.id
						break
			players.append({"id": _next_id, "name": str(args[0]).strip_edges().substr(0, 14) if str(args[0]).strip_edges() != "" else "PESCADOR %d" % _next_id, "character": c, "owner_peer": sender})
			_next_id += 1
			_broadcast_view()
		"set_character":
			for p in players:
				if int(p.owner_peer) == sender:
					p.character = str(args[0])
			_broadcast_view()
		"set_config":
			if sender == 1 and str(args[0]) == "night_minutes":
				config.night_minutes = int(args[1])
				_broadcast_view()
		"start":
			if sender == 1 and str(view.mode) == "lobby" and players.size() > 0:
				Net.set_lobby_open(false)
				var saved: Dictionary = Profile.load_expedition() if args.size() > 0 and bool(args[0]) else {}
				_start_run(saved)
		"rematch":
			if sender == 1:
				_start_run()
		"to_lobby":
			if sender == 1:
				view.mode = "lobby"
				Net.set_lobby_open(true)
				_broadcast_view()
		_:
			if in_run() and pid >= 0:
				_run_request(pid, method, args)


func _pid_of(peer: int) -> int:
	for p in players:
		if int(p.owner_peer) == peer:
			return int(p.id)
	return -1


func _on_peer_left(peer: int) -> void:
	if not is_host():
		return
	var pid := _pid_of(peer)
	players = players.filter(func(p): return int(p.owner_peer) != peer)
	if model.driver == pid:
		model.driver = -1
	_broadcast_view()


# --- Expedição (host) -----------------------------------------------------------------

func _start_run(saved: Dictionary = {}) -> void:
	model.reset()
	if not saved.is_empty():
		model.from_save(saved)
	paused_for_summary = false
	view.mode = "run"
	_broadcast_view()
	_send_run()
	if saved.is_empty():
		_emit("notify", ["NOITE 1 — Cota: %s em 3 noites" % Fmt.money(model.quota), Color("ffcc33")])
	else:
		_roll_weather()
		_emit("notify", ["EXPEDIÇÃO CONTINUADA — NOITE %d · Cota: %s" % [model.night, Fmt.money(model.quota)], Color("ffcc33")])


func night_seconds() -> float:
	return NIGHT_SECONDS.get(int(config.night_minutes), 360.0)


func _process(delta: float) -> void:
	clock += delta
	if not is_host() or not in_run() or paused_for_summary:
		return
	_simulate(delta)
	_send_t += delta
	if _send_t >= 0.066:
		_send_t = 0.0
		_send_state()


func _simulate(delta: float) -> void:
	var m := model
	# relógio
	m.minute += delta * RunModel.NIGHT_MINUTES / night_seconds()
	if m.minute >= RunModel.NIGHT_MINUTES:
		_end_night()
		return
	# barco
	var target := m.throttle * m.max_speed()
	m.speed = move_toward(m.speed, target, delta * (3.0 if absf(target) > absf(m.speed) else 5.0))
	if m.driver < 0:
		m.speed = move_toward(m.speed, 0.0, delta * 2.0)
	m.yaw -= m.steer * delta * 0.6 * clampf(absf(m.speed) / 4.0, 0.2, 1.0) * signf(m.speed if absf(m.speed) > 0.1 else 1.0)
	var fwd := Vector3(sin(m.yaw), 0, cos(m.yaw))
	m.pos += fwd * m.speed * delta
	var d := m.distance()
	if d > 720.0:
		m.pos = m.pos * (720.0 / d)
		m.speed *= 0.5
	# vazamentos drenam o casco
	if not m.leaks.is_empty():
		m.hull -= m.leaks.size() * 2.0 * delta
	if m.hull <= 0.0:
		_sink()
		return
	# pavor e perigos
	var zid := str(m.zone().id)
	var rate: float = {"raso": 0.0, "fundo": 0.45, "abismo": 1.1}.get(zid, 0.0)
	if m.lantern and zid == "abismo":
		rate *= 1.5
	if absf(m.speed) > 1.0:
		rate *= 1.3
	rate *= 1.0 + 0.12 * (m.night - 1)
	if m.weather == "tempestade":
		rate *= 1.3
	m.dread = clampf(m.dread + rate * delta, 0.0, 100.0)
	if zid == "raso":
		m.dread = maxf(0.0, m.dread - delta * 3.0)
	_event_t -= delta
	if _event_t <= 0.0:
		_event_t = rng.randf_range(4.0, 8.0)
		_maybe_event(zid)
	_tick_threats(delta)


func _maybe_event(zid: String) -> void:
	var m := model
	if zid == "raso" or m.docked():
		return
	if not m.tentacle.is_empty() or not m.eyes.is_empty():
		return
	if zid == "abismo" and m.dread > (55.0 if m.weather == "nevoeiro" else 70.0) and m.lantern and rng.randf() < 0.45:
		m.eyes = {"t": 9.0, "angle": rng.randf() * TAU}
		m.dread -= 30.0
		_emit("fx", ["eyes", {"angle": m.eyes.angle}])
		_emit("notify", ["OLHOS NA NÉVOA! Apague a LANTERNA (F) e PARE O MOTOR!", Color("ff4d6d")])
	elif zid == "abismo" and m.dread > 55.0 and rng.randf() < 0.5:
		m.tentacle = {"side": -1.0 if rng.randf() < 0.5 else 1.0, "hp": 6 + m.night, "t": 9.0}
		m.dread -= 35.0
		_emit("fx", ["tentacle_rise", {"side": m.tentacle.side, "hp": m.tentacle.hp}])
		_emit("notify", ["TENTÁCULO! Bata nele com o REMO (clique)!", Color("ff4d6d")])
	elif m.dread > 30.0 and rng.randf() < 0.5:
		m.dread -= 25.0
		var n := 1 if zid == "fundo" else 2
		for i in n:
			m.add_leak(rng)
		m.hull -= 12.0
		_emit("fx", ["thump", {"leaks": n}])
		_emit("notify", ["ALGO BATEU NO CASCO! Conserte os vazamentos (E)!", Color("ff9f1c")])
		_send_run()


func _tick_threats(delta: float) -> void:
	var m := model
	if not m.tentacle.is_empty():
		m.tentacle.t = float(m.tentacle.t) - delta
		if float(m.tentacle.t) <= 0.0:
			m.hull -= 40.0
			m.add_leak(rng)
			m.add_leak(rng)
			var victim: Dictionary = players[rng.randi_range(0, players.size() - 1)] if players.size() > 0 else {}
			_emit("fx", ["tentacle_smash", {"victim": int(victim.get("id", -1))}])
			_emit("notify", ["O TENTÁCULO ESMAGOU O BARCO!", Color("ff4d6d")])
			m.tentacle = {}
			_send_run()
	if not m.eyes.is_empty():
		m.eyes.t = float(m.eyes.t) - delta
		var quiet: bool = not m.lantern and absf(m.speed) < 1.0
		if quiet and float(m.eyes.t) < 6.0:
			m.eyes = {}
			_emit("fx", ["eyes_gone", {}])
			_emit("notify", ["Os olhos sumiram na escuridão... ufa.", Color("3ddc97")])
		elif float(m.eyes.t) <= 0.0:
			m.hull -= 65.0
			m.add_leak(rng)
			m.eyes = {}
			_emit("fx", ["leviathan", {}])
			_emit("notify", ["O LEVIATÃ ATACOU!", Color("ff4d6d")])
			_send_run()


func _sink() -> void:
	var m := model
	m.stats.sinks = int(m.stats.sinks) + 1
	var lost := m.cooler_value()
	m.cooler.clear()
	m.reset_boat()
	m.driver = -1
	_emit("fx", ["sink", {}])
	_emit("notify", ["NAUFRÁGIO! Vocês perderam %s em peixes. Rebocados até o porto." % Fmt.money(lost), Color("ff4d6d")])
	_send_run()


func _end_night() -> void:
	var m := model
	var lost := 0
	if not m.docked() and m.distance() > 30.0:
		var keep: Array = []
		for f in m.cooler:
			if rng.randf() < 0.5:
				keep.append(f)
			else:
				lost += int(f.value)
		m.cooler = keep
	var sold := m.cooler_value()
	_sell_all()
	var summary := {"night": m.night, "sold": sold, "lost": lost, "money": m.money, "quota": m.quota, "sold_cycle": m.sold_cycle}
	var cycle_end := m.night % RunModel.NIGHTS_PER_QUOTA == 0
	if cycle_end:
		summary["quota_check"] = true
		summary["quota_ok"] = m.sold_cycle >= m.quota
		if m.sold_cycle < m.quota:
			paused_for_summary = true
			Profile.clear_expedition()
			var final := {"nights": m.night, "money": m.money, "quota": m.quota, "sold_cycle": m.sold_cycle, "stats": m.stats.duplicate()}
			Profile.data.best_money = maxi(int(Profile.data.get("best_money", 0)), int(m.stats.earned))
			Profile.save_profile()
			_send_run()
			_emit("gameover", [final])
			return
		m.quota_index += 1
		m.quota = RunModel.quota_for(m.quota_index)
		m.sold_cycle = 0
		m.quotas_met += 1
	m.night += 1
	m.minute = 0.0
	m.reset_boat()
	m.driver = -1
	summary["next_quota"] = m.quota
	summary["next_night"] = m.night
	summary["earned"] = int(m.stats.earned)
	summary["quotas_met"] = m.quotas_met
	_roll_weather()
	summary["weather"] = m.weather
	Profile.save_expedition(m.to_save())
	paused_for_summary = true
	_send_run()
	_emit("night_end", [summary])
	get_tree().create_timer(6.0, true).timeout.connect(_after_night_pause)


func _after_night_pause() -> void:
	var m := model
	paused_for_summary = false
	_emit("notify", ["NOITE %d — Cota: %s até a noite %d" % [m.night, Fmt.money(m.quota), (int((m.night - 1) / RunModel.NIGHTS_PER_QUOTA) + 1) * RunModel.NIGHTS_PER_QUOTA], Color("ffcc33")])
	match m.weather:
		"tempestade": _emit("notify", ["TEMPESTADE! Ondas enormes, peixes raros... e mais perigo.", Color("b072ff")])
		"nevoeiro": _emit("notify", ["NEVOEIRO DENSO. Algo observa da névoa...", Color("8fa3b8")])


func _roll_weather() -> void:
	var r := rng.randf()
	model.weather = "calmo" if r < 0.5 else ("nevoeiro" if r < 0.75 else "tempestade")


func _sell_all() -> int:
	var m := model
	var v := m.cooler_value()
	m.money += v
	m.sold_cycle += v
	m.stats.earned = int(m.stats.earned) + v
	m.cooler.clear()
	return v


func _run_request(pid: int, method: String, args: Array) -> void:
	var m := model
	match method:
		"drive":
			var enter := bool(args[0])
			if enter and m.driver < 0:
				m.driver = pid
			elif not enter and m.driver == pid:
				m.driver = -1
				m.throttle = 0.0
				m.steer = 0.0
			_send_run()
		"catch":
			var f: Dictionary = args[0]
			# validação simples: peixe existe e valor plausível
			var base := FishDB.get_fish(str(f.get("id", "")))
			if base.is_empty() or int(f.get("value", 0)) > int(base.value) * 2:
				return
			m.cooler.append(f)
			m.stats.caught = int(m.stats.caught) + 1
			if int(f.value) > int(m.stats.best_value):
				m.stats.best_value = int(f.value)
				m.stats.best_name = str(f.name)
			if float(f.kg) > float(m.stats.biggest_kg):
				m.stats.biggest_kg = float(f.kg)
				m.stats.biggest_name = str(f.name)
			_emit("catch", [pid, f])
			_send_run()
		"sell":
			if m.docked() and not m.cooler.is_empty():
				var v := _sell_all()
				_emit("notify", ["VENDIDO! +%s  (cota: %s / %s)" % [Fmt.money(v), Fmt.money(m.sold_cycle), Fmt.money(m.quota)], Color("3ddc97")])
				_emit("fx", ["sold", {"value": v}])
				_send_run()
		"buy":
			var k := str(args[0])
			if not RunModel.UPGRADES.has(k) or not m.docked():
				return
			var cost := m.upgrade_cost(k)
			if cost < 0 or m.money < cost:
				return
			m.money -= cost
			m.upgrades[k] = int(m.upgrades[k]) + 1
			if k == "casco":
				m.hull = m.hull_max()
			_emit("notify", ["Comprado: %s nível %d" % [RunModel.UPGRADES[k].name, int(m.upgrades[k])], Color("27e1ff")])
			_send_run()
		"lantern":
			m.lantern = not m.lantern
			_send_run()
		"repair":
			var id := int(args[0])
			for l in m.leaks:
				if int(l.id) == id:
					l.hp = float(l.hp) - float(args[1])
			var before := m.leaks.size()
			m.leaks = m.leaks.filter(func(l): return float(l.hp) > 0.0)
			if m.leaks.size() < before:
				m.hull = minf(m.hull_max(), m.hull + 3.0)
				_emit("fx", ["leak_fixed", {}])
				_send_run()
		"hit":
			if not m.tentacle.is_empty():
				m.tentacle.hp = int(m.tentacle.hp) - 1
				_emit("fx", ["tentacle_hit", {"hp": int(m.tentacle.hp)}])
				if int(m.tentacle.hp) <= 0:
					m.tentacle = {}
					_emit("fx", ["tentacle_gone", {}])
					_emit("notify", ["O TENTÁCULO RECUOU!", Color("3ddc97")])


## Entrada do timoneiro (enviada ~20x/s, não confiável).
func send_boat_input(throttle: float, steer: float) -> void:
	if is_host():
		_apply_input(my_pid(), throttle, steer)
	else:
		_rpc_input.rpc_id(1, throttle, steer)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_input(throttle: float, steer: float) -> void:
	if is_host():
		_apply_input(_pid_of(multiplayer.get_remote_sender_id()), throttle, steer)


func _apply_input(pid: int, throttle: float, steer: float) -> void:
	if pid >= 0 and pid == model.driver:
		model.throttle = clampf(throttle, -0.4, 1.0)
		model.steer = clampf(steer, -1.0, 1.0)


## Pose do pescador local para as outras máquinas.
func send_pose(pose: Dictionary) -> void:
	if Net.is_online():
		_rpc_pose.rpc(my_pid(), pose)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_pose(pid: int, pose: Dictionary) -> void:
	pose_received.emit(pid, pose)


# --- Envio de estado -------------------------------------------------------------------

func _send_state() -> void:
	var m := model
	var s := {"pos": m.pos, "yaw": m.yaw, "speed": m.speed, "t": clock, "leaks": m.leaks.map(func(l): return [l.id, l.pos, l.hp]),
		"tentacle": m.tentacle.duplicate(), "eyes": m.eyes.duplicate(), "lantern": m.lantern, "hull": m.hull, "minute": m.minute, "dread": m.dread}
	_last_state = s
	world_state.emit(s)
	if Net.is_online():
		_rpc_state.rpc(s)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_state(s: Dictionary) -> void:
	_last_state = s
	world_state.emit(s)


func _send_run() -> void:
	_emit("run", [model.to_public()])


func build_view() -> Dictionary:
	return {"mode": view.mode, "players": players.duplicate(true), "config": config.duplicate()}


func _broadcast_view() -> void:
	_emit("view", [build_view()])


func _emit(ev: String, args: Array) -> void:
	_apply(ev, args)
	if Net.is_online():
		_rpc_event.rpc(ev, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_event(ev: String, args: Array) -> void:
	if EVENTS.has(ev):
		_apply(ev, args)


func _apply(ev: String, args: Array) -> void:
	match ev:
		"view":
			view = args[0]
			view_changed.emit()
		"run":
			run_view = args[0]
			run_changed.emit(run_view)
		"notify":
			notify.emit(str(args[0]), args[1])
		"fx":
			fx.emit(str(args[0]), args[1])
		"catch":
			catch_announced.emit(int(args[0]), args[1])
		"night_end":
			night_ended.emit(args[0])
		"gameover":
			game_over.emit(args[0])
		"menu":
			Net.close()
			_local_menu()
			error_message.emit("O host encerrou a partida.")
		"error":
			error_message.emit(str(args[0]))


## compatibilidade com NetworkManager (copiado dos outros jogos)
func _broadcast_view_compat() -> void:
	_broadcast_view()
