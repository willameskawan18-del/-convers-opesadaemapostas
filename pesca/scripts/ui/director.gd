class_name Director
extends Node
## Liga o mundo à interface: câmera do menu, cria o pescador local e os outros.

var world: World
var ui: UIManager
var player: PlayerController
var avatars: RemoteAvatars
var menu_cam: Camera3D
var _t := 0.0


func _ready() -> void:
	menu_cam = Camera3D.new()
	menu_cam.fov = 60
	world.add_child(menu_cam)
	Game.returned_to_menu.connect(_clear_run)


func show_menu() -> void:
	_clear_run()
	menu_cam.make_current()
	Audio.play_music("music_menu")
	Audio.play_ambient("sea_loop")


func _clear_run() -> void:
	if player and is_instance_valid(player):
		player.queue_free()
	player = null
	if avatars and is_instance_valid(avatars):
		avatars.queue_free()
	avatars = null


func start_run() -> void:
	_clear_run()
	player = PlayerController.new()
	player.boat = world.boat
	player.creatures = world.creatures
	world.boat.add_child(player)
	avatars = RemoteAvatars.new()
	world.boat.add_child(avatars)
	ui.hud.bind_player(player)
	Audio.stop_music()
	Audio.play_ambient("sea_loop")


func _process(delta: float) -> void:
	_t += delta
	if menu_cam.current:
		var b := world.boat.global_position
		var a := _t * 0.06
		menu_cam.global_position = b + Vector3(sin(a) * 11.0, 4.0 + sin(_t * 0.3) * 0.5, cos(a) * 11.0)
		menu_cam.look_at(b + Vector3(0, 1.2, 0))
	if player and is_instance_valid(player):
		player.enabled = not ui.modal_open()
