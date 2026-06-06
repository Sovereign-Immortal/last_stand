extends CanvasLayer

var _current_tab: String = "audio"

# UI Node References
var _panel: PanelContainer
var _left_vbox: VBoxContainer
var _content_panel: PanelContainer
var _content_scroll: ScrollContainer
var _content_vbox: VBoxContainer

func _ready() -> void:
	# Keep layer high to render on top of HUD and paused overlays
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_setup_ui()
	_show_tab("audio")
	UIStyler.style_scene(_panel)

func _setup_ui() -> void:
	# Main full screen color overlay to dim the background
	var dim_rect := ColorRect.new()
	dim_rect.color = Color(0, 0, 0, 0.6)
	dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim_rect)
	
	# Center settings container
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(540, 300)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left = -270
	_panel.offset_top = -150
	_panel.offset_right = 270
	_panel.offset_bottom = 150
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.1, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.8, 1.0, 0.5)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 15)
	_panel.add_child(main_hbox)
	
	# Left Menu Sidebar (width 140)
	_left_vbox = VBoxContainer.new()
	_left_vbox.custom_minimum_size = Vector2(130, 0)
	_left_vbox.add_theme_constant_override("separation", 8)
	_left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_hbox.add_child(_left_vbox)
	
	var settings_lbl := Label.new()
	settings_lbl.text = "SETTINGS"
	settings_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_lbl.add_theme_font_size_override("font_size", 14)
	settings_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.1))
	_left_vbox.add_child(settings_lbl)
	
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 4)
	_left_vbox.add_child(spacer1)
	
	var btn_audio := Button.new()
	btn_audio.text = "AUDIO"
	btn_audio.add_theme_font_size_override("font_size", 9)
	btn_audio.pressed.connect(func(): _show_tab("audio"))
	_left_vbox.add_child(btn_audio)
	
	var btn_ctrl := Button.new()
	btn_ctrl.text = "CONTROLS"
	btn_ctrl.add_theme_font_size_override("font_size", 9)
	btn_ctrl.pressed.connect(func(): _show_tab("controls"))
	_left_vbox.add_child(btn_ctrl)
	
	var btn_guide := Button.new()
	btn_guide.text = "FIELD GUIDE"
	btn_guide.add_theme_font_size_override("font_size", 9)
	btn_guide.pressed.connect(func(): _show_tab("guide"))
	_left_vbox.add_child(btn_guide)
	
	var btn_delete := Button.new()
	btn_delete.text = "WIPE SAVE"
	btn_delete.add_theme_font_size_override("font_size", 9)
	btn_delete.pressed.connect(func(): _show_tab("delete_data"))
	_left_vbox.add_child(btn_delete)
	
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	_left_vbox.add_child(spacer2)
	
	var btn_close := Button.new()
	btn_close.text = "CLOSE"
	btn_close.add_theme_font_size_override("font_size", 10)
	btn_close.pressed.connect(_on_close_pressed)
	_left_vbox.add_child(btn_close)
	
	# Right Content panel (width 360)
	_content_panel = PanelContainer.new()
	_content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content_style := StyleBoxFlat.new()
	content_style.bg_color = Color(0.01, 0.03, 0.06, 0.8)
	content_style.border_width_left = 1
	content_style.border_width_top = 1
	content_style.border_width_right = 1
	content_style.border_width_bottom = 1
	content_style.border_color = Color(0.0, 0.8, 1.0, 0.15)
	content_style.content_margin_left = 12
	content_style.content_margin_top = 12
	content_style.content_margin_right = 12
	content_style.content_margin_bottom = 12
	_content_panel.add_theme_stylebox_override("panel", content_style)
	main_hbox.add_child(_content_panel)
	
	# Scroll area for tab content
	_content_scroll = ScrollContainer.new()
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_panel.add_child(_content_scroll)
	
	# Inner VBox
	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 10)
	_content_scroll.add_child(_content_vbox)

