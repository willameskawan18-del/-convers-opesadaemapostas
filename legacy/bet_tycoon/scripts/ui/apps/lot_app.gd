extends AppBase
## Detalhes de um imóvel (placas ALUGA-SE / VENDE-SE).


func title() -> String:
	return str(GameData.find("properties", "properties", str(arg)).get("name", "Imóvel"))


func subtitle() -> String:
	return "Corretora Paula — imóveis da cidade"


func window_size() -> Vector2:
	return Vector2(640, 480)


func build(body: VBoxContainer) -> void:
	var s := sim()
	var p := GameData.find("properties", "properties", str(arg))
	body.add_child(UiKit.label(str(p.get("desc", "")), 15, UiKit.MUTED, true))
	var c := UiKit.card(body)
	if float(p.get("rent", 0)) > 0:
		UiKit.kv(c, "Aluguel", Fmt.money(float(p.rent)) + "/dia")
		UiKit.kv(c, "Taxa de contrato", Fmt.money(float(p.get("deposit", 0))))
	UiKit.kv(c, "Preço de compra", Fmt.money(float(p.get("price", 0))))
	UiKit.kv(c, "Manutenção (se comprado)", Fmt.money(float(p.get("upkeep", 0))) + "/dia")
	if p.get("type", "") == "business":
		UiKit.kv(c, "Estágios suportados", ", ".join(PackedStringArray(p.get("stages", []).map(func(x): return str(int(x))))))
	else:
		UiKit.kv(c, "Renda de aluguel", Fmt.money(float(p.get("rental_income", 0))) + "/dia")
	UiKit.kv(c, "Nível mínimo", str(int(p.get("min_level", 1))))
	var contract := str(s.properties.contracts.get(str(arg), ""))
	if contract != "":
		body.add_child(UiKit.label("Situação: " + ("alugado por você" if contract == "rented" else "propriedade sua"), 15, UiKit.GREEN))
	if p.get("type", "") == "business" and not s.has_business() and not s.licenses.has("basica"):
		body.add_child(UiKit.label("Para abrir uma banca aqui você precisa do Alvará Municipal (celular > Administração > Licenças).", 14, UiKit.ORANGE, true))
	var h := UiKit.hbox()
	body.add_child(h)
	h.add_child(UiKit.spacer())
	LotActions.add(h, s, str(arg), ui)
