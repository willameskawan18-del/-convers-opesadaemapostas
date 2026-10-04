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


func reset_stats() -> void:
	stats = {"challenges_won": 0, "best_mult": 0.0, "max_risk": 0, "gained": 0, "lost": 0, "peak_money": 0}


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "character": character, "is_bot": is_bot, "owner_peer": owner_peer,
		"connected": connected, "money": money, "stats": stats.duplicate()}


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
	return p
