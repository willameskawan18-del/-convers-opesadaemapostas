class_name Fmt
## Formatação de valores (dinheiro fictício do show).


static func money(v: float) -> String:
	var n := int(roundf(absf(v)))
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if v < 0 else "$") + s + out


static func delta(v: float) -> String:
	return ("+" if v >= 0 else "") + money(v)


static func place(pos: int) -> String:
	return "%dº" % pos


static func mult(m: float) -> String:
	if is_equal_approx(m, roundf(m)):
		return "x%d" % int(m)
	return "x%.1f" % m
