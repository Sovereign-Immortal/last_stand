extends CharacterBody2D
class_name NPC

# ---------------------------------------------------------------------------
# Config & State
# ---------------------------------------------------------------------------
@export var npc_type: String = "hunter" # "hunter" or "pacifist"
@export var max_health: float = 100.0
@export var move_speed: float = 140.0
@export var fire_rate: float = 0.5 # seconds between shots

var health: float
var is_dead: bool = false
var fire_cooldown: float = 0.0

var wander_timer: float = 0.0
var nav_agent: NavigationAgent2D
var prompt_label: Label = null
var has_gun: bool = false
var equipped_weapon: int = -1
var ammo_count: int = 0
var max_ammo: int = 100
var is_hostile_to_player: bool = false
var npc_name: String = ""
var npc_age: int = 25
var npc_gender: String = "Male"
var equipped_bullet_type: int = 0
var scream_timer: float = 0.0

var _bullet_scene := preload("res://Scenes/Projectiles/bullet.tscn")
var _zombie_gunner_scene := preload("res://Scenes/Zombies/zombie_gunner.tscn")
var _zombie_bomber_scene := preload("res://Scenes/Zombies/zombie_bomber.tscn")

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	health = max_health
	scale = Vector2(0.75, 0.75)
	
	# Generate identity
	if npc_type == "vanguard_captain":
		npc_name = "Captain Vane"
		npc_gender = "Male"
		npc_age = 42
		max_health = 300.0
		health = max_health
	elif npc_type == "researcher_elara":
		npc_name = "Dr. Elara"
		npc_gender = "Female"
		npc_age = 35
		max_health = 150.0
		health = max_health
	elif npc_type == "hostile_hunter":
		npc_name = "Hostile Operative"
		npc_gender = "Male"
		npc_age = 30
		max_health = 180.0
		health = max_health
		is_hostile_to_player = true
		has_gun = true
		equipped_weapon = 1 # Machine Gun
		ammo_count = 200
		max_ammo = 200
	else:
		var names_m = ["Alex", "Marcus", "Vanguard", "Kaelen", "Hunter", "Logan", "Dante", "Garrison"]
		var names_f = ["Elena", "Sarah", "Valerie", "Cora", "Faith", "Hope", "Nova", "Morgan"]
		if randf() < 0.5:
			npc_gender = "Male"
			npc_name = names_m[randi() % names_m.size()]
		else:
			npc_gender = "Female"
			npc_name = names_f[randi() % names_f.size()]
		npc_age = randi_range(20, 45)
	
	# Create Health Bar (ProgressBar) dynamically
	var hb := ProgressBar.new()
	hb.name = "HealthBar"
	hb.max_value = max_health
	hb.value = health
	hb.show_percentage = false
	hb.custom_minimum_size = Vector2(40, 4)
	hb.position = Vector2(-20, -32)
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	hb.add_theme_stylebox_override("background", sb_bg)
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = Color(0.2, 1.0, 0.2)
	hb.add_theme_stylebox_override("fill", sb_fg)
	add_child(hb)
	
	add_to_group("npcs")
	add_to_group("targets") # Zombies hunt both targets by default
		
	# Setup Collision mask and layers:
	# Layer 1 is player/human, Layer 2 is walls, Layer 3 is zombies.
	# We want to collide with walls (Layer 2) and zombies (Layer 3)
	collision_layer = 1
	collision_mask = 6 # 2 (walls) + 4 (zombies)
	
	# Create Sprite2D dynamically to avoid scene editor configurations
	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"
	if npc_type == "hunter" or npc_type == "vanguard_captain" or npc_type == "hostile_hunter":
		sprite.texture = load("res://Last Stand Assets/Characters/PNG/Soldier 1/soldier1_gun.png")
	else:
		sprite.texture = load("res://Last Stand Assets/Characters/PNG/Survivor 1/survivor1_stand.png")
	add_child(sprite)
	
	if is_hostile_to_player:
		modulate = Color(1.3, 0.7, 0.7)
	
	# Create NavigationAgent2D dynamically
	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 15.0
	nav_agent.target_desired_distance = 15.0
	nav_agent.avoidance_enabled = false
	add_child(nav_agent)
	
	_pick_new_wander_target()
	
	# Setup interactive area
	var area := Area2D.new()
	var area_col := CollisionShape2D.new()
	var area_circle := CircleShape2D.new()
	area_circle.radius = 60.0
	area_col.shape = area_circle
	area.add_child(area_col)
	add_child(area)
	
	# Visual Prompt
	var prompt := Label.new()
	prompt.text = "[E] Equip Weapon"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 9)
	prompt.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
	prompt.position = Vector2(-50, -45)
	prompt.custom_minimum_size = Vector2(100, 20)
	prompt.visible = false
	add_child(prompt)
	prompt_label = prompt
	
	set_meta("is_interacted", false)
	
	# Interactive method
	var interact_callable = func():
		if is_hostile_to_player:
			return # No friendly interaction when hostile!
			
		AudioManager.play_click()
		
		# Open the mercenary menu so the player can select what to give them
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_merc_menu"):
			hud.set("_selected_merc", self)
			hud.open_merc_menu()
		
		# Case 3: Normal Dialogue (NPC has weapon and is fully loaded)
		if npc_type == "vanguard_captain":
			DialogManager.show_dialog([
				{"speaker": npc_name, "text": "Kaelan! You're alive... I thought the Vanguard wiped out the entire project.", "color": Color(1.0, 0.8, 0.2)},
				{"speaker": npc_name, "text": "They lied to us. We were sent here to bury the truth, not save civilians.", "color": Color(1.0, 0.8, 0.2)},
				{"speaker": npc_name, "text": "I'll help you reach the core. Just point me at the horde.", "color": Color(1.0, 0.8, 0.2)}
			])
		elif npc_type == "researcher_elara":
			DialogManager.show_dialog([
				{"speaker": npc_name, "text": "Specimen 73... You actually woke up. The stabilization process worked.", "color": Color(0.4, 1.0, 0.8)},
				{"speaker": npc_name, "text": "I tried to stop them from purging the lab, but it was too late.", "color": Color(0.4, 1.0, 0.8)},
				{"speaker": npc_name, "text": "The Heart Cavern holds the answers. Protect me, and I'll guide you.", "color": Color(0.4, 1.0, 0.8)}
			])
		elif npc_type == "hunter":
			if not Globals.discovered_lore.has(7):
				Globals.discover_lore(7)
				DialogManager.show_dialog(Globals.LORE_FRAGMENTS[7]["dialogue"])
			else:
				DialogManager.show_dialog([
					{
						"speaker": "Hired Soldier",
						"text": "Keep your eyes open, Commander. We've got waves incoming.",
						"color": Color(1.0, 0.4, 0.4)
					}
				])
		else: # pacifist
			if not Globals.discovered_lore.has(8):
				Globals.discover_lore(8)
				DialogManager.show_dialog(Globals.LORE_FRAGMENTS[8]["dialogue"])
			else:
				DialogManager.show_dialog([
					{
						"speaker": "Survivor",
						"text": "I'll try to stay out of the way. Stay safe!",
						"color": Color(0.4, 1.0, 0.4)
					}
				])
				
	set_meta("interact_method", interact_callable)
	
	# Connect triggers
	area.body_entered.connect(func(body):
		if body.is_in_group("player") and not is_dead:
			prompt.visible = true
			body.set_meta("active_crypt", self)
	)
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			prompt.visible = false
			if body.has_meta("active_crypt") and body.get_meta("active_crypt") == self:
				body.remove_meta("active_crypt")
	)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Tick cooldowns
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
		
	if wander_timer > 0.0:
		wander_timer -= delta
		
	if is_hostile_to_player and npc_type == "hostile_hunter":
		if scream_timer > 0.0:
			scream_timer -= delta
		else:
			scream_timer = randf_range(4.0, 7.0)
			scream_subject_73()
			
	# Process behaviors
	if is_hostile_to_player:
		_process_hostile_behavior(delta)
	elif npc_type == "hunter":
		_process_hunter_behavior(delta)
	else:
		_process_pacifist_behavior(delta)
		
	# Move using navigation agent
	var next_pos = nav_agent.get_next_path_position()
	if next_pos.distance_to(global_position) > 2.0:
		var dir = global_position.direction_to(next_pos)
		velocity = dir * move_speed
		look_at(next_pos)
	else:
		velocity = Vector2.ZERO
		
	move_and_slide()
	
	# Update prompt label dynamically
	if prompt_label and is_instance_valid(prompt_label):
		prompt_label.rotation = -global_rotation
		if is_hostile_to_player:
			prompt_label.text = "HOSTILE!"
			prompt_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		elif not has_gun:
			prompt_label.text = "[E] Equip Weapon"
			prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.4))
		elif ammo_count < max_ammo:
			prompt_label.text = "[E] Refill Ammo (%d/%d)" % [ammo_count, max_ammo]
			prompt_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		else:
			prompt_label.text = "[E] Talk (%d/%d)" % [ammo_count, max_ammo]
			prompt_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))

