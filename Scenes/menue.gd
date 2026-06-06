extends Control

@onready var vbox: VBoxContainer = $VBoxContainer
var _lore_panel: Panel = null
var _keybinds_popup: PanelContainer = null

func _ready() -> void:
	# Check if a save exists to offer Continue Progress
	if Globals.has_save_file():
		var continue_btn := Button.new()
		continue_btn.text = "CONTINUE"
		continue_btn.tooltip_text = "Continue progress from Wave %d with all upgrades." % Globals.current_wave
		continue_btn.add_theme_font_size_override("font_size", 30)
		continue_btn.add_theme_stylebox_override("normal", preload("res://btn styles/menue buttons.tres"))
		vbox.add_child(continue_btn)
		vbox.move_child(continue_btn, 0)
		continue_btn.pressed.connect(_on_continue_pressed)
		
	# Add Settings button
	var settings_btn := Button.new()
	settings_btn.text = "SETTINGS"
	settings_btn.tooltip_text = "Configure volume, control binds, and check the Zombie Directory."
	settings_btn.add_theme_font_size_override("font_size", 30)
	settings_btn.add_theme_stylebox_override("normal", preload("res://btn styles/menue buttons.tres"))
	vbox.add_child(settings_btn)
	
	# Keep QUIT at the very bottom
	var quit_btn = $VBoxContainer/Button3
	if quit_btn:
		vbox.move_child(settings_btn, vbox.get_child_count() - 2)
		vbox.move_child(quit_btn, vbox.get_child_count() - 1)
		
	settings_btn.pressed.connect(_on_settings_pressed)
	
	# ---------------------------------------------------------------------------
	# Cinematic Background Effects & Darkening
	# ---------------------------------------------------------------------------
	var bg = get_node_or_null("Background")
	if bg:
		# Darken the background image with a cold/ash tint
		bg.modulate = Color(0.22, 0.22, 0.25, 1.0)
		
		# Add a subtle vignette overlay to focus visual attention on the center UI
		var vignette_style := StyleBoxFlat.new()
		vignette_style.bg_color = Color(0, 0, 0, 0)
		vignette_style.border_width_left = 80
		vignette_style.border_width_top = 80
		vignette_style.border_width_right = 80
		vignette_style.border_width_bottom = 80
		vignette_style.border_color = Color(0.01, 0.01, 0.02, 0.85)
		vignette_style.border_blend = true
		
		var vignette_panel := Panel.new()
		vignette_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vignette_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vignette_panel.add_theme_stylebox_override("panel", vignette_style)
		add_child(vignette_panel)
		move_child(vignette_panel, 1) # Position right above the background
		
		# Add premium cinematic rising red embers (glowing ashes)
		var embers := CPUParticles2D.new()
		embers.position = Vector2(320, 370)
		embers.amount = 35
		embers.lifetime = 6.0
		embers.preprocess = 5.0
		embers.speed_scale = 0.75
		embers.randomness = 1.0
		embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		embers.emission_rect_extents = Vector2(320, 10)
		embers.direction = Vector2(0.2, -1.0)
		embers.spread = 30.0
		embers.gravity = Vector2(0, -6.0)
		embers.initial_velocity_min = 30.0
		embers.initial_velocity_max = 70.0
		embers.scale_amount_min = 2.0
		embers.scale_amount_max = 5.0
		
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([
			Color(1.0, 0.38, 0.1, 0.95),
			Color(0.85, 0.15, 0.02, 0.7),
			Color(0.25, 0.25, 0.25, 0.0)
		])
		embers.color_ramp = ramp
		
		add_child(embers)
		move_child(embers, 2) # Position above vignette, below labels
	
	UIStyler.style_scene(self)

# ---------------------------------------------------------------------------
# Button Actions
# ---------------------------------------------------------------------------
func _on_button_pressed() -> void:
	# PLAY / NEW GAME
	AudioManager.play_click()
	open_map_selection()

