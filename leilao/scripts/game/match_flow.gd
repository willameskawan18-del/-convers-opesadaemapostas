class_name MatchFlow
extends Node
## Fluxo da partida (só no host):
## INTRO → [DIA: LOJA → (ESPIAR → LEILÃO AO VIVO → ABRIR) × galpões → VENDER → FIM DO DIA] × dias → FINAL

const T_INTRO := 4.5
const T_SHOP := 18.0
const T_PEEK := 12.0
const T_SELL := 40.0
const AUCTION_START := 9.0
const AUCTION_EXTEND := 4.5
const FIRST_BID := 100
const UPGRADES := {
	"lanterna": [1500, "LANTERNA", "Vê 2 itens a mais ao espiar."],
	"avaliador": [2000, "AVALIADOR", "Vê o valor estimado dos itens ao espiar."],
	"informante": [1200, "INFORMANTE", "Recebe uma dica secreta e verdadeira de cada galpão."],
}

var unit: Dictionary = {}
var auction: Dictionary = {}
var accepting := false
var expecting: Array = []
var actions: Dictionary = {}
var unit_log: Array = []
var _token := 0
var _bot_plans: Dictionary = {}
var _sync_t := 0.0
var _day := 1


func g() -> Node:
	return get_parent()


func _alive(t: int) -> bool:
	return t == g().token and is_inside_tree()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout


func _phase(p: String, info: Dictionary = {}) -> void:
	info["day"] = _day
	info["days"] = int(g().config.days)
	g()._emit("phase", [p, info])


func _money(pid: int, delta: int, reason: String) -> void:
	var p: PlayerState = g().players.get_p(pid)
	if p == null or delta == 0:
		return
	var old := p.money
	p.money += delta
	if delta > 0:
		p.stats.earned = int(p.stats.earned) + delta
	else:
		p.stats.spent = int(p.stats.spent) - delta
	g()._emit("money", [pid, old, p.money, reason])


# --- Partida ----------------------------------------------------------------------

## Usado pelo roteiro do trailer: garante um item especial no próximo galpão.
var force_special := ""


func run(t: int) -> void:
	_token = t
	unit_log.clear()
	_day = 1
	g()._broadcast_view()
	_phase("intro", {"title": "LEILÃO DE GARAGEM", "text": "Todos começam com " + Fmt.money(g().START_MONEY)})
	await _wait(1.5)
	if not _alive(t): return
	for p in g().players.list:
		_money(p.id, g().START_MONEY, "Dinheiro inicial")
	await _wait(T_INTRO - 1.5)
	for day in range(1, int(g().config.days) + 1):
		_day = day
		if not _alive(t): return
		if day > 1:
			await _shop(t)
			if not _alive(t): return
		for n in range(1, int(g().config.units_per_day) + 1):
			unit = UnitGen.generate(g().rng, day, (day - 1) * int(g().config.units_per_day) + n)
			if force_special != "":
				var sp := UnitGen.make_item(UnitGen.item_def(force_special), g().rng, day)
				sp.value = maxi(int(sp.value), int(sp.max) / 2)
				unit.items.insert(mini(4, unit.items.size()), sp)
				unit.total = int(unit.total) + int(sp.value)
				force_special = ""
			await _peek(t, n)
			if not _alive(t): return
			await _auction(t)
			if not _alive(t): return
			await _open(t)
			if not _alive(t): return
		await _sell(t)
		if not _alive(t): return
		_phase("day_end", {"ranking": _ranking_ids()})
		await _wait(4.5)
	if not _alive(t): return
	await _finish(t)


func _ranking_ids() -> Array:
	var r: Array = g().players.list.duplicate()
	r.sort_custom(func(a, b): return a.money > b.money)
	return r.map(func(p): return p.id)


# --- Loja de melhorias ---------------------------------------------------------------

func _shop(t: int) -> void:
	actions.clear()
	expecting = []
	for p in g().players.list:
		if p.is_bot or not p.connected:
			for k in UPGRADES:
				if not p.upgrades.has(k) and p.money > int(UPGRADES[k][0]) * 3 and g().rng.randf() < 0.35:
					_buy(p, k)
			continue
		expecting.append(p.id)
		g().send_private(p.id, {"kind": "shop", "upgrades": UPGRADES, "owned": p.upgrades.duplicate(), "money": p.money})
	_phase("shop", {"deadline_in": T_SHOP})
	await _wait_actions(t, T_SHOP)


