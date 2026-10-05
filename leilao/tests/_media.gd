extends Node
## Material de loja: uma partida roteirizada (você + 3 bots) para screenshots e trailer.
##   screenshots:  godot --path . res://tests/_media.tscn -- shots <pasta>
##   trailer:      godot --path . --write-movie x.avi --fixed-fps 30 res://tests/_media.tscn -- trailer

var main: Node
var ui: UIManager
var yard: Yard
var caption_layer: CanvasLayer
var mode := "shots"
var out_dir := "user://media"
var me := -1
var bid_cap := 6000
var _phase := ""
var auto_all := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else "shots"
	if args.size() > 1:
		out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	get_window().size = Vector2i(3840, 2160) if mode == "keyart" else Vector2i(1920, 1080)
	ui = main.ui
	yard = main.yard
	caption_layer = CanvasLayer.new()
	caption_layer.layer = 50
	add_child(caption_layer)
	Game.phase_changed.connect(_on_phase)
	Game.auction_changed.connect(_auto_bid)
	await _wait(1.0)
	if mode == "trailer":
		await _trailer()
	elif mode == "keyart":
		await _keyart()
	else:
		await _shots()
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until_phase(ph: String) -> void:
	while _phase != ph:
		await get_tree().process_frame


func _on_phase(phase: String, _info: Dictionary) -> void:
	_phase = phase
	if me < 0 and Game.local_players().size() > 0:
		me = int(Game.local_players()[0].id)
	await _wait(0.3)
	match phase:
		"shop":
			Game.submit_action(me, {"buy": ["lanterna"]})
		"peek":
			if auto_all:
				Game.submit_action(me, {"ready": true})
		"sell":
			if auto_all:
				var ch := {}
				for it in Game.private_infos.get(me, {}).get("items", []):
					ch[str(it.uid)] = "loja" if not it.mystery else "abrir"
				Game.submit_action(me, {"choices": ch})


func _auto_bid(a: Dictionary) -> void:
	if float(a.get("ends_in", 0.0)) <= 0.0 or me < 0 or int(a.get("leader", -1)) == me:
		return
	if int(a.get("next_min", 100)) <= bid_cap and randf() < 0.35:
		await _wait(randf_range(0.4, 1.2))
		var b: Dictionary = Game.view.get("auction", {})
		if int(b.get("leader", -1)) != me and float(b.get("ends_in", 0.0)) > 0.0:
			Game.bid(me, int(b.get("next_min", 100)))


func _inspector() -> PeekInspector:
	return get_tree().root.find_child("Inspector", true, false) as PeekInspector


## Passa a lanterna pelos volumes cobertos, um de cada vez (o mouse vai junto).
func _sweep_flashlight(count: int) -> void:
	var insp := _inspector()
	if insp == null:
		return
	var done := 0
	for e in yard.item_nodes:
		if done >= count or insp.left <= 0:
			break
		if insp._seen.has(int(e.index)):
			continue
		var p := yard.cam.unproject_position(e.node.global_position + Vector3(0, 0.35, 0))
		Input.warp_mouse(p)
		get_viewport().warp_mouse(p)
		await _wait(PeekInspector.HOLD + 0.35)
		done += 1


func _press_haggle() -> void:
	var n := 0
	for b in ui.panels.find_children("*", "Button", true, false):
		if (b as Button).text == "PECHINCHAR" and n < 3:
			(b as Button).pressed.emit()
			(b as Button).pressed.emit()
			n += 1


func _caption(text: String, sub: String = "", dur: float = 3.0) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 210
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := AW.title(text, 66, Color.WHITE)
	l.add_theme_constant_override("outline_size", 16)
	box.add_child(l)
	if sub != "":
		box.add_child(AW.center(AW.label(sub, 30, AW.GOLD, "Bold", 8)))
	caption_layer.add_child(box)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.3)
	tw.tween_interval(maxf(0.3, dur - 0.7))
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)


func _card(title: String, sub: String, dur: float, logo: bool = false) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color("0b0f1e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption_layer.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	bg.add_child(v)
	var l := AW.title(title, 104 if logo else 64, AW.GOLD if logo else Color.WHITE)
	l.add_theme_color_override("font_shadow_color", Color(AW.PINK, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 8)
	v.add_child(l)
	if sub != "":
		v.add_child(AW.center(AW.label(sub, 34, AW.CYAN if logo else AW.MUTED, "Bold", 4)))
	bg.modulate.a = 0.0
	var tw := bg.create_tween()
	tw.tween_property(bg, "modulate:a", 1.0, 0.35)
	if dur > 0:
		tw.tween_interval(maxf(0.2, dur - 0.7))
		tw.tween_property(bg, "modulate:a", 0.0, 0.35)
		tw.tween_callback(bg.queue_free)
	return bg


func _start_match() -> void:
	Game.request_set_config("days", 2)
	ui.quick_play()
	Game.config.days = 2
	Game.config.units_per_day = 1
	Game.flow.force_special = "moto"


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name_ + ".png"))
	print("shot ", name_)


