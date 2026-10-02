class_name CasinoLogic
## Regras e pagamentos dos jogos de cassino (todos fictícios, dinheiro do jogo).
## Funções puras: recebem o RNG e devolvem resultados. Os pagamentos estão calibrados
## para uma vantagem da casa realista (ver tests/run_tests.gd: test_casino_rtp).

const SUITS := ["espadas", "copas", "ouros", "paus"]
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

# --- Catálogo de jogos jogáveis ---------------------------------------------------
const GAMES := {
	"caca_niquel": {"name": "Caça-níquel Clássico", "kind": "Máquina", "rtp": "92,7%"},
	"video_slot": {"name": "Tesouro Dourado", "kind": "Máquina", "rtp": "≈94%"},
	"jackpot": {"name": "Jackpot Progressivo", "kind": "Máquina", "rtp": "≈88% + pote"},
	"video_poker": {"name": "Video Poker", "kind": "Máquina", "rtp": "até 99%"},
	"blackjack": {"name": "21 (Blackjack)", "kind": "Mesa", "rtp": "≈99%"},
	"roleta": {"name": "Roleta Europeia", "kind": "Mesa", "rtp": "97,3%"},
	"bacara": {"name": "Bacará", "kind": "Mesa", "rtp": "98,8%"},
	"bac_dados": {"name": "Bacará de Dados (Bac Bo)", "kind": "Mesa", "rtp": "≈98,9%"},
	"dragao_tigre": {"name": "Dragão & Tigre", "kind": "Mesa", "rtp": "≈96%"},
	"sic_bo": {"name": "Sic Bo", "kind": "Mesa", "rtp": "97,2%"},
	"roda": {"name": "Roda da Fortuna", "kind": "Show", "rtp": "≈89%"},
	"aviaozinho": {"name": "Aviãozinho", "kind": "Crash", "rtp": "97%"},
	"minas": {"name": "Campo Minado", "kind": "Instantâneo", "rtp": "97%"},
	"plinko": {"name": "Plinko", "kind": "Instantâneo", "rtp": "99%"},
	"dados": {"name": "Dados Acima/Abaixo", "kind": "Instantâneo", "rtp": "98%"},
	"hilo": {"name": "Maior ou Menor", "kind": "Cartas", "rtp": "97%"},
	"keno": {"name": "Keno", "kind": "Sorteio", "rtp": "≈88%"},
	"bingo": {"name": "Bingo", "kind": "Sorteio", "rtp": "≈91%"},
	"raspadinha": {"name": "Raspadinha", "kind": "Instantâneo", "rtp": "84%"},
}


static func rank_of(card: int) -> int:
	return card % 13


static func suit_of(card: int) -> int:
	return card / 13


static func card_name(card: int) -> String:
	return "%s de %s" % [RANKS[rank_of(card)], SUITS[suit_of(card)]]


static func draw(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, 51)


static func shuffled_deck(rng: RandomNumberGenerator) -> Array:
	var d: Array = []
	for i in 52:
		d.append(i)
	for i in range(51, 0, -1):
		var j := rng.randi_range(0, i)
		var t = d[i]
		d[i] = d[j]
		d[j] = t
	return d


# --- Caça-níquel clássico -------------------------------------------------------
const SLOT_SYMBOLS := ["CEREJA", "LIMÃO", "LARANJA", "SINO", "BAR", "7"]
const SLOT_WEIGHTS := [30, 25, 20, 12, 8, 5]
const SLOT_PAY3 := [5, 8, 12, 25, 60, 200]
const SLOT_COLORS := [Color("e74c3c"), Color("f1c40f"), Color("e67e22"), Color("f5c542"), Color("ecf0f1"), Color("ff3b6b")]


static func _weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	var r := rng.randi_range(1, total)
	for i in weights.size():
		r -= int(weights[i])
		if r <= 0:
			return i
	return weights.size() - 1


## Retorna {reels: [idx,idx,idx], mult}
static func slot_spin(rng: RandomNumberGenerator) -> Dictionary:
	var r := [_weighted(rng, SLOT_WEIGHTS), _weighted(rng, SLOT_WEIGHTS), _weighted(rng, SLOT_WEIGHTS)]
	var mult := 0.0
	if r[0] == r[1] and r[1] == r[2]:
		mult = SLOT_PAY3[r[0]]
	else:
		var cherries := r.count(0)
		if cherries == 2:
			mult = 2.5
	return {"reels": r, "mult": mult}


