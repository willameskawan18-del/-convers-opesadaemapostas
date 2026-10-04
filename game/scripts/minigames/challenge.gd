class_name Challenge
extends RefCounted
## Base de todos os desafios. A lógica roda só no servidor (host); a interface recebe
## opções, informações públicas/privadas e uma sequência de "passos de revelação".
##
## Um passo é um Dictionary com:
##   kind      → tipo visual (ex.: "door_open", "player_result", "banner")
##   duration  → segundos em tela
##   title / text
##   money     → [[pid, delta, motivo], ...] aplicado quando o passo aparece
##   mult      → [[pid, multiplicador]], risk → [[pid, valor arriscado]] (estatísticas)
##   fx        → "win", "lose", "suspense", "drumroll", "reveal", "jackpot"
##   camera    → "wide", "stage", "doors", "players", "player", "screen"
##   pid       → jogador em destaque (opcional)

var def: ChallengeDef
var ctx: MatchContext
var participants: Array[int] = []
var actions: Dictionary = {}       # pid -> Dictionary
var submit_order: Array[int] = []


func setup(context: MatchContext, definition: ChallengeDef) -> void:
	ctx = context
	def = definition
	participants = ctx.pm.ids()
	start()


# --- Para sobrescrever ----------------------------------------------------------

func start() -> void:
	pass


## [{id, label, desc, color}]
func options(_pid: int) -> Array:
	return []


func public_info() -> Dictionary:
	return {}


func private_info(_pid: int) -> Dictionary:
	return {}


func time_limit() -> float:
	return ctx.decision_time


func bot_action(_pid: int) -> Dictionary:
	return default_action(_pid)


func default_action(pid: int) -> Dictionary:
	var opts := options(pid)
	return {"choice": opts[opts.size() - 1].id} if opts.size() > 0 else {}


func validate(pid: int, action: Dictionary) -> bool:
	if def.input == "choice":
		var c := str(action.get("choice", ""))
		for o in options(pid):
			if o.id == c:
				return true
		return false
	return true


func resolve() -> Array:
	return []


# --- Comum ---------------------------------------------------------------------

func needs_decision() -> bool:
	return def.input != "none"


func submit(pid: int, action: Dictionary) -> bool:
	if not participants.has(pid) or actions.has(pid):
		return false
	if not validate(pid, action):
		return false
	actions[pid] = action
	submit_order.append(pid)
	return true


func all_submitted() -> bool:
	for pid in participants:
		if not actions.has(pid):
			return false
	return true


func fill_defaults() -> void:
	for pid in participants:
		if not actions.has(pid):
			var a := default_action(pid)
			a["auto"] = true
			actions[pid] = a
			submit_order.append(pid)


func pname(pid: int) -> String:
	var p := ctx.pm.get_player(pid)
	return p.name if p else "?"


func money_of(pid: int) -> int:
	return ctx.money.get_money(pid)


## Aposta da rodada: limitada ao saldo. Quem está zerado joga com uma "ficha de resgate"
## (não perde nada), para sempre ter chance de virar o jogo.
func stake_for(pid: int, base: int) -> Dictionary:
	var m := money_of(pid)
	if m <= 0:
		return {"amount": maxi(50, base / 2), "free": true}
	return {"amount": mini(m, base), "free": false}


static func step(kind: String, duration: float, extra: Dictionary = {}) -> Dictionary:
	var s := {"kind": kind, "duration": duration, "title": "", "text": "", "money": [], "mult": [], "risk": [], "fx": "", "camera": "wide", "pid": -1}
	s.merge(extra, true)
	return s


func choice_label(pid: int) -> String:
	var a: Dictionary = actions.get(pid, {})
	for o in options(pid):
		if o.id == str(a.get("choice", "")):
			return str(o.label)
	return "-"
