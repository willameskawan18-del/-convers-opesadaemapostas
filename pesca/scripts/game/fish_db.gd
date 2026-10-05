class_name FishDB
## Peixes, zonas e sorteio de capturas.


static func data() -> Dictionary:
	return GameData.load_json("fish")


static func zone_at(dist: float) -> Dictionary:
	for z in data().zones:
		if dist >= float(z.from) and dist < float(z.to):
			return z
	return data().zones[0]


static func get_fish(id: String) -> Dictionary:
	for f in data().fish:
		if f.id == id:
			return f
	return {}


static func rarity(r: String) -> Dictionary:
	return data().rarity.get(r, {"name": r, "color": "#ffffff", "weight": 1})


## Sorteia um peixe para a zona. isca (0..3) e lanterna no abismo puxam para os raros.
static func roll(zone_id: String, isca: int, lantern_abyss: bool, rng: RandomNumberGenerator) -> Dictionary:
	var pool := []
	var total := 0.0
	var boost := 1.0 + isca * 0.35 + (0.6 if lantern_abyss else 0.0)
	for f in data().fish:
		if f.zone != zone_id and f.zone != "any":
			continue
		var w := float(rarity(f.rarity).weight)
		if f.rarity != "comum":
			w *= boost
		if f.get("junk", false):
			w *= 0.12
		pool.append([f, w])
		total += w
	var r := rng.randf() * total
	var pick: Dictionary = pool[0][0]
	for e in pool:
		r -= float(e[1])
		if r <= 0.0:
			pick = e[0]
			break
	var kg := rng.randf_range(float(pick.kg[0]), float(pick.kg[1]))
	var rel := (kg - float(pick.kg[0])) / maxf(0.01, float(pick.kg[1]) - float(pick.kg[0]))
	var value := int(roundf(float(pick.value) * (0.7 + rel * 0.8)))
	return {"id": pick.id, "name": pick.name, "rarity": pick.rarity, "kg": snappedf(kg, 0.1), "value": value,
		"strength": float(pick.strength), "color": pick.color, "size": float(pick.size), "glow": bool(pick.get("glow", false))}
