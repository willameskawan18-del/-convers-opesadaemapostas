class_name Fmt
## Utilitários de formatação de texto (moeda, tempo, percentuais).

static func money(v: float) -> String:
	var neg := v < -0.5
	var n := int(round(absf(v)))
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return ("-R$ " if neg else "R$ ") + out


static func signed_money(v: float) -> String:
	return ("+" if v >= 0 else "") + money(v)


static func pct(v: float, decimals: int = 1) -> String:
	return ("%." + str(decimals) + "f%%") % (v * 100.0)


static func hm(minute_of_day: int) -> String:
	var m := posmod(minute_of_day, 1440)
	return "%02d:%02d" % [m / 60, m % 60]


static func odds(v: float) -> String:
	return "%.2f" % v


static func num(v: float) -> String:
	return money(v).replace("R$ ", "")