func _on_continue_pressed() -> void:
	# CONTINUE GAME
	Globals.load_save()
	Globals.is_continuing_game = true
	SceneTransition.fade_to("res://Scenes/root.tscn")

func _on_button_2_pressed() -> void:
	# TRUTH (LORE MENU)
	AudioManager.play_click()
	open_lore_menu()

func _on_button_3_pressed() -> void:
	# QUIT
	get_tree().quit()

# ---------------------------------------------------------------------------
# Settings Popup UI
# ---------------------------------------------------------------------------
func _on_settings_pressed() -> void:
	var settings = preload("res://Scenes/UI/settings_menu.tscn").instantiate()
	add_child(settings)

# ---------------------------------------------------------------------------
# Lore Archive Menu UI
# ---------------------------------------------------------------------------
func open_lore_menu() -> void:
	if _lore_panel:
		_lore_panel.queue_free()
		
	_lore_panel = Panel.new()
	_lore_panel.name = "LoreMenu"
	_lore_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.1, 0.8, 1.0, 0.5)
	_lore_panel.add_theme_stylebox_override("panel", style)
	add_child(_lore_panel)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	main_vbox.layout_mode = 1
	main_vbox.offset_left = 20
	main_vbox.offset_top = 15
	main_vbox.offset_right = -20
	main_vbox.offset_bottom = -15
	_lore_panel.add_child(main_vbox)
	
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	var title := Label.new()
	title.text = "THE ARCHIVE OF TRUTH"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.1))
	header_hbox.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = " — Recovered Logs"
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header_hbox.add_child(subtitle)
	
	# Discovery Progress Bar & Label
	var progress_hbox := HBoxContainer.new()
	progress_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(progress_hbox)
	
	var total_frags := Globals.LORE_FRAGMENTS.size()
	var disc_frags := Globals.discovered_lore.size()
	var pct := 0.0
	if total_frags > 0:
		pct = (float(disc_frags) / float(total_frags)) * 100.0
		
	var progress_lbl := Label.new()
	progress_lbl.text = "DISCOVERY: %d%% (%d/%d)" % [pct, disc_frags, total_frags]
	progress_lbl.add_theme_font_size_override("font_size", 9)
	progress_lbl.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	progress_hbox.add_child(progress_lbl)
	
	var progress_bar := ProgressBar.new()
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = pct
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(150, 6)
	progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.01, 0.03, 0.06, 0.9)
	pb_bg.border_width_left = 1
	pb_bg.border_width_top = 1
	pb_bg.border_width_right = 1
	pb_bg.border_width_bottom = 1
	pb_bg.border_color = Color(0.0, 0.8, 1.0, 0.15)
	pb_bg.corner_radius_top_left = 2
	pb_bg.corner_radius_top_right = 2
	pb_bg.corner_radius_bottom_left = 2
	pb_bg.corner_radius_bottom_right = 2
	
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color(0.0, 0.8, 1.0, 0.8)
	pb_fill.corner_radius_top_left = 2
	pb_fill.corner_radius_top_right = 2
	pb_fill.corner_radius_bottom_left = 2
	pb_fill.corner_radius_bottom_right = 2
	
	progress_bar.add_theme_stylebox_override("background", pb_bg)
	progress_bar.add_theme_stylebox_override("fill", pb_fill)
	progress_hbox.add_child(progress_bar)
	
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 15)
	main_vbox.add_child(content_hbox)
	
	# Truth Web: Three Columns Layout with ScrollContainer to prevent overflow
	var web_scroll := ScrollContainer.new()
	web_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	web_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	web_scroll.size_flags_stretch_ratio = 1.4
	web_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	web_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_hbox.add_child(web_scroll)
	
	var web_hbox := HBoxContainer.new()
	web_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	web_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	web_hbox.add_theme_constant_override("separation", 15)
	web_scroll.add_child(web_hbox)
	
	# Column 1: Implanted Memories (Red)
	var col_implanted := VBoxContainer.new()
	col_implanted.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_implanted.custom_minimum_size = Vector2(110, 0)
	col_implanted.add_theme_constant_override("separation", 6)
	web_hbox.add_child(col_implanted)
	
	var lbl_implanted := Label.new()
	lbl_implanted.text = "IMPLANTED"
	lbl_implanted.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_implanted.add_theme_font_size_override("font_size", 10)
	lbl_implanted.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	col_implanted.add_child(lbl_implanted)
	
	# Column 2: Giant Heritage (Gold)
	var col_heritage := VBoxContainer.new()
	col_heritage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_heritage.custom_minimum_size = Vector2(110, 0)
	col_heritage.add_theme_constant_override("separation", 6)
	web_hbox.add_child(col_heritage)
	
	var lbl_heritage := Label.new()
	lbl_heritage.text = "GIANT"
	lbl_heritage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_heritage.add_theme_font_size_override("font_size", 10)
	lbl_heritage.add_theme_color_override("font_color", Color(1.0, 0.8, 0.1))
	col_heritage.add_child(lbl_heritage)
	
	# Column 3: World Lore (Blue)
	var col_world := VBoxContainer.new()
	col_world.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_world.custom_minimum_size = Vector2(110, 0)
	col_world.add_theme_constant_override("separation", 6)
	web_hbox.add_child(col_world)
	
	var lbl_world := Label.new()
	lbl_world.text = "WORLD"
	lbl_world.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_world.add_theme_font_size_override("font_size", 10)
	lbl_world.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	col_world.add_child(lbl_world)
	
	# Reader Panel (Right) removed in favor of popup modal

	for i in range(Globals.LORE_FRAGMENTS.size()):
		var frag = Globals.LORE_FRAGMENTS[i]
		var is_disc = Globals.discovered_lore.has(frag["id"])
		var category = frag.get("category", "world")
		
		# Choose target column
		var target_col: VBoxContainer = col_world
		var theme_color := Color(0.0, 0.8, 1.0)
		var dim_color := Color(0.1, 0.4, 0.6, 0.4)
		if category == "implanted":
			target_col = col_implanted
			theme_color = Color(1.0, 0.25, 0.25)
			dim_color = Color(0.6, 0.1, 0.1, 0.4)
		elif category == "heritage":
			target_col = col_heritage
			theme_color = Color(1.0, 0.8, 0.1)
			dim_color = Color(0.5, 0.4, 0.05, 0.4)
			
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 24)
		btn.add_theme_font_size_override("font_size", 8)
		
		# Custom normal, hover, pressed styling for dynamic visual feedback
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.01, 0.03, 0.05, 0.95)
		btn_style.border_width_left = 1
		btn_style.border_width_top = 1
		btn_style.border_width_right = 1
		btn_style.border_width_bottom = 1
		btn_style.border_color = theme_color if is_disc else dim_color
		btn_style.corner_radius_top_left = 2
		btn_style.corner_radius_top_right = 2
		btn_style.corner_radius_bottom_left = 2
		btn_style.corner_radius_bottom_right = 2
		btn.add_theme_stylebox_override("normal", btn_style)
		
		var hover_style := btn_style.duplicate()
		hover_style.border_color = theme_color * 1.3
		btn.add_theme_stylebox_override("hover", hover_style)
		
		if is_disc:
			btn.text = frag["title"]
			btn.add_theme_color_override("font_color", theme_color)
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.pressed.connect(func():
				AudioManager.play_click()
				_open_lore_popup(frag, theme_color)
			)
		else:
			btn.text = "[ PAGE %d ]" % [i + 1]
			btn.disabled = true
			btn.add_theme_color_override("font_disabled_color", dim_color)
		
		target_col.add_child(btn)
	
	# Unlocked Endings Section
	var endings_vbox := VBoxContainer.new()
	endings_vbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(endings_vbox)
	
	var endings_label := Label.new()
	endings_label.text = "UNLOCKED ENDINGS"
	endings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	endings_label.add_theme_font_size_override("font_size", 11)
	endings_label.add_theme_color_override("font_color", Color(1.0, 0.4, 1.0))
	endings_vbox.add_child(endings_label)
	
	var endings_hbox := HBoxContainer.new()
	endings_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	endings_hbox.add_theme_constant_override("separation", 16)
	endings_vbox.add_child(endings_hbox)
	
	var all_endings = ["Destroy", "Absorb", "Seal", "Veil's End"]
	for end_name in all_endings:
		var end_lbl := Label.new()
		end_lbl.add_theme_font_size_override("font_size", 9)
		if Globals.unlocked_endings.has(end_name):
			end_lbl.text = "[ %s ]" % end_name.to_upper()
			if end_name == "Destroy":
				end_lbl.add_theme_color_override("font_color", Color(0.85, 0.1, 0.1))
			elif end_name == "Absorb":
				end_lbl.add_theme_color_override("font_color", Color(0.8, 0.1, 0.8))
			elif end_name == "Seal":
				end_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			elif end_name == "Veil's End":
				end_lbl.add_theme_color_override("font_color", Color(0.1, 0.8, 0.9))
		else:
			end_lbl.text = "[ ??? ]"
			end_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		endings_hbox.add_child(end_lbl)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "RETURN TO TITLE"
	back_btn.custom_minimum_size = Vector2(120, 24)
	back_btn.add_theme_font_size_override("font_size", 10)
	back_btn.pressed.connect(func():
		AudioManager.play_click()
		_lore_panel.queue_free()
		_lore_panel = null
	)
	main_vbox.add_child(back_btn)
	
	UIStyler.style_scene(_lore_panel)

