class_name PlayerState
extends RefCounted
## Um comprador: dinheiro, inventário de itens, melhorias e estatísticas.

var id := 0
var name := ""
var character := "rico"
var is_bot := false
var owner_peer := 1
var connected := true
var money := 0
var inventory: Array = []      # itens (Dictionary) ainda não vendidos
var kept: Array = []           # itens guardados para coleção
var upgrades := {}             # "lanterna", "avaliador", "informante" -> true
var stats := {}


func reset() -> void:
	money = 0
	inventory = []
	kept = []
	upgrades = {}
	stats = {"units_won": 0, "best_profit": 0, "worst_profit": 0, "biggest_bid": 0, "best_item": 0, "best_item_name": "", "spent": 0, "earned": 0}


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "character": character, "is_bot": is_bot, "owner_peer": owner_peer, "connected": connected,
		"money": money, "items": inventory.size(), "kept": kept.size(), "upgrades": upgrades.duplicate(), "stats": stats.duplicate()}
