class_name MatchRunner
extends Node
## Fluxo de uma partida (roda só no host):
## INTRO → [RODADA → DESAFIO → DECISÃO → REVELAÇÃO → RESULTADO (+ EVENTO)] × N → ALL WIN → FINAL

const T_INTRO := 5.0
const T_ROUND_INTRO := 6.0
const T_RESULTS := 4.5
const T_ALLWIN_INTRO := 8.0

var accepting := false
var _token := 0
var _bot_queue: Array = []   # [tempo, pid]
var _round_start_hist := 0


func _game() -> Node:
	return get_parent()


func tick() -> void:
	if not accepting:
		return
	var g = _game()
	for i in range(_bot_queue.size() - 1, -1, -1):
		if g.clock >= float(_bot_queue[i][0]):
			var pid := int(_bot_queue[i][1])
			_bot_queue.remove_at(i)
			if g.challenge and g.challenge.submit(pid, g.challenge.bot_action(pid)):
				g._emit("submitted", [g.challenge.actions.keys()])


func on_player_disconnected(pid: int) -> void:
	var g = _game()
	if accepting and g.challenge and not g.challenge.actions.has(pid):
		_bot_queue.append([g.clock + 0.5, pid])


func _alive(t: int) -> bool:
	return t == _game().token and is_inside_tree()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _phase(phase: String, info: Dictionary = {}) -> void:
	var g = _game()
	g._emit("phase", [phase, info, g.rounds.current, g.rounds.total])


func run(t: int) -> void:
	_token = t
	var g = _game()
	accepting = false
	g._broadcast_view()
	# INTRO: todos recebem o dinheiro inicial
	_phase("intro", {"title": "BEM-VINDOS AO ALL WIN!", "text": "Todos começam com " + Fmt.money(g.START_MONEY)})
	await _wait(1.6)
	if not _alive(t): return
	g.money.set_all(g.START_MONEY, "Dinheiro inicial")
	await _wait(T_INTRO - 1.6)
	if not _alive(t): return
	while g.rounds.has_next():
		var id: String = g.rounds.next()
		g.ctx.round_index = g.rounds.current
		g.money.round_index = g.rounds.current
		await _play_challenge(t, id, "round")
		if not _alive(t): return
		if g.rounds.event_now():
			await _play_challenge(t, "evento", "event")
			if not _alive(t): return
	# ALL WIN
	g.ctx.round_index = g.rounds.total + 2
	g.money.round_index = g.rounds.total + 1
	_phase("allwin_intro", {"title": "ALL WIN", "text": "A última decisão da noite. Tudo ou quase nada."})
	await _wait(T_ALLWIN_INTRO)
	if not _alive(t): return
	await _play_challenge(t, "allwin", "allwin")
	if not _alive(t): return
	_finish()


## Joga um desafio completo. kind: "round", "event" ou "allwin".
func _play_challenge(t: int, id: String, kind: String) -> void:
	var g = _game()
	g.challenge = g.mm.create(id, g.ctx)
	var c: Challenge = g.challenge
	if c == null:
		return
	_round_start_hist = g.money.history.size()
	var info := {"id": id, "kind": kind, "title": c.def.title, "tagline": c.def.tagline, "rules": c.def.rules,
		"color": c.def.color.to_html(), "input": c.def.input, "public": c.public_info()}
	if kind != "allwin":
		_phase("event_intro" if kind == "event" else "round_intro", info)
		await _wait(3.5 if kind == "event" else T_ROUND_INTRO)
		if not _alive(t): return
	if c.needs_decision():
		for pid in c.participants:
			var pinfo := c.private_info(pid)
			pinfo["options"] = c.options(pid)
			g.send_private(pid, pinfo)
		var limit := c.time_limit() + _hotseat_extra()
		var dinfo := info.duplicate()
		dinfo["deadline_in"] = limit
		_bot_queue.clear()
		for pid in c.participants:
			var p: PlayerState = g.pm.get_player(pid)
			if p.is_bot or not p.connected:
				var think: float = g.ctx.rng.randf_range(1.0, minf(5.0, limit * 0.4))
				if id == "reacao":
					var a: Dictionary = c.bot_action(pid)
					think = float(c.public_info().delay) + (0.3 if a.has("false_start") else float(a.get("ms", 500)) / 1000.0)
				_bot_queue.append([g.clock + think, pid])
		accepting = true
		_phase("allwin_decision" if kind == "allwin" else "decision", dinfo)
		var end_t: float = g.clock + limit
		while _alive(t) and not c.all_submitted() and g.clock < end_t:
			await get_tree().process_frame
		accepting = false
		_bot_queue.clear()
		if not _alive(t): return
		c.fill_defaults()
		g._emit("submitted", [c.actions.keys()])
		await _wait(0.6)
		if not _alive(t): return
	var steps := c.resolve()
	_phase("allwin_reveal" if kind == "allwin" else "reveal", info)
	await _wait(0.4)
	for s in steps:
		if not _alive(t): return
		_apply_step(s)
		g._emit("step", [s])
		await _wait(float(s.duration))
	if not _alive(t): return
	if kind == "round":
		var res := _round_results()
		_phase("round_results", res)
		await _wait(T_RESULTS)


