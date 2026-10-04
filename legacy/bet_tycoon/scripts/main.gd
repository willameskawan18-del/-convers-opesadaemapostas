extends Node
## Cena principal: monta o mundo 3D e a interface.

var world: GameWorld
var ui: UIManager


func _ready() -> void:
	world = GameWorld.new()
	world.name = "World"
	add_child(world)
	ui = UIManager.new()
	ui.name = "UI"
	add_child(ui)
