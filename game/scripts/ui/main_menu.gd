class_name MainMenu
extends Control
## Menu principal: BET TYCOON — Da Banca ao Cassino.

signal new_game_requested(player_name: String, brand: String)
signal continue_requested
signal settings_requested
signal quit_requested

var _buttons: VBoxContainer
var _new_form: PanelContainer
var _continue_btn: Button
var _info: Label
var _name_edit: LineEdit
var _brand_edit: LineEdit


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.07, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.03, 0.07, 0.95))
	g.set_color(1, Color(0.02, 0.03, 0.07, 0.0))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)
	var col := UiKit.vbox(14)
	col.position = Vector2(90, 110)
	add_child(col)
	var t := UiKit.label("BET TYCOON", 86, UiKit.GOLD)
	t.add_theme_constant_override("outline_size", 10)
	t.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.0, 0.8))
	col.add_child(t)
	col.add_child(UiKit.label("DA BANCA AO CASSINO", 26, UiKit.TEXT))
	col.add_child(UiKit.label("Comece com R$ 100. Construa um império de entretenimento.", 16, UiKit.MUTED))
	var gap := Control.new()
	gap.custom_minimum_size.y = 30
	col.add_child(gap)
	_buttons = UiKit.vbox(10)
	col.add_child(_buttons)
	_continue_btn = _menu_button("CONTINUAR", func(): continue_requested.emit())
	_menu_button("NOVO JOGO", _show_new_form)
	_menu_button("CONFIGURAÇÕES", func(): settings_requested.emit())
	_menu_button("SAIR", func(): quit_requested.emit())
	_info = UiKit.label("", 14, UiKit.MUTED)
	col.add_child(_info)
	var foot := UiKit.label("Jogo de simulação. Todo dinheiro e todas as apostas são fictícios.", 12, Color(1, 1, 1, 0.4))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 90
	foot.offset_top = -40
	add_child(foot)
	_build_new_form()
	refresh()


func _menu_button(text: String, cb: Callable) -> Button:
	var b := UiKit.button(text, cb)
	b.custom_minimum_size = Vector2(320, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_buttons.add_child(b)
	return b


func refresh() -> void:
	var has := Game.has_save()
	_continue_btn.disabled = not has
	if has:
		var info := SaveSystem.save_info()
		_info.text = "Save: %s — Dia %d — %s" % [info.get("brand", ""), int(info.get("day", 1)), Fmt.money(float(info.get("cash", 0)))] if not info.is_empty() else ""
	else:
		_info.text = ""
	_new_form.visible = false


func _build_new_form() -> void:
	_new_form = PanelContainer.new()
	_new_form.add_theme_stylebox_override("panel", UiKit.style(UiKit.PANEL, 14, UiKit.GOLD.darkened(0.3), 1, 22))
	_new_form.position = Vector2(470, 300)
	add_child(_new_form)
	var v := UiKit.vbox(10)
	_new_form.add_child(v)
	v.add_child(UiKit.heading("Novo jogo", 22))
	v.add_child(UiKit.label("Seu nome", 14, UiKit.MUTED))
	_name_edit = LineEdit.new()
	_name_edit.text = "Alex"
	_name_edit.custom_minimum_size.x = 320
	v.add_child(_name_edit)
	v.add_child(UiKit.label("Nome da sua futura marca", 14, UiKit.MUTED))
	_brand_edit = LineEdit.new()
	_brand_edit.text = "Fortuna Bet"
	v.add_child(_brand_edit)
	if Game.has_save():
		v.add_child(UiKit.label("Atenção: o save atual será substituído ao salvar.", 13, UiKit.ORANGE))
	var h := UiKit.hbox()
	v.add_child(h)
	h.add_child(UiKit.button("Cancelar", func(): _new_form.visible = false))
	h.add_child(UiKit.button("COMEÇAR", func(): new_game_requested.emit(_name_edit.text.substr(0, 20), _brand_edit.text.substr(0, 24)), true))
	_new_form.visible = false


func _show_new_form() -> void:
	_new_form.visible = true
