extends Node
## Configurações do jogador (gráficos, áudio, controles), salvas em user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const QUALITY_NAMES := ["Baixa", "Média", "Alta"]
const DISTANCE_NAMES := ["Curta", "Média", "Longa"]

var values := {
	"resolution": 1,
	"fullscreen": false,
	"vsync": true,
	"quality": 1,
	"shadows": true,
	"render_distance": 1,
	"master_volume": 0.8,
	"music_volume": 0.5,
	"sfx_volume": 0.8,
	"mouse_sensitivity": 0.25,
	"invert_y": false,
}


func _ready() -> void:
	load_settings()
	apply()


func get_value(key: String) -> Variant:
	return values.get(key)


func set_value(key: String, v: Variant) -> void:
	values[key] = v
	apply()
	save_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in values.keys():
		values[k] = cfg.get_value("settings", k, values[k])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in values.keys():
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)


func far_distance() -> float:
	return [140.0, 240.0, 420.0][clampi(int(values.render_distance), 0, 2)]


func apply() -> void:
	if DisplayServer.get_name() == "headless":
		changed.emit()
		return
	var win := get_window()
	if values.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res: Vector2i = RESOLUTIONS[clampi(int(values.resolution), 0, RESOLUTIONS.size() - 1)]
		if win.size != res:
			win.size = res
			var screen := DisplayServer.screen_get_size()
			win.position = (screen - res) / 2
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	var vp := get_viewport()
	match int(values.quality):
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = 0.75
		1:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 1.0
		_:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.scaling_3d_scale = 1.0
	_apply_audio()
	changed.emit()


func _apply_audio() -> void:
	_set_bus("Master", float(values.master_volume))
	_set_bus("Music", float(values.music_volume))
	_set_bus("SFX", float(values.sfx_volume))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)
