extends Node
## Autoload "Game": dono da Simulation, controla o fluxo de tempo real → tempo de jogo,
## estados (menu/jogando), save/load e mapeamento de entradas.

signal session_started
signal session_ended
signal time_speed_changed(speed: float)
## Pedido do mundo 3D para a UI abrir algo (ex: "app", "jobs", "lot").
signal ui_request(kind: String, arg: Variant)

const SPEEDS := [1.0, 2.0, 4.0]
const SHIFT_RATE := 30.0   # minutos de jogo por segundo durante turnos de trabalho
const SLEEP_RATE := 240.0

var sim: Simulation
var playing := false
var speed_index := 0
var hold_reasons: Dictionary = {}   # motivos que congelam o relógio (relatório, diálogos...)
var sleeping := false
var player: Node3D = null           # definido pelo mundo; usado para salvar posição
var pending_player_state: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	sim = Simulation.new()
	_setup_input()


func _exit_tree() -> void:
	if sim:
		sim.free()


func _process(delta: float) -> void:
	if not playing or is_held():
		return
	var rate: float = float(GameData.balance("game_minutes_per_second", 2.0)) * SPEEDS[speed_index]
	if sleeping:
		rate = SLEEP_RATE
	elif sim.jobs.is_shift():
		rate = SHIFT_RATE
	sim.advance(delta * rate)


func is_held() -> bool:
	return not hold_reasons.is_empty() or sim.paused_for_decision


func hold(reason: String, on: bool) -> void:
	if on:
		hold_reasons[reason] = true
	else:
		hold_reasons.erase(reason)


func time_speed() -> float:
	return SPEEDS[speed_index]


func cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	time_speed_changed.emit(SPEEDS[speed_index])


func start_sleep() -> void:
	sleeping = true


func stop_sleep() -> void:
	sleeping = false


func new_game(p_name: String, brand: String) -> void:
	sim.new_game(p_name, brand)
	pending_player_state = {}
	_begin()


func _begin() -> void:
	hold_reasons.clear()
	speed_index = 0
	sleeping = false
	playing = true
	session_started.emit()


func end_session() -> void:
	playing = false
	sleeping = false
	hold_reasons.clear()
	session_ended.emit()


func save_game(slot: String = "slot1") -> bool:
	if not playing:
		return false
	var extra := {}
	if is_instance_valid(player):
		extra["player_pos"] = [player.global_position.x, player.global_position.y, player.global_position.z]
	var ok := SaveSystem.save_game({"sim": sim.to_dict(), "timestamp": Time.get_datetime_string_from_system(false, true), "extra": extra}, slot)
	sim.notify("Jogo salvo." if ok else "Falha ao salvar o jogo!", "save" if ok else "error")
	return ok


func load_game(slot: String = "slot1") -> bool:
	var data := SaveSystem.load_game(slot)
	if data.is_empty() or not data.has("sim"):
		sim.notify("Nenhum jogo salvo válido encontrado.", "error")
		return false
	sim.from_dict(data.sim)
	pending_player_state = data.get("extra", {})
	_begin()
	sim.notify("Jogo carregado.", "save")
	return true


func request_ui(kind: String, arg: Variant = null) -> void:
	ui_request.emit(kind, arg)


func has_save() -> bool:
	return SaveSystem.has_save()


func debug_enabled() -> bool:
	return OS.is_debug_build() or "--dev" in OS.get_cmdline_user_args()


func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"jump": [KEY_SPACE],
		"interact": [KEY_E],
		"phone": [KEY_TAB],
		"pause": [KEY_ESCAPE],
		"time_speed": [KEY_T],
		"camera_toggle": [KEY_V],
		"quick_save": [KEY_F5],
		"quick_load": [KEY_F9],
		"debug": [KEY_F12],
		"admin": [KEY_B],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
