extends SceneTree
## Testes da lógica (sem interface): godot --headless --path . -s res://tests/run_tests.gd

var checks := 0
var fails := 0


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  FALHOU: ", msg)


func _init() -> void:
	print("=== ALL WIN — testes ===")
	test_money()
	test_players()
	test_sequence()
	for i in 40:
		test_challenges(i)
	print("\n=== %d verificações, %d falhas ===" % [checks, fails])
	quit(1 if fails > 0 else 0)


func make_ctx(n: int, seed_v: int) -> MatchContext:
	var pm := PlayerManager.new()
	var chars := ["sortudo", "azarado", "rico", "trapaceiro", "apostador", "genio", "medroso", "maluco"]
	for i in n:
		pm.add("P%d" % i, chars[i % 8], true)
	var ctx := MatchContext.new()
	ctx.pm = pm
	ctx.money = MoneyManager.new(pm)
	ctx.rng.seed = seed_v
	ctx.money.set_all(1000, "inicial")
	return ctx


func test_money() -> void:
	print("- dinheiro")
	var pm := PlayerManager.new()
	var a := pm.add("A", "rico", false)
	var b := pm.add("B", "maluco", false)
	var mm := MoneyManager.new(pm)
	var events := []
	mm.money_changed.connect(func(pid, o, n, r): events.append([pid, o, n]))
	mm.set_all(1000, "inicial")
	ok(a.money == 1000 and b.money == 1000, "dinheiro inicial 1000")
	mm.earn(a.id, 500, "x")
	ok(a.money == 1500, "ganhar")
	ok(mm.lose(b.id, 10000, "x") == 6000 and b.money == -5000, "dívida limitada a -$5.000")
	mm.change(b.id, 6000, "x")
	mm.multiply(a.id, 2.0, "x")
	ok(a.money == 3000, "multiplicar")
	ok(mm.transfer(a.id, b.id, 1000, "x") == 1000 and a.money == 2000 and b.money == 2000, "transferir")
	mm.zero(a.id, "x")
	ok(a.money == 0, "zerar")
	ok(events.size() == 9, "sinal a cada mudança (%d)" % events.size())
	ok(mm.history.size() == 9, "histórico")
	ok(Fmt.money(12450) == "$12.450" and Fmt.delta(-1000) == "-$1.000" and Fmt.money(0) == "$0", "formatação")


func test_players() -> void:
	print("- jogadores e ranking")
	var pm := PlayerManager.new()
	for i in 10:
		pm.add("P", "rico", true)
	ok(pm.count() == 8, "máximo de 8 jogadores")
	pm.players[3].money = 500
	pm.players[5].money = 500
	pm.players[0].money = 100
	ok(pm.ranking()[0].id == pm.players[3].id, "ranking por dinheiro, empate por ordem")
	ok(pm.position_of(pm.players[5].id) == 1, "empate divide posição")
	ok(pm.position_of(pm.players[0].id) == 3, "posição do terceiro")
	pm.remove(pm.players[0].id)
	ok(pm.count() == 7, "remover")


func test_sequence() -> void:
	print("- categorias e sorteio de desafios")
	var mm := MinigameManager.new()
	for cat in ["conhecimento", "habilidade", "risco", "social"]:
		ok(mm.rotation_ids(cat).size() == 5, "5 desafios em %s (%d)" % [cat, mm.rotation_ids(cat).size()])
	ok(mm.get_def("allwin") != null and mm.get_def("evento") != null, "ALL WIN e evento registrados")
	var rng := RandomNumberGenerator.new()
	for s in 30:
		rng.seed = s
		var rm := RoundManager.new()
		rm.setup(9, mm, rng, ["quiz", "portas"])
		var ids := []
		while rm.has_next():
			var id := rm.next(rng)
			ok(mm.get_def(id).category == rm.category() or rm.category() == "grande_risco", "categoria certa (%s em %s)" % [id, rm.category()])
			ids.append(id)
		ok(rm.categories[8] == "grande_risco" and rm.display_total() == 10, "rodada 9 = grande risco, 10 = ALL WIN")
		ok(ids.size() == 9 and not ids.has("quiz") and not ids.has("portas"), "evita desafios da partida anterior (%s)" % str(ids))
		var uniq := {}
		for id in ids:
			uniq[id] = true
		ok(uniq.size() == 9, "sem repetir na partida")
		ok(not ids.slice(0, 3).has("rei"), "DERRUBE O REI só depois da rodada 4")
	var bank: Dictionary = GameData.load_json("questions")
	for q in bank.questions:
		ok(q.a.size() == 4 and int(q.c) >= 0 and int(q.c) < 4 and int(q.d) in [1, 2, 3], "pergunta válida: " + str(q.q))
	ok(bank.preferences.size() >= 20, "perguntas do hot seat")