func _buy(p: PlayerState, k: String) -> bool:
	if p.upgrades.has(k) or not UPGRADES.has(k) or p.money < int(UPGRADES[k][0]):
		return false
	p.upgrades[k] = true
	_money(p.id, -int(UPGRADES[k][0]), "Melhoria: " + UPGRADES[k][1])
	return true


func _wait_actions(t: int, limit: float) -> void:
	var end_t: float = g().clock + limit
	while _alive(t) and g().clock < end_t:
		if expecting.all(func(pid): return actions.has(pid)):
			break
		await get_tree().process_frame
	expecting = []


## Ações dos humanos (loja, espiar pronto, venda).
func submit(pid: int, action: Dictionary) -> void:
	if not expecting.has(pid) or actions.has(pid):
		return
	var p: PlayerState = g().players.get_p(pid)
	match str(view_phase()):
		"shop":
			for k in action.get("buy", []):
				_buy(p, str(k))
			g()._broadcast_view()
		"sell":
			pass
	actions[pid] = action
	g()._emit("submitted", [actions.keys()])


func view_phase() -> String:
	return str(g().view.get("phase", ""))


# --- Espiar ----------------------------------------------------------------------------

func _peek(t: int, n: int) -> void:
	actions.clear()
	expecting = []
	_bot_plans.clear()
	var items: Array = unit.items
	for p in g().players.list:
		var vis := mini(items.size(), UnitGen.visible_count(p.upgrades.has("lanterna"), unit.number + p.id))
		if p.is_bot or not p.connected:
			_bot_plans[p.id] = {"max": BotBrain.max_bid(p, unit, vis, g().rng), "next": 0.0}
			continue
		expecting.append(p.id)
		# Todos os itens vão para o cliente, mas a lanterna só deixa inspecionar `budget`
		# deles (os 2 da fresta são de graça). Os bots continuam usando `vis`.
		var shown := []
		for i in items.size():
			var it: Dictionary = items[i]
			var e := {"name": it.name, "cat": it.cat, "shape": it.shape, "color": it.color}
			if p.upgrades.has("avaliador"):
				e["est"] = "%s – %s" % [Fmt.money(int(it.est_lo)), Fmt.money(int(it.est_hi))] if not it.mystery else "???"
			shown.append(e)
		var tip := ""
		if p.upgrades.has("informante"):
			var best := 0
			for it in items:
				best = maxi(best, int(it.value))
			tip = "INFORMANTE: o item mais valioso daqui vale %s." % ("mais de " + Fmt.money(int(best * 0.7 / 100) * 100) if best > 500 else "menos de $500")
		g().send_private(p.id, {"kind": "peek", "visible": shown, "budget": maxi(2, vis), "count": items.size(), "tip": tip, "money": p.money})
	_phase("peek", {"deadline_in": T_PEEK, "unit": unit.number, "n": n, "per_day": int(g().config.units_per_day), "rumor": unit.rumor,
		"count": items.size(), "visible_public": _public_visible()})
	await _wait_actions(t, T_PEEK)


## O que todos veem pela fresta da porta (2 primeiros itens, sem valores).
func _public_visible() -> Array:
	var out := []
	for i in mini(2, unit.items.size()):
		out.append({"name": unit.items[i].name, "shape": unit.items[i].shape, "color": unit.items[i].color})
	return out


# --- Leilão ao vivo -----------------------------------------------------------------------

func _auction(t: int) -> void:
	auction = {"price": 0, "leader": -1, "leader_name": "", "history": [], "unit": unit.number, "ends_in": AUCTION_START, "call": ""}
	accepting = true
	var dl: float = g().clock + AUCTION_START
	auction["_deadline"] = dl
	_phase("auction", {"unit": unit.number, "count": unit.items.size(), "rumor": unit.rumor, "visible_public": _public_visible()})
	_sync_auction()
	for pid in _bot_plans:
		_bot_plans[pid].next = g().clock + g().rng.randf_range(1.0, 4.0)
	var last_call := ""
	while _alive(t) and g().clock < float(auction._deadline):
		var left: float = float(auction._deadline) - g().clock
		var call := ""
		if left < 1.6:
			call = "DOU-LHE DUAS..."
		elif left < 3.2:
			call = "DOU-LHE UMA..."
		if call != last_call:
			last_call = call
			auction.call = call
			_sync_auction()
		await get_tree().process_frame
	accepting = false
	if not _alive(t): return
	auction.call = "VENDIDO!" if int(auction.leader) >= 0 else "SEM LANCES!"
	auction.ends_in = 0.0
	_sync_auction()
	await _wait(2.0)


