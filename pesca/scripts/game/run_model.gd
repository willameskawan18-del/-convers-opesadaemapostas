class_name RunModel
extends RefCounted
## Estado da expedição (só no host): dinheiro, noite, cota, caixa térmica, melhorias,
## barco, casco, vazamentos, ameaças e "pavor" (chance de eventos perigosos).

const NIGHT_MINUTES := 540.0      # 20:00 → 05:00
const NIGHTS_PER_QUOTA := 3
const DOCK := Vector3(0, 0, 0)
const UPGRADES := {
	"vara": {"name": "VARA REFORÇADA", "desc": "Zona segura maior ao puxar.", "costs": [150, 400, 900]},
	"isca": {"name": "ISCA ESPECIAL", "desc": "Peixes mordem mais rápido e mais raros.", "costs": [120, 350, 800]},
	"motor": {"name": "MOTOR TURBO", "desc": "Barco mais rápido.", "costs": [200, 500, 1100]},
	"casco": {"name": "CASCO BLINDADO", "desc": "+50 de resistência por nível.", "costs": [180, 450, 1000]},
	"sonar": {"name": "SONAR", "desc": "Mostra a profundidade e perigos por perto.", "costs": [600]},
}

var money := 0
var night := 1
var minute := 0.0               # minutos desde as 20:00
var quota := 0
var quota_index := 0
var sold_cycle := 0
var cooler: Array = []
var upgrades := {"vara": 0, "isca": 0, "motor": 0, "casco": 0, "sonar": 0}
var hull := 100.0
var leaks: Array = []           # [{id, pos: Vector3 (local), hp}]
var dread := 0.0
var stats := {"caught": 0, "best_name": "", "best_value": 0, "biggest_kg": 0.0, "biggest_name": "", "earned": 0, "sinks": 0}
# barco
var pos := Vector3(0, 0, 18)
var yaw := 0.0
var speed := 0.0
var throttle := 0.0
var steer := 0.0
var driver := -1
var lantern := true
# ameaças
var tentacle := {}              # {side, hp, t}
var eyes := {}                  # {t, angle}
var _leak_id := 0


func reset() -> void:
	money = 0
	night = 1
	minute = 0.0
	quota_index = 0
	quota = quota_for(0)
	sold_cycle = 0
	cooler = []
	upgrades = {"vara": 0, "isca": 0, "motor": 0, "casco": 0, "sonar": 0}
	stats = {"caught": 0, "best_name": "", "best_value": 0, "biggest_kg": 0.0, "biggest_name": "", "earned": 0, "sinks": 0}
	reset_boat()


func reset_boat() -> void:
	pos = Vector3(0, 0, 18)
	yaw = 0.0
	speed = 0.0
	throttle = 0.0
	steer = 0.0
	hull = hull_max()
	leaks = []
	dread = 0.0
	tentacle = {}
	eyes = {}


static func quota_for(i: int) -> int:
	return int(roundf(700.0 * pow(2.05, i) / 50.0) * 50.0)


func hull_max() -> float:
	return 100.0 + 50.0 * int(upgrades.casco)


func max_speed() -> float:
	return 9.0 + 3.0 * int(upgrades.motor)


func distance() -> float:
	return Vector2(pos.x, pos.z).length()


func zone() -> Dictionary:
	return FishDB.zone_at(distance())


func docked() -> bool:
	return distance() < 30.0 and absf(speed) < 2.0


func cooler_value() -> int:
	var v := 0
	for f in cooler:
		v += int(f.value)
	return v


func clock_text() -> String:
	var total := int(minute) + 20 * 60
	return "%02d:%02d" % [(total / 60) % 24, total % 60]


func upgrade_cost(k: String) -> int:
	var costs: Array = UPGRADES[k].costs
	var lv := int(upgrades.get(k, 0))
	return int(costs[lv]) if lv < costs.size() else -1


func add_leak(rng: RandomNumberGenerator) -> void:
	_leak_id += 1
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	leaks.append({"id": _leak_id, "pos": Vector3(side * 1.25, 0.25, rng.randf_range(-2.6, 2.6)), "hp": 1.0})


func to_public() -> Dictionary:
	return {"money": money, "night": night, "clock": clock_text(), "minute": minute, "quota": quota, "sold_cycle": sold_cycle,
		"nights_left": NIGHTS_PER_QUOTA - ((night - 1) % NIGHTS_PER_QUOTA), "cooler_count": cooler.size(), "cooler_value": cooler_value(),
		"upgrades": upgrades.duplicate(), "hull": hull, "hull_max": hull_max(), "zone": zone().name, "zone_id": zone().id,
		"depth": zone().depth, "distance": distance(), "docked": docked(), "lantern": lantern, "driver": driver, "stats": stats.duplicate(),
		"dread": dread}
