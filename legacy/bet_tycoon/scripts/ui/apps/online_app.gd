extends AppBase
## Operação online: site/app, servidores, marketing, suporte, segurança e reputação online.


func title() -> String:
	return "Operação Online — " + sim().brand_name


func subtitle() -> String:
	return "Plataforma fictícia de apostas da sua marca"


func live() -> bool:
	return true


func build(body: VBoxContainer) -> void:
	var s := sim()
	var on := s.online
	if not on.open:
		body.add_child(UiKit.label("Leve sua marca para a internet. A operação online tem clientes, receita, custos, reputação e riscos próprios, separados da banca física.", 16, UiKit.TEXT, true))
		UiKit.status_line(body, s.has_business() and s.business.stage >= 3, "Estabelecimento estágio 3 (Salão)")
		UiKit.status_line(body, s.licenses.has("digital"), "Licença de Operação Digital")
		var why := on.launch_block_reason()
		body.add_child(UiKit.button("LANÇAR SITE (%s)" % Fmt.money(float(on.cfg().get("launch_cost", 20000))), func():
			on.launch()
			ui.refresh(), true, why == ""))
		if why != "":
			body.add_child(UiKit.label(why, 14, UiKit.ORANGE))
		return
	var row := UiKit.hbox(12)
	body.add_child(row)
	for st in [["Usuários ativos", "%d" % int(on.users), UiKit.BLUE], ["Capacidade", "%d" % int(on.capacity()), UiKit.TEXT if on.users <= on.capacity() else UiKit.RED],
			["Reputação online", "%d" % int(on.online_rep), UiKit.GOLD], ["Resultado hoje", Fmt.signed_money(on.today_net), UiKit.money_color(on.today_net)]]:
		var c := UiKit.card(row)
		c.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(UiKit.label(str(st[0]).to_upper(), 11, UiKit.MUTED))
		c.add_child(UiKit.label(str(st[1]), 20, st[2]))
	if s.time.abs_minute() < on.outage_until:
		body.add_child(UiKit.label("SITE FORA DO AR (sobrecarga). Compre servidores na aba Equipamentos.", 15, UiKit.RED))
	UiKit.kv(body, "Meta de usuários atual", "%d" % int(on.target_users()))
	UiKit.kv(body, "Resultado acumulado", Fmt.signed_money(on.total_net), UiKit.money_color(on.total_net))
	# Plataforma
	var lv := on.level_data()
	var nd := on.level_data(on.site_level + 1)
	var pc := UiKit.card(body)
	pc.add_child(UiKit.heading("Plataforma: %s (nível %d)" % [lv.get("name", ""), on.site_level], 16))
	pc.add_child(UiKit.label("Hospedagem: %s/dia" % Fmt.money(float(lv.get("hosting", 0))), 13, UiKit.MUTED))
	if not nd.is_empty():
		pc.add_child(UiKit.button("Atualizar para %s (%s)" % [nd.name, Fmt.money(float(nd.upgrade_cost))], func():
			on.upgrade()
			ui.refresh(), true, s.economy.can_afford(float(nd.upgrade_cost))))
	# Marketing
	var mc := UiKit.card(body)
	mc.add_child(UiKit.heading("Marketing digital: %s/dia" % Fmt.money(on.marketing), 16))
	var mh := UiKit.hbox()
	mc.add_child(mh)
	for v in [0, 500, 2000, 5000, 15000]:
		mh.add_child(UiKit.button(Fmt.money(v), func():
			on.marketing = float(v)
			ui.refresh(), is_equal_approx(on.marketing, float(v))))
	# Suporte
	var need := int(ceil(on.users / float(on.cfg().get("users_per_support", 400))))
	var sc := UiKit.card(body)
	sc.add_child(UiKit.heading("Atendimento ao cliente: %d atendente(s) (recomendado: %d)" % [on.support, need], 16))
	var sh := UiKit.hbox()
	sc.add_child(sh)
	sh.add_child(UiKit.button("- 1", func():
		on.support = maxi(0, on.support - 1)
		ui.refresh()))
	sh.add_child(UiKit.button("+ 1 (%s/dia)" % Fmt.money(float(on.cfg().get("support_salary", 140))), func():
		on.support += 1
		ui.refresh()))
	# Segurança
	var secs: Array = on.cfg().get("security_levels", [])
	var sec := UiKit.card(body)
	sec.add_child(UiKit.heading("Segurança digital", 16))
	var sech := HFlowContainer.new()
	sech.add_theme_constant_override("h_separation", 6)
	sec.add_child(sech)
	for l in secs:
		var lvl := int(l.level)
		sech.add_child(UiKit.button("%s (%s/dia)" % [l.name, Fmt.money(float(l.daily))], func():
			on.security_level = lvl
			ui.refresh(), on.security_level == lvl))
	sec.add_child(UiKit.label("Sem segurança, ataques virtuais (abstratos) causam prejuízo e derrubam a reputação online.", 13, UiKit.MUTED, true))
