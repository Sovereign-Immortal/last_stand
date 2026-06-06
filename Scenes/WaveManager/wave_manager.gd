extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal wave_started(wave_num: int, total_zombies: int)
signal wave_completed(wave_num: int)
signal wave_countdown(seconds_left: int)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
@export var between_wave_delay: float = 5.0
@export var spawn_delay: float = 0.7

# ---------------------------------------------------------------------------
# Preloaded scenes
# ---------------------------------------------------------------------------
var _scene_slow   := preload("res://Scenes/Zombies/zombie_slow.tscn")
var _scene_base   := preload("res://Scenes/Zombies/zombie_base.tscn")
var _scene_cyborg := preload("res://Scenes/Zombies/Cyborg_zombie.tscn")
var _scene_heart  := preload("res://Scenes/Zombies/zombie_heart.tscn")
var _scene_bomber := preload("res://Scenes/Zombies/zombie_bomber.tscn")
var _scene_gunner := preload("res://Scenes/Zombies/zombie_gunner.tscn")
var _bullet_pickup_scene := preload("res://Scenes/Pickups/bullet_pickup.tscn")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _current_wave: int = 0
var _enemies_node: Node2D = null
var _spawn_points: Array[Node2D] = []
var _running: bool = false

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Wait one frame for node tree structure initialization to complete safely
	await get_tree().process_frame

	# Heart cavern now runs waves normally — do NOT early return
	# But we hide the regular HUD zombie counter and use heart cavern UI instead
	if Globals.selected_map == "res://Scenes/Locations/heart_cavern.tscn":
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.visible = true # keep HUD for wave counter

	# Spawn points = all Marker2D direct children of this node
	for child in get_children():
		if child is Marker2D:
			_spawn_points.append(child as Node2D)

	_enemies_node = get_parent().get_node_or_null("Enemies")
	
	# Auto-create Enemies container if the map doesn't have one (e.g. heart_cavern)
	if _enemies_node == null:
		var enemies_container := Node2D.new()
		enemies_container.name = "Enemies"
		get_parent().add_child(enemies_container)
		_enemies_node = enemies_container

	# Auto-create spawn points around the arena perimeter if none exist (heart_cavern)
	if _spawn_points.is_empty():
		var sp_radius = 380.0
		for i in range(8):
			var angle = i * (TAU / 8.0)
			var marker := Marker2D.new()
			marker.position = Vector2(cos(angle), sin(angle)) * sp_radius
			add_child(marker)
			_spawn_points.append(marker)


	# Dynamically set up Godot 4 Navigation Region so NavigationAgent2Ds can pathfind around walls/obstacles
	var root := get_parent()
	var map := root.get_node_or_null("Map1")
	if map:
		var nav_region := NavigationRegion2D.new()
		nav_region.name = "NavigationRegion"
		
		# Add nav_region synchronously and move it to index 0 so the map renders behind players and zombies
		root.add_child(nav_region)
		root.move_child(nav_region, 0)
		
		# Reparent the map inside the navigation region so the baker parses its collision boundaries
		map.get_parent().remove_child(map)
		nav_region.add_child(map)
		
		# Create navigation polygon outline
		var nav_poly := NavigationPolygon.new()
		var outline := PackedVector2Array([
			Vector2(-3500, -3500),
			Vector2(3500, -3500),
			Vector2(3500, 3500),
			Vector2(-3500, 3500)
		])
		nav_poly.add_outline(outline)
		nav_poly.agent_radius = 24.0
		nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
		nav_poly.make_polygons_from_outlines()
		nav_region.navigation_polygon = nav_poly
		
		# Bake the navigation mesh synchronously (false = on main thread) so it's ready immediately
		nav_region.bake_navigation_polygon(false)

	if Globals.is_continuing_game:
		_current_wave = Globals.current_wave - 1
		Globals.is_continuing_game = false
	else:
		_current_wave = 0

	# Add current map to visited maps
	if not Globals.visited_maps.has(Globals.selected_map):
		Globals.visited_maps.append(Globals.selected_map)
		Globals.save()

	# Check if we have returned from the other two zones with at least 10% lore in each
	var other_zones_ok = true
	var maps = [
		"res://Scenes/Locations/map_1.tscn",
		"res://Scenes/Locations/cemetery_hills.tscn",
		"res://Scenes/Locations/subway_tunnels.tscn"
	]
	
	for m in maps:
		if m != Globals.selected_map:
			var visited = Globals.visited_maps.has(m)
			var pct = Globals.get_map_lore_percentage(m)
			if not visited or pct < 0.10:
				other_zones_ok = false
				
	if other_zones_ok:
		DialogManager.show_dialog([
			{
				"speaker": "Kaelan",
				"text": "The pieces are falling into place. The other zones... I remember them now.",
				"color": Color(0.9, 0.4, 0.9)
			},
			{
				"speaker": "Kaelan",
				"text": "The whispers of the crypt, the resonance of the subway tunnels. My connection to the Veil is strengthening.",
				"color": Color(0.9, 0.4, 0.9)
			}
		])

	var player = get_parent().get_node_or_null("Player")

	# If starting Map1 fresh, play the intro sequence where an NPC dies in front of us
	if Globals.selected_map == "res://Scenes/Locations/map_1.tscn" and not Globals.is_continuing_game:
		# 1. Strip player of starting equipment
		if player:
			player.bullet_ammo[0] = 0
			player.explosives_ammo.assign([0, 0, 0, 0, 0])
			player.emit_signal("bullet_changed", "Standard", 0)
			player.emit_signal("explosive_changed", "Grenade", 0)

		# 2. Spawn dying NPC in front of the player
		var dying_npc := Sprite2D.new()
		dying_npc.texture = load("res://Last Stand Assets/Characters/PNG/Soldier 1/soldier1_hold.png")
		if player:
			dying_npc.global_position = player.global_position + Vector2(0, -110)
		else:
			dying_npc.global_position = Vector2(0, -110)
		get_parent().add_child(dying_npc)
		
		# 3. Wait 1.5 seconds, then scream and collapse
		await get_tree().create_timer(1.5).timeout
		
		# Scream effect (DialogManager + sound + camera shake)
		AudioManager.play_player_hurt()
		AudioManager.trigger_tinnitus(2.0)
		if player and player.has_method("_shake_screen"):
			player._shake_screen(12.0, 1.5)
			
		DialogManager.show_dialog([
			{"speaker": "Soldier", "text": "AAARGH! Help me... what is this...?! AAAAAHHH!", "color": Color(1.0, 0.2, 0.2)}
		])
		
		# Wait for dialogue to close
		while DialogManager.is_active():
			await get_tree().create_timer(0.2).timeout
		
		# NPC collapses
		dying_npc.rotation = PI/2
		dying_npc.modulate = Color(0.4, 0.4, 0.4, 0.8)
		
		# Spawn blood pool
		var blood_pool := Line2D.new()
		blood_pool.width = 15.0
		blood_pool.default_color = Color(0.6, 0.0, 0.0, 0.8)
		blood_pool.points = PackedVector2Array([
			dying_npc.global_position + Vector2(-10, 5),
			dying_npc.global_position + Vector2(10, 5)
		])
		get_parent().add_child(blood_pool)
		
		# 4. Proximity-based looting prompt
		var prompt := Label.new()
		prompt.text = "[E] Loot Equipment"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.add_theme_font_size_override("font_size", 10)
		prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
		prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		prompt.add_theme_constant_override("outline_size", 4)
		prompt.global_position = dying_npc.global_position + Vector2(-50, -40)
		prompt.visible = false
		get_parent().add_child(prompt)
		
		var looted = false
		while not looted:
			await get_tree().create_timer(0.05).timeout
			if not is_instance_valid(player) or not is_instance_valid(dying_npc):
				break
			var dist = player.global_position.distance_to(dying_npc.global_position)
			if dist < 65.0:
				prompt.visible = true
				if Input.is_action_just_pressed("interact") or Input.is_key_pressed(KEY_E):
					looted = true
			else:
				prompt.visible = false
				
		# 5. Handle looting success
		prompt.queue_free()
		AudioManager.play_pickup()
		
		# Restore starting equipment and add special ammo/items
		if player:
			player.bullet_ammo[0] = 300
			player.bullet_ammo[1] = 10
			player.bullet_ammo[2] = 10
			player.bullet_ammo[3] = 10
			player.bullet_ammo[4] = 10
			player.explosives_ammo.assign([9, 9, 9, 1, 1])
			if player.has_method("_notify_bullet_changed"):
				player._notify_bullet_changed()
			else:
				player.emit_signal("bullet_changed", "Standard", 300)
			if player.has_method("_notify_explosive_changed"):
				player._notify_explosive_changed()
			else:
				player.emit_signal("explosive_changed", "Grenade", 9)
			
		# Dialogue triggers
		AudioManager.trigger_tinnitus(4.5)
		DialogManager.show_dialog([
			{"speaker": "Kaelan", "text": "What... what happened to him? There are no visible wounds.", "color": Color(0.2, 0.8, 1.0)},
			{"speaker": "Kaelan", "text": "His skin is pale, cold... like his entire life force was drained in an instant.", "color": Color(0.2, 0.8, 1.0)},
			{"speaker": "Kaelan", "text": "Argh... my ears! My hearing is acting up again. The high-pitched noise is deafening...", "color": Color(0.2, 0.8, 1.0)},
			{"speaker": "Kaelan", "text": "It sounds like... \"maggOTTss\"...", "color": Color(0.2, 0.8, 1.0)},
			{"speaker": "Kaelan", "text": "And \"SCREAchiNGG STElLL\"...", "color": Color(0.2, 0.8, 1.0)},
			{"speaker": "Kaelan", "text": "SHUtYY UOP! Please, just stop!", "color": Color(0.2, 0.8, 1.0)},
			{"speaker": "Kaelan", "text": "Wait. I hear actual groans in the distance. They are coming!", "color": Color(0.2, 0.8, 1.0)},
		])
		
		# Wait for dialogue to close
		while DialogManager.is_active():
			await get_tree().create_timer(0.2).timeout

		# --- Zombie Eating Sequence ---
		# Make the dying NPC a valid target for the incoming zombies
		dying_npc.add_to_group("targets")
		
		# Spawn 3 eating zombies
		var z_base = load("res://Scenes/Zombies/zombie_base.tscn")
		var eating_zombies: Array[Node2D] = []
		var spawn_offsets = [
			Vector2(160, -120),
			Vector2(-160, -100),
			Vector2(40, -180)
		]
		for offset in spawn_offsets:
			if _enemies_node:
				var z = z_base.instantiate() as Node2D
				z.global_position = dying_npc.global_position + offset
				_enemies_node.add_child(z)
				eating_zombies.append(z)
				
		# Wait for them to reach the body
		await get_tree().create_timer(1.2).timeout
		
		# Spawn eating/blood splatter particles
		var particles := CPUParticles2D.new()
		particles.emitting = true
		particles.amount = 25
		particles.lifetime = 0.6
		particles.one_shot = false
		particles.explosiveness = 0.2
		particles.color = Color(0.65, 0.0, 0.0, 0.9)
		particles.direction = Vector2(0, -1)
		particles.spread = 75.0
		particles.initial_velocity_min = 20.0
		particles.initial_velocity_max = 45.0
		particles.global_position = dying_npc.global_position
		get_parent().add_child(particles)
		
		# Play gnawing / groaning audio
		for k in range(3):
			AudioManager.play_zombie_groan()
			await get_tree().create_timer(0.8).timeout
			
		# Fade out the corpse and its blood pool
		var tw_fade = create_tween()
		tw_fade.tween_property(dying_npc, "modulate:a", 0.0, 1.0)
		tw_fade.parallel().tween_property(blood_pool, "modulate:a", 0.0, 1.0)
		await tw_fade.finished
		
		# Clean up corpse
		dying_npc.remove_from_group("targets")
		dying_npc.queue_free()
		blood_pool.queue_free()
		particles.queue_free()

	_running = true
	for i in range(10, 0, -1):
		emit_signal("wave_countdown", i)
		await get_tree().create_timer(1.0).timeout
		if not _running:
			return
	emit_signal("wave_countdown", 0)
	_run_loop()