# --- Video slot com curinga ---------------------------------------------------------
const VS_SYMBOLS := ["MOEDA", "TAÇA", "COROA", "BAÚ", "DIAMANTE", "CURINGA"]
const VS_WEIGHTS := [30, 22, 15, 10, 6, 5]
const VS_PAY := [3.5, 7.0, 14.0, 32.0, 80.0, 280.0]
const VS_COLORS := [Color("f5c542"), Color("c0a062"), Color("e1b12c"), Color("8e5b34"), Color("4ea8ff"), Color("c77dff")]


static func video_slot_spin(rng: RandomNumberGenerator) -> Dictionary:
	var r := [_weighted(rng, VS_WEIGHTS), _weighted(rng, VS_WEIGHTS), _weighted(rng, VS_WEIGHTS)]
	var non_wild: Array = r.filter(func(x): return x != 5)
	var mult := 0.0
	if non_wild.is_empty():
		mult = VS_PAY[5]
	elif non_wild.count(non_wild[0]) == non_wild.size():
		mult = VS_PAY[non_wild[0]]
	return {"reels": r, "mult": mult}


# --- Jackpot progressivo (3 diamantes = pote) -------------------------------------------
const JP_SYMBOLS := ["MOEDA", "SINO", "TREVO", "ESTRELA", "DIAMANTE"]
const JP_WEIGHTS := [40, 28, 18, 11, 3]
const JP_PAY3 := [6.0, 12.0, 30.0, 90.0, -1.0]
const JP_COLORS := [Color("f5c542"), Color("f39c12"), Color("2ecc71"), Color("74b9ff"), Color("00d2ff")]


static func jackpot_spin(rng: RandomNumberGenerator) -> Dictionary:
	var r := [_weighted(rng, JP_WEIGHTS), _weighted(rng, JP_WEIGHTS), _weighted(rng, JP_WEIGHTS)]
	var mult := 0.0
	var pot := false
	if r[0] == r[1] and r[1] == r[2]:
		if r[0] == 4:
			pot = true
		else:
			mult = JP_PAY3[r[0]]
	elif r.count(0) == 2:
		mult = 1.5
	return {"reels": r, "mult": mult, "pot": pot}


# --- 21 ------------------------------------------------------------------------------

static func bj_value(cards: Array) -> int:
	var total := 0
	var aces := 0
	for c in cards:
		var r := rank_of(int(c))
		if r == 0:
			aces += 1
			total += 11
		elif r >= 9:
			total += 10
		else:
			total += r + 1
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
	return total


static func bj_is_blackjack(cards: Array) -> bool:
	return cards.size() == 2 and bj_value(cards) == 21


## Crupiê compra até 17 (para no 17 macio).
static func bj_dealer_play(rng: RandomNumberGenerator, dealer: Array) -> Array:
	while bj_value(dealer) < 17:
		dealer.append(draw(rng))
	return dealer


## Multiplicador de retorno (já inclui a aposta): 0 perdeu, 1 empate, 2 venceu, 2.5 blackjack.
static func bj_settle(player: Array, dealer: Array) -> float:
	var pv := bj_value(player)
	var dv := bj_value(dealer)
	if pv > 21:
		return 0.0
	if bj_is_blackjack(player) and not bj_is_blackjack(dealer):
		return 2.5
	if bj_is_blackjack(dealer) and not bj_is_blackjack(player):
		return 0.0
	if dv > 21 or pv > dv:
		return 2.0
	if pv == dv:
		return 1.0
	return 0.0


# --- Roleta europeia -----------------------------------------------------------------
const RED_NUMBERS := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]


static func roulette_color(n: int) -> String:
	if n == 0:
		return "verde"
	return "vermelho" if n in RED_NUMBERS else "preto"


