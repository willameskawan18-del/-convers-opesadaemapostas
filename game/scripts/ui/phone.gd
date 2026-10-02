class_name Phone
extends PanelContainer
## Celular: interface central com os aplicativos do jogo.

signal app_chosen(app_id: String)

const APPS := [
	["banco", "Banco", Color("2e86de")], ["apostas", "Apostas", Color("10ac84")], ["noticias", "Notícias", Color("ee5253")],
	["empregos", "Empregos", Color("ff9f43")], ["admin", "Administração", Color("f5c542")], ["mercado", "Mercado", Color("8854d0")],
	["mensagens", "Mensagens", Color("0abde3")], ["contatos", "Contatos", Color("576574")], ["objetivos", "Objetivos", Color("feca57")],
	["mapa", "Mapa", Color("1dd1a1")], ["online", "Operação Online", Color("5f27cd")], ["internet", "Internet", Color("54a0ff")],
]

var _clock: Label
var _grid: GridContainer


func _ready() -> void:
	theme = UiKit.theme()
	add_theme_stylebox_override("panel", UiKit.style(Color("05070d"), 28, Color("2a3350"), 3, 18))
	custom_minimum_size = Vector2(330, 560)
	var v := UiKit.vbox(12)
	add_child(v)
	var top := UiKit.hbox()
	v.add_child(top)
	_clock = UiKit.label("", 14, UiKit.TEXT)
	top.add_child(UiKit.expand(_clock))
	top.add_child(UiKit.label("BET TYCOON OS", 12, UiKit.GOLD))
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	v.add_child(_grid)
	for a in APPS:
		var b := Button.new()
		b.text = a[1]
		b.custom_minimum_size = Vector2(92, 80)
		b.focus_mode = Control.FOCUS_NONE
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_stylebox_override("normal", UiKit.style(a[2].darkened(0.35), 16, a[2], 1, 6))
		b.add_theme_stylebox_override("hover", UiKit.style(a[2].darkened(0.1), 16, Color.WHITE, 1, 6))
		b.add_theme_stylebox_override("pressed", UiKit.style(a[2], 16, Color.WHITE, 1, 6))
		var id: String = a[0]
		b.pressed.connect(func():
			Audio.play("click", -6.0)
			app_chosen.emit(id))
		_grid.add_child(b)
	v.add_child(UiKit.label("[TAB] fecha o celular", 12, UiKit.MUTED))


func _process(_d: float) -> void:
	if visible:
		_clock.text = "Dia %d  %s" % [Game.sim.time.day, Game.sim.time.clock_text()]
		var vs := get_viewport_rect().size
		position = Vector2(vs.x - size.x - 30, vs.y - size.y - 30)
