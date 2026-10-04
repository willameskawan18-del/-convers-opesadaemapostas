class_name MissionSystem
extends RefCounted
## Missões secretas: cada jogador recebe uma no início. São reveladas antes do ALL WIN;
## quem cumpriu ganha um bônus.

const MISSIONS := [
	{"id": "leader", "text": "Esteja em 1º lugar antes do ALL WIN."},
	{"id": "rich", "text": "Tenha pelo menos $12.000 antes do ALL WIN.", "key": "money", "v": 12000},
	{"id": "wins", "text": "Vença 2 rodadas.", "key": "challenges_won", "v": 2},
	{"id": "brain", "text": "Acerte 4 respostas de conhecimento.", "key": "correct", "v": 4},
	{"id": "thief", "text": "Faça outro jogador perder dinheiro (roube ou traia).", "key": "steals", "v": 1},
	{"id": "brave", "text": "Escolha SUBIR / ABRIR / TROCAR 3 vezes.", "key": "continues", "v": 3},
	{"id": "skill", "text": "Vença uma prova de HABILIDADE.", "key": "skill_wins", "v": 1},
	{"id": "risk", "text": "Arrisque mais de $3.000 de uma vez.", "key": "max_risk", "v": 3000},
	{"id": "comeback", "text": "Recupere $5.000 depois do seu pior momento.", "key": "recovery", "v": 5000},
	{"id": "shield", "text": "Use uma SAFE CARD.", "key": "shields_used", "v": 1},
]
const BONUS := 3000


static func assign(pm: PlayerManager, rng: RandomNumberGenerator) -> void:
	var bag := MISSIONS.duplicate()
	for p in pm.players:
		if bag.is_empty():
			bag = MISSIONS.duplicate()
		var i := rng.randi_range(0, bag.size() - 1)
		p.mission = bag[i].duplicate()
		bag.remove_at(i)


static func completed(p: PlayerState, pm: PlayerManager) -> bool:
	var m: Dictionary = p.mission
	match str(m.get("id", "")):
		"leader":
			return pm.position_of(p.id) == 1
		"rich":
			return p.money >= int(m.v)
	if not m.has("key"):
		return false
	return float(p.stats.get(m.key, 0)) >= float(m.v)
