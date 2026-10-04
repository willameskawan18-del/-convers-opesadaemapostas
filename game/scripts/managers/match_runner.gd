class_name MatchRunner
extends Node
## Fluxo de uma partida (roda só no host):
## INTRO → [RODADA (categoria) → DESAFIO → (DECISÃO → REVELAÇÃO) × etapas → PLACAR (+ EVENTO)] × N
## → MISSÕES SECRETAS → ALL WIN → FINAL

const T_INTRO := 5.0
const T_ROUND_INTRO := 6.0
const T_RESULTS := 4.5
const T_ALLWIN_INTRO := 8.0

var accepting := false
var _token := 0
var _bot_queue: Array = []   # [tempo, pid, ação]
var _round_start_hist := 0
var _pending_inflation := 1.0
var _kind := "round"


func _game() -> Node:
	return get_parent()


func tick() -> void:
	if not accepting:
		return
	var g = _game()
	for i in range(_bot_queue.size() - 1, -1, -1):
		if g.clock >= float(_bot_queue[i][0]):
			var pid := int(_bot_queue[i][1])
			var action: Dictionary = _bot_queue[i][2]
			_bot_queue.remove_at(i)
			if g.challenge and g.challenge.submit(pid, action):
				g._emit("submitted", [g.challenge.actions.keys()])


func on_player_disconnected(pid: int) -> void:
	var g = _game()
	if accepting and g.challenge and not g.challenge.actions.has(pid) and g.challenge.deciders().has(pid):
		_bot_queue.append([g.clock + 0.5, pid, g.challenge.bot_action(pid)])


func _alive(t: int) -> bool:
	return t == _game().token and is_inside_tree()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _phase(phase: String, info: Dictionary = {}) -> void:
	var g = _game()
	g._emit("phase", [phase, info, g.rounds.current, g.rounds.display_total()])


func run(t: int) -> void:
	_token = t
	var g = _game()
	accepting = false
	_pending_inflation = 1.0
	g.ctx.jackpot = MatchContext.JACKPOT_BASE
	g.ctx.jackpot_won = false
	g.ctx.inflation = 1.0
	g.ctx.high_stakes = 1.0
	g.ctx.questions_used.clear()
	MissionSystem.assign(g.pm, g.ctx.rng)
	g._broadcast_view()
	_phase("intro", {"title": "BEM-VINDOS AO ALL WIN!", "text": "Todos começam com " + Fmt.money(g.START_MONEY)})
	await _wait(1.6)
	if not _alive(t): return
	g.money.set_all(g.START_MONEY, "Dinheiro inicial")
	for p in g.pm.players:
		p.stats.min_money = p.money
		p.stats.recovery = 0
		p.stats.peak_money = p.money
		g.send_mission(p.id, str(p.mission.get("text", "")))
	await _wait(T_INTRO - 1.6)
	if not _alive(t): return
	while g.rounds.has_next():
		var id: String = g.rounds.next(g.ctx.rng)
		g.ctx.round_index = g.rounds.current
		g.money.round_index = g.rounds.current
		g.ctx.inflation = _pending_inflation
		_pending_inflation = 1.0
		g.ctx.high_stakes = 2.0 if g.rounds.category() == "grande_risco" else 1.0
		_update_flags()
		await _play_challenge(t, id, "round")
		if not _alive(t): return
		g.ctx.inflation = 1.0
		g.ctx.high_stakes = 1.0
		_update_jackpot()
		if g.rounds.event_now():
			await _play_challenge(t, "evento", "event")
			if not _alive(t): return
	_update_flags()
	await _missions(t)
	if not _alive(t): return
	# ALL WIN
	g.ctx.round_index = g.rounds.total
	g.money.round_index = g.rounds.total + 1
	g.rounds.current = g.rounds.display_total()
	_phase("allwin_intro", {"title": "ALL WIN", "text": "A última decisão da noite. Tudo ou quase nada."})
	await _wait(T_ALLWIN_INTRO)
	if not _alive(t): return
	await _play_challenge(t, "allwin", "allwin")
	if not _alive(t): return
	_finish()


## KING = líder; VIRADA = quem está muito atrás (bônus de +50% nos ganhos da rodada).
func _update_flags() -> void:
	var g = _game()
	var leader: PlayerState = g.pm.leader()
	var lm: int = leader.money if leader else 0
	for p in g.pm.players:
		p.flags.erase("king")
		p.flags.erase("comeback")
		if leader and p.id == leader.id and lm > g.START_MONEY:
			var tied: bool = g.pm.players.filter(func(o): return o.money == lm).size() > 1
			if not tied:
				p.flags["king"] = true
		if lm >= 3000 and (p.money <= 0 or p.money < lm * 0.4):
			p.flags["comeback"] = true
	g._broadcast_view()


