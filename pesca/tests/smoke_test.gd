extends Node
## Fluxo com interface: menu → PLAY → pescador no barco → porto → fim da noite → menu.

var fails := 0


func check(c: bool, m: String) -> void:
	if not c:
		fails += 1
		print("FALHOU: ", m)


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(1.0).timeout
	var ui: UIManager = null
	for c in main.get_children():
		if c is CanvasLayer:
			ui = c.get_child(0)
	check(ui != null and ui._current == "menu", "menu")
	ui.quick_play()
	await get_tree().create_timer(1.5).timeout
	check(ui._current == "run" and ui.director.player != null, "pescador criado no barco")
	check(ui.hud.player != null, "HUD ligado ao pescador")
	ui.hud.open_cooler()
	check(ui.hud.panel_open(), "caixa/porto abre")
	ui.hud.close_panels()
	Game.request("catch", [FishDB.roll("raso", 0, false, Game.rng)])
	await get_tree().create_timer(0.5).timeout
	Engine.time_scale = 8.0
	Game.model.minute = RunModel.NIGHT_MINUTES - 0.5
	await get_tree().create_timer(10.0).timeout
	check(Game.model.night == 2, "segunda noite (%d)" % Game.model.night)
	check(Game.model.money > 0, "pesca vendida ao amanhecer")
	Engine.time_scale = 1.0
	ui.back_to_menu()
	await get_tree().create_timer(1.0).timeout
	check(ui._current == "menu" and ui.director.player == null, "voltou ao menu")
	print("PESCA SMOKE: %s (%d falhas)" % ["OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)