func _hotseat_extra() -> float:
	# Várias pessoas na mesma máquina escolhem em sequência: mais tempo.
	var g = _game()
	var most := 1
	var per_peer := {}
	for p in g.pm.players:
		if not p.is_bot:
			per_peer[p.owner_peer] = int(per_peer.get(p.owner_peer, 0)) + 1
			most = maxi(most, per_peer[p.owner_peer])
	return (most - 1) * 8.0


func _apply_step(s: Dictionary) -> void:
	var g = _game()
	for m in s.get("money", []):
		g.money.change(int(m[0]), int(m[1]), str(m[2]))
	for m in s.get("mult", []):
		var p: PlayerState = g.pm.get_player(int(m[0]))
		if p:
			p.stats.best_mult = maxf(float(p.stats.get("best_mult", 0.0)), float(m[1]))
	for m in s.get("risk", []):
		var p: PlayerState = g.pm.get_player(int(m[0]))
		if p:
			p.stats.max_risk = maxi(int(p.stats.get("max_risk", 0)), int(m[1]))


func _round_results() -> Dictionary:
	var g = _game()
	var deltas := {}
	for pid in g.pm.ids():
		deltas[pid] = 0
	for i in range(_round_start_hist, g.money.history.size()):
		var h: Dictionary = g.money.history[i]
		deltas[h.pid] = int(deltas.get(h.pid, 0)) + int(h.delta)
	var best := 0
	for pid in deltas:
		best = maxi(best, int(deltas[pid]))
	var winners := []
	if best > 0:
		for pid in deltas:
			if int(deltas[pid]) == best:
				winners.append(pid)
				g.pm.get_player(pid).stats.challenges_won = int(g.pm.get_player(pid).stats.get("challenges_won", 0)) + 1
	var ranking: Array = g.pm.ranking().map(func(p): return p.id)
	g._broadcast_view()
	return {"deltas": deltas, "winners": winners, "ranking": ranking}


func _finish() -> void:
	var g = _game()
	g.challenge = null
	var ranking: Array = g.pm.ranking()
	var rows := []
	for p in ranking:
		rows.append({"id": p.id, "name": p.name, "character": p.character, "money": p.money, "is_bot": p.is_bot,
			"owner_peer": p.owner_peer, "position": g.pm.position_of(p.id), "stats": p.stats.duplicate()})
	var biggest_gain := {}
	var biggest_loss := {}
	for h in g.money.history:
		if biggest_gain.is_empty() or int(h.delta) > int(biggest_gain.delta):
			biggest_gain = h
		if biggest_loss.is_empty() or int(h.delta) < int(biggest_loss.delta):
			biggest_loss = h
	var summary := {"ranking": rows, "winner": rows[0].id if rows.size() > 0 else -1, "rounds": g.rounds.total,
		"biggest_gain": biggest_gain, "biggest_loss": biggest_loss}
	g._broadcast_view()
	_phase("final", summary)
	g._emit("ended", [summary])
