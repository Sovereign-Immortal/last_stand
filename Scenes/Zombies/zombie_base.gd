extends CharacterBody2D

# ------------------------------------------------------------------
# 1. Zombie properties – override these in inherited scenes for variety
# ------------------------------------------------------------------
@export var strength : float = 10.0          # Higher -> more likely to be leader
@export var zombie_type : String = "basic"   # Only zombies of same type flock together
@export var move_speed : float = 150.0
@export var sight_range : float = 200.0      # How far the zombie “sees”
@export var formation_radius : float = 80.0  # How far followers stay from leader

# ------------------------------------------------------------------
# 2. Horde / leader data
# ------------------------------------------------------------------
var leader : CharacterBody2D = null          # Reference to the leader (self if leader)
var followers : Array = []                   # Only used if this zombie is the leader
var formation_offset : Vector2 = Vector2.ZERO # Offset from leader (computed)
var current_pattern : int = 0                # 0=scout, 1=chase, 2=encircle, 3=random

# ------------------------------------------------------------------
# 3. Target (player) tracking
# ------------------------------------------------------------------
var player_target : Node2D = null            # Set when player enters sight

# ------------------------------------------------------------------
# 4. Simple movement variables
# ------------------------------------------------------------------
var wander_target : Vector2                  # Random point for scout/random
var wander_timer : float = 0.0

# Predefined patterns (just for readability)
enum Pattern { SCOUT = 0, CHASE = 1, ENCIRCLE = 2, RANDOM = 3 }

# ------------------------------------------------------------------
# _ready – set up detection area, start leader election timer
# ------------------------------------------------------------------
func _ready():
	# Add self to a global group so all zombies can find each other
	add_to_group("zombies")
	
	# Set detection area size according to sight_range
	$DetectionArea/CollisionShape2D.shape.radius = sight_range
	
	# Leader election timer – every 0.5 seconds is enough
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_elect_horde_leader)
	add_child(timer)

# ------------------------------------------------------------------
# _process – run behaviour every frame
# ------------------------------------------------------------------
func _process(delta):
	look_at($"../../Player".global_position)
	if leader == self:
		# I am the leader → run leader behaviour
		_update_leader(delta)
	else:
		# I am a follower → follow leader and copy its pattern
		_update_follower(delta)
	
	# Apply movement (velocity is set by the behaviours)
	move_and_slide()

# ------------------------------------------------------------------
# 5. Leader election (called by timer)
# ------------------------------------------------------------------
func _elect_horde_leader():
	# Find all zombies of the same type inside the detection area
	var nearby = []
	for body in $DetectionArea.get_overlapping_bodies():
		if body.is_in_group("zombies") and body != self and body.zombie_type == zombie_type:
			nearby.append(body)
	
	# If nobody else is here, I’m automatically a lone leader
	if nearby.is_empty():
		_become_leader()
		return
	
	# Find the zombie with the highest strength
	var strongest = self
	for z in nearby:
		if z.strength > strongest.strength:
			strongest = z
	
	if strongest == self:
		_become_leader()
	else:
		# A stronger zombie exists → follow it
		_follow_leader(strongest)

func _become_leader():
	if leader == self:
		return   # already leader
	# Remove myself from old leader’s followers (if any)
	if leader != null and leader != self:
		leader.remove_follower(self)
	leader = self
	followers.clear()   # old followers will re-register next election

func _follow_leader(new_leader):
	if leader == new_leader:
		return
	# Unregister from old leader
	if leader != null and leader != self:
		leader.remove_follower(self)
	leader = new_leader
	# Register with the new leader (and get a formation offset)
	leader.add_follower(self)

# ------------------------------------------------------------------
# 6. Leader helpers (managing followers)
# ------------------------------------------------------------------
func add_follower(follower):
	if follower not in followers:
		followers.append(follower)
		# Assign a formation offset: distribute followers evenly on a circle
		_calculate_formation_offsets()

func remove_follower(follower):
	followers.erase(follower)
	_calculate_formation_offsets()

func _calculate_formation_offsets():
	# Simple circular formation around the leader
	var count = followers.size()
	var angle_step = TAU / max(count, 1)
	for i in range(count):
		var angle = i * angle_step
		followers[i].formation_offset = Vector2.RIGHT.rotated(angle) * formation_radius

