extends Control
class_name Minimap

# ---------------------------------------------------------------------------
# Config & State
# ---------------------------------------------------------------------------
const CELL_SIZE: float = 64.0
const MINIMAP_SCALE: float = 0.05 # 1 world unit = 0.05 minimap pixels
const RADIUS_PX: float = 46.0     # Radius of the circular radar
const WORLD_RADIUS: float = RADIUS_PX / MINIMAP_SCALE # 920 world units visible radius

var center: Vector2 = Vector2(50, 50)
var visited_cells: Dictionary = {}
var obstacles: Array = []
var _scanned: bool = false
var _is_minimap_visible: bool = true

# Ambient radar sweep angle
var _sweep_angle: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	# Configure control sizing and anchoring (Bottom-Left)
	custom_minimum_size = Vector2(100, 100)
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 14
	offset_top = -114
	offset_right = 114
	offset_bottom = -14
	
	# Set pivot center for scaling animations
	pivot_offset = Vector2(50, 50)
	
	# Request redraw every frame to animate player, sweep, and entities
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			toggle_minimap()

func toggle_minimap() -> void:
	_is_minimap_visible = not _is_minimap_visible
	var target_alpha = 1.0 if _is_minimap_visible else 0.0
	var target_scale = Vector2.ONE if _is_minimap_visible else Vector2(0.8, 0.8)
	
	AudioManager.play_click()
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", target_alpha, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", target_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	# Keep requesting redraws
	queue_redraw()
	
	# Animate radar sweep
	_sweep_angle = fmod(_sweep_angle + delta * 2.5, TAU)
	
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
		
	# Perform obstacle scan on first frame when the map is fully loaded
	if not _scanned:
		_scanned = true
		scan_obstacles()
		
	# Track player position and reveal cells
	var p_pos = player.global_position
	var px = int(floor(p_pos.x / CELL_SIZE))
	var py = int(floor(p_pos.y / CELL_SIZE))
	
	# Reveal cells in a circle around the player
	var reveal_radius = 3
	for dx in range(-reveal_radius, reveal_radius + 1):
		for dy in range(-reveal_radius, reveal_radius + 1):
			if dx*dx + dy*dy <= reveal_radius*reveal_radius:
				var cell = Vector2i(px + dx, py + dy)
				visited_cells[cell] = true

# ---------------------------------------------------------------------------
# Obstacle Scan
# ---------------------------------------------------------------------------
func scan_obstacles() -> void:
	obstacles.clear()
	var map_node = get_node_or_null("/root/Root/Map1")
	if not map_node:
		return
	_scan_node_recursive(map_node)

func _scan_node_recursive(node: Node) -> void:
	if node is TileMapLayer:
		var layer = node as TileMapLayer
		var layer_name = layer.name.to_lower()
		# Identify boundary or bushes/rocks as obstacles
		if "boundary" in layer_name or "bush" in layer_name or "rock" in layer_name or "obstacle" in layer_name or "wall" in layer_name:
			var cells = layer.get_used_cells()
			var tile_sz = layer.tile_set.tile_size if layer.tile_set else Vector2i(16, 16)
			for cell in cells:
				var local_pos = layer.map_to_local(cell)
				var global_pos = layer.to_global(local_pos)
				obstacles.append({
					"type": "tile",
					"pos": global_pos,
					"size": Vector2(tile_sz)
				})
	elif node is StaticBody2D:
		var body = node as StaticBody2D
		var body_size = Vector2(16, 16)
		var shape_type = "circle"
		var radius = 8.0
		for child in body.get_children():
			if child is CollisionShape2D and child.shape:
				if child.shape is RectangleShape2D:
					body_size = child.shape.size
					shape_type = "rect"
				elif child.shape is CircleShape2D:
					radius = child.shape.radius
					shape_type = "circle"
					body_size = Vector2(radius * 2, radius * 2)
		obstacles.append({
			"type": "static_body",
			"pos": body.global_position,
			"shape": shape_type,
			"size": body_size,
			"radius": radius,
			"name": body.name
		})
		
	for child in node.get_children():
		_scan_node_recursive(child)

# ---------------------------------------------------------------------------
# Dynamic Level Theme Colors
# ---------------------------------------------------------------------------
func _get_theme_colors() -> Dictionary:
	var map_path = Globals.selected_map.to_lower()
	if "cemetery" in map_path:
		return {
			"floor": Color(0.12, 0.42, 0.18, 0.45), # Dark moss green
			"wall": Color(0.42, 0.45, 0.48, 0.8), # Slate grey
			"border": Color(0.2, 0.8, 0.3, 0.85), # Spooky neon green
			"player": Color(0.1, 1.0, 0.2, 1.0) # Bright green
		}
	elif "heart" in map_path:
		return {
			"floor": Color(0.48, 0.05, 0.08, 0.45), # Volcanic crimson
			"wall": Color(0.95, 0.15, 0.15, 0.85), # Pulsing lava red
			"border": Color(0.95, 0.1, 0.25, 0.85), # Hot pink/red
			"player": Color(1.0, 0.8, 0.1, 1.0) # Golden yellow
		}
	elif "subway" in map_path:
		return {
			"floor": Color(0.18, 0.2, 0.24, 0.45), # Concrete grey
			"wall": Color(0.85, 0.65, 0.1, 0.85), # Brass trim warning yellow
			"border": Color(0.85, 0.65, 0.1, 0.85), # Yellow/Gold warning lines
			"player": Color(0.0, 0.9, 1.0, 1.0) # Electric cyan
		}
	else: # map_1
		return {
			"floor": Color(0.05, 0.22, 0.42, 0.45), # Sci-fi deep blue
			"wall": Color(0.1, 0.65, 0.95, 0.85), # Hologram cyan
			"border": Color(0.1, 0.75, 1.0, 0.85), # Glowing cyan border
			"player": Color(0.0, 0.9, 1.0, 1.0) # Cyan player
		}