# ---------------------------------------------------------------------------
# Main coroutine loop
# ---------------------------------------------------------------------------
func _run_loop() -> void:
	while _running:
		_current_wave += 1
		
		if _current_wave >= 12:
			var total_lore = Globals.LORE_FRAGMENTS.size()
			var discovered_count = Globals.discovered_lore.size()
			var lore_percentage = float(discovered_count) / float(total_lore) if total_lore > 0 else 0.0
			
			var stats_ok = Globals.hp_stat_level >= 5 and Globals.speed_stat_level >= 5 and Globals.damage_stat_level >= 5
			
			var other_zones_ok = true
			var other_zones_status = ""
			var maps = [
				"res://Scenes/Locations/map_1.tscn",
				"res://Scenes/Locations/cemetery_hills.tscn",
				"res://Scenes/Locations/subway_tunnels.tscn"
			]
			
			for m in maps:
				if m != Globals.selected_map:
					var map_name = "Sovereign Ruins"
					if m.ends_with("cemetery_hills.tscn"):
						map_name = "Cemetery Hills"
					elif m.ends_with("subway_tunnels.tscn"):
						map_name = "Subway Tunnels"
						
					var visited = Globals.visited_maps.has(m)
					var pct = int(Globals.get_map_lore_percentage(m) * 100.0)
					if not visited or pct < 10:
						other_zones_ok = false
					other_zones_status += "%s: %s (Lore: %d%%) | " % [
						map_name,
						"VISITED" if visited else "UNVISITED",
						pct
					]
			if other_zones_status.ends_with(" | "):
				other_zones_status = other_zones_status.left(other_zones_status.length() - 3)
				
			if Globals.player_level >= 5 and lore_percentage >= 0.30 and stats_ok and other_zones_ok:
				_running = false
				Globals.selected_map = "res://Scenes/Locations/heart_cavern.tscn"
				Globals.player_was_killed = false
				Globals.reset()
				Globals.save()
				SceneTransition.fade_to("res://Scenes/root.tscn")
				return
			else:
				# Notify player and let them continue fighting waves until they satisfy the requirements
				DialogManager.show_dialog([
					{
						"speaker": "Sensory Interface",
						"text": "SENSORY SYNC BLOCKED: Deeper descent into the Heart Cavern requires higher synchronization.",
						"color": Color(0.9, 0.2, 0.2)
					},
					{
						"speaker": "Sensory Interface",
						"text": "Requirements: Level 5 (Current: %d) | Lore 30%% (Current: %d%%) | Stats 5+ (HP: %d/5, Spd: %d/5, Dmg: %d/5)." % [
							Globals.player_level, 
							int(lore_percentage * 100),
							Globals.hp_stat_level,
							Globals.speed_stat_level,
							Globals.damage_stat_level
						],
						"color": Color(0.9, 0.6, 0.2)
					},
					{
						"speaker": "Sensory Interface",
						"text": "Other Zones (Need 10%% Lore): %s" % other_zones_status,
						"color": Color(0.9, 0.6, 0.2)
					}
				])
			
		await _execute_wave(_current_wave)

		emit_signal("wave_completed", _current_wave)
		Globals.advance_wave()

		var delay := int(between_wave_delay)
		for i in range(delay, 0, -1):
			emit_signal("wave_countdown", i)
			await get_tree().create_timer(1.0).timeout
			if not _running:
				return
		emit_signal("wave_countdown", 0)