## bet: "vermelho","preto","par","impar","baixo","alto","d1","d2","d3" ou "n<numero>"
static func roulette_payout(bet: String, n: int) -> float:
	if bet.begins_with("n"):
		return 36.0 if int(bet.substr(1)) == n else 0.0
	if n == 0:
		return 0.0
	match bet:
		"vermelho": return 2.0 if roulette_color(n) == "vermelho" else 0.0
		"preto": return 2.0 if roulette_color(n) == "preto" else 0.0
		"par": return 2.0 if n % 2 == 0 else 0.0
		"impar": return 2.0 if n % 2 == 1 else 0.0
		"baixo": return 2.0 if n <= 18 else 0.0
		"alto": return 2.0 if n >= 19 else 0.0
		"d1": return 3.0 if n <= 12 else 0.0
		"d2": return 3.0 if n >= 13 and n <= 24 else 0.0
		"d3": return 3.0 if n >= 25 else 0.0
	return 0.0


# --- Bacará ----------------------------------------------------------------------------

static func bac_value(cards: Array) -> int:
	var t := 0
	for c in cards:
		var r := rank_of(int(c))
		t += 0 if r >= 9 else r + 1
	return t % 10


## Distribui a mão completa com a regra da terceira carta.
static func baccarat_deal(rng: RandomNumberGenerator) -> Dictionary:
	var p := [draw(rng), draw(rng)]
	var b := [draw(rng), draw(rng)]
	var pv := bac_value(p)
	var bv := bac_value(b)
	if pv < 8 and bv < 8:
		var third := -1
		if pv <= 5:
			third = draw(rng)
			p.append(third)
		var bv2 := bac_value(b)
		var banker_draws := false
		if third < 0:
			banker_draws = bv2 <= 5
		else:
			var t := 0 if rank_of(third) >= 9 else rank_of(third) + 1
			if bv2 <= 2: banker_draws = true
			elif bv2 == 3: banker_draws = t != 8
			elif bv2 == 4: banker_draws = t >= 2 and t <= 7
			elif bv2 == 5: banker_draws = t >= 4 and t <= 7
			elif bv2 == 6: banker_draws = t == 6 or t == 7
		if banker_draws:
			b.append(draw(rng))
	var fp := bac_value(p)
	var fb := bac_value(b)
	var winner := "empate" if fp == fb else ("jogador" if fp > fb else "banca")
	return {"player": p, "banker": b, "pv": fp, "bv": fb, "winner": winner}


## Retorno total: jogador 2x, banca 1.95x (comissão 5%), empate 9x (aposta principal devolvida no empate).
static func baccarat_payout(bet: String, winner: String) -> float:
	if winner == "empate":
		return 9.0 if bet == "empate" else 1.0
	if bet == winner:
		return 2.0 if bet == "jogador" else 1.95
	return 0.0


# --- Bacará de dados (Bac Bo) -------------------------------------------------------------

static func bac_dice(rng: RandomNumberGenerator) -> Dictionary:
	var p := [rng.randi_range(1, 6), rng.randi_range(1, 6)]
	var b := [rng.randi_range(1, 6), rng.randi_range(1, 6)]
	var ps: int = p[0] + p[1]
	var bs: int = b[0] + b[1]
	return {"player": p, "banker": b, "ps": ps, "bs": bs, "winner": "empate" if ps == bs else ("jogador" if ps > bs else "banca")}


## No empate, apostas em Jogador/Banca recebem 90% de volta; Empate paga 7 para 1.
static func bac_dice_payout(bet: String, winner: String) -> float:
	if winner == "empate":
		return 8.0 if bet == "empate" else 0.9
	return 2.0 if bet == winner else 0.0


# --- Dragão & Tigre --------------------------------------------------------------------------

static func dragon_tiger(rng: RandomNumberGenerator) -> Dictionary:
	var d := draw(rng)
	var t := draw(rng)
	var dr := rank_of(d)
	var tr := rank_of(t)
	return {"dragon": d, "tiger": t, "winner": "empate" if dr == tr else ("dragao" if dr > tr else "tigre")}


static func dragon_tiger_payout(bet: String, winner: String) -> float:
	if winner == "empate":
		return 12.0 if bet == "empate" else 0.5
	return 2.0 if bet == winner else 0.0


# --- Sic Bo -----------------------------------------------------------------------------

static func sic_bo_roll(rng: RandomNumberGenerator) -> Array:
	return [rng.randi_range(1, 6), rng.randi_range(1, 6), rng.randi_range(1, 6)]


