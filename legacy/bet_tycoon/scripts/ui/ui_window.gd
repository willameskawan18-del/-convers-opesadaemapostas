class_name UiWindow
extends PanelContainer
## Janela central reutilizável: barra de título, botão fechar e corpo com rolagem.

signal closed

var body: VBoxContainer
var scroll: ScrollContainer
var _title: Label
var _subtitle: Label


func _init() -> void:
	theme = UiKit.theme()
	add_theme_stylebox_override("panel", UiKit.style(UiKit.PANEL, 14, UiKit.GOLD.darkened(0.45), 1, 18))
	var root := UiKit.vbox(10)
	add_child(root)
	var top := UiKit.hbox()
	root.add_child(top)
	var tv := UiKit.vbox(0)
	top.add_child(UiKit.expand(tv))
	_title = UiKit.bold(UiKit.label("", 24, UiKit.GOLD), "Bold") as Label
	tv.add_child(_title)
	_subtitle = UiKit.label("", 13, UiKit.MUTED)
	tv.add_child(_subtitle)
	top.add_child(UiKit.button("  X  ", func(): closed.emit()))
	UiKit.sep(root)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	body = UiKit.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)


func set_title(t: String, sub: String = "") -> void:
	_title.text = t
	_subtitle.text = sub
	_subtitle.visible = sub != ""


func clear_body() -> void:
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()


## Centraliza com o tamanho dado (em pixels de tela base 1280x720).
func layout(size_px: Vector2) -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = size_px
	size = size_px
	position = (_parent_size() - size_px) / 2.0 if get_parent() else Vector2.ZERO


func _parent_size() -> Vector2:
	var p := get_parent()
	if p is Control:
		return p.size
	return get_viewport_rect().size
