extends AppBase
## Apartamento do jogador: dormir (pula para o próximo dia) e salvar.


func title() -> String:
	return "Seu apartamento"


func window_size() -> Vector2:
	return Vector2(520, 360)


func build(body: VBoxContainer) -> void:
	var s := sim()
	body.add_child(UiKit.label("Um apartamento pequeno no Edifício Aurora. Aqui você descansa e organiza a vida.", 15, UiKit.MUTED, true))
	body.add_child(UiKit.button("Dormir até amanhã (encerra o dia)", func():
		ui.close_window()
		Game.start_sleep(), true, not s.jobs.is_busy()))
	body.add_child(UiKit.button("Salvar jogo", func():
		Game.save_game()
		ui.refresh()))
	if s.jobs.is_busy():
		body.add_child(UiKit.label("Termine o trabalho atual antes de dormir.", 13, UiKit.ORANGE))
	if s.has_business() and s.business.is_open():
		body.add_child(UiKit.label("Atenção: sua banca está aberta. Sem funcionários, a fila não anda enquanto você dorme.", 13, UiKit.ORANGE, true))
