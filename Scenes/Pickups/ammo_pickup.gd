extends Area2D

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
@export var weapon_index: int = 1    # 0=Pistol(∞), 1=MG, 2=Silencer
@export var amount: int = 30
@export var pickup_lifetime: float = 12.0

const WEAPON_COLORS: Array[Color] = [
	Color(1.0, 0.9,  0.0, 1.0),  # pistol  — yellow
	Color(1.0, 0.27, 0.0, 1.0),  # MG      — orange-red
	Color(0.0, 1.0,  1.0, 1.0),  # silencer — cyan
]

const WEAPON_SPRITES: Array[String] = [
	"res://Last Stand Assets/Characters/PNG/weapon_gun.png",
	"res://Last Stand Assets/Characters/PNG/weapon_machine.png",
	"res://Last Stand Assets/Characters/PNG/weapon_silencer.png"
]

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("pickups")
	get_tree().create_timer(pickup_lifetime).timeout.connect(queue_free)

	# Apply unique texture and modulate color based on weapon type
	var col := WEAPON_COLORS[weapon_index]
	if has_node("Sprite2D"):
		if weapon_index >= 0 and weapon_index < WEAPON_SPRITES.size():
			$Sprite2D.texture = load(WEAPON_SPRITES[weapon_index])
		$Sprite2D.modulate = col
	if has_node("GlowRect"):
		$GlowRect.color = Color(col.r, col.g, col.b, 0.35)

	# Bob up/down with tween (animating Sprite2D local position to avoid global coordinate tween capture bugs)
	if has_node("Sprite2D"):
		var tw := create_tween().set_loops()
		tw.tween_property($Sprite2D, "position:y", -5.0, 0.7).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property($Sprite2D, "position:y", 5.0, 0.7).set_ease(Tween.EASE_IN_OUT)

	# Spin slowly
	var spin := create_tween().set_loops()
	spin.tween_property(self, "rotation", TAU, 3.0)

const WEAPON_TO_BULLET: Dictionary = {
	0: 0,
	1: 1,
	2: 2
}

# ---------------------------------------------------------------------------
# Collection
# ---------------------------------------------------------------------------
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# If the player already carries this gun type, just give them the bullets!
		if weapon_index in body.carried_weapons:
			var b_idx: int = WEAPON_TO_BULLET.get(weapon_index, 0)
			body.add_bullet_ammo(b_idx, amount)
			_pop_collect()
		else:
			# Open the weapon selection menu!
			var hud = get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("open_weapon_pickup_menu"):
				hud.open_weapon_pickup_menu(weapon_index, amount, self)

func start_cooldown() -> void:
	set_deferred("monitoring", false)
	var t := get_tree().create_timer(1.5)
	t.timeout.connect(func():
		monitoring = true
	)

func _pop_collect() -> void:
	set_deferred("monitoring", false)
	AudioManager.play_pickup()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.0, 2.0), 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(queue_free)