## bet: "pequeno" (4-10), "grande" (11-17), "trinca" (qualquer trinca 30:1), "f<1-6>" (face: 1:1, 2:1, 3:1)
static func sic_bo_payout(bet: String, d: Array) -> float:
	var total: int = d[0] + d[1] + d[2]
	var triple: bool = d[0] == d[1] and d[1] == d[2]
	match bet:
		"pequeno": return 2.0 if total >= 4 and total <= 10 and not triple else 0.0
		"grande": return 2.0 if total >= 11 and total <= 17 and not triple else 0.0
		"trinca": return 31.0 if triple else 0.0
	if bet.begins_with("f"):
		var face := int(bet.substr(1))
		var n := d.count(face)
		return 0.0 if n == 0 else float(n + 1)
	return 0.0


# --- Roda da Fortuna ----------------------------------------------------------------------
const WHEEL_SEGMENTS := {"1x": [24, 2.0], "2x": [15, 3.0], "5x": [7, 6.0], "10x": [4, 11.0], "20x": [2, 21.0], "40x": [2, 41.0]}


static func wheel_spin(rng: RandomNumberGenerator) -> String:
	var keys := WHEEL_SEGMENTS.keys()
	var weights: Array = keys.map(func(k): return WHEEL_SEGMENTS[k][0])
	return keys[_weighted(rng, weights)]


# --- Aviãozinho (crash) -----------------------------------------------------------------------

## P(multiplicador >= x) = 0.97 / x  → retorno esperado de 97% para qualquer estratégia.
static func crash_point(rng: RandomNumberGenerator) -> float:
	var u := rng.randf()
	return maxf(1.0, floorf(0.97 / maxf(1.0 - u, 0.0001) * 100.0) / 100.0)


static func crash_multiplier_at(seconds: float) -> float:
	return exp(0.11 * seconds)


# --- Campo minado ------------------------------------------------------------------------------

static func mines_layout(rng: RandomNumberGenerator, mines: int) -> Array:
	var cells: Array = []
	for i in 25:
		cells.append(i)
	var out: Array = []
	for k in mines:
		var j := rng.randi_range(0, cells.size() - 1)
		out.append(cells[j])
		cells.remove_at(j)
	return out


static func _comb(n: int, k: int) -> float:
	if k < 0 or k > n:
		return 0.0
	var r := 1.0
	for i in k:
		r = r * float(n - i) / float(i + 1)
	return r


static func mines_multiplier(mines: int, revealed: int) -> float:
	if revealed <= 0:
		return 1.0
	var p := _comb(25 - mines, revealed) / _comb(25, revealed)
	return floorf(0.97 / p * 100.0) / 100.0


# --- Plinko -----------------------------------------------------------------------------------
const PLINKO_MULTS := [5.6, 2.1, 1.1, 1.0, 0.5, 1.0, 1.1, 2.1, 5.6]


static func plinko_drop(rng: RandomNumberGenerator) -> Array:
	var path: Array = []
	for i in 8:
		path.append(rng.randi_range(0, 1))
	return path


# --- Dados acima/abaixo ---------------------------------------------------------------------

static func dice_win_chance(target: int, over: bool) -> float:
	return (99.0 - target) / 100.0 if over else target / 100.0


static func dice_multiplier(target: int, over: bool) -> float:
	return floorf(0.98 / maxf(dice_win_chance(target, over), 0.01) * 100.0) / 100.0


# --- Maior ou menor -----------------------------------------------------------------------------

## Chance de acerto de "maior" ou "menor" (empate perde) a partir do valor atual (A=1 ... K=13).
static func hilo_chance(rank: int, higher: bool) -> float:
	var v := rank + 1
	return (13.0 - v) / 13.0 if higher else (v - 1.0) / 13.0


static func hilo_step_mult(rank: int, higher: bool) -> float:
	var c := hilo_chance(rank, higher)
	return 0.0 if c <= 0.0 else floorf(0.97 / c * 100.0) / 100.0


# --- Keno (40 números, 10 sorteados) ----------------------------------------------------------
const KENO_PAY := {1: {1: 3.6}, 2: {2: 12.0, 1: 0.5}, 3: {3: 46.0, 2: 2.5}, 4: {4: 100.0, 3: 8.0, 2: 1.5}, 5: {5: 400.0, 4: 25.0, 3: 4.0, 2: 0.6}}


