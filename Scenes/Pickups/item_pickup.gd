extends Area2D

@export var item_type_index: int = 0  # 0=Grenade, 1=Landmine, 2=Ice Bomb, 3=Skill Point Orb, 4=Giantification
@export var amount: int = 1
@export var pickup_lifetime: float = 15.0

const ITEM_COLORS: Array[Color] = [
	Color(0.2, 0.8, 0.2),   # 0=Grenade (green)
	Color(0.8, 0.2, 0.2),   # 1=Landmine (red)
	Color(0.2, 0.8, 1.0),   # 2=Ice Bomb (blue)
	Color(1.0, 0.8, 0.1),   # 3=Skill Point Orb (gold)
	Color(1.0, 0.5, 0.0)    # 4=Giantification (orange)
]

func _ready() -> void:
	add_to_group("pickups")
	get_tree().create_timer(pickup_lifetime).timeout.connect(queue_free)

	var col := ITEM_COLORS[item_type_index]
	if has_node("Sprite2D"):
		$Sprite2D.modulate = col
	if has_node("GlowRect"):
		$GlowRect.color = Color(col.r, col.g, col.b, 0.45)

	# Bobbing animation
	if has_node("Sprite2D"):
		var tw := create_tween().set_loops()
		tw.tween_property($Sprite2D, "position:y", -6.0, 0.6).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property($Sprite2D, "position:y", 6.0, 0.6).set_ease(Tween.EASE_IN_OUT)

	# Spin animation
	var spin := create_tween().set_loops()
	spin.tween_property(self, "rotation", TAU, 3.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("add_item_ammo"):
		body.add_item_ammo(item_type_index, amount)
		_pop_collect()

func _pop_collect() -> void:
	set_deferred("monitoring", false)
	AudioManager.play_pickup()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.1)
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(queue_free)
