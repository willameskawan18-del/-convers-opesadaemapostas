extends Node
## Material de loja: cenas roteirizadas para screenshots e trailer.
##   screenshots:  godot --path . res://tests/_media.tscn -- shots <pasta>
##   trailer:      godot --path . --write-movie x.avi --fixed-fps 30 res://tests/_media.tscn -- trailer

var ui: UIManager
var world: World
var dir: Director
var mcam: Camera3D
var caption_layer: CanvasLayer
var mode := "shots"
var out_dir := "user://media"
var _cam_fn: Callable
var _t := 0.0
var _scene_t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else "shots"
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	get_window().size = Vector2i(3840, 2160) if mode == "keyart" else Vector2i(1920, 1080)
	for c in main.get_children():
		if c is CanvasLayer:
			ui = c.get_child(0)
		elif c is World:
			world = c
	dir = ui.director
	if world == null:
		world = dir.world
	mcam = Camera3D.new()
	mcam.fov = 60
	world.add_child(mcam)
	caption_layer = CanvasLayer.new()
	caption_layer.layer = 50
	add_child(caption_layer)
	Profile.data.tutorial_done = true
	await get_tree().create_timer(0.5).timeout
	if mode == "trailer":
		await _trailer()
	elif mode == "keyart":
		await _keyart()
	else:
		await _shots()
	get_tree().quit()


# --- Controle do mundo ---------------------------------------------------------------

func _setup_run(zone_dist: float, weather: String, minute: float = 120.0) -> void:
	if not Game.in_run():
		ui.quick_play()
		await get_tree().create_timer(1.0).timeout
	var m := Game.model
	Game.paused_for_summary = true
	m.pos = Vector3(0, 0, zone_dist)
	m.yaw = 0.0
	m.speed = 0.0
	m.minute = minute
	m.weather = weather
	m.tentacle = {}
	m.eyes = {}
	m.leaks.clear()
	m.lantern = true
	m.money = 2350
	m.sold_cycle = 480
	Game._send_run()
	Game._send_state()
	world._boat_pos = m.pos
	await get_tree().process_frame
	world.ocean.set_depth(world._depth)
	ui.hud.close_panels()
	if dir.player:
		dir.player.fishing.cancel()
	ui.hud.catch_card = null
	AW.clear(ui.hud.notes)
	Ocean.amp = {"tempestade": 1.9, "nevoeiro": 0.7}.get(weather, 1.0)
	world.creatures.tentacle_down()
	world.creatures.hide_eyes()


func _hud(on: bool) -> void:
	ui.hud.visible = on


func _orbit(dist: float, height: float, speed: float, offset: float = 0.0) -> Callable:
	return func(t: float):
		var b := world.boat.global_position
		var a := offset + t * speed
		mcam.global_position = b + Vector3(sin(a) * dist, height, cos(a) * dist)
		mcam.look_at(b + Vector3(0, 1.0, 0))


func _fp(yaw: float, pitch: float) -> Callable:
	return func(t: float):
		var p := dir.player
		if p:
			p.yaw = yaw + sin(t * 0.4) * 0.05
			p.pitch = pitch
			p.cam.make_current()


func _process(delta: float) -> void:
	_t += delta
	_scene_t += delta
	if Game.in_run():
		Game._send_state()
	if _cam_fn.is_valid():
		_cam_fn.call(_scene_t)


func _use(cam_fn: Callable, media: bool = true) -> void:
	_scene_t = 0.0
	_cam_fn = cam_fn
	if media:
		mcam.make_current()


func _caption(text: String, sub: String = "", dur: float = 3.0) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 200
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := AW.title(text, 58, Color.WHITE)
	l.add_theme_constant_override("outline_size", 14)
	box.add_child(l)
	if sub != "":
		var s := AW.center(AW.label(sub, 30, AW.CYAN, "Bold", 8))
		box.add_child(s)
	caption_layer.add_child(box)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.35)
	tw.tween_interval(maxf(0.3, dur - 0.8))
	tw.tween_property(box, "modulate:a", 0.0, 0.45)
	tw.tween_callback(box.queue_free)


