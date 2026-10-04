class_name SettingsPanel
extends UiWindow
## Configurações gráficas, de áudio e controles.


func _ready() -> void:
	set_title("Configurações", "Gráficos, áudio e controles (salvo automaticamente)")
	_build()


func _build() -> void:
	clear_body()
	body.add_child(UiKit.heading("Vídeo", 18))
	_option("Resolução", Settings.RESOLUTIONS.map(func(r): return "%dx%d" % [r.x, r.y]), "resolution")
	_toggle("Tela cheia", "fullscreen")
	_toggle("VSync", "vsync")
	_option("Qualidade", Settings.QUALITY_NAMES, "quality")
	_toggle("Sombras", "shadows")
	_option("Distância de renderização", Settings.DISTANCE_NAMES, "render_distance")
	body.add_child(UiKit.heading("Áudio", 18))
	_slider("Volume geral", "master_volume", 0.0, 1.0)
	_slider("Música", "music_volume", 0.0, 1.0)
	_slider("Efeitos", "sfx_volume", 0.0, 1.0)
	body.add_child(UiKit.heading("Controles", 18))
	_slider("Sensibilidade do mouse", "mouse_sensitivity", 0.05, 0.8)
	_toggle("Inverter eixo Y", "invert_y")


func _row(text: String) -> HBoxContainer:
	var h := UiKit.hbox()
	h.add_child(UiKit.expand(UiKit.label(text, 16)))
	body.add_child(h)
	return h


func _option(text: String, items: Array, key: String) -> void:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.selected = int(Settings.get_value(key))
	o.custom_minimum_size.x = 220
	o.item_selected.connect(func(i): Settings.set_value(key, i))
	_row(text).add_child(o)


func _toggle(text: String, key: String) -> void:
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_value(key))
	c.toggled.connect(func(v): Settings.set_value(key, v))
	_row(text).add_child(c)


func _slider(text: String, key: String, mn: float, mx: float) -> void:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.01
	s.value = float(Settings.get_value(key))
	s.custom_minimum_size.x = 220
	s.drag_ended.connect(func(_c): Settings.set_value(key, s.value))
	_row(text).add_child(s)
