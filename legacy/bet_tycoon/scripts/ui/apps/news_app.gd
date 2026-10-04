extends AppBase
## Notícias esportivas e resultados. Notícias alteram as chances reais dos eventos.


func title() -> String:
	return "Notícias"


func subtitle() -> String:
	return "Esportes, resultados e acontecimentos da cidade"


func build(body: VBoxContainer) -> void:
	var s := sim()
	body.add_child(UiKit.heading("Últimas notícias", 18))
	var items: Array = s.betting.news.duplicate()
	items.reverse()
	if items.is_empty():
		body.add_child(UiKit.label("Sem notícias no momento.", 15, UiKit.MUTED))
	for n in items.slice(0, 10):
		var c := UiKit.card(body)
		c.add_child(UiKit.label("%s — Dia %d" % [str(n.sport).to_upper(), int(n.day)], 12, UiKit.BLUE))
		c.add_child(UiKit.label(str(n.text), 16, UiKit.TEXT, true))
		var ev := s.betting.get_event(str(n.event_id))
		var when := ""
		if not ev.is_empty():
			when = "  (%s, %s)" % [Fmt.hm(int(ev.start) % 1440), "encerrado" if ev.status == "finished" else "em aberto"]
		c.add_child(UiKit.label("Evento: " + str(n.event) + when, 13, UiKit.MUTED, true))
	body.add_child(UiKit.heading("Resultados", 18))
	for ev in s.betting.finished_events(12):
		var res := str(ev.outcomes[int(ev.result)]) if int(ev.result) >= 0 else "?"
		body.add_child(UiKit.label("%s — %s: %s" % [ev.sport_name, ev.name, res], 14, UiKit.TEXT, true))
