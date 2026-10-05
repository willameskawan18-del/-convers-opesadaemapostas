class_name BotBrain
extends RefCounted
## Decisões dos compradores controlados pelo computador.

const PERSONALITY := {"rico": 1.0, "apostador": 1.15, "maluco": 1.25, "medroso": 0.65, "genio": 0.9, "trapaceiro": 0.95, "sortudo": 1.05, "azarado": 0.85}


## Quanto o bot aceita pagar no máximo pelo galpão.
static func max_bid(p: PlayerState, unit: Dictionary, visible: int, rng: RandomNumberGenerator) -> int:
	var est := 0.0
	for i in mini(visible, unit.items.size()):
		est += UnitGen.eye_estimate(unit.items[i]) * rng.randf_range(0.6, 1.3)
	var hidden_n: int = unit.items.size() - visible
	est += hidden_n * rng.randf_range(250.0, 650.0)
	if str(unit.rumor).contains("cofre") or str(unit.rumor).contains("motos") or str(unit.rumor).contains("galerias") or str(unit.rumor).contains("joias"):
		est *= rng.randf_range(1.1, 1.5)
	var k: float = PERSONALITY.get(p.character, 1.0)
	var cap := int(p.money * (0.45 if k < 1.0 else 0.65))
	return mini(cap, int(est * k * rng.randf_range(0.55, 0.9) / 50.0) * 50)


## Decisão de venda de um item: "loja", "online", "guardar" ou (mistério) "abrir"/"fechado".
static func sell_choice(p: PlayerState, it: Dictionary, collection_count: int, rng: RandomNumberGenerator) -> String:
	if it.mystery:
		return "abrir" if rng.randf() < PERSONALITY.get(p.character, 1.0) * 0.6 else "fechado"
	if collection_count >= 2 and it.cat != "lixo":
		return "guardar"
	var k: float = PERSONALITY.get(p.character, 1.0)
	return "online" if rng.randf() < 0.25 * k else "loja"
