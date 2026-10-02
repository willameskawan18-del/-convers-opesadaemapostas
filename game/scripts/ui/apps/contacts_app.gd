extends AppBase
## Contatos: personagens da cidade e o que cada um oferece.

const CONTACTS := [
	["Zé", "Dono da Banca do Zé", "Aceita apostas no balcão dele, na avenida (lado leste). Pode virar seu concorrente."],
	["Sr. Almeida", "Gerente do Banco Central", "Empréstimos e crédito. Visite o banco ou use o app Banco."],
	["Dona Marta", "Mercado Bom Preço", "Oferece limpeza e carga de mercadorias."],
	["Seu Jorge", "Depósito Logístico", "Entregas pela cidade. Paga bem quem é pontual."],
	["Paula", "Corretora de imóveis", "Cuida da Sala Comercial, do Salão, do Galpão e das casas para alugar."],
	["Rafael", "Eletro Center", "Vende equipamentos e oferece turnos de auxiliar de loja."],
	["Mentor", "Antigo empresário da cidade", "Envia conselhos conforme você avança na campanha."],
]


func title() -> String:
	return "Contatos"


func build(body: VBoxContainer) -> void:
	for c in CONTACTS:
		var card := UiKit.card(body)
		card.add_child(UiKit.label("%s — %s" % [c[0], c[1]], 16, UiKit.GOLD))
		card.add_child(UiKit.label(c[2], 14, UiKit.TEXT, true))
	var s := sim()
	if s.employees != null and s.employees.staff.size() > 0:
		body.add_child(UiKit.heading("Sua equipe", 17))
		for e in s.employees.staff:
			body.add_child(UiKit.label("%s — %s (nível %d)" % [e.name, s.employees.role_name(str(e.role)), int(e.level)], 14))
