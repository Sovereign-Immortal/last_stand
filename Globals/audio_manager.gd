extends Node
## Kenney Audio Manager — manages sound effects and continuous background music.

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _shoot_pl: AudioStreamPlayer
var _music_pl: AudioStreamPlayer

# Auditory Impairment Effects
var _lowpass_effect: AudioEffectLowPassFilter
var _distortion_effect: AudioEffectDistortion
var _reverb_effect: AudioEffectReverb
var _tinnitus_pl: AudioStreamPlayer
var _tinnitus_timer: float = 0.0
var tinnitus_active: bool = false

# Sensory Overload / Headache
var _sound_timestamps: Array[float] = []
var headache_active: bool = false
var _headache_cooldown_timer: float = 0.0
var _headache_duration_timer: float = 0.0

func _ready() -> void:
	# Ensure audio plays even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	
	# Instantiate SFX pool
	for _i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
		
	_shoot_pl = AudioStreamPlayer.new()
	_shoot_pl.bus = "SFX"
	add_child(_shoot_pl)
	
	# Setup tinnitus player
	_tinnitus_pl = AudioStreamPlayer.new()
	_tinnitus_pl.bus = "SFX"
	add_child(_tinnitus_pl)
	
	_load_all()
	
	# Assign tinnitus stream
	_tinnitus_pl.stream = _streams["dialog_beep"]
	
	_setup_music()

func _setup_buses() -> void:
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),   -2.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -15.0)
	
	# Clear existing Master effects (to prevent duplication)
	while AudioServer.get_bus_effect_count(0) > 0:
		AudioServer.remove_bus_effect(0, 0)
		
	# Setup lowpass filter (Master bus, index 0)
	_lowpass_effect = AudioEffectLowPassFilter.new()
	_lowpass_effect.cutoff_hz = 1800.0 # Default muffled
	_lowpass_effect.resonance = 0.5
	AudioServer.add_bus_effect(0, _lowpass_effect)
	
	# Setup distortion filter
	_distortion_effect = AudioEffectDistortion.new()
	_distortion_effect.drive = 0.0 # Default clean
	_distortion_effect.mode = AudioEffectDistortion.MODE_CLIP
	AudioServer.add_bus_effect(0, _distortion_effect)

	# Clear existing SFX effects (to prevent duplication)
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		while AudioServer.get_bus_effect_count(sfx_idx) > 0:
			AudioServer.remove_bus_effect(sfx_idx, 0)
		
		# Setup reverb filter on SFX bus
		_reverb_effect = AudioEffectReverb.new()
		_reverb_effect.room_size = 0.8
		_reverb_effect.damping = 0.5
		_reverb_effect.wet = 0.0 # Default dry (off)
		AudioServer.add_bus_effect(sfx_idx, _reverb_effect)

func set_echo_enabled(enabled: bool) -> void:
	if _reverb_effect:
		_reverb_effect.wet = 0.45 if enabled else 0.0

func _setup_music() -> void:
	_music_pl = AudioStreamPlayer.new()
	_music_pl.bus = "Music"
	_music_pl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_pl)
	
	var stream = load("res://Last Stand Assets/Audio/kenney_rpg-audio/Preview.ogg")
	if stream:
		_music_pl.stream = stream
		_music_pl.finished.connect(func():
			_music_pl.play()
		)
		_music_pl.play()

func _process(delta: float) -> void:
	# Handle tinnitus duration
	if _tinnitus_timer > 0.0:
		_tinnitus_timer -= delta
		if _tinnitus_timer <= 0.0:
			tinnitus_active = false
			_tinnitus_pl.stop()
			
	# Handle headache timers
	if _headache_cooldown_timer > 0.0:
		_headache_cooldown_timer -= delta
	if _headache_duration_timer > 0.0:
		_headache_duration_timer -= delta
		if _headache_duration_timer <= 0.0:
			headache_active = false
			
	# Update active sound timestamps in the last 2 seconds
	var now := Time.get_ticks_msec() / 1000.0
	var active_ts: Array[float] = []
	for ts in _sound_timestamps:
		if now - ts <= 2.0:
			active_ts.append(ts)
	_sound_timestamps = active_ts
	
	# Trigger sensory overload / headache state
	# Triggers when 8 or more sounds occur within 2.0 seconds
	if _sound_timestamps.size() >= 8 and not headache_active and _headache_cooldown_timer <= 0.0:
		headache_active = true
		_headache_duration_timer = 5.0
		_headache_cooldown_timer = 20.0
		
		# Shake player screen on headache
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("_shake_screen"):
			player._shake_screen(8.0, 3.0)
			
		var shouts: Array[String] = ["SHUT UPP", "ShUTUpp!!"]
		var chosen_shout: String = shouts[randi() % shouts.size()]
		DialogManager.show_dialog([
			{
				"speaker": "Kaelan",
				"text": chosen_shout,
				"color": Color(0.2, 0.9, 1.0)
			}
		])
	
	# Update real-time audio impairment state
	if DialogManager.has_method("is_active") and DialogManager.is_active():
		# Dialogue active: crystal-clear relief
		_lowpass_effect.cutoff_hz = 20000.0
		_distortion_effect.drive = 0.0
	elif tinnitus_active:
		# Tinnitus event: heavy muffle, distorted, high-pitch ring
		_lowpass_effect.cutoff_hz = 500.0
		_distortion_effect.drive = 0.4
		if not _tinnitus_pl.playing:
			_tinnitus_pl.play()
	elif headache_active:
		# Headache sensory overload: heavy lowpass, high distortion
		_lowpass_effect.cutoff_hz = 600.0
		_distortion_effect.drive = 0.65
	else:
		# Normal gameplay: muffled filter with slight organic fluctuations
		var time_ms := Time.get_ticks_msec()
		var fluctuation := sin(time_ms * 0.003) * 120.0
		_lowpass_effect.cutoff_hz = 1750.0 + fluctuation
		_distortion_effect.drive = 0.0

