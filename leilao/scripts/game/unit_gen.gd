class_name UnitGen
extends RefCounted
## Gera galpões: tipo, itens (com valor real escondido), boato público e dicas.

static var _uid := 0


static func data() -> Dictionary:
	return GameData.load_json("items")


static func item_def(id: String) -> Dictionary:
	for it in data().items:
		if it.id == id:
			return it
	return {}


static func make_item(def: Dictionary, rng: RandomNumberGenerator, day: int) -> Dictionary:
	_uid += 1
	var lo := float(def.min)
	var hi := float(def.max)
	# a maioria vale pouco; às vezes vale MUITO
	var v := lo + (hi - lo) * pow(rng.randf(), 2.4)
	v *= 1.0 + 0.06 * (day - 1)
	var value := int(roundf(v / 10.0) * 10.0)
	var mystery := bool(def.get("mystery", false))
	var est_lo := int(roundf(value * rng.randf_range(0.45, 0.9) / 10.0) * 10.0)
	var est_hi := int(roundf(maxf(value * rng.randf_range(1.1, 1.9), float(def.min) + 20.0) / 10.0) * 10.0)
	return {"uid": _uid, "id": def.id, "name": def.name, "cat": def.cat, "value": value, "est_lo": est_lo, "est_hi": est_hi,
		"mystery": mystery, "shape": def.shape, "color": def.color, "rare": bool(def.get("rare", false)), "max": int(def.max)}


static func generate(rng: RandomNumberGenerator, day: int, number: int) -> Dictionary:
	var d := data()
	var units: Array = d.units
	var u: Dictionary = units[rng.randi_range(0, units.size() - 1)]
	var by_cat := {}
	for it in d.items:
		if it.cat == "especial":
			continue
		if not by_cat.has(it.cat):
			by_cat[it.cat] = []
		by_cat[it.cat].append(it)
	var items := []
	var n := rng.randi_range(6, 10)
	for i in n:
		var cat: String = u.cats[rng.randi_range(0, u.cats.size() - 1)]
		if rng.randf() < 0.18:
			var keys := by_cat.keys()
			cat = keys[rng.randi_range(0, keys.size() - 1)]
		var pool: Array = by_cat[cat]
		items.append(make_item(pool[rng.randi_range(0, pool.size() - 1)], rng, day))
	var special := ""
	if rng.randf() < 0.24:
		special = u.special[rng.randi_range(0, u.special.size() - 1)]
		items.insert(rng.randi_range(2, items.size()), make_item(item_def(special), rng, day))
	var total := 0
	for it in items:
		total += int(it.value)
	return {"number": number, "type": u.id, "name": u.name, "items": items, "total": total, "rumor": _rumor(u, special, items, rng), "special": special}


static func _rumor(u: Dictionary, special: String, items: Array, rng: RandomNumberGenerator) -> String:
	var lines := []
	if special != "" and rng.randf() < 0.7:
		match special:
			"cofre": lines.append("Os vizinhos ouviram barulho de algo pesado de ferro sendo guardado...")
			"moto": lines.append("Dizem que o dono adorava motos antigas.")
			"pintura_rara": lines.append("O dono frequentava galerias de arte famosas.")
			"joias": lines.append("A dona sempre aparecia cheia de joias.")
			"bau": lines.append("Tem um baú que ninguém nunca abriu.")
	elif rng.randf() < 0.35:
		lines.append(["Dizem que tem um cofre aqui... ou não.", "O dono era colecionador. Talvez.", "Só tem tralha, segundo o porteiro.", "O antigo dono sumiu sem pagar o aluguel."][rng.randi_range(0, 3)])
	else:
		lines.append(["Galpão fechado há 8 anos.", "Último pagamento: 2019.", "O cadeado estava enferrujado.", "Cheiro de mofo... e mistério."][rng.randi_range(0, 3)])
	return lines[0]


## Quantos itens cada um vê ao espiar (lanterna mostra mais).
static func visible_count(has_lantern: bool, rng_seed: int) -> int:
	return 2 + (rng_seed % 2) + (2 if has_lantern else 0)


## Valor estimado "de olho" para um item visível (ninguém sabe o valor real ao espiar).
static func eye_estimate(it: Dictionary) -> int:
	return int((int(it.est_lo) + int(it.est_hi)) / 2)