const ALL_IDS := ["quiz", "relampago", "matematica", "detetive", "mentiroso", "reacao", "precisao", "tiro", "memoria", "corrida",
	"portas", "bomba", "escada", "cartas", "leilao", "risco", "bluff", "votacao", "alianca", "hotseat", "roubo", "rei", "evento", "allwin"]


func test_challenges(seed_v: int) -> void:
	var mm := MinigameManager.new()
	var n := 2 + seed_v % 7
	for id in ALL_IDS:
		var ctx := make_ctx(n, seed_v * 13 + id.length())
		ctx.round_index = 1 + seed_v % 9
		if seed_v % 5 == 0:
			ctx.money.change(1, -6000, "teste")   # jogador endividado também precisa funcionar
		if seed_v % 3 == 0:
			ctx.money.change(2, 9000, "teste")
		var c := mm.create(id, ctx)
		ok(c != null, "cria " + id)
		var guard := 0
		while true:
			guard += 1
			if guard > 12:
				ok(false, id + ": etapas infinitas")
				break
			if c.needs_decision():
				for pid in c.deciders():
					var a := c.bot_action(pid)
					ok(c.submit(pid, a), "%s: ação de bot válida (etapa %d): %s" % [id, c.stage, str(a)])
					var info := c.private_info(pid)
					ok(info is Dictionary, id + ": info privada")
				var d0: Array = c.deciders()
				if d0.size() > 0:
					ok(not c.submit(d0[0], c.bot_action(d0[0])), "%s: não aceita duas ações" % id)
				ok(c.all_submitted(), id + ": todos enviaram")
			var steps := c.resolve()
			ok(steps.size() > 0, "%s: tem revelação (etapa %d)" % [id, c.stage])
			for s in steps:
				ok(float(s.duration) > 0.0, id + ": passo com duração")
				for m in s.get("money", []):
					ctx.money.change(int(m[0]), int(m[1]), str(m[2]))
			if c.has_next_stage():
				c.next_stage()
			else:
				break
		for p in ctx.pm.players:
			ok(p.money >= -MoneyManager.DEBT_LIMIT, id + ": dívida limitada")
		if id == "allwin":
			for pid in c.participants:
				ok(c.actions[pid].choice != "allwin" or c.outcomes.has(pid), "allwin: resultado para quem arriscou")
	# Ações inválidas são recusadas
	var ctx2 := make_ctx(3, seed_v)
	var portas := mm.create("portas", ctx2)
	ok(not portas.submit(1, {"choice": "Z"}), "porta inválida recusada")
	var leilao := mm.create("leilao", ctx2)
	ok(not leilao.submit(1, {"bid": 999999}), "lance acima do saldo recusado")
	ok(not leilao.submit(2, {"bid": 1}), "lance abaixo do mínimo recusado")
	ok(leilao.submit(3, {"bid": 1000}), "lance com todo o saldo aceito")
	var quiz := mm.create("quiz", ctx2)
	ok(not quiz.submit(1, {"choice": "impossivel"}), "dificuldade inválida recusada")
	# SAFE CARD protege numa prova de risco
	var ctx3 := make_ctx(2, seed_v)
	ctx3.pm.players[0].items.shield = 1
	var esc := mm.create("escada", ctx3)
	ok(esc.submit(1, {"choice": "up", "shield": true}), "usar SAFE CARD")
	ok(esc.shields.has(1) and ctx3.pm.players[0].shields() == 0, "SAFE CARD consumida")
