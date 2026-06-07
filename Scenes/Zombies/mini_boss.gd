extends "res://Scenes/Zombies/zombie_base.gd"

var boss_name: String = ""
var abilities: Array[String] = []
var boss_type: String = ""

var original_modulate: Color = Color.WHITE
var ability_timer: float = 0.0
var _heart_beat_timer: float = 0.0

# Ability states
var lunge_timer: float = 0.0
var lunge_duration: float = 0.0
var lunge_dir: Vector2 = Vector2.ZERO

var laser_duration: float = 0.0
var sprint_timer: float = 0.0

var draw_smash_circle: bool = false
var smash_circle_radius: float = 0.0

var draw_repulsion_circle: bool = false
var repulsion_circle_radius: float = 0.0
var attraction_pulse: bool = false # true = pulling, false = pushing

var draw_disarm_circle: bool = false
var disarm_circle_radius: float = 0.0

var draw_laser: bool = false
var laser_hit_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	super()
	# Mini-boss acts independently
	leader = self

func setup_boss(type: String) -> void:
	boss_type = type
	zombie_type = "mini_boss"
	add_to_group("mini_bosses")
	
	match type:
		"spine":
			boss_name = "Subject 0: Spine"
			max_health = 700.0
			move_speed = 170.0
			damage = 22
			abilities = ["sprint", "repulsion_attraction", "summon_weak"]
			original_modulate = Color(0.8, 0.95, 1.0)
			scale = Vector2(1.6, 1.6)
		"skull":
			boss_name = "Subject 0 Skull"
			max_health = 800.0
			move_speed = 150.0
			damage = 25
			abilities = ["flying_sword", "lazer_eyes", "summon_weak"]
			original_modulate = Color(0.7, 0.4, 0.9)
			scale = Vector2(1.5, 1.5)
		"heart":
			boss_name = "Subject 0 Heart"
			max_health = 900.0
			move_speed = 140.0
			damage = 30
			abilities = ["repulsion_attraction", "flying_sword", "explosion"]
			original_modulate = Color(1.0, 0.15, 0.15)
			scale = Vector2(2.0, 2.0)
		"true_cyborg":
			boss_name = "True Cyborg"
			max_health = 1000.0
			move_speed = 160.0
			damage = 28
			abilities = ["lazer_eyes", "repulsion_attraction", "sprint"]
			original_modulate = Color(0.35, 0.4, 0.45)
			scale = Vector2(1.8, 1.8)
		"prototype":
			boss_name = "Prototype"
			max_health = 600.0
			move_speed = 190.0
			damage = 18
			abilities = ["sprint", "lunge", "force_swap"]
			original_modulate = Color(0.85, 0.95, 0.1)
			scale = Vector2(1.7, 1.7)
		"zombiefied_giant":
			boss_name = "Zombiefied Giant"
			max_health = 1100.0
			move_speed = 120.0
			damage = 35
			abilities = ["smash", "sprint", "explosion"]
			original_modulate = Color(0.2, 0.8, 0.3)
			scale = Vector2(2.3, 2.3)
		"fake_true_giant":
			boss_name = "Fake True Giant"
			max_health = 1200.0
			move_speed = 110.0
			damage = 40
			abilities = ["smash", "lunge", "force_swap"]
			original_modulate = Color(1.0, 0.6, 0.1)
			scale = Vector2(2.5, 2.5)

	health = max_health
	modulate = original_modulate
	strength = 12.0
	
	# Load specific texture based on the mini boss type
	var tex_path := ""
	match type:
		"spine": tex_path = "res://Last Stand Assets/Characters/PNG/Soldier 1/soldier1_hold.png"
		"skull": tex_path = "res://Last Stand Assets/Characters/PNG/Zombie 1/zoimbie1_silencer.png"
		"heart": tex_path = "res://Last Stand Assets/Characters/PNG/Zombie 1/zoimbie1_machine.png"
		"true_cyborg": tex_path = "res://Last Stand Assets/Characters/PNG/Robot 1/robot1_machine.png"
		"prototype": tex_path = "res://Last Stand Assets/Characters/PNG/Robot 1/robot1_gun.png"
		"zombiefied_giant": tex_path = "res://Last Stand Assets/Characters/PNG/Zombie 1/zoimbie1_hold.png"
		"fake_true_giant": tex_path = "res://Last Stand Assets/Characters/PNG/Soldier 1/soldier1_machine.png"
	
	if has_node("image"):
		var sprite = get_node("image") as Sprite2D
		if sprite:
			sprite.visible = false
			
	# Add unique visual effects
	_add_boss_effects(type)
	
	# Create HUD elements
	call_deferred("_create_boss_hud")

