class_name PeekInspector
extends Node
## Lanterna da espiada: o jogador aponta o mouse para um volume coberto dentro do galpão,
## segura a luz nele por um instante e descobre o que é. Inspeções limitadas.

signal inspected(item: Dictionary)
signal budget_changed(left: int)

const HOLD := 0.55
const RADIUS := 90.0

var yard: Yard
var items: Array = []
var left := 0
var _seen: Dictionary = {}     # index -> true
var _aim := -1
var _aim_t := 0.0
var ring: Control


func setup(y: Yard, all_items: Array, budget: int, public_count: int, overlay: Control) -> void:
	yard = y
	items = all_items
	left = budget
	for i in public_count:
		_seen[i] = true
	ring = Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(_draw_ring)
	AW.full_rect(ring)
	overlay.add_child(ring)


func _exit_tree() -> void:
	if ring and is_instance_valid(ring):
		ring.queue_free()


func _process(delta: float) -> void:
	if yard == null or not is_instance_valid(yard):
		return
	var vp := yard.get_viewport()
	var mouse := vp.get_mouse_position()
	var cam := yard.cam
	# a luz da lanterna segue o mouse
	var target := cam.project_position(mouse, 4.0)
	if yard.flash.global_position.distance_to(target) > 0.1:
		yard.flash.look_at(target, Vector3.UP)
	var best := -1
	var best_d := RADIUS
	for e in yard.item_nodes:
		var idx := int(e.index)
		if _seen.has(idx) or not is_instance_valid(e.node):
			continue
		var wp: Vector3 = e.node.global_position + Vector3(0, 0.35, 0)
		if cam.is_position_behind(wp):
			continue
		var d := cam.unproject_position(wp).distance_to(mouse)
		if d < best_d:
			best_d = d
			best = idx
	if best != _aim:
		_aim = best
		_aim_t = 0.0
	if _aim >= 0 and left > 0 and _aim < items.size():
		_aim_t += delta
		if _aim_t >= HOLD:
			_reveal(_aim)
	ring.queue_redraw()


func _reveal(idx: int) -> void:
	_seen[idx] = true
	left -= 1
	_aim = -1
	var it: Dictionary = items[idx]
	var pos := Vector2.ZERO
	for e in yard.item_nodes:
		if int(e.index) == idx and is_instance_valid(e.node):
			pos = yard.cam.unproject_position(e.node.global_position + Vector3(0, 0.6, 0))
	yard.reveal_item(idx, it, false)
	_float_name(str(it.name), pos)
	Audio.play("coin", -6.0, 1.3)
	inspected.emit(it)
	budget_changed.emit(left)


## Nome do item subindo na tela, no ponto onde a lanterna revelou.
func _float_name(text: String, pos: Vector2) -> void:
	var l := AW.label(text, 26, AW.GOLD, "ExtraBold", 6)
	l.position = pos - Vector2(160, 30)
	l.custom_minimum_size.x = 320
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ring.add_child(l)
	AW.pop(l, 1.4, 0.25)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60, 1.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.tween_callback(l.queue_free)


func _draw_ring() -> void:
	if _aim < 0 or yard == null:
		return
	for e in yard.item_nodes:
		if int(e.index) != _aim or not is_instance_valid(e.node):
			continue
		var p := yard.cam.unproject_position(e.node.global_position + Vector3(0, 0.35, 0))
		var col := AW.GOLD if left > 0 else AW.RED
		ring.draw_arc(p, 38, 0, TAU, 40, Color(col, 0.35), 3, true)
		if left > 0:
			ring.draw_arc(p, 38, -PI / 2, -PI / 2 + TAU * clampf(_aim_t / HOLD, 0, 1), 40, col, 6, true)
		else:
			ring.draw_string(AW.font("Bold"), p + Vector2(-70, 60), "SEM BATERIA", HORIZONTAL_ALIGNMENT_CENTER, 140, 16, AW.RED)
