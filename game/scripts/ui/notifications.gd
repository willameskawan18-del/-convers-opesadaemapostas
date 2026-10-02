class_name Notifications
extends VBoxContainer
## Notificações discretas no canto superior direito (não ocupam a tela).

const MAX := 3
const DURATION := 4.5

const KIND_COLORS := {
	"error": UiKit.RED, "lose": UiKit.RED, "warning": UiKit.ORANGE,
	"win": UiKit.GREEN, "cash": UiKit.GREEN, "objective": UiKit.GOLD, "chapter": UiKit.GOLD,
	"level": UiKit.GOLD, "unlock": UiKit.BLUE, "event": UiKit.ORANGE, "job": UiKit.BLUE,
	"bet": UiKit.BLUE, "save": UiKit.MUTED, "competitor": Color("c77dff"),
}
const KIND_SOUNDS := {
	"error": "error", "lose": "lose", "win": "win", "cash": "cash", "level": "levelup",
	"chapter": "levelup", "objective": "notify", "event": "notify", "unlock": "notify",
	"warning": "notify", "competitor": "notify",
}


func _ready() -> void:
	theme = UiKit.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	Game.sim.notified.connect(push)


func _process(_d: float) -> void:
	var vs := get_viewport_rect().size
	position = Vector2(vs.x - 380 - 226, 16)
	custom_minimum_size.x = 364


func push(text: String, kind: String = "info") -> void:
	if not is_inside_tree():
		return
	var col: Color = KIND_COLORS.get(kind, UiKit.TEXT)
	var p := PanelContainer.new()
	var st := UiKit.style(Color(0.05, 0.08, 0.15, 0.92), 8, col.darkened(0.2), 0, 10)
	st.border_width_left = 4
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(text, 15, UiKit.TEXT, true)
	l.custom_minimum_size.x = 330
	p.add_child(l)
	add_child(p)
	if KIND_SOUNDS.has(kind):
		Audio.play(KIND_SOUNDS[kind], -6.0)
	while get_child_count() > MAX:
		var old := get_child(0)
		remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(DURATION)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