# ---------------------------------------------------------------------------
# Behaviors
# ---------------------------------------------------------------------------
func _process_hunter_behavior(_delta: float) -> void:
	# If no gun or out of ammo, follow player for safety!
	if not has_gun or ammo_count <= 0:
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			nav_agent.target_position = player.global_position
		return
		
	var zombie = _get_nearest_zombie()
	if zombie:
		var dist = global_position.distance_to(zombie.global_position)
		look_at(zombie.global_position)
		
		# Shoot when in range
		if dist <= 380.0:
			if fire_cooldown <= 0.0:
				_fire_at(zombie)
				
		# Move to optimal position
		if dist < 140.0:
			# Too close, back away from zombie
			var dir_away = global_position.direction_to(zombie.global_position) * -1.0
			nav_agent.target_position = global_position + dir_away * 120.0
		elif dist > 260.0:
			# Too far, close the distance
			nav_agent.target_position = zombie.global_position
		else:
			# Satisfactory range, stand ground or slowly wander around player
			if wander_timer <= 0.0:
				_pick_new_wander_target()
	else:
		# No zombies present, follow player if far, otherwise wander
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			var dist_to_player = global_position.distance_to(player.global_position)
			if dist_to_player > 150.0:
				nav_agent.target_position = player.global_position
			elif wander_timer <= 0.0:
				_pick_new_wander_target()
		elif wander_timer <= 0.0 or nav_agent.is_navigation_finished():
			_pick_new_wander_target()

