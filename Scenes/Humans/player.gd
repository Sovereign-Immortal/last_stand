extends CharacterBody2D

# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------
@export var MAX_SPEED: float = 300.0
@export var ACCELERATION: float = 1500.0
@export var FRICTION: float = 1200.0
@export var max_health: int = 100

# ---------------------------------------------------------------------------
# Weapon definitions
# ---------------------------------------------------------------------------
const WEAPONS: Array[Dictionary] = [
	{
		"name":        "Pistol",
		"damage":      25.0,
		"fire_rate":   0.35,   # seconds between shots
		"bullet_spd":  800.0,
		"ammo":        -1,     # -1 = unlimited
		"spread":      0.04,   # radians of random spread
		"sprite":      "res://Last Stand Assets/Characters/PNG/Man Blue/manBlue_gun.png",
		"weight":      1.0,    # Normal speed
		"description": "Pistol: Light-weight, reliable, and works every time. Standard infinite ammo fallback."
	},
	{
		"name":        "Machine Gun",
		"damage":      12.0,
		"fire_rate":   0.08,
		"bullet_spd":  900.0,
		"ammo":        120,
		"spread":      0.12,
		"sprite":      "res://Last Stand Assets/Characters/PNG/Man Blue/manBlue_machine.png",
		"weight":      0.50,   # Slows player down by 50% (increased weight)
		"description": "Machine Gun: Fast and strong, grinds hordes to dust, but very heavy (slows movement speed)."
	},
	{
		"name":        "Silencer",
		"damage":      65.0,   # Increased power from 40 to 65
		"fire_rate":   0.75,   # Slightly slower firing speed as requested
		"bullet_spd":  700.0,
		"ammo":        30,
		"spread":      0.01,
		"sprite":      "res://Last Stand Assets/Characters/PNG/Man Blue/manBlue_silencer.png",
		"weight":      0.9,    # Slows player down by 10%
		"description": "Silencer: Light, quick, and sneaky. High damage, but has a slower fire rate."
	},
]


# Bullet Type data
const BULLET_TYPES: Array[Dictionary] = [
	{
		"name": "Standard",
		"damage_mult": 1.0,
		"speed_mult": 1.0,
		"color": Color(1.0, 0.9, 0.0),
		"ammo": 300, # Starts limited
	},
	{
		"name": "Quick",
		"damage_mult": 0.8,
		"speed_mult": 1.6,
		"color": Color(0.1, 0.6, 1.0),
		"ammo": 50,
	},
	{
		"name": "Paralysis",
		"damage_mult": 0.5,
		"speed_mult": 0.9,
		"color": Color(0.7, 0.1, 1.0),
		"ammo": 15,
	},
	{
		"name": "Knockback",
		"damage_mult": 1.2,
		"speed_mult": 1.0,
		"color": Color(0.1, 0.9, 0.1),
		"ammo": 20,
	},
	{
		"name": "Slow Down",
		"damage_mult": 0.9,
		"speed_mult": 1.1,
		"color": Color(0.3, 0.9, 1.0),
		"ammo": 30,
	}
]

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
var health: int
var is_dead: bool = false

var current_weapon_index: int = 0
var carried_weapons: Array[int] = [0]
var active_slot: int = 0
var ammo_remaining: Array[int] = [-1, 0, 0] # MG/Silencer start locked at 0
var bullet_ammo: Array[int] = [300, 0, 0, 0, 0] # Starting standard bullet at 300, others 0
var current_bullet_type: int = 0
var fire_cooldown: float = 0.0
var is_firing: bool = false
var stun_timer: float = 0.0
var slow_timer: float = 0.0
var _pickup_scene := preload("res://Scenes/Pickups/ammo_pickup.tscn")

# Camera shake state
var _shake_amount: float = 0.0
var _shake_timer: float = 0.0
var _camera: Camera2D = null

# VFX nodes (created at runtime)
var _muzzle_flash: CPUParticles2D = null
var _shell_casings: CPUParticles2D = null

