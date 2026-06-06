extends Node2D

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var heart_node: Polygon2D
var heart_body: StaticBody2D
var _heart_timer: float = 0.0
var _drip_timer: float = 0.0
var _particle_nodes: Array = []
var _vein_lines: Array = []
var _lava_pools: Array = []
var _mini_boss_defeated: bool = false
var _hud_visible: bool = true

# Pillar veins / atmosphere
var _atmo_timer: float = 0.0

# ---------------------------------------------------------------------------
# Ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	_build_floor()
	_spawn_lava_pools()
	_spawn_cavern_walls()
	_spawn_stalactites()
	_spawn_vein_network()
	_spawn_giant_heart()
	_spawn_altar("Destroy", Vector2(-160, -180), Color(0.85, 0.1, 0.1), 1)
	_spawn_altar("Absorb", Vector2(160, -180), Color(0.8, 0.1, 0.8), 2)
	_spawn_altar("Seal", Vector2(-160, 100), Color(0.5, 0.5, 0.5), 3)
	_spawn_altar("Veil", Vector2(160, 100), Color(0.1, 0.8, 0.9), 4)

	# Lock altars until heart mini-boss is beaten
	_set_altars_active(false)

	get_tree().create_timer(1.2).timeout.connect(func():
		DialogManager.show_dialog([
			{
				"speaker": "Kaelan",
				"text": "This is it. The core. I can hear it... beating in my head.",
				"color": Color(0.2, 0.9, 1.0)
			},
			{
				"speaker": "System",
				"text": "The Giant Heart pulses with forbidden life. Its guardians still protect it.",
				"color": Color(0.8, 0.2, 0.2)
			},
			{
				"speaker": "System",
				"text": "DEFEAT ALL WAVES. Then — destroy the Heart's guardian to unlock the four paths.",
				"color": Color(1.0, 0.3, 0.1)
			}
		])
	)

	# Wire up real boss signal
	real_boss_incoming.connect(_spawn_true_boss)

func _spawn_true_boss() -> void:
	await get_tree().create_timer(3.0).timeout
	
	var boss_scene = load("res://Scenes/Zombies/zombie_base.tscn")
	if boss_scene:
		var boss: Node2D = boss_scene.instantiate() as Node2D
		boss.set_script(load("res://Scenes/Zombies/true_boss.gd"))
		boss.global_position = Vector2(0, 0)
		add_child(boss)
		
		# Add to zombies group so altars stay locked until boss dies
		boss.add_to_group("zombies")

# ---------------------------------------------------------------------------
# Process — animations
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	_heart_timer += delta
	_atmo_timer += delta
	_drip_timer += delta

	# Pulsing heart
	var thump := sin(_heart_timer * 4.0)
	var clamp_thump := clampf(thump, 0.0, 1.0)
	if heart_node:
		heart_node.scale = Vector2.ONE * (2.2 + clamp_thump * 0.32)
		heart_node.color = Color(0.75 + clamp_thump * 0.25, 0.03, 0.05)

	# Heartbeat groan
	if fmod(_heart_timer, PI / 2.0) < delta * 1.5:
		AudioManager.play_zombie_groan()

	# Vein pulse — breathe brightness
	for ln in _vein_lines:
		if is_instance_valid(ln):
			var pulse = 0.4 + sin(_atmo_timer * 2.0 + ln.position.x * 0.02) * 0.3
			ln.modulate = Color(1.0, pulse * 0.4, pulse * 0.4, 0.7 + pulse * 0.3)

	# Lava shimmer
	for lp in _lava_pools:
		if is_instance_valid(lp):
			var shimmer = 0.6 + sin(_atmo_timer * 3.0 + lp.position.x * 0.01) * 0.4
			lp.color = Color(shimmer, shimmer * 0.2, 0.0, 0.85)

	# Blood drip particles every 1.5s
	if _drip_timer > 1.5:
		_drip_timer = 0.0
		_spawn_drip_particle()

	# Redraw border glow
	queue_redraw()

# ---------------------------------------------------------------------------
# _draw — outer crimson glow border
# ---------------------------------------------------------------------------
func _draw() -> void:
	var glow_alpha = 0.08 + sin(_atmo_timer * 1.5) * 0.04
	draw_circle(Vector2.ZERO, 520.0, Color(0.8, 0.0, 0.0, glow_alpha))
	draw_circle(Vector2.ZERO, 480.0, Color(0.9, 0.05, 0.05, glow_alpha * 0.6))

