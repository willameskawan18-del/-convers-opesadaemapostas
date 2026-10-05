class_name Challenge
extends RefCounted
## Base de todos os desafios. A lógica roda só no host; a interface recebe opções,
## informações públicas/privadas e uma sequência de "passos de revelação".
##
## Desafios podem ter várias ETAPAS (ex.: escolher a caixa → parar ou continuar).
## O MatchRunner repete: decisão (de quem `deciders()` indicar) → resolve() → has_next_stage()?
##
## Um passo de revelação é um Dictionary com:
##   kind      → tipo visual ("banner", "player_result", "list", "door_open", "race"...)
##   duration  → segundos em tela
##   title / text
##   money     → [[pid, delta, motivo, tag?]] aplicado quando o passo aparece.
##               tag "pay" = pagamento voluntário (SAFE CARD não protege), "nobonus" = sem bônus de virada
##   mult / risk → [[pid, valor]] (estatísticas)
##   stat      → [[pid, chave, incremento]] (estatísticas genéricas)
##   items     → [[pid, item, quantidade]]   flags → [[pid, flag, valor]]
##   fx        → "win", "lose", "suspense", "drumroll", "reveal", "jackpot"
##   camera    → "wide", "stage", "doors", "players", "player", "screen"
##   pid       → jogador em destaque (opcional)

var def: ChallengeDef
var ctx: MatchContext
var participants: Array[int] = []
var actions: Dictionary = {}       # pid -> Dictionary (etapa atual)
var submit_order: Array[int] = []
var stage := 1
var shields: Dictionary = {}       # pid -> true (usou SAFE CARD neste desafio)


func setup(context: MatchContext, definition: ChallengeDef) -> void:
	ctx = context
	def = definition
	participants = ctx.pm.ids()
	start()


# --- Para sobrescrever ----------------------------------------------------------

func start() -> void:
	pass


## Quem decide nesta etapa (padrão: todos).
func deciders() -> Array[int]:
	return participants


## Tipo de entrada desta etapa.
func input_type() -> String:
	return def.input


## [{id, label, desc, color}]
func options(_pid: int) -> Array:
	return []


func public_info() -> Dictionary:
	return {}


## Pode conter: prompt (texto grande), lines (linhas de contexto) e dados do minijogo.
func private_info(_pid: int) -> Dictionary:
	return {}


func time_limit() -> float:
	return ctx.decision_time


func stage_title() -> String:
	return ""


func bot_action(pid: int) -> Dictionary:
	return default_action(pid)


func default_action(pid: int) -> Dictionary:
	var opts := options(pid)
	return {"choice": opts[opts.size() - 1].id} if opts.size() > 0 else {}


func validate(pid: int, action: Dictionary) -> bool:
	if input_type() == "choice":
		var c := str(action.get("choice", ""))
		for o in options(pid):
			if o.id == c:
				return true
		return false
	return true


## Passos de revelação da etapa atual.
func resolve() -> Array:
	return []


func has_next_stage() -> bool:
	return false


## Desafios de risco aceitam SAFE CARD.
func allows_shield() -> bool:
	return def.category == "risco"


# --- Comum ---------------------------------------------------------------------

func needs_decision() -> bool:
	return input_type() != "none" and not deciders().is_empty()


func next_stage() -> void:
	stage += 1
	actions.clear()
	submit_order.clear()


func submit(pid: int, action: Dictionary) -> bool:
	if not deciders().has(pid) or actions.has(pid):
		return false
	if not validate(pid, action):
		return false
	if action.get("shield", false):
		var p := ctx.pm.get_player(pid)
		if allows_shield() and p and p.shields() > 0 and not shields.has(pid):
			shields[pid] = true
			p.items.shield = p.shields() - 1
			p.stats.shields_used = int(p.stats.get("shields_used", 0)) + 1
	actions[pid] = action
	submit_order.append(pid)
	return true


func all_submitted() -> bool:
	for pid in deciders():
		if not actions.has(pid):
			return false
	return true


func fill_defaults() -> void:
	for pid in deciders():
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


func others(pid: int) -> Array[int]:
	var out: Array[int] = []
	for o in participants:
		if o != pid:
			out.append(o)
	return out


## Aposta da rodada: limitada ao saldo. Quem está zerado/endividado joga com uma
## "ficha de resgate" (não perde nada), para sempre ter chance de virar o jogo.
func stake_for(pid: int, base: int) -> Dictionary:
	var m := money_of(pid)
	if m <= 0:
		return {"amount": maxi(50, base / 2), "free": true}
	return {"amount": mini(m, base), "free": false}


## Opções com os outros jogadores (votação, alvo de roubo...).
func player_options(pid: int, include_self: bool = false) -> Array:
	var out := []
	for o in participants:
		if o == pid and not include_self:
			continue
		var p := ctx.pm.get_player(o)
		out.append({"id": str(o), "label": p.name, "desc": Fmt.money(p.money), "color": GameData.character_color(p.character), "player": o})
	return out


## Concede o jackpot progressivo (se dividido, cada um leva uma parte).
func jackpot_entries(pids: Array) -> Array:
	var out := []
	if pids.is_empty():
		return out
	var each := int(ctx.jackpot / pids.size())
	for pid in pids:
		out.append([pid, each, "JACKPOT!", "nobonus"])
	ctx.jackpot_won = true
	return out


static func step(kind: String, duration: float, extra: Dictionary = {}) -> Dictionary:
	var s := {"kind": kind, "duration": duration, "title": "", "text": "", "money": [], "mult": [], "risk": [], "fx": "", "camera": "wide", "pid": -1}
	s.merge(extra, true)
	return s


## Passo com uma tabela: rows = [[esquerda, direita, cor_esquerda, cor_direita], ...]
static func list_step(title: String, rows: Array, duration: float, extra: Dictionary = {}) -> Dictionary:
	var e := {"title": title, "rows": rows, "fx": "reveal", "camera": "screen"}
	e.merge(extra, true)
	return step("list", duration, e)


func choice_label(pid: int) -> String:
	var a: Dictionary = actions.get(pid, {})
	for o in options(pid):
		if o.id == str(a.get("choice", "")):
			return str(o.label)
	return "-"


func pcolor(pid: int) -> Color:
	var p := ctx.pm.get_player(pid)
	return GameData.character_color(p.character if p else "")