func _update_jackpot() -> void:
	var g = _game()
	if g.ctx.jackpot_won:
		g.ctx.jackpot = MatchContext.JACKPOT_BASE
		g.ctx.jackpot_won = false
	else:
		g.ctx.jackpot = mini(MatchContext.JACKPOT_CAP, int(roundf(g.ctx.jackpot * MatchContext.JACKPOT_GROWTH / 500.0) * 500.0))
	g._broadcast_view()


## Joga um desafio completo (todas as etapas). kind: "round", "event" ou "allwin".
func _play_challenge(t: int, id: String, kind: String) -> void:
	var g = _game()
	_kind = kind
	g.challenge = g.mm.create(id, g.ctx)
	var c: Challenge = g.challenge
	if c == null:
		return
	_round_start_hist = g.money.history.size()
	var cat: String = g.rounds.category() if kind == "round" else "especial"
	var info := {"id": id, "kind": kind, "title": c.def.title, "tagline": c.def.tagline, "rules": c.def.rules,
		"color": c.def.color.to_html(), "category": cat, "category_name": MinigameManager.CATEGORY_NAMES.get(cat, ""),
		"category_color": MinigameManager.CATEGORY_COLORS.get(cat, "ffffff"), "public": c.public_info(),
		"high_stakes": g.ctx.high_stakes > 1.0, "inflation": g.ctx.inflation > 1.0}
	if kind != "allwin":
		_phase("event_intro" if kind == "event" else "round_intro", info)
		await _wait(3.5 if kind == "event" else T_ROUND_INTRO)
		if not _alive(t): return
	while true:
		if c.needs_decision():
			await _decision(t, c, info, kind)
			if not _alive(t): return
		var steps := c.resolve()
		var rinfo := info.duplicate()
		rinfo["stage"] = c.stage
		rinfo["public"] = c.public_info()
		_phase("allwin_reveal" if kind == "allwin" else "reveal", rinfo)
		await _wait(0.4)
		for s in steps:
			if not _alive(t): return
			_apply_step(c, s)
			g._emit("step", [s])
			await _wait(float(s.duration))
		if not _alive(t): return
		if c.has_next_stage():
			c.next_stage()
			continue
		break
	if kind == "round":
		var res := _round_results()
		_phase("round_results", res)
		await _wait(T_RESULTS)


func _decision(t: int, c: Challenge, info: Dictionary, kind: String) -> void:
	var g = _game()
	var deciders: Array[int] = c.deciders()
	for pid in deciders:
		var pinfo := c.private_info(pid)
		pinfo["options"] = c.options(pid)
		pinfo["stage"] = c.stage
		var p: PlayerState = g.pm.get_player(pid)
		pinfo["shields"] = p.shields() if c.allows_shield() else 0
		g.send_private(pid, pinfo)
	var limit := c.time_limit() + _hotseat_extra(c)
	var dinfo := info.duplicate()
	dinfo["deadline_in"] = limit
	dinfo["input"] = c.input_type()
	dinfo["public"] = c.public_info()
	dinfo["stage"] = c.stage
	dinfo["stage_title"] = c.stage_title()
	dinfo["deciders"] = deciders
	_bot_queue.clear()
	for pid in deciders:
		var p: PlayerState = g.pm.get_player(pid)
		if p.is_bot or not p.connected:
			var a: Dictionary = c.bot_action(pid)
			var think: float = g.ctx.rng.randf_range(1.0, minf(5.0, limit * 0.4))
			if c.input_type() == "reaction":
				think = float(c.public_info().delay) + (0.3 if a.has("false_start") else float(a.get("ms", 500)) / 1000.0)
			elif c.has_method("bot_delay"):
				think = minf(c.bot_delay(pid, a), limit - 0.5)
			_bot_queue.append([g.clock + think, pid, a])
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


func _hotseat_extra(c: Challenge) -> float:
	# Várias pessoas na mesma máquina decidem/jogam em sequência: mais tempo.
	var g = _game()
	var most := 1
	var per_peer := {}
	for pid in c.deciders():
		var p: PlayerState = g.pm.get_player(pid)
		if not p.is_bot:
			per_peer[p.owner_peer] = int(per_peer.get(p.owner_peer, 0)) + 1
			most = maxi(most, per_peer[p.owner_peer])
	var each := 8.0
	if c.input_type() in ["precision", "targets", "memory", "race"]:
		each = (c.game_seconds() if c.has_method("game_seconds") else 10.0) + 5.0
	elif c.input_type() == "reaction":
		each = 0.0
	return (most - 1) * each


