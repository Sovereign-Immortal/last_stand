extends Node2D

# Spooky dialog lines for the 6 unique crypts
const CRYPT_DIALOGS := [
	[
		{
			"speaker": "Crypt Inscription",
			"text": "Here lies the First Commander of the Vanguard. 'The project has failed. The dead do not sleep.'",
			"color": Color(0.8, 0.8, 0.8)
		}
	],
	[
		{
			"speaker": "A Whisper",
			"text": "A giant's heart beats in human veins. The prince sleeps in the center of the world.",
			"color": Color(0.9, 0.4, 0.9)
		}
	],
	[
		{
			"speaker": "Old Diary Fragment",
			"text": "Day 45: The infection is airborne. The low-pass ringing in our ears is the final stage. God help us.",
			"color": Color(0.2, 0.9, 1.0)
		}
	],
	[
		{
			"speaker": "Crumbled Slate",
			"text": "The subway tunnels lead to the core. Run. Do not enter the tunnels without an echo filter.",
			"color": Color(1.0, 0.8, 0.2)
		}
	],
	[
		{
			"speaker": "Ancient Stone",
			"text": "The cyborgs were built to defend the vault. Now they only track the living.",
			"color": Color(1.0, 0.3, 0.3)
		}
	],
	[
		{
			"speaker": "Restless Spirit",
			"text": "The Bomber's core is unstable. Keep your distance when they begin to flash red.",
			"color": Color(0.4, 1.0, 0.4)
		}
	]
]

func _ready() -> void:
	# Build the floor grid
	var ground := TileMapLayer.new()
	ground.tile_set = preload("res://tiles.tres")
	add_child(ground)
	
	# Grass tile from atlas source 0, coordinate (0, 7)
	for x in range(-60, 60):
		for y in range(-60, 60):
			ground.set_cell(Vector2i(x, y), 1, Vector2i(0, 7))

	# Spawn Cemetery Gravestones & Crypts
	var r := RandomNumberGenerator.new()
	r.seed = 1337 # deterministic
	
	# Spawn 45 gravestones
	for i in range(45):
		var pos := Vector2(r.randf_range(-1200, 1200), r.randf_range(-1200, 1200))
		if pos.length() < 180.0:
			continue # clear around player spawn
		_spawn_tombstone(pos, r.randi_range(0, 1) == 0, i)

	# Spawn 6 larger brick Crypts
	for i in range(6):
		var pos := Vector2(r.randf_range(-1000, 1000), r.randf_range(-1000, 1000))
		if pos.length() < 250.0:
			continue
		_spawn_crypt(pos, i)

	# Spawn Vanguard Captain story NPC
	var npc_scene = load("res://Scenes/Humans/npc.tscn")
	if npc_scene:
		var cap = npc_scene.instantiate()
		cap.npc_type = "vanguard_captain"
		cap.global_position = Vector2(80, -120)
		add_child(cap)

func _spawn_tombstone(pos: Vector2, is_cross: bool, index: int) -> void:
	var sb := StaticBody2D.new()
	sb.global_position = pos
	sb.name = "Tombstone_%d" % index
	
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	col.shape = circle
	sb.add_child(col)
	
	# Visual tombstone shape
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-12, 10),
		Vector2(-12, -10),
		Vector2(-6, -18),
		Vector2(6, -18),
		Vector2(12, -10),
		Vector2(12, 10)
	])
	poly.color = Color(0.38, 0.4, 0.43) # spooky slate grey
	
	# If this is a special grave, give it a subtle blue-ish edge glow
	if index == 10 or index == 20:
		poly.color = Color(0.28, 0.42, 0.53) # slightly tinted cyan-grey
	sb.add_child(poly)
	
	# Detail markings
	if is_cross:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(0, -12), Vector2(0, 2), Vector2(-5, -7), Vector2(5, -7)])
		line.width = 2.0
		line.default_color = Color(0.18, 0.2, 0.22)
		sb.add_child(line)
	else:
		var rip_line := Line2D.new()
		rip_line.points = PackedVector2Array([Vector2(-4, -6), Vector2(4, -6)])
		rip_line.width = 2.0
		rip_line.default_color = Color(0.18, 0.2, 0.22)
		sb.add_child(rip_line)
		
	# Setup interactive area
	var area := Area2D.new()
	var area_col := CollisionShape2D.new()
	var area_circle := CircleShape2D.new()
	area_circle.radius = 50.0
	area_col.shape = area_circle
	area.add_child(area_col)
	sb.add_child(area)
	
	# Visual Prompt
	var prompt := Label.new()
	prompt.text = "[E] Inspect Grave"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 9)
	prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	prompt.position = Vector2(-50, -45)
	prompt.custom_minimum_size = Vector2(100, 20)
	prompt.visible = false
	sb.add_child(prompt)
	
	sb.set_meta("is_interacted", false)
	
	# Interactive method
	var interact_callable = func():
		if sb.get_meta("is_interacted"):
			DialogManager.show_dialog([
				{
					"speaker": "Grave",
					"text": "The ground is silent.",
					"color": Color(0.5, 0.5, 0.5)
				}
			])
			return
			
		sb.set_meta("is_interacted", true)
		prompt.visible = false
		AudioManager.play_click()
		
		if index == 10:
			DialogManager.show_dialog([
				{
					"speaker": "System",
					"text": "You inspect the dusty grave... A glowing note slides out of a crack in the stone.",
					"color": Color(0.3, 0.8, 1.0)
				}
			])
			# Drop Lore Note 5
			var lp = load("res://Scenes/Objects/lore_pickup.tscn").instantiate()
			lp.lore_id = 5
			lp.global_position = sb.global_position + Vector2(0, 32.0)
			get_parent().add_child(lp)
			
			# Glow color
			poly.color = Color(0.1, 0.6, 0.8)
		elif index == 20:
			DialogManager.show_dialog([
				{
					"speaker": "System",
					"text": "Under the mossy soil, you find a sealed metal container containing a note.",
					"color": Color(0.3, 0.8, 1.0)
				}
			])
			# Drop Lore Note 6
			var lp = load("res://Scenes/Objects/lore_pickup.tscn").instantiate()
			lp.lore_id = 6
			lp.global_position = sb.global_position + Vector2(0, 32.0)
			get_parent().add_child(lp)
			
			# Glow color
			poly.color = Color(0.1, 0.6, 0.8)
		else:
			# Atmospheric inscription
			var inscriptions := [
				"Here lies a forgotten resident of the Vanguard colony.",
				"Rest in Peace. 'We tried our best to hold the wall.'",
				"The stone is worn down by wind and rain.",
				"A silent headstone. The name has faded away.",
				"This grave is empty. The occupant rose again...",
				"A simple grave with a hand-carved inscription: 'Never forget us.'"
			]
			var ins = inscriptions[index % inscriptions.size()]
			DialogManager.show_dialog([
				{
					"speaker": "Grave Inscription",
					"text": ins,
					"color": Color(0.7, 0.7, 0.75)
				}
			])
			poly.color = Color(0.25, 0.25, 0.25) # faded color
			
	sb.set_meta("interact_method", interact_callable)
	
	# Connect triggers
	area.body_entered.connect(func(body):
		if body.is_in_group("player") and not sb.get_meta("is_interacted"):
			prompt.visible = true
			body.set_meta("active_crypt", sb)
	)
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			prompt.visible = false
			if body.has_meta("active_crypt") and body.get_meta("active_crypt") == sb:
				body.remove_meta("active_crypt")
	)
	
	add_child(sb)