func _show_tab(tab_name: String) -> void:
	AudioManager.play_click()
	_current_tab = tab_name
	
	# Clear previous tab contents
	for child in _content_vbox.get_children():
		child.queue_free()
		
	# Populate based on selected tab
	if tab_name == "audio":
		_build_audio_tab()
	elif tab_name == "controls":
		_build_controls_tab()
	elif tab_name == "guide":
		_build_guide_tab()
	elif tab_name == "delete_data":
		_build_delete_tab()

func _build_audio_tab() -> void:
	var title := Label.new()
	title.text = "AUDIO VOLUME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	_content_vbox.add_child(title)
	
	var buses = ["Master", "Music", "SFX"]
	for bus in buses:
		var bus_lbl := Label.new()
		bus_lbl.text = bus + " Volume"
		bus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bus_lbl.add_theme_font_size_override("font_size", 9)
		bus_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_content_vbox.add_child(bus_lbl)
		
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.02
		slider.value = AudioManager.get_volume(bus)
		slider.value_changed.connect(func(val):
			AudioManager.set_volume(bus, val)
		)
		_content_vbox.add_child(slider)

func _build_controls_tab() -> void:
	var title := Label.new()
	title.text = "KEYBOARD CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	_content_vbox.add_child(title)
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 6)
	_content_vbox.add_child(grid)
	
	var binds = [
		["Move", "W, A, S, D / Arrow Keys"],
		["Aim / Shoot", "Mouse / Left Mouse Button"],
		["Stats Menu (C)", "Spend EXP / Buy Heal (Pauses Game)"],
		["Weapon Shop (G)", "Buy Guns & Ammo (Pauses Game)"],
		["Select Gun", "1, 2, 3 / Mouse Scroll Wheel"],
		["Special Ammo", "Q Key (Forward) / R Key (Backward)"],
		["Mercenaries (V)", "Manage Companions (Pauses Game)"],
		["Items / Explosives", "F Key (Cycle) / X Key (Use / Throw)"]
	]
	
	for pair in binds:
		var act_lbl := Label.new()
		act_lbl.text = pair[0] + ":"
		act_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		act_lbl.add_theme_font_size_override("font_size", 9)
		act_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		grid.add_child(act_lbl)
		
		var key_lbl := Label.new()
		key_lbl.text = pair[1]
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 9)
		key_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		grid.add_child(key_lbl)

