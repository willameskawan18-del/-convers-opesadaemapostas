class_name AppBase
extends RefCounted
## Base dos "apps" (celular/computador). Cada app constrói seu conteúdo no corpo de uma
## UiWindow e é reconstruído após ações (ui.refresh()) ou periodicamente se live() for true.

var ui            # UIManager
var arg: Variant = null


func title() -> String:
	return "App"


func subtitle() -> String:
	return ""


func window_size() -> Vector2:
	return Vector2(820, 560)


func live() -> bool:
	return false


func build(_body: VBoxContainer) -> void:
	pass


func sim() -> Simulation:
	return Game.sim