func _shots() -> void:
	await _wait(2.0)
	await _shot("01_menu")
	_start_match()
	await _until_phase("peek")
	await _wait(1.6)
	await _sweep_flashlight(2)
	var insp := _inspector()
	if insp:
		for e in yard.item_nodes:
			if not insp._seen.has(int(e.index)):
				Input.warp_mouse(yard.cam.unproject_position(e.node.global_position + Vector3(0, 0.35, 0)))
				break
	await _wait(0.3)
	await _shot("02_espiar_lanterna")
	Game.submit_action(me, {"ready": true})
	await _until_phase("auction")
	await _wait(3.0)
	for p in Game.view.players:
		if bool(p.is_bot):
			yard.say(int(p.id), "Tudo ou nada!")
			break
	await _wait(0.4)
	await _shot("03_leilao_ao_vivo")
	await _until_phase("open")
	await _wait(5.6)
	await _shot("04_abrindo_o_galpao")
	await _until_phase("sell")
	await _wait(1.0)
	_press_haggle()
	await _wait(0.4)
	await _shot("05_pechincha")
	Game.submit_action(me, {"choices": ui.panels._sell_choices.duplicate()})
	auto_all = true
	await _until_phase("day_end")
	await _wait(1.0)
	await _shot("06_ranking")
	await _until_phase("final")
	await _wait(3.5)
	await _shot("07_resultado")
	ui.back_to_menu()
	await _wait(1.5)
	CareerUi.open_career(ui.modal_root)
	await _wait(0.6)
	await _shot("08_carreira")


func _trailer() -> void:
	Audio.play_music("music_menu")
	await _wait(1.0)
	_card("VOCÊ COMPRARIA UM GALPÃO", "...sem saber o que tem dentro?", 3.4)
	await _wait(3.6)
	_caption("LEILÃO DE GARAGEM", "Compre às cegas. Abra. Revenda.", 3.2)
	await _wait(3.4)
	var cover := _card("", "", 0)
	_start_match()
	await _until_phase("peek")
	await _wait(1.2)
	cover.queue_free()
	_caption("ESPIE COM A LANTERNA", "", 3.0)
	await _sweep_flashlight(3)
	await _wait(0.6)
	Game.submit_action(me, {"ready": true})
	await _until_phase("auction")
	_caption("DÊ LANCES AO VIVO", "contra amigos ou bots com personalidade", 3.4)
	await _until_phase("open")
	_caption("E AGORA...", "tralha ou fortuna?", 2.6)
	await _wait(9.0)
	await _until_phase("sell")
	await _wait(0.6)
	_caption("PECHINCHE. COLECIONE. REVENDA.", "", 3.0)
	await _wait(0.8)
	_press_haggle()
	await _wait(2.4)
	Game.submit_action(me, {"choices": ui.panels._sell_choices.duplicate()})
	auto_all = true
	await _wait(3.5)
	var c2 := _card("1 A 6 JOGADORES", "Online ou contra bots · Partidas de 15 minutos", 0)
	await _wait(2.5)
	Engine.time_scale = 8.0
	await _until_phase("final")
	Engine.time_scale = 1.0
	c2.queue_free()
	await _wait(1.0)
	_caption("QUEM TERMINAR MAIS RICO VENCE", "", 3.2)
	await _wait(3.6)
	_card("LEILÃO DE GARAGEM", "Adicione à sua Lista de Desejos na Steam", 5.0, true)
	await _wait(5.2)


## Arte-chave sem interface (4K): galpão aberto com o tesouro brilhando e os compradores.
func _keyart() -> void:
	Engine.time_scale = 4.0
	_start_match()
	await _until_phase("auction")
	bid_cap = 20000
	await _until_phase("open")
	Engine.time_scale = 1.0
	await _wait(7.0)
	ui.visible = false
	for l in yard.bidder_labels.values():
		(l as Label3D).visible = false
	yard.all_anim("shock")
	yard.shot("wide", 0.01)
	yard.cam.global_transform = Transform3D(Basis(), Vector3(0.6, 2.2, 8.5)).looking_at(Vector3(0, 1.0, -3.0), Vector3.UP)
	yard._cam_to = yard.cam.global_transform
	yard._cam_from = yard.cam.global_transform
	await _wait(0.5)
	await _shot("keyart_a")