func _spawn_crypt(pos: Vector2, index: int) -> void:
	var sb := StaticBody2D.new()
	sb.global_position = pos
	sb.name = "Crypt_%d" % index
	
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 70)
	col.shape = rect
	sb.add_child(col)
	
	# Crypt base
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-35, -35),
		Vector2(35, -35),
		Vector2(35, 35),
		Vector2(-35, 35)
	])
	poly.color = Color(0.24, 0.25, 0.28) # dark crypt bricks
	sb.add_child(poly)
	
	# Crypt roof trim
	var roof := Polygon2D.new()
	roof.polygon = PackedVector2Array([
		Vector2(-40, -35),
		Vector2(0, -55),
		Vector2(40, -35)
	])
	roof.color = Color(0.16, 0.17, 0.2)
	sb.add_child(roof)
	
	# Add a gate detail
	var gate := ColorRect.new()
	gate.size = Vector2(24, 30)
	gate.position = Vector2(-12, 5)
	gate.color = Color(0.08, 0.08, 0.1)
	sb.add_child(gate)
	
	# Setup interactive area
	var area := Area2D.new()
	var area_col := CollisionShape2D.new()
	var area_circle := CircleShape2D.new()
	area_circle.radius = 80.0
	area_col.shape = area_circle
	area.add_child(area_col)
	sb.add_child(area)
	
	# Visual Prompt
	var prompt := Label.new()
	prompt.text = "[E] Inspect Crypt"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 9)
	prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	prompt.position = Vector2(-50, -80)
	prompt.custom_minimum_size = Vector2(100, 20)
	prompt.visible = false
	sb.add_child(prompt)
	
	# Store properties for interaction
	sb.set_meta("dialog_index", index)
	sb.set_meta("is_interacted", false)
	
	# Define dynamic interaction method on the StaticBody2D
	var interact_callable = func():
		if sb.get_meta("is_interacted"):
			DialogManager.show_dialog([
				{
					"speaker": "Tombstone",
					"text": "The echoes of this place are silent now...",
					"color": Color(0.5, 0.5, 0.5)
				}
			])
			return
		
		# Set interacted
		sb.set_meta("is_interacted", true)
		prompt.visible = false
		AudioManager.play_click()
		
		# Show dialogues
		var lines = CRYPT_DIALOGS[index]
		DialogManager.show_dialog(lines)
		
		# Award experience (score) or custom ammo as a bonus!
		Globals.score += 150
		Globals.save()
		
		# Visual cue: tint the gate to a green glow to show it's completed
		gate.color = Color(0.1, 0.5, 0.2)
	
	sb.set_meta("interact_method", interact_callable)
	
	# Connect triggers
	area.body_entered.connect(func(body):
		if body.is_in_group("player") and not sb.get_meta("is_interacted"):
			prompt.visible = true
			body.set_meta("active_crypt", sb)
	)
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			prompt.visible = false
			if body.has_meta("active_crypt") and body.get_meta("active_crypt") == sb:
				body.remove_meta("active_crypt")
	)
	
	add_child(sb)
