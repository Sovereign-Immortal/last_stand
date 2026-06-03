extends CharacterBody2D

# ------------------------------------------------------------------
# 1. Exports (unchanged)
# ------------------------------------------------------------------
@export var strength : float = 2.0
@export var zombie_type : String = "basic"
@export var move_speed : float = 160.0
@export var sight_range : float = 250.0
@export var formation_radius : float = 80.0
@export var max_health : float = 60.0
@export var damage : int = 12
@export var attack_range : float = 28.0
@export var attack_cooldown : float = 0.9
@export var score_value : int = 15   # points awarded on kill

var _pickup_scene := preload("res://Scenes/Pickups/ammo_pickup.tscn")
var _bullet_pickup_scene := preload("res://Scenes/Pickups/bullet_pickup.tscn")
var _bullet_scene := preload("res://Scenes/Projectiles/bullet.tscn")
var _health_pickup_scene := preload("res://Scenes/Pickups/health_pickup.tscn")

var _gunner_shoot_timer: float = 4.0
var _exploded: bool = false
var _is_primed: bool = false
var _prime_timer: float = 0.0

# ------------------------------------------------------------------
# 2. Horde / leader data
# ------------------------------------------------------------------
var leader : CharacterBody2D = null
var followers : Array = []
var formation_offset : Vector2 = Vector2.ZERO
var current_pattern : int = 0
var health : float
var is_dead : bool = false
var _attack_timer : float = 0.0   # counts down to next allowed attack

# Status effects
var stun_timer : float = 0.0
var slow_timer : float = 0.0
var current_speed : float = 160.0

# ------------------------------------------------------------------
# 3. Target (player) & Navigation
# ------------------------------------------------------------------
var player_target : Node2D = null
var nav_agent : NavigationAgent2D

# ------------------------------------------------------------------
# 4. Movement helpers
# ------------------------------------------------------------------
var wander_target : Vector2
var wander_timer : float = 0.0

enum Pattern { SCOUT = 0, CHASE = 1, ENCIRCLE = 2, RANDOM = 3 }

# ------------------------------------------------------------------
# _ready
# ------------------------------------------------------------------
func _ready():
	health = max_health
	current_speed = move_speed
	add_to_group("zombies")
	$DetectionArea/CollisionShape2D.shape.radius = sight_range

	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 15.0
	nav_agent.target_desired_distance = 15.0
	nav_agent.avoidance_enabled = false
	add_child(nav_agent)

	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_elect_horde_leader)
	add_child(timer)

# ------------------------------------------------------------------
# _process – runs every frame
# ------------------------------------------------------------------
func _process(delta):
	if is_dead:
		return

	# Tick status effect timers
	if stun_timer > 0.0:
		stun_timer -= delta
	if slow_timer > 0.0:
		slow_timer -= delta

	current_speed = move_speed
	if stun_timer > 0.0:
		current_speed = 0.0
	elif slow_timer > 0.0:
		current_speed = move_speed * 0.4 # 60% slow

	# Cyborg persistent tracking: always target the player node
	if zombie_type == "cyborg zombie":
		var p = get_tree().get_first_node_in_group("player")
		if p and not p.get("is_dead"):
			player_target = p

	# Dynamically target/verify player target to avoid getting stuck or losing target
	if player_target == null or not is_instance_valid(player_target) or player_target.get("is_dead") == true:
		var p = get_tree().get_first_node_in_group("player")
		if p and not p.get("is_dead"):
			player_target = p
		else:
			player_target = null

	# Bomber priming logic
	if zombie_type == "bomber" and player_target:
		var dist = global_position.distance_to(player_target.global_position)
		if dist < 180.0 and not _is_primed:
			_is_primed = true
			_prime_timer = 1.2
			# Trigger warning groan
			AudioManager.play_zombie_groan()
			
		if _is_primed:
			_prime_timer -= delta
			current_speed = move_speed * 1.75 # speed rush
			
			# Flashing warning effect
			var flash_freq := 18.0
			var flash := sin(Time.get_ticks_msec() * 0.001 * flash_freq) * 0.5 + 0.5
			modulate = Color(2.0, 0.3, 0.3).lerp(Color.WHITE, flash)
			
			if _prime_timer <= 0.0:
				_explode()
				return

	if player_target:
		look_at(player_target.global_position)  # visual only
		nav_agent.target_position = player_target.global_position

	# Ensure leader is valid
	if not is_instance_valid(leader):
		_become_leader()

	if leader == self:
		_update_leader(delta)
	else:
		_update_follower(delta)

	if zombie_type == "gunner" and player_target:
		_gunner_shoot_timer -= delta
		if _gunner_shoot_timer <= 0.0:
			_gunner_shoot_timer = 4.0
			_gunner_shoot()

	move_and_slide()

	if zombie_type == "bomber" and get_slide_collision_count() > 0:
		_explode()
		return

	_try_melee_attack(delta)

