extends Node2D

func _ready() -> void:
	# Enable subway echo filters
	AudioManager.set_echo_enabled(true)
	
	# Build the floor grid
	var ground := TileMapLayer.new()
	ground.tile_set = preload("res://tiles.tres")
	add_child(ground)
	
	# Brick/Concrete floor from atlas source 0, coordinate (1, 10)
	for x in range(-60, 60):
		for y in range(-60, 60):
			ground.set_cell(Vector2i(x, y), 0, Vector2i(1, 10))

	# Spawn Subway Tunnels/Walls forming narrow corridors
	# Horizontal tunnel wall top
	_spawn_wall(Vector2(0, -300), Vector2(1600, 40))
	# Horizontal tunnel wall bottom
	_spawn_wall(Vector2(0, 500), Vector2(1600, 40))
	
	# Vertical dividers with openings (creating tunnel rooms)
	_spawn_wall(Vector2(-400, 100), Vector2(40, 600))
	_spawn_wall(Vector2(400, 100), Vector2(40, 600))
	
	# Subway pillars (Grid layout of 16 structural pillars)
	var r := RandomNumberGenerator.new()
	r.seed = 98765
	for px in [-600, -200, 200, 600]:
		for py in [-150, 150, 350]:
			_spawn_pillar(Vector2(px, py))
			
	# Spawn 3 Lore pickups in the subway corridors
	var coords := [
		Vector2(-500.0, -100.0),
		Vector2(500.0, 300.0),
		Vector2(0.0, 150.0)
	]
	var lore_ids := [9, 10, 11]
	for i in range(3):
		var lp = load("res://Scenes/Objects/lore_pickup.tscn").instantiate()
		lp.lore_id = lore_ids[i]
		lp.global_position = coords[i]
		add_child(lp)

	# Spawn Researcher Elara story NPC
	var npc_scene = load("res://Scenes/Humans/npc.tscn")
	if npc_scene:
		var elara = npc_scene.instantiate()
		elara.npc_type = "researcher_elara"
		elara.global_position = Vector2(0, -100)
		add_child(elara)

func _exit_tree() -> void:
	# Disable echo filters when exiting level
	AudioManager.set_echo_enabled(false)

func _spawn_wall(pos: Vector2, size: Vector2) -> void:
	var sb := StaticBody2D.new()
	sb.global_position = pos
	
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	sb.add_child(col)
	
	# Subway brick color
	var poly := Polygon2D.new()
	var half_w := size.x / 2.0
	var half_h := size.y / 2.0
	poly.polygon = PackedVector2Array([
		Vector2(-half_w, -half_h),
		Vector2(half_w, -half_h),
		Vector2(half_w, half_h),
		Vector2(-half_w, half_h)
	])
	poly.color = Color(0.2, 0.22, 0.25)
	sb.add_child(poly)
	
	add_child(sb)

func _spawn_pillar(pos: Vector2) -> void:
	var sb := StaticBody2D.new()
	sb.global_position = pos
	
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 28)
	col.shape = rect
	sb.add_child(col)
	
	# Pillar concrete color
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-14, -14),
		Vector2(14, -14),
		Vector2(14, 14),
		Vector2(-14, 14)
	])
	poly.color = Color(0.45, 0.48, 0.5)
	sb.add_child(poly)
	
	# Add a metallic wrap around pillar (for subway visual feel)
	var trim := Line2D.new()
	trim.points = PackedVector2Array([Vector2(-14, 0), Vector2(14, 0)])
	trim.width = 3.0
	trim.default_color = Color(0.8, 0.6, 0.1) # gold/brass warning strip
	sb.add_child(trim)
	
	add_child(sb)
