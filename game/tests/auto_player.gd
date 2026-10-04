class_name AutoPlayer
## Jogador automático para os testes: gera uma ação válida para qualquer tipo de entrada.


static func action(input: String, priv: Dictionary, info: Dictionary) -> Dictionary:
	match input:
		"reaction":
			return {"ms": 300}
		"auction":
			var mb := int(priv.get("min_bid", 0))
			if mb <= int(priv.get("max_bid", 0)) and randf() < 0.5:
				return {"bid": mb}
			return {"pass": true}
		"precision":
			return {"offset": randf() * 0.4, "stake": randi() % 3, "score": 0.8}
		"targets":
			return {"points": randi() % 20, "score": 0.4, "jackpot": false}
		"memory":
			return {"correct": randi() % 4, "score": 0.5}
		"race":
			return {"time": 9.0 + randf() * 6.0, "score": 0.6}
	var opts: Array = priv.get("options", [])
	var a := {"choice": opts[randi() % opts.size()].id} if opts.size() > 0 else {}
	if bool(priv.get("timed", false)):
		a["ms"] = 1500
	if int(priv.get("shields", 0)) > 0 and randf() < 0.5:
		a["shield"] = true
	return a


## Responde por todos os humanos locais que ainda não decidiram nesta etapa.
static func play_all(info: Dictionary) -> void:
	for p in Game.local_players():
		var pid := int(p.id)
		if Game.has_submitted(pid) or not Game.private_infos.has(pid):
			continue
		var priv: Dictionary = Game.private_infos[pid]
		if int(priv.get("stage", 1)) != int(info.get("stage", 1)):
			continue
		if not info.get("deciders", []).has(pid):
			continue
		Game.submit_action(pid, action(str(info.get("input", "choice")), priv, info))
