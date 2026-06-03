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

	# Spawn points = all Marker2D direct children of this node
	for child in get_children():
		if child is Marker2D:
			_spawn_points.append(child as Node2D)

	_enemies_node = get_parent().get_node_or_null("Enemies")

	if _enemies_node == null:
		push_error("WaveManager: 'Enemies' node not found!")
		return
	if _spawn_points.is_empty():
		push_error("WaveManager: No nodes in group 'spawn_points'!")
		return

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

	_running = true
	await get_tree().create_timer(2.0).timeout
	_run_loop()

# ---------------------------------------------------------------------------
# Main coroutine loop
# ---------------------------------------------------------------------------
func _run_loop() -> void:
	while _running:
		_current_wave += 1
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

# ---------------------------------------------------------------------------
# Wave definitions
# ---------------------------------------------------------------------------
func _build_spawn_list(wave_num: int) -> Array:
	var list: Array[Dictionary] = []
	match wave_num:
		1: list = _batch("slow", 3, 1.0) + _batch("bomber", 1, 1.0)
		2: list = _batch("slow", 4, 1.0) + _batch("bomber", 1, 1.0) + _batch("heart", 1, 1.0)
		3: list = _batch("slow", 3, 1.1) + _batch("base", 2, 1.0) + _batch("bomber", 2, 1.0) + _batch("gunner", 1, 1.0)
		4: list = _batch("slow", 3, 1.1) + _batch("base", 3, 1.0) + _batch("heart", 1, 1.0) + _batch("gunner", 1, 1.0) + _batch("bomber", 2, 1.0)
		5: list = _batch("base", 4, 1.1) + _batch("cyborg", 1, 1.0) + _batch("heart", 1, 1.0) + _batch("gunner", 2, 1.0) + _batch("bomber", 2, 1.0)
		_:
			var n := wave_num - 5
			var mult := 1.0 + n * 0.07
			list = _batch("slow",   clampi(2 + n / 2, 2, 8),  mult) \
				 + _batch("base",   clampi(2 + n,     2, 12), mult) \
				 + _batch("cyborg", clampi(n - 1,     0, 4),  mult) \
				 + _batch("heart",  clampi(1 + n / 2, 1, 4),  mult) \
				 + _batch("bomber", clampi(2 + n / 2, 2, 6),  mult) \
				 + _batch("gunner", clampi(1 + n / 2, 1, 5),  mult)
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
