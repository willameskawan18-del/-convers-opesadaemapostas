extends AppBase
## Observação de um concorrente (placa na fachada).


func title() -> String:
	var c := sim().competition.get_comp(str(arg))
	return str(c.get("name", "Concorrente"))


func subtitle() -> String:
	return "Inteligência de mercado"


func window_size() -> Vector2:
	return Vector2(640, 520)


func build(body: VBoxContainer) -> void:
	CompetitorCard.build(body, sim(), str(arg), ui, true)
