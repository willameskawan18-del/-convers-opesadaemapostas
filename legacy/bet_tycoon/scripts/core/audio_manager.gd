extends Node
## Áudio do jogo. Sem assets de áudio no projeto, os sons são sintetizados em tempo de
## execução (placeholders funcionais). Para usar arquivos reais, coloque-os em
## res://audio/<nome>.ogg|.wav — eles têm prioridade sobre os sons sintetizados.

const RATE := 22050

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -8.0
	add_child(_music)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "SFX"
	_ambient.volume_db = -22.0
	add_child(_ambient)
	Settings.apply()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func play(sfx: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _get_stream(sfx)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_music() -> void:
	if _music.playing:
		return
	_music.stream = _get_stream("music")
	_music.play()


func play_ambient() -> void:
	if _ambient.playing:
		return
	_ambient.stream = _get_stream("ambient")
	_ambient.play()


func stop_ambient() -> void:
	_ambient.stop()


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


# --- Síntese de placeholders -------------------------------------------------

func _synth(sfx_name: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var loop := false
	match sfx_name:
		"click":
			samples = _tone(880.0, 0.05, "sine", 0.4)
		"hover":
			samples = _tone(1200.0, 0.03, "sine", 0.15)
		"cash":
			samples = _concat([_tone(1318.0, 0.07, "square", 0.25), _tone(1760.0, 0.18, "sine", 0.35)])
		"notify":
			samples = _concat([_tone(784.0, 0.09, "sine", 0.35), _tone(1046.0, 0.16, "sine", 0.35)])
		"error":
			samples = _tone(160.0, 0.22, "square", 0.25)
		"step":
			samples = _noise(0.05, 0.25, 0.85)
		"levelup":
			samples = _concat([_tone(523.0, 0.1, "square", 0.25), _tone(659.0, 0.1, "square", 0.25), _tone(784.0, 0.1, "square", 0.25), _tone(1046.0, 0.3, "sine", 0.35)])
		"win":
			samples = _concat([_tone(659.0, 0.1, "sine", 0.35), _tone(880.0, 0.1, "sine", 0.35), _tone(1318.0, 0.3, "sine", 0.35)])
		"lose":
			samples = _concat([_tone(440.0, 0.15, "sine", 0.3), _tone(330.0, 0.15, "sine", 0.3), _tone(220.0, 0.3, "sine", 0.3)])
		"door":
			samples = _noise(0.18, 0.3, 0.95)
		"machine":
			samples = _concat([_tone(600.0, 0.05, "square", 0.2), _tone(900.0, 0.05, "square", 0.2), _tone(1200.0, 0.08, "square", 0.2)])
		"music":
			samples = _music_loop()
			loop = true
		"ambient":
			samples = _noise(4.0, 0.12, 0.985)
			loop = true
		_:
			samples = _tone(660.0, 0.08, "sine", 0.3)
	return _to_wav(samples, loop)


func _tone(freq: float, dur: float, wave: String, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var ph := fmod(t * freq, 1.0)
		var v := 0.0
		match wave:
			"square":
				v = 1.0 if ph < 0.5 else -1.0
			"tri":
				v = 4.0 * absf(ph - 0.5) - 1.0
			_:
				v = sin(TAU * ph)
		var env := minf(1.0, float(i) / (RATE * 0.005)) * (1.0 - float(i) / n)
		out[i] = v * amp * env
	return out


func _noise(dur: float, amp: float, smooth: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in n:
		last = last * smooth + rng.randf_range(-1.0, 1.0) * (1.0 - smooth)
		out[i] = last * amp * 6.0
	if dur < 1.0:
		for i in n:
			out[i] *= 1.0 - float(i) / n
	else:
		var fade := int(RATE * 0.05)
		for i in fade:
			out[i] *= float(i) / fade
			out[n - 1 - i] *= float(i) / fade
	return out


func _music_loop() -> PackedFloat32Array:
	# Progressão simples em loop (lo-fi), 4 acordes de 2 segundos.
	var chords := [[220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [196.0, 246.9, 293.7], [164.8, 207.7, 246.9]]
	var out := PackedFloat32Array()
	var beat := 0.25
	for c in chords:
		var seg := PackedFloat32Array()
		seg.resize(int(2.0 * RATE))
		for i in seg.size():
			var t := float(i) / RATE
			var v := 0.0
			for f in c:
				v += sin(TAU * f * t) * 0.06
			var arp_f: float = c[int(t / beat) % 3] * 2.0
			var lt := fmod(t, beat)
			v += sin(TAU * arp_f * t) * 0.05 * exp(-lt * 10.0)
			seg[i] = v
		out.append_array(seg)
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
