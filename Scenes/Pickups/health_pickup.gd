extends Area2D

@export var heal_amount: int = 25
@export var pickup_lifetime: float = 15.0

func _ready() -> void:
	add_to_group("pickups")
	get_tree().create_timer(pickup_lifetime).timeout.connect(queue_free)

	# Bobbing animation
	if has_node("Sprite2D"):
		var tw := create_tween().set_loops()
		tw.tween_property($Sprite2D, "position:y", -6.0, 0.6).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property($Sprite2D, "position:y", 6.0, 0.6).set_ease(Tween.EASE_IN_OUT)

	# Spin animation
	var spin := create_tween().set_loops()
	spin.tween_property(self, "rotation", TAU, 4.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("heal"):
		body.heal(heal_amount)
		
		# Show announcement on HUD in bright green
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_pickup_announcement"):
			hud.show_pickup_announcement("Health Orb", heal_amount, Color(0.2, 1.0, 0.4))
			
		_pop_collect()

func _pop_collect() -> void:
	set_deferred("monitoring", false)
	# Play heal sound or pickup sound
	AudioManager.play_pickup()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(queue_free)
