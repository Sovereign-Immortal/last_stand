extends Node2D

var heart_node: Polygon2D
var _heart_timer: float = 0.0
var _active_altar: StaticBody2D = null

func _ready() -> void:
	# Build the volcanic cavern floor grid
	var ground := TileMapLayer.new()
	ground.tile_set = preload("res://tiles.tres")
	add_child(ground)
	
	# Muddy dark-stone coordinates modulated red/purple
	ground.modulate = Color(0.35, 0.15, 0.18)
	for x in range(-40, 40):
		for y in range(-40, 40):
			ground.set_cell(Vector2i(x, y), 0, Vector2i(1, 10))
			
	# Spawn cavern boundary walls to shape a circular ritual room
	_spawn_cavern_walls()

	# Spawn the pulsing Giant Heart in the center
	_spawn_giant_heart()

	# Spawn the 4 Altars
	_spawn_altar("Destroy", Vector2(-160, -180), Color(0.85, 0.1, 0.1), 1)
	_spawn_altar("Absorb", Vector2(160, -180), Color(0.8, 0.1, 0.8), 2)
	_spawn_altar("Seal", Vector2(-160, 100), Color(0.5, 0.5, 0.5), 3)
	_spawn_altar("Veil", Vector2(160, 100), Color(0.1, 0.8, 0.9), 4)

	# Initial intro text on entering the cavern
	get_tree().create_timer(1.2).timeout.connect(func():
		DialogManager.show_dialog([
			{
				"speaker": "Kaelan",
				"text": "This is it. The core. I can hear it... beating in my head.",
				"color": Color(0.2, 0.9, 1.0)
			},
			{
				"speaker": "System",
				"text": "Before you pulses the Heart of the King. Four paths lie ahead. Choose wisely.",
				"color": Color(0.8, 0.2, 0.2)
			}
		])
	)

func _process(delta: float) -> void:
	# Pulsate heart scale and color intensity
	_heart_timer += delta
	var thump := sin(_heart_timer * 4.0)
	var clamp_thump := clampf(thump, 0.0, 1.0)
	
	if heart_node:
		heart_node.scale = Vector2.ONE * (2.2 + clamp_thump * 0.28)
		heart_node.color = Color(0.75 + clamp_thump * 0.25, 0.03, 0.03)

	# Play ambient heartbeat thump sound effect at the peak of the pulsate
	if fmod(_heart_timer, PI / 2.0) < delta * 1.5:
		AudioManager.play_zombie_groan() # low cavern echo rumble

func _spawn_giant_heart() -> void:
	var sb := StaticBody2D.new()
	sb.global_position = Vector2(0, -60)
	
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	col.shape = circle
	sb.add_child(col)
	
	# Create Polygon2D Heart shape
	heart_node = Polygon2D.new()
	var points := PackedVector2Array([
		Vector2(0, 32),
		Vector2(-20, 12),
		Vector2(-32, -12),
		Vector2(-28, -32),
		Vector2(-12, -36),
		Vector2(0, -18),
		Vector2(12, -36),
		Vector2(28, -32),
		Vector2(32, -12),
		Vector2(20, 12)
	])
	heart_node.polygon = points
	heart_node.color = Color(0.8, 0.05, 0.05)
	sb.add_child(heart_node)
	
	add_child(sb)

func _spawn_altar(action_type: String, pos: Vector2, neon_color: Color, index: int) -> void:
	var sb := StaticBody2D.new()
	sb.global_position = pos
	sb.name = "Altar_%s" % action_type
	
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(50, 50)
	col.shape = rect
	sb.add_child(col)
	
	# Altar Stone Base
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-25, -25),
		Vector2(25, -25),
		Vector2(25, 25),
		Vector2(-25, 25)
	])
	poly.color = Color(0.18, 0.18, 0.22)
	sb.add_child(poly)
	
	# Glowing Runes
	var glow := ColorRect.new()
	glow.size = Vector2(16, 16)
	glow.position = Vector2(-8, -8)
	glow.color = neon_color
	sb.add_child(glow)
	
	# Area2D Trigger
	var area := Area2D.new()
	var area_col := CollisionShape2D.new()
	var area_circle := CircleShape2D.new()
	area_circle.radius = 70.0
	area_col.shape = area_circle
	area.add_child(area_col)
	sb.add_child(area)
	
	# Visual Prompt
	var prompt := Label.new()
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 9)
	prompt.position = Vector2(-75, -55)
	prompt.custom_minimum_size = Vector2(150, 20)
	prompt.visible = false
	sb.add_child(prompt)
	
	# Setup labels
	if action_type == "Veil":
		if Globals.discovered_lore.size() >= 6:
			prompt.text = "[E] Altar of the Veil (Secret)"
			prompt.add_theme_color_override("font_color", neon_color)
		else:
			prompt.text = "[E] Altar of the Veil (Locked)"
			prompt.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	else:
		prompt.text = "[E] Altar of %s" % action_type.to_upper()
		prompt.add_theme_color_override("font_color", neon_color)
		
	# Interactive Callable
	var interact_callable = func():
		if action_type == "Veil" and Globals.discovered_lore.size() < 6:
			DialogManager.show_dialog([
				{
					"speaker": "System",
					"text": "The Altar of the Veil is cold and inactive.",
					"color": Color(0.5, 0.5, 0.5)
				},
				{
					"speaker": "System",
					"text": "To activate the fourth path, you must discover and resolve all 6 archives of truth in your diary.",
					"color": Color(0.5, 0.5, 0.5)
				}
			])
			return
			
		AudioManager.play_click()
		
		# Show double confirmation dialog
		var confirmation_lines := [
			{
				"speaker": "System",
				"text": "Do you wish to initiate the %s path? There is no turning back." % action_type.to_upper(),
				"color": neon_color
			}
		]
		DialogManager.show_dialog(confirmation_lines)
		
		# Connect to dialog close to trigger ending narration
		get_tree().create_timer(0.2).timeout.connect(func():
			# Wait until confirmation dialog is clicked
			while DialogManager.is_active():
				await get_tree().create_timer(0.1).timeout
				
			# Show ending slideshow narration
			_trigger_ending_slides(index)
		)
		
	sb.set_meta("interact_method", interact_callable)
	
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			prompt.visible = true
			body.set_meta("active_crypt", sb)
	)
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			prompt.visible = false
			if body.has_meta("active_crypt") and body.get_meta("active_crypt") == sb:
				body.remove_meta("active_crypt")
				
	add_child(sb)