func _execute_wave(wave_num: int) -> void:
	if wave_num == 6:
		DialogManager.show_dialog([
			{
				"speaker": "System",
				"text": "The ground trembles. The air grows cold. A memory from five hundred years ago drags you under...",
				"color": Color(0.8, 0.2, 0.2)
			},
			{
				"speaker": "Kaelan",
				"text": "Where... where am I? Why are they so small?",
				"color": Color(0.9, 0.4, 0.9)
			}
		])
		while DialogManager.is_active():
			await get_tree().create_timer(0.1).timeout
		
		AudioManager.trigger_tinnitus(2.5)
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("enter_giant_flashback"):
			player.enter_giant_flashback(true)

	var list := _build_spawn_list(wave_num)
	emit_signal("wave_started", wave_num, list.size())

	for data in list:
		if not _running:
			return
		_spawn_zombie(data)
		await get_tree().create_timer(spawn_delay).timeout

	# Wait until all zombies are cleared
	while get_tree().get_nodes_in_group("zombies").size() > 0:
		await get_tree().create_timer(0.5).timeout
		if not _running:
			return

	# Check for scheduled mini-boss
	var boss_type = _get_scheduled_boss(wave_num)
	if boss_type != "":
		_spawn_mini_boss(boss_type)
		# Wait for mini-boss to be cleared
		while get_tree().get_nodes_in_group("zombies").size() > 0:
			await get_tree().create_timer(0.5).timeout
			if not _running:
				return
		# Notify heart cavern when heart boss is defeated
		if boss_type == "heart":
			var cavern = get_parent().get_node_or_null(".")
			if cavern and cavern.has_method("on_heart_boss_defeated"):
				cavern.on_heart_boss_defeated()
			else:
				# Fallback — search all nodes
				for node in get_tree().get_nodes_in_group("heart_cavern"):
					if node.has_method("on_heart_boss_defeated"):
						node.on_heart_boss_defeated()

	if wave_num == 6:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("enter_giant_flashback"):
			player.enter_giant_flashback(false)
		
		DialogManager.show_dialog([
			{
				"speaker": "Kaelan",
				"text": "*gasp*... *gasp*... What was that?",
				"color": Color(0.2, 0.9, 1.0)
			},
			{
				"speaker": "Kaelan",
				"text": "I was huge. I was tearing them apart with my bare hands.",
				"color": Color(0.2, 0.9, 1.0)
			},
			{
				"speaker": "Kaelan",
				"text": "Was that... me? Five hundred years ago?",
				"color": Color(0.2, 0.9, 1.0)
			}
		])
		while DialogManager.is_active():
			await get_tree().create_timer(0.1).timeout

