extends Node
## Placeholder audio system. No copyrighted assets: every "track" is generated
## procedurally as PCM sine/saw/noise at startup. The public API is split by use
## so real audio assets can be dropped in later without touching gameplay code.

const MIX_RATE := 22050
const MAX_PLAYERS := 14

var _sfx_cache: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _sfx_pool: Array[AudioStreamPlayer] = []
var _current_music: String = ""


func _ready() -> void:
	_generate_all()
	_build_players()
	_apply_volumes()


func _build_players() -> void:
	for i in range(MAX_PLAYERS):
		var p := AudioStreamPlayer.new()
		p.volume_db = 0.0
		add_child(p)
		_sfx_pool.append(p)
	for i in range(2):
		var m := AudioStreamPlayer.new()
		m.volume_db = -6.0
		m.autoplay = false
		add_child(m)
		_music_players.append(m)


func play_sfx(sfx_id: String, pitch_scale: float = 1.0) -> void:
	if not _sfx_cache.has(sfx_id):
		return
	var player := _next_sfx_player()
	if player == null:
		return
	player.stream = _sfx_cache[sfx_id]
	player.pitch_scale = pitch_scale
	player.volume_db = linear_to_db(GameState.settings["sfx_volume"]) if GameState else 0.0
	player.play()


func play_music(music_id: String) -> void:
	if music_id == _current_music:
		return
	_current_music = music_id
	if not _sfx_cache.has(music_id) or _music_players.is_empty():
		return
	var player := _music_players[0]
	player.stream = _sfx_cache[music_id]
	player.volume_db = linear_to_db(GameState.settings["music_volume"]) if GameState else -6.0
	player.play()


func stop_music() -> void:
	for m in _music_players:
		m.stop()
	_current_music = ""


func set_volumes() -> void:
	if GameState == null:
		return
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_db(master, linear_to_db(GameState.settings["master_volume"]))
	apply_to_players()


func apply_to_players() -> void:
	if GameState == null:
		return
	var sfx_db := linear_to_db(GameState.settings["sfx_volume"])
	for p in _sfx_pool:
		p.volume_db = sfx_db
	for m in _music_players:
		m.volume_db = linear_to_db(GameState.settings["music_volume"])


func _next_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return _sfx_pool[0]


func _generate_all() -> void:
	_sfx_cache["swing"] = _make_tone(420.0, 0.12, 0.22, "noise")
	_sfx_cache["hit"] = _make_tone(150.0, 0.09, 0.45, "saw")
	_sfx_cache["hit_heavy"] = _make_tone(90.0, 0.16, 0.52, "saw")
	_sfx_cache["perfect_guard"] = _make_tone(720.0, 0.18, 0.35, "sine")
	_sfx_cache["dash"] = _make_tone(300.0, 0.13, 0.30, "noise")
	_sfx_cache["jump"] = _make_tone(340.0, 0.10, 0.20, "sine")
	_sfx_cache["guard"] = _make_tone(220.0, 0.10, 0.25, "saw")
	_sfx_cache["skill"] = _make_tone(520.0, 0.22, 0.30, "sine")
	_sfx_cache["burst"] = _make_tone(650.0, 0.45, 0.40, "sine")
	_sfx_cache["hurt"] = _make_tone(130.0, 0.16, 0.42, "saw")
	_sfx_cache["death"] = _make_tone(70.0, 0.40, 0.50, "saw")
	_sfx_cache["pickup"] = _make_tone(880.0, 0.14, 0.28, "sine")
	_sfx_cache["totem_break"] = _make_tone(120.0, 0.5, 0.55, "noise")
	_sfx_cache["boss_roar"] = _make_tone(55.0, 0.9, 0.5, "saw")
	_sfx_cache["ui"] = _make_tone(520.0, 0.06, 0.18, "sine")
	_sfx_cache["save"] = _make_tone(740.0, 0.08, 0.22, "sine")

	_sfx_cache["music_exploration"] = _make_tone(220.0, 8.0, 0.07, "sine")
	_sfx_cache["music_combat"] = _make_tone(160.0, 6.0, 0.08, "saw")
	_sfx_cache["music_boss"] = _make_tone(55.0, 8.0, 0.10, "saw")
	_sfx_cache["ambience_wind"] = _make_tone(95.0, 6.0, 0.05, "noise")


func _make_tone(freq: float, duration: float, volume: float, shape: String) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * duration)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if duration > 2.0 else AudioStreamWAV.LOOP_DISABLED
	wav.loop_begin = 0
	wav.loop_end = sample_count if duration > 2.0 else 0

	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	var phase_inc := TAU * freq / MIX_RATE
	var rng_freq := freq * 0.9

	for i in range(sample_count):
		var t := float(i) / float(MIX_RATE)
		var envelope: float = 1.0
		if duration <= 2.0:
			var attack := minf(1.0, t / 0.01)
			var release := 1.0 - clampf((t - (duration - 0.04)) / 0.04, 0.0, 1.0)
			envelope = attack * release
		phase += phase_inc

		var sample := 0.0
		match shape:
			"saw":
				sample = (fmod(phase, TAU) / TAU) * 2.0 - 1.0
			"square":
				sample = 1.0 if fmod(phase, TAU) < 3.14 else -1.0
			"noise":
				sample = sin(phase * 1.7) * 0.5 + sin(phase * 0.5) * 0.3
				sample += randf_range(-1.0, 1.0) * 0.25
			_:
				sample = sin(phase)

		var value := int(clamp(sample * envelope * volume * 32767.0, -32000.0, 32000.0))
		value = value & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF

	wav.data = data
	return wav
