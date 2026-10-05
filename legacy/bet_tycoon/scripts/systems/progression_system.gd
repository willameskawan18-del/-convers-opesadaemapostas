class_name ProgressionSystem
extends RefCounted
## Experiência de Gestão: XP, níveis, títulos e desbloqueios.

var sim: Simulation
var level := 1
var xp := 0
var total_xp := 0
var xp_today := 0


func _init(s) -> void:
	sim = s


func reset() -> void:
	level = 1
	xp = 0
	total_xp = 0
	xp_today = 0


func xp_to_next(lv: int = -1) -> int:
	if lv < 0:
		lv = level
	var d: Dictionary = GameData.load_json("progression")
	return int(float(d.get("xp_base", 120)) * pow(float(lv), float(d.get("xp_exp", 1.55))))


func add_xp(amount: int, _reason: String = "") -> void:
	if amount <= 0:
		return
	xp += amount
	total_xp += amount
	xp_today += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		var t := title()
		sim.notify("NÍVEL %d — %s" % [level, t], "level")
		var unlocks: Array = GameData.load_json("progression").get("unlocks", {}).get(str(level), [])
		for u in unlocks:
			sim.notify("Desbloqueado: " + str(u), "unlock")
		sim.level_up.emit(level, t)


func title(lv: int = -1) -> String:
	if lv < 0:
		lv = level
	var best := "Apostador"
	for t in GameData.list("progression", "titles"):
		if lv >= int(t.level):
			best = str(t.title)
	return best


func progress_ratio() -> float:
	return clampf(float(xp) / maxf(1.0, float(xp_to_next())), 0.0, 1.0)


func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "total_xp": total_xp, "xp_today": xp_today}


func from_dict(d: Dictionary) -> void:
	level = maxi(1, int(d.get("level", 1)))
	xp = int(d.get("xp", 0))
	total_xp = int(d.get("total_xp", 0))
	xp_today = int(d.get("xp_today", 0))
