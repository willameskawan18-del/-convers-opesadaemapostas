extends Challenge
## DETETIVE — "Alguém roubou o cofre!" Quatro suspeitos, pistas lógicas. Quem foi?
## Acertar +3.000 · Errar -2.000. As pistas sempre levam a um único culpado.

const NAMES := ["Dona Cleide", "Seu Valdir", "Tia Neide", "Professor Lima", "Madame Zuzu", "Capitão Bento", "Doutora Íris", "Barão Fofo"]
const ATTRS := {
	"chapeu": ["de chapéu", "sem chapéu"],
	"cor": ["de camisa vermelha", "de camisa azul", "de camisa verde"],
	"local": ["na cozinha", "no jardim", "na garagem", "no camarim"],
	"item": ["com um guarda-chuva", "com uma maleta", "com uma bengala", "de mãos vazias"],
}
const CASES := ["Alguém roubou %s do cofre do apresentador!", "Sumiram %s do prêmio da plateia!", "Alguém trocou %s por dinheiro de brinquedo!"]

var suspects: Array = []   # [{name, chapeu, cor, local, item}]
var culprit := 0
var clues: Array[String] = []
var story := ""


func start() -> void:
	for attempt in 60:
		if _generate():
			return
	_generate_simple()


func _generate() -> bool:
	var names := NAMES.duplicate()
	names.shuffle()
	suspects.clear()
	for i in 4:
		var s := {"name": names[i]}
		for k in ATTRS:
			s[k] = ctx.rng.randi_range(0, ATTRS[k].size() - 1)
		suspects.append(s)
	culprit = ctx.rng.randi_range(0, 3)
	story = CASES[ctx.rng.randi_range(0, CASES.size() - 1)] % Fmt.money(ctx.scaled(5000))
	clues.clear()
	var alive := [0, 1, 2, 3]
	var keys := ATTRS.keys()
	keys.shuffle()
	for k in keys:
		if alive.size() == 1:
			break
		var cv: int = suspects[culprit][k]
		var positive := ctx.rng.randf() < 0.5
		var remaining := []
		if positive:
			remaining = alive.filter(func(i): return int(suspects[i][k]) == cv)
		else:
			var other: int = (cv + ctx.rng.randi_range(1, ATTRS[k].size() - 1)) % ATTRS[k].size()
			remaining = alive.filter(func(i): return int(suspects[i][k]) != other)
			if remaining.size() < alive.size():
				clues.append("O culpado NÃO estava %s." % ATTRS[k][other] if k == "local" else "O culpado NÃO estava %s." % ATTRS[k][other])
				alive = remaining
			continue
		if remaining.size() < alive.size():
			clues.append("Uma testemunha viu o culpado %s." % ATTRS[k][cv])
			alive = remaining
	return alive.size() == 1 and alive[0] == culprit and clues.size() >= 2


func _generate_simple() -> void:
	# garante solução: dá atributo único ao culpado
	suspects[culprit]["item"] = 3
	for i in 4:
		if i != culprit and int(suspects[i]["item"]) == 3:
			suspects[i]["item"] = i % 3
	clues = ["Uma testemunha viu o culpado %s." % ATTRS.item[3]]


func describe(i: int) -> String:
	var s: Dictionary = suspects[i]
	return "%s: %s, %s, estava %s, %s" % [s.name, ATTRS.chapeu[s.chapeu], ATTRS.cor[s.cor], ATTRS.local[s.local].trim_prefix(""), ATTRS.item[s.item]]


func time_limit() -> float:
	return ctx.decision_time + 12.0


func options(_pid: int) -> Array:
	var out := []
	for i in 4:
		out.append({"id": str(i), "label": str(suspects[i].name), "desc": "", "color": [Pal.PINK, Pal.CYAN, Pal.GOLD, Pal.PURPLE][i]})
	return out


func private_info(_pid: int) -> Dictionary:
	var lines: Array = ["SUSPEITOS:"]
	for i in 4:
		lines.append("• " + describe(i))
	lines.append("PISTAS:")
	for c in clues:
		lines.append("» " + c)
	return {"prompt": story + " Quem foi?", "lines": lines, "layout": "grid", "small_lines": true,
		"footer": "Acertar %s  ·  Errar %s" % [Fmt.delta(ctx.scaled(3000)), Fmt.delta(-ctx.scaled(2000))]}


func bot_action(pid: int) -> Dictionary:
	var sk := ctx.bot_skill(pid, "knowledge")
	if ctx.rng.randf() < 0.45 + sk * 0.45:
		return {"choice": str(culprit)}
	return {"choice": str((culprit + ctx.rng.randi_range(1, 3)) % 4)}


func default_action(_pid: int) -> Dictionary:
	return {"choice": "-1"}


func validate(pid: int, action: Dictionary) -> bool:
	return str(action.get("choice", "")) == "-1" or super.validate(pid, action)


func resolve() -> Array:
	var money := []
	var stat := []
	var rows := []
	for pid in participants:
		var ok := str(actions[pid].choice) == str(culprit)
		var d := ctx.scaled(3000) if ok else -ctx.scaled(2000)
		money.append([pid, d, "Detetive"])
		stat.append([pid, "answered", 1])
		if ok:
			stat.append([pid, "correct", 1])
		var guess := int(actions[pid].choice)
		rows.append([pname(pid) + " → " + (str(suspects[guess].name) if guess >= 0 else "?"), Fmt.delta(d), pcolor(pid), Pal.GREEN if ok else Pal.RED])
	return [
		Challenge.step("banner", 2.4, {"title": "O CULPADO É...", "text": "Rufem os tambores!", "fx": "drumroll", "camera": "stage"}),
		Challenge.step("banner", 2.4, {"title": str(suspects[culprit].name).to_upper() + "!", "text": describe(culprit), "fx": "reveal", "camera": "screen"}),
		Challenge.list_step("QUEM ACERTOU?", rows, 3.0, {"money": money, "stat": stat}),
	]
