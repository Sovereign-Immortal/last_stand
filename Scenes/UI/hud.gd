extends CanvasLayer

# ---------------------------------------------------------------------------
# Node references (set via @onready after scene is built)
# ---------------------------------------------------------------------------
@onready var health_bar: ProgressBar  = $HUDContainer/VBox/HealthRow/HealthBar
@onready var health_label: Label      = $HUDContainer/VBox/HealthRow/HealthLabel
@onready var score_label: Label       = $HUDContainer/VBox/TopRow/ScoreLabel
@onready var wave_label: Label        = $HUDContainer/VBox/TopRow/WaveLabel
@onready var weapon_label: Label      = $HUDContainer/VBox/BottomRow/WeaponLabel
@onready var ammo_label: Label        = $HUDContainer/VBox/BottomRow/AmmoLabel
@onready var damage_flash: ColorRect  = $DamageFlash
@onready var announcement: Label      = $AnnouncementLabel
@onready var combo_label: Label       = $ComboLabel
@onready var enemies_label: Label     = $HUDContainer/VBox/TopRow/EnemiesLabel
@onready var pause_menu               = $PauseMenu

var _flash_timer: float = 0.0
var _enemies_poll_timer: float = 0.0
var _vignette_mat: ShaderMaterial = null
var _player: CharacterBody2D = null
var _next_wave_timer_label: Label = null
var weapon_icon: Control = null
var bullet_icon: Control = null
var explosive_icon: Control = null
var explosive_label: Label = null
var _crosshair_scene := preload("res://Scenes/UI/crosshair.tscn")
var _crosshair: Control = null
var _minimap: Control = null

# Weapon select menu variables
var _weapon_menu: PanelContainer = null
var _wm_title: Label
var _wm_desc: Label
var _wm_stats: Label
var _wm_slot1_btn: Button
var _wm_slot2_btn: Button
var _wm_close_btn: Button
var _pickup_weapon_idx: int = -1
var _pickup_amount: int = 0
var _pickup_node: Node2D = null
var _weapon_menu_open: bool = false
var _legend_labels: Array[Label] = []

# Character/Merchant menu variables
var _char_menu: PanelContainer = null
var _char_menu_open: bool = false
var _cm_title: Label
var _cm_info: Label
var _cm_level_btn: Button
var _cm_vigor_lbl: Label
var _cm_haste_lbl: Label
var _cm_strength_lbl: Label
var _cm_vigor_btn: Button
var _cm_haste_btn: Button
var _cm_strength_btn: Button
var _cm_ammo_std_btn: Button
var _cm_ammo_sp_btn: Button
var _cm_heal_btn: Button
var _cm_hire_hunter_btn: Button
var _cm_hire_pacifist_btn: Button
var _cm_close_btn: Button

# Mercenary menu variables
var _merc_menu: PanelContainer = null
var _merc_menu_open: bool = false
var _selected_merc: Node2D = null
var _merc_list_container: VBoxContainer = null
var _merc_details_title: Label = null
var _merc_details_bio: Label = null
var _merc_details_hb: ProgressBar = null
var _merc_details_weapon: Label = null
var _merc_details_bullets: Label = null
var _merc_w1_btn: Button = null # Pistol
var _merc_w2_btn: Button = null # Machine Gun
var _merc_w3_btn: Button = null # Silencer
var _merc_b0_btn: Button = null # Standard
var _merc_b1_btn: Button = null # Quick
var _merc_b2_btn: Button = null # Paralysis
var _merc_b3_btn: Button = null # Knockback
var _merc_b4_btn: Button = null # Slow Down
var _merc_close_btn: Button = null


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("hud")
	process_mode = Node.PROCESS_MODE_ALWAYS  # respond to input while paused
	_setup_vignette()
	
	# Set up the Next Wave Timer Label programmatically
	_next_wave_timer_label = Label.new()
	_next_wave_timer_label.name = "NextWaveTimerLabel"
	_next_wave_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_wave_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_next_wave_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_next_wave_timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_next_wave_timer_label.offset_top = 40
	_next_wave_timer_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0)) # Orange
	_next_wave_timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_next_wave_timer_label.add_theme_constant_override("shadow_offset_x", 1)
	_next_wave_timer_label.add_theme_constant_override("shadow_offset_y", 1)
	_next_wave_timer_label.add_theme_font_size_override("font_size", 13)
	_next_wave_timer_label.text = ""
	_next_wave_timer_label.visible = false
	add_child(_next_wave_timer_label)

	# Set up bullet type and ammo label programmatically in BottomRow
	var bottom_row = $HUDContainer/VBox/BottomRow
	if bottom_row:
		# Hide default weapon text label to replace it with icon
		if weapon_label:
			weapon_label.visible = false
		
		var hud_icon_script = load("res://Scenes/UI/hud_icon.gd")
		
		# Create weapon icon and insert at index 0
		weapon_icon = hud_icon_script.new()
		weapon_icon.name = "WeaponIcon"
		bottom_row.add_child(weapon_icon)
		bottom_row.move_child(weapon_icon, 0)
		
		# Create bullet icon and insert before AmmoLabel
		bullet_icon = hud_icon_script.new()
		bullet_icon.name = "BulletIcon"
		bottom_row.add_child(bullet_icon)
		
		# AmmoLabel is originally at index 2 (WeaponLabel(0), Separator(1), AmmoLabel(2)).
		# Since we added weapon_icon, indices shifted. Let's find AmmoLabel and insert before it.
		var ammo_idx = bottom_row.get_child_count() - 1
		for i in range(bottom_row.get_child_count()):
			if bottom_row.get_child(i) == ammo_label:
				ammo_idx = i
				break
		bottom_row.move_child(bullet_icon, ammo_idx)
		
		# Add sep2 (" | ")
		var sep2 := Label.new()
		sep2.text = "  |  "
		sep2.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		bottom_row.add_child(sep2)
		
		# Create explosive icon
		explosive_icon = hud_icon_script.new()
		explosive_icon.name = "ExplosiveIcon"
		bottom_row.add_child(explosive_icon)
		
		# Create explosive label (only for ammo display)
		explosive_label = Label.new()
		explosive_label.name = "ExplosiveLabel"
		explosive_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		explosive_label.add_theme_font_size_override("font_size", 14)
		explosive_label.text = "[3]"
		bottom_row.add_child(explosive_label)

	Globals.score_changed.connect(_on_score_changed)
	Globals.wave_changed.connect(_on_wave_changed)
	Globals.combo_changed.connect(_on_combo_changed)
	Globals.level_up_available.connect(func():
		if is_inside_tree():
			_show_announcement("YOU CAN LEVEL UP!\n[Press C]", Color(0.1, 0.8, 1.0))
	)
	Globals.player_leveled_up.connect(func():
		if is_inside_tree():
			_on_score_changed(Globals.score)
			_update_char_menu()
	)

	# Instantiate and add crosshair
	_crosshair = _crosshair_scene.instantiate()
	add_child(_crosshair)

	# Instantiate and add minimap
	var minimap_script = load("res://Scenes/UI/minimap.gd")
	if minimap_script:
		_minimap = minimap_script.new()
		add_child(_minimap)

	_create_weapon_menu()
	_create_char_menu()
	_create_merc_menu()

	await get_tree().process_frame

	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.health_changed.connect(_on_health_changed)
		_player.weapon_changed.connect(_on_weapon_changed)
		_player.ammo_changed.connect(_on_ammo_changed)
		_player.bullet_changed.connect(_on_bullet_changed)
		if _player.has_signal("explosive_changed"):
			_player.explosive_changed.connect(_on_explosive_changed)
		if _player.has_signal("weapon_fired"):
			_player.weapon_fired.connect(_on_weapon_fired)
		_on_health_changed(_player.health, _player.max_health)
		_on_bullet_changed(_player.BULLET_TYPES[_player.current_bullet_type]["name"], _player.bullet_ammo[_player.current_bullet_type])
		if _player.has_signal("explosive_changed"):
			_on_explosive_changed("Grenade", _player.explosives_ammo[0])

	var wm := get_tree().get_root().get_node_or_null("Root/WaveManager")
	if wm:
		wm.wave_started.connect(_on_wave_started)
		wm.wave_completed.connect(_on_wave_completed)
		wm.wave_countdown.connect(_on_wave_countdown)

	_on_score_changed(Globals.score)
	_on_wave_changed(Globals.current_wave)
	_on_weapon_changed("Pistol", -1)
	_on_combo_changed(1)


	damage_flash.modulate.a = 0.0
	announcement.modulate.a = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if _player and _player.is_dead:
			return
		if _weapon_menu_open:
			close_weapon_menu()
			return
		if _char_menu_open:
			close_char_menu()
			return
		if _merc_menu_open:
			close_merc_menu()
			return
		var new_pause_state = !pause_menu.visible
		get_tree().paused = new_pause_state
		pause_menu.visible = new_pause_state
	
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		if _player and not _player.is_dead and not pause_menu.visible:
			if _weapon_menu_open:
				close_weapon_menu()
			else:
				if _char_menu_open:
					close_char_menu()
				if _merc_menu_open:
					close_merc_menu()
				open_weapon_switch_menu()
	
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		if _player and not _player.is_dead and not pause_menu.visible:
			if _char_menu_open:
				close_char_menu()
			else:
				if _weapon_menu_open:
					close_weapon_menu()
				if _merc_menu_open:
					close_merc_menu()
				open_char_menu()
				
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		if _player and not _player.is_dead and not pause_menu.visible:
			if _merc_menu_open:
				close_merc_menu()
			else:
				if _weapon_menu_open:
					close_weapon_menu()
				if _char_menu_open:
					close_char_menu()
				open_merc_menu()


