extends CharacterBody2D

# ---------------------------------------------------------------------------
# Wanderer NPC — open-world travellers that roam maps naturally.
# Types: merchant | scholar | cultist | escapee
# ---------------------------------------------------------------------------

var wanderer_type: String = "merchant"
var is_dead: bool = false
var health: float = 80.0
var max_health: float = 80.0
var move_speed: float = 70.0

var nav_agent: NavigationAgent2D
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var _atmo_timer: float = 0.0
var _interact_cd: float = 0.0
var _has_sold: bool = false          # merchant sold once, moves on
var _lore_id: int = -1               # lore this wanderer carries
var _shop_items: Array[Dictionary] = []

# Visual nodes
var _body: Polygon2D
var _cloak_line: Line2D
var _hat: Polygon2D
var _prompt_lbl: Label
var _health_bar: ProgressBar
var _sprite: Sprite2D

# Scripture lore IDs
const SCRIPTURE_LORE_IDS := [19, 20, 21, 22, 23, 24, 25, 26, 27]

const MERCHANT_STOCK := [
	{"label": "Standard Ammo x50",   "cost": 40,  "action": "ammo", "idx": 0, "qty": 50},
	{"label": "Quick Bullets x15",   "cost": 55,  "action": "ammo", "idx": 1, "qty": 15},
	{"label": "Grenade",             "cost": 80,  "action": "item", "idx": 0, "qty": 1},
	{"label": "Landmine",            "cost": 70,  "action": "item", "idx": 1, "qty": 1},
	{"label": "Ice Bomb",            "cost": 75,  "action": "item", "idx": 2, "qty": 1},
	{"label": "Health Kit",          "cost": 90,  "action": "heal", "idx": 0, "qty": 40},
	{"label": "Skill Point Orb",     "cost": 150, "action": "item", "idx": 3, "qty": 1},
]

const SCHOLAR_LINES := [
	"\"He who studies his enemy studies himself. Anurag Shre wrote six scriptures. I have seen four.\"",
	"\"The exoskeleton was not built in a day. Years of failure. Each prototype a stepping stone.\"",
	"\"They say he grafted monomolecular filaments into his own tendons. Madness... or genius?\"",
	"\"He once said: the difference between a villain and a legend is the chapter the story ends on.\"",
	"\"I traded a scripture page for safe passage through the tunnels. Worth every credit.\"",
]

const CULTIST_LINES := [
	"GLORY TO THE IMMORTAL SCIENTIST!",
	"You cannot kill what has already conquered death!",
	"Anurag Shre will complete the formula — your blood is just one more ingredient!",
	"The Demonic Scriptures will outlive every soul in this world!",
]

const ESCAPEE_LINES := [
	"I was in his lab. Specimen 44. I escaped when the outbreak started. Don't go south.",
	"The whip-sword... I watched it cut through reinforced steel like paper. RUN from him.",
	"He kept notes. Everywhere. Every wall. Six rules he called the path to immortality.",
	"There's a tunnel under the lab. I found scripture pages there. Take this one.",
]

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
func setup(type: String) -> void:
	wanderer_type = type
	_assign_lore()
	_pick_shop_items()
	_update_visuals()

func _assign_lore() -> void:
	match wanderer_type:
		"scholar":
			# Scholars carry a random undiscovered scripture
			var undiscovered := SCRIPTURE_LORE_IDS.filter(func(id): return not Globals.discovered_lore.has(id))
			_lore_id = undiscovered.pick_random() if not undiscovered.is_empty() else SCRIPTURE_LORE_IDS.pick_random()
		"cultist":
			_lore_id = SCRIPTURE_LORE_IDS.pick_random()
		"escapee":
			_lore_id = SCRIPTURE_LORE_IDS.pick_random()
		_:
			_lore_id = -1

func _pick_shop_items() -> void:
	if wanderer_type != "merchant": return
	var pool: Array = MERCHANT_STOCK.duplicate()
	pool.shuffle()
	_shop_items.assign(pool.slice(0, 3))

# ---------------------------------------------------------------------------
# Ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("wanderers")
	add_to_group("npcs")
	collision_layer = 1
	collision_mask = 6

	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 18.0
	nav_agent.target_desired_distance = 18.0
	add_child(nav_agent)

	_build_visuals()
	_pick_wander_target()

	if wanderer_type == "cultist":
		health = 120.0; max_health = 120.0
		modulate = Color(0.6, 0.2, 0.8)
	elif wanderer_type == "merchant":
		modulate = Color(1.0, 0.85, 0.5)
	elif wanderer_type == "scholar":
		modulate = Color(0.5, 0.8, 1.0)
	else:
		modulate = Color(0.8, 0.9, 0.7)