func _card(title: String, sub: String, dur: float, logo: bool = false) -> void:
	var bg := ColorRect.new()
	bg.color = Color("03060d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption_layer.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	bg.add_child(v)
	var l := AW.title(title, 104 if logo else 64, AW.CYAN if logo else Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color(AW.PURPLE, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 8)
	v.add_child(l)
	if sub != "":
		v.add_child(AW.center(AW.label(sub, 34, AW.GOLD if logo else AW.MUTED, "Bold", 4)))
	bg.modulate.a = 0.0
	var tw := bg.create_tween()
	tw.tween_property(bg, "modulate:a", 1.0, 0.4)
	tw.tween_interval(maxf(0.2, dur - 0.8))
	tw.tween_property(bg, "modulate:a", 0.0, 0.4)
	tw.tween_callback(bg.queue_free)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _legend() -> Dictionary:
	return {"id": "coracao", "name": "Coração do Abismo", "rarity": "lendario", "kg": 31.4, "value": 3120, "strength": 1.2, "color": "#ff2e88", "size": 1.2, "glow": true}


# --- Cenas ------------------------------------------------------------------------

func scene_hero() -> void:
	await _setup_run(70.0, "calmo")
	_hud(false)
	_use(_orbit(9.5, 2.2, 0.12, 0.6))


func scene_cast() -> void:
	await _setup_run(200.0, "calmo")
	_hud(true)
	_use(_fp(PI * 0.5, -0.12), false)
	await _wait(0.4)
	dir.player.fishing.press()
	await _wait(0.9)
	dir.player.fishing.release()


func scene_reel() -> void:
	await _setup_run(220.0, "calmo")
	_hud(true)
	_use(_fp(PI * 0.5, -0.2), false)
	var f := dir.player.fishing
	f.cancel()
	f._land = dir.player.cam.global_position + Vector3(-9, -1.6, 0)
	f.bobber.visible = true
	f.bobber.global_position = f._land
	f._start_reel()
	f.tension = 0.55
	f.progress = 0.62


func scene_catch() -> void:
	await _setup_run(420.0, "calmo")
	_hud(true)
	_use(_fp(PI * 0.5, -0.05), false)
	await _wait(0.2)
	var fish := _legend()
	dir.player._show_landed(fish, dir.player.cam.global_position + Vector3(-7, -1.5, 0))
	ui.hud._on_catch(Game.my_pid(), fish)
	Audio.play("jackpot")


func scene_tentacle() -> void:
	await _setup_run(430.0, "calmo")
	_hud(false)
	world.creatures.tentacle_rise(1.0)
	Audio.play("roar")
	_use(func(t: float):
		var b := world.boat
		var bx := b.global_transform.basis.x
		mcam.global_position = b.global_position - bx * 1.5 + Vector3(0, 1.0, 0) + b.global_transform.basis.z * (3.2 - t * 0.2)
		mcam.look_at(b.global_position + bx * 3.4 + Vector3(0, 3.8, 0)))


func scene_eyes() -> void:
	await _setup_run(450.0, "nevoeiro", 300.0)
	_hud(true)
	world.creatures.show_eyes(0.0)
	world.creatures._eyes_on = 0.8
	Game.model.lantern = false
	Game._send_run()
	Audio.play("suspense")
	_use(_fp(PI, 0.1), false)


func scene_storm() -> void:
	await _setup_run(260.0, "tempestade")
	_hud(false)
	world._lightning_t = 1.25
	_use(_orbit(8.0, 1.6, -0.1, 2.4))


func scene_dock() -> void:
	await _setup_run(14.0, "calmo")
	Game.model.cooler = [_legend(), {"id": "x", "name": "Atum", "rarity": "raro", "kg": 12.0, "value": 340}]
	Game._send_run()
	_hud(true)
	_use(_fp(PI * 1.25, -0.3), false)
	await _wait(0.3)
	ui.hud.open_cooler()


func scene_bestiary() -> void:
	for f in GameData.load_json("fish").fish.slice(0, 19):
		Profile.data.bestiary[str(f.id)] = {"count": randi_range(1, 30), "best_kg": randf_range(1, 40)}
	await _setup_run(80.0, "calmo")
	_hud(true)
	_use(_orbit(9.0, 3.0, 0.05))
	MetaUi.open_bestiary(ui.hud.panel)


func scene_lighthouse() -> void:
	await _setup_run(40.0, "calmo")
	_hud(false)
	_use(func(t: float):
		mcam.global_position = Vector3(-14 + t * 0.6, 6.0, 60)
		mcam.look_at(Vector3(0, 3.0, 10)))


# --- Saídas -------------------------------------------------------------------------

func _shot(name_: String) -> void:
	await _wait(1.6)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name_ + ".png"))
	print("shot ", name_)