func _create_boss_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 90 # Mini bosses slightly below true boss
	add_child(canvas)
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_top", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)
	
	var lbl := Label.new()
	lbl.name = "BossNameLabel"
	lbl.text = boss_name.to_upper()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", original_modulate.lightened(0.2))
	lbl.add_theme_color_override("font_outline_color", Color(0,0,0))
	lbl.add_theme_constant_override("outline_size", 6)
	vbox.add_child(lbl)
	
	var hb := ProgressBar.new()
	hb.name = "BossHealthBar"
	hb.max_value = max_health
	hb.value = health
	hb.show_percentage = false
	var screen_w: float = get_viewport_rect().size.x
	var bar_width: float = min(600.0, screen_w - 120.0)
	hb.custom_minimum_size = Vector2(bar_width, 20)
	hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	sb_bg.border_width_left = 3; sb_bg.border_width_right = 3; sb_bg.border_width_top = 3; sb_bg.border_width_bottom = 3
	sb_bg.border_color = Color(0.3, 0.3, 0.3, 0.8)
	hb.add_theme_stylebox_override("background", sb_bg)
	
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = original_modulate
	hb.add_theme_stylebox_override("fill", sb_fg)
	vbox.add_child(hb)

func take_damage(amount: float) -> void:
	if is_dead:
		return
	health -= amount
	AudioManager.play_zombie_hit()
	
	var hb = find_child("BossHealthBar", true, false)
	if hb:
		hb.value = health
		
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.2, 0.2), 0.05)
	tw.tween_property(self, "modulate", original_modulate, 0.15)
	
	if health <= 0.0:
		_die()

func _die() -> void:
	var lore_id := 12
	match boss_name:
		"Subject 0: Spine": lore_id = 12
		"Subject 0 Skull": lore_id = 13
		"Subject 0 Heart": lore_id = 14
		"True Cyborg": lore_id = 15
		"Prototype": lore_id = 16
		"Zombiefied Giant": lore_id = 17
		"Fake True Giant": lore_id = 18
	
	Globals.discover_lore(lore_id)
	
	var frag = Globals.LORE_FRAGMENTS[lore_id]
	DialogManager.show_dialog([
		{
			"speaker": "System",
			"text": "MINI-BOSS DEFEATED! Discovered Lore: %s" % frag["title"],
			"color": Color(0.1, 0.9, 0.2)
		}
	])
	
	# Dynamic drop scaling based on wave number and boss strength
	var wave_factor = 1.0 + (Globals.current_wave - 1) * 0.03
	var strength_factor = strength / 2.0
	var amount_mult = strength_factor * wave_factor

	# Drop rare items: scale number of items and use weighted index
	var item_pickup_scene = load("res://Scenes/Pickups/item_pickup.tscn")
	if item_pickup_scene:
		var num_items = clampi(2 + int(Globals.current_wave / 5.0) + int(strength / 4.0), 2, 5)
		for i in range(num_items):
			var item = item_pickup_scene.instantiate()
			
			# Weighted item index
			var w0 = maxf(10.0, 30.0 - Globals.current_wave * 0.5 - strength * 1.5)
			var w1 = maxf(15.0, 25.0 - Globals.current_wave * 0.2)
			var w2 = 25.0
			var w3 = 15.0 + Globals.current_wave * 0.8 + strength * 2.0
			var w4 = 5.0 + Globals.current_wave * 0.4 + strength * 1.5
			var total_w = w0 + w1 + w2 + w3 + w4
			var roll = randf() * total_w
			var type_idx = 0
			if roll < w0: type_idx = 0
			elif roll < w0 + w1: type_idx = 1
			elif roll < w0 + w1 + w2: type_idx = 2
			elif roll < w0 + w1 + w2 + w3: type_idx = 3
			else: type_idx = 4
			
			item.item_type_index = type_idx
			item.global_position = global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			get_parent().add_child.call_deferred(item)
			
	# Drop bullet pickups: scale count and amount
	if _bullet_pickup_scene:
		var num_bullets = clampi(3 + int(Globals.current_wave / 4.0) + int(strength / 3.0), 3, 8)
		for i in range(num_bullets):
			var b = _bullet_pickup_scene.instantiate()
			b.bullet_type_index = randi_range(0, 4)
			b.amount = clampi(int(randi_range(20, 50) * (1.0 + Globals.current_wave * 0.04 + strength * 0.05)), 10, 150)
			b.global_position = global_position + Vector2(randf_range(-45, 45), randf_range(-45, 45))
			get_parent().add_child.call_deferred(b)
			
	# Drop health: scale count
	if _health_pickup_scene:
		var num_hp = clampi(1 + int(Globals.current_wave / 6.0), 1, 3)
		for i in range(num_hp):
			var hp = _health_pickup_scene.instantiate()
			hp.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			get_parent().add_child.call_deferred(hp)

	# Track unique boss kills per zone
	if Globals.selected_map == "res://Scenes/Locations/map_1.tscn":
		if not Globals.zone1_bosses_defeated.has(boss_name):
			Globals.zone1_bosses_defeated.append(boss_name)
			Globals.save()
	elif Globals.selected_map == "res://Scenes/Locations/cemetery_hills.tscn":
		if not Globals.zone2_bosses_defeated.has(boss_name):
			Globals.zone2_bosses_defeated.append(boss_name)
			Globals.save()

	super()

