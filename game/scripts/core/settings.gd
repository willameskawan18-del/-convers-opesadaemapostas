extends Node
## Configurações (user://settings.cfg): áudio, vídeo, controles e idioma.

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const FPS_LIMITS := [30, 60, 120, 144, 0]
const LANGUAGES := [["pt_BR", "Português (Brasil)"], ["en", "English (em breve)"]]

var values := {
	"resolution": 1,
	"fullscreen": false,
	"vsync": true,
	"fps_limit": 1,
	"quality": 1,
	"master_volume": 0.8,
	"music_volume": 0.55,
	"sfx_volume": 0.85,
	"ui_volume": 0.8,
	"sensitivity": 1.0,
	"language": "pt_BR",
	"camera_shake": true,
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


func apply() -> void:
	TranslationServer.set_locale(str(values.language))
	Engine.max_fps = FPS_LIMITS[clampi(int(values.fps_limit), 0, FPS_LIMITS.size() - 1)]
	_apply_audio()
	if DisplayServer.get_name() != "headless":
		var win := get_window()
		if values.fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var res: Vector2i = RESOLUTIONS[clampi(int(values.resolution), 0, RESOLUTIONS.size() - 1)]
			if win.size != res:
				win.size = res
				win.position = (DisplayServer.screen_get_size() - res) / 2
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
		var vp := get_viewport()
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(int(values.quality), 0, 2)]
		vp.scaling_3d_scale = 0.75 if int(values.quality) == 0 else 1.0
	changed.emit()


func _apply_audio() -> void:
	_set_bus("Master", float(values.master_volume))
	_set_bus("Music", float(values.music_volume))
	_set_bus("SFX", float(values.sfx_volume))
	_set_bus("UI", float(values.ui_volume))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)