# ------------------------------------------------------------------
# Melee attack
# ------------------------------------------------------------------
func _try_melee_attack(delta: float) -> void:
	if player_target == null or is_dead:
		return
	if player_target.get("is_dead") == true:
		return
	_attack_timer -= delta
	var dist := global_position.distance_to(player_target.global_position)
	if dist <= attack_range and _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		if player_target.has_method("take_damage"):
			player_target.take_damage(damage)

# ------------------------------------------------------------------
# 5. Leader election (unchanged)
# ------------------------------------------------------------------
func _elect_horde_leader():
	var nearby = []
	for body in $DetectionArea.get_overlapping_bodies():
		if body.is_in_group("zombies") and body != self and body.zombie_type == zombie_type:
			nearby.append(body)

	if nearby.is_empty():
		_become_leader()
		return

	var strongest = self
	for z in nearby:
		if is_instance_valid(z) and z.strength > strongest.strength:
			strongest = z

	if strongest == self:
		_become_leader()
	else:
		_follow_leader(strongest)

func _become_leader():
	if leader == self:
		return
	if is_instance_valid(leader) and leader != self:
		leader.remove_follower(self)
	leader = self
	followers.clear()

func _follow_leader(new_leader):
	if not is_instance_valid(new_leader):
		_become_leader()
		return
	if leader == new_leader:
		return
	if is_instance_valid(leader) and leader != self:
		leader.remove_follower(self)
	leader = new_leader
	leader.add_follower(self)

func add_follower(follower):
	if not is_instance_valid(follower):
		return
	if follower not in followers:
		followers.append(follower)
		_calculate_formation_offsets()

func remove_follower(follower):
	followers.erase(follower)
	_calculate_formation_offsets()

func _calculate_formation_offsets():
	# Filter out any freed/dead followers
	var valid_followers = []
	for f in followers:
		if is_instance_valid(f):
			valid_followers.append(f)
	followers = valid_followers

	var count = followers.size()
	if count == 0: return
	var angle_step = TAU / count
	for i in range(count):
		var angle = i * angle_step
		if is_instance_valid(followers[i]):
			followers[i].formation_offset = Vector2.RIGHT.rotated(angle) * formation_radius

# ------------------------------------------------------------------
# 6. Leader behaviour – smarter state switching
# ------------------------------------------------------------------
func _update_leader(delta):
	# Decide pattern using hysteresis to avoid flickering
	var dist_to_player = INF
	if player_target:
		dist_to_player = global_position.distance_to(player_target.global_position)

	# Transition logic
	match current_pattern:
		Pattern.SCOUT, Pattern.RANDOM:
			if player_target:
				if dist_to_player < 150:
					current_pattern = Pattern.ENCIRCLE
				else:
					current_pattern = Pattern.CHASE
		Pattern.CHASE:
			if not player_target:
				_enter_wander_state()
			elif dist_to_player < 100:  # close enough to encircle
				current_pattern = Pattern.ENCIRCLE
		Pattern.ENCIRCLE:
			if not player_target:
				_enter_wander_state()
			elif dist_to_player > 200:  # player escaped
				current_pattern = Pattern.CHASE

	# Run pattern
	match current_pattern:
		Pattern.CHASE:   _chase(delta)
		Pattern.ENCIRCLE: _encircle_leader(delta)
		Pattern.SCOUT:   _scout(delta)
		Pattern.RANDOM:  _random_wander(delta)

	# Apply separation force when chasing/encircling player to avoid stacking with followers
	if player_target:
		velocity += _separation() * 1.5

