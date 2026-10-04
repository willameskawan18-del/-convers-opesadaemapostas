extends AppBase
## Mensagens de personagens, clientes e funcionários.


func title() -> String:
	return "Mensagens"


func build(body: VBoxContainer) -> void:
	var msgs: Array = sim().messages.duplicate()
	msgs.reverse()
	if msgs.is_empty():
		body.add_child(UiKit.label("Nenhuma mensagem.", 15, UiKit.MUTED))
	for m in msgs:
		var c := UiKit.card(body)
		c.add_child(UiKit.label("%s  —  Dia %d, %s" % [m.from, int(m.day), m.time], 13, UiKit.GOLD))
		c.add_child(UiKit.label(str(m.text), 15, UiKit.TEXT, true))