# ---------------------------------------------------------------------------
# Map Selection Popup UI
# ---------------------------------------------------------------------------
var _map_panel: Panel = null

func open_map_selection() -> void:
	if _map_panel:
		_map_panel.queue_free()
		
	_map_panel = Panel.new()
	_map_panel.name = "MapSelectionMenu"
	_map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.07, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.2, 0.8, 0.6) # Magenta neon border
	_map_panel.add_theme_stylebox_override("panel", style)
	add_child(_map_panel)
	
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	main_vbox.layout_mode = 1
	main_vbox.offset_left = 20
	main_vbox.offset_top = 15
	main_vbox.offset_right = -20
	main_vbox.offset_bottom = -15
	_map_panel.add_child(main_vbox)
	
	# Title
	var title := Label.new()
	title.text = "SELECT SURVIVAL DEPLOYMENT ZONE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.6)) # Neon pink
	main_vbox.add_child(title)
	
	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Choose your combat grounds. Subterranean environments activate heavy sensory echoes."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	main_vbox.add_child(subtitle)
	
	# Map Columns
	var maps_hbox := HBoxContainer.new()
	maps_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	maps_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(maps_hbox)
	
	var maps = [
		{
			"name": "SOVEREIGN RUINS",
			"desc": "The open graveyard surrounding the giant prince's empty sarcophagus.\n\n• Standard outdoor arena\n• Dry acoustics\n• Recommended for beginners",
			"path": "res://Scenes/Locations/map_1.tscn",
			"color": Color(0.2, 0.8, 1.0)
		},
		{
			"name": "CEMETERY HILLS",
			"desc": "A sprawling maze of tombstones, memorials, and ancient brick crypts.\n\n• Spooky outdoor acoustics\n• Maze-like line of sight\n• Plenty of cover to hide/dodge",
			"path": "res://Scenes/Locations/cemetery_hills.tscn",
			"color": Color(0.2, 1.0, 0.4)
		},
		{
			"name": "SUBWAY TUNNELS",
			"desc": "Damp subterranean train tunnels and narrow concrete corridors.\n\n• Tight bottleneck spaces\n• Harder to dodge cyborgs/bombers\n• Active Echo Filter (Heavy Reverb)",
			"path": "res://Scenes/Locations/subway_tunnels.tscn",
			"color": Color(1.0, 0.8, 0.2)
		}
	]
	
	for m in maps:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.04, 0.06, 0.1, 0.85)
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = m["color"] * 0.4
		card_style.corner_radius_top_left = 4
		card_style.corner_radius_top_right = 4
		card_style.corner_radius_bottom_left = 4
		card_style.corner_radius_bottom_right = 4
		card.add_theme_stylebox_override("panel", card_style)
		maps_hbox.add_child(card)
		
		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 8)
		
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)
		margin.add_child(card_vbox)
		
		var map_title := Label.new()
		map_title.text = m["name"]
		map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		map_title.add_theme_font_size_override("font_size", 11)
		map_title.add_theme_color_override("font_color", m["color"])
		card_vbox.add_child(map_title)
		
		# Split Separator
		var separator := TextureRect.new()
		separator.texture = load("res://Last Stand Assets/UI/ui_split.png")
		separator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		separator.ignore_texture_size = true
		separator.custom_minimum_size = Vector2(0, 10)
		separator.modulate = m["color"]
		card_vbox.add_child(separator)
		
		var map_desc := Label.new()
		map_desc.text = m["desc"]
		map_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		map_desc.add_theme_font_size_override("font_size", 8)
		map_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		map_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_vbox.add_child(map_desc)
		
		# Check locks
		var is_locked := false
		var lock_msg := ""
		if m["path"] == "res://Scenes/Locations/cemetery_hills.tscn":
			var count = Globals.zone1_bosses_defeated.size()
			if count < 2:
				is_locked = true
				lock_msg = "LOCKED: Defeat 2 unique bosses in Sovereign Ruins (%d/2)" % count
		elif m["path"] == "res://Scenes/Locations/subway_tunnels.tscn":
			var count1 = Globals.zone1_bosses_defeated.size()
			var count2 = Globals.zone2_bosses_defeated.size()
			if count1 < 2 or count2 < 2:
				is_locked = true
				var z1_status = "%d/2" % count1
				var z2_status = "%d/2" % count2
				lock_msg = "LOCKED: Defeat unique bosses in Sovereign Ruins (%s) & Cemetery Hills (%s)" % [z1_status, z2_status]

		var select_btn := Button.new()
		select_btn.text = "LOCKED" if is_locked else "DEPLOY"
		select_btn.disabled = is_locked
		select_btn.custom_minimum_size = Vector2(0, 22)
		select_btn.add_theme_font_size_override("font_size", 9)
		
		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = m["color"] * 0.15
		btn_normal.border_width_left = 1
		btn_normal.border_width_top = 1
		btn_normal.border_width_right = 1
		btn_normal.border_width_bottom = 1
		btn_normal.border_color = m["color"]
		select_btn.add_theme_stylebox_override("normal", btn_normal)
		
		var btn_hover := btn_normal.duplicate()
		btn_hover.bg_color = m["color"] * 0.3
		select_btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_disabled := btn_normal.duplicate()
		btn_disabled.bg_color = Color(0.1, 0.1, 0.1, 0.5)
		btn_disabled.border_color = Color(0.2, 0.2, 0.2, 0.5)
		select_btn.add_theme_stylebox_override("disabled", btn_disabled)
		
		if not is_locked:
			select_btn.pressed.connect(func():
				AudioManager.play_click()
				Globals.selected_map = m["path"]
				Globals.reset()
				SceneTransition.fade_to("res://Scenes/root.tscn")
			)
		
		card_vbox.add_child(select_btn)

		if is_locked:
			card.modulate = Color(0.65, 0.65, 0.65, 0.95)
			var lock_lbl := Label.new()
			lock_lbl.text = lock_msg
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			lock_lbl.add_theme_font_size_override("font_size", 7)
			lock_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			card_vbox.add_child(lock_lbl)
		
	# Back Button
	var back_btn2 := Button.new()
	back_btn2.text = "RETURN TO TITLE"
	back_btn2.custom_minimum_size = Vector2(120, 22)
	back_btn2.add_theme_font_size_override("font_size", 9)
	back_btn2.pressed.connect(func():
		AudioManager.play_click()
		_map_panel.queue_free()
		_map_panel = null
	)
	main_vbox.add_child(back_btn2)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	UIStyler.style_scene(_map_panel)