func _process(delta: float) -> void:
	# Damage flash
	if _flash_timer > 0.0:
		_flash_timer -= delta
		damage_flash.modulate.a = _flash_timer / 0.3
	else:
		damage_flash.modulate.a = 0.0
	# Vignette: pulse red at low health or purple/red at headache overload
	if _vignette_mat and _player and not _player.is_dead:
		if AudioManager.headache_active:
			var pulse := sin(Time.get_ticks_msec() * 0.008) * 0.5 + 0.5
			_vignette_mat.set_shader_parameter("strength", lerp(1.0, 2.2, pulse))
			_vignette_mat.set_shader_parameter("vig_color", Vector3(0.6, 0.0, 0.45)) # Deep purple/red
		else:
			var hp_pct := float(_player.health) / float(_player.max_health)
			if hp_pct < 0.3:
				var pulse := sin(Time.get_ticks_msec() * 0.004) * 0.5 + 0.5
				_vignette_mat.set_shader_parameter("strength", lerp(0.7, 1.8, pulse))
				_vignette_mat.set_shader_parameter("vig_color", Vector3(0.5, 0.0, 0.0))
			else:
				_vignette_mat.set_shader_parameter("strength", 0.55)
				_vignette_mat.set_shader_parameter("vig_color", Vector3(0.0, 0.0, 0.0))
	# Poll zombie count
	_enemies_poll_timer -= delta
	if _enemies_poll_timer <= 0.0:
		_enemies_poll_timer = 0.5
		var count := get_tree().get_nodes_in_group("zombies").size()
		enemies_label.text = "%d LEFT" % count if count > 0 else ""

# ---------------------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------------------
func _on_health_changed(new_hp: int, max_hp: int) -> void:
	health_bar.max_value = max_hp
	health_bar.value = new_hp
	health_label.text = "%d / %d" % [new_hp, max_hp]
	if new_hp < max_hp * 0.3:
		health_bar.modulate = Color(1.0, 0.2, 0.2)
	elif new_hp < max_hp * 0.6:
		health_bar.modulate = Color(1.0, 0.7, 0.1)
	else:
		health_bar.modulate = Color(0.2, 0.9, 0.3)
	# Trigger red flash
	_flash_timer = 0.3

func _on_score_changed(new_score: int) -> void:
	score_label.text = "LVL %d  [EXP: %d/%d]" % [Globals.player_level, new_score, Globals.get_next_level_cost()]

func _on_wave_changed(new_wave: int) -> void:
	wave_label.text = "WAVE  %d" % new_wave

func _on_weapon_changed(weapon_name: String, _ammo: int) -> void:
	if weapon_icon:
		weapon_icon.set_icon("weapon", weapon_name)
	if _player:
		var b_name = _player.BULLET_TYPES[_player.current_bullet_type]["name"]
		var b_ammo = _player.bullet_ammo[_player.current_bullet_type]
		_on_bullet_changed(b_name, b_ammo)

func _on_ammo_changed(_ammo: int) -> void:
	pass


func _on_combo_changed(multiplier: int) -> void:
	if multiplier <= 1:
		combo_label.visible = false
		return
	combo_label.visible = true
	combo_label.text = "x%d  COMBO!" % multiplier
	# Flash bigger on new combo level
	var tw := create_tween()
	tw.tween_property(combo_label, "scale", Vector2(1.3, 1.3), 0.08)
	tw.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.15)

# ---------------------------------------------------------------------------
# Wave announcements
# ---------------------------------------------------------------------------
func _on_wave_started(wave_num: int, total: int) -> void:
	AudioManager.play_wave_start()
	_show_announcement("WAVE  %d\n%d ENEMIES" % [wave_num, total], Color(1.0, 0.92, 0.2))

func _on_wave_completed(_wave_num: int) -> void:
	AudioManager.play_wave_complete()
	_show_announcement("WAVE COMPLETE!", Color(0.2, 1.0, 0.4))

func _show_announcement(text: String, color: Color) -> void:
	announcement.text = text
	announcement.modulate = color
	var tw := create_tween()
	tw.tween_property(announcement, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.0)
	tw.tween_property(announcement, "modulate:a", 0.0, 0.5)

func show_pickup_announcement(bullet_name: String, amount: int, color: Color) -> void:
	var label := Label.new()
	label.text = "+%d %s Bullets" % [amount, bullet_name]
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	
	var viewport_size := get_viewport().get_visible_rect().size
	var target_pos := Vector2(viewport_size.x / 2.0 - 150.0, viewport_size.y - 180.0)
	target_pos.x += randf_range(-30.0, 30.0)
	target_pos.y += randf_range(-20.0, 20.0)
	
	label.global_position = target_pos
	
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 18)
	
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "global_position:y", target_pos.y - 50.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.chain().tween_callback(label.queue_free)

func _on_wave_countdown(seconds_left: int) -> void:
	if seconds_left > 0:
		_next_wave_timer_label.text = "NEXT WAVE IN %d..." % seconds_left
		_next_wave_timer_label.visible = true
	else:
		_next_wave_timer_label.text = ""
		_next_wave_timer_label.visible = false

# ---------------------------------------------------------------------------
# Vignette setup (programmatic — no shader file needed)
# ---------------------------------------------------------------------------
func _setup_vignette() -> void:
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 3.0) = 0.55;
uniform vec3 vig_color : source_color = vec3(0.0, 0.0, 0.0);
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = clamp(dot(uv, uv) * strength, 0.0, 1.0);
	COLOR = vec4(vig_color, d);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	vig.material = mat
	_vignette_mat = mat
	add_child(vig)
	move_child(vig, 0)  # render behind all other HUD nodes

func _on_bullet_changed(bullet_name: String, ammo: int) -> void:
	# Set text color based on bullet type
	var colors = {
		"Standard": Color(1.0, 0.9, 0.0),
		"Quick": Color(0.1, 0.6, 1.0),
		"Paralysis": Color(0.7, 0.1, 1.0),
		"Knockback": Color(0.1, 0.9, 0.1),
		"Slow Down": Color(0.3, 0.9, 1.0)
	}
	var col: Color = colors.get(bullet_name, Color(1.0, 1.0, 1.0))
	
	if bullet_icon:
		bullet_icon.set_icon("bullet", bullet_name, col)
		
	if ammo_label:
		var ammo_str = "∞" if ammo == -1 else str(ammo)
		ammo_label.text = ammo_str
		ammo_label.add_theme_color_override("font_color", col)