func _build_visuals() -> void:
	# Character Body Collision
	var main_col := CollisionShape2D.new()
	var main_circle := CircleShape2D.new()
	main_circle.radius = 16.0
	main_col.shape = main_circle
	add_child(main_col)

	# Sprite
	_sprite = Sprite2D.new()
	add_child(_sprite)

	# Role badge
	var badge := Label.new()
	badge.text = _get_role_label()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 7)
	badge.add_theme_color_override("font_color", _get_badge_color())
	badge.add_theme_color_override("font_outline_color", Color(0,0,0))
	badge.add_theme_constant_override("outline_size", 3)
	badge.position = Vector2(-40, -48)
	badge.custom_minimum_size = Vector2(80, 12)
	add_child(badge)

	# Interaction prompt
	_prompt_lbl = Label.new()
	_prompt_lbl.text = _get_prompt_text()
	_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_lbl.add_theme_font_size_override("font_size", 8)
	_prompt_lbl.add_theme_color_override("font_color", _get_badge_color())
	_prompt_lbl.add_theme_color_override("font_outline_color", Color(0,0,0))
	_prompt_lbl.add_theme_constant_override("outline_size", 3)
	_prompt_lbl.position = Vector2(-60, -62)
	_prompt_lbl.custom_minimum_size = Vector2(120, 14)
	_prompt_lbl.visible = false
	add_child(_prompt_lbl)

	# Mini health bar (cultists only)
	if wanderer_type == "cultist":
		_health_bar = ProgressBar.new()
		_health_bar.max_value = max_health
		_health_bar.value = health
		_health_bar.show_percentage = false
		_health_bar.custom_minimum_size = Vector2(36, 4)
		_health_bar.position = Vector2(-18, -30)
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.1,0.1,0.1,0.8)
		var sf := StyleBoxFlat.new(); sf.bg_color = Color(0.6, 0.1, 0.8)
		_health_bar.add_theme_stylebox_override("background", sb)
		_health_bar.add_theme_stylebox_override("fill", sf)
		add_child(_health_bar)

	# Proximity Area
	var area := Area2D.new()
	var col := CollisionShape2D.new()
	var circ := CircleShape2D.new(); circ.radius = 75.0
	col.shape = circ; area.add_child(col); add_child(area)

	area.body_entered.connect(func(body):
		if body.is_in_group("player") and not is_dead:
			_prompt_lbl.visible = true
			body.set_meta("active_crypt", self)
			# Register interact callable so player's [E] handler works
			set_meta("interact_method", func(): interact(body))
			if wanderer_type == "cultist":
				_become_hostile(body)
	)
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			_prompt_lbl.visible = false
			if body.has_meta("active_crypt") and body.get_meta("active_crypt") == self:
				body.remove_meta("active_crypt")
	)

func _get_body_color() -> Color:
	match wanderer_type:
		"merchant": return Color(0.35, 0.25, 0.12)
		"scholar":  return Color(0.20, 0.30, 0.40)
		"cultist":  return Color(0.25, 0.08, 0.30)
		_:          return Color(0.30, 0.35, 0.28)

func _get_cloak_color() -> Color:
	match wanderer_type:
		"merchant": return Color(0.55, 0.35, 0.12, 0.8)
		"scholar":  return Color(0.20, 0.50, 0.70, 0.8)
		"cultist":  return Color(0.45, 0.05, 0.55, 0.8)
		_:          return Color(0.40, 0.45, 0.35, 0.8)

func _get_hat_color() -> Color:
	match wanderer_type:
		"merchant": return Color(0.50, 0.30, 0.10)
		"scholar":  return Color(0.15, 0.25, 0.38)
		"cultist":  return Color(0.30, 0.04, 0.38)
		_:          return Color(0.28, 0.32, 0.22)

func _get_role_label() -> String:
	match wanderer_type:
		"merchant": return "[ MERCHANT ]"
		"scholar":  return "[ SCHOLAR ]"
		"cultist":  return "[ CULTIST ]"
		_:          return "[ DRIFTER ]"

func _get_badge_color() -> Color:
	match wanderer_type:
		"merchant": return Color(1.0, 0.85, 0.3)
		"scholar":  return Color(0.4, 0.85, 1.0)
		"cultist":  return Color(0.8, 0.2, 1.0)
		_:          return Color(0.6, 0.9, 0.5)

func _get_prompt_text() -> String:
	match wanderer_type:
		"merchant": return "[E] Trade"
		"scholar":  return "[E] Learn"
		"cultist":  return "[E] (HOSTILE)"
		_:          return "[E] Listen"