func _process_pacifist_behavior(_delta: float) -> void:
	# Pacifist just wanders around the map
	if wander_timer <= 0.0 or nav_agent.is_navigation_finished():
		_pick_new_wander_target()

func _process_hostile_behavior(_delta: float) -> void:
	var target: Node2D = null
	var min_dist = 999999.0
	
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player) and not player.get("is_dead"):
		var dist = global_position.distance_to(player.global_position)
		if dist < min_dist:
			min_dist = dist
			target = player
			
	var zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in zombies:
		if is_instance_valid(zombie) and not zombie.get("is_dead"):
			var dist = global_position.distance_to(zombie.global_position)
			if dist < min_dist:
				min_dist = dist
				target = zombie
				
	if target:
		look_at(target.global_position)
		
		# Shoot when in range
		if min_dist <= 380.0 and has_gun and ammo_count > 0:
			if fire_cooldown <= 0.0:
				_fire_at(target)
				
		# Keep aggressive distance
		if min_dist > 200.0:
			nav_agent.target_position = target.global_position
		elif min_dist < 120.0:
			var dir_away = global_position.direction_to(target.global_position) * -1.0
			nav_agent.target_position = global_position + dir_away * 100.0
		else:
			if wander_timer <= 0.0:
				_pick_new_wander_target()
	else:
		if wander_timer <= 0.0 or nav_agent.is_navigation_finished():
			_pick_new_wander_target()