func _on_explosive_changed(exp_name: String, ammo: int) -> void:
	var col = Color(0.2, 0.8, 0.2) # default green
	if exp_name == "Landmine":
		col = Color(0.8, 0.2, 0.2) # red
	elif exp_name == "Ice Bomb":
		col = Color(0.2, 0.8, 1.0) # blue
	elif exp_name == "Skill Point Orb":
		col = Color(1.0, 0.8, 0.1) # gold
	elif exp_name == "Giantification":
		col = Color(1.0, 0.5, 0.0) # orange
		
	if explosive_icon:
		explosive_icon.set_icon("item", exp_name, col)
		
	if explosive_label:
		explosive_label.text = "[%d]" % ammo
		explosive_label.add_theme_color_override("font_color", col)

		if _crosshair:
			_crosshair.set_crosshair_color(col)

func _on_weapon_fired() -> void:
	if _crosshair and _player:
		var kicks = [4.0, 7.0, 5.0]  # Pistol, MG, Silencer
		var idx = _player.current_weapon_index
		var kick = kicks[idx] if idx < kicks.size() else 5.0
		_crosshair.kick_spread(kick)

# ---------------------------------------------------------------------------
# Weapon Selection / Swap Menu (Programmatic Glassmorphic Overlay)
# ---------------------------------------------------------------------------
func _create_weapon_menu() -> void:
	_weapon_menu = PanelContainer.new()
	_weapon_menu.name = "WeaponSelectMenu"
	
	# Beautiful glassmorphic panel style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.05, 0.05, 0.8) # neon red border
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0.85, 0.05, 0.05, 0.15)
	style.shadow_size = 10
	_weapon_menu.add_theme_stylebox_override("panel", style)
	
	# Compact dimensions side-by-side (fits inside 640x360)
	_weapon_menu.custom_minimum_size = Vector2(520, 240)
	_weapon_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_weapon_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_weapon_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_weapon_menu.visible = false
	
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 8)
	margin_container.add_theme_constant_override("margin_right", 8)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	_weapon_menu.add_child(margin_container)
	
	# Side-by-side HBox layout
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	margin_container.add_child(hbox)
	
	# Left Side: Weapon Selection
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.custom_minimum_size = Vector2(235, 0)
	hbox.add_child(vbox)
	
	# Title
	_wm_title = Label.new()
	_wm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wm_title.add_theme_font_size_override("font_size", 11)
	_wm_title.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	vbox.add_child(_wm_title)
	
	# Description
	_wm_desc = Label.new()
	_wm_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wm_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wm_desc.add_theme_font_size_override("font_size", 9)
	_wm_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.82))
	vbox.add_child(_wm_desc)
	
	# Stats / Weapon Description Label
	_wm_stats = Label.new()
	_wm_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wm_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wm_stats.add_theme_font_size_override("font_size", 8)
	_wm_stats.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2)) # Sleek yellow
	vbox.add_child(_wm_stats)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(spacer)
	
	# Button VBox for slots
	var btn_vbox := VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_vbox)
	
	# Slot 1 button
	_wm_slot1_btn = Button.new()
	_wm_slot1_btn.custom_minimum_size = Vector2(220, 24)
	_wm_slot1_btn.add_theme_font_size_override("font_size", 9)
	_wm_slot1_btn.pressed.connect(_on_wm_slot1_pressed)
	btn_vbox.add_child(_wm_slot1_btn)
	
	# Slot 2 button
	_wm_slot2_btn = Button.new()
	_wm_slot2_btn.custom_minimum_size = Vector2(220, 24)
	_wm_slot2_btn.add_theme_font_size_override("font_size", 9)
	_wm_slot2_btn.pressed.connect(_on_wm_slot2_pressed)
	btn_vbox.add_child(_wm_slot2_btn)
	
	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(spacer2)
	
	# Close/Cancel button
	_wm_close_btn = Button.new()
	_wm_close_btn.custom_minimum_size = Vector2(110, 20)
	_wm_close_btn.add_theme_font_size_override("font_size", 8)
	_wm_close_btn.pressed.connect(_on_wm_close_pressed)
	vbox.add_child(_wm_close_btn)
	
	# Vertical separator (soft neon red line)
	var v_sep := ColorRect.new()
	v_sep.custom_minimum_size = Vector2(1, 180)
	v_sep.color = Color(0.85, 0.05, 0.05, 0.3)
	hbox.add_child(v_sep)
	
	# Right Side: Bullet Legend
	var legend_vbox := VBoxContainer.new()
	legend_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	legend_vbox.add_theme_constant_override("separation", 4)
	legend_vbox.custom_minimum_size = Vector2(235, 0)
	hbox.add_child(legend_vbox)
	
	# Title of Legend
	var legend_title := Label.new()
	legend_title.text = "BULLET EFFECT LEGEND"
	legend_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend_title.add_theme_font_size_override("font_size", 10)
	legend_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	legend_vbox.add_child(legend_title)
	
	# Separator line under title
	var legend_line := ColorRect.new()
	legend_line.custom_minimum_size = Vector2(210, 1)
	legend_line.color = Color(0.3, 0.3, 0.35, 0.5)
	legend_vbox.add_child(legend_line)
	
	# Legend rows VBox
	var legend_list := VBoxContainer.new()
	legend_list.add_theme_constant_override("separation", 2)
	legend_vbox.add_child(legend_list)
	
	var legends: Array[Dictionary] = [
		{
			"name": "Standard",
			"color": Color(1.0, 0.9, 0.0),
			"desc": "Standard damage. Refillable limited ammo."
		},
		{
			"name": "Quick",
			"color": Color(0.1, 0.6, 1.0),
			"desc": "1.6x Speed, 0.8x Damage. Good for fast targets."
		},
		{
			"name": "Paralysis",
			"color": Color(0.7, 0.1, 1.0),
			"desc": "Stuns enemies for 1.2 seconds on hit."
		},
		{
			"name": "Knockback",
			"color": Color(0.1, 0.9, 0.1),
			"desc": "Pushes enemies backward with 1.2x Damage."
		},
		{
			"name": "Slow Down",
			"color": Color(0.3, 0.9, 1.0),
			"desc": "Slows enemy speed by 60% for 3 seconds."
		}
	]
	
	_legend_labels.clear()
	for leg in legends:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		legend_list.add_child(row)
		
		# Bullet Indicator Dot "●"
		var bullet_dot := Label.new()
		bullet_dot.text = "●"
		bullet_dot.add_theme_font_size_override("font_size", 10)
		bullet_dot.add_theme_color_override("font_color", leg["color"])
		row.add_child(bullet_dot)
		
		var text_vbox := VBoxContainer.new()
		text_vbox.add_theme_constant_override("separation", 0)
		row.add_child(text_vbox)
		
		var name_lbl := Label.new()
		name_lbl.text = leg["name"]
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", leg["color"])
		text_vbox.add_child(name_lbl)
		_legend_labels.append(name_lbl)
		
		var desc_lbl := Label.new()
		desc_lbl.text = leg["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(200, 0)
		desc_lbl.add_theme_font_size_override("font_size", 8)
		desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.74))
		text_vbox.add_child(desc_lbl)
	
	# Add to CanvasLayer
	add_child(_weapon_menu)
	
	# Apply premium UIStyler styling to the menu
	UIStyler.style_scene(_weapon_menu)