@onready var sprite: Sprite2D = $Sprite2D
var bullet_container: Node2D

var bullet_scene: PackedScene = preload("res://Scenes/Projectiles/bullet.tscn")

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal died
signal health_changed(new_health: int, max_h: int)
signal weapon_changed(weapon_name: String, ammo: int)
signal ammo_changed(ammo: int)
signal bullet_changed(bullet_name: String, ammo: int)
signal weapon_fired

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	health = max_health
	# Bullet container at root level (keeps bullets from moving with camera)
	var root := get_tree().root.get_child(0)
	if root.has_node("Bullets"):
		bullet_container = root.get_node("Bullets")
	else:
		bullet_container = Node2D.new()
		bullet_container.name = "Bullets"
		root.add_child(bullet_container)

	# Cache camera (added to player instance in root.tscn)
	_camera = get_node_or_null("Camera2D")

	_setup_muzzle_flash()
	_setup_shell_casings()
	_notify_bullet_changed()
	_apply_weapon_sprite()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Tick status effect timers
	if stun_timer > 0.0:
		stun_timer -= delta
	if slow_timer > 0.0:
		slow_timer -= delta

	# --- Screen shake ---
	if _shake_timer > 0.0:
		_shake_timer -= delta
		if _camera:
			_camera.offset = Vector2(
				randf_range(-_shake_amount, _shake_amount),
				randf_range(-_shake_amount, _shake_amount)
			)
	else:
		if _camera:
			_camera.offset = Vector2.ZERO

	# --- Movement ---
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down").normalized()
	if input_vector != Vector2.ZERO:
		var speed_mult: float = WEAPONS[current_weapon_index].get("weight", 1.0)
		if stun_timer > 0.0:
			speed_mult = 0.0
		elif slow_timer > 0.0:
			speed_mult *= 0.5 # 50% slow down effect
		velocity = velocity.move_toward(input_vector * MAX_SPEED * speed_mult, ACCELERATION * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	look_at(get_global_mouse_position())

	# --- Weapon cooldown tick ---
	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	# --- Shooting ---
	var weapon := WEAPONS[current_weapon_index]
	var press := Input.is_action_just_pressed("shoot")
	var hold  := Input.is_action_pressed("shoot")

	# Machine gun auto-fires while held; pistol/silencer require a fresh press
	var should_fire: bool
	if stun_timer > 0.0:
		should_fire = false
	elif current_weapon_index == 1:  # Machine Gun
		should_fire = hold and fire_cooldown <= 0.0
	else:
		should_fire = press and fire_cooldown <= 0.0

	if should_fire:
		_fire(weapon)

	# --- Weapon switching ---
	if Input.is_action_just_pressed("weapon_1"):
		_select_weapon_slot(0)
	elif Input.is_action_just_pressed("weapon_2"):
		_select_weapon_slot(1)
	elif Input.is_action_just_pressed("ui_scroll_down"):
		_cycle_weapon(1)
	elif Input.is_action_just_pressed("ui_scroll_up"):
		_cycle_weapon(-1)

# ---------------------------------------------------------------------------
# Shooting
# ---------------------------------------------------------------------------
func _fire(weapon: Dictionary) -> void:
	# Check bullet ammo
	var b_type := BULLET_TYPES[current_bullet_type]
	if bullet_ammo[current_bullet_type] <= 0:
		if current_bullet_type != 0:
			# Fallback to standard
			current_bullet_type = 0
			_notify_bullet_changed()
			if bullet_ammo[0] <= 0:
				AudioManager.play_empty()
				return
		else:
			AudioManager.play_empty()
			return
	
	bullet_ammo[current_bullet_type] -= 1
	_notify_bullet_changed()

	fire_cooldown = weapon["fire_rate"]
	AudioManager.play_shoot(current_weapon_index)
	emit_signal("weapon_fired")

	# Direction: toward mouse, with slight spread
	var to_mouse := global_position.direction_to(get_global_mouse_position())
	var spread: float = randf_range(-float(weapon["spread"]), float(weapon["spread"]))
	var dir := to_mouse.rotated(spread)

	# Spawn bullet slightly in front of the player
	var b: Area2D = bullet_scene.instantiate()
	b.initialize(
		dir, 
		weapon["damage"] * b_type["damage_mult"], 
		weapon["bullet_spd"] * b_type["speed_mult"],
		current_bullet_type
	)
	bullet_container.add_child(b)
	var muzzle_pos := global_position + dir * 22.0
	b.global_position = muzzle_pos

	# Tint bullet by bullet type color
	if b.has_node("Sprite2D"):
		b.get_node("Sprite2D").modulate = b_type["color"]

	# Muzzle flash at spawn point modulated by bullet color
	if _muzzle_flash:
		_muzzle_flash.global_position = muzzle_pos
		_muzzle_flash.color = b_type["color"]
		_muzzle_flash.restart()

	# Shell casing ejected perpendicular (right side of aim)
	if _shell_casings and current_weapon_index != 2:  # silencer has no shell VFX
		_shell_casings.global_position = global_position + dir.rotated(PI * 0.5) * 8.0
		_shell_casings.restart()

# ---------------------------------------------------------------------------
# Weapon management
# ---------------------------------------------------------------------------
func _cycle_weapon(direction: int) -> void:
	if carried_weapons.size() > 1:
		var next_slot = posmod(active_slot + direction, carried_weapons.size())
		_select_weapon_slot(next_slot)

func _select_weapon_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < carried_weapons.size():
		active_slot = slot_index
		current_weapon_index = carried_weapons[active_slot]
		_apply_weapon_sprite()
		var w := WEAPONS[current_weapon_index]
		emit_signal("weapon_changed", w["name"], -1)

func _apply_weapon_sprite() -> void:
	var path: String = WEAPONS[current_weapon_index]["sprite"]
	sprite.texture = load(path)

func equip_weapon_in_slot(weapon_index: int, slot: int, amount: int) -> void:
	var b_idx := 0
	if weapon_index == 1:
		b_idx = 1 # Quick bullets
	elif weapon_index == 2:
		b_idx = 2 # Paralysis bullets
	
	if b_idx > 0 and amount > 0:
		add_bullet_ammo(b_idx, amount)

	if slot < carried_weapons.size():
		var old_weapon := carried_weapons[slot]
		_drop_weapon(old_weapon)
		carried_weapons[slot] = weapon_index
	else:
		carried_weapons.append(weapon_index)

	_select_weapon_slot(slot)

func add_ammo(weapon_index: int, amount: int) -> void:
	# Keep legacy method for compatibility if needed
	var b_idx := 0
	if weapon_index == 1:
		b_idx = 1
	elif weapon_index == 2:
		b_idx = 2
	if b_idx > 0:
		add_bullet_ammo(b_idx, amount)
	if not weapon_index in carried_weapons:
		if carried_weapons.size() < 2:
			carried_weapons.append(weapon_index)
			_select_weapon_slot(carried_weapons.size() - 1)
		else:
			equip_weapon_in_slot(weapon_index, active_slot, amount)

func _drop_weapon(w_idx: int) -> void:
	var pickup := _pickup_scene.instantiate()
	pickup.weapon_index = w_idx
	if w_idx == 1:
		pickup.amount = 50
	elif w_idx == 2:
		pickup.amount = 15
	else:
		pickup.amount = 0
	var spawn_offset := Vector2.RIGHT.rotated(randf_range(0, TAU)) * 48.0
	pickup.position = global_position + spawn_offset
	get_parent().add_child.call_deferred(pickup)

func add_bullet_ammo(b_type: int, amount: int) -> void:
	if b_type >= 0 and b_type < bullet_ammo.size():
		var b_info = BULLET_TYPES[b_type]
		bullet_ammo[b_type] += amount
		# Caps for all bullet types: Standard, Quick, Paralysis, Knockback, Slow Down
		var caps = [500, 200, 50, 60, 100]
		bullet_ammo[b_type] = min(bullet_ammo[b_type], caps[b_type])
		_notify_bullet_changed()
		
		# Show pickup announcement on the HUD
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_pickup_announcement"):
			hud.show_pickup_announcement(b_info["name"], amount, b_info["color"])

# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------
func take_damage(amount: int) -> void:
	if is_dead:
		return
	health = max(0, health - amount)
	emit_signal("health_changed", health, max_health)
	AudioManager.play_player_hurt()
	_shake_screen(6.0, 0.25)
	if health == 0:
		_die()

func heal(amount: int) -> void:
	if is_dead:
		return
	health = min(max_health, health + amount)
	emit_signal("health_changed", health, max_health)

func _die() -> void:
	is_dead = true
	emit_signal("died")
	set_physics_process(false)
	Engine.time_scale = 0.25
	# ignore_time_scale=true so the wait is in real seconds, not slow-mo seconds
	await get_tree().create_timer(1.2, true, false, true).timeout
	Engine.time_scale = 1.0
	SceneTransition.fade_to("res://Scenes/UI/game_over.tscn")

# ---------------------------------------------------------------------------
# VFX helpers
# ---------------------------------------------------------------------------
func _shake_screen(amount: float, duration: float) -> void:
	_shake_amount = amount
	_shake_timer  = duration

func _setup_muzzle_flash() -> void:
	_muzzle_flash = CPUParticles2D.new()
	get_tree().root.get_child(0).add_child(_muzzle_flash)  # root level so it's not affected by player scale
	_muzzle_flash.emitting       = false
	_muzzle_flash.one_shot       = true
	_muzzle_flash.explosiveness  = 1.0
	_muzzle_flash.amount         = 8
	_muzzle_flash.lifetime       = 0.1
	_muzzle_flash.initial_velocity_min = 100.0
	_muzzle_flash.initial_velocity_max = 220.0
	_muzzle_flash.spread         = 25.0
	_muzzle_flash.scale_amount_min = 3.0
	_muzzle_flash.scale_amount_max = 6.0
	_muzzle_flash.color          = Color(1.0, 0.85, 0.3)

func _setup_shell_casings() -> void:
	_shell_casings = CPUParticles2D.new()
	get_tree().root.get_child(0).add_child(_shell_casings)
	_shell_casings.emitting       = false
	_shell_casings.one_shot       = true
	_shell_casings.explosiveness  = 1.0
	_shell_casings.amount         = 2
	_shell_casings.lifetime       = 0.5
	_shell_casings.initial_velocity_min = 40.0
	_shell_casings.initial_velocity_max = 90.0
	_shell_casings.spread         = 20.0
	_shell_casings.gravity        = Vector2(0, 80)
	_shell_casings.scale_amount_min = 2.0
	_shell_casings.scale_amount_max = 3.0
	_shell_casings.color          = Color(0.9, 0.75, 0.2)

func _cycle_bullet_type() -> void:
	current_bullet_type = (current_bullet_type + 1) % BULLET_TYPES.size()
	_notify_bullet_changed()
	AudioManager.play_empty() # Click sound for changing bullet type

func _cycle_bullet_type_backward() -> void:
	current_bullet_type = posmod(current_bullet_type - 1, BULLET_TYPES.size())
	_notify_bullet_changed()
	AudioManager.play_empty() # Click sound for changing bullet type

func _notify_bullet_changed() -> void:
	var b_type := BULLET_TYPES[current_bullet_type]
	var ammo: int = bullet_ammo[current_bullet_type]
	emit_signal("bullet_changed", b_type["name"], ammo)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_cycle_bullet_type()
		elif event.keycode == KEY_R:
			_cycle_bullet_type_backward()
