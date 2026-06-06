extends Area2D

# ---------------------------------------------------------------------------
# Stats (set by whoever spawns the bullet)
# ---------------------------------------------------------------------------
@export var speed: float = 800.0
@export var damage: float = 25.0
@export var max_range: float = 600.0

var _direction: Vector2 = Vector2.RIGHT
var _distance_traveled: float = 0.0
var bullet_type: int = 0
var trail_particles: CPUParticles2D
var is_enemy_bullet: bool = false
var pierces: bool = false
var _hit_bodies: Array[Node2D] = []

# ---------------------------------------------------------------------------
# Setup — call this right after instancing
# ---------------------------------------------------------------------------
func initialize(dir: Vector2, dmg: float, spd: float = 800.0, b_type: int = 0) -> void:
	_direction = dir.normalized()
	damage = dmg
	speed = spd
	rotation = _direction.angle()
	bullet_type = b_type

func _ready() -> void:
	z_index = 10
	# Add dynamic trail particles depending on the bullet type
	trail_particles = CPUParticles2D.new()
	trail_particles.z_index = 10
	trail_particles.amount = 8
	trail_particles.lifetime = 0.15
	trail_particles.local_coords = false
	trail_particles.gravity = Vector2.ZERO
	trail_particles.initial_velocity_min = 0.0
	trail_particles.initial_velocity_max = 10.0
	trail_particles.scale_amount_min = 2.0
	trail_particles.scale_amount_max = 4.0
	
	match bullet_type:
		0: # Standard: orange/yellow
			trail_particles.color = Color(1.0, 0.8, 0.2)
		1: # Quick: light blue sparks
			trail_particles.color = Color(0.1, 0.6, 1.0)
			trail_particles.amount = 12
			trail_particles.lifetime = 0.2
		2: # Paralysis: purple lightning
			trail_particles.color = Color(0.7, 0.1, 1.0)
			trail_particles.amount = 10
			trail_particles.scale_amount_min = 3.0
		3: # Knockback: green shockwave
			trail_particles.color = Color(0.1, 0.9, 0.1)
			trail_particles.scale_amount_max = 5.0
		4: # Slow down: icy cyan/white
			trail_particles.color = Color(0.3, 0.9, 1.0)
			trail_particles.amount = 10

	add_child(trail_particles)

# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var step := _direction * speed * delta
	position += step
	_distance_traveled += step.length()
	if _distance_traveled >= max_range:
		queue_free()

# ---------------------------------------------------------------------------
# Hit detection
# ---------------------------------------------------------------------------
func _on_body_entered(body: Node2D) -> void:
	if body in _hit_bodies:
		return
	_hit_bodies.append(body)

	if is_enemy_bullet:
		if body.is_in_group("player") or body.is_in_group("npcs"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			# Apply effect on player
			if body.has_method("apply_bullet_effect"):
				body.apply_bullet_effect(bullet_type, _direction)
			_spawn_hit_particles()
			queue_free()
		elif body.is_in_group("zombies"):
			if has_meta("from_hostile_npc") and get_meta("from_hostile_npc") == true:
				if body.has_method("take_damage"):
					body.take_damage(damage)
				if body.has_method("apply_bullet_effect"):
					body.apply_bullet_effect(bullet_type, _direction)
				_spawn_hit_particles()
				queue_free()
				return
			# Enemy bullets ignore other zombies
			return
		else:
			# Wall hit
			_spawn_wall_hit_particles()
			queue_free()
	else:
		if body.is_in_group("zombies"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			if body.has_method("apply_bullet_effect"):
				body.apply_bullet_effect(bullet_type, _direction)
			_spawn_hit_particles()
			if not pierces:
				queue_free()
		elif body.is_in_group("npcs"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			if body.has_method("provoke"):
				body.provoke()
			_spawn_hit_particles()
			if not pierces:
				queue_free()
		elif body.is_in_group("player"):
			# Player bullets ignore player
			return
		else:
			_spawn_wall_hit_particles()
			if not pierces:
				queue_free()

func _spawn_hit_particles() -> void:
	var p := CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = global_position
	p.z_index = 10  # Ensure it renders on top of characters and terrain
	
	# Particle settings for a realistic backwards blood/energy splatter
	p.amount = 12
	p.lifetime = 0.3
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = -_direction
	p.spread = 50.0
	p.gravity = Vector2.ZERO # Keep particles on target plane
	
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 160.0
	
	# Select color based on bullet type
	var colors := [
		Color(0.85, 0.05, 0.05, 0.95),  # Standard: red
		Color(0.1, 0.6, 1.0, 0.95),     # Quick: blue
		Color(0.7, 0.1, 1.0, 0.95),     # Paralysis: purple
		Color(0.1, 0.9, 0.1, 0.95),     # Knockback: green
		Color(0.3, 0.9, 1.0, 0.95)      # Slow down: icy cyan
	]
	p.color = colors[bullet_type]
	
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.emitting = true
	
	# Self-clean after particles finish
	var t := get_tree().create_timer(0.5)
	t.timeout.connect(p.queue_free)

func _spawn_wall_hit_particles() -> void:
	var p := CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = global_position
	p.z_index = 10
	
	p.amount = 8
	p.lifetime = 0.25
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = -_direction
	p.spread = 45.0
	p.gravity = Vector2.ZERO
	
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 120.0
	
	# Concrete dust/sparks color
	p.color = Color(0.75, 0.75, 0.75, 0.9)
	
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.emitting = true
	
	var t := get_tree().create_timer(0.4)
	t.timeout.connect(p.queue_free)
