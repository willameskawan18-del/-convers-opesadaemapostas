extends AppBase
## Modo de desenvolvimento (F12). Só disponível em builds de debug ou com o argumento --dev.


func title() -> String:
	return "DEBUG"


func subtitle() -> String:
	return "Ferramentas de teste — não aparece na versão final"


func live() -> bool:
	return true


func build(body: VBoxContainer) -> void:
	var s := sim()
	body.add_child(UiKit.label("Caixa %s | Nível %d | Dia %d | Capítulo %d" % [Fmt.money(s.economy.cash), s.progression.level, s.time.day, s.missions.chapter_index + 1], 15))
	var actions := [
		["+ R$ 1.000", func(): s.economy.earn(1000, EconomySystem.REWARD)],
		["+ R$ 50.000", func(): s.economy.earn(50000, EconomySystem.REWARD)],
		["+ R$ 1.000.000", func(): s.economy.earn(1000000, EconomySystem.REWARD)],
		["- R$ 5.000", func(): s.economy.charge(5000, EconomySystem.EVENTS)],
		["+ 500 XP", func(): s.progression.add_xp(500)],
		["+ 5.000 XP", func(): s.progression.add_xp(5000)],
		["Avançar 1 hora", func(): s.advance(60)],
		["Avançar dia", func(): s.advance(1440 - s.time.minute)],
		["Completar objetivo", func(): s.missions.complete_current_objective()],
		["Reputação +10", func(): s.reputation.add(10, "Debug")],
		["Testar falência", func(): s.declare_bankruptcy()],
		["Testar empréstimo", func(): s.loans.take("micro")],
		["Desbloquear licenças", func():
			for l in s.licenses.all():
				if not s.licenses.has(str(l.id)):
					s.licenses.owned.append(str(l.id))],
		["Gerar evento", func():
			if s.events != null:
				s.events.trigger_random(true)],
		["Gerar cliente", func():
			if s.customers != null:
				s.customers.spawn_visit()],
	]
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	body.add_child(flow)
	for a in actions:
		var cb: Callable = a[1]
		flow.add_child(UiKit.button(a[0], func():
			cb.call()
			s.after_action()
			ui.refresh()))