# ---------------------------------------------------------------------------
# Wave definitions
# ---------------------------------------------------------------------------
func _build_spawn_list(wave_num: int) -> Array:
	var list: Array[Dictionary] = []
	match wave_num:
		1: list = _batch("slow", 3, 1.0) + _batch("bomber", 1, 1.0)
		2: list = _batch("slow", 4, 1.0) + _batch("bomber", 1, 1.0) + _batch("heart", 1, 1.0)
		3: list = _batch("slow", 3, 1.1) + _batch("base", 2, 1.0) + _batch("bomber", 2, 1.0) + _batch("gunner", 1, 1.0) + _batch("hostile_hunter", 2, 1.0)
		4: list = _batch("slow", 3, 1.1) + _batch("base", 3, 1.0) + _batch("heart", 1, 1.0) + _batch("gunner", 1, 1.0) + _batch("bomber", 2, 1.0) + _batch("hostile_hunter", 2, 1.0)
		5: list = _batch("base", 4, 1.1) + _batch("cyborg", 1, 1.0) + _batch("heart", 1, 1.0) + _batch("gunner", 2, 1.0) + _batch("bomber", 2, 1.0) + _batch("hostile_hunter", 3, 1.0)
		6: list = _batch("slow", 18, 1.0) + _batch("base", 12, 1.0) + _batch("hostile_hunter", 2, 1.0)
		7: list = _batch("slow", 5, 1.2) + _batch("base", 6, 1.2) + _batch("cyborg", 3, 1.2) + _batch("bomber", 4, 1.2) + _batch("gunner", 3, 1.2) + _batch("hostile_hunter", 3, 1.0)
		_:
			var n := wave_num - 5
			var mult := 1.0 + n * 0.07
			list = _batch("slow",   clampi(2 + n / 2, 2, 8),  mult) \
				 + _batch("base",   clampi(2 + n,     2, 12), mult) \
				 + _batch("cyborg", clampi(n - 1,     0, 4),  mult) \
				 + _batch("heart",  clampi(1 + n / 2, 1, 4),  mult) \
				 + _batch("bomber", clampi(2 + n / 2, 2, 6),  mult) \
				 + _batch("gunner", clampi(1 + n / 2, 1, 5),  mult) \
				 + _batch("hostile_hunter", clampi(wave_num / 3, 2, 5), 1.0)
	list.shuffle()
	return list