func _update_visuals() -> void:
	if _body: _body.color = _get_body_color()
	if _cloak_line: _cloak_line.default_color = _get_cloak_color()
	if _hat: _hat.color = _get_hat_color()
	
	if _sprite:
		var path := ""
		match wanderer_type:
			"merchant": path = "res://Last Stand Assets/Characters/PNG/Man Brown/manBrown_stand.png"
			"scholar":  path = "res://Last Stand Assets/Characters/PNG/Man Old/manOld_stand.png"
			"cultist":  path = "res://Last Stand Assets/Characters/PNG/Hitman 1/hitman1_stand.png"
			_:          path = "res://Last Stand Assets/Characters/PNG/Survivor 1/survivor1_stand.png"
		_sprite.texture = load(path)

# ---------------------------------------------------------------------------
# Process — wandering
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if is_dead: return
	_atmo_timer += delta
	_interact_cd -= delta
	wander_timer -= delta

	# Gentle bob animation
	if _cloak_line:
		_cloak_line.scale.y = 1.0 + sin(_atmo_timer * 2.5) * 0.06
	elif _sprite:
		_sprite.scale = Vector2.ONE * (1.0 + sin(_atmo_timer * 2.5) * 0.04)

	# Pick new wander destination
	if wander_timer <= 0.0 or nav_agent.is_navigation_finished():
		_pick_wander_target()

	# Move
	var next := nav_agent.get_next_path_position()
	if next.distance_to(global_position) > 5.0:
		velocity = global_position.direction_to(next) * move_speed
		look_at(next)
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func _pick_wander_target() -> void:
	wander_timer = randf_range(6.0, 14.0)
	wander_target = global_position + Vector2(
		randf_range(-400, 400),
		randf_range(-400, 400)
	)
	nav_agent.target_position = wander_target

# ---------------------------------------------------------------------------
# Interaction (called by player pressing E)
# ---------------------------------------------------------------------------
func interact(player: Node) -> void:
	if is_dead or _interact_cd > 0.0: return
	_interact_cd = 2.0

	match wanderer_type:
		"merchant": _do_trade(player)
		"scholar":  _do_lore(player)
		"cultist":  _become_hostile(player)
		"escapee":  _do_escapee(player)

func _do_trade(player: Node) -> void:
	if _has_sold:
		DialogManager.show_dialog([{"speaker": "Merchant", "text": "I've sold you what I can spare. I must move on. Survive out there.", "color": Color(1.0, 0.85, 0.3)}])
		return

	if _shop_items.is_empty():
		DialogManager.show_dialog([{"speaker": "Merchant", "text": "Nothing left in my pack. Try the next wanderer.", "color": Color(1.0, 0.85, 0.3)}])
		return

	# Show shop — up to 3 items, buy the first affordable one
	var dialog_lines := [{"speaker": "Merchant", "text": "What do you need, traveller? I deal in necessities.", "color": Color(1.0, 0.85, 0.3)}]
	var stock_text := ""
	for item in _shop_items:
		stock_text += "  %s — %d EXP\n" % [item["label"], item["cost"]]
	dialog_lines.append({"speaker": "Merchant", "text": "Stock:\n%s\n[Will sell cheapest you can afford]" % stock_text, "color": Color(1.0, 0.9, 0.5)})

	# Find best affordable item
	var bought := false
	for item in _shop_items:
		if Globals.score >= item["cost"]:
			Globals.score -= item["cost"]
			_apply_purchase(player, item)
			dialog_lines.append({"speaker": "Merchant", "text": "Sold! Take it. May it serve you better than it served me.", "color": Color(0.4, 1.0, 0.4)})
			bought = true
			_has_sold = true
			break

	if not bought:
		dialog_lines.append({"speaker": "Merchant", "text": "You can't afford anything. Kill more and come back.", "color": Color(0.9, 0.4, 0.3)})

	DialogManager.show_dialog(dialog_lines)

	if _has_sold:
		# Wander away after selling
		get_tree().create_timer(8.0).timeout.connect(func():
			if is_instance_valid(self) and not is_dead:
				_begin_departure()
		)

func _apply_purchase(player: Node, item: Dictionary) -> void:
	match item["action"]:
		"ammo":
			if player.get("bullet_ammo") != null:
				player.bullet_ammo[item["idx"]] += item["qty"]
		"item":
			if player.has_method("add_item_ammo"):
				player.add_item_ammo(item["idx"], item["qty"])
		"heal":
			if player.get("health") != null:
				player.health = min(player.health + item["qty"], player.max_health)
				if player.has_method("_update_health_bar"):
					player._update_health_bar()