func _process(delta: float) -> void:
	if is_dead:
		return
		
	_heart_beat_timer += delta
	queue_redraw()
		
	# Heart boss heartbeat scaling pulse
	if boss_name.contains("Heart"):
		var pulse: float = 1.0 + abs(sin(_heart_beat_timer * 5.0)) * 0.12
		scale = Vector2(2.0, 2.0) * pulse
		
	# Special movement behaviors
	if lunge_duration > 0.0:
		lunge_duration -= delta
		velocity = lunge_dir * (move_speed * 4.0)
		move_and_slide()
		if player_target and global_position.distance_to(player_target.global_position) < 50.0:
			if player_target.has_method("take_damage"):
				player_target.take_damage(damage * 1.5)
				var push_dir = global_position.direction_to(player_target.global_position).normalized()
				if player_target.get("velocity") != null:
					player_target.velocity += push_dir * 300.0
			lunge_duration = 0.0
		if lunge_duration <= 0.0:
			current_speed = move_speed
		return
		
	if laser_duration > 0.0:
		laser_duration -= delta
		if player_target:
			laser_hit_pos = player_target.global_position
			if player_target.has_method("take_damage") and randf() < 0.15:
				player_target.take_damage(4.0)
		if laser_duration <= 0.0:
			draw_laser = false
			queue_redraw()
			
	if sprint_timer > 0.0:
		sprint_timer -= delta
		current_speed = move_speed * 2.0
		if sprint_timer <= 0.0:
			current_speed = move_speed

	super(delta)
	
	if ability_timer > 0.0:
		ability_timer -= delta
	else:
		ability_timer = randf_range(5.0, 8.0)
		if abilities.size() > 0:
			_use_random_ability()

func _use_random_ability() -> void:
	if not player_target or not is_instance_valid(player_target):
		return
		
	var ability = abilities.pick_random()
	match ability:
		"smash":
			_trigger_smash()
		"lunge":
			_trigger_lunge()
		"sprint":
			_trigger_sprint()
		"summon_weak":
			_trigger_summon_weak()
		"flying_sword":
			_trigger_flying_sword()
		"explosion":
			_trigger_explosion()
		"lazer_eyes":
			_trigger_laser_eyes()
		"repulsion_attraction":
			_trigger_repulsion_attraction()
		"force_swap":
			_trigger_force_swap()

func _trigger_smash() -> void:
	draw_smash_circle = true
	smash_circle_radius = 10.0
	queue_redraw()
	
	var tw = create_tween()
	tw.tween_property(self, "smash_circle_radius", 130.0, 0.8)
	tw.tween_callback(func():
		draw_smash_circle = false
		queue_redraw()
		var targets = get_tree().get_nodes_in_group("targets")
		for t in targets:
			if is_instance_valid(t) and t.has_method("take_damage"):
				var dist = global_position.distance_to(t.global_position)
				if dist <= 130.0:
					t.take_damage(damage * 1.3)
					var push_dir = global_position.direction_to(t.global_position).normalized()
					if t.get("velocity") != null:
						t.velocity += push_dir * 500.0
		var main_player = get_tree().get_first_node_in_group("player")
		if main_player and main_player.has_method("_shake_screen"):
			main_player._shake_screen(12.0, 0.4)
		AudioManager.play_zombie_groan()
	)

func _trigger_lunge() -> void:
	if not player_target:
		return
	lunge_dir = global_position.direction_to(player_target.global_position).normalized()
	lunge_duration = 0.5
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(3.0, 0.3, 0.3), 0.15)
	tw.tween_property(self, "modulate", original_modulate, 0.15)

func _trigger_sprint() -> void:
	sprint_timer = 3.0
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1.5, 1.5, 0.5), 0.2)
	tw.tween_property(self, "modulate", original_modulate, 2.8)