func _trigger_ending_slides(ending_index: int) -> void:
	var ending_text := []
	var ending_name := ""
	
	match ending_index:
		1:
			ending_name = "Destroy"
			ending_text = [
				{
					"speaker": "Ending — Destroy",
					"text": "You shatter the Giant's Heart. A shockwave tears through the cavern, turning the Revenants outside to ash.",
					"color": Color(0.85, 0.1, 0.1)
				},
				{
					"speaker": "Ending — Destroy",
					"text": "The plague ends, but the ancient power is gone forever.",
					"color": Color(0.85, 0.1, 0.1)
				},
				{
					"speaker": "Ending — Destroy",
					"text": "You return to the surface as Kaelan – a human with no family, no past, and memories that will never heal.",
					"color": Color(0.85, 0.1, 0.1)
				}
			]
		2:
			ending_name = "Absorb"
			ending_text = [
				{
					"speaker": "Ending — Absorb",
					"text": "You place your hands on the pulsing heart and draw its energy into yourself.",
					"color": Color(0.8, 0.1, 0.8)
				},
				{
					"speaker": "Ending — Absorb",
					"text": "Your skin thickens, your bones stretch. The flesh of the giant prince reclaimed.",
					"color": Color(0.8, 0.1, 0.8)
				},
				{
					"speaker": "Ending — Absorb",
					"text": "The Revenants fall to their knees, bowing to their new king. But you rule a dead empire. There is no one left to save.",
					"color": Color(0.8, 0.1, 0.8)
				}
			]
		3:
			ending_name = "Seal"
			ending_text = [
				{
					"speaker": "Ending — Seal",
					"text": "You turn your back on the heart, building a massive stone barrier to seal the cavern forever.",
					"color": Color(0.6, 0.6, 0.6)
				},
				{
					"speaker": "Ending — Seal",
					"text": "The world above continues its slow, desperate struggle.",
					"color": Color(0.6, 0.6, 0.6)
				},
				{
					"speaker": "Ending — Seal",
					"text": "You watch from the shadows, a silent guardian who refuses to choose.",
					"color": Color(0.6, 0.6, 0.6)
				}
			]
		4:
			ending_name = "Veil's End"
			ending_text = [
				{
					"speaker": "Ending — Veil's End",
					"text": "With all archives of truth gathered, you merge your human memories and giant essence into the heart.",
					"color": Color(0.1, 0.8, 0.9)
				},
				{
					"speaker": "Ending — Veil's End",
					"text": "A brilliant white light erupts, washing over the ruins, the cemetery, and the tunnels.",
					"color": Color(0.1, 0.8, 0.9)
				},
				{
					"speaker": "Ending — Veil's End",
					"text": "The plague is completely purified. The earth heals. You awaken in the sunlight – completely human, free of the curse, ready to start anew.",
					"color": Color(0.1, 0.8, 0.9)
				}
			]

	DialogManager.show_dialog(ending_text)
	
	# Wait until narration closes, then wipe progress and load menu
	get_tree().create_timer(0.2).timeout.connect(func():
		while DialogManager.is_active():
			await get_tree().create_timer(0.1).timeout
			
		# Record unlocked ending meta-progression
		if not Globals.unlocked_endings.has(ending_name):
			Globals.unlocked_endings.append(ending_name)
			
		# Reset campaign wave state for next playthrough
		Globals.current_wave = 1
		Globals.selected_map = "res://Scenes/Locations/map_1.tscn"
		Globals.save()
		
		# Return to Menu
		SceneTransition.fade_to("res://Scenes/menue.tscn")
	)

func _spawn_cavern_walls() -> void:
	# Circular boundary colliders to keep player inside
	var radius := 540.0
	var count := 32
	for i in range(count):
		var angle := i * (2.0 * PI / count)
		var wall_pos := Vector2(cos(angle), sin(angle)) * radius
		var sb := StaticBody2D.new()
		sb.global_position = wall_pos
		
		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 24.0
		col.shape = circle
		sb.add_child(col)
		
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-24, -24),
			Vector2(24, -24),
			Vector2(24, 24),
			Vector2(-24, 24)
		])
		poly.color = Color(0.14, 0.1, 0.12)
		sb.add_child(poly)
		
		add_child(sb)
