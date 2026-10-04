class_name Interactable
extends Area3D
## Objeto com o qual o jogador interage pela tecla [E].

var prompt := "Interagir"
var prompt_func: Callable
var action: Callable
var enabled := true


static func create(p_prompt: String, p_action: Callable, radius: float = 1.2) -> Interactable:
	var it := Interactable.new()
	it.prompt = p_prompt
	it.action = p_action
	it.collision_layer = 4
	it.collision_mask = 0
	it.monitoring = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	it.add_child(cs)
	return it


func get_prompt() -> String:
	if prompt_func.is_valid():
		return str(prompt_func.call())
	return prompt


func interact() -> void:
	if enabled and action.is_valid():
		Audio.play("click", -6.0)
		action.call()