func _trigger_summon_weak() -> void:
	var zombie_scene = load("res://Scenes/Zombies/zombie_slow.tscn")
	if not zombie_scene:
		zombie_scene = load("res://Scenes/Zombies/zombie_base.tscn")
		
	for i in range(3):
		var angle = randf_range(0, TAU)
		var spawn_pos = global_position + Vector2.from_angle(angle) * 70.0
		var z = zombie_scene.instantiate()
		z.scale = Vector2(0.8, 0.8)
		z.max_health = 40.0
		z.health = 40.0
		z.global_position = spawn_pos
		get_parent().add_child(z)
		
	var portal_indicator = Line2D.new()
	portal_indicator.width = 3.0
	portal_indicator.default_color = Color(0.7, 0.2, 0.9, 0.7)
	var pts = PackedVector2Array()
	for j in range(17):
		var ang = j * (TAU / 16.0)
		pts.append(Vector2.from_angle(ang) * 70.0)
	portal_indicator.points = pts
	add_child(portal_indicator)
	
	var tw = create_tween()
	tw.tween_property(portal_indicator, "scale", Vector2(1.5, 1.5), 0.5)
	tw.parallel().tween_property(portal_indicator, "modulate:a", 0.0, 0.5)
	tw.tween_callback(portal_indicator.queue_free)

func _trigger_flying_sword() -> void:
	if not player_target:
		return
	var base_dir = global_position.direction_to(player_target.global_position).normalized()
	var angles = [-0.25, 0.0, 0.25]
	for angle in angles:
		var dir = base_dir.rotated(angle)
		_spawn_sword_projectile(dir)

func _spawn_sword_projectile(dir: Vector2) -> void:
	var sword = Line2D.new()
	sword.width = 4.0
	sword.default_color = Color(0.9, 0.9, 0.95, 0.9)
	sword.points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(25, 0),
		Vector2(20, -4),
		Vector2(25, 0),
		Vector2(20, 4)
	])
	get_parent().add_child(sword)
	sword.global_position = global_position
	sword.rotation = dir.angle()
	
	var tw = create_tween()
	var dest = global_position + dir * 600.0
	tw.tween_property(sword, "global_position", dest, 1.0)
	tw.parallel().tween_property(sword, "rotation", dir.angle() + 10.0, 1.0)
	tw.tween_callback(sword.queue_free)
	
	var hit_check_timer = get_tree().create_timer(1.0)
	var check_state = { "active": true }
	hit_check_timer.timeout.connect(func(): check_state.active = false)
	
	var check_loop = func():
		while check_state.active and is_instance_valid(sword):
			var targets = get_tree().get_nodes_in_group("targets")
			for t in targets:
				if is_instance_valid(t) and t.has_method("take_damage"):
					if sword.global_position.distance_to(t.global_position) < 30.0:
						t.take_damage(15.0)
						check_state.active = false
						sword.queue_free()
						break
			await get_tree().process_frame
	
	check_loop.call()

func _trigger_explosion() -> void:
	draw_smash_circle = true
	smash_circle_radius = 10.0
	queue_redraw()
	
	var tw = create_tween()
	tw.tween_property(self, "smash_circle_radius", 150.0, 1.2)
	tw.tween_callback(func():
		draw_smash_circle = false
		queue_redraw()
		var targets = get_tree().get_nodes_in_group("targets")
		for t in targets:
			if is_instance_valid(t) and t.has_method("take_damage"):
				var dist = global_position.distance_to(t.global_position)
				if dist <= 150.0:
					t.take_damage(damage * 1.5)
		var exp_ring = Line2D.new()
		exp_ring.width = 6.0
		exp_ring.default_color = Color(1.0, 0.4, 0.1, 0.9)
		var pts = PackedVector2Array()
		for j in range(17):
			var ang = j * (TAU / 16.0)
			pts.append(Vector2.from_angle(ang) * 150.0)
		exp_ring.points = pts
		add_child(exp_ring)
		var tw2 = create_tween()
		tw2.tween_property(exp_ring, "scale", Vector2(1.2, 1.2), 0.3)
		tw2.parallel().tween_property(exp_ring, "modulate:a", 0.0, 0.3)
		tw2.tween_callback(exp_ring.queue_free)
		
		var main_player = get_tree().get_first_node_in_group("player")
		if main_player and main_player.has_method("_shake_screen"):
			main_player._shake_screen(15.0, 0.5)
		AudioManager.play_zombie_groan()
	)