# ---------------------------------------------------------------------------
# Floor
# ---------------------------------------------------------------------------
func _build_floor() -> void:
	var ground := TileMapLayer.new()
	ground.tile_set = preload("res://tiles.tres")
	add_child(ground)
	ground.modulate = Color(0.28, 0.10, 0.13)
	for x in range(-40, 40):
		for y in range(-40, 40):
			ground.set_cell(Vector2i(x, y), 0, Vector2i(1, 10))

# ---------------------------------------------------------------------------
# Lava pools (visual only Polygon2D blobs)
# ---------------------------------------------------------------------------
func _spawn_lava_pools() -> void:
	var pool_positions = [
		Vector2(-280, 200), Vector2(300, 160), Vector2(-340, -180),
		Vector2(260, -220), Vector2(0, 280), Vector2(-180, 310),
		Vector2(380, 50), Vector2(-400, 30)
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for pos in pool_positions:
		var pool := Polygon2D.new()
		var pts := PackedVector2Array()
		var r_base = rng.randf_range(28.0, 55.0)
		for i in range(10):
			var angle = i * (TAU / 10.0)
			var r = r_base + rng.randf_range(-10.0, 10.0)
			pts.append(Vector2(cos(angle) * r, sin(angle) * r * 0.6))
		pool.polygon = pts
		pool.color = Color(0.75, 0.15, 0.0, 0.85)
		pool.position = pos
		pool.z_index = -1
		add_child(pool)
		_lava_pools.append(pool)

		# Glow ring around pool
		var ring := Line2D.new()
		ring.width = 3.0
		ring.default_color = Color(1.0, 0.35, 0.0, 0.5)
		var ring_pts := PackedVector2Array()
		for i in range(11):
			var angle = i * (TAU / 10.0)
			ring_pts.append(Vector2(cos(angle) * (r_base + 10), sin(angle) * (r_base + 10) * 0.6))
		ring.points = ring_pts
		ring.position = pos
		add_child(ring)

# ---------------------------------------------------------------------------
# Stalactites hanging from ceiling (triangles)
# ---------------------------------------------------------------------------
func _spawn_stalactites() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in range(24):
		var angle = rng.randf_range(0.0, TAU)
		var dist = rng.randf_range(300.0, 490.0)
		var pos = Vector2(cos(angle), sin(angle)) * dist
		var h = rng.randf_range(20.0, 55.0)
		var w = rng.randf_range(8.0, 18.0)
		var st := Polygon2D.new()
		st.polygon = PackedVector2Array([
			Vector2(-w, 0), Vector2(w, 0), Vector2(0, h)
		])
		st.color = Color(0.12, 0.07, 0.09)
		st.position = pos
		# Point inward
		st.rotation = angle + PI
		st.z_index = 2
		add_child(st)

# ---------------------------------------------------------------------------
# Vein network radiating from heart
# ---------------------------------------------------------------------------
func _spawn_vein_network() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var center := Vector2(0, -60)
	for i in range(18):
		var line := Line2D.new()
		line.width = rng.randf_range(1.5, 4.0)
		line.default_color = Color(0.8, 0.1, 0.1, 0.7)
		var pts := PackedVector2Array()
		var angle = rng.randf_range(0.0, TAU)
		var cur := center
		pts.append(cur)
		var steps = rng.randi_range(4, 8)
		for _s in range(steps):
			angle += rng.randf_range(-0.6, 0.6)
			var step_len = rng.randf_range(40.0, 90.0)
			cur += Vector2(cos(angle), sin(angle)) * step_len
			pts.append(cur)
		line.points = pts
		line.z_index = -1
		add_child(line)
		_vein_lines.append(line)

# ---------------------------------------------------------------------------
# Giant Heart
# ---------------------------------------------------------------------------
func _spawn_giant_heart() -> void:
	heart_body = StaticBody2D.new()
	heart_body.global_position = Vector2(0, -60)

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 52.0
	col.shape = circle
	heart_body.add_child(col)

	# Outer glow ring
	var glow_ring := Line2D.new()
	glow_ring.width = 8.0
	glow_ring.default_color = Color(1.0, 0.05, 0.05, 0.4)
	var ring_pts := PackedVector2Array()
	for i in range(33):
		var a = i * (TAU / 32.0)
		ring_pts.append(Vector2(cos(a) * 60, sin(a) * 60))
	glow_ring.points = ring_pts
	heart_body.add_child(glow_ring)

	# Heart polygon
	heart_node = Polygon2D.new()
	heart_node.polygon = PackedVector2Array([
		Vector2(0, 32), Vector2(-22, 14), Vector2(-34, -10),
		Vector2(-30, -32), Vector2(-14, -38), Vector2(0, -20),
		Vector2(14, -38), Vector2(30, -32), Vector2(34, -10),
		Vector2(22, 14)
	])
	heart_node.color = Color(0.82, 0.05, 0.05)
	heart_body.add_child(heart_node)

	# Label
	var lbl := Label.new()
	lbl.text = "THE GIANT HEART"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(-70, -72)
	lbl.custom_minimum_size = Vector2(140, 16)
	heart_body.add_child(lbl)

	add_child(heart_body)

# ---------------------------------------------------------------------------
# Blood drip particles
# ---------------------------------------------------------------------------
func _spawn_drip_particle() -> void:
	var px := randf_range(-440.0, 440.0)
	var py := randf_range(-440.0, 440.0)
	if Vector2(px, py).length() > 460.0:
		return
	var dot := ColorRect.new()
	dot.size = Vector2(3, 5)
	dot.color = Color(0.65, 0.0, 0.0, 0.9)
	dot.position = Vector2(px, py)
	add_child(dot)
	var tw := create_tween()
	tw.tween_property(dot, "position:y", py + randf_range(20, 50), 0.8)
	tw.parallel().tween_property(dot, "modulate:a", 0.0, 0.8)
	tw.tween_callback(dot.queue_free)

# ---------------------------------------------------------------------------
# Altar lock / unlock
# ---------------------------------------------------------------------------
var _altars: Array = []

func _set_altars_active(active: bool) -> void:
	for altar in _altars:
		if is_instance_valid(altar):
			altar.set_meta("altars_enabled", active)
			var prompt = altar.get_node_or_null("Prompt")
			if prompt:
				if active:
					prompt.add_theme_color_override("font_color",
						altar.get_meta("altar_color", Color.WHITE))
				else:
					prompt.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))