func next_min() -> int:
	return FIRST_BID if int(auction.get("leader", -1)) < 0 else int(auction.price) + Game.min_increment(int(auction.price))


func try_bid(pid: int, amount: int) -> bool:
	if not accepting:
		return false
	var p: PlayerState = g().players.get_p(pid)
	if p == null or pid == int(auction.leader) or amount < next_min() or amount > p.money:
		return false
	auction.price = amount
	auction.leader = pid
	auction.leader_name = p.name
	auction.history.append([p.name, amount])
	if auction.history.size() > 8:
		auction.history.pop_front()
	auction._deadline = maxf(float(auction._deadline), g().clock + AUCTION_EXTEND)
	auction.call = ""
	p.stats.biggest_bid = maxi(int(p.stats.biggest_bid), amount)
	_sync_auction()
	return true


func _sync_auction() -> void:
	var s := auction.duplicate()
	s.erase("_deadline")
	s.ends_in = maxf(0.0, float(auction.get("_deadline", 0.0)) - g().clock) if accepting else 0.0
	s.next_min = next_min()
	g()._emit("auction", [s])
	_sync_t = g().clock


func tick() -> void:
	if not accepting:
		return
	if g().clock - _sync_t > 1.0:
		_sync_auction()
	var left: float = float(auction._deadline) - g().clock
	for pid in _bot_plans:
		var plan: Dictionary = _bot_plans[pid]
		if g().clock < float(plan.next) or pid == int(auction.leader):
			continue
		var nm := next_min()
		var p: PlayerState = g().players.get_p(pid)
		if nm > int(plan.max) or nm > p.money:
			plan.next = INF
			continue
		# bots gostam de dar lance no fim ("sniper") — às vezes pulam o preço
		if left > 2.5 and g().rng.randf() < 0.45:
			plan.next = g().clock + g().rng.randf_range(0.6, 1.5)
			continue
		var amt := nm
		if g().rng.randf() < 0.2:
			amt = mini(int(plan.max), nm + Game.min_increment(nm) * g().rng.randi_range(1, 4))
		var prev := int(auction.leader)
		if try_bid(pid, mini(amt, p.money)) and g().rng.randf() < 0.35:
			_taunt(p, prev)
		plan.next = g().clock + g().rng.randf_range(0.7, 2.4)


const TAUNTS := {
	"rico": ["Dinheiro não é problema.", "Pode subir, eu cubro.", "Isso é troco pra mim."],
	"apostador": ["Tudo ou nada!", "Sinto cheiro de ouro aí dentro!", "Vou no escuro mesmo!"],
	"maluco": ["MEU! É TUDO MEU!", "Tem um dinossauro aí, eu sei!", "HAHAHA mais um lance!"],
	"medroso": ["É... só mais um pouquinho...", "Ai, será que vale?", "Último lance, juro."],
	"genio": ["Calculei: ainda dá lucro.", "Estatisticamente, compensa.", "Vocês não leram o boato?"],
	"trapaceiro": ["Eu vi o que tem lá dentro...", "Confia em mim, não vale nada. Lance!", "Heh heh."],
	"sortudo": ["Hoje é meu dia!", "Sorte de principiante!", "Trevo de quatro folhas no bolso!"],
	"azarado": ["Dessa vez vai...", "Por favor, que não seja lixo.", "Nada pode dar errado. Né?"],
}


func _taunt(p: PlayerState, prev_leader: int) -> void:
	var lines: Array = TAUNTS.get(p.character, ["Lance!"])
	var text: String = lines[g().rng.randi() % lines.size()]
	var prev: PlayerState = g().players.get_p(prev_leader)
	if prev and not prev.is_bot and g().rng.randf() < 0.5:
		text = "Desculpa, %s!" % prev.name
	g()._emit("step", [{"kind": "taunt", "pid": p.id, "text": text}])


# --- Abrir o galpão ----------------------------------------------------------------------

