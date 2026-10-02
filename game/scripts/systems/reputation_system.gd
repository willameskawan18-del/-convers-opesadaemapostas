class_name ReputationSystem
extends RefCounted
## Reputação do negócio (0 a 100). Cada alteração registra um motivo para o relatório diário.

var sim: Simulation
var value := 50.0
var day_start_value := 50.0
var today_changes := {}


func _init(s) -> void:
	sim = s


func reset() -> void:
	value = float(GameData.balance("reputation_start", 50))
	day_start_value = value
	today_changes = {}


func add(delta: float, reason: String) -> void:
	if is_nan(delta) or delta == 0.0:
		return
	value = clampf(value + delta, 0.0, 100.0)
	today_changes[reason] = float(today_changes.get(reason, 0.0)) + delta


func label() -> String:
	if value < 20: return "Péssima"
	if value < 40: return "Ruim"
	if value < 55: return "Regular"
	if value < 70: return "Boa"
	if value < 85: return "Ótima"
	return "Lendária"


func stars() -> float:
	return snappedf(value / 20.0, 0.5)


## Chamado no fechamento do dia: pequenos ajustes passivos.
func daily() -> void:
	if sim.has_business():
		var sec: float = sim.business.security_score()
		if sec >= 30.0:
			add(0.4, "Segurança percebida")
		var comfort: float = sim.business.comfort()
		if comfort >= 10.0:
			add(0.3, "Conforto do ambiente")
		var mgr: float = sim.employees.manager_bonus()
		if mgr > 0.0:
			add(0.5 * mgr * 5.0, "Gestão profissional")
	# Memória curta do público: tende lentamente à média
	var pull := 0.05 if sim.has_business() else 0.1
	add((50.0 - value) * pull, "Tendência natural")


func start_day() -> void:
	day_start_value = value
	today_changes = {}


func to_dict() -> Dictionary:
	return {"value": value, "day_start_value": day_start_value, "today_changes": today_changes}


func from_dict(d: Dictionary) -> void:
	value = float(d.get("value", 50.0))
	day_start_value = float(d.get("day_start_value", value))
	today_changes = d.get("today_changes", {})