func _trigger_laser_eyes() -> void:
	if not player_target:
		return
	draw_laser = true
	laser_duration = 1.8
	laser_hit_pos = player_target.global_position
	queue_redraw()

func _trigger_repulsion_attraction() -> void:
	attraction_pulse = (randf() < 0.5)
	draw_repulsion_circle = true
	repulsion_circle_radius = 200.0 if attraction_pulse else 10.0
	queue_redraw()
	
	var tw = create_tween()
	if attraction_pulse:
		tw.tween_property(self, "repulsion_circle_radius", 10.0, 0.8)
	else:
		tw.tween_property(self, "repulsion_circle_radius", 200.0, 0.8)
		
	tw.tween_callback(func():
		draw_repulsion_circle = false
		queue_redraw()
		
		var targets = get_tree().get_nodes_in_group("targets")
		for t in targets:
			if is_instance_valid(t) and t.has_method("take_damage"):
				var dist = global_position.distance_to(t.global_position)
				if dist <= 220.0:
					var force_dir = global_position.direction_to(t.global_position).normalized()
					if attraction_pulse:
						force_dir = -force_dir
					if t.get("velocity") != null:
						t.velocity += force_dir * 800.0
					t.take_damage(5.0)
	)

func _trigger_force_swap() -> void:
	draw_disarm_circle = true
	disarm_circle_radius = 10.0
	queue_redraw()
	
	var tw = create_tween()
	tw.tween_property(self, "disarm_circle_radius", 250.0, 0.8)
	tw.tween_callback(func():
		draw_disarm_circle = false
		queue_redraw()
		
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			if dist <= 250.0:
				if player.has_method("_select_weapon_slot") and player.get("carried_weapons").size() > 1:
					var current_slot = player.get("active_slot")
					var new_slot = (current_slot + 1) % player.get("carried_weapons").size()
					player._select_weapon_slot(new_slot)
					
					var disarm_lbl := Label.new()
					disarm_lbl.text = "WEAPON SWAPPED / DISARMED!"
					disarm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					disarm_lbl.add_theme_font_size_override("font_size", 10)
					disarm_lbl.add_theme_color_override("font_color", Color(0.8, 0.2, 1.0))
					disarm_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
					disarm_lbl.add_theme_constant_override("outline_size", 3)
					disarm_lbl.position = Vector2(-100, -50)
					player.add_child(disarm_lbl)
					var tw_lbl = create_tween()
					tw_lbl.tween_property(disarm_lbl, "position:y", -70.0, 1.2)
					tw_lbl.parallel().tween_property(disarm_lbl, "modulate:a", 0.0, 1.2)
					tw_lbl.tween_callback(disarm_lbl.queue_free)
	)

func _draw() -> void:
	# Custom procedural boss graphics
	match boss_type:
		"spine":
			_draw_spine()
		"skull":
			_draw_skull()
		"heart":
			_draw_heart()
		"true_cyborg":
			_draw_cyborg()
		"prototype":
			_draw_prototype()
		"zombiefied_giant":
			_draw_zombiefied_giant()
		"fake_true_giant":
			_draw_fake_true_giant()

	if draw_smash_circle:
		draw_circle(Vector2.ZERO, smash_circle_radius, Color(0.9, 0.2, 0.2, 0.3))
		draw_arc(Vector2.ZERO, smash_circle_radius, 0.0, TAU, 32, Color(0.9, 0.1, 0.1, 0.8), 2.0)
		
	if draw_repulsion_circle:
		var color_circle = Color(0.2, 0.6, 1.0, 0.25) if attraction_pulse else Color(1.0, 0.4, 0.2, 0.25)
		var color_border = Color(0.1, 0.5, 0.9, 0.8) if attraction_pulse else Color(0.9, 0.3, 0.1, 0.8)
		draw_circle(Vector2.ZERO, repulsion_circle_radius, color_circle)
		draw_arc(Vector2.ZERO, repulsion_circle_radius, 0.0, TAU, 32, color_border, 2.0)
		
	if draw_disarm_circle:
		draw_circle(Vector2.ZERO, disarm_circle_radius, Color(0.7, 0.1, 0.8, 0.25))
		draw_arc(Vector2.ZERO, disarm_circle_radius, 0.0, TAU, 32, Color(0.6, 0.1, 0.7, 0.8), 2.0)
		
	if draw_laser:
		var local_laser_target = to_local(laser_hit_pos)
		draw_line(Vector2(0, -10), local_laser_target, Color(1.0, 0.0, 0.0, 0.9), 3.0)
		draw_circle(local_laser_target, 4.0, Color(1.0, 0.4, 0.4))