func open_weapon_pickup_menu(weapon_idx: int, amount: int, pickup_node: Node2D) -> void:
	if not _player or _player.is_dead:
		return
	
	_pickup_weapon_idx = weapon_idx
	_pickup_amount = amount
	_pickup_node = pickup_node
	_weapon_menu_open = true
	
	# Set pause and mouse mode
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _crosshair:
		_crosshair.visible = false
	
	# Setup labels
	_wm_title.text = "NEW WEAPON DETECTED!"
	_wm_desc.text = "Choose a slot to equip:"
	_wm_stats.text = "FOUND: " + _player.WEAPONS[weapon_idx]["description"]
	
	# Setup slot 1 button
	var w1_name = _player.WEAPONS[_player.carried_weapons[0]]["name"]
	_wm_slot1_btn.text = "SLOT 1: REPLACE %s" % w1_name.to_upper()
	_wm_slot1_btn.disabled = false
	
	# Setup slot 2 button
	if _player.carried_weapons.size() > 1:
		var w2_name = _player.WEAPONS[_player.carried_weapons[1]]["name"]
		_wm_slot2_btn.text = "SLOT 2: REPLACE %s" % w2_name.to_upper()
		_wm_slot2_btn.disabled = false
	else:
		_wm_slot2_btn.text = "SLOT 2: EQUIP HERE (EMPTY)"
		_wm_slot2_btn.disabled = false
	
	_wm_close_btn.text = "LEAVE ON GROUND"
	
	_weapon_menu.visible = true
	_update_weapon_menu_bullet_counts()
	UIStyler.style_scene(_weapon_menu)

func open_weapon_switch_menu() -> void:
	if not _player or _player.is_dead:
		return
		
	_pickup_weapon_idx = -1
	_pickup_node = null
	_weapon_menu_open = true
	
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _crosshair:
		_crosshair.visible = false
		
	_wm_title.text = "WEAPON INVENTORY"
	_wm_desc.text = "Select a weapon to equip:"
	
	var desc1 = _player.WEAPONS[_player.carried_weapons[0]]["description"]
	var desc2 = ""
	if _player.carried_weapons.size() > 1:
		desc2 = "\n" + _player.WEAPONS[_player.carried_weapons[1]]["description"]
	_wm_stats.text = desc1 + desc2
	
	var w1_name = _player.WEAPONS[_player.carried_weapons[0]]["name"]
	var active_indicator1 = " [EQUIPPED]" if _player.active_slot == 0 else ""
	_wm_slot1_btn.text = "SLOT 1: %s%s" % [w1_name.to_upper(), active_indicator1]
	_wm_slot1_btn.disabled = false
	
	if _player.carried_weapons.size() > 1:
		var w2_name = _player.WEAPONS[_player.carried_weapons[1]]["name"]
		var active_indicator2 = " [EQUIPPED]" if _player.active_slot == 1 else ""
		_wm_slot2_btn.text = "SLOT 2: %s%s" % [w2_name.to_upper(), active_indicator2]
		_wm_slot2_btn.disabled = false
	else:
		_wm_slot2_btn.text = "SLOT 2: EMPTY"
		_wm_slot2_btn.disabled = true
		
	_wm_close_btn.text = "CLOSE"
	
	_weapon_menu.visible = true
	_update_weapon_menu_bullet_counts()
	UIStyler.style_scene(_weapon_menu)


func close_weapon_menu() -> void:
	_weapon_menu.visible = false
	_weapon_menu_open = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if _crosshair:
		_crosshair.visible = true
	# If we canceled a pickup, trigger cooldown
	if _pickup_node and is_instance_valid(_pickup_node):
		if _pickup_node.has_method("start_cooldown"):
			_pickup_node.start_cooldown()
	_pickup_node = null
	_pickup_weapon_idx = -1

func _update_weapon_menu_bullet_counts() -> void:
	if not _player:
		return
	for i in range(_legend_labels.size()):
		var lbl = _legend_labels[i]
		if is_instance_valid(lbl):
			var b_name = _player.BULLET_TYPES[i]["name"]
			var ammo = _player.bullet_ammo[i]
			lbl.text = b_name + "  [%d]" % ammo

func _on_wm_slot1_pressed() -> void:
	if not _player:
		return
	if _pickup_weapon_idx != -1:
		_player.equip_weapon_in_slot(_pickup_weapon_idx, 0, _pickup_amount)
		if _pickup_node and is_instance_valid(_pickup_node):
			if _pickup_node.has_method("_pop_collect"):
				_pickup_node._pop_collect()
			else:
				_pickup_node.queue_free()
			_pickup_node = null
		close_weapon_menu()
	else:
		_player._select_weapon_slot(0)
		close_weapon_menu()

func _on_wm_slot2_pressed() -> void:
	if not _player:
		return
	if _pickup_weapon_idx != -1:
		_player.equip_weapon_in_slot(_pickup_weapon_idx, 1, _pickup_amount)
		if _pickup_node and is_instance_valid(_pickup_node):
			if _pickup_node.has_method("_pop_collect"):
				_pickup_node._pop_collect()
			else:
				_pickup_node.queue_free()
			_pickup_node = null
		close_weapon_menu()
	else:
		if _player.carried_weapons.size() > 1:
			_player._select_weapon_slot(1)
		close_weapon_menu()

func _on_wm_close_pressed() -> void:
	close_weapon_menu()


