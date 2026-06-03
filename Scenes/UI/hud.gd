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
var _is_paused: bool = false
var _next_wave_timer_label: Label = null
var bullet_label: Label = null
var _crosshair_scene := preload("res://Scenes/UI/crosshair.tscn")
var _crosshair: Control = null

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
		var sep := Label.new()
		sep.text = "  |  "
		sep.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		bottom_row.add_child(sep)
		
		bullet_label = Label.new()
		bullet_label.name = "BulletLabel"
		bullet_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
		bullet_label.add_theme_font_size_override("font_size", 14)
		bullet_label.text = "Bullet: STANDARD"
		bottom_row.add_child(bullet_label)

	Globals.score_changed.connect(_on_score_changed)
	Globals.wave_changed.connect(_on_wave_changed)
	Globals.combo_changed.connect(_on_combo_changed)

	# Instantiate and add crosshair
	_crosshair = _crosshair_scene.instantiate()
	add_child(_crosshair)

	_create_weapon_menu()

	await get_tree().process_frame

	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.health_changed.connect(_on_health_changed)
		_player.weapon_changed.connect(_on_weapon_changed)
		_player.ammo_changed.connect(_on_ammo_changed)
		_player.bullet_changed.connect(_on_bullet_changed)
		if _player.has_signal("weapon_fired"):
			_player.weapon_fired.connect(_on_weapon_fired)
		_on_health_changed(_player.health, _player.max_health)
		_on_bullet_changed(_player.BULLET_TYPES[_player.current_bullet_type]["name"], _player.bullet_ammo[_player.current_bullet_type])

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
		_is_paused = !_is_paused
		get_tree().paused = _is_paused
		pause_menu.visible = _is_paused
	
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		if _player and not _player.is_dead and not _is_paused:
			if _weapon_menu_open:
				close_weapon_menu()
			else:
				open_weapon_switch_menu()


func _process(delta: float) -> void:
	# Damage flash
	if _flash_timer > 0.0:
		_flash_timer -= delta
		damage_flash.modulate.a = _flash_timer / 0.3
	else:
		damage_flash.modulate.a = 0.0
	# Vignette: pulse red at low health
	if _vignette_mat and _player and not _player.is_dead:
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
	score_label.text = "SCORE  %06d" % new_score

func _on_wave_changed(new_wave: int) -> void:
	wave_label.text = "WAVE  %d" % new_wave