func _enter_wander_state():
	wander_timer = 2.0
	current_pattern = Pattern.RANDOM if randi() % 2 == 0 else Pattern.SCOUT

# ------------------------------------------------------------------
# 7. Improved pattern implementations for leader
# ------------------------------------------------------------------
func _chase(_delta):
	if player_target:
		var next_pos = nav_agent.get_next_path_position()
		# Fallback to direct chasing if navigation is not ready or fails
		if next_pos.distance_to(global_position) < 2.0:
			next_pos = player_target.global_position
		var desired_vel = global_position.direction_to(next_pos) * current_speed
		var steer_weight = 18.0 if zombie_type == "cyborg zombie" else 10.0
		velocity = _steer_toward(velocity, desired_vel, steer_weight)  # smooth steering
	else:
		velocity = Vector2.ZERO

func _encircle_leader(_delta):
	if not player_target:
		return

	var to_player = player_target.global_position - global_position
	var current_dist = to_player.length()
	if current_dist > 0:
		if current_dist > attack_range * 2.0:
			# Pathfind to player when far away
			var next_pos = nav_agent.get_next_path_position()
			if next_pos.distance_to(global_position) < 2.0:
				next_pos = player_target.global_position
			var desired_vel = global_position.direction_to(next_pos) * current_speed
			velocity = _steer_toward(velocity, desired_vel, 5.0)
		else:
			# Close range: strafe around player and close distance to attack!
			var desired_dir = to_player.normalized()
			var strafe = desired_dir.rotated(PI/2)  # 90 degrees CCW
			var desired_vel = strafe * current_speed * 0.8
			var target_dist = clampf(attack_range - 4.0, 10.0, 30.0)
			var dist_error = current_dist - target_dist
			var correction = desired_dir * dist_error * 2.0
			velocity = _steer_toward(velocity, desired_vel + correction, 5.0)
	else:
		velocity = Vector2.ZERO

func _scout(_delta):
	if wander_target == Vector2.ZERO:
		wander_target = _random_far_point()
	var desired_vel = global_position.direction_to(wander_target) * current_speed
	velocity = _steer_toward(velocity, desired_vel, 5.0)
	if global_position.distance_to(wander_target) < 10:
		wander_target = _random_far_point()

func _random_wander(_delta):
	if wander_target == Vector2.ZERO:
		wander_target = global_position + Vector2(randf_range(-100,100), randf_range(-100,100))
	var desired_vel = global_position.direction_to(wander_target) * current_speed * 0.5
	velocity = _steer_toward(velocity, desired_vel, 5.0)
	if global_position.distance_to(wander_target) < 10:
		wander_target = Vector2.ZERO

func _random_far_point():
	var angle = randf_range(0, TAU)
	var dist = randf_range(300, 500)
	return global_position + Vector2.RIGHT.rotated(angle) * dist

# ------------------------------------------------------------------
# 8. Follower behaviour – now with flocking for smooth encirclement
# ------------------------------------------------------------------
func _update_follower(delta):
	if leader == null or leader == self:
		return

	# Swarm the player directly if we have a target
	if player_target:
		var next_pos = nav_agent.get_next_path_position()
		if next_pos.distance_to(global_position) < 2.0:
			next_pos = player_target.global_position
		velocity = _arrive_to(next_pos, current_speed)
		velocity += _separation() * 2.0
		return

	# Followers copy the leader's pattern, but use smart steering
	match leader.current_pattern:
		Pattern.CHASE:
			_follower_chase(delta)
		Pattern.ENCIRCLE:
			_follower_encircle(delta)
		Pattern.SCOUT, Pattern.RANDOM:
			_follower_scout_random(delta)

func _follower_chase(_delta):
	# Move toward leader's player target plus formation offset, but allow some flocking
	if leader.player_target:
		var desired_pos = leader.player_target.global_position + formation_offset
		velocity = _arrive_to(desired_pos, current_speed)
		# Add separation from other zombies
		velocity += _separation() * 2.0
	else:
		_follow_leader_position()