func _open(t: int) -> void:
	var winner := int(auction.leader)
	var paid := int(auction.price)
	_phase("open", {"unit": unit.number, "winner": winner, "paid": paid, "name": unit.name})
	await _wait(0.4)
	var w: PlayerState = g().players.get_p(winner) if winner >= 0 else null
	if w:
		_money(winner, -paid, "Arrematou o galpão %d" % unit.number)
		w.stats.units_won = int(w.stats.units_won) + 1
	g()._emit("step", [{"kind": "door", "duration": 1.6, "title": ("%s ABRE O GALPÃO!" % w.name) if w else "NINGUÉM QUIS... VAMOS ESPIAR!", "unit_name": unit.name, "pid": winner}])
	await _wait(1.6)
	var est_lo := 0
	var est_hi := 0
	for idx in unit.items.size():
		var it: Dictionary = unit.items[idx]
		if not _alive(t): return
		est_lo += int(it.est_lo)
		est_hi += int(it.est_hi)
		var big: bool = it.rare or it.mystery or int(it.est_hi) > 2500
		g()._emit("step", [{"kind": "item", "duration": 2.0 if big else 0.9, "item": _public_item(it), "big": big, "pid": winner, "index": idx}])
		await _wait(2.0 if big else 0.9)
	if w:
		for it in unit.items:
			w.inventory.append(it)
	unit_log.append({"winner": winner, "paid": paid, "total": int(unit.total), "name": unit.name, "number": unit.number})
	if w:
		var profit := int(unit.total) - paid
		w.stats.best_profit = maxi(int(w.stats.best_profit), profit)
		w.stats.worst_profit = mini(int(w.stats.worst_profit), profit)
	g()._emit("step", [{"kind": "summary", "duration": 3.2, "pid": winner, "paid": paid, "est_lo": est_lo, "est_hi": est_hi, "unit_name": unit.name,
		"title": ("%s pagou %s" % [w.name, Fmt.money(paid)]) if w else "Ninguém arrematou",
		"text": "Avaliação dos especialistas: %s a %s" % [Fmt.money(est_lo), Fmt.money(est_hi)]}])
	g()._broadcast_view()
	await _wait(3.2)


func _public_item(it: Dictionary) -> Dictionary:
	return {"uid": it.uid, "name": it.name, "cat": it.cat, "shape": it.shape, "color": it.color, "mystery": it.mystery, "rare": it.rare,
		"est_lo": int(it.est_lo), "est_hi": int(it.est_hi)}


# --- Venda ------------------------------------------------------------------------------

func collection_counts(p: PlayerState) -> Dictionary:
	var c := {}
	for it in p.kept:
		c[it.cat] = int(c.get(it.cat, 0)) + 1
	return c


## Categoria que o colecionador do dia está procurando (paga melhor na pechincha).
var buyer_cat := ""


## Chance do comprador aceitar o preço pedido.
static func haggle_chance(ask: int, value: int, wanted: bool) -> float:
	var v := float(value) * (1.5 if wanted else 1.0)
	return clampf(1.3 - 0.8 * float(ask) / maxf(1.0, v), 0.03, 0.95)


func _sell(t: int) -> void:
	actions.clear()
	var cats: Array = GameData.load_json("items").categories.keys().filter(func(c): return c != "lixo" and c != "especial")
	buyer_cat = str(cats[g().rng.randi() % cats.size()])
	expecting = []
	var any_items := false
	for p in g().players.list:
		if p.inventory.is_empty():
			continue
		any_items = true
		if p.is_bot or not p.connected:
			var ch := {}
			var counts := collection_counts(p)
			for it in p.inventory:
				ch[str(it.uid)] = BotBrain.sell_choice(p, it, int(counts.get(it.cat, 0)), g().rng)
				if ch[str(it.uid)] == "guardar":
					counts[it.cat] = int(counts.get(it.cat, 0)) + 1
			actions[p.id] = {"choices": ch}
			continue
		expecting.append(p.id)
		g().send_private(p.id, {"kind": "sell", "items": p.inventory.map(func(it): return _public_item(it)), "collections": collection_counts(p), "money": p.money})
	if not any_items:
		return
	_phase("sell", {"deadline_in": T_SELL, "buyer_cat": buyer_cat})
	await _wait_actions(t, T_SELL)
	if not _alive(t): return
	_phase("sell_results", {})
	await _wait(0.5)
	for p in g().players.list:
		if p.inventory.is_empty():
			continue
		var ch: Dictionary = actions.get(p.id, {}).get("choices", {})
		var rows := []
		var total := 0
		for it in p.inventory:
			var c := str(ch.get(str(it.uid), "loja"))
			var got := 0
			var label := ""
			if it.mystery:
				if c == "abrir":
					got = int(it.value)
					label = "ABRIU: " + ("VAZIO!" if got == 0 else Fmt.money(got))
				else:
					got = int(int(it.max) * 0.35 / 10) * 10
					label = "vendeu fechado: %s (valia %s)" % [Fmt.money(got), Fmt.money(int(it.value))]
			else:
				if c.begins_with("pech:"):
					var ask := int(c.substr(5))
					if g().rng.randf() < haggle_chance(ask, int(it.value), str(it.cat) == buyer_cat):
						got = ask
						label = "PECHINCHA ACEITA: " + Fmt.money(got)
						p.stats.haggles = int(p.stats.get("haggles", 0)) + 1
					else:
						got = int(int(it.value) * 0.7 / 10) * 10
						label = "comprador recusou → loja 70%%: %s" % Fmt.money(got)
					c = "-"
				match c:
					"-":
						pass
					"guardar":
						p.kept.append(it)
						label = "GUARDOU (coleção)"
					"online":
						got = int(int(it.value) * g().rng.randf_range(0.5, 1.6) / 10) * 10
						label = "leilão online: " + Fmt.money(got)
					_:
						got = int(int(it.value) * 0.85 / 10) * 10
						label = "loja: " + Fmt.money(got)
			total += got
			if int(it.value) > int(p.stats.best_item):
				p.stats.best_item = int(it.value)
				p.stats.best_item_name = str(it.name)
			rows.append([str(it.name), label, got])
		p.inventory.clear()
		g()._emit("step", [{"kind": "sales", "duration": 2.0 + rows.size() * 0.35, "pid": p.id, "title": "%s VENDEU %s" % [p.name, Fmt.money(total)], "rows": rows}])
		_money(p.id, total, "Vendas do dia %d" % _day)
		await _wait(2.0 + rows.size() * 0.35)
	g()._broadcast_view()