# ------------------------------------------------------------------
# 7. Leader behaviour – decides pattern and moves
# ------------------------------------------------------------------
func _update_leader(delta):
	# Determine pattern based on whether a player is seen
	if player_target:
		# Chase or encircle depending on distance (switch at 150 pixels)
		if global_position.distance_to(player_target.global_position) < 150:
			current_pattern = Pattern.ENCIRCLE
		else:
			current_pattern = Pattern.CHASE
	else:
		# No target → wander or scout
		# Alternate every few seconds to give variety
		wander_timer -= delta
		if wander_timer <= 0:
			# 50% scout (go to random far point), 50% random (small wander)
			if randi() % 2 == 0:
				current_pattern = Pattern.SCOUT
			else:
				current_pattern = Pattern.RANDOM
			wander_timer = 2.0   # change every 2 seconds
	
	# Execute the chosen pattern
	match current_pattern:
		Pattern.CHASE:
			_chase(delta)
		Pattern.ENCIRCLE:
			_encircle_leader(delta)
		Pattern.SCOUT:
			_scout(delta)
		Pattern.RANDOM:
			_random_wander(delta)

func _chase(_delta):
	if player_target:
		var dir = global_position.direction_to(player_target.global_position)
		velocity = dir * move_speed
	else:
		velocity = Vector2.ZERO

func _encircle_leader(_delta):
	# Leader orbits the player slowly, followers will handle their own offsets
	if player_target:
		var dir_to_player = global_position.direction_to(player_target.global_position)
		# Stay at a comfortable distance (120 px) – move sideways around target
		var desired_dist = 120.0
		var offset = global_position - player_target.global_position
		if offset.length() > 0:
			var radial = offset.normalized() * desired_dist
			var tangential = radial.rotated(PI/2) * 0.5   # orbit
			var desired_pos = player_target.global_position + radial + tangential
			var move_dir = global_position.direction_to(desired_pos)
			velocity = move_dir * move_speed
		else:
			velocity = Vector2.ZERO

func _scout(_delta):
	# Move towards a fixed far away point (scout)
	if wander_target == Vector2.ZERO:
		wander_target = _random_far_point()
	var dir = global_position.direction_to(wander_target)
	velocity = dir * move_speed
	if global_position.distance_to(wander_target) < 10:
		wander_target = _random_far_point()   # pick a new target

func _random_wander(_delta):
	# Small random movement
	if wander_target == Vector2.ZERO:
		wander_target = global_position + Vector2(randf_range(-100,100), randf_range(-100,100))
	var dir = global_position.direction_to(wander_target)
	velocity = dir * move_speed * 0.5   # slow wander
	if global_position.distance_to(wander_target) < 10:
		wander_target = Vector2.ZERO

func _random_far_point():
	# Scout targets are 300–500 pixels away
	var angle = randf_range(0, TAU)
	var dist = randf_range(300, 500)
	return global_position + Vector2.RIGHT.rotated(angle) * dist

# ------------------------------------------------------------------
# 8. Follower behaviour – copy leader’s pattern
# ------------------------------------------------------------------
func _update_follower(delta):
	if leader == null or leader == self:
		return
	
	# Followers simply use the leader’s current pattern
	match leader.current_pattern:
		Pattern.CHASE:
			_follower_chase(delta)
		Pattern.ENCIRCLE:
			_follower_encircle(delta)
		Pattern.SCOUT, Pattern.RANDOM:
			_follower_scout_random(delta)

func _follower_chase(_delta):
	# Chase the same target as the leader, using our own formation offset relative to leader
	if leader.player_target:
		# Move towards player, but keep formation offset from leader
		var desired_pos = leader.player_target.global_position + formation_offset
		var dir = global_position.direction_to(desired_pos)
		velocity = dir * move_speed
	else:
		_follow_leader_position()

func _follower_encircle(_delta):
	# Encircle the player: form a ring around the player using the formation offset
	if leader.player_target:
		var target_pos = leader.player_target.global_position + formation_offset
		var dir = global_position.direction_to(target_pos)
		velocity = dir * move_speed
	else:
		_follow_leader_position()

func _follower_scout_random(_delta):
	# Simply stay in formation behind the leader
	_follow_leader_position()

func _follow_leader_position():
	# Move towards (leader.position + formation_offset)
	var target = leader.global_position + formation_offset
	var dir = global_position.direction_to(target)
	if global_position.distance_to(target) > 10:
		velocity = dir * move_speed
	else:
		velocity = Vector2.ZERO

# ------------------------------------------------------------------
# 9. Player detection (signals connected from DetectionArea)
# ------------------------------------------------------------------
func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player_target = body

func _on_detection_area_body_exited(body):
	if body == player_target:
		player_target = null
