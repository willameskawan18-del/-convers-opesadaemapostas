class_name SaveSystem
## Save/Load em JSON com proteção contra corrupção:
## grava em arquivo temporário, mantém backup (.bak) e valida checksum ao carregar.

const DIR := "user://saves"


static func _path(slot: String) -> String:
	return "%s/%s.json" % [DIR, slot]


static func save_game(data: Dictionary, slot: String = "slot1") -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var payload := JSON.stringify(data)
	var wrapper := JSON.stringify({"checksum": payload.md5_text(), "payload": payload})
	var final_path := ProjectSettings.globalize_path(_path(slot))
	var tmp_path := final_path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: não foi possível gravar " + tmp_path)
		return false
	f.store_string(wrapper)
	f.close()
	# Valida o que foi gravado antes de substituir o save anterior
	if _read(tmp_path).is_empty():
		push_error("SaveSystem: verificação do save falhou")
		return false
	if FileAccess.file_exists(final_path):
		DirAccess.remove_absolute(final_path + ".bak")
		DirAccess.rename_absolute(final_path, final_path + ".bak")
	return DirAccess.rename_absolute(tmp_path, final_path) == OK


static func _read(abs_path: String) -> Dictionary:
	if not FileAccess.file_exists(abs_path):
		return {}
	var wrapper: Variant = JSON.parse_string(FileAccess.get_file_as_string(abs_path))
	if not (wrapper is Dictionary) or not wrapper.has("payload"):
		return {}
	var payload := str(wrapper.payload)
	if payload.md5_text() != str(wrapper.get("checksum", "")):
		push_warning("SaveSystem: checksum inválido em " + abs_path)
		return {}
	var data: Variant = JSON.parse_string(payload)
	return data if data is Dictionary else {}


static func load_game(slot: String = "slot1") -> Dictionary:
	var p := ProjectSettings.globalize_path(_path(slot))
	var data := _read(p)
	if data.is_empty():
		data = _read(p + ".bak")
		if not data.is_empty():
			push_warning("SaveSystem: save principal corrompido; backup carregado.")
	return data


static func has_save(slot: String = "slot1") -> bool:
	var p := ProjectSettings.globalize_path(_path(slot))
	return FileAccess.file_exists(p) or FileAccess.file_exists(p + ".bak")


static func save_info(slot: String = "slot1") -> Dictionary:
	var d := load_game(slot)
	if d.is_empty():
		return {}
	var sim: Dictionary = d.get("sim", {})
	return {"day": int(sim.get("time", {}).get("day", 1)), "cash": float(sim.get("economy", {}).get("cash", 0)),
		"timestamp": str(d.get("timestamp", "")), "brand": str(sim.get("brand_name", ""))}


static func delete_save(slot: String = "slot1") -> void:
	var p := ProjectSettings.globalize_path(_path(slot))
	DirAccess.remove_absolute(p)
	DirAccess.remove_absolute(p + ".bak")