func _follower_encircle(_delta):
	# Encircle the player: position self on a circle around the player, using formation offset as angle anchor.
	if leader.player_target:
		var target = leader.player_target
		# Compute dynamic circle point based on formation offset rotated to match the player's direction
		var dir_to_player = target.global_position - leader.global_position
		var angle = dir_to_player.angle() if dir_to_player.length() > 0 else 0
		# Rotate the formation offset by the player‑leader direction so the circle always faces the player
		var rotated_offset = formation_offset.rotated(angle)
		var desired_pos = target.global_position + rotated_offset

		velocity = _arrive_to(desired_pos, current_speed)
		velocity += _separation() * 1.5
	else:
		_follow_leader_position()

func _follower_scout_random(_delta):
	# Stay in formation behind the leader, with separation
	var target_pos = leader.global_position + formation_offset
	velocity = _arrive_to(target_pos, current_speed * 0.8)
	velocity += _separation() * 2.0

func _follow_leader_position():
	var target_pos = leader.global_position + formation_offset
	velocity = _arrive_to(target_pos, current_speed)

# ------------------------------------------------------------------
# 9. Steering helpers
# ------------------------------------------------------------------
func _arrive_to(target: Vector2, max_speed: float) -> Vector2:
	var desired = target - global_position
	var dist = desired.length()
	if dist < 5.0:
		return Vector2.ZERO
	# Slow down when near the target
	var speed = max_speed * (dist / 50.0) if dist < 50.0 else max_speed
	speed = clamp(speed, 20.0, max_speed)
	return desired.normalized() * speed

func _separation() -> Vector2:
	var steer = Vector2.ZERO
	var count = 0
	for body in $DetectionArea.get_overlapping_bodies():
		if body.is_in_group("zombies") and body != self:
			var away = global_position - body.global_position
			var dist = away.length()
			if dist > 0 and dist < 40.0:  # separation radius
				steer += away.normalized() / dist
				count += 1
	if count > 0:
		steer /= count
	return steer * current_speed  # scale to meaningful force

func _steer_toward(current: Vector2, desired: Vector2, weight: float) -> Vector2:
	# Simple steering: move current velocity toward desired velocity
	var steer = desired - current
	steer = steer.limit_length(weight)
	return current + steer

# ------------------------------------------------------------------
# 10. DetectionArea signal handlers (wired in .tscn)
# ------------------------------------------------------------------
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_target = body

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player_target:
		player_target = null

# ------------------------------------------------------------------
# 11. Health & Death
# ------------------------------------------------------------------
func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	AudioManager.play_zombie_hit()
	# Red hit flash
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.2, 0.2), 0.05)
	tw.tween_property(self, "modulate", Color.WHITE, 0.15)
	if health <= 0.0:
		_die()

func _die() -> void:
	is_dead = true
	set_process(false)
	set_physics_process(false)
	if is_instance_valid(leader) and leader != self:
		leader.remove_follower(self)
	for f in followers:
		if is_instance_valid(f):
			f.leader = null
			f._become_leader()
	
	if zombie_type == "bomber":
		_explode()
		return
		
	if zombie_type == "heart":
		for i in range(3):
			var hp_orb = _health_pickup_scene.instantiate()
			hp_orb.global_position = global_position + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
			get_parent().add_child.call_deferred(hp_orb)
			
	AudioManager.play_zombie_die()
	Globals.add_score(score_value)
	if randf() < 0.4:
		if randf() < 0.35:
			_drop_bullet_ammo()
		else:
			_drop_ammo()
	var tw := create_tween()
	tw.tween_property(self, "scale", scale * 1.6, 0.1)
	tw.parallel().tween_property(self, "modulate", Color(1, 0.1, 0.1, 0.0), 0.15)
	tw.tween_callback(queue_free)

func _drop_ammo() -> void:
	var pickup := _pickup_scene.instantiate()
	# Weight toward MG ammo (index 1) since it depletes fastest
	var weights := [0.15, 0.60, 0.25]
	var roll := randf()
	if roll < weights[0]:
		# Spawn standard bullet pickup instead of obsolete gun ammo
		var bullet_pickup := _bullet_pickup_scene.instantiate()
		bullet_pickup.bullet_type_index = 0
		bullet_pickup.amount = randi_range(30, 55)
		bullet_pickup.position = global_position
		get_parent().add_child.call_deferred(bullet_pickup)
		pickup.queue_free()
		return
	elif roll < weights[0] + weights[1]:
		pickup.weapon_index = 1
		pickup.amount = randi_range(20, 40)
	else:
		pickup.weapon_index = 2
		pickup.amount = randi_range(5, 12)
	pickup.position = global_position
	get_parent().add_child.call_deferred(pickup)