func _shots() -> void:
	var scenes := [["01_noite", scene_hero], ["02_arremesso", scene_cast], ["03_puxando", scene_reel], ["04_lendario", scene_catch],
		["05_tentaculo", scene_tentacle], ["06_olhos_na_nevoa", scene_eyes], ["07_tempestade", scene_storm], ["08_porto", scene_dock],
		["09_bestiario", scene_bestiary], ["10_farol", scene_lighthouse]]
	var only := OS.get_cmdline_user_args().slice(2)
	for s in scenes:
		if only.size() > 0 and not only.has(s[0]):
			continue
		await s[1].call()
		await _shot(s[0])
		ui.hud.close_panels()


func _trailer() -> void:
	Audio.play_music("music_menu")
	_card("", "", 0.1)
	await scene_lighthouse()
	_caption("UMA NOITE. UM BARCO.", "", 3.0)
	await _wait(3.2)
	await scene_hero()
	_caption("E UMA COTA PARA PAGAR.", "Pesca cooperativa para 1 a 4 jogadores", 3.4)
	await _wait(3.6)
	await scene_cast()
	_caption("ARREMESSE...", "", 2.2)
	await _wait(2.6)
	await scene_reel()
	_caption("...SEGURE A LINHA...", "", 2.4)
	await _wait(2.8)
	await scene_catch()
	_caption("", "28 espécies. Algumas não deveriam existir.", 3.4)
	await _wait(3.8)
	_card("QUANTO MAIS FUNDO", "mais valioso o peixe", 2.4)
	await _wait(2.2)
	await scene_tentacle()
	await _wait(0.3)
	_caption("MAIS PERIGOSO O MAR.", "", 3.0)
	await _wait(3.4)
	await scene_eyes()
	_caption("APAGUE A LANTERNA.", "Não se mexa.", 3.4)
	await _wait(3.8)
	await scene_storm()
	_caption("TEMPESTADES. NÉVOA. LEVIATÃS.", "", 3.4)
	await _wait(3.8)
	await scene_dock()
	_caption("", "Venda, melhore o barco e sobreviva a mais uma noite.", 3.2)
	await _wait(3.4)
	ui.hud.close_panels()
	await scene_hero()
	_use(_orbit(16.0, 5.0, 0.08, 1.2))
	await _wait(0.6)
	_card("PESCA NO ABISMO", "Adicione à sua Lista de Desejos na Steam", 5.0, true)
	await _wait(5.2)


## Arte-chave sem interface (4K) para as cápsulas da loja.
func _keyart() -> void:
	await _setup_run(430.0, "calmo", 300.0)
	_hud(false)
	world.creatures.tentacle_rise(-1.0)
	world.creatures.show_eyes(PI * 0.82)
	world.creatures._eyes_on = 0.9
	mcam.fov = 55
	_use(func(_t: float):
		var b := world.boat
		mcam.global_position = b.global_position + Vector3(-4.5, 1.6, 9.5)
		mcam.look_at(b.global_position + Vector3(-1.0, 2.6, -6.0)))
	await _wait(3.5)
	await _shot("keyart_a")
	await _setup_run(70.0, "calmo")
	_hud(false)
	_use(func(_t: float):
		var b := world.boat
		mcam.global_position = b.global_position + Vector3(7.0, 1.2, 6.0)
		mcam.look_at(b.global_position + Vector3(0, 1.6, -4.0)))
	await _wait(1.0)
	await _shot("keyart_b")