func _batch(type: String, count: int, mult: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for _i in count:
		out.append({"type": type, "mult": mult})
	return out

# ---------------------------------------------------------------------------
# Spawning
# ---------------------------------------------------------------------------
func _spawn_zombie(data: Dictionary) -> void:
	if data["type"] == "hostile_hunter":
		var npc_scene = load("res://Scenes/Humans/npc.tscn")
		if npc_scene:
			var hunter = npc_scene.instantiate()
			hunter.npc_type = "hostile_hunter"
			# Add to zombies group so that they count as wave enemies
			hunter.add_to_group("zombies")
			
			var sp: Node2D = _spawn_points.pick_random()
			_enemies_node.add_child(hunter)
			hunter.global_position = sp.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		return

	var scene: PackedScene = _scene_slow
	match data["type"]:
		"base":   scene = _scene_base
		"cyborg": scene = _scene_cyborg
		"heart":  scene = _scene_heart
		"bomber": scene = _scene_bomber
		"gunner": scene = _scene_gunner

	var z := scene.instantiate()
	var mult: float = data["mult"]
	if z.get("max_health") != null: z.max_health  = z.max_health  * mult
	if z.get("move_speed") != null: z.move_speed   = z.move_speed  * clampf(mult, 1.0, 2.5)

	var sp: Node2D = _spawn_points.pick_random()
	_enemies_node.add_child(z)
	z.global_position = sp.global_position + Vector2(
		randf_range(-40, 40), randf_range(-40, 40))

	# 15% chance to spawn a specialty bullet pickup near the spawn point / horde
	if randf() < 0.15:
		_spawn_bullet_pickup(sp.global_position)

func _spawn_bullet_pickup(pos: Vector2) -> void:
	var pickup = _bullet_pickup_scene.instantiate()
	pickup.bullet_type_index = randi_range(0, 4) # 0=Standard, 1=Quick, 2=Paralysis, 3=Knockback, 4=Slow Down
	var amounts = [randi_range(50, 85), randi_range(15, 25), randi_range(5, 10), randi_range(8, 12), randi_range(10, 18)]
	pickup.amount = amounts[pickup.bullet_type_index]
	get_parent().add_child(pickup)
	# Random offset so it's placed near the spawn point but spread out
	pickup.global_position = pos + Vector2(randf_range(-150, 150), randf_range(-150, 150))

func stop() -> void:
	_running = false

func _get_scheduled_boss(wave_num: int) -> String:
	var map = Globals.selected_map
	if map == "res://Scenes/Locations/map_1.tscn":
		if wave_num == 3: return "prototype"
		elif wave_num == 5: return "true_cyborg"
	elif map == "res://Scenes/Locations/cemetery_hills.tscn":
		if wave_num == 2: return "spine"
		elif wave_num == 4: return "fake_true_giant"
	elif map == "res://Scenes/Locations/subway_tunnels.tscn":
		if wave_num == 2: return "skull"
		elif wave_num == 4: return "zombiefied_giant"
	elif map == "res://Scenes/Locations/heart_cavern.tscn":
		if wave_num == 2: return "heart"
	return ""

func _spawn_mini_boss(boss_type: String) -> void:
	var boss_names = {
		"spine": "Subject 0: Spine",
		"skull": "Subject 0 Skull",
		"heart": "Subject 0 Heart",
		"true_cyborg": "True Cyborg",
		"prototype": "Prototype",
		"zombiefied_giant": "Zombiefied Giant",
		"fake_true_giant": "Fake True Giant"
	}
	var name_str = boss_names.get(boss_type, "Unknown anomaly")
	
	DialogManager.show_dialog([
		{
			"speaker": "System",
			"text": "WARNING: HIGH-FREQUENCY EMISSIONS DETECTED. MINI-BOSS INCOMING: %s!" % name_str.to_upper(),
			"color": Color(1.0, 0.1, 0.1)
		}
	])
	
	var base_scene = load("res://Scenes/Zombies/zombie_base.tscn")
	if base_scene:
		var boss = base_scene.instantiate()
		boss.set_script(load("res://Scenes/Zombies/mini_boss.gd"))
		boss.setup_boss(boss_type)
		boss.add_to_group("zombies")
		
		var sp = _spawn_points.pick_random()
		_enemies_node.add_child(boss)
		boss.global_position = sp.global_position