# ---------------------------------------------------------------------------
# Character Progression & Merchant Shop Menu (Compact Glassmorphic HBox Overlay)
# ---------------------------------------------------------------------------
func _create_char_menu() -> void:
	_char_menu = PanelContainer.new()
	_char_menu.name = "CharacterShopMenu"
	
	# Beautiful glassmorphic panel style (neon cyan border for character progression)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.1, 0.8, 1.0, 0.8) # neon cyan border
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0.1, 0.8, 1.0, 0.15)
	style.shadow_size = 10
	_char_menu.add_theme_stylebox_override("panel", style)
	
	# Compact dimensions side-by-side (fits inside 640x360)
	_char_menu.custom_minimum_size = Vector2(520, 240)
	_char_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_char_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_char_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_char_menu.visible = false
	
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 8)
	margin_container.add_theme_constant_override("margin_right", 8)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	_char_menu.add_child(margin_container)
	
	# Side-by-side HBox layout
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	margin_container.add_child(hbox)
	
	# Left Side: Character Stats & Leveling
	var stats_vbox := VBoxContainer.new()
	stats_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_vbox.add_theme_constant_override("separation", 4)
	stats_vbox.custom_minimum_size = Vector2(235, 0)
	hbox.add_child(stats_vbox)
	
	# Title
	_cm_title = Label.new()
	_cm_title.text = "CHARACTER PROGRESSION"
	_cm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cm_title.add_theme_font_size_override("font_size", 11)
	_cm_title.add_theme_color_override("font_color", Color(0.1, 0.8, 1.0))
	stats_vbox.add_child(_cm_title)
	
	# Info text displaying level, EXP, and skill points
	_cm_info = Label.new()
	_cm_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cm_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cm_info.add_theme_font_size_override("font_size", 9)
	_cm_info.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	stats_vbox.add_child(_cm_info)
	
	# Level Up button
	_cm_level_btn = Button.new()
	_cm_level_btn.custom_minimum_size = Vector2(220, 22)
	_cm_level_btn.add_theme_font_size_override("font_size", 9)
	_cm_level_btn.pressed.connect(_on_cm_level_pressed)
	stats_vbox.add_child(_cm_level_btn)
	
	# Separator line
	var stat_sep := ColorRect.new()
	stat_sep.custom_minimum_size = Vector2(200, 1)
	stat_sep.color = Color(0.1, 0.8, 1.0, 0.2)
	stats_vbox.add_child(stat_sep)
	
	# Stats Upgrades rows VBox
	var upg_list := VBoxContainer.new()
	upg_list.add_theme_constant_override("separation", 3)
	stats_vbox.add_child(upg_list)
	
	# Vigor Upgrade Row
	var vigor_row := HBoxContainer.new()
	vigor_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vigor_row.add_theme_constant_override("separation", 10)
	upg_list.add_child(vigor_row)
	
	_cm_vigor_lbl = Label.new()
	_cm_vigor_lbl.text = "Vigor (+10 Max HP)"
	_cm_vigor_lbl.add_theme_font_size_override("font_size", 9)
	_cm_vigor_lbl.custom_minimum_size = Vector2(165, 0)
	vigor_row.add_child(_cm_vigor_lbl)
	
	_cm_vigor_btn = Button.new()
	_cm_vigor_btn.text = "+"
	_cm_vigor_btn.custom_minimum_size = Vector2(30, 18)
	_cm_vigor_btn.add_theme_font_size_override("font_size", 8)
	_cm_vigor_btn.pressed.connect(func(): _on_upgrade_stat_pressed("hp"))
	vigor_row.add_child(_cm_vigor_btn)
	
	# Haste Upgrade Row
	var haste_row := HBoxContainer.new()
	haste_row.alignment = BoxContainer.ALIGNMENT_CENTER
	haste_row.add_theme_constant_override("separation", 10)
	upg_list.add_child(haste_row)
	
	_cm_haste_lbl = Label.new()
	_cm_haste_lbl.text = "Haste (+8% Move Speed)"
	_cm_haste_lbl.add_theme_font_size_override("font_size", 9)
	_cm_haste_lbl.custom_minimum_size = Vector2(165, 0)
	haste_row.add_child(_cm_haste_lbl)
	
	_cm_haste_btn = Button.new()
	_cm_haste_btn.text = "+"
	_cm_haste_btn.custom_minimum_size = Vector2(30, 18)
	_cm_haste_btn.add_theme_font_size_override("font_size", 8)
	_cm_haste_btn.pressed.connect(func(): _on_upgrade_stat_pressed("speed"))
	haste_row.add_child(_cm_haste_btn)
	
	# Strength Upgrade Row
	var str_row := HBoxContainer.new()
	str_row.alignment = BoxContainer.ALIGNMENT_CENTER
	str_row.add_theme_constant_override("separation", 10)
	upg_list.add_child(str_row)
	
	_cm_strength_lbl = Label.new()
	_cm_strength_lbl.text = "Strength (+10% Bullet Dmg)"
	_cm_strength_lbl.add_theme_font_size_override("font_size", 9)
	_cm_strength_lbl.custom_minimum_size = Vector2(165, 0)
	str_row.add_child(_cm_strength_lbl)
	
	_cm_strength_btn = Button.new()
	_cm_strength_btn.text = "+"
	_cm_strength_btn.custom_minimum_size = Vector2(30, 18)
	_cm_strength_btn.add_theme_font_size_override("font_size", 8)
	_cm_strength_btn.pressed.connect(func(): _on_upgrade_stat_pressed("damage"))
	str_row.add_child(_cm_strength_btn)
	
	# Vertical separator (soft neon cyan line)
	var v_sep := ColorRect.new()
	v_sep.custom_minimum_size = Vector2(1, 180)
	v_sep.color = Color(0.1, 0.8, 1.0, 0.3)
	hbox.add_child(v_sep)
	
	# Right Side: Merchant Shop
	var shop_vbox := VBoxContainer.new()
	shop_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_vbox.add_theme_constant_override("separation", 4)
	shop_vbox.custom_minimum_size = Vector2(235, 0)
	hbox.add_child(shop_vbox)
	
	# Shop Title
	var shop_title := Label.new()
	shop_title.text = "MERCHANT SHOP"
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_title.add_theme_font_size_override("font_size", 11)
	shop_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.1)) # golden merchant theme
	shop_vbox.add_child(shop_title)
	
	var shop_sub := Label.new()
	shop_sub.text = "Spend EXP directly on supplies:"
	shop_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_sub.add_theme_font_size_override("font_size", 8)
	shop_sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	shop_vbox.add_child(shop_sub)
	
	# Shop list VBox
	var shop_list := VBoxContainer.new()
	shop_list.add_theme_constant_override("separation", 3)
	shop_vbox.add_child(shop_list)
	
	# Item 1: Refill Standard Ammo
	var row_std := HBoxContainer.new()
	row_std.alignment = BoxContainer.ALIGNMENT_CENTER
	row_std.add_theme_constant_override("separation", 10)
	shop_list.add_child(row_std)
	
	var std_lbl := Label.new()
	std_lbl.text = "Refill Std (+150 Bullets)"
	std_lbl.add_theme_font_size_override("font_size", 9)
	std_lbl.custom_minimum_size = Vector2(145, 0)
	row_std.add_child(std_lbl)
	
	_cm_ammo_std_btn = Button.new()
	_cm_ammo_std_btn.text = "50 EXP"
	_cm_ammo_std_btn.custom_minimum_size = Vector2(55, 18)
	_cm_ammo_std_btn.add_theme_font_size_override("font_size", 8)
	_cm_ammo_std_btn.pressed.connect(_on_buy_ammo_std_pressed)
	row_std.add_child(_cm_ammo_std_btn)
	
	# Item 2: Refill Special Ammo
	var row_sp := HBoxContainer.new()
	row_sp.alignment = BoxContainer.ALIGNMENT_CENTER
	row_sp.add_theme_constant_override("separation", 10)
	shop_list.add_child(row_sp)
	
	var sp_lbl := Label.new()
	sp_lbl.text = "Refill Special (+30)"
	sp_lbl.add_theme_font_size_override("font_size", 9)
	sp_lbl.custom_minimum_size = Vector2(145, 0)
	row_sp.add_child(sp_lbl)
	
	_cm_ammo_sp_btn = Button.new()
	_cm_ammo_sp_btn.text = "80 EXP"
	_cm_ammo_sp_btn.custom_minimum_size = Vector2(55, 18)
	_cm_ammo_sp_btn.add_theme_font_size_override("font_size", 8)
	_cm_ammo_sp_btn.pressed.connect(_on_buy_ammo_sp_pressed)
	row_sp.add_child(_cm_ammo_sp_btn)
	
	# Item 3: Medkit
	var row_heal := HBoxContainer.new()
	row_heal.alignment = BoxContainer.ALIGNMENT_CENTER
	row_heal.add_theme_constant_override("separation", 10)
	shop_list.add_child(row_heal)
	
	var heal_lbl := Label.new()
	heal_lbl.text = "Medkit Heal (+50 HP)"
	heal_lbl.add_theme_font_size_override("font_size", 9)
	heal_lbl.custom_minimum_size = Vector2(145, 0)
	row_heal.add_child(heal_lbl)
	
	_cm_heal_btn = Button.new()
	_cm_heal_btn.text = "60 EXP"
	_cm_heal_btn.custom_minimum_size = Vector2(55, 18)
	_cm_heal_btn.add_theme_font_size_override("font_size", 8)
	_cm_heal_btn.pressed.connect(_on_buy_heal_pressed)
	row_heal.add_child(_cm_heal_btn)
	
	# Item 4: Hire Zombie Hunter
	var row_hunter := HBoxContainer.new()
	row_hunter.alignment = BoxContainer.ALIGNMENT_CENTER
	row_hunter.add_theme_constant_override("separation", 10)
	shop_list.add_child(row_hunter)
	
	var hunter_lbl := Label.new()
	hunter_lbl.text = "Hire Hunter (zombie killer)"
	hunter_lbl.add_theme_font_size_override("font_size", 9)
	hunter_lbl.custom_minimum_size = Vector2(145, 0)
	row_hunter.add_child(hunter_lbl)
	
	_cm_hire_hunter_btn = Button.new()
	_cm_hire_hunter_btn.text = "120 EXP"
	_cm_hire_hunter_btn.custom_minimum_size = Vector2(55, 18)
	_cm_hire_hunter_btn.add_theme_font_size_override("font_size", 8)
	_cm_hire_hunter_btn.pressed.connect(_on_hire_hunter_pressed)
	row_hunter.add_child(_cm_hire_hunter_btn)
	
	# Item 5: Hire Pacifist Companion
	var row_pacifist := HBoxContainer.new()
	row_pacifist.alignment = BoxContainer.ALIGNMENT_CENTER
	row_pacifist.add_theme_constant_override("separation", 10)
	shop_list.add_child(row_pacifist)
	
	var pacifist_lbl := Label.new()
	pacifist_lbl.text = "Hire Pacifist Companion"
	pacifist_lbl.add_theme_font_size_override("font_size", 9)
	pacifist_lbl.custom_minimum_size = Vector2(145, 0)
	row_pacifist.add_child(pacifist_lbl)
	
	_cm_hire_pacifist_btn = Button.new()
	_cm_hire_pacifist_btn.text = "60 EXP"
	_cm_hire_pacifist_btn.custom_minimum_size = Vector2(55, 18)
	_cm_hire_pacifist_btn.add_theme_font_size_override("font_size", 8)
	_cm_hire_pacifist_btn.pressed.connect(_on_hire_pacifist_pressed)
	row_pacifist.add_child(_cm_hire_pacifist_btn)
	
	# Spacer
	var shop_spacer := Control.new()
	shop_spacer.custom_minimum_size = Vector2(0, 1)
	shop_vbox.add_child(shop_spacer)
	
	# Close button
	_cm_close_btn = Button.new()
	_cm_close_btn.text = "CLOSE MENU [C]"
	_cm_close_btn.custom_minimum_size = Vector2(110, 20)
	_cm_close_btn.add_theme_font_size_override("font_size", 8)
	_cm_close_btn.pressed.connect(close_char_menu)
	shop_vbox.add_child(_cm_close_btn)
	
	# Add to CanvasLayer
	add_child(_char_menu)
	
	# Style the characters page
	UIStyler.style_scene(_char_menu)

