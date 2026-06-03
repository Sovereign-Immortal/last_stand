extends Control

@export var dot_radius: float = 1.0
@export var line_length: float = 5.0
@export var line_width: float = 1.0
@export var base_spread: float = 4.0

var current_spread: float = 4.0
var target_spread: float = 4.0
var crosshair_color: Color = Color(1.0, 0.9, 0.0, 0.9)  # matches standard bullet yellow

var _rotation_angle: float = 0.0
var _click_effects: Array[Dictionary] = []

func _ready() -> void:
	z_index = 100
	mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _exit_tree() -> void:
	# Restore cursor when leaving the game scene
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_spawn_click_effect()

func _spawn_click_effect() -> void:
	var fx: Dictionary = {
		"radius": 2.0,
		"max_radius": 16.0,
		"alpha": 1.0,
		"speed": 55.0
	}
	_click_effects.append(fx)

func _process(delta: float) -> void:
	# Check if game is paused or UI is active
	if get_tree().paused:
		visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	else:
		visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Follow mouse position exactly
	global_position = get_viewport().get_mouse_position()

	# Lerp spread back to base
	current_spread = lerp(current_spread, target_spread, 12.0 * delta)
	target_spread = lerp(target_spread, base_spread, 8.0 * delta)

	# Slowly rotate outer tick marks
	_rotation_angle += 0.4 * delta

	# Process click effects
	var kept_effects: Array[Dictionary] = []
	for effect: Dictionary in _click_effects:
		effect["radius"] += effect["speed"] * delta
		effect["alpha"] = 1.0 - (effect["radius"] / effect["max_radius"])
		if effect["alpha"] > 0.0:
			kept_effects.append(effect)
	_click_effects = kept_effects

	queue_redraw()

func kick_spread(amount: float) -> void:
	target_spread = clamp(target_spread + amount, base_spread, base_spread * 3.5)

func set_crosshair_color(col: Color) -> void:
	crosshair_color = Color(col.r, col.g, col.b, 0.9)

func _draw() -> void:
	var center := Vector2.ZERO
	# Draw black drop shadow outline for contrast (draw outlines of click effects first)
	for effect: Dictionary in _click_effects:
		var shadow_col := Color(0.0, 0.0, 0.0, effect["alpha"] * 0.45)
		draw_arc(center, effect["radius"], 0, TAU, 32, shadow_col, 2.0)
	
	_draw_shape(center, Color(0.0, 0.0, 0.0, 0.65), current_spread, line_width + 1.5, line_length + 2.0, dot_radius + 1.0)
	
	# Draw active click effect shockwaves
	for effect: Dictionary in _click_effects:
		var fx_col := Color(crosshair_color.r, crosshair_color.g, crosshair_color.b, effect["alpha"] * 0.75)
		draw_arc(center, effect["radius"], 0, TAU, 32, fx_col, 1.0)

	# Draw main crosshair shape
	_draw_shape(center, crosshair_color, current_spread, line_width, line_length, dot_radius)

func _draw_shape(center: Vector2, col: Color, spread: float, width: float, length: float, dot: float) -> void:
	# Center dot
	draw_circle(center, dot, col)
	
	# Enclosing circle (semi-transparent)
	var circle_radius := spread + length + 2.0
	var circle_col := Color(col.r, col.g, col.b, col.a * 0.4)
	draw_arc(center, circle_radius, 0, TAU, 32, circle_col, width)
	
	# Draw 4 tick marks rotated
	var directions: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for dir in directions:
		var r_dir: Vector2 = dir.rotated(_rotation_angle)
		var start: Vector2 = center + r_dir * spread
		var end: Vector2 = center + r_dir * (spread + length)
		draw_line(start, end, col, width)

