class_name PlayerState
extends RefCounted
## Dados de um participante da partida. O dinheiro fica aqui, mas só o MoneyManager o altera.

var id := 0
var name := ""
var character := "sortudo"
var is_bot := false
var owner_peer := 1          # peer de rede que controla este jogador (1 = host / local)
var connected := true
var money := 0
var stats := {}
var items := {}              # "shield": SAFE CARDs
var flags := {}              # "king", "comeback", "traitor"
var mission := {}            # missão secreta {id, text, bonus}


func reset_stats() -> void:
	stats = {"challenges_won": 0, "best_mult": 0.0, "max_risk": 0, "risk_total": 0, "gained": 0, "lost": 0,
		"peak_money": 0, "min_money": 0, "recovery": 0, "biggest_loss": 0, "correct": 0, "answered": 0,
		"skill_sum": 0.0, "skill_n": 0, "skill_wins": 0, "steals": 0, "continues": 0, "shields_used": 0, "safe_choices": 0}
	items = {"shield": 0}
	flags = {}
	mission = {}


func shields() -> int:
	return int(items.get("shield", 0))


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "character": character, "is_bot": is_bot, "owner_peer": owner_peer,
		"connected": connected, "money": money, "stats": stats.duplicate(), "items": items.duplicate(), "flags": flags.duplicate()}


static func from_dict(d: Dictionary) -> PlayerState:
	var p := PlayerState.new()
	p.id = int(d.get("id", 0))
	p.name = str(d.get("name", ""))
	p.character = str(d.get("character", "sortudo"))
	p.is_bot = bool(d.get("is_bot", false))
	p.owner_peer = int(d.get("owner_peer", 1))
	p.connected = bool(d.get("connected", true))
	p.money = int(d.get("money", 0))
	p.stats = d.get("stats", {}).duplicate()
	p.items = d.get("items", {}).duplicate()
	p.flags = d.get("flags", {}).duplicate()
	return p