func open_char_menu() -> void:
	if not _player or _player.is_dead:
		return
	_char_menu_open = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _crosshair:
		_crosshair.visible = false
	
	_update_char_menu()
	_char_menu.visible = true
	UIStyler.style_scene(_char_menu)

func close_char_menu() -> void:
	_char_menu.visible = false
	_char_menu_open = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if _crosshair:
		_crosshair.visible = true

func _update_char_menu() -> void:
	if not _player or not _char_menu:
		return
	
	# Update Title with Stats information
	_cm_info.text = "LVL %d  |  EXP: %d/%d  |  Skill Points: %d" % [
		Globals.player_level,
		Globals.score,
		Globals.get_next_level_cost(),
		Globals.skill_points
	]
	
	# Upgrade level cost and enable status
	var can_lvl := Globals.check_level_up_available()
	_cm_level_btn.text = "LEVEL UP (Cost: %d EXP)" % Globals.get_next_level_cost()
	_cm_level_btn.disabled = not can_lvl
	
	# Stat upgrade buttons enable state
	var has_sp := Globals.skill_points > 0
	_cm_vigor_btn.disabled = not has_sp
	_cm_haste_btn.disabled = not has_sp
	_cm_strength_btn.disabled = not has_sp
	
	# Show levels in labels
	_cm_vigor_lbl.text = "Vigor: Lv %d (+10 Max HP)" % Globals.hp_stat_level
	_cm_haste_lbl.text = "Haste: Lv %d (+8%% Spd)" % Globals.speed_stat_level
	_cm_strength_lbl.text = "Strength: Lv %d (+10%% Dmg)" % Globals.damage_stat_level
	
	# Merchant buttons status
	_cm_ammo_std_btn.disabled = Globals.score < 50
	_cm_heal_btn.disabled = Globals.score < 60 or _player.health >= _player.max_health
	
	# Count active alive companions
	var active_npcs = 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(npc) and npc.get("npc_name") != null and npc.get("npc_name") != "" and not npc.get("is_dead") and not npc.get("is_hostile_to_player"):
			active_npcs += 1
			
	var current_hunter_cost = 120 + 50 * active_npcs
	var current_pacifist_cost = 60 + 30 * active_npcs
	
	if active_npcs >= 20:
		_cm_hire_hunter_btn.text = "MAX REACHED"
		_cm_hire_hunter_btn.disabled = true
		_cm_hire_pacifist_btn.text = "MAX REACHED"
		_cm_hire_pacifist_btn.disabled = true
	else:
		_cm_hire_hunter_btn.text = "%d EXP" % current_hunter_cost
		_cm_hire_hunter_btn.disabled = Globals.score < current_hunter_cost
		_cm_hire_pacifist_btn.text = "%d EXP" % current_pacifist_cost
		_cm_hire_pacifist_btn.disabled = Globals.score < current_pacifist_cost
	
	# Special ammo can only be refilled if player has a special bullet type active currently (types 1 to 4)
	var special_active: bool = _player.current_bullet_type > 0
	_cm_ammo_sp_btn.disabled = Globals.score < 80 or not special_active

func _on_cm_level_pressed() -> void:
	if Globals.level_up():
		AudioManager.play_upgrade()
		_update_char_menu()

func _on_upgrade_stat_pressed(stat_name: String) -> void:
	if Globals.upgrade_stat(stat_name):
		AudioManager.play_upgrade()
		_update_char_menu()

func _on_buy_ammo_std_pressed() -> void:
	if Globals.score >= 50:
		Globals.score -= 50
		Globals.emit_signal("score_changed", Globals.score)
		if _player:
			_player.bullet_ammo[0] += 150
			_player._notify_bullet_changed()
		AudioManager.play_buy()
		_update_char_menu()

func _on_buy_ammo_sp_pressed() -> void:
	if Globals.score >= 80 and _player and _player.current_bullet_type > 0:
		Globals.score -= 80
		Globals.emit_signal("score_changed", Globals.score)
		_player.bullet_ammo[_player.current_bullet_type] += 30
		_player._notify_bullet_changed()
		AudioManager.play_buy()
		_update_char_menu()

func _on_buy_heal_pressed() -> void:
	if Globals.score >= 60 and _player and _player.health < _player.max_health:
		Globals.score -= 60
		Globals.emit_signal("score_changed", Globals.score)
		_player.heal(50)
		AudioManager.play_buy()
		_update_char_menu()

func _on_hire_hunter_pressed() -> void:
	var active_npcs = 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(npc) and npc.get("npc_name") != null and npc.get("npc_name") != "" and not npc.get("is_dead") and not npc.get("is_hostile_to_player"):
			active_npcs += 1
			
	if active_npcs >= 20:
		return
		
	var current_hunter_cost = 120 + 50 * active_npcs
	if Globals.score >= current_hunter_cost and _player:
		Globals.score -= current_hunter_cost
		Globals.emit_signal("score_changed", Globals.score)
		_spawn_npc("hunter")
		AudioManager.play_buy()
		_update_char_menu()

func _on_hire_pacifist_pressed() -> void:
	var active_npcs = 0
	for npc in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(npc) and npc.get("npc_name") != null and npc.get("npc_name") != "" and not npc.get("is_dead") and not npc.get("is_hostile_to_player"):
			active_npcs += 1
			
	if active_npcs >= 20:
		return
		
	var current_pacifist_cost = 60 + 30 * active_npcs
	if Globals.score >= current_pacifist_cost and _player:
		Globals.score -= current_pacifist_cost
		Globals.emit_signal("score_changed", Globals.score)
		_spawn_npc("pacifist")
		AudioManager.play_buy()
		_update_char_menu()

func _spawn_npc(type: String) -> void:
	var npc_scene = load("res://Scenes/Humans/npc.tscn")
	var npc = npc_scene.instantiate()
	npc.npc_type = type
	
	# Determine safe position: close to player, but far from zombie spawns
	var spawn_pos = _get_safe_spawn_position()
	npc.global_position = spawn_pos
	
	# Add to the level parent of player
	_player.get_parent().add_child(npc)

