extends Node
## Cena principal: pátio 3D + interface + diretor.

var yard: Yard
var ui: UIManager


func _ready() -> void:
	yard = Yard.new()
	add_child(yard)
	var director := Director.new()
	director.yard = yard
	add_child(director)
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = UIManager.new()
	ui.arena = null
	ui.director = director
	layer.add_child(ui)
