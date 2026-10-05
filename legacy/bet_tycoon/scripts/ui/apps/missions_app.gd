extends AppBase
## Campanha e objetivos secundários.


func title() -> String:
	return "Objetivos"


func subtitle() -> String:
	return "Campanha: da banca ao cassino"


func build(body: VBoxContainer) -> void:
	var s := sim()
	var chapters := s.missions.chapters()
	for i in chapters.size():
		var ch: Dictionary = chapters[i]
		var cur := i == s.missions.chapter_index
		var done := i < s.missions.chapter_index
		var c := UiKit.card(body, UiKit.PANEL2, UiKit.GOLD if cur else Color(1, 1, 1, 0.04))
		c.add_child(UiKit.label(str(ch.title) + ("  — CONCLUÍDO" if done else ""), 17, UiKit.GREEN if done else (UiKit.GOLD if cur else UiKit.MUTED)))
		if cur:
			c.add_child(UiKit.label(str(ch.get("intro", "")), 13, UiKit.MUTED, true))
			var objs: Array = ch.objectives
			for k in objs.size():
				var o: Dictionary = objs[k]
				var p := s.missions.progress(o)
				var ok: bool = s.missions.done[k]
				var txt := str(o.text)
				if float(p[1]) > 1.0 and not ok:
					txt += "  (%s / %s)" % [_fmt_prog(o, float(p[0])), _fmt_prog(o, float(p[1]))]
				UiKit.status_line(c, ok, txt)
			if float(ch.get("reward_cash", 0)) > 0:
				c.add_child(UiKit.label("Recompensa: " + Fmt.money(float(ch.reward_cash)), 13, UiKit.GOLD))
		if i > s.missions.chapter_index + 1:
			break
	body.add_child(UiKit.heading("Objetivos secundários", 18))
	for o in GameData.list("missions", "secondary"):
		var ok2: bool = o.id in s.missions.secondary_done
		var p2 := s.missions.progress(o)
		UiKit.status_line(body, ok2, "%s  (+%s)%s" % [o.text, Fmt.money(float(o.reward_cash)), "" if ok2 else "  [%s / %s]" % [_fmt_prog(o, float(p2[0])), _fmt_prog(o, float(p2[1]))]])


func _fmt_prog(o: Dictionary, v: float) -> String:
	match str(o.type):
		"cash", "net_worth":
			return Fmt.money(v)
		"market_share":
			return Fmt.pct(v, 0)
	return str(int(v))