func _get_safe_spawn_position() -> Vector2:
	if not _player:
		return Vector2.ZERO
		
	# Retrieve zombie spawn points from WaveManager
	var spawn_points = []
	var wm = get_tree().get_root().get_node_or_null("Root/WaveManager")
	if wm:
		spawn_points = wm._spawn_points
		
	# Find the closest zombie spawn point to the player
	var closest_sp = null
	var min_dist = INF
	for sp in spawn_points:
		if is_instance_valid(sp):
			var d = _player.global_position.distance_to(sp.global_position)
			if d < min_dist:
				min_dist = d
				closest_sp = sp
				
	# If we found a spawn point, spawn between player and that spawn point
	if closest_sp:
		var dir = (closest_sp.global_position - _player.global_position).normalized()
		# Spawn at a moderate distance (e.g. 100-150 pixels) towards the spawn
		var dist = clamp(120.0, 50.0, min_dist * 0.6)
		var offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		return _player.global_position + dir * dist + offset
		
	# Fallback: spawn in direction of player's mouse/looking direction
	var look_dir = (_player.get_global_mouse_position() - _player.global_position).normalized()
	return _player.global_position + look_dir * 120.0 + Vector2(randf_range(-15, 15), randf_range(-15, 15))

# ---------------------------------------------------------------------------
# Mercenary Tab / Management Menu
# ---------------------------------------------------------------------------
func _create_merc_menu() -> void:
	_merc_menu = PanelContainer.new()
	_merc_menu.name = "MercenaryMenu"
	
	# Beautiful glassmorphic panel style with neon green border
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.9, 0.4, 0.8) # neon green border
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0.2, 0.9, 0.4, 0.15)
	style.shadow_size = 10
	_merc_menu.add_theme_stylebox_override("panel", style)
	
	_merc_menu.custom_minimum_size = Vector2(520, 240)
	_merc_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_merc_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_merc_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_merc_menu.visible = false
	
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 8)
	margin_container.add_theme_constant_override("margin_right", 8)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	_merc_menu.add_child(margin_container)
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	margin_container.add_child(hbox)
	
	# Left Side: List
	var list_vbox := VBoxContainer.new()
	list_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	list_vbox.add_theme_constant_override("separation", 4)
	list_vbox.custom_minimum_size = Vector2(235, 0)
	hbox.add_child(list_vbox)
	
	var list_title := Label.new()
	list_title.text = "ACTIVE MERCENARIES"
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_title.add_theme_font_size_override("font_size", 11)
	list_title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	list_vbox.add_child(list_title)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230, 160)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_vbox.add_child(scroll)
	
	_merc_list_container = VBoxContainer.new()
	_merc_list_container.add_theme_constant_override("separation", 3)
	scroll.add_child(_merc_list_container)
	
	# Vertical separator
	var v_sep := ColorRect.new()
	v_sep.custom_minimum_size = Vector2(1, 180)
	v_sep.color = Color(0.2, 0.9, 0.4, 0.3)
	hbox.add_child(v_sep)
	
	# Right Side: Bio & Controls
	var details_vbox := VBoxContainer.new()
	details_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	details_vbox.add_theme_constant_override("separation", 4)
	details_vbox.custom_minimum_size = Vector2(235, 0)
	hbox.add_child(details_vbox)
	
	_merc_details_title = Label.new()
	_merc_details_title.text = "SELECT A COMPANION"
	_merc_details_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_merc_details_title.add_theme_font_size_override("font_size", 11)
	_merc_details_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.1))
	details_vbox.add_child(_merc_details_title)
	
	_merc_details_bio = Label.new()
	_merc_details_bio.text = "Select a companion from the list on the left to manage their resources."
	_merc_details_bio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_merc_details_bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_merc_details_bio.add_theme_font_size_override("font_size", 9)
	_merc_details_bio.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
	details_vbox.add_child(_merc_details_bio)
	
	# Health Bar
	_merc_details_hb = ProgressBar.new()
	_merc_details_hb.max_value = 100
	_merc_details_hb.value = 100
	_merc_details_hb.show_percentage = false
	_merc_details_hb.custom_minimum_size = Vector2(220, 6)
	_merc_details_hb.visible = false
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	_merc_details_hb.add_theme_stylebox_override("background", sb_bg)
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = Color(0.2, 1.0, 0.2)
	_merc_details_hb.add_theme_stylebox_override("fill", sb_fg)
	details_vbox.add_child(_merc_details_hb)
	
	_merc_details_weapon = Label.new()
	_merc_details_weapon.add_theme_font_size_override("font_size", 8)
	_merc_details_weapon.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
	_merc_details_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_vbox.add_child(_merc_details_weapon)
	
	_merc_details_bullets = Label.new()
	_merc_details_bullets.add_theme_font_size_override("font_size", 8)
	_merc_details_bullets.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	_merc_details_bullets.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_vbox.add_child(_merc_details_bullets)
	
	# Weapon equip buttons
	var w_lbl := Label.new()
	w_lbl.text = "GIVE WEAPON (deducts 50 bullets):"
	w_lbl.add_theme_font_size_override("font_size", 8)
	w_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	details_vbox.add_child(w_lbl)
	
	var w_hbox := HBoxContainer.new()
	w_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	w_hbox.add_theme_constant_override("separation", 4)
	details_vbox.add_child(w_hbox)
	
	_merc_w1_btn = Button.new()
	_merc_w1_btn.text = "Pistol"
	_merc_w1_btn.custom_minimum_size = Vector2(70, 18)
	_merc_w1_btn.add_theme_font_size_override("font_size", 8)
	_merc_w1_btn.pressed.connect(func(): _on_give_weapon_pressed(0))
	w_hbox.add_child(_merc_w1_btn)
	
	_merc_w2_btn = Button.new()
	_merc_w2_btn.text = "MG"
	_merc_w2_btn.custom_minimum_size = Vector2(70, 18)
	_merc_w2_btn.add_theme_font_size_override("font_size", 8)
	_merc_w2_btn.pressed.connect(func(): _on_give_weapon_pressed(1))
	w_hbox.add_child(_merc_w2_btn)
	
	_merc_w3_btn = Button.new()
	_merc_w3_btn.text = "Silencer"
	_merc_w3_btn.custom_minimum_size = Vector2(70, 18)
	_merc_w3_btn.add_theme_font_size_override("font_size", 8)
	_merc_w3_btn.pressed.connect(func(): _on_give_weapon_pressed(2))
	w_hbox.add_child(_merc_w3_btn)
	
	# Bullet ammo type buttons
	var b_lbl := Label.new()
	b_lbl.text = "GIVE BULLET TYPE (+30 special ammo):"
	b_lbl.add_theme_font_size_override("font_size", 8)
	b_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	details_vbox.add_child(b_lbl)
	
	var b_hbox := HBoxContainer.new()
	b_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	b_hbox.add_theme_constant_override("separation", 3)
	details_vbox.add_child(b_hbox)
	
	_merc_b0_btn = Button.new()
	_merc_b0_btn.text = "Std"
	_merc_b0_btn.custom_minimum_size = Vector2(40, 18)
	_merc_b0_btn.add_theme_font_size_override("font_size", 8)
	_merc_b0_btn.pressed.connect(func(): _on_give_bullet_pressed(0))
	b_hbox.add_child(_merc_b0_btn)
	
	_merc_b1_btn = Button.new()
	_merc_b1_btn.text = "Quick"
	_merc_b1_btn.custom_minimum_size = Vector2(40, 18)
	_merc_b1_btn.add_theme_font_size_override("font_size", 8)
	_merc_b1_btn.pressed.connect(func(): _on_give_bullet_pressed(1))
	b_hbox.add_child(_merc_b1_btn)
	
	_merc_b2_btn = Button.new()
	_merc_b2_btn.text = "Paraly"
	_merc_b2_btn.custom_minimum_size = Vector2(40, 18)
	_merc_b2_btn.add_theme_font_size_override("font_size", 8)
	_merc_b2_btn.pressed.connect(func(): _on_give_bullet_pressed(2))
	b_hbox.add_child(_merc_b2_btn)
	
	_merc_b3_btn = Button.new()
	_merc_b3_btn.text = "Knock"
	_merc_b3_btn.custom_minimum_size = Vector2(40, 18)
	_merc_b3_btn.add_theme_font_size_override("font_size", 8)
	_merc_b3_btn.pressed.connect(func(): _on_give_bullet_pressed(3))
	b_hbox.add_child(_merc_b3_btn)
	
	_merc_b4_btn = Button.new()
	_merc_b4_btn.text = "Slow"
	_merc_b4_btn.custom_minimum_size = Vector2(40, 18)
	_merc_b4_btn.add_theme_font_size_override("font_size", 8)
	_merc_b4_btn.pressed.connect(func(): _on_give_bullet_pressed(4))
	b_hbox.add_child(_merc_b4_btn)
	
	# Close button
	_merc_close_btn = Button.new()
	_merc_close_btn.text = "CLOSE MENU [V]"
	_merc_close_btn.custom_minimum_size = Vector2(110, 20)
	_merc_close_btn.add_theme_font_size_override("font_size", 8)
	_merc_close_btn.pressed.connect(close_merc_menu)
	details_vbox.add_child(_merc_close_btn)
	
	add_child(_merc_menu)
	UIStyler.style_scene(_merc_menu)