func _drop_bullet_ammo() -> void:
	var pickup := _bullet_pickup_scene.instantiate()
	pickup.bullet_type_index = randi_range(1, 4)
	var amounts = [0, randi_range(15, 25), randi_range(5, 10), randi_range(8, 12), randi_range(10, 18)]
	pickup.amount = amounts[pickup.bullet_type_index]
	pickup.position = global_position
	get_parent().add_child.call_deferred(pickup)

func apply_bullet_effect(bullet_type: int, dir: Vector2) -> void:
	match bullet_type:
		0, 1: # Standard, Quick
			pass
		2: # Paralysis: stun for 1.5 seconds
			stun_timer = 1.5
			# Flash purple
			var tw := create_tween()
			tw.tween_property(self, "modulate", Color(0.7, 0.1, 1.0), 0.1)
			tw.tween_property(self, "modulate", Color.WHITE, 0.2)
		3: # Knockback: push back velocity by large force
			velocity += dir * 550.0
			# Flash green
			var tw := create_tween()
			tw.tween_property(self, "modulate", Color(0.1, 0.9, 0.1), 0.1)
			tw.tween_property(self, "modulate", Color.WHITE, 0.2)
		4: # Slow down: slow by 60% for 3.0 seconds
			slow_timer = 3.0
			# Flash cyan/light blue
			var tw := create_tween()
			tw.tween_property(self, "modulate", Color(0.3, 0.9, 1.0), 0.1)
			tw.tween_property(self, "modulate", Color.WHITE, 0.2)

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	is_dead = true
	
	# Spawn explosion particles
	var particles := CPUParticles2D.new()
	particles.amount = 45
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.5
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 280.0
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0
	particles.color = Color(1.0, 0.45, 0.0) # Fiery orange
	get_parent().add_child.call_deferred(particles)
	particles.global_position = global_position
	
	# Delay setting emitting to ensure it is in the tree
	get_tree().create_timer(0.01).timeout.connect(func(): particles.emitting = true)
	
	# Damage nearby characters
	var player = get_tree().get_first_node_in_group("player")
	if player and not player.is_dead:
		var dist = global_position.distance_to(player.global_position)
		if dist < 350.0:
			AudioManager.trigger_tinnitus(2.5)
			if player.has_method("trigger_explosion_dialog"):
				player.trigger_explosion_dialog()
		if dist < 220.0:
			if player.has_method("_shake_screen"):
				player._shake_screen(9.0, 0.35)
			var dmg = int(lerpf(35.0, 5.0, dist / 220.0))
			player.take_damage(dmg)
			
	var zombies = get_tree().get_nodes_in_group("zombies")
	for z in zombies:
		if z != self and is_instance_valid(z) and not z.is_dead:
			var dist = global_position.distance_to(z.global_position)
			if dist < 150.0:
				var dmg = int(lerpf(75.0, 10.0, dist / 150.0))
				z.take_damage(dmg)
				
	AudioManager.play_zombie_die()
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free)
	queue_free()

func _gunner_shoot() -> void:
	if is_dead or player_target == null:
		return
	
	# Select a random specialty bullet type (index 1 to 4)
	var random_bullet_type := randi_range(1, 4)
	var dir := global_position.direction_to(player_target.global_position)
	
	var b: Area2D = _bullet_scene.instantiate()
	b.is_enemy_bullet = true
	b.initialize(
		dir, 
		8.0,      # Bullet damage
		600.0,    # Bullet speed
		random_bullet_type
	)
	
	# Pistol shot audio
	AudioManager.play_shoot(0)
	
	get_parent().add_child(b)
	b.global_position = global_position + dir * 24.0
	
	var colors = [
		Color(1.0, 0.9, 0.0), # Standard
		Color(0.1, 0.6, 1.0), # Quick
		Color(0.7, 0.1, 1.0), # Paralysis
		Color(0.1, 0.9, 0.1), # Knockback
		Color(0.3, 0.9, 1.0)  # Slow Down
	]
	if b.has_node("Sprite2D"):
		b.get_node("Sprite2D").modulate = colors[random_bullet_type]
