class_name MoneyManager
extends RefCounted
## Única porta de entrada para alterar dinheiro (fictício). Registra o histórico da partida
## e avisa a interface a cada mudança. Permite DÍVIDA limitada (até -$5.000): quem zera
## continua no jogo, mas precisa recuperar.

signal money_changed(pid: int, old_value: int, new_value: int, reason: String)

const DEBT_LIMIT := 5000

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


## Transfere até `amount` (limitado ao saldo positivo de quem paga). Retorna o valor transferido.
func transfer(from_pid: int, to_pid: int, amount: int, reason: String) -> int:
	var a := pm.get_player(from_pid)
	var b := pm.get_player(to_pid)
	if a == null or b == null or from_pid == to_pid:
		return 0
	var v := mini(absi(amount), maxi(a.money, 0))
	_apply(a, -v, reason)
	_apply(b, v, reason)
	return v


func _apply(p: PlayerState, amount: int, reason: String) -> int:
	var old := p.money
	p.money = maxi(-DEBT_LIMIT, p.money + amount)
	var d := p.money - old
	if d == 0:
		return 0
	if d > 0:
		p.stats.gained = int(p.stats.get("gained", 0)) + d
	else:
		p.stats.lost = int(p.stats.get("lost", 0)) - d
		p.stats.biggest_loss = maxi(int(p.stats.get("biggest_loss", 0)), -d)
	p.stats.peak_money = maxi(int(p.stats.get("peak_money", 0)), p.money)
	p.stats.min_money = mini(int(p.stats.get("min_money", p.money)), p.money)
	p.stats.recovery = maxi(int(p.stats.get("recovery", 0)), p.money - int(p.stats.min_money))
	history.append({"round": round_index, "pid": p.id, "delta": d, "reason": reason})
	money_changed.emit(p.id, old, p.money, reason)
	return d


func total() -> int:
	var t := 0
	for p in pm.players:
		t += p.money
	return t