func _build_guide_tab() -> void:
	var title := Label.new()
	title.text = "FIELD GUIDE: CHARACTERS & INFECTED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.0, 0.8, 1.0))
	_content_vbox.add_child(title)
	
	var zombies_data = [
		{
			"name": "MERCENARY: VANGUARD CAPTAIN",
			"stats": "HP: 300",
			"desc": "Elite soldier 'Captain Vane'. Rebelled against orders to destroy Specimen 73. Heavy combat expert.",
			"color": Color(1.0, 0.8, 0.2)
		},
		{
			"name": "MERCENARY: RESEARCHER ELARA",
			"stats": "HP: 150",
			"desc": "Lab scientist who monitored Kaelan's stabilization. Fragile but knowledgeable about the Heart Cavern.",
			"color": Color(0.4, 1.0, 0.8)
		},
		{
			"name": "BASIC ZOMBIE",
			"stats": "HP: 60 | Speed: 160 | DMG: 12",
			"desc": "The common undead. Relatively slow but dangerous in numbers. Drops basic ammunition.",
			"color": Color(0.85, 0.1, 0.1)
		},
		{
			"name": "SLOW ZOMBIE",
			"stats": "HP: 40 | Speed: 120 | DMG: 10",
			"desc": "A fragile, lumbering walker. Extremely slow, but easily overlooked in massive waves.",
			"color": Color(0.6, 0.6, 0.65)
		},
		{
			"name": "CYBORG ZOMBIE",
			"stats": "HP: 100 | Speed: 200 | DMG: 25",
			"desc": "A fast, steel-plated cybernetic hybrid. High health and aggressive charging speed.",
			"color": Color(0.0, 0.8, 1.0)
		},
		{
			"name": "HEART LEADER ZOMBIE",
			"stats": "HP: 120 | Speed: 140 | DMG: 15",
			"desc": "Glowing squad commander. Radiates a biological aura that coordinates surrounding undead.",
			"color": Color(0.9, 0.1, 0.7)
		},
		{
			"name": "BOMBER ZOMBIE",
			"stats": "HP: 50 | Speed: 180 | DMG: 30 (Explosion)",
			"desc": "Unstable carrier. Runs straight at survivors and self-destructs upon close contact.",
			"color": Color(1.0, 0.5, 0.0)
		},
		{
			"name": "GUNNER ZOMBIE",
			"stats": "HP: 80 | Speed: 130 | DMG: 8 (Ranged Status)",
			"desc": "Wields a customized rifle. Shoots slowing, paralyzing, or toxic chemical bullets from afar.",
			"color": Color(0.6, 0.2, 0.9)
		},
		{
			"name": "MINI BOSS: SUBJECT 0 SERIES (SPINE / SKULL / HEART)",
			"stats": "HP: 400 - 650",
			"desc": "Infected prototypes from the old sovereign labs. Defeating unique specimens unlocks access to Cemetery Hills (Zone 2).",
			"color": Color(1.0, 0.4, 0.0)
		},
		{
			"name": "MINI BOSS: CYBORG & GIANT SPECIMENS (PROTOTYPE / GIANT)",
			"stats": "HP: 600 - 850",
			"desc": "Heavy armored variants patrolling Cemetery Hills. Defeating unique specimens unlocks access to Subway Tunnels (Zone 3).",
			"color": Color(0.9, 0.1, 0.35)
		}
	]
	
	for z in zombies_data:
		# Card Container
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.02, 0.04, 0.08, 0.6)
		card_style.border_width_left = 2
		card_style.border_color = z["color"] # Colored indicator for the zombie class
		card_style.content_margin_left = 6
		card_style.content_margin_top = 4
		card_style.content_margin_bottom = 4
		card_style.content_margin_right = 6
		card.add_theme_stylebox_override("panel", card_style)
		_content_vbox.add_child(card)
		
		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 2)
		card.add_child(card_vbox)
		
		var name_lbl := Label.new()
		name_lbl.text = z["name"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", z["color"])
		card_vbox.add_child(name_lbl)
		
		var stats_lbl := Label.new()
		stats_lbl.text = z["stats"]
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_lbl.add_theme_font_size_override("font_size", 8)
		stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		card_vbox.add_child(stats_lbl)
		
		var desc_lbl := Label.new()
		desc_lbl.text = z["desc"]
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.add_theme_font_size_override("font_size", 8)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.custom_minimum_size = Vector2(300, 0)
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		card_vbox.add_child(desc_lbl)

func _on_close_pressed() -> void:
	AudioManager.play_click()
	queue_free()

func _build_delete_tab() -> void:
	var title := Label.new()
	title.text = "WIPE SAVE DATA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	_content_vbox.add_child(title)
	
	var warning_lbl := Label.new()
	warning_lbl.text = "This will permanently erase all save data, including current wave progress, stats upgrades, high score, and discovered lore fragments.\n\nTHIS CANNOT BE UNDONE!"
	warning_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	warning_lbl.custom_minimum_size = Vector2(300, 0)
	warning_lbl.add_theme_font_size_override("font_size", 9)
	warning_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_content_vbox.add_child(warning_lbl)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_content_vbox.add_child(spacer)
	
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	_content_vbox.add_child(btn_hbox)
	
	var yes_btn := Button.new()
	yes_btn.text = "YES, DELETE ALL"
	yes_btn.add_theme_font_size_override("font_size", 9)
	yes_btn.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	yes_btn.pressed.connect(func():
		Globals.delete_save()
		AudioManager.play_zombie_die()
		warning_lbl.text = "\n\nALL DATA ERASED SUCCESSFULLY!\n\nPlease restart the game or start a New Game."
		yes_btn.visible = false
	)
	btn_hbox.add_child(yes_btn)
	
	var no_btn := Button.new()
	no_btn.text = "CANCEL"
	no_btn.add_theme_font_size_override("font_size", 9)
	no_btn.pressed.connect(func():
		_show_tab("audio")
	)
	btn_hbox.add_child(no_btn)
