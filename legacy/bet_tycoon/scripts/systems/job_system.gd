class_name JobSystem
extends RefCounted
## Pequenos trabalhos: válvula de recuperação econômica.
## "delivery": o jogador caminha até pontos marcados no mapa dentro de um prazo.
## "shift": turno; o tempo é acelerado enquanto o personagem trabalha.

var sim: Simulation
var active: Dictionary = {}
var cooldowns: Dictionary = {}   # job_id -> minuto absoluto em que volta a ficar disponível


func _init(s) -> void:
	sim = s


func reset() -> void:
	active = {}
	cooldowns = {}


func all_jobs() -> Array:
	return GameData.list("jobs", "jobs")


func job_data(id: String) -> Dictionary:
	return GameData.find("jobs", "jobs", id)


func jobs_at(giver: String) -> Array:
	return all_jobs().filter(func(j): return str(j.giver) == giver)


func is_busy() -> bool:
	return not active.is_empty()


func is_shift() -> bool:
	return not active.is_empty() and active.type == "shift"


## Retorna "" se disponível ou o motivo de indisponibilidade.
func availability(job: Dictionary) -> String:
	if sim.progression.level < int(job.get("min_level", 1)):
		return "Requer nível %d" % int(job.min_level)
	var h: int = sim.time.hour()
	var hours: Array = job.get("hours", [0, 24])
	if h < int(hours[0]) or h >= int(hours[1]):
		return "Disponível das %02d:00 às %02d:00" % [int(hours[0]), int(hours[1])]
	var cd := int(cooldowns.get(job.id, 0))
	var now: int = sim.time.abs_minute()
	if now < cd:
		return "Disponível em %d min" % (cd - now)
	if is_busy():
		return "Você já está trabalhando"
	return ""


func start(job_id: String) -> bool:
	var job := job_data(job_id)
	if job.is_empty():
		return false
	var why := availability(job)
	if why != "":
		sim.notify(why, "error")
		return false
	var r: Array = job.reward
	var reward := sim.rng.randf_range(float(r[0]), float(r[1]))
	if sim.recovery_mode:
		reward *= float(GameData.balance("recovery_job_bonus", 1.25))
	reward = roundf(reward / 5.0) * 5.0
	var now: int = sim.time.abs_minute()
	active = {"job_id": job_id, "name": job.name, "type": job.type, "reward": reward, "step": 0, "started": now}
	if job.type == "shift":
		active["end"] = now + int(job.duration)
		sim.notify("Turno iniciado: %s (%d min)" % [job.name, int(job.duration)], "job")
	else:
		var stops: Array = []
		var houses: Array = GameData.load_json("jobs").get("houses", ["casa_1"])
		for s in job.stops:
			stops.append(houses[sim.rng.randi_range(0, houses.size() - 1)] if s == "casa_random" else s)
		active["stops"] = stops
		active["deadline"] = now + int(job.time_limit)
		sim.notify("Trabalho aceito: %s — siga o marcador (prazo %d min)" % [job.name, int(job.time_limit)], "job")
	sim.job_changed.emit()
	return true


func current_stop() -> String:
	if active.is_empty() or active.type != "delivery":
		return ""
	return str(active.stops[int(active.step)])


## Chamado pelo mundo quando o jogador alcança o marcador atual.
func reach_stop(point: String) -> void:
	if current_stop() != point:
		return
	active.step = int(active.step) + 1
	if int(active.step) >= active.stops.size():
		_finish(true)
	else:
		sim.notify("Etapa concluída (%d/%d)" % [int(active.step), active.stops.size()], "job")
		sim.job_changed.emit()


func step(now: int) -> void:
	if active.is_empty():
		return
	if active.type == "shift" and now >= int(active.end):
		_finish(true)
	elif active.type == "delivery" and now > int(active.deadline):
		_finish(false)


func cancel() -> void:
	if active.is_empty():
		return
	_finish(false, "Trabalho cancelado.")


func _finish(success: bool, msg: String = "") -> void:
	var job := job_data(str(active.job_id))
	cooldowns[active.job_id] = sim.time.abs_minute() + int(job.get("cooldown_hours", 2)) * 60
	if success:
		sim.economy.earn(float(active.reward), EconomySystem.JOBS)
		sim.add_stat("jobs_done")
		sim.progression.add_xp(int(job.get("xp", GameData.xp_value("job"))))
		sim.notify("Trabalho concluído: +%s" % Fmt.money(float(active.reward)), "cash")
	else:
		sim.notify(msg if msg != "" else "Prazo perdido: %s não foi pago." % active.name, "error")
	active = {}
	sim.job_changed.emit()


func to_dict() -> Dictionary:
	return {"active": active, "cooldowns": cooldowns}


func from_dict(d: Dictionary) -> void:
	active = d.get("active", {})
	cooldowns = d.get("cooldowns", {})
