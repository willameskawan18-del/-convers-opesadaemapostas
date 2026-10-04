extends Node
## Cena principal: arena 3D + interface + diretor do programa.

var arena: Arena
var ui: UIManager


func _ready() -> void:
	arena = Arena.new()
	add_child(arena)
	var director := ShowDirector.new()
	director.arena = arena
	add_child(director)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = UIManager.new()
	ui.arena = arena
	ui.director = director
	layer.add_child(ui)
