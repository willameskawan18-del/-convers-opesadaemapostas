extends AppBase
## Observação de um concorrente.


func title() -> String:
	return "Concorrente"


func window_size() -> Vector2:
	return Vector2(600, 440)


func build(body: VBoxContainer) -> void:
	var s := sim()
	if s.competition == null:
		body.add_child(UiKit.label("Uma casa de apostas concorrente. Quando você abrir sua banca, poderá acompanhar capital, reputação, odds e estratégia dela.", 15, UiKit.MUTED, true))
		return
	s.competition.build_info(body, str(arg), ui)
