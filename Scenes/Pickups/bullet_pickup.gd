extends Area2D

@export var bullet_type_index: int = 1  # 1=Quick, 2=Paralysis, 3=Knockback, 4=Slow Down
@export var amount: int = 15
@export var pickup_lifetime: float = 12.0

const BULLET_COLORS: Array[Color] = [
	Color(1.0, 0.9, 0.0),   # 0=Standard (yellow)
	Color(0.1, 0.6, 1.0),   # 1=Quick (blue)
	Color(0.7, 0.1, 1.0),   # 2=Paralysis (purple)
	Color(0.1, 0.9, 0.1),   # 3=Knockback (green)
	Color(0.3, 0.9, 1.0)    # 4=Slow Down (cyan)
]

func _ready() -> void:
	add_to_group("pickups")
	get_tree().create_timer(pickup_lifetime).timeout.connect(queue_free)

	var col := BULLET_COLORS[bullet_type_index]
	if has_node("Sprite2D"):
		$Sprite2D.modulate = col
	if has_node("GlowRect"):
		$GlowRect.color = Color(col.r, col.g, col.b, 0.4)

	# Bobbing animation (animating Sprite2D local position to avoid global coordinate tween capture bugs)
	if has_node("Sprite2D"):
		var tw := create_tween().set_loops()
		tw.tween_property($Sprite2D, "position:y", -6.0, 0.6).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property($Sprite2D, "position:y", 6.0, 0.6).set_ease(Tween.EASE_IN_OUT)

	# Spin animation
	var spin := create_tween().set_loops()
	spin.tween_property(self, "rotation", TAU, 4.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("add_bullet_ammo"):
		body.add_bullet_ammo(bullet_type_index, amount)
		_pop_collect()

func _pop_collect() -> void:
	set_deferred("monitoring", false)
	AudioManager.play_pickup()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(queue_free)
