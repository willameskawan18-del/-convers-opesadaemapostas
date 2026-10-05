class_name TimeSystem
extends RefCounted
## Relógio do jogo. 1 dia = 1440 minutos. O dia começa às 07:00 e termina à meia-noite.

const WEEKDAYS := ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]

var sim: Simulation
var day := 1
var minute := 420


func _init(s) -> void:
	sim = s


func reset() -> void:
	day = 1
	minute = int(GameData.balance("day_start_minute", 420))


func step() -> void:
	minute += 1


func abs_minute() -> int:
	return day * 1440 + minute


func hour() -> int:
	return mini(minute / 60, 23)


func weekday() -> int:
	return (day - 1) % 7


func weekday_name() -> String:
	return WEEKDAYS[weekday()]


func is_weekend() -> bool:
	return weekday() >= 5


func day_over() -> bool:
	return minute >= 1440


func next_day() -> void:
	day += 1
	minute = int(GameData.balance("day_start_minute", 420))


func clock_text() -> String:
	return "%02d:%02d" % [mini(minute, 1439) / 60, mini(minute, 1439) % 60]


func to_dict() -> Dictionary:
	return {"day": day, "minute": minute}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	minute = int(d.get("minute", 420))