func _draw_spine() -> void:
	var vertebrae_count := 6
	for i in range(vertebrae_count):
		var x = -20.0 + i * 8.0
		var wiggle = sin(_heart_beat_timer * 10.0 - i * 1.2) * 5.0
		var pos = Vector2(x, wiggle)
		if i >= 1 and i <= 4:
			draw_arc(pos + Vector2(-2, -5), 8.0, PI, PI * 1.5, 8, Color(0.6, 0.85, 1.0, 0.65), 1.5)
			draw_arc(pos + Vector2(-2, 5), 8.0, PI * 0.5, PI, 8, Color(0.6, 0.85, 1.0, 0.65), 1.5)
		draw_circle(pos, 4.5, Color(0.9, 0.9, 0.85))
		draw_line(pos, pos + Vector2(0, -7), Color(0.85, 0.85, 0.8), 2.0)
		draw_line(pos, pos + Vector2(0, 7), Color(0.85, 0.85, 0.8), 2.0)
		draw_line(pos, pos + Vector2(-5, 0), Color(0.8, 0.8, 0.75), 1.8)
	var head_x = -20.0 + vertebrae_count * 8.0
	var head_wiggle = sin(_heart_beat_timer * 10.0 - vertebrae_count * 1.2) * 5.0
	var head_pos = Vector2(head_x, head_wiggle)
	draw_circle(head_pos, 6.5, Color(0.92, 0.92, 0.88))
	draw_circle(head_pos + Vector2(3, -2.2), 1.8, Color(0.1, 0.1, 0.15))
	draw_circle(head_pos + Vector2(3, 2.2), 1.8, Color(0.1, 0.1, 0.15))
	draw_circle(head_pos + Vector2(3.5, -2.2), 0.7, Color(0.4, 0.9, 1.0))
	draw_circle(head_pos + Vector2(3.5, 2.2), 0.7, Color(0.4, 0.9, 1.0))

func _draw_skull() -> void:
	draw_circle(Vector2(-3, 0), 16.0, Color(0.95, 0.95, 0.9))
	var jaw_pts = PackedVector2Array([
		Vector2(-3, -10),
		Vector2(15, -7),
		Vector2(15, 7),
		Vector2(-3, 10)
	])
	draw_polygon(jaw_pts, PackedColorArray([Color(0.9, 0.9, 0.85)]))
	var left_socket = Vector2(5, -6)
	var right_socket = Vector2(5, 6)
	draw_circle(left_socket, 4.0, Color(0.08, 0.08, 0.08))
	draw_circle(right_socket, 4.0, Color(0.08, 0.08, 0.08))
	var pupil_pulse = 1.2 + sin(_heart_beat_timer * 8.0) * 0.4
	draw_circle(left_socket + Vector2(1, 0), pupil_pulse, Color(0.8, 0.2, 1.0))
	draw_circle(right_socket + Vector2(1, 0), pupil_pulse, Color(0.8, 0.2, 1.0))
	var nose_pts = PackedVector2Array([
		Vector2(10, 0),
		Vector2(7, -2),
		Vector2(7, 2)
	])
	draw_polygon(nose_pts, PackedColorArray([Color(0.08, 0.08, 0.08)]))
	draw_line(Vector2(15, -5), Vector2(15, 5), Color(0.3, 0.3, 0.3), 1.5)
	draw_line(Vector2(11, -3), Vector2(15, -3), Color(0.4, 0.4, 0.4), 1.0)
	draw_line(Vector2(11, 0), Vector2(15, 0), Color(0.4, 0.4, 0.4), 1.0)
	draw_line(Vector2(11, 3), Vector2(15, 3), Color(0.4, 0.4, 0.4), 1.0)

func _draw_heart() -> void:
	var scale_factor: float = 1.0 + abs(sin(_heart_beat_timer * 5.0)) * 0.1
	draw_circle(Vector2(-3, -4) * scale_factor, 13.0 * scale_factor, Color(0.8, 0.05, 0.08))
	draw_circle(Vector2(-3, 4) * scale_factor, 11.5 * scale_factor, Color(0.65, 0.02, 0.05))
	var apex_pts = PackedVector2Array([
		Vector2(-3, -11) * scale_factor,
		Vector2(-16, 0) * scale_factor,
		Vector2(-3, 11) * scale_factor
	])
	draw_polygon(apex_pts, PackedColorArray([Color(0.7, 0.03, 0.06)]))
	draw_line(Vector2(-3, -5) * scale_factor, Vector2(13, -7) * scale_factor, Color(0.48, 0.15, 0.45), 4.5 * scale_factor)
	draw_line(Vector2(-3, 5) * scale_factor, Vector2(11, 7) * scale_factor, Color(0.4, 0.12, 0.4), 5.0 * scale_factor)
	var pulse_bright = 0.7 + sin(_heart_beat_timer * 12.0) * 0.3
	var vein_color = Color(1.0, 0.35 * pulse_bright, 0.1 * pulse_bright)
	draw_line(Vector2(-10, 0), Vector2(-2, -3), vein_color, 1.2)
	draw_line(Vector2(-2, -3), Vector2(4, -5), vein_color, 1.2)
	draw_line(Vector2(-10, 0), Vector2(-4, 3), vein_color, 1.0)
	draw_line(Vector2(-4, 3), Vector2(2, 5), vein_color, 1.0)