static func keno_draw(rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for i in range(1, 41):
		pool.append(i)
	var out: Array = []
	for k in 10:
		var j := rng.randi_range(0, pool.size() - 1)
		out.append(pool[j])
		pool.remove_at(j)
	out.sort()
	return out


static func keno_payout(picks: Array, drawn: Array) -> float:
	var hits := 0
	for p in picks:
		if p in drawn:
			hits += 1
	var table: Dictionary = KENO_PAY.get(picks.size(), {})
	return float(table.get(hits, 0.0))


# --- Bingo (cartela de 15 números de 1 a 75, 30 bolas) -----------------------------------------
const BINGO_PAY := {8: 1.5, 9: 3.0, 10: 10.0, 11: 40.0, 12: 200.0, 13: 2000.0, 14: 20000.0, 15: 200000.0}


static func bingo_card(rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for i in range(1, 76):
		pool.append(i)
	var out: Array = []
	for k in 15:
		var j := rng.randi_range(0, pool.size() - 1)
		out.append(pool[j])
		pool.remove_at(j)
	out.sort()
	return out


static func bingo_balls(rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for i in range(1, 76):
		pool.append(i)
	var out: Array = []
	for k in 30:
		var j := rng.randi_range(0, pool.size() - 1)
		out.append(pool[j])
		pool.remove_at(j)
	return out


# --- Raspadinha -----------------------------------------------------------------------------------
const SCRATCH_PRIZES := [[500.0, 0.0001], [50.0, 0.002], [10.0, 0.015], [5.0, 0.04], [2.0, 0.08], [1.0, 0.18]]
const SCRATCH_SYMBOLS := ["TREVO", "ESTRELA", "MOEDA", "COROA", "SINO", "DIAMANTE"]


static func scratch(rng: RandomNumberGenerator) -> Dictionary:
	var r := rng.randf()
	var mult := 0.0
	var tier := -1
	for i in SCRATCH_PRIZES.size():
		r -= float(SCRATCH_PRIZES[i][1])
		if r <= 0.0:
			mult = float(SCRATCH_PRIZES[i][0])
			tier = i
			break
	# Monta a cartela: 3 símbolos iguais se ganhou; nunca 3 iguais se perdeu
	var cells: Array = []
	var win_sym := tier % SCRATCH_SYMBOLS.size() if tier >= 0 else -1
	if tier >= 0:
		cells = [win_sym, win_sym, win_sym]
	while cells.size() < 9:
		var s := rng.randi_range(0, SCRATCH_SYMBOLS.size() - 1)
		if s != win_sym and cells.count(s) < 2:
			cells.append(s)
	for i in range(8, 0, -1):
		var j := rng.randi_range(0, i)
		var t = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	return {"cells": cells, "mult": mult, "symbol": win_sym}


# --- Video poker (Jacks or Better) ----------------------------------------------------------------
const VP_PAY := {"Royal Flush": 250.0, "Straight Flush": 50.0, "Quadra": 25.0, "Full House": 9.0, "Flush": 6.0, "Sequência": 4.0, "Trinca": 3.0, "Dois Pares": 2.0, "Par de Valetes ou mais": 1.0}


static func vp_evaluate(hand: Array) -> String:
	var ranks: Array = hand.map(func(c): return rank_of(int(c)))
	var suits: Array = hand.map(func(c): return suit_of(int(c)))
	var counts := {}
	for r in ranks:
		counts[r] = int(counts.get(r, 0)) + 1
	var vals: Array = counts.values()
	vals.sort()
	vals.reverse()
	var flush := suits.count(suits[0]) == 5
	var sr: Array = ranks.map(func(r): return 14 if r == 0 else r + 1)
	sr.sort()
	var straight := counts.size() == 5 and (int(sr[4]) - int(sr[0]) == 4 or sr == [2, 3, 4, 5, 14])
	if straight and flush:
		return "Royal Flush" if sr[0] == 10 else "Straight Flush"
	if vals[0] == 4:
		return "Quadra"
	if vals[0] == 3 and vals[1] == 2:
		return "Full House"
	if flush:
		return "Flush"
	if straight:
		return "Sequência"
	if vals[0] == 3:
		return "Trinca"
	if vals[0] == 2 and vals[1] == 2:
		return "Dois Pares"
	if vals[0] == 2:
		for r in counts:
			if counts[r] == 2 and (r == 0 or r >= 10):
				return "Par de Valetes ou mais"
	return ""
