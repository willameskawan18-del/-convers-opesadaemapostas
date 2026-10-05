class_name AW
## Identidade visual do ALL WIN: cores, fontes, estilos e componentes de interface.

const BG := Color("12052b")
const PANEL := Color("1d0b40")
const PANEL2 := Color("2a1257")
const PINK := Color("ff2e88")
const GOLD := Color("ffcc33")
const CYAN := Color("27e1ff")
const GREEN := Color("3ddc97")
const RED := Color("ff4d6d")
const ORANGE := Color("ff9f1c")
const PURPLE := Color("b072ff")
const TEXT := Color("fff6e8")
const MUTED := Color("b9a8d9")

static var _theme: Theme
static var _fonts: Dictionary = {}


static func font(weight: String = "Regular") -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var path := "res://assets/fonts/Poppins-%s.ttf" % weight
	var f: Font = load(path) if ResourceLoader.exists(path) else null
	_fonts[weight] = f
	return f


static func style(bg: Color, radius: int = 14, border: Color = Color(0, 0, 0, 0), border_w: int = 0, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	return s


static func glow_style(bg: Color, glow: Color, radius: int = 16, border_w: int = 3, pad: int = 16) -> StyleBoxFlat:
	var s := style(bg, radius, glow, border_w, pad)
	s.shadow_color = Color(glow, 0.45)
	s.shadow_size = 14
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("SemiBold")
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_stylebox("panel", "PanelContainer", glow_style(Color(PANEL, 0.92), Color(PINK, 0.5), 18, 2, 18))
	t.set_stylebox("panel", "Panel", style(Color(PANEL, 0.9), 18))
	t.set_stylebox("normal", "Button", _btn(PANEL2, Color(1, 1, 1, 0.12)))
	t.set_stylebox("hover", "Button", _btn(PANEL2.lightened(0.15), GOLD))
	t.set_stylebox("pressed", "Button", _btn(GOLD.darkened(0.25), GOLD))
	t.set_stylebox("focus", "Button", _btn(Color(0, 0, 0, 0), Color(GOLD, 0.7)))
	t.set_stylebox("disabled", "Button", _btn(Color(0.12, 0.08, 0.2), Color(1, 1, 1, 0.04)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.4))
	t.set_font("font", "Button", font("Bold"))
	t.set_font_size("font_size", "Button", 20)
	t.set_stylebox("normal", "LineEdit", style(Color("0d0420"), 10, Color(1, 1, 1, 0.15), 2, 12))
	t.set_stylebox("focus", "LineEdit", style(Color("0d0420"), 10, GOLD, 2, 12))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_font_size("font_size", "LineEdit", 20)
	t.set_stylebox("slider", "HSlider", style(Color(1, 1, 1, 0.12), 6, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("grabber_area", "HSlider", style(PINK, 6, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", style(GOLD, 6, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("background", "ProgressBar", style(Color(1, 1, 1, 0.1), 8, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("fill", "ProgressBar", style(GOLD, 8, Color(0, 0, 0, 0), 0, 0))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_stylebox("normal", "OptionButton", _btn(PANEL2, Color(1, 1, 1, 0.12)))
	t.set_stylebox("hover", "OptionButton", _btn(PANEL2.lightened(0.15), GOLD))
	t.set_stylebox("panel", "PopupMenu", style(PANEL, 10, Color(PINK, 0.5), 2, 8))
	t.set_stylebox("panel", "TooltipPanel", style(PANEL, 8, GOLD, 1, 8))
	_theme = t
	return t


static func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var s := style(bg, 14, border, 2, 18)
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func label(text: String, size: int = 18, color: Color = TEXT, weight: String = "SemiBold", outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var f := font(weight)
	if f:
		l.add_theme_font_override("font", f)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	return l


static func title(text: String, size: int = 64, color: Color = GOLD) -> Label:
	var l := label(text, size, color, "ExtraBold", maxi(4, size / 7))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color("3a0a3f"))
	l.add_theme_color_override("font_shadow_color", Color(PINK, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 6)
	return l


static func center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Botão grande colorido. color = cor de destaque.
static func button(text: String, cb: Callable, color: Color = PINK, size: int = 22, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _btn_col(color, 0.0))
	b.add_theme_stylebox_override("hover", _btn_col(color, 0.18))
	b.add_theme_stylebox_override("pressed", _btn_col(color.lightened(0.3), 0.3))
	b.add_theme_stylebox_override("focus", _btn_col(color, 0.18))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(func():
		Audio.play("click")
		cb.call())
	b.mouse_entered.connect(func(): Audio.play("hover", -6.0))
	return b


static func _btn_col(color: Color, light: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color.darkened(0.35).lightened(light)
	s.set_corner_radius_all(16)
	s.border_color = color.lightened(0.25 + light)
	s.set_border_width_all(3)
	s.border_width_bottom = 6
	s.shadow_color = Color(color, 0.35 + light)
	s.shadow_size = 8 + int(light * 30)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	s.anti_aliasing = true
	return s


static func panel(bg: Color = Color(PANEL, 0.94), glow: Color = PINK, pad: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", glow_style(bg, Color(glow, 0.7), 20, 2, pad))
	return p


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(min_size: float = 0.0, vertical: bool = false) -> Control:
	var c := Control.new()
	if vertical:
		c.custom_minimum_size.y = min_size
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL if min_size == 0.0 else Control.SIZE_SHRINK_BEGIN
	else:
		c.custom_minimum_size.x = min_size
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL if min_size == 0.0 else Control.SIZE_SHRINK_BEGIN
	return c


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func centered(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	full_rect(cc)
	cc.add_child(c)
	return cc


## Animação "pop" (escala) para chamar atenção.
static func pop(c: Control, strength: float = 1.25, time: float = 0.35) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2.0
	var tw := c.create_tween()
	c.scale = Vector2.ONE * strength
	tw.tween_property(c, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func slam(c: Control, from_scale: float = 3.0, time: float = 0.45) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ONE * from_scale
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, time * 0.5)


static func fade_in(c: Control, time: float = 0.3, from_y: float = 30.0) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "modulate:a", 1.0, time)
	if from_y != 0.0 and c.is_inside_tree():
		var y := c.position.y
		c.position.y = y + from_y
		tw.tween_property(c, "position:y", y, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


static func char_color(id: String) -> Color:
	return GameData.character_color(id)


## Selo de posição: 1º ouro, 2º prata, 3º bronze.
static func place_color(pos: int) -> Color:
	match pos:
		1: return GOLD
		2: return Color("d9e2ec")
		3: return Color("e0915a")
	return MUTED
