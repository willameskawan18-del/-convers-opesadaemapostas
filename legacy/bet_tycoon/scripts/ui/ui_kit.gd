class_name UiKit
## Tema e componentes de UI reutilizáveis (identidade visual: azul-noite + dourado).

const BG := Color("0b1120")
const PANEL := Color("131b2e")
const PANEL2 := Color("1b2540")
const GOLD := Color("f5c542")
const TEXT := Color("e8ecf3")
const MUTED := Color("8a94a8")
const GREEN := Color("3ddc84")
const RED := Color("ff5a5f")
const BLUE := Color("4ea8ff")
const ORANGE := Color("ff9f43")

static var _theme: Theme


static var _fonts: Dictionary = {}


## Poppins (licença OFL) embutida em assets/fonts. weight: Regular, SemiBold, Bold, ExtraBold.
static func font(weight: String = "Regular") -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var path := "res://assets/fonts/Poppins-%s.ttf" % weight
	var f: Font = load(path) if ResourceLoader.exists(path) else null
	_fonts[weight] = f
	return f


static func bold(l: Control, weight: String = "SemiBold") -> Control:
	var f := font(weight)
	if f:
		l.add_theme_font_override("font", f)
	return l


static func style(bg: Color, radius: int = 10, border: Color = Color(0, 0, 0, 0), border_w: int = 0, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 16
	var f := font("Regular")
	if f:
		t.default_font = f
	t.set_color("font_color", "Label", TEXT)
	var panel_st := style(PANEL, 12, Color(1, 1, 1, 0.06), 1, 14)
	panel_st.shadow_size = 10
	panel_st.shadow_color = Color(0, 0, 0, 0.35)
	t.set_stylebox("panel", "PanelContainer", panel_st)
	t.set_stylebox("panel", "Panel", style(PANEL, 12))
	t.set_stylebox("normal", "Button", style(PANEL2, 8, Color(1, 1, 1, 0.08), 1, 12))
	t.set_stylebox("hover", "Button", style(PANEL2.lightened(0.12), 8, GOLD.darkened(0.2), 1, 12))
	t.set_stylebox("pressed", "Button", style(GOLD.darkened(0.3), 8, GOLD, 1, 12))
	t.set_stylebox("disabled", "Button", style(Color(0.1, 0.12, 0.18), 8, Color(1, 1, 1, 0.03), 1, 12))
	t.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), 8, GOLD.darkened(0.3), 1, 12))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	t.set_stylebox("normal", "LineEdit", style(Color("0e1526"), 8, Color(1, 1, 1, 0.12), 1, 10))
	t.set_stylebox("focus", "LineEdit", style(Color("0e1526"), 8, GOLD, 1, 10))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("background", "ProgressBar", style(Color(1, 1, 1, 0.08), 6, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("fill", "ProgressBar", style(GOLD, 6, Color(0, 0, 0, 0), 0, 0))
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_stylebox("separator", "HSeparator", style(Color(1, 1, 1, 0.08), 0, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("panel", "TooltipPanel", style(PANEL2, 6))
	t.set_stylebox("normal", "OptionButton", style(PANEL2, 8, Color(1, 1, 1, 0.08), 1, 10))
	t.set_stylebox("hover", "OptionButton", style(PANEL2.lightened(0.1), 8, GOLD, 1, 10))
	t.set_stylebox("pressed", "OptionButton", style(PANEL2, 8, GOLD, 1, 10))
	t.set_stylebox("normal", "SpinBox", style(PANEL2, 8))
	_theme = t
	return t


static func label(text: String, size: int = 16, color: Color = TEXT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 100
	return l


static func heading(text: String, size: int = 20) -> Label:
	return bold(label(text, size, GOLD)) as Label


static func button(text: String, cb: Callable, primary: bool = false, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", style(GOLD.darkened(0.1), 8, GOLD, 1, 12))
		b.add_theme_stylebox_override("hover", style(GOLD, 8, Color.WHITE, 1, 12))
		b.add_theme_color_override("font_color", Color("1a1405"))
		b.add_theme_color_override("font_hover_color", Color("1a1405"))
	b.pressed.connect(func():
		Audio.play("click", -8.0)
		cb.call())
	b.mouse_entered.connect(func(): Audio.play("hover", -20.0))
	return b


static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


## Cartão com fundo; retorna o VBox interno para adicionar conteúdo.
static func card(parent: Control, bg: Color = PANEL2, border: Color = Color(1, 1, 1, 0.05)) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, 10, border, 1, 12))
	parent.add_child(p)
	var v := vbox(6)
	p.add_child(v)
	return v


static func expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Linha "chave ...... valor".
static func kv(parent: Control, key: String, value: String, value_color: Color = TEXT) -> HBoxContainer:
	var h := hbox()
	h.add_child(expand(label(key, 15, MUTED)))
	var v := label(value, 15, value_color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	parent.add_child(h)
	return h


static func bar(value: float, max_value: float, color: Color = GOLD, height: float = 10.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maxf(max_value, 0.001)
	b.value = clampf(value, 0.0, b.max_value)
	b.show_percentage = false
	b.custom_minimum_size.y = height
	b.add_theme_stylebox_override("fill", style(color, 6, Color(0, 0, 0, 0), 0, 0))
	return b


static func sep(parent: Control) -> void:
	parent.add_child(HSeparator.new())


static func money_color(v: float) -> Color:
	return GREEN if v >= 0 else RED


static func risk_color(level: String) -> Color:
	match level:
		"BAIXO": return GREEN
		"MÉDIO": return GOLD
		"ALTO": return ORANGE
		_: return RED


static func status_line(parent: Control, ok: bool, text: String) -> void:
	parent.add_child(label(("OK  " if ok else "FALTA  ") + text, 15, GREEN if ok else RED))
