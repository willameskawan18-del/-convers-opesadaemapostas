extends AppBase
## Trabalhos disponíveis. Pelo celular só é possível ver; para aceitar, vá ao quadro do local
## (arg = id do local) — exceto se arg for null, que mostra todos.

const GIVER_NAMES := {"deposito": "Depósito Logístico", "mercado": "Mercado Bom Preço", "loja": "Eletro Center"}


func title() -> String:
	return "Trabalhos" if arg == null else "Quadro de trabalhos — " + str(GIVER_NAMES.get(arg, arg))


func subtitle() -> String:
	return "Pequenos trabalhos para juntar capital"


func live() -> bool:
	return true


func build(body: VBoxContainer) -> void:
	var s := sim()
	var a: Dictionary = s.jobs.active
	if not a.is_empty():
		var c := UiKit.card(body, UiKit.PANEL2, UiKit.BLUE)
		c.add_child(UiKit.label("Em andamento: %s (+%s)" % [a.name, Fmt.money(float(a.reward))], 17, UiKit.BLUE))
		if a.type == "delivery":
			c.add_child(UiKit.label("Etapa %d/%d — siga o marcador azul. Prazo: %d min" % [int(a.step) + 1, a.stops.size(), int(a.deadline) - s.time.abs_minute()], 14))
		c.add_child(UiKit.button("Cancelar trabalho", func():
			s.jobs.cancel()
			ui.refresh()))
	if s.recovery_mode:
		body.add_child(UiKit.label("Modo recuperação: trabalhos pagam bônus de 25%.", 14, UiKit.ORANGE))
	var list: Array = s.jobs.all_jobs() if arg == null else s.jobs.jobs_at(str(arg))
	for j in list:
		var c2 := UiKit.card(body)
		var h := UiKit.hbox()
		c2.add_child(h)
		var info := UiKit.vbox(2)
		h.add_child(UiKit.expand(info))
		info.add_child(UiKit.label(str(j.name), 17, UiKit.TEXT))
		info.add_child(UiKit.label(str(j.desc), 13, UiKit.MUTED, true))
		var dur := ("Turno de %d min" % int(j.duration)) if j.type == "shift" else ("%d etapa(s), prazo %d min" % [j.stops.size(), int(j.time_limit)])
		info.add_child(UiKit.label("%s a %s  |  %s  |  Dificuldade %d  |  %s" % [Fmt.money(float(j.reward[0])), Fmt.money(float(j.reward[1])), dur, int(j.difficulty), GIVER_NAMES.get(j.giver, j.giver)], 13, UiKit.GOLD, true))
		var why := s.jobs.availability(j)
		if why != "":
			info.add_child(UiKit.label(why, 13, UiKit.ORANGE))
		if arg != null:
			h.add_child(UiKit.button("Aceitar", func():
				if s.jobs.start(str(j.id)):
					ui.close_window()
				else:
					ui.refresh(), true, why == ""))
	if arg == null:
		body.add_child(UiKit.label("Para aceitar, vá até o quadro de trabalhos no local (marcado como TRABALHOS na cidade).", 14, UiKit.MUTED, true))