func _draw_cyborg() -> void:
	draw_circle(Vector2.ZERO, 14.0, Color(0.22, 0.24, 0.28))
	draw_arc(Vector2.ZERO, 14.0, 0, TAU, 32, Color(0.5, 0.55, 0.6), 2.5)
	draw_circle(Vector2(2, 0), 8.0, Color(0.12, 0.14, 0.16))
	draw_line(Vector2(-9, -6), Vector2(1, -6), Color(0.1, 0.85, 1.0, 0.85), 1.2)
	draw_line(Vector2(1, -6), Vector2(6, -1), Color(0.1, 0.85, 1.0, 0.85), 1.2)
	draw_line(Vector2(-9, 6), Vector2(1, 6), Color(0.1, 0.85, 1.0, 0.85), 1.2)
	draw_line(Vector2(1, 6), Vector2(6, 1), Color(0.1, 0.85, 1.0, 0.85), 1.2)
	var scan_offset = sin(_heart_beat_timer * 7.0) * 4.0
	var scan_pos = Vector2(8.0, scan_offset)
	draw_circle(scan_pos, 2.2, Color(1.0, 0.1, 0.15))

func _draw_prototype() -> void:
	var frame_pts = PackedVector2Array([
		Vector2(14, 0),
		Vector2(4, -11),
		Vector2(-11, -11),
		Vector2(-14, -5),
		Vector2(-14, 5),
		Vector2(-11, 11),
		Vector2(4, 11)
	])
	draw_polygon(frame_pts, PackedColorArray([Color(0.85, 0.72, 0.08)]))
	draw_line(Vector2(-6, -11), Vector2(-11, -6), Color(0.1, 0.1, 0.1), 2.0)
	draw_line(Vector2(-1, -11), Vector2(-9, -3), Color(0.1, 0.1, 0.1), 2.0)
	draw_line(Vector2(4, -11), Vector2(-7, 0), Color(0.1, 0.1, 0.1), 2.0)
	draw_line(Vector2(-6, 11), Vector2(-11, 6), Color(0.1, 0.1, 0.1), 2.0)
	draw_line(Vector2(-1, 11), Vector2(-9, 3), Color(0.1, 0.1, 0.1), 2.0)
	draw_line(Vector2(4, 11), Vector2(-7, 0), Color(0.1, 0.1, 0.1), 2.0)
	draw_rect(Rect2(7, -8, 9, 2.5), Color(0.22, 0.22, 0.22))
	draw_rect(Rect2(7, 5.5, 9, 2.5), Color(0.22, 0.22, 0.22))
	var pulse_core = 3.5 + sin(_heart_beat_timer * 15.0) * 1.0
	draw_circle(Vector2(-2, 0), pulse_core, Color(0.2, 0.9, 0.35))
	draw_circle(Vector2(-2, 0), 1.8, Color(0.8, 1.0, 0.85))

func _draw_zombiefied_giant() -> void:
	draw_circle(Vector2(-4, 0), 20.0, Color(0.2, 0.55, 0.25))
	draw_circle(Vector2(-2, -15), 9.0, Color(0.15, 0.45, 0.2))
	draw_circle(Vector2(-2, 15), 9.0, Color(0.15, 0.45, 0.2))
	draw_line(Vector2(-2, -15), Vector2(15, -16), Color(0.15, 0.45, 0.2), 7.0)
	draw_line(Vector2(-2, 15), Vector2(15, 16), Color(0.15, 0.45, 0.2), 7.0)
	draw_line(Vector2(-10, -5), Vector2(-6, -5), Color(0.9, 0.9, 0.85), 1.8)
	draw_line(Vector2(-11, 0), Vector2(-5, 0), Color(0.9, 0.9, 0.85), 1.8)
	draw_line(Vector2(-10, 5), Vector2(-6, 5), Color(0.9, 0.9, 0.85), 1.8)
	draw_circle(Vector2(-8, -8), 4.0, Color(0.35, 0.32, 0.15))
	draw_circle(Vector2(-1, 7), 5.0, Color(0.35, 0.32, 0.15))

func _draw_fake_true_giant() -> void:
	var rock_pts = PackedVector2Array([
		Vector2(16, 0),
		Vector2(5, -15),
		Vector2(-14, -12),
		Vector2(-14, 12),
		Vector2(5, 15)
	])
	draw_polygon(rock_pts, PackedColorArray([Color(0.22, 0.2, 0.2)]))
	draw_line(Vector2(-14, 0), Vector2(16, 0), Color(1.0, 0.45, 0.0), 1.5)
	draw_line(Vector2(-14, -6), Vector2(5, -15), Color(1.0, 0.45, 0.0), 1.2)
	draw_line(Vector2(-14, 6), Vector2(5, 15), Color(1.0, 0.45, 0.0), 1.2)
	draw_line(Vector2(5, -15), Vector2(0, 0), Color(1.0, 0.45, 0.0), 1.2)
	draw_line(Vector2(5, 15), Vector2(0, 0), Color(1.0, 0.45, 0.0), 1.2)
	var pulse_core = 6.0 + sin(_heart_beat_timer * 8.0) * 1.5
	draw_circle(Vector2(0, 0), pulse_core, Color(1.0, 0.5, 0.05))
	draw_circle(Vector2(0, 0), 2.5, Color(1.0, 0.85, 0.2))

func _add_boss_effects(type: String) -> void:
	var particles := CPUParticles2D.new()
	particles.name = "BossParticles"
	particles.amount = 35
	particles.lifetime = 1.0
	particles.preprocess = 0.5
	particles.explosiveness = 0.0
	particles.randomness = 0.5
	
	# Common properties
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 20.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 10.0
	particles.initial_velocity_max = 30.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	
	# Custom colors & curves per boss
	var color_ramp := Gradient.new()
	
	match type:
		"spine":
			# Ice/Frost blue aura
			color_ramp.set_colors(PackedColorArray([Color(0.5, 0.8, 1.0, 0.8), Color(0.1, 0.4, 0.8, 0.0)]))
			particles.amount = 40
			particles.scale_amount_min = 1.5
			particles.scale_amount_max = 3.5
		"skull":
			# Purple shadow flame aura
			color_ramp.set_colors(PackedColorArray([Color(0.8, 0.2, 0.9, 0.8), Color(0.3, 0.05, 0.4, 0.0)]))
			particles.amount = 45
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 6.0
		"heart":
			# Crimson blood pulse
			color_ramp.set_colors(PackedColorArray([Color(1.0, 0.05, 0.05, 0.8), Color(0.4, 0.0, 0.0, 0.0)]))
			particles.amount = 50
			particles.scale_amount_min = 3.0
			particles.scale_amount_max = 8.0
		"true_cyborg":
			# Electric sparks
			color_ramp.set_colors(PackedColorArray([Color(0.1, 0.9, 1.0, 0.9), Color(0.0, 0.3, 0.6, 0.0)]))
			particles.amount = 30
			particles.initial_velocity_min = 40.0
			particles.initial_velocity_max = 80.0
			particles.scale_amount_min = 1.0
			particles.scale_amount_max = 3.0
		"prototype":
			# Golden high tech particles
			color_ramp.set_colors(PackedColorArray([Color(1.0, 0.9, 0.2, 0.9), Color(0.5, 0.4, 0.0, 0.0)]))
			particles.amount = 35
			particles.initial_velocity_min = 20.0
			particles.initial_velocity_max = 50.0
			particles.scale_amount_min = 1.5
			particles.scale_amount_max = 4.0
		"zombiefied_giant":
			# Green acid sludge dripping
			color_ramp.set_colors(PackedColorArray([Color(0.2, 0.9, 0.2, 0.8), Color(0.05, 0.4, 0.05, 0.0)]))
			particles.amount = 40
			particles.gravity = Vector2(0, 50) # Fall down
			particles.scale_amount_min = 3.0
			particles.scale_amount_max = 7.0
		"fake_true_giant":
			# Orange/Fire energy aura
			color_ramp.set_colors(PackedColorArray([Color(1.0, 0.6, 0.05, 0.8), Color(0.6, 0.2, 0.0, 0.0)]))
			particles.amount = 50
			particles.scale_amount_min = 2.0
			particles.scale_amount_max = 6.0

	particles.color_ramp = color_ramp
	add_child(particles)
