extends Node
## Procedural audio — all SFX synthesized from PCM. No audio files needed.

const SR := 22050  # sample rate

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _shoot_pl: AudioStreamPlayer

func _ready() -> void:
	_setup_buses()
	for _i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_shoot_pl = AudioStreamPlayer.new()
	_shoot_pl.bus = "SFX"
	add_child(_shoot_pl)
	_bake_all()

func _setup_buses() -> void:
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),   -2.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -10.0)

func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing: return p
	return _pool[0]

# ── Public API ──────────────────────────────────────────────────────────────
func play_shoot(weapon_index: int = 0) -> void:
	var keys: Array[String] = ["sht_pistol", "sht_mg", "sht_silencer"]
	_shoot_pl.stream = _streams[keys[weapon_index]] as AudioStreamWAV
	_shoot_pl.pitch_scale = randf_range(0.94, 1.06)
	_shoot_pl.play(0.0)

func play_empty() -> void:
	var p := _free_player(); p.stream = _streams["empty"] as AudioStreamWAV; p.play()

func play_zombie_hit() -> void:
	var p := _free_player()
	p.stream = _streams["z_hit"] as AudioStreamWAV
	p.pitch_scale = randf_range(0.75, 1.25)
	p.play()

func play_zombie_die() -> void:
	var p := _free_player()
	p.stream = _streams["z_die"] as AudioStreamWAV
	p.pitch_scale = randf_range(0.7, 1.0)
	p.play()

func play_player_hurt() -> void:
	var p := _free_player(); p.stream = _streams["p_hurt"] as AudioStreamWAV; p.play()

func play_pickup() -> void:
	var p := _free_player(); p.stream = _streams["pickup"] as AudioStreamWAV; p.play()

func play_wave_start() -> void:
	var p := _free_player(); p.stream = _streams["wave_start"] as AudioStreamWAV; p.volume_db = -4.0; p.play()

func play_wave_complete() -> void:
	var p := _free_player(); p.stream = _streams["wave_done"] as AudioStreamWAV; p.volume_db = -4.0; p.play()

# ── PCM baking ──────────────────────────────────────────────────────────────
func _bake_all() -> void:
	_streams["sht_pistol"]  = _wav(_shoot(0.08, 35.0, 1.0))
	_streams["sht_mg"]      = _wav(_shoot(0.05, 55.0, 0.80))
	_streams["sht_silencer"]= _wav(_shoot(0.07, 28.0, 0.22))
	_streams["z_hit"]       = _wav(_noise(0.10, 18.0, 0.50))
	_streams["z_die"]       = _wav(_zombie_die())
	_streams["p_hurt"]      = _wav(_noise(0.18, 10.0, 0.75))
	_streams["empty"]       = _wav(_noise(0.03, 200.0, 0.35))
	_streams["pickup"]      = _wav(_pickup())
	_streams["wave_start"]  = _wav(_wave_start())
	_streams["wave_done"]   = _wav(_wave_complete())

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR; s.stereo = false
	var d := PackedByteArray(); d.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		d[i*2] = v & 0xFF; d[i*2+1] = (v >> 8) & 0xFF
	s.data = d; return s

func _noise(dur: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(SR * dur); var o := PackedFloat32Array(); o.resize(n)
	for i in n:
		o[i] = randf_range(-1.0, 1.0) * amp * exp(-float(i)/SR * decay)
	return o

func _shoot(dur: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(SR * dur); var o := PackedFloat32Array(); o.resize(n)
	for i in n:
		var t := float(i) / SR
		var env := exp(-t * decay)
		o[i] = (randf_range(-1.0,1.0)*0.7 + sin(TAU*80.0*t)*exp(-t*60.0)*0.5) * amp * env
	return o

func _zombie_die() -> PackedFloat32Array:
	var dur := 0.30; var n := int(SR*dur); var o := PackedFloat32Array(); o.resize(n)
	for i in n:
		var t := float(i)/SR; var env := exp(-t*8.0)
		o[i] = (sin(TAU*120.0*t)*0.4 + sin(TAU*80.0*t*(1.0-t*0.5))*0.3 + randf_range(-1.0,1.0)*0.3) * env
	return o

func _pickup() -> PackedFloat32Array:
	var dur := 0.18; var n := int(SR*dur); var o := PackedFloat32Array(); o.resize(n)
	for i in n:
		var t: float = float(i)/SR
		var freq: float = lerpf(440.0, 1200.0, t/dur)
		o[i] = sin(TAU*freq*t) * sin(PI*t/dur) * 0.5
	return o

func _wave_start() -> PackedFloat32Array:
	var dur := 0.60; var n := int(SR*dur); var o := PackedFloat32Array(); o.resize(n)
	for i in n:
		var t := float(i)/SR
		var env := minf(t*5.0,1.0) * (1.0 - maxf((t-0.4)/0.2, 0.0))
		o[i] = (sin(TAU*110.0*t)*0.5 + sin(TAU*116.0*t)*0.5) * env * 0.6
	return o

func _wave_complete() -> PackedFloat32Array:
	var dur := 0.60; var n := int(SR*dur)
	var notes := [523.25, 659.25, 783.99]  # C5 E5 G5
	var nd := dur / notes.size()
	var o := PackedFloat32Array(); o.resize(n)
	for i in n:
		var t := float(i)/SR; var ni := mini(int(t/nd), notes.size()-1)
		var tl := fmod(t, nd)
		o[i] = sin(TAU * notes[ni] * t) * sin(PI * tl / nd) * 0.4
	return o