func _apply_step(c: Challenge, s: Dictionary) -> void:
	var g = _game()
	var final_money := []
	var shielded := []
	for m in s.get("money", []):
		var pid := int(m[0])
		var d := int(m[1])
		var tag: String = str(m[3]) if m.size() > 3 else ""
		var p: PlayerState = g.pm.get_player(pid)
		if p == null:
			continue
		if d < 0 and tag != "pay" and c.shields.has(pid):
			shielded.append(pid)
			continue
		final_money.append([pid, d, str(m[2])])
		if d > 0 and _kind == "round" and tag != "nobonus" and tag != "pay" and bool(p.flags.get("comeback", false)):
			var bonus := mini(int(d * 0.5), g.ctx.scaled(1500))
			if bonus > 0:
				final_money.append([pid, bonus, "Bônus de VIRADA"])
	s["money"] = final_money
	if not shielded.is_empty():
		s["shielded"] = shielded
	for m in final_money:
		g.money.change(int(m[0]), int(m[1]), str(m[2]))
	for m in s.get("mult", []):
		var p: PlayerState = g.pm.get_player(int(m[0]))
		if p:
			p.stats.best_mult = maxf(float(p.stats.get("best_mult", 0.0)), float(m[1]))
	for m in s.get("risk", []):
		var p: PlayerState = g.pm.get_player(int(m[0]))
		if p:
			p.stats.max_risk = maxi(int(p.stats.get("max_risk", 0)), int(m[1]))
			p.stats.risk_total = int(p.stats.get("risk_total", 0)) + int(m[1])
	for m in s.get("stat", []):
		var p: PlayerState = g.pm.get_player(int(m[0]))
		if p:
			p.stats[m[1]] = p.stats.get(m[1], 0) + m[2]
	var changed := false
	for m in s.get("items", []):
		var p: PlayerState = g.pm.get_player(int(m[0]))
		if p:
			p.items[m[1]] = int(p.items.get(m[1], 0)) + int(m[2])
			changed = true
	for m in s.get("flags", []):
		var p: PlayerState = g.pm.get_player(int(m[0]))
		if p:
			p.flags[m[1]] = m[2]
			changed = true
	if s.has("inflation"):
		_pending_inflation = float(s.inflation)
	if changed or not shielded.is_empty():
		g._broadcast_view()


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
	return {"deltas": deltas, "winners": winners, "ranking": ranking, "jackpot": g.ctx.jackpot}


## Missões secretas reveladas antes do ALL WIN.
func _missions(t: int) -> void:
	var g = _game()
	_phase("missions", {"title": "MISSÕES SECRETAS", "text": "Hora de revelar as missões de cada um!"})
	await _wait(3.0)
	for p in g.pm.players:
		if not _alive(t): return
		var ok := MissionSystem.completed(p, g.pm)
		var bonus: int = g.ctx.scaled(MissionSystem.BONUS)
		var s := Challenge.step("player_result", 2.6, {"title": "%s: %s" % [p.name, "CUMPRIU!" if ok else "FALHOU"], "text": str(p.mission.get("text", "")) + ("  " + Fmt.delta(bonus) if ok else ""),
			"pid": p.id, "money": [[p.id, bonus, "Missão secreta", "nobonus"]] if ok else [], "fx": "win" if ok else "lose", "camera": "player"})
		_kind = "missions"
		_apply_step(Challenge.new(), s)
		g._emit("step", [s])
		await _wait(float(s.duration))


func _finish() -> void:
	var g = _game()
	g.challenge = null
	var ranking: Array = g.pm.ranking()
	var rows := []
	for p in ranking:
		rows.append({"id": p.id, "name": p.name, "character": p.character, "money": p.money, "is_bot": p.is_bot,
			"owner_peer": p.owner_peer, "position": g.pm.position_of(p.id), "stats": p.stats.duplicate(), "mission": p.mission.get("text", "")})
	var biggest_gain := {}
	var biggest_loss := {}
	for h in g.money.history:
		if biggest_gain.is_empty() or int(h.delta) > int(biggest_gain.delta):
			biggest_gain = h
		if biggest_loss.is_empty() or int(h.delta) < int(biggest_loss.delta):
			biggest_loss = h
	var summary := {"ranking": rows, "winner": rows[0].id if rows.size() > 0 else -1, "rounds": g.rounds.display_total(),
		"biggest_gain": biggest_gain, "biggest_loss": biggest_loss, "awards": AwardSystem.compute(g.pm), "played": g.rounds.sequence}
	Profile.remember_recent(g.rounds.sequence)
	g._broadcast_view()
	_phase("final", summary)
	g._emit("ended", [summary])
