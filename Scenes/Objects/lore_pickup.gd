extends Area2D

@export var lore_id: int = 0
@export var lore_title: String = "Lore Note"
@export var dialogue_lines: Array = []

var _pulse_time: float = 0.0

func _ready() -> void:
	# If already discovered, don't spawn it in the world
	if Globals.discovered_lore.has(lore_id):
		queue_free()
		return
		
	# Automatically retrieve dialog and title from Globals repository based on lore_id
	if lore_id >= 0 and lore_id < Globals.LORE_FRAGMENTS.size():
		var frag = Globals.LORE_FRAGMENTS[lore_id]
		lore_title = frag["title"]
		dialogue_lines = frag["dialogue"]
	
	# Set collision layer/mask to detect the Player (layer 1/mask 1)
	collision_layer = 0
	collision_mask = 1 # Player is on layer 1
	
	# Connect collision signals
	body_entered.connect(_on_body_entered)
	
	# Create a CollisionShape2D programmatically
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 40.0
	shape_node.shape = circle
	add_child(shape_node)

func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()

func _draw() -> void:
	# Glassmorphic pulse glow effect
	var pulse := sin(_pulse_time * 4.0) * 3.0 + 10.0
	
	# Outer cyan aura
	draw_circle(Vector2.ZERO, pulse + 8.0, Color(0.0, 0.8, 1.0, 0.12))
	draw_circle(Vector2.ZERO, pulse + 3.0, Color(0.0, 0.8, 1.0, 0.22))
	
	# Glowing center dot
	draw_circle(Vector2.ZERO, 3.0, Color(0.1, 0.9, 1.0, 1.0))
	
	# Glass card container for the note
	var rect_size := Vector2(16, 20)
	var rect_pos := -rect_size * 0.5
	draw_rect(Rect2(rect_pos, rect_size), Color(0.05, 0.12, 0.2, 0.8), true)
	draw_rect(Rect2(rect_pos, rect_size), Color(0.0, 0.8, 1.0, 0.7), false, 1.0)
	
	# Draw decorative horizontal lines representing writing on paper
	draw_line(Vector2(-5, -4), Vector2(5, -4), Color(1, 1, 1, 0.7), 1.0)
	draw_line(Vector2(-5, 0), Vector2(3, 0), Color(1, 1, 1, 0.7), 1.0)
	draw_line(Vector2(-5, 4), Vector2(1, 4), Color(1, 1, 1, 0.7), 1.0)

func _on_body_entered(body: Node2D) -> void:
	# Trigger dialogue when player runs near it
	if body.name == "Player":
		Globals.discover_lore(lore_id)
		DialogManager.show_dialog(dialogue_lines)
		AudioManager.play_pickup()
		queue_free()