func _open_lore_popup(frag: Dictionary, theme_color: Color) -> void:
	# Create overlay background to dim the rest of the screen
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.0, 0.0, 0.0, 0.75) # Dimmed semi-transparent background
	overlay.add_theme_stylebox_override("panel", overlay_style)
	_lore_panel.add_child(overlay)
	
	# Center container to position popup
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	# Popup window container
	var popup_card := PanelContainer.new()
	popup_card.custom_minimum_size = Vector2(340, 240)
	
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.02, 0.04, 0.08, 0.98) # Dark aesthetic glassmorphism
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = theme_color
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_left = 6
	card_style.corner_radius_bottom_right = 6
	card_style.content_margin_left = 16
	card_style.content_margin_top = 16
	card_style.content_margin_right = 16
	card_style.content_margin_bottom = 16
	popup_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(popup_card)
	
	# Layout inside card
	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 12)
	popup_card.add_child(card_vbox)
	
	# Header
	var title_lbl := Label.new()
	title_lbl.text = frag["title"].to_upper()
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", theme_color)
	card_vbox.add_child(title_lbl)
	
	# Split Separator
	var separator := TextureRect.new()
	separator.texture = load("res://Last Stand Assets/UI/ui_split.png")
	separator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	separator.ignore_texture_size = true
	separator.custom_minimum_size = Vector2(0, 10)
	separator.modulate = theme_color
	card_vbox.add_child(separator)
	
	# Dialogue/Body Scroll
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(body_scroll)
	
	var body_vbox := VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", 6)
	body_scroll.add_child(body_vbox)
	
	for line in frag["dialogue"]:
		var line_lbl := Label.new()
		line_lbl.text = "%s:\n\"%s\"\n" % [line["speaker"], line["text"]]
		line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		line_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line_lbl.add_theme_font_size_override("font_size", 8)
		line_lbl.add_theme_color_override("font_color", line.get("color", Color(0.8, 0.8, 0.8)))
		body_vbox.add_child(line_lbl)
		
	# Close button
	var close_btn := Button.new()
	close_btn.text = "DISMISS"
	close_btn.custom_minimum_size = Vector2(80, 22)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 9)
	
	var close_btn_style := StyleBoxFlat.new()
	close_btn_style.bg_color = theme_color * 0.15
	close_btn_style.border_width_left = 1
	close_btn_style.border_width_top = 1
	close_btn_style.border_width_right = 1
	close_btn_style.border_width_bottom = 1
	close_btn_style.border_color = theme_color
	close_btn_style.corner_radius_top_left = 3
	close_btn_style.corner_radius_top_right = 3
	close_btn_style.corner_radius_bottom_left = 3
	close_btn_style.corner_radius_bottom_right = 3
	close_btn.add_theme_stylebox_override("normal", close_btn_style)
	
	var close_btn_hover := close_btn_style.duplicate()
	close_btn_hover.bg_color = theme_color * 0.3
	close_btn.add_theme_stylebox_override("hover", close_btn_hover)
	
	close_btn.pressed.connect(func():
		AudioManager.play_click()
		overlay.queue_free()
	)
	card_vbox.add_child(close_btn)
