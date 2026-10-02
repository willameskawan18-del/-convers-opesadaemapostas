extends SceneTree
## Robô que joga a campanha inteira para validar o balanceamento.
## Executar: godot --headless --path game -s res://tests/campaign_bot.gd

var sim: Simulation
var log_days := {}


func _init() -> void:
	sim = Simulation.new()
	sim.auto_decide = true
	sim.new_game("Bot", "Bot Bet", 77)
	var last_stage := 0
	var last_chapter := 0
	for day in 140:
		_play_day()
		var r := sim.last_report
		if sim.business.stage != last_stage or sim.missions.chapter_index != last_chapter or day % 10 == 0:
			print("dia %3d | cap %2d | estágio %d | nível %2d | caixa %s | patrimônio %s | rep %d | clientes %d | lucro %s | share %s" % [
				sim.time.day, sim.missions.chapter_index + 1, sim.business.stage, sim.progression.level, Fmt.money(sim.economy.cash),
				Fmt.money(sim.economy.net_worth()), int(sim.reputation.value), int(r.get("served", 0)), Fmt.money(float(r.get("biz_profit", 0))),
				Fmt.pct(sim.competition.player_share(), 0)])
			last_stage = sim.business.stage
			last_chapter = sim.missions.chapter_index
		if sim.campaign_complete:
			print(">>> CAMPANHA CONCLUÍDA no dia %d" % sim.time.day)
			break
	print("falências: ", sim.stat("bankruptcies"), "  capítulo final: ", sim.missions.chapter_index + 1)
	print("livro: apostas %s  prêmios %s  margem real %s" % [Fmt.money(sim.stat("book_stakes")), Fmt.money(sim.stat("book_payouts")), Fmt.pct(1.0 - sim.stat("book_payouts") / maxf(1.0, sim.stat("book_stakes")))])
	var by_type := {}
	for id in sim.customers.pool:
		var p: Dictionary = sim.customers.pool[id]
		var t: String = p.type
		if not by_type.has(t): by_type[t] = [0.0, 0.0]
		by_type[t][0] += float(p.staked)
		by_type[t][1] += float(p.net)
	for t in by_type:
		print("  %-13s apostou %s  resultado do cliente %s" % [t, Fmt.money(by_type[t][0]), Fmt.signed_money(by_type[t][1])])
	sim.free()
	quit()


func _play_day() -> void:
	var day := sim.time.day
	while sim.time.day == day:
		_act()
		sim.player_at_counter = sim.has_business() and sim.employees.count_role("atendente") < 2 and sim.time.minute >= 540 and sim.time.minute < 1320
		if not sim.has_business() and not sim.jobs.is_busy():
			for j in ["auxiliar", "limpeza", "entrega", "carregar", "panfletos", "transporte"]:
				if sim.jobs.availability(sim.jobs.job_data(j)) == "":
					sim.jobs.start(j)
					if sim.jobs.active.type == "delivery":
						for stop in sim.jobs.active.stops.duplicate():
							sim.advance(15)
							sim.jobs.reach_stop(stop)
					break
		sim.advance(30)