# Helper to transform world position to minimap coordinates
func world_to_minimap(world_pos: Vector2, player_pos: Vector2) -> Vector2:
	return center + (world_pos - player_pos) * MINIMAP_SCALE

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------
func _draw() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
		
	var player_pos = player.global_position
	var map_theme = _get_theme_colors()
	
	# 1. Draw Glassmorphic Dark Circle Background
	var bg_color = Color(0.04, 0.04, 0.06, 0.78)
	draw_circle(center, RADIUS_PX, bg_color)
	
	# 2. Draw Radar Scanner grid lines (concentric rings & crosshair)
	var grid_color = Color(map_theme.border.r, map_theme.border.g, map_theme.border.b, 0.18)
	draw_arc(center, RADIUS_PX * 0.33, 0.0, TAU, 16, grid_color, 1.0)
	draw_arc(center, RADIUS_PX * 0.66, 0.0, TAU, 24, grid_color, 1.0)
	draw_line(center - Vector2(RADIUS_PX, 0), center + Vector2(RADIUS_PX, 0), grid_color, 1.0)
	draw_line(center - Vector2(0, RADIUS_PX), center + Vector2(0, RADIUS_PX), grid_color, 1.0)
	
	# 3. Draw Visited Floor Grid Cells
	var px = int(floor(player_pos.x / CELL_SIZE))
	var py = int(floor(player_pos.y / CELL_SIZE))
	
	# Calculate visible cell ranges
	var cell_range = int(ceil(WORLD_RADIUS / CELL_SIZE)) + 1
	var cell_draw_size = CELL_SIZE * MINIMAP_SCALE
	
	for dx in range(-cell_range, cell_range + 1):
		for dy in range(-cell_range, cell_range + 1):
			var cx = px + dx
			var cy = py + dy
			var cell = Vector2i(cx, cy)
			
			if visited_cells.has(cell):
				var cell_center = Vector2((cx + 0.5) * CELL_SIZE, (cy + 0.5) * CELL_SIZE)
				
				# Only draw if within circular map boundaries
				if cell_center.distance_to(player_pos) <= WORLD_RADIUS:
					var m_pos = world_to_minimap(cell_center, player_pos)
					# Draw cell block
					draw_rect(Rect2(m_pos - Vector2(cell_draw_size * 0.5, cell_draw_size * 0.5), Vector2(cell_draw_size * 1.05, cell_draw_size * 1.05)), map_theme.floor)

	# 4. Draw Obstacles inside Visited Areas
	for obs in obstacles:
		var obs_pos: Vector2 = obs.pos
		var obs_cell = Vector2i(int(floor(obs_pos.x / CELL_SIZE)), int(floor(obs_pos.y / CELL_SIZE)))
		
		# Only draw obstacles if they are in visited cells
		if visited_cells.has(obs_cell) and obs_pos.distance_to(player_pos) <= WORLD_RADIUS:
			var m_pos = world_to_minimap(obs_pos, player_pos)
			
			if obs.type == "tile":
				var sz = obs.size * MINIMAP_SCALE
				draw_rect(Rect2(m_pos - sz * 0.5, sz), map_theme.wall)
			elif obs.type == "static_body":
				if "Crypt" in obs.name:
					var sz = obs.size * MINIMAP_SCALE
					# Draw brick border
					draw_rect(Rect2(m_pos - sz * 0.5, sz), map_theme.wall)
					# Fill crypt interior slightly darker
					draw_rect(Rect2(m_pos - sz * 0.4, sz * 0.8), Color(0.08, 0.08, 0.1, 0.9))
				elif "Altar" in obs.name:
					var sz = obs.size * MINIMAP_SCALE
					# Glowing Altar Rect
					draw_rect(Rect2(m_pos - sz * 0.5, sz), map_theme.wall)
					# Draw altar core rune glow
					draw_rect(Rect2(m_pos - sz * 0.25, sz * 0.5), Color(1, 1, 1, 0.95))
				elif "Heart" in obs.name:
					var rad = obs.radius * MINIMAP_SCALE
					# Pulse the heart visually on minimap too!
					var pulse = 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.004)
					draw_circle(m_pos, rad * pulse, map_theme.wall)
					draw_circle(m_pos, rad * 0.5 * pulse, Color.WHITE)
				else:
					if obs.shape == "rect":
						var sz = obs.size * MINIMAP_SCALE
						draw_rect(Rect2(m_pos - sz * 0.5, sz), map_theme.wall)
					else:
						var rad = obs.radius * MINIMAP_SCALE
						draw_circle(m_pos, rad, map_theme.wall)

	# 5. Draw Pickups (if in visited areas)
	var pickups = get_tree().get_nodes_in_group("pickups")
	for pickup in pickups:
		if is_instance_valid(pickup):
			var p_pos = pickup.global_position
			var p_cell = Vector2i(int(floor(p_pos.x / CELL_SIZE)), int(floor(p_pos.y / CELL_SIZE)))
			if visited_cells.has(p_cell) and p_pos.distance_to(player_pos) <= WORLD_RADIUS:
				var m_pos = world_to_minimap(p_pos, player_pos)
				# Draw diamond pickup shape
				var pulse = 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.01)
				var d_size = 2.2 * pulse
				var points = PackedVector2Array([
					m_pos + Vector2(0, -d_size),
					m_pos + Vector2(d_size, 0),
					m_pos + Vector2(0, d_size),
					m_pos + Vector2(-d_size, 0)
				])
				# Modulation color of pickup, fallback to gold
				var pickup_col = Color(1.0, 0.8, 0.1)
				if "weapon_index" in pickup:
					var colors = [Color(1.0, 0.9, 0.0), Color(1.0, 0.27, 0.0), Color(0.0, 1.0, 1.0)]
					var idx = pickup.weapon_index
					if idx >= 0 and idx < colors.size():
						pickup_col = colors[idx]
				draw_polygon(points, PackedColorArray([pickup_col]))

	# 6. Draw Zombies / Enemies (if in visited areas)
	var zombies = get_tree().get_nodes_in_group("zombies")
	for zombie in zombies:
		if is_instance_valid(zombie):
			var z_pos = zombie.global_position
			var z_cell = Vector2i(int(floor(z_pos.x / CELL_SIZE)), int(floor(z_pos.y / CELL_SIZE)))
			if visited_cells.has(z_cell) and z_pos.distance_to(player_pos) <= WORLD_RADIUS:
				var m_pos = world_to_minimap(z_pos, player_pos)
				# Pulsing enemy indicator
				var pulse = 1.0 + 0.3 * sin(Time.get_ticks_msec() * 0.015)
				draw_circle(m_pos, 2.5 * pulse, Color(1.0, 0.15, 0.15))
				draw_circle(m_pos, 1.2, Color.WHITE)
				
	# 6.5. Draw NPCs (if in visited areas)
	var npcs = get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if is_instance_valid(npc) and not npc.get("is_dead"):
			var n_pos = npc.global_position
			var n_cell = Vector2i(int(floor(n_pos.x / CELL_SIZE)), int(floor(n_pos.y / CELL_SIZE)))
			if visited_cells.has(n_cell) and n_pos.distance_to(player_pos) <= WORLD_RADIUS:
				var m_pos = world_to_minimap(n_pos, player_pos)
				var dot_color = Color(0.2, 0.8, 1.0) if not npc.get("is_hostile_to_player") else Color(1.0, 0.2, 0.2)
				draw_circle(m_pos, 2.5, dot_color)
				draw_circle(m_pos, 1.0, Color.WHITE)

	# 7. Draw Radar Sweep Line
	var sweep_end = center + Vector2(RADIUS_PX, 0).rotated(_sweep_angle)
	draw_line(center, sweep_end, Color(map_theme.border.r, map_theme.border.g, map_theme.border.b, 0.25), 1.5)

	# 8. Draw Player Arrow Pointer in the center
	var p_rot = player.rotation
	var p_color = map_theme.player
	var p_size = 5.0
	var player_poly = PackedVector2Array([
		center + Vector2(p_size * 1.5, 0).rotated(p_rot),
		center + Vector2(-p_size, -p_size * 0.8).rotated(p_rot),
		center + Vector2(-p_size * 0.5, 0).rotated(p_rot),
		center + Vector2(-p_size, p_size * 0.8).rotated(p_rot)
	])
	draw_polygon(player_poly, PackedColorArray([p_color]))
	# Subtle player glow dot in center
	draw_circle(center, 1.2, Color.WHITE)

	# 9. Draw Neon Circular Border Frame with Glow
	draw_arc(center, RADIUS_PX, 0.0, TAU, 32, map_theme.border, 1.5)
	draw_arc(center, RADIUS_PX + 0.5, 0.0, TAU, 32, Color(map_theme.border.r, map_theme.border.g, map_theme.border.b, 0.3), 1.0)
	
	# 10. Draw Mini Toggle Helper text at the bottom edge of the minimap
	# Only show helper if we are expanded
	var font = ThemeDB.fallback_font
	if font:
		var txt = "[M] Map"
		var font_sz = 8
		var txt_size = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz)
		var txt_pos = center + Vector2(-txt_size.x * 0.5, RADIUS_PX + 9)
		draw_string_outline(font, txt_pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, 3, Color.BLACK)
		draw_string(font, txt_pos, txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_sz, Color(0.75, 0.75, 0.8))
