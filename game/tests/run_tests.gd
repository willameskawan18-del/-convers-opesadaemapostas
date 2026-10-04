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
	ok(mm.lose(b.id, 5000, "x") == 1000 and b.money == 0, "perder é limitado ao saldo")
	mm.multiply(a.id, 2.0, "x")
	ok(a.money == 3000, "multiplicar")
	ok(mm.transfer(a.id, b.id, 1000, "x") == 1000 and a.money == 2000 and b.money == 1000, "transferir")
	mm.zero(a.id, "x")
	ok(a.money == 0, "zerar")
	ok(events.size() == 8, "sinal a cada mudança (%d)" % events.size())
	ok(mm.history.size() == 8, "histórico")
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
	print("- sequência de desafios")
	var mm := MinigameManager.new()
	ok(mm.rotation_ids().size() == 5, "5 desafios no sorteio")
	ok(mm.get_def("allwin") != null and mm.get_def("evento") != null, "ALL WIN e evento registrados")
	var rng := RandomNumberGenerator.new()
	for s in 30:
		rng.seed = s
		var seq := mm.build_sequence(10, rng)
		var good := seq.size() == 10
		for i in range(1, seq.size()):
			if seq[i] == seq[i - 1]:
				good = false
		var first5 := {}
		for i in 5:
			first5[seq[i]] = true
		ok(good and first5.size() == 5, "sequência sem repetição seguida e com todos (%s)" % str(seq))
	var rm := RoundManager.new()
	rm.setup(8, mm, rng)
	ok(rm.event_after == [3, 5], "eventos após rodadas 3 e 5 (%s)" % str(rm.event_after))


func test_challenges(seed_v: int) -> void:
	var mm := MinigameManager.new()
	var n := 2 + seed_v % 7
	for id in ["portas", "risco", "reacao", "leilao", "bluff", "evento", "allwin"]:
		var ctx := make_ctx(n, seed_v * 13 + id.length())
		ctx.round_index = 1 + seed_v % 8
		if seed_v % 5 == 0:
			ctx.money.zero(1, "teste")   # jogador zerado também precisa funcionar
		var c := mm.create(id, ctx)
		ok(c != null, "cria " + id)
		if c.needs_decision():
			for pid in c.participants:
				ok(c.submit(pid, c.bot_action(pid)), "%s: ação de bot válida" % id)
			ok(not c.submit(c.participants[0], c.bot_action(c.participants[0])), "%s: não aceita duas ações" % id)
			ok(c.all_submitted(), id + ": todos enviaram")
		var before := ctx.money.total()
		var steps := c.resolve()
		ok(steps.size() > 0, id + ": tem revelação")
		var expected := 0
		for s in steps:
			ok(float(s.duration) > 0.0, id + ": passo com duração")
			for m in s.get("money", []):
				ctx.money.change(int(m[0]), int(m[1]), str(m[2]))
		for p in ctx.pm.players:
			ok(p.money >= 0, id + ": dinheiro nunca negativo")
		if id == "allwin":
			for pid in c.participants:
				ok(c.actions[pid].choice != "allwin" or c.outcomes.has(pid), "allwin: resultado para quem arriscou")
	# Ação inválida é recusada
	var ctx2 := make_ctx(3, seed_v)
	var portas := mm.create("portas", ctx2)
	ok(not portas.submit(1, {"choice": "Z"}), "porta inválida recusada")
	var leilao := mm.create("leilao", ctx2)
	ok(not leilao.submit(1, {"bid": 999999}), "lance acima do saldo recusado")
	ok(leilao.submit(1, {"bid": 1000}), "lance com todo o saldo aceito")