func trigger_tinnitus(duration: float = 2.0) -> void:
	tinnitus_active = true
	_tinnitus_timer = duration
	_tinnitus_pl.pitch_scale = 5.0 # Extremely high pitch tone
	_tinnitus_pl.volume_db = 2.0
	_tinnitus_pl.play()
	
	# Shake the player's screen and add aim penalty
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("_shake_screen"):
			player._shake_screen(10.0, duration)
		if "slow_timer" in player:
			player.slow_timer = duration # slow down movement speed during ringing

func _register_sound() -> void:
	# Don't track clicks or ticks
	if DialogManager.has_method("is_active") and DialogManager.is_active():
		return
	_sound_timestamps.append(Time.get_ticks_msec() / 1000.0)

func _free_player() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing: return p
	return _pool[0]

# ── Public API ──────────────────────────────────────────────────────────────
func play_shoot(weapon_index: int = 0) -> void:
	_register_sound()
	var keys: Array[String] = ["sht_pistol", "sht_mg", "sht_silencer"]
	var key = keys[weapon_index] if weapon_index < keys.size() else "sht_pistol"
	_shoot_pl.stream = _streams[key]
	_shoot_pl.pitch_scale = randf_range(0.94, 1.06)
	_shoot_pl.play(0.0)

func play_empty() -> void:
	var p := _free_player()
	p.stream = _streams["empty"]
	p.play()

func play_zombie_hit() -> void:
	_register_sound()
	var p := _free_player()
	p.stream = _streams["z_hit"]
	p.pitch_scale = randf_range(0.85, 1.15)
	p.play()

func play_zombie_die() -> void:
	_register_sound()
	var p := _free_player()
	p.stream = _streams["z_die"]
	p.pitch_scale = randf_range(0.9, 1.1)
	p.play()

func play_zombie_groan() -> void:
	_register_sound()
	var p := _free_player()
	p.stream = _streams["z_groan"]
	p.pitch_scale = randf_range(0.45, 0.6) # Low pitch wood creak sounds like a zombie growl
	p.play()

func play_player_hurt() -> void:
	_register_sound()
	var p := _free_player()
	p.stream = _streams["p_hurt"]
	p.play()

func play_pickup() -> void:
	var p := _free_player()
	p.stream = _streams["pickup"]
	p.play()

func play_wave_start() -> void:
	var p := _free_player()
	p.stream = _streams["wave_start"]
	p.volume_db = -4.0
	p.play()

func play_wave_complete() -> void:
	var p := _free_player()
	p.stream = _streams["wave_done"]
	p.volume_db = -4.0
	p.play()

func play_hover() -> void:
	var p := _free_player()
	p.stream = _streams["hover"]
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()

func play_click() -> void:
	var p := _free_player()
	p.stream = _streams["click"]
	p.play()

func play_upgrade() -> void:
	var p := _free_player()
	p.stream = _streams["upgrade"]
	p.play()

func play_buy() -> void:
	var p := _free_player()
	p.stream = _streams["buy"]
	p.play()

func play_dialog_beep() -> void:
	var p := _free_player()
	p.stream = _streams["dialog_beep"]
	p.pitch_scale = randf_range(1.15, 1.35)
	p.volume_db = -8.0
	p.play()

# ── Sound Loading ───────────────────────────────────────────────────────────
func _load_all() -> void:
	var base_path := "res://Last Stand Assets/Audio/kenney_impact-sounds/Audio/"
	var base_path_ui := "res://Last Stand Assets/Audio/kenney_interface-sounds/Audio/"
	var base_path_rpg := "res://Last Stand Assets/Audio/kenney_rpg-audio/Audio/"
	
	_streams["sht_pistol"]   = load(base_path + "impactPlate_light_002.ogg")
	_streams["sht_mg"]       = load(base_path + "impactPlate_heavy_000.ogg")
	_streams["sht_silencer"] = load(base_path + "impactSoft_medium_001.ogg")
	_streams["z_hit"]        = load(base_path + "impactPunch_medium_001.ogg")
	_streams["z_die"]        = load(base_path + "impactPunch_heavy_002.ogg")
	_streams["p_hurt"]       = load(base_path + "impactPunch_heavy_000.ogg")
	_streams["empty"]        = load(base_path_ui + "toggle_001.ogg")
	_streams["pickup"]       = load(base_path_ui + "confirmation_001.ogg")
	_streams["wave_start"]   = load(base_path + "impactBell_heavy_001.ogg")
	_streams["wave_done"]    = load(base_path + "impactBell_heavy_000.ogg")
	_streams["hover"]        = load(base_path_ui + "tick_001.ogg")
	_streams["click"]        = load(base_path_ui + "click_001.ogg")
	_streams["z_groan"]      = load(base_path_rpg + "creak1.ogg")
	_streams["upgrade"]      = load(base_path_rpg + "handleCoins.ogg")
	_streams["buy"]          = load(base_path_rpg + "handleCoins2.ogg")
	_streams["dialog_beep"]  = load(base_path_ui + "tick_002.ogg")

func set_volume(bus_name: String, pct: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db = linear_to_db(pct)
		AudioServer.set_bus_volume_db(idx, db)

func get_volume(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db = AudioServer.get_bus_volume_db(idx)
		return db_to_linear(db)
	return 1.0