func _spawn_altar(action_type: String, pos: Vector2, neon_color: Color, index: int) -> void:
	var sb := StaticBody2D.new()
	sb.global_position = pos
	sb.name = "Altar_%s" % action_type
	sb.set_meta("altars_enabled", false)
	sb.set_meta("altar_color", neon_color)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(54, 54)
	col.shape = rect
	sb.add_child(col)

	# Stone slab
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-27, -27), Vector2(27, -27), Vector2(27, 27), Vector2(-27, 27)
	])
	poly.color = Color(0.14, 0.10, 0.14)
	sb.add_child(poly)

	# Edge border
	var border := Line2D.new()
	border.width = 2.0
	border.default_color = neon_color * Color(1, 1, 1, 0.6)
	border.points = PackedVector2Array([
		Vector2(-27, -27), Vector2(27, -27), Vector2(27, 27),
		Vector2(-27, 27), Vector2(-27, -27)
	])
	sb.add_child(border)

	# Rune glow
	var glow := ColorRect.new()
	glow.size = Vector2(18, 18)
	glow.position = Vector2(-9, -9)
	glow.color = neon_color
	sb.add_child(glow)

	# Label
	var lbl := Label.new()
	lbl.text = action_type.to_upper()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", neon_color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(-27, -40)
	lbl.custom_minimum_size = Vector2(54, 14)
	sb.add_child(lbl)

	# Interaction prompt
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 9)
	prompt.position = Vector2(-75, -58)
	prompt.custom_minimum_size = Vector2(150, 20)
	prompt.visible = false
	if action_type == "Veil":
		if Globals.discovered_lore.size() >= 9:
			prompt.text = "[E] Altar of the Veil (Secret)"
		else:
			prompt.text = "[E] Altar of the Veil (Locked)"
	else:
		prompt.text = "[E] Altar of %s" % action_type.to_upper()
	prompt.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt.add_theme_constant_override("outline_size", 2)
	sb.add_child(prompt)

	# Interaction area
	var area := Area2D.new()
	var area_col := CollisionShape2D.new()
	var area_circle := CircleShape2D.new()
	area_circle.radius = 72.0
	area_col.shape = area_circle
	area.add_child(area_col)
	sb.add_child(area)

	var interact_callable = func():
		if not sb.get_meta("altars_enabled", false):
			DialogManager.show_dialog([{
				"speaker": "System",
				"text": "The altars are sealed. Defeat the Heart's guardian first.",
				"color": Color(0.7, 0.2, 0.2)
			}])
			return
		if action_type == "Veil" and Globals.discovered_lore.size() < 9:
			DialogManager.show_dialog([
				{"speaker": "System", "text": "The Altar of the Veil is cold and inactive.", "color": Color(0.5, 0.5, 0.5)},
				{"speaker": "System", "text": "Discover all 9 lore archives to unlock the fourth path.", "color": Color(0.5, 0.5, 0.5)}
			])
			return
		AudioManager.play_click()
		DialogManager.show_dialog([{
			"speaker": "System",
			"text": "Do you wish to initiate the %s path? There is no turning back." % action_type.to_upper(),
			"color": neon_color
		}])
		get_tree().create_timer(0.2).timeout.connect(func():
			while DialogManager.is_active():
				await get_tree().create_timer(0.1).timeout
			_trigger_ending_slides(index)
		)

	sb.set_meta("interact_method", interact_callable)

	area.body_entered.connect(func(body):
		if body.is_in_group("player") and not body.get("is_dead"):
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
	_altars.append(sb)

# ---------------------------------------------------------------------------
# Called by wave_manager when heart mini-boss is defeated
# ---------------------------------------------------------------------------
func on_heart_boss_defeated() -> void:
	if _mini_boss_defeated:
		return
	_mini_boss_defeated = true

	# Unlock lore
	Globals.discover_lore(14)

	# Heart turns grey/dead
	var tw := create_tween()
	tw.tween_property(heart_node, "color", Color(0.25, 0.12, 0.12), 1.2)
	tw.parallel().tween_property(heart_node, "scale", Vector2(1.8, 1.8), 1.2)

	# Screen shake
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_shake_screen"):
		player._shake_screen(14.0, 0.6)

	# Crack lines radiating from heart
	for i in range(8):
		var crack := Line2D.new()
		crack.width = 2.0
		crack.default_color = Color(0.1, 0.1, 0.1, 0.9)
		var angle = i * (TAU / 8.0) + randf_range(-0.2, 0.2)
		crack.points = PackedVector2Array([
			Vector2(0, 0),
			Vector2(cos(angle) * randf_range(60, 120), sin(angle) * randf_range(60, 120))
		])
		crack.global_position = heart_body.global_position
		add_child(crack)

	await get_tree().create_timer(1.5).timeout

	DialogManager.show_dialog([
		{
			"speaker": "System",
			"text": "The guardian falls. The Heart's defences are shattered.",
			"color": Color(1.0, 0.1, 0.1)
		},
		{
			"speaker": "Kaelan",
			"text": "It... stopped. The pounding in my skull is gone. But something else is stirring. Something older.",
			"color": Color(0.2, 0.9, 1.0)
		},
		{
			"speaker": "System",
			"text": "The four altars have awakened. Choose your path — but be warned. The true architect of this nightmare approaches.",
			"color": Color(1.0, 0.7, 0.1)
		}
	])

	while DialogManager.is_active():
		await get_tree().create_timer(0.1).timeout

	# Unlock all altars
	_set_altars_active(true)
	# Update altar prompt colors
	for altar in _altars:
		if is_instance_valid(altar):
			var prompt = altar.get_node_or_null("Prompt")
			if prompt:
				var c = altar.get_meta("altar_color", Color.WHITE)
				prompt.add_theme_color_override("font_color", c)

	# Signal: "real boss incoming" — placeholder for future implementation
	emit_signal("real_boss_incoming")

# ---------------------------------------------------------------------------
# Signal — real boss (to be wired up when the real boss is implemented)
# ---------------------------------------------------------------------------
signal real_boss_incoming

# ---------------------------------------------------------------------------
# Ending slides (unchanged logic, updated colors)
# ---------------------------------------------------------------------------
func _trigger_ending_slides(ending_index: int) -> void:
	var ending_text := []
	var ending_name := ""

	match ending_index:
		1:
			ending_name = "Destroy"
			ending_text = [
				{"speaker": "Ending — Destroy", "text": "You shatter the Giant's Heart. A shockwave tears through the cavern, turning the Revenants outside to ash.", "color": Color(0.85, 0.1, 0.1)},
				{"speaker": "Ending — Destroy", "text": "The plague ends, but the ancient power is gone forever.", "color": Color(0.85, 0.1, 0.1)},
				{"speaker": "Ending — Destroy", "text": "You return to the surface as Kaelan — a human with no family, no past, and memories that will never fully heal.", "color": Color(0.85, 0.1, 0.1)}
			]
		2:
			ending_name = "Absorb"
			ending_text = [
				{"speaker": "Ending — Absorb", "text": "You place your hands on the pulsing heart and draw its energy into yourself.", "color": Color(0.8, 0.1, 0.8)},
				{"speaker": "Ending — Absorb", "text": "Your skin thickens, your bones stretch. The flesh of the giant prince reclaimed.", "color": Color(0.8, 0.1, 0.8)},
				{"speaker": "Ending — Absorb", "text": "The Revenants bow to their new king. But you rule a dead empire. There is no one left to save.", "color": Color(0.8, 0.1, 0.8)}
			]
		3:
			ending_name = "Seal"
			ending_text = [
				{"speaker": "Ending — Seal", "text": "You turn your back on the heart, building a massive stone barrier to seal the cavern forever.", "color": Color(0.6, 0.6, 0.6)},
				{"speaker": "Ending — Seal", "text": "The world above continues its slow, desperate struggle.", "color": Color(0.6, 0.6, 0.6)},
				{"speaker": "Ending — Seal", "text": "You watch from the shadows, a silent guardian who refuses to choose.", "color": Color(0.6, 0.6, 0.6)}
			]
		4:
			ending_name = "Veil's End"
			ending_text = [
				{"speaker": "Ending — Veil's End", "text": "With all archives of truth gathered, you merge your human memories and giant essence into the heart.", "color": Color(0.1, 0.8, 0.9)},
				{"speaker": "Ending — Veil's End", "text": "A brilliant white light erupts, washing over the ruins, the cemetery, and the tunnels.", "color": Color(0.1, 0.8, 0.9)},
				{"speaker": "Ending — Veil's End", "text": "The plague is completely purified. The earth heals. You awaken in the sunlight — completely human, free of the curse, ready to start anew.", "color": Color(0.1, 0.8, 0.9)}
			]

	DialogManager.show_dialog(ending_text)

	get_tree().create_timer(0.2).timeout.connect(func():
		while DialogManager.is_active():
			await get_tree().create_timer(0.1).timeout
		if not Globals.unlocked_endings.has(ending_name):
			Globals.unlocked_endings.append(ending_name)
		Globals.current_wave = 1
		Globals.selected_map = "res://Scenes/Locations/map_1.tscn"
		Globals.save()
		SceneTransition.fade_to("res://Scenes/menue.tscn")
	)

# ---------------------------------------------------------------------------
# Cavern walls
# ---------------------------------------------------------------------------
func _spawn_cavern_walls() -> void:
	var radius := 540.0
	var count := 36
	for i in range(count):
		var angle := i * (TAU / count)
		var wall_pos := Vector2(cos(angle), sin(angle)) * radius
		var sb := StaticBody2D.new()
		sb.global_position = wall_pos

		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 26.0
		col.shape = circle
		sb.add_child(col)

		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-26, -26), Vector2(26, -26), Vector2(26, 26), Vector2(-26, 26)
		])
		poly.color = Color(0.11, 0.07, 0.10)
		sb.add_child(poly)

		# Edge veins on walls
		var vein := Line2D.new()
		vein.width = 2.0
		vein.default_color = Color(0.6, 0.05, 0.05, 0.5)
		vein.points = PackedVector2Array([
			Vector2(randf_range(-20, -5), randf_range(-20, 0)),
			Vector2(randf_range(5, 20), randf_range(0, 20))
		])
		sb.add_child(vein)

		add_child(sb)