func open_merc_menu() -> void:
	if not _player or _player.is_dead:
		return
	_merc_menu_open = true
	_selected_merc = null
	
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _crosshair:
		_crosshair.visible = false
	
	# Select first active friendly companion automatically
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if is_instance_valid(npc) and npc.get("npc_name") != null and npc.get("npc_name") != "" and not npc.get("is_dead") and not npc.get("is_hostile_to_player"):
			_selected_merc = npc
			break
			
	_update_merc_menu()
	_merc_menu.visible = true
	UIStyler.style_scene(_merc_menu)

func close_merc_menu() -> void:
	_merc_menu.visible = false
	_merc_menu_open = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if _crosshair:
		_crosshair.visible = true

func _update_merc_menu() -> void:
	if not _player or not _merc_menu:
		return
		
	# Clear previous list
	for child in _merc_list_container.get_children():
		child.queue_free()
		
	# Populate list of alive friendly companions
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if is_instance_valid(npc) and npc.get("npc_name") != null and npc.get("npc_name") != "" and not npc.get("is_dead") and not npc.get("is_hostile_to_player"):
			var btn := Button.new()
			var npc_type_name = "Hunter" if npc.get("npc_type") == "hunter" else "Pacifist"
			btn.text = "%s (%d%s) - %s" % [
				npc.get("npc_name"), 
				npc.get("npc_age"), 
				"M" if npc.get("npc_gender") == "Male" else "F",
				npc_type_name
			]
			btn.custom_minimum_size = Vector2(220, 22)
			btn.add_theme_font_size_override("font_size", 8)
			
			# Highlight selected
			if npc == _selected_merc:
				btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
				
			btn.pressed.connect(func():
				_selected_merc = npc
				_update_merc_menu()
			)
			_merc_list_container.add_child(btn)
			
	# Update right side details
	if _selected_merc and is_instance_valid(_selected_merc) and not _selected_merc.get("is_dead"):
		var npc = _selected_merc
		_merc_details_title.text = npc.get("npc_name").to_upper()
		var npc_type_name = "Zombie Hunter" if npc.get("npc_type") == "hunter" else "Pacifist Companion"
		_merc_details_bio.text = "%d years old, %s\nClass: %s" % [
			npc.get("npc_age"),
			npc.get("npc_gender"),
			npc_type_name
		]
		
		# Health Bar
		_merc_details_hb.visible = true
		_merc_details_hb.value = npc.get("health")
		_merc_details_hb.max_value = npc.get("max_health")
		
		# Weapon and bullet info
		var w_idx = npc.get("equipped_weapon")
		var w_name = "None"
		if npc.get("has_gun") and w_idx >= 0 and w_idx < _player.WEAPONS.size():
			w_name = _player.WEAPONS[w_idx]["name"]
			
		var b_idx = npc.get("equipped_bullet_type")
		var b_name = _player.BULLET_TYPES[b_idx]["name"]
		
		_merc_details_weapon.text = "EQUIPPED WEAPON: %s" % w_name.to_upper()
		_merc_details_bullets.text = "AMMO: %d/%d (%s BULLETS)" % [npc.get("ammo_count"), npc.get("max_ammo"), b_name.to_upper()]
		
		# Enable/Disable weapon buttons based on player carrying weapon and having ammo
		_merc_w1_btn.disabled = false # Pistol always available
		_merc_w2_btn.disabled = not (1 in _player.carried_weapons) or _player.ammo_remaining[1] <= 0
		_merc_w3_btn.disabled = not (2 in _player.carried_weapons) or _player.ammo_remaining[2] <= 0
		
		# Enable/Disable bullet buttons based on player inventory
		_merc_b0_btn.disabled = _player.bullet_ammo[0] <= 0
		_merc_b1_btn.disabled = _player.bullet_ammo[1] <= 0
		_merc_b2_btn.disabled = _player.bullet_ammo[2] <= 0
		_merc_b3_btn.disabled = _player.bullet_ammo[3] <= 0
		_merc_b4_btn.disabled = _player.bullet_ammo[4] <= 0
	else:
		_selected_merc = null
		_merc_details_title.text = "NO COMPANION SELECTED"
		_merc_details_bio.text = "Hire companions at the progression menu [C], then select them here to manage equipment."
		_merc_details_hb.visible = false
		_merc_details_weapon.text = ""
		_merc_details_bullets.text = ""
		
		_merc_w1_btn.disabled = true
		_merc_w2_btn.disabled = true
		_merc_w3_btn.disabled = true
		
		_merc_b0_btn.disabled = true
		_merc_b1_btn.disabled = true
		_merc_b2_btn.disabled = true
		_merc_b3_btn.disabled = true
		_merc_b4_btn.disabled = true

func _on_give_weapon_pressed(weapon_idx: int) -> void:
	if not _selected_merc or not is_instance_valid(_selected_merc) or not _player:
		return
		
	var npc = _selected_merc
	var player_ammo = 0
	if weapon_idx == 0:
		player_ammo = _player.bullet_ammo[0]
	elif weapon_idx == 1:
		player_ammo = _player.ammo_remaining[1]
	elif weapon_idx == 2:
		player_ammo = _player.ammo_remaining[2]
		
	var transfer = min(50, player_ammo)
	if transfer <= 0 and weapon_idx > 0:
		return
		
	# Deduct from player
	if weapon_idx == 0:
		_player.bullet_ammo[0] -= transfer
	elif weapon_idx == 1:
		_player.ammo_remaining[1] -= transfer
	elif weapon_idx == 2:
		_player.ammo_remaining[2] -= transfer
		
	# Equip on NPC
	npc.set("has_gun", true)
	npc.set("equipped_weapon", weapon_idx)
	npc.set("ammo_count", transfer)
	
	# Update player HUD
	_player.emit_signal("ammo_changed", _player.ammo_remaining[_player.current_weapon_index])
	_player.emit_signal("bullet_changed", _player.BULLET_TYPES[_player.current_bullet_type]["name"], _player.bullet_ammo[_player.current_bullet_type])
	_player._notify_bullet_changed()
	
	AudioManager.play_buy()
	_update_merc_menu()

func _on_give_bullet_pressed(bullet_idx: int) -> void:
	if not _selected_merc or not is_instance_valid(_selected_merc) or not _player:
		return
		
	var npc = _selected_merc
	var player_ammo = _player.bullet_ammo[bullet_idx]
	if player_ammo <= 0:
		return
		
	# Determine transfer amount
	var need = npc.get("max_ammo") - npc.get("ammo_count")
	if need <= 0:
		need = 30 # standard transfer chunk
	var transfer = min(need, player_ammo)
	
	if transfer > 0:
		# Deduct from player
		_player.bullet_ammo[bullet_idx] -= transfer
		# Transfer to NPC
		npc.set("equipped_bullet_type", bullet_idx)
		npc.set("ammo_count", min(npc.get("max_ammo"), npc.get("ammo_count") + transfer))
		
		# Update player HUD
		_player.emit_signal("bullet_changed", _player.BULLET_TYPES[_player.current_bullet_type]["name"], _player.bullet_ammo[_player.current_bullet_type])
		_player._notify_bullet_changed()
		
		AudioManager.play_buy()
		_update_merc_menu()
