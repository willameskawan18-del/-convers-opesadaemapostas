extends Node
## Cena principal: mundo (mar, porto, barco) + interface + diretor.

func _ready() -> void:
	var world := World.new()
	add_child(world)
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := UIManager.new()
	var director := Director.new()
	director.world = world
	director.ui = ui
	ui.director = director
	add_child(director)
	layer.add_child(ui)
