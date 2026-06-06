extends Area2D

var explosive_type: String = "grenade" # "grenade", "landmine", "ice_bomb"
var damage: float = 200.0
var explosion_radius: float = 150.0

var _timer: float = 0.0
var _triggered: bool = false
var _velocity := Vector2.ZERO
var _player_ref: Node2D = null

func _ready() -> void:
	if explosive_type == "grenade":
		_timer = 2.0
	elif explosive_type == "ice_bomb":
		_timer = 2.0
		damage = 50.0 # mostly for freezing
	elif explosive_type == "landmine":
		_timer = -1.0 # triggered by body
		damage = 300.0
		
	# Setup collision shape for the physical object
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	col.shape = circle
	add_child(col)
	
	# Visual
	var rect = ColorRect.new()
	rect.size = Vector2(16, 16)
	rect.position = Vector2(-8, -8)
	if explosive_type == "grenade":
		rect.color = Color(0.2, 0.8, 0.2) # green
	elif explosive_type == "landmine":
		rect.color = Color(0.8, 0.2, 0.2) # red
	elif explosive_type == "ice_bomb":
		rect.color = Color(0.2, 0.8, 1.0) # ice blue
	add_child(rect)
	
	# Zombies are on collision layer 2. Set mask to 2 to detect them.
	collision_mask = 2
	body_entered.connect(_on_body_entered)

func setup(type: String, dir: Vector2, speed: float) -> void:
	explosive_type = type
	_velocity = dir * speed

func _physics_process(delta: float) -> void:
	if _velocity.length() > 0:
		global_position += _velocity * delta
		_velocity = _velocity.move_toward(Vector2.ZERO, 800.0 * delta)
		
	if _timer > 0.0 and not _triggered:
		_timer -= delta
		if _timer <= 0.0:
			explode()

func _on_body_entered(body: Node2D) -> void:
	if explosive_type == "landmine" and not _triggered and body.is_in_group("zombies"):
		explode()

func explode() -> void:
	if _triggered:
		return
	_triggered = true
	
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
	
	if explosive_type == "ice_bomb":
		particles.color = Color(0.2, 0.8, 1.0) # Icy blue
	else:
		particles.color = Color(1.0, 0.45, 0.0) # Fiery orange
		
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	
	# Clean up particles after lifetime
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
	
	# Damage/Freeze zombies/NPCs in radius using distance check (super robust)
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if is_instance_valid(zombie) and zombie.has_method("take_damage"):
			var dist = global_position.distance_to(zombie.global_position)
			if dist <= explosion_radius:
				zombie.take_damage(damage)
				if explosive_type == "ice_bomb":
					zombie.set("slow_timer", 5.0)
					zombie.set("stun_timer", 1.5)
					if zombie.has_method("apply_bullet_effect"):
						zombie.apply_bullet_effect(4, Vector2.ZERO) # 4 is Slow Down
					
	for npc in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(npc) and npc.has_method("take_damage"):
			var dist = global_position.distance_to(npc.global_position)
			if dist <= explosion_radius:
				npc.take_damage(damage)
				if npc.has_method("provoke"):
					npc.provoke()
					
	# Screen shake
	if _player_ref and _player_ref.has_method("_shake_screen"):
		_player_ref._shake_screen(8.0, 0.3)
		
	queue_free()
