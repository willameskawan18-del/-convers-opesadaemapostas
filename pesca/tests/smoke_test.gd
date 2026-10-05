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
	Profile.clear_expedition()
	ui.quick_play()
	await get_tree().create_timer(1.5).timeout
	check(ui._current == "run" and ui.director.player != null, "pescador criado no barco")
	check(ui.hud.player != null, "HUD ligado ao pescador")
	ui.hud.open_cooler()
	check(ui.hud.panel_open(), "caixa/porto abre")
	ui.hud.close_panels()
	var before := int(Profile.data.total_caught)
	var fish := FishDB.roll("raso", 0, false, Game.rng)
	Game.request("catch", [fish])
	ui.director.player._show_landed(fish, ui.director.player.global_position + Vector3(0, -1, 3))
	await get_tree().create_timer(0.5).timeout
	check(int(Profile.data.total_caught) == before + 1, "captura registrada no perfil")
	check(Profile.data.bestiary.has(str(fish.id)), "espécie no bestiário")
	check(Profile.data.achievements.has("primeiro"), "conquista primeiro peixe")
	MetaUi.open_bestiary(ui.hud.panel)
	check(ui.hud.panel_open(), "bestiário abre")
	ui.hud.close_panels()
	Engine.time_scale = 8.0
	Game.model.minute = RunModel.NIGHT_MINUTES - 0.5
	await get_tree().create_timer(10.0).timeout
	check(Game.model.night == 2, "segunda noite (%d)" % Game.model.night)
	check(Game.model.money > 0, "pesca vendida ao amanhecer")
	check(Profile.has_expedition(), "expedição salva ao amanhecer")
	Engine.time_scale = 1.0
	ui.back_to_menu()
	await get_tree().create_timer(1.0).timeout
	check(ui._current == "menu" and ui.director.player == null, "voltou ao menu")
	var money := Game.model.money
	ui.quick_play(true)
	await get_tree().create_timer(1.5).timeout
	check(ui._current == "run" and Game.model.night == 2 and Game.model.money == money, "continuar expedição (noite %d)" % Game.model.night)
	ui.back_to_menu()
	await get_tree().create_timer(0.5).timeout
	print("PESCA SMOKE: %s (%d falhas)" % ["OK" if fails == 0 else "FALHOU", fails])
	get_tree().quit(1 if fails else 0)
