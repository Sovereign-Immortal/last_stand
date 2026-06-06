extends Control

@onready var splash_image: TextureRect = $SplashImage
@onready var background: ColorRect = $Background

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	background.color = Color(0.01, 0.01, 0.02, 1.0)
	splash_image.modulate.a = 0.0
	
	# Start-up delay
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self): return
	
	# Creepy scientific reanimation audiocue
	AudioManager.play_zombie_groan()
	
	# Smooth fade-in
	var tw_fade := create_tween()
	tw_fade.tween_property(splash_image, "modulate:a", 1.0, 1.5).set_ease(Tween.EASE_OUT)
	
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
