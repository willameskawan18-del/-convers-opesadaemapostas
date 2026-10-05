extends Node
## AudioManager (autoload "Audio"). Categorias: MUSIC, SFX, UI, WIN, LOSE, COUNTDOWN.
## Barramentos: Music, SFX e UI (WIN/LOSE/COUNTDOWN tocam no SFX).
## Sem arquivos de áudio, tudo é sintetizado (placeholders). Para trocar por sons reais,
## coloque res://audio/<nome>.ogg|.wav — eles têm prioridade.

const RATE := 22050
const CATEGORY_BUS := {"MUSIC": "Music", "SFX": "SFX", "UI": "UI", "WIN": "SFX", "LOSE": "SFX", "COUNTDOWN": "SFX"}
const SOUND_CATEGORY := {
	"click": "UI", "hover": "UI", "confirm": "UI", "error": "UI",
	"money_gain": "WIN", "money_loss": "LOSE", "win": "WIN", "jackpot": "WIN", "lose": "LOSE", "crowd_cheer": "WIN", "crowd_aww": "LOSE",
	"tick": "COUNTDOWN", "countdown_go": "COUNTDOWN", "drumroll": "SFX", "reveal": "SFX", "whoosh": "SFX", "suspense": "SFX", "door": "SFX", "coin": "SFX", "splash": "SFX", "bite": "SFX", "thump": "SFX", "roar": "SFX",
}

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _loop: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX", "UI"]:
		_ensure_bus(b)
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -6.0
	add_child(_music)
	_loop = AudioStreamPlayer.new()
	_loop.bus = "SFX"
	add_child(_loop)
	Settings.apply()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func play(sfx: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream := _get_stream(sfx)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.bus = CATEGORY_BUS.get(SOUND_CATEGORY.get(sfx, "SFX"), "SFX")
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Música em loop: "music_menu", "music_game", "music_allwin".
func play_music(music_name: String) -> void:
	if DisplayServer.get_name() == "headless" or _music_name == music_name:
		return
	_music_name = music_name
	_music.stream = _get_stream(music_name)
	_music.play()


func stop_music() -> void:
	_music_name = ""
	_music.stop()


## Som contínuo de suspense (sobe de volume) — para o ALL WIN e revelações.
func start_suspense() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_loop.stream = _get_stream("suspense_loop")
	_loop.volume_db = -18.0
	_loop.play()
	var tw := create_tween()
	tw.tween_property(_loop, "volume_db", -2.0, 5.0)


func play_ambient(name_: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _loop.playing and _loop.stream == _get_stream(name_):
		return
	_loop.stream = _get_stream(name_)
	_loop.volume_db = -10.0
	_loop.play()


func stop_suspense() -> void:
	_loop.stop()


func _get_stream(sfx_name: String) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var stream: AudioStream = null
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://audio/%s.%s" % [sfx_name, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		stream = _synth(sfx_name)
	_cache[sfx_name] = stream
	return stream


# --- Síntese ---------------------------------------------------------------------

func _synth(n: String) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var loop := false
	match n:
		"click": s = _tone(900.0, 0.045, "sine", 0.35)
		"hover": s = _tone(1400.0, 0.025, "sine", 0.12)
		"confirm": s = _concat([_tone(660.0, 0.06, "square", 0.18), _tone(990.0, 0.12, "sine", 0.35)])
		"error": s = _concat([_tone(180.0, 0.12, "square", 0.22), _tone(140.0, 0.18, "square", 0.22)])
		"money_gain": s = _concat([_tone(1318.0, 0.06, "square", 0.18), _tone(1568.0, 0.06, "square", 0.18), _tone(2093.0, 0.2, "sine", 0.32)])
		"money_loss": s = _sweep(700.0, 180.0, 0.35, "square", 0.2)
		"coin": s = _concat([_tone(1975.0, 0.05, "sine", 0.3), _tone(2637.0, 0.25, "sine", 0.3)])
		"win": s = _concat([_tone(523.0, 0.1, "square", 0.22), _tone(659.0, 0.1, "square", 0.22), _tone(784.0, 0.1, "square", 0.22), _chord([1046.0, 1318.0, 1568.0], 0.5, 0.18)])
		"jackpot": s = _concat([_arp([523.0, 659.0, 784.0, 1046.0, 1318.0, 1568.0, 2093.0], 0.06, 0.22), _chord([1046.0, 1318.0, 1568.0, 2093.0], 0.9, 0.16)])
		"lose": s = _concat([_tone(392.0, 0.22, "tri", 0.35), _tone(370.0, 0.22, "tri", 0.35), _tone(349.0, 0.22, "tri", 0.35), _sweep(330.0, 250.0, 0.7, "tri", 0.35)])
		"tick": s = _tone(1200.0, 0.06, "square", 0.25)
		"countdown_go": s = _chord([880.0, 1318.0], 0.35, 0.25)
		"drumroll": s = _drumroll(1.8)
		"reveal": s = _concat([_noise(0.08, 0.5, 0.3), _chord([784.0, 988.0, 1175.0], 0.4, 0.16)])
		"whoosh": s = _whoosh(0.45)
		"door": s = _concat([_noise(0.12, 0.35, 0.9), _tone(110.0, 0.25, "sine", 0.5)])
		"crowd_cheer": s = _crowd(1.6, true)
		"crowd_aww": s = _crowd(1.4, false)
		"suspense": s = _sweep(110.0, 440.0, 2.5, "saw", 0.12)
		"splash": s = _concat([_noise(0.05, 0.6, 0.4), _noise(0.35, 0.35, 0.9)])
		"bite": s = _concat([_tone(1500.0, 0.05, "sine", 0.4), _tone(1500.0, 0.05, "sine", 0.0), _tone(1900.0, 0.12, "sine", 0.4)])
		"thump": s = _concat([_sweep(90.0, 40.0, 0.5, "sine", 0.9), _noise(0.3, 0.4, 0.95)])
		"roar": s = _sweep(70.0, 45.0, 2.2, "saw", 0.35)
		"sea_loop":
			s = _noise(6.0, 0.18, 0.993)
			loop = true
		"suspense_loop":
			s = _drone(4.0)
			loop = true
		"music_menu":
			s = _music_loop([[0, 4, 7], [5, 9, 12], [7, 11, 14], [5, 9, 12]], 128.0, 57, 0.9)
			loop = true
		"music_game":
			s = _music_loop([[0, 3, 7], [8, 12, 15], [5, 8, 12], [7, 11, 14]], 116.0, 57, 0.75)
			loop = true
		"music_allwin":
			s = _music_loop([[0, 3, 7], [1, 4, 8], [0, 3, 7], [-1, 3, 6]], 92.0, 45, 1.0)
			loop = true
		_: s = _tone(660.0, 0.08, "sine", 0.3)
	return _to_wav(s, loop)


func _osc(wave: String, ph: float) -> float:
	match wave:
		"square": return 1.0 if ph < 0.5 else -1.0
		"tri": return 4.0 * absf(ph - 0.5) - 1.0
		"saw": return 2.0 * ph - 1.0
	return sin(TAU * ph)


func _tone(freq: float, dur: float, wave: String, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, float(i) / (RATE * 0.004)) * pow(1.0 - float(i) / n, 1.5)
		out[i] = _osc(wave, fmod(t * freq, 1.0)) * amp * env
	return out


func _sweep(f0: float, f1: float, dur: float, wave: String, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph = fmod(ph + lerpf(f0, f1, k) / RATE, 1.0)
		out[i] = _osc(wave, ph) * amp * minf(1.0, float(i) / (RATE * 0.01)) * (1.0 - k * 0.8)
	return out


func _chord(freqs: Array, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * float(f) * t) + 0.3 * sin(TAU * float(f) * 2.0 * t)
		out[i] = v * amp * minf(1.0, float(i) / (RATE * 0.005)) * pow(1.0 - float(i) / n, 1.2)
	return out


func _arp(freqs: Array, each: float, amp: float) -> PackedFloat32Array:
	var parts := []
	for f in freqs:
		parts.append(_tone(float(f), each, "square", amp))
	return _concat(parts)


func _noise(dur: float, amp: float, smooth: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in n:
		last = last * smooth + rng.randf_range(-1.0, 1.0) * (1.0 - smooth)
		out[i] = last * amp * (1.0 - float(i) / n) * (3.0 if smooth > 0.5 else 1.0)
	return out


func _whoosh(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last := 0.0
	for i in n:
		var k := float(i) / n
		var sm := lerpf(0.97, 0.6, sin(k * PI))
		last = last * sm + rng.randf_range(-1.0, 1.0) * (1.0 - sm)
		out[i] = last * sin(k * PI) * 1.4
	return out


func _drumroll(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var hit := int(RATE * 0.045)
	for i in n:
		var k := float(i) / n
		var local := float(i % hit) / hit
		out[i] = rng.randf_range(-1.0, 1.0) * exp(-local * 5.0) * (0.15 + 0.35 * k)
	return out


func _crowd(dur: float, cheer: bool) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var last := 0.0
	for i in n:
		var k := float(i) / n
		last = last * 0.82 + rng.randf_range(-1.0, 1.0) * 0.18
		var env := sin(minf(k * 4.0, 1.0) * PI * 0.5) * (1.0 - k)
		var voice := 0.0
		if not cheer:
			var t := float(i) / RATE
			voice = sin(TAU * lerpf(300.0, 180.0, k) * t) * 0.12 + sin(TAU * lerpf(380.0, 220.0, k) * t) * 0.1
		out[i] = (last * (0.9 if cheer else 0.35) + voice) * env * 1.3
	return out


func _drone(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var pulse := 0.6 + 0.4 * sin(TAU * 2.0 * t)
		out[i] = (sin(TAU * 55.0 * t) * 0.35 + sin(TAU * 82.5 * t) * 0.18 + _osc("saw", fmod(t * 110.0, 1.0)) * 0.05) * pulse * 0.6
	return out


## Loop musical simples: baixo + acordes + bumbo/chimbal. chords em semitons a partir de `root` (MIDI).
func _music_loop(chords: Array, bpm: float, root: int, energy: float) -> PackedFloat32Array:
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var total := int(bar * chords.size() * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in total:
		var t := float(i) / RATE
		var ci := int(t / bar) % chords.size()
		var ch: Array = chords[ci]
		var tb := fmod(t, beat)
		var t8 := fmod(t, beat / 2.0)
		var v := 0.0
		# baixo em colcheias
		var bass_f := 440.0 * pow(2.0, (root - 12 + int(ch[0]) - 69) / 12.0)
		v += _osc("tri", fmod(t * bass_f, 1.0)) * 0.22 * exp(-t8 * 6.0)
		# acordes (stabs no contratempo)
		var stab := exp(-fmod(t + beat / 2.0, beat) * 9.0)
		for semi in ch:
			var f := 440.0 * pow(2.0, (root + 12 + int(semi) - 69) / 12.0)
			v += _osc("square", fmod(t * f, 1.0)) * 0.035 * stab * energy
		# bumbo e chimbal
		v += sin(TAU * (50.0 + 90.0 * exp(-tb * 30.0)) * tb) * exp(-tb * 14.0) * 0.45 * energy
		v += rng.randf_range(-1.0, 1.0) * exp(-t8 * 60.0) * 0.06 * energy
		out[i] = v * 0.8
	return out


func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav
