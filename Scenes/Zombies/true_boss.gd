extends CharacterBody2D

# ── Identity ──────────────────────────────────────────────────────────────────
const BOSS_NAME := "Anurag Shre"
const MAX_HEALTH := 5000.0

# ── State ─────────────────────────────────────────────────────────────────────
var health: float = MAX_HEALTH
var is_dead: bool = false
var phase: int = 0        # 0-5  maps to 6 scripture abilities
var phase_timer: float = 0.0
var ability_cd: float = 0.0
var move_speed: float = 140.0
var atmo_timer: float = 0.0

# Phase flags
var _invincible: bool = false
var _reflecting: bool = false
var _flying: bool = false
var _fly_offset: float = 0.0
var _regen_active: bool = false
var _poison_pools: Array = []

# Mini-boss borrowed abilities state
var _lunge_duration: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO
var _disarm_ring_radius: float = 0.0
var _draw_disarm_ring: bool = false
var _shield_active: bool = false
var _shield_timer: float = 0.0
var _draw_repulsion_ring: bool = false
var _repulsion_ring_radius: float = 0.0
var _repulsion_attract: bool = false

# Whip / sword arm
var _whip_extended: bool = false
var _whip_timer: float = 0.0
var _whip_line: Line2D

# Wings
var _wing_l: Line2D
var _wing_r: Line2D

# Jetpack particles
var _jet_l: CPUParticles2D
var _jet_r: CPUParticles2D

# Body sprite
var _body_poly: Sprite2D

# HUD
var _health_bar: ProgressBar
var _phase_label: Label
var _name_label: Label

# Navigation
var nav_agent: NavigationAgent2D
var player_target: Node2D = null

var _bullet_scene := preload("res://Scenes/Projectiles/bullet.tscn")

# ── Phase definitions ─────────────────────────────────────────────────────────
const PHASES := [
	{"name": "PERSEVERANCE",        "color": Color(0.10, 0.06, 0.08), "hp_pct": 1.00},
	{"name": "DETACHED TEMPERAMENT","color": Color(0.70, 0.80, 0.85), "hp_pct": 0.84},
	{"name": "COVETOUSNESS",        "color": Color(0.45, 0.05, 0.65), "hp_pct": 0.68},
	{"name": "SELF-INTEGRITY",      "color": Color(0.05, 0.05, 0.07), "hp_pct": 0.52},
	{"name": "RESOLVE & RUTHLESSNESS","color": Color(0.75, 0.05, 0.05),"hp_pct": 0.36},
	{"name": "CUNNING",             "color": Color(0.05, 0.45, 0.10), "hp_pct": 0.20},
]

const QUOTES := [
	"\"He who walks a thousand miles finishes with a thousand more no one sees.\"",
	"\"The wise man feels the storm but does not become it.\"",
	"\"I will take what is mine. Then I will take what isn't.\"",
	"\"Better to reign in Hell than serve in Heaven.\"",
	"\"If I must burn the world to keep my promise, I will strike the first match.\"",
	"\"The perfect game is won before the opponent knows he is playing.\""
]

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("zombies")
	add_to_group("true_boss")
	collision_layer = 2
	collision_mask = 7
	scale = Vector2(2.2, 2.2)
	
	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 20.0
	add_child(nav_agent)
	
	_build_visuals()
	_enter_phase(0)
	
	get_tree().create_timer(0.5).timeout.connect(func():
		DialogManager.show_dialog([
			{"speaker": "Anurag Shre", "text": "So. Subject 73 finally woke up. Perfect. I need a living test subject.", "color": Color(0.2, 0.9, 0.3)},
			{"speaker": "Anurag Shre", "text": "Do you know how many web novels I read before I found the formula? Immortality is a science, not a myth.", "color": Color(0.2, 0.9, 0.3)},
			{"speaker": "Kaelan", "text": "You experimented on me. You stole my life.", "color": Color(0.2, 0.8, 1.0)},
			{"speaker": "Anurag Shre", "text": "I GIFTED you purpose. Now hold still — this will only hurt permanently.", "color": Color(0.2, 0.9, 0.3)},
		])
	)

func _build_visuals() -> void:
	# Mad Scientist Sprite
	_body_poly = Sprite2D.new()
	_body_poly.texture = load("res://Last Stand Assets/Characters/PNG/Man Old/manOld_machine.png")
	add_child(_body_poly)
	
	# Whip arm (right)
	_whip_line = Line2D.new()
	_whip_line.width = 3.0
	_whip_line.default_color = Color(0.7, 0.6, 0.1)
	_whip_line.points = PackedVector2Array([Vector2(18, 0), Vector2(28, 0)])
	add_child(_whip_line)
	
	# Wings
	_wing_l = Line2D.new()
	_wing_l.width = 2.5
	_wing_l.default_color = Color(0.3, 0.5, 0.4, 0.7)
	_wing_l.visible = false
	add_child(_wing_l)
	
	_wing_r = Line2D.new()
	_wing_r.width = 2.5
	_wing_r.default_color = Color(0.3, 0.5, 0.4, 0.7)
	_wing_r.visible = false
	add_child(_wing_r)
	
	# Jetpacks
	_jet_l = CPUParticles2D.new()
	_jet_l.emitting = false
	_jet_l.amount = 12
	_jet_l.lifetime = 0.4
	_jet_l.direction = Vector2(0, 1)
	_jet_l.spread = 20.0
	_jet_l.initial_velocity_min = 80.0
	_jet_l.initial_velocity_max = 130.0
	_jet_l.color = Color(1.0, 0.5, 0.1)
	_jet_l.position = Vector2(-14, 20)
	add_child(_jet_l)
	
	_jet_r = CPUParticles2D.new()
	_jet_r.emitting = false
	_jet_r.amount = 12
	_jet_r.lifetime = 0.4
	_jet_r.direction = Vector2(0, 1)
	_jet_r.spread = 20.0
	_jet_r.initial_velocity_min = 80.0
	_jet_r.initial_velocity_max = 130.0
	_jet_r.color = Color(1.0, 0.5, 0.1)
	_jet_r.position = Vector2(14, 20)
	add_child(_jet_r)
	
	# Screen-space Dark Souls style HUD
	var canvas := CanvasLayer.new()
	canvas.layer = 100 # Put it above everything
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
	
	_name_label = Label.new()
	_name_label.text = BOSS_NAME.to_upper()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	_name_label.add_theme_color_override("font_outline_color", Color(0,0,0))
	_name_label.add_theme_constant_override("outline_size", 8)
	vbox.add_child(_name_label)
	
	_health_bar = ProgressBar.new()
	_health_bar.max_value = MAX_HEALTH
	_health_bar.value = health
	_health_bar.show_percentage = false
	var screen_w: float = get_viewport_rect().size.x
	var bar_width: float = min(800.0, screen_w - 160.0)
	_health_bar.custom_minimum_size = Vector2(bar_width, 24)
	_health_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.05, 0.9)
	bg.border_width_left = 3; bg.border_width_right = 3; bg.border_width_top = 3; bg.border_width_bottom = 3
	bg.border_color = Color(0.3, 0.3, 0.3, 0.8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.2, 0.9, 0.3)
	_health_bar.add_theme_stylebox_override("background", bg)
	_health_bar.add_theme_stylebox_override("fill", fg)
	vbox.add_child(_health_bar)
	
	_phase_label = Label.new()
	_phase_label.text = ""
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_size_override("font_size", 18)
	_phase_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_phase_label.add_theme_color_override("font_outline_color", Color(0,0,0))
	_phase_label.add_theme_constant_override("outline_size", 5)
	vbox.add_child(_phase_label)

# ── Phase transition ──────────────────────────────────────────────────────────
func _enter_phase(p: int) -> void:
	phase = p
	_invincible = false
	_reflecting = false
	_regen_active = false
	_flying = false
	_jet_l.emitting = false
	_jet_r.emitting = false
	_wing_l.visible = false
	_wing_r.visible = false
	ability_cd = 3.0
	
	var pdata = PHASES[p]
	_body_poly.modulate = pdata["color"]
	_phase_label.text = "[ %s ]" % pdata["name"]
	
	var fg2 := StyleBoxFlat.new()
	fg2.bg_color = pdata["color"].lightened(0.3)
	_health_bar.add_theme_stylebox_override("fill", fg2)
	
	DialogManager.show_dialog([
		{"speaker": "Anurag Shre", "text": QUOTES[p], "color": pdata["color"].lightened(0.5)},
	], false)
	
	# Phase-specific setup
	match p:
		0: _regen_active = true
		1: _reflecting = true
		3: pass  # integrity = brief invincibility bursts handled in process
		4:
			_flying = true
			_jet_l.emitting = true
			_jet_r.emitting = true
			_wing_l.visible = true
			_wing_r.visible = true

func _check_phase_transition() -> void:
	var pct := health / MAX_HEALTH
	var target_phase := 0
	for i in range(PHASES.size() - 1, -1, -1):
		if pct <= PHASES[i]["hp_pct"]:
			target_phase = i
			break
	if target_phase > phase:
		_enter_phase(target_phase)

# ── Process ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if is_dead: return
	atmo_timer += delta
	phase_timer += delta
	ability_cd -= delta
	_whip_timer -= delta
	
	if _shield_active:
		_shield_timer -= delta
		if _shield_timer <= 0.0:
			_shield_active = false
			queue_redraw()
			
	if _lunge_duration > 0.0:
		_lunge_duration -= delta
		velocity = _lunge_dir * (move_speed * 3.5)
		move_and_slide()
		if player_target and global_position.distance_to(player_target.global_position) < 60.0:
			if player_target.has_method("take_damage"):
				player_target.take_damage(25.0)
				var push_dir = global_position.direction_to(player_target.global_position).normalized()
				if player_target.get("velocity") != null:
					player_target.velocity += push_dir * 300.0
			_lunge_duration = 0.0
		return
	
	# Regen in Phase 0
	if _regen_active and health < MAX_HEALTH * 0.84:
		health = minf(health + 12.0 * delta, MAX_HEALTH * 0.84)
		if _health_bar: _health_bar.value = health
	
	# Flying bob
	if _flying:
		_fly_offset = sin(atmo_timer * 2.8) * 18.0
		var target_y = global_position.y
		position.y += _fly_offset * delta
		_update_wings()
	
	# Whip animation
	if _whip_extended and _whip_timer <= 0.0:
		_whip_line.points = PackedVector2Array([Vector2(18, 0), Vector2(28, 0)])
		_whip_extended = false
	
	# Find player
	player_target = get_tree().get_first_node_in_group("player")
	if player_target and player_target.get("is_dead") == true:
		player_target = null
	
	if player_target and is_instance_valid(player_target):
		look_at(player_target.global_position)
		nav_agent.target_position = player_target.global_position
		var dist := global_position.distance_to(player_target.global_position)
		
		# Move toward player
		if dist > 180.0:
			var next := nav_agent.get_next_path_position()
			velocity = global_position.direction_to(next) * move_speed * (1.8 if _flying else 1.0)
		else:
			velocity = Vector2.ZERO
		
		# Melee if close
		if dist < 55.0 and phase_timer > 1.5:
			phase_timer = 0.0
			if player_target.has_method("take_damage"):
				player_target.take_damage(30.0 + phase * 8.0)
				_flash_hit()
		
		# Trigger abilities
		if ability_cd <= 0.0:
			_trigger_phase_ability(dist)
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	_check_phase_transition()

func _update_wings() -> void:
	var t := atmo_timer * 3.0
	var span := 70.0 + sin(t) * 20.0
	_wing_l.points = PackedVector2Array([
		Vector2(-16, -10), Vector2(-span, -30 + sin(t) * 15.0), Vector2(-span * 0.5, 10.0)
	])
	_wing_r.points = PackedVector2Array([
		Vector2(16, -10), Vector2(span, -30 + sin(t) * 15.0), Vector2(span * 0.5, 10.0)
	])

# ── Phase abilities ───────────────────────────────────────────────────────────
func _trigger_phase_ability(dist: float) -> void:
	var use_secondary = (randf() < 0.5)
	if use_secondary:
		match phase:
			0: _ability_boss_lunge()
			1: _ability_boss_teleport()
			2: _ability_boss_summon()
			3: _ability_boss_disarm()
			4: _ability_boss_shield()
			5: _ability_boss_repulsion()
	else:
		match phase:
			0: _ability_whip_strike()
			1: _ability_detached_orbit()
			2: _ability_covetous_drain()
			3: _ability_integrity_pulse()
			4: _ability_ruthless_barrage()
			5: _ability_cunning_trap()
	ability_cd = randf_range(4.0, 7.0)

func _ability_boss_lunge() -> void:
	if not player_target: return
	_lunge_duration = 0.8
	_lunge_dir = global_position.direction_to(player_target.global_position).normalized()
	queue_redraw()

func _ability_boss_teleport() -> void:
	if not player_target: return
	var angle = randf() * TAU
	var target_pos = player_target.global_position + Vector2.from_angle(angle) * randf_range(120.0, 200.0)
	
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.7, 0.2, 0.9, 0.8)
	var pts := PackedVector2Array()
	for i in range(17): pts.append(Vector2.from_angle(i * TAU / 16.0) * 30.0)
	ring.points = pts
	get_parent().add_child(ring)
	ring.global_position = target_pos
	
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.4)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		ring.queue_free()
		if is_dead: return
		global_position = target_pos
		for i in range(8):
			_shoot_bullet(Vector2.from_angle(i * TAU / 8.0), 15.0)
	)

func _ability_boss_summon() -> void:
	var zombie_scene = load("res://Scenes/Zombies/zombie_slow.tscn")
	if not zombie_scene:
		zombie_scene = load("res://Scenes/Zombies/zombie_base.tscn")
		
	for i in range(3):
		var angle = randf_range(0, TAU)
		var spawn_pos = global_position + Vector2.from_angle(angle) * 80.0
		var z = zombie_scene.instantiate()
		z.scale = Vector2(0.9, 0.9)
		z.max_health = 60.0
		z.health = 60.0
		z.global_position = spawn_pos
		get_parent().add_child(z)
		
	var portal_indicator = Line2D.new()
	portal_indicator.width = 3.0
	portal_indicator.default_color = Color(0.8, 0.1, 0.1, 0.7)
	var pts = PackedVector2Array()
	for j in range(17):
		pts.append(Vector2.from_angle(j * (TAU / 16.0)) * 80.0)
	portal_indicator.points = pts
	add_child(portal_indicator)
	
	var tw = create_tween()
	tw.tween_property(portal_indicator, "scale", Vector2(1.6, 1.6), 0.5)
	tw.parallel().tween_property(portal_indicator, "modulate:a", 0.0, 0.5)
	tw.tween_callback(portal_indicator.queue_free)

func _ability_boss_disarm() -> void:
	_draw_disarm_ring = true
	_disarm_ring_radius = 10.0
	queue_redraw()
	
	var tw = create_tween()
	tw.tween_property(self, "_disarm_ring_radius", 260.0, 0.8)
	tw.tween_callback(func():
		_draw_disarm_ring = false
		queue_redraw()
		
		if not player_target or is_dead: return
		var dist = global_position.distance_to(player_target.global_position)
		if dist <= 260.0:
			if player_target.has_method("_select_weapon_slot") and player_target.get("carried_weapons").size() > 1:
				var current_slot = player_target.get("active_slot")
				var new_slot = (current_slot + 1) % player_target.get("carried_weapons").size()
				player_target._select_weapon_slot(new_slot)
				
				var disarm_lbl := Label.new()
				disarm_lbl.text = "WEAPON JAMMED / FORCED SWAP!"
				disarm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				disarm_lbl.add_theme_font_size_override("font_size", 12)
				disarm_lbl.add_theme_color_override("font_color", Color(0.9, 0.2, 0.9))
				disarm_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
				disarm_lbl.add_theme_constant_override("outline_size", 4)
				disarm_lbl.position = Vector2(-120, -60)
				player_target.add_child(disarm_lbl)
				
				var tw_lbl = create_tween()
				tw_lbl.tween_property(disarm_lbl, "position:y", -80.0, 1.2)
				tw_lbl.parallel().tween_property(disarm_lbl, "modulate:a", 0.0, 1.2)
				tw_lbl.tween_callback(disarm_lbl.queue_free)
	)

func _ability_boss_shield() -> void:
	_shield_active = true
	_shield_timer = 4.0
	queue_redraw()
	DialogManager.show_dialog([{"speaker": "Anurag Shre", "text": "Deploying electromagnetic shielding barrier.", "color": Color(0.1, 0.7, 1.0)}], false)

func _ability_boss_repulsion() -> void:
	_repulsion_attract = (randf() < 0.5)
	_draw_repulsion_ring = true
	_repulsion_ring_radius = 240.0 if _repulsion_attract else 10.0
	queue_redraw()
	
	var tw = create_tween()
	if _repulsion_attract:
		tw.tween_property(self, "_repulsion_ring_radius", 10.0, 0.8)
	else:
		tw.tween_property(self, "_repulsion_ring_radius", 240.0, 0.8)
		
	tw.tween_callback(func():
		_draw_repulsion_ring = false
		queue_redraw()
		
		if not player_target or is_dead: return
		var dist = global_position.distance_to(player_target.global_position)
		if dist <= 250.0:
			var force_dir = global_position.direction_to(player_target.global_position).normalized()
			if _repulsion_attract:
				force_dir = -force_dir
			if player_target.get("velocity") != null:
				player_target.velocity += force_dir * 950.0
			player_target.take_damage(12.0)
	)

func _draw() -> void:
	if _shield_active:
		draw_arc(Vector2.ZERO, 32.0, 0, TAU, 32, Color(0.1, 0.7, 1.0, 0.8), 3.0)
		draw_circle(Vector2.ZERO, 32.0, Color(0.1, 0.5, 1.0, 0.18))
		
	if _draw_disarm_ring:
		draw_circle(Vector2.ZERO, _disarm_ring_radius, Color(0.8, 0.2, 0.9, 0.2))
		draw_arc(Vector2.ZERO, _disarm_ring_radius, 0.0, TAU, 32, Color(0.8, 0.2, 0.9, 0.75), 2.0)
		
	if _draw_repulsion_ring:
		var color_circle = Color(0.2, 0.6, 1.0, 0.2) if _repulsion_attract else Color(1.0, 0.4, 0.2, 0.2)
		var color_border = Color(0.1, 0.5, 0.9, 0.75) if _repulsion_attract else Color(0.9, 0.3, 0.1, 0.75)
		draw_circle(Vector2.ZERO, _repulsion_ring_radius, color_circle)
		draw_arc(Vector2.ZERO, _repulsion_ring_radius, 0.0, TAU, 32, color_border, 2.0)

func _ability_whip_strike() -> void:
	if not player_target: return
	_whip_extended = true
	_whip_timer = 0.6
	var dir = global_position.direction_to(player_target.global_position)
	var tip = to_local(player_target.global_position)
	_whip_line.points = PackedVector2Array([Vector2(18, 0), tip * 0.5, tip])
	_whip_line.default_color = Color(0.9, 0.8, 0.1)
	
	var tw := create_tween()
	tw.tween_property(_whip_line, "default_color", Color(0.4, 0.3, 0.05), 0.4)
	
	if player_target.has_method("take_damage"):
		var d = global_position.distance_to(player_target.global_position)
		if d < 280.0:
			player_target.take_damage(35.0)
			if player_target.get("velocity") != null:
				player_target.velocity += dir * 400.0

func _ability_detached_orbit() -> void:
	# Spin around player for 2s, fire burst
	if not player_target: return
	var base_pos = player_target.global_position
	for i in range(6):
		await get_tree().create_timer(0.3).timeout
		if is_dead or not is_instance_valid(player_target): return
		var angle = i * (TAU / 6.0)
		var shoot_dir = Vector2(cos(angle), sin(angle))
		_shoot_bullet(shoot_dir, 18.0)

func _ability_covetous_drain() -> void:
	if not player_target: return
	var dist = global_position.distance_to(player_target.global_position)
	if dist > 250.0: return
	
	# Drain ammo
	if player_target.get("bullet_ammo") != null:
		var ammo_arr: Array = player_target.bullet_ammo
		for i in range(ammo_arr.size()):
			ammo_arr[i] = max(0, ammo_arr[i] - 30)
	
	# Visual tendril
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.6, 0.1, 0.8, 0.8)
	line.points = PackedVector2Array([Vector2.ZERO, to_local(player_target.global_position)])
	add_child(line)
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.8)
	tw.tween_callback(line.queue_free)
	
	DialogManager.show_dialog([{"speaker": "Anurag Shre", "text": "Your ammunition is MY resource now.", "color": Color(0.6, 0.1, 0.8)}], false)

func _ability_integrity_pulse() -> void:
	_invincible = true
	_body_poly.modulate = Color(0.0, 0.0, 0.0)
	
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = Color(0.1, 0.1, 0.1, 0.9)
	var pts := PackedVector2Array()
	for i in range(17): pts.append(Vector2.from_angle(i * TAU / 16.0) * 60.0)
	ring.points = pts
	add_child(ring)
	
	# Fire in all directions while invincible
	for i in range(8):
		_shoot_bullet(Vector2.from_angle(i * TAU / 8.0), 20.0)
	
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(2.0, 2.0), 1.2)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func():
		ring.queue_free()
		_invincible = false
		_body_poly.modulate = PHASES[phase]["color"]
	)

func _ability_ruthless_barrage() -> void:
	if not player_target: return
	# Carpet bomb - 5 rapid shots in a spread
	var base_dir = global_position.direction_to(player_target.global_position)
	for i in range(5):
		await get_tree().create_timer(0.12).timeout
		if is_dead: return
		var spread = base_dir.rotated(randf_range(-0.5, 0.5))
		_shoot_bullet(spread, 25.0)
	
	# Explosion ring
	var exp_ring := Line2D.new()
	exp_ring.width = 5.0
	exp_ring.default_color = Color(0.9, 0.2, 0.05, 0.9)
	var pts := PackedVector2Array()
	for i in range(17): pts.append(Vector2.from_angle(i * TAU / 16.0) * 20.0)
	exp_ring.points = pts
	get_parent().add_child(exp_ring)
	exp_ring.global_position = player_target.global_position
	var tw := create_tween()
	tw.tween_property(exp_ring, "scale", Vector2(8.0, 8.0), 0.5)
	tw.parallel().tween_property(exp_ring, "modulate:a", 0.0, 0.5)
	tw.tween_callback(exp_ring.queue_free)
	
	if player_target.has_method("take_damage"):
		player_target.take_damage(20.0)

func _ability_cunning_trap() -> void:
	if not player_target: return
	# Drop 3 poison pools near player
	for i in range(3):
		var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		var pool_pos = player_target.global_position + offset
		_spawn_poison_pool(pool_pos)
	DialogManager.show_dialog([{"speaker": "Anurag Shre", "text": "The perfect game is won before the opponent knows he is playing.", "color": Color(0.1, 0.8, 0.1)}], false)

func _spawn_poison_pool(pos: Vector2) -> void:
	var pool := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(10): pts.append(Vector2.from_angle(i * TAU / 10.0) * randf_range(22, 38))
	pool.polygon = pts
	pool.color = Color(0.05, 0.55, 0.1, 0.7)
	get_parent().add_child(pool)
	pool.global_position = pos
	_poison_pools.append({"node": pool, "timer": 6.0, "pos": pos})
	
	# Tick damage
	var tick := func():
		for _i in range(12):
			await get_tree().create_timer(0.5).timeout
			if not is_instance_valid(pool): return
			var player = get_tree().get_first_node_in_group("player")
			if player and player.global_position.distance_to(pos) < 45.0:
				if player.has_method("take_damage"):
					player.take_damage(6.0)
		if is_instance_valid(pool): pool.queue_free()
	tick.call()

func _shoot_bullet(dir: Vector2, dmg: float) -> void:
	var b := _bullet_scene.instantiate()
	b.is_enemy_bullet = true
	b.initialize(dir, dmg, 700.0, 0)
	get_parent().add_child(b)
	b.global_position = global_position

func _flash_hit() -> void:
	var tw := create_tween()
	tw.tween_property(_body_poly, "modulate", Color(2.0, 0.2, 0.2), 0.06)
	tw.tween_property(_body_poly, "modulate", PHASES[phase]["color"], 0.15)

# ── Damage & Death ────────────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if is_dead or _invincible: return
	if _shield_active:
		var tw := create_tween()
		tw.tween_property(_body_poly, "modulate", Color(0.3, 0.8, 1.0), 0.05)
		tw.tween_property(_body_poly, "modulate", PHASES[phase]["color"], 0.15)
		return
		
	if _reflecting:
		# Reflect 40% back at player
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("take_damage"):
			player.take_damage(amount * 0.4)
		amount *= 0.6
	
	health -= amount
	if _health_bar: _health_bar.value = health
	_flash_hit()
	AudioManager.play_zombie_hit()
	
	if health <= 0.0:
		_die()

func _die() -> void:
	if is_dead: return
	is_dead = true
	set_process(false)
	set_physics_process(false)
	
	# Clear poison pools
	for p in _poison_pools:
		if p["node"] and is_instance_valid(p["node"]): p["node"].queue_free()
	
	# Death VFX - expanding rings
	for i in range(6):
		var ring := Line2D.new()
		ring.width = 5.0
		ring.default_color = Color(0.2, 1.0, 0.3, 0.9)
		var pts := PackedVector2Array()
		for j in range(17): pts.append(Vector2.from_angle(j * TAU / 16.0) * 30.0)
		ring.points = pts
		get_parent().add_child(ring)
		ring.global_position = global_position
		var delay = i * 0.2
		var tw2 := get_tree().create_timer(delay)
		tw2.timeout.connect(func():
			if is_instance_valid(ring):
				var tw3 := create_tween()
				tw3.tween_property(ring, "scale", Vector2(7.0, 7.0), 0.6)
				tw3.parallel().tween_property(ring, "modulate:a", 0.0, 0.6)
				tw3.tween_callback(ring.queue_free)
		)
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_shake_screen"):
		player._shake_screen(20.0, 1.0)
	
	await get_tree().create_timer(1.5).timeout
	
	DialogManager.show_dialog([
		{"speaker": "Anurag Shre", "text": "Im...immortal... this is... impossible...", "color": Color(0.2, 0.9, 0.3)},
		{"speaker": "Anurag Shre", "text": "The formula... was PERFECT. I read every novel... every scripture...", "color": Color(0.15, 0.6, 0.2)},
		{"speaker": "Kaelan", "text": "You were never immortal. You were just afraid of being forgotten.", "color": Color(0.2, 0.8, 1.0)},
		{"speaker": "System", "text": "Anurag Shre has fallen. The Heart Cavern trembles. All altars glow with final power.", "color": Color(1.0, 0.85, 0.1)},
	])
	
	# Notify the cavern to restore walls and enrage surviving mini-bosses
	var cavern = get_parent()
	if cavern and cavern.has_method("on_true_boss_defeated"):
		cavern.on_true_boss_defeated()
	Globals.discover_lore(28)
	Globals.discover_lore(29)
	Globals.discover_lore(30)
	
	# Massive drops scaled by wave number
	var item_scene = load("res://Scenes/Pickups/item_pickup.tscn")
	if item_scene:
		var num_items = clampi(5 + int(Globals.current_wave / 2.0), 5, 12)
		for i in range(num_items):
			var it: Node2D = item_scene.instantiate() as Node2D
			
			# Weighted item index
			var w0 = maxf(10.0, 30.0 - Globals.current_wave * 0.5 - 15.0)
			var w1 = maxf(15.0, 25.0 - Globals.current_wave * 0.2)
			var w2 = 25.0
			var w3 = 15.0 + Globals.current_wave * 0.8 + 20.0
			var w4 = 5.0 + Globals.current_wave * 0.4 + 15.0
			var total_w = w0 + w1 + w2 + w3 + w4
			var roll = randf() * total_w
			var type_idx = 0
			if roll < w0: type_idx = 0
			elif roll < w0 + w1: type_idx = 1
			elif roll < w0 + w1 + w2: type_idx = 2
			elif roll < w0 + w1 + w2 + w3: type_idx = 3
			else: type_idx = 4
			
			it.item_type_index = type_idx
			it.global_position = global_position + Vector2(randf_range(-80,80), randf_range(-80,80))
			get_parent().add_child.call_deferred(it)
	
	Globals.add_score(5000)
	
	var tw_death := create_tween()
	tw_death.tween_property(self, "scale", Vector2(0.01, 0.01), 1.0)
	tw_death.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	tw_death.tween_callback(queue_free)