func _on_weapon_changed(weapon_name: String, _ammo: int) -> void:
	weapon_label.text = weapon_name.to_upper()
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
	if bullet_label:
		bullet_label.text = "Bullet: %s" % bullet_name.to_upper()
		
		# Set text color based on bullet type
		var colors = {
			"Standard": Color(1.0, 0.9, 0.0),
			"Quick": Color(0.1, 0.6, 1.0),
			"Paralysis": Color(0.7, 0.1, 1.0),
			"Knockback": Color(0.1, 0.9, 0.1),
			"Slow Down": Color(0.3, 0.9, 1.0)
		}
		var col: Color = colors.get(bullet_name, Color(1.0, 1.0, 1.0))
		bullet_label.add_theme_color_override("font_color", col)
		
		if ammo_label:
			var ammo_str = "∞" if ammo == -1 else str(ammo)
			ammo_label.text = ammo_str
			ammo_label.add_theme_color_override("font_color", col)

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
	
	# Compact dimensions side-by-side
	_weapon_menu.custom_minimum_size = Vector2(650, 310)
	_weapon_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_weapon_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_weapon_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_weapon_menu.visible = false
	
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 14)
	margin_container.add_theme_constant_override("margin_right", 14)
	margin_container.add_theme_constant_override("margin_top", 14)
	margin_container.add_theme_constant_override("margin_bottom", 14)
	_weapon_menu.add_child(margin_container)
	
	# Side-by-side HBox layout
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	margin_container.add_child(hbox)
	
	# Left Side: Weapon Selection
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(280, 0)
	hbox.add_child(vbox)
	
	# Title
	_wm_title = Label.new()
	_wm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wm_title.add_theme_font_size_override("font_size", 16)
	_wm_title.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	vbox.add_child(_wm_title)
	
	# Description
	_wm_desc = Label.new()
	_wm_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wm_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wm_desc.add_theme_font_size_override("font_size", 12)
	_wm_desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.82))
	vbox.add_child(_wm_desc)

	# Stats / Weapon Description Label
	_wm_stats = Label.new()
	_wm_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wm_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wm_stats.add_theme_font_size_override("font_size", 10)
	_wm_stats.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2)) # Sleek yellow
	vbox.add_child(_wm_stats)
	
	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(spacer)
	
	# Button VBox for slots
	var btn_vbox := VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_vbox)
	
	# Slot 1 button
	_wm_slot1_btn = Button.new()
	_wm_slot1_btn.custom_minimum_size = Vector2(260, 36)
	_wm_slot1_btn.pressed.connect(_on_wm_slot1_pressed)
	btn_vbox.add_child(_wm_slot1_btn)
	
	# Slot 2 button
	_wm_slot2_btn = Button.new()
	_wm_slot2_btn.custom_minimum_size = Vector2(260, 36)
	_wm_slot2_btn.pressed.connect(_on_wm_slot2_pressed)
	btn_vbox.add_child(_wm_slot2_btn)
	
	# Spacer
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 2)
	vbox.add_child(spacer2)
	
	# Close/Cancel button
	_wm_close_btn = Button.new()
	_wm_close_btn.custom_minimum_size = Vector2(140, 28)
	_wm_close_btn.pressed.connect(_on_wm_close_pressed)
	vbox.add_child(_wm_close_btn)
	
	# Vertical separator (soft neon red line)
	var v_sep := ColorRect.new()
	v_sep.custom_minimum_size = Vector2(2, 230)
	v_sep.color = Color(0.85, 0.05, 0.05, 0.3)
	hbox.add_child(v_sep)
	
	# Right Side: Bullet Legend
	var legend_vbox := VBoxContainer.new()
	legend_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	legend_vbox.add_theme_constant_override("separation", 8)
	legend_vbox.custom_minimum_size = Vector2(290, 0)
	hbox.add_child(legend_vbox)
	
	# Title of Legend
	var legend_title := Label.new()
	legend_title.text = "BULLET EFFECT LEGEND"
	legend_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend_title.add_theme_font_size_override("font_size", 13)
	legend_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	legend_vbox.add_child(legend_title)
	
	# Separator line under title
	var legend_line := ColorRect.new()
	legend_line.custom_minimum_size = Vector2(240, 1.5)
	legend_line.color = Color(0.3, 0.3, 0.35, 0.5)
	legend_vbox.add_child(legend_line)
	
	# Legend rows VBox
	var legend_list := VBoxContainer.new()
	legend_list.add_theme_constant_override("separation", 4)
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
		row.add_theme_constant_override("separation", 8)
		legend_list.add_child(row)
		
		# Bullet Indicator Dot "●"
		var bullet_dot := Label.new()
		bullet_dot.text = "●"
		bullet_dot.add_theme_font_size_override("font_size", 14)
		bullet_dot.add_theme_color_override("font_color", leg["color"])
		row.add_child(bullet_dot)
		
		var text_vbox := VBoxContainer.new()
		text_vbox.add_theme_constant_override("separation", 1)
		row.add_child(text_vbox)
		
		var name_lbl := Label.new()
		name_lbl.text = leg["name"]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", leg["color"])
		text_vbox.add_child(name_lbl)
		_legend_labels.append(name_lbl)
		
		var desc_lbl := Label.new()
		desc_lbl.text = leg["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(230, 0)
		desc_lbl.add_theme_font_size_override("font_size", 9)
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
