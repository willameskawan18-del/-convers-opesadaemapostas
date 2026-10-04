class_name MoneyManager
extends RefCounted
## Única porta de entrada para alterar dinheiro (fictício). Registra o histórico da partida
## e avisa a interface a cada mudança. O dinheiro nunca fica negativo.

signal money_changed(pid: int, old_value: int, new_value: int, reason: String)

var pm: PlayerManager
var history: Array = []   # {round, pid, delta, reason}
var round_index := 0


func _init(player_manager: PlayerManager) -> void:
	pm = player_manager


func get_money(pid: int) -> int:
	var p := pm.get_player(pid)
	return p.money if p else 0


func set_all(amount: int, reason: String) -> void:
	for p in pm.players:
		_apply(p, amount - p.money, reason)


## Soma (ou subtrai, se negativo). Retorna a variação real aplicada.
func change(pid: int, amount: int, reason: String) -> int:
	var p := pm.get_player(pid)
	if p == null:
		return 0
	return _apply(p, amount, reason)


func earn(pid: int, amount: int, reason: String) -> int:
	return change(pid, absi(amount), reason)


func lose(pid: int, amount: int, reason: String) -> int:
	return -change(pid, -absi(amount), reason)


func multiply(pid: int, factor: float, reason: String) -> int:
	var p := pm.get_player(pid)
	if p == null:
		return 0
	return _apply(p, int(roundf(p.money * factor)) - p.money, reason)


func zero(pid: int, reason: String) -> int:
	var p := pm.get_player(pid)
	if p == null:
		return 0
	return _apply(p, -p.money, reason)


## Transfere até `amount` (limitado ao saldo de quem paga). Retorna o valor transferido.
func transfer(from_pid: int, to_pid: int, amount: int, reason: String) -> int:
	var a := pm.get_player(from_pid)
	var b := pm.get_player(to_pid)
	if a == null or b == null or from_pid == to_pid:
		return 0
	var v := mini(absi(amount), a.money)
	_apply(a, -v, reason)
	_apply(b, v, reason)
	return v


func _apply(p: PlayerState, amount: int, reason: String) -> int:
	var old := p.money
	p.money = maxi(0, p.money + amount)
	var d := p.money - old
	if d == 0:
		return 0
	if d > 0:
		p.stats.gained = int(p.stats.get("gained", 0)) + d
	else:
		p.stats.lost = int(p.stats.get("lost", 0)) - d
	p.stats.peak_money = maxi(int(p.stats.get("peak_money", 0)), p.money)
	history.append({"round": round_index, "pid": p.id, "delta": d, "reason": reason})
	money_changed.emit(p.id, old, p.money, reason)
	return d


func total() -> int:
	var t := 0
	for p in pm.players:
		t += p.money
	return t