# --- Final -------------------------------------------------------------------------------

func _finish(t: int) -> void:
	_phase("collections", {})
	await _wait(0.5)
	for p in g().players.list:
		if p.kept.is_empty():
			continue
		var counts := collection_counts(p)
		var value := 0
		var bonus := 0
		var by_cat := {}
		for it in p.kept:
			value += int(it.value)
			by_cat[it.cat] = int(by_cat.get(it.cat, 0)) + int(it.value)
		var sets := []
		for cat in counts:
			if int(counts[cat]) >= 3 and cat != "lixo":
				bonus += int(by_cat[cat] * 0.5)
				sets.append(str(GameData.load_json("items").categories.get(cat, cat)))
		g()._emit("step", [{"kind": "collection", "duration": 3.0, "pid": p.id, "title": "COLEÇÃO DE %s: %s" % [p.name, Fmt.money(value + bonus)],
			"text": ("Coleções completas: " + ", ".join(sets) + "  (+50%)") if not sets.is_empty() else "Nenhuma coleção completa (3 do mesmo tipo)."}])
		_money(p.id, value + bonus, "Coleção")
		await _wait(3.0)
		if not _alive(t): return
	var r: Array = g().players.list.duplicate()
	r.sort_custom(func(a, b): return a.money > b.money)
	var rows := []
	for i in r.size():
		var p: PlayerState = r[i]
		rows.append({"id": p.id, "name": p.name, "character": p.character, "money": p.money, "is_bot": p.is_bot, "owner_peer": p.owner_peer, "position": i + 1, "stats": p.stats.duplicate()})
	var summary := {"ranking": rows, "winner": rows[0].id if rows.size() > 0 else -1, "awards": _awards(), "units": unit_log.size()}
	g()._broadcast_view()
	_phase("final", summary)
	g()._emit("ended", [summary])


func _awards() -> Array:
	var out := []
	var defs := [
		["MAIOR LUCRO NUM GALPÃO", "best_profit", true],
		["PIOR COMPRA", "worst_profit", false],
		["MAIOR LANCE", "biggest_bid", true],
		["ITEM MAIS VALIOSO", "best_item", true],
		["REI DOS GALPÕES", "units_won", true],
	]
	for d in defs:
		var best: PlayerState = null
		for p in g().players.list:
			var v := int(p.stats.get(d[1], 0))
			if best == null or (v > int(best.stats.get(d[1], 0)) if d[2] else v < int(best.stats.get(d[1], 0))):
				best = p
		if best == null:
			continue
		var v2 := int(best.stats.get(d[1], 0))
		if v2 == 0:
			continue
		var txt := Fmt.money(v2)
		if d[1] == "units_won":
			txt = "%d galpões" % v2
		elif d[1] == "best_item":
			txt = "%s (%s)" % [best.stats.best_item_name, Fmt.money(v2)]
		elif d[1] == "worst_profit":
			txt = "prejuízo de " + Fmt.money(-v2)
		out.append({"title": d[0], "pid": best.id, "name": best.name, "character": best.character, "value": txt})
	return out