func scream_subject_73() -> void:
	var scream_lbl := Label.new()
	scream_lbl.text = "subject 73 DIE!!!"
	scream_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scream_lbl.add_theme_font_size_override("font_size", 10)
	scream_lbl.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	scream_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	scream_lbl.add_theme_constant_override("outline_size", 4)
	
	scream_lbl.position = Vector2(-75, -50)
	scream_lbl.custom_minimum_size = Vector2(150, 20)
	add_child(scream_lbl)
	
	var tw := create_tween()
	tw.tween_property(scream_lbl, "position:y", -75.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(scream_lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(scream_lbl.queue_free)

func provoke() -> void:
	if not is_hostile_to_player:
		is_hostile_to_player = true
		if not has_gun:
			has_gun = true
			equipped_weapon = 0 # basic Pistol
			ammo_count = 99999
		# Update HealthBar fill style to red
		var hb = get_node_or_null("HealthBar")
		if hb:
			var sb_fg = StyleBoxFlat.new()
			sb_fg.bg_color = Color(1.0, 0.2, 0.2)
			hb.add_theme_stylebox_override("fill", sb_fg)
		# Change visual tone to show anger/hostility
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1.5, 0.5, 0.5), 0.2)

func _pick_new_wander_target() -> void:
	var angle = randf_range(0, TAU)
	var dist = randf_range(160.0, 450.0)
	var target_pos = global_position + Vector2.RIGHT.rotated(angle) * dist
	nav_agent.target_position = target_pos
	wander_timer = randf_range(2.0, 5.0)

func _get_nearest_zombie() -> Node2D:
	var zombies = get_tree().get_nodes_in_group("zombies")
	var nearest: Node2D = null
	var min_dist = INF
	for z in zombies:
		if is_instance_valid(z) and not z.is_dead:
			var dist = global_position.distance_to(z.global_position)
			if dist < min_dist:
				min_dist = dist
				nearest = z
	return nearest

func _fire_at(target: Node2D) -> void:
	if ammo_count <= 0:
		return
		
	# Consume ammo if not infinite hostile weapon
	if ammo_count < 90000:
		ammo_count -= 1
		
	fire_cooldown = fire_rate
	
	var dir = global_position.direction_to(target.global_position)
	dir = dir.rotated(randf_range(-0.06, 0.06))
	
	var b = _bullet_scene.instantiate()
	b.is_enemy_bullet = is_hostile_to_player
	
	var dmg = 18.0
	var speed = 750.0
	if equipped_weapon == 1: # MG
		dmg = 12.0
		speed = 850.0
	elif equipped_weapon == 2: # Silencer
		dmg = 15.0
		speed = 700.0
		
	b.initialize(
		dir, 
		dmg, 
		speed, 
		equipped_bullet_type
	)
	
	AudioManager.play_shoot(equipped_weapon if equipped_weapon >= 0 else 0)
	if is_hostile_to_player:
		b.set_meta("from_hostile_npc", true)
	get_parent().add_child(b)
	b.global_position = global_position + dir * 22.0

# ---------------------------------------------------------------------------
# Damage & Death
# ---------------------------------------------------------------------------
func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	
	# Update health bar value
	var hb = get_node_or_null("HealthBar")
	if hb:
		hb.value = health
	
	# Red hit flash tween
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.2, 0.2), 0.05)
	tw.tween_property(self, "modulate", Color.WHITE if not is_hostile_to_player else Color(1.5, 0.5, 0.5), 0.15)
	
	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	set_process(false)
	set_physics_process(false)
	
	# Award EXP directly
	Globals.add_score(60)
	
	# Drop physical bullet pickup
	var bullet_pickup = load("res://Scenes/Pickups/bullet_pickup.tscn").instantiate()
	bullet_pickup.position = global_position
	bullet_pickup.bullet_type_index = 0
	bullet_pickup.amount = randi_range(15, 30)
	get_parent().add_child.call_deferred(bullet_pickup)
	
	# Turn into a zombie!
	var zombie: Node2D = null
	if npc_type == "hunter":
		zombie = _zombie_gunner_scene.instantiate()
	else:
		zombie = _zombie_bomber_scene.instantiate()
		
	if zombie:
		zombie.global_position = global_position
		get_parent().add_child.call_deferred(zombie)
		
	# Trigger death animation
	var tw := create_tween()
	tw.tween_property(self, "scale", scale * 1.3, 0.1)
	tw.parallel().tween_property(self, "modulate", Color(1.0, 0.1, 0.1, 0.0), 0.15)
	tw.tween_callback(queue_free)