func _do_lore(_player: Node) -> void:
	var line: String = SCHOLAR_LINES.pick_random() as String
	var dialog := [
		{"speaker": "Wandering Scholar", "text": line, "color": Color(0.4, 0.85, 1.0)}
	]

	# Grant lore if player doesn't have it yet
	if _lore_id >= 0 and not Globals.discovered_lore.has(_lore_id):
		Globals.discover_lore(_lore_id)
		var frag := Globals.LORE_FRAGMENTS[_lore_id]
		dialog.append({"speaker": "System", "text": "Lore Discovered: \"%s\"" % frag["title"], "color": Color(0.1, 0.9, 0.2)})
		dialog.append_array(frag["dialogue"])
		_lore_id = -1  # Already given

	DialogManager.show_dialog(dialog)

func _do_escapee(player: Node) -> void:
	var line: String = ESCAPEE_LINES.pick_random() as String
	var dialog := [
		{"speaker": "Lab Escapee", "text": line, "color": Color(0.6, 0.9, 0.5)},
		{"speaker": "Lab Escapee", "text": "Take this — I found it in one of his storage crates.", "color": Color(0.6, 0.9, 0.5)}
	]

	# Escapee always gives a lore page + small ammo gift
	if _lore_id >= 0 and not Globals.discovered_lore.has(_lore_id):
		Globals.discover_lore(_lore_id)
		var frag := Globals.LORE_FRAGMENTS[_lore_id]
		dialog.append({"speaker": "System", "text": "Lore Discovered: \"%s\"" % frag["title"], "color": Color(0.1, 0.9, 0.2)})
		dialog.append_array(frag["dialogue"])
	
	if player.get("bullet_ammo") != null:
		player.bullet_ammo[0] = min(player.bullet_ammo[0] + 30, 999)

	DialogManager.show_dialog(dialog)

	# Escapee flees after interaction
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(self) and not is_dead:
			_begin_departure()
	)

# ---------------------------------------------------------------------------
# Cultist hostile behaviour
# ---------------------------------------------------------------------------
func _become_hostile(player: Node) -> void:
	if is_dead: return
	modulate = Color(0.9, 0.2, 1.0)
	_prompt_lbl.visible = false
	move_speed = 110.0

	DialogManager.show_dialog([
		{"speaker": "Anurag Cultist", "text": CULTIST_LINES.pick_random(), "color": Color(0.8, 0.2, 1.0)}
	])

	# Simple chase & melee
	set_process(false)
	_chase_loop(player)

func _chase_loop(player: Node) -> void:
	while not is_dead and is_instance_valid(player) and not player.get("is_dead"):
		await get_tree().create_timer(0.15).timeout
		if not is_instance_valid(self) or is_dead: return
		
		nav_agent.target_position = player.global_position
		var next := nav_agent.get_next_path_position()
		velocity = global_position.direction_to(next) * move_speed
		look_at(player.global_position)
		move_and_slide()

		var dist := global_position.distance_to(player.global_position)
		if dist < 38.0:
			if player.has_method("take_damage"):
				player.take_damage(14.0)
			await get_tree().create_timer(0.8).timeout

# ---------------------------------------------------------------------------
# Departure (graceful exit)
# ---------------------------------------------------------------------------
func _begin_departure() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 2.0)
	tw.tween_callback(queue_free)

# ---------------------------------------------------------------------------
# Damage & Death
# ---------------------------------------------------------------------------
func take_damage(amount: float) -> void:
	if is_dead: return
	health -= amount
	if _health_bar: _health_bar.value = health

	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 0.3, 0.3), 0.05)
	tw.tween_property(self, "modulate", Color(0.9, 0.2, 1.0), 0.15)

	if health <= 0.0: _die()

func _die() -> void:
	if is_dead: return
	is_dead = true
	_prompt_lbl.visible = false

	# EXP reward
	Globals.add_score(65)

	# Cultist drops a scripture lore fragment
	if wanderer_type == "cultist" and _lore_id >= 0:
		var lore_pickup_scene = load("res://Scenes/Objects/lore_pickup.tscn")
		if lore_pickup_scene and not Globals.discovered_lore.has(_lore_id):
			var lp: Node2D = lore_pickup_scene.instantiate() as Node2D
			lp.lore_id = _lore_id
			lp.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			get_parent().add_child.call_deferred(lp)

	# Drop small ammo
	var bullet_pickup_scene = load("res://Scenes/Pickups/bullet_pickup.tscn")
	if bullet_pickup_scene:
		var bp: Node2D = bullet_pickup_scene.instantiate() as Node2D
		bp.bullet_type_index = 0
		bp.amount = randi_range(15, 30)
		bp.global_position = global_position
		get_parent().add_child.call_deferred(bp)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