func _act() -> void:
	var b := sim.business
	var s := sim
	if s.stat("bets_placed") < 1 and s.economy.cash >= 20:
		var evs := s.betting.open_events()
		if evs.size() > 0:
			s.betting.place_player_bet(evs[0].id, 0, 10)
	if not s.licenses.has("basica"):
		s.licenses.buy("basica")
	if not s.has_business() and s.licenses.has("basica") and s.economy.cash > 3500:
		s.properties.rent("sala_comercio")
	if not s.has_business():
		return
	for e in b.equipment:
		if e.broken:
			b.repair(int(e.uid))
	b.set_max_stake(150.0 * b.stage * b.stage)
	var ex := s.betting.total_exposure()
	var reserve := maxf(3000.0 * b.stage * b.stage, float(ex.worst_net) * 1.2 + 500.0 * b.stage)
	if s.economy.cash < 0.0:
		for o in ["micro", "pme", "expansao", "corporativo"]:
			if s.loans.offer_status(GameData.find("loans", "offers", o)) == "":
				s.loans.take(o)
				break
	if b.count_category("counter") < b.counters() and s.economy.cash > 600:
		b.buy_equipment("balcao_pro" if b.stage >= 2 else "balcao_simples")
	if b.count_category("computer") < b.count_category("counter") and s.economy.cash > 1200:
		b.buy_equipment("computador_rapido" if s.progression.level >= 3 and s.economy.cash > 6000 else "computador")
	for id in ["cadeiras", "tv", "caixa", "impressora", "camera", "camera", "alarme", "telao", "sofa", "sistema_gestao", "terminal", "area_vip"]:
		if b.buy_block_reason(id) == "" and s.economy.cash - b.price_of(id) > reserve:
			b.buy_equipment(id)
	# Equipe
	s.employees.refresh_candidates()
	var wanted := {"atendente": b.counters() if (b.stage >= 2 or s.economy.cash > 10000) else 0, "caixa": 1 if b.stage >= 2 else 0, "seguranca": 1 if b.stage >= 2 else 0, "analista": 1 if b.stage >= 3 else 0,
		"gerente": 1 if b.stage >= 3 else 0, "especialista": 1 if b.stage >= 4 else 0, "crupie": _tables()}
	for c in s.employees.candidates.duplicate():
		var role := str(c.role)
		if s.employees.count_role(role) < int(wanted.get(role, 0)) and s.economy.cash > float(c.salary) * 15 and s.employees.hire_block_reason(c) == "":
			s.employees.hire(str(c.id))
	if s.employees.candidates.size() < 3 or s.time.day % 2 == 0:
		s.employees.refresh_candidates(true)
	# Licenças
	for l in ["comercial", "digital", "grande", "entretenimento", "cassino"]:
		if s.licenses.can_buy(l) and s.economy.cash - float(s.licenses.data(l).cost) > reserve:
			s.licenses.buy(l)
	# Expansão
	var nd := b.stage_data(b.stage + 1)
	if not nd.is_empty():
		var pid := b.property_for_stage(b.stage + 1)
		if pid != b.property_id and not s.properties.contracts.has(pid):
			if s.properties.data(pid).get("rent", 0) > 0:
				if s.economy.cash > float(nd.upgrade_cost) + float(s.properties.data(pid).deposit) + reserve:
					s.properties.rent(pid)
			elif s.economy.cash > s.properties.price(pid) + float(nd.upgrade_cost) + reserve:
				s.properties.buy(pid)
		if b.can_upgrade() and s.economy.cash - float(nd.upgrade_cost) > reserve:
			b.upgrade()
	# Comprar o imóvel atual quando sobra muito dinheiro
	if s.properties.contracts.get(b.property_id, "") == "rented" and s.economy.cash > s.properties.price(b.property_id) * 1.5 + reserve * 3:
		s.properties.buy(b.property_id)
	# Cassino
	for id in ["caca_niquel", "video_slot", "blackjack", "roleta", "bacara", "aviaozinho", "jackpot", "poquer"]:
		if b.buy_block_reason(id) == "" and s.economy.cash - b.price_of(id) > reserve * 2:
			b.buy_equipment(id)
	# Online
	if s.online.launch_block_reason() == "" and s.economy.cash > 80000:
		s.online.launch()
	if s.online.open:
		s.online.support = int(ceil(s.online.users / 400.0))
		s.online.security_level = 1 if s.online.users > 200 else 0
		s.online.marketing = 2000.0 if s.economy.cash > 100000 else 0.0
		if s.online.users > s.online.capacity() * 0.8 and b.buy_block_reason("servidor") == "" and s.economy.cash > 40000:
			b.buy_equipment("servidor")
		var nl := s.online.level_data(s.online.site_level + 1)
		if not nl.is_empty() and s.economy.cash > float(nl.upgrade_cost) * 3:
			s.online.upgrade()
	# Promoção ocasional
	if s.time.minute == 600 and s.economy.cash > reserve * 3 and s.time.day % 3 == 0:
		for p in ["noite_classico", "panfletos", "sorteio", "outdoor", "tv_local"]:
			if s.promotions.block_reason(p) == "":
				s.promotions.launch(p)
				break
	# Aquisições
	for c in s.competition.comps:
		if c.status == "active" and s.competition.acquire_block_reason(c) == "" and s.economy.cash > s.competition.acquisition_price(c) * 2:
			s.competition.acquire(str(c.id))


func _tables() -> int:
	var n := 0
	for e in sim.business.equipment:
		if sim.business.item_data(str(e.id)).get("dealer", false):
			n += 1
	return n
