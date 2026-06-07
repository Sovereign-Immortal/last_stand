extends Control

@onready var splash_image: TextureRect = $SplashImage
@onready var background: ColorRect = $Background

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	background.color = Color(0.005, 0.005, 0.01, 1.0)
	splash_image.modulate = Color(0.45, 0.42, 0.42, 0.0)
	
	# Add a subtle vignette overlay
	var vignette_style := StyleBoxFlat.new()
	vignette_style.bg_color = Color(0, 0, 0, 0)
	vignette_style.border_width_left = 80
	vignette_style.border_width_top = 80
	vignette_style.border_width_right = 80
	vignette_style.border_width_bottom = 80
	vignette_style.border_color = Color(0.01, 0.01, 0.02, 0.85)
	vignette_style.border_blend = true
	
	var vignette_panel := Panel.new()
	vignette_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_panel.add_theme_stylebox_override("panel", vignette_style)
	add_child(vignette_panel)
	move_child(vignette_panel, 1) # Place between background and splash image
	
	# Add rising red embers floating over the screen
	var embers := CPUParticles2D.new()
	embers.position = Vector2(320, 370)
	embers.amount = 35
	embers.lifetime = 6.0
	embers.preprocess = 5.0
	embers.speed_scale = 0.75
	embers.randomness = 1.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(320, 10)
	embers.direction = Vector2(0.2, -1.0)
	embers.spread = 30.0
	embers.gravity = Vector2(0, -6.0)
	embers.initial_velocity_min = 30.0
	embers.initial_velocity_max = 70.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 5.0
	
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([
		Color(1.0, 0.38, 0.1, 0.95),
		Color(0.85, 0.15, 0.02, 0.7),
		Color(0.25, 0.25, 0.25, 0.0)
	])
	embers.color_ramp = ramp
	
	add_child(embers) # Rendered on top of the splash image
	
	# Start-up delay
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self): return
	
	# Creepy scientific reanimation audiocue
	AudioManager.play_zombie_groan()
	
	# Smooth fade-in to a darkened, thematic color state
	var tw_fade := create_tween()
	tw_fade.tween_property(splash_image, "modulate", Color(0.45, 0.42, 0.42, 1.0), 1.5).set_ease(Tween.EASE_OUT)
	
	# Creepy breathing/zoom effect
	var tw_scale := create_tween()
	tw_scale.tween_property(splash_image, "scale", Vector2(0.55, 0.55), 3.5).set_ease(Tween.EASE_OUT)
	
	# Dwell duration
	await get_tree().create_timer(3.5).timeout
	if not is_instance_valid(self): return
	
	# Fade-out to menu
	var tw_out := create_tween()
	tw_out.tween_property(splash_image, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	await tw_out.finished
	
	if is_instance_valid(self):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://Scenes/menue.tscn")
