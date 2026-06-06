extends Control

@export var icon_type: String = "weapon" # "weapon", "bullet", "item"
@export var icon_name: String = ""
@export var icon_color: Color = Color(1, 1, 1)

func _ready() -> void:
	custom_minimum_size = Vector2(32, 20)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func set_icon(type: String, item_name: String, color: Color = Color(1, 1, 1)) -> void:
	icon_type = type
	icon_name = item_name.to_lower()
	icon_color = color
	queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	
	# Draw background glow/shadow or subtle card backing
	draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.15, 0.2, 0.3), true)
	
	match icon_type:
		"weapon":
			_draw_weapon(w, h)
		"bullet":
			_draw_bullet(w, h)
		"item":
			_draw_item(w, h)

func _draw_weapon(w: float, h: float) -> void:
	var color = Color(0.7, 0.85, 1.0) # Sleek blue-grey for weapons
	
	# Center position helper
	var cx = w / 2.0
	var cy = h / 2.0
	
	if "pistol" in icon_name:
		# Draw a simple pistol
		# Barrel/Slide
		draw_rect(Rect2(cx - 10, cy - 6, 16, 5), color, true)
		# Grip
		draw_rect(Rect2(cx + 2, cy - 2, 5, 8), color, true)
		# Trigger area (dot or small rectangle)
		draw_rect(Rect2(cx - 2, cy - 1, 3, 3), color, false, 1.0)
	elif "machine" in icon_name or "mg" in icon_name:
		# Draw an assault rifle/machine gun
		# Barrel
		draw_rect(Rect2(cx - 14, cy - 4, 24, 4), color, true)
		# Stock
		draw_rect(Rect2(cx + 6, cy - 4, 6, 6), color, true)
		# Grip
		draw_rect(Rect2(cx + 2, cy, 3, 6), color, true)
		# Magazine (curved/angled)
		draw_rect(Rect2(cx - 4, cy, 4, 8), color, true)
	elif "silencer" in icon_name:
		# Draw a pistol with a silencer barrel extension
		# Slide/Barrel
		draw_rect(Rect2(cx - 6, cy - 6, 12, 5), color, true)
		# Silencer attachment
		draw_rect(Rect2(cx - 14, cy - 5, 8, 3), color * 0.8, true)
		# Grip
		draw_rect(Rect2(cx + 2, cy - 2, 5, 8), color, true)
		# Trigger
		draw_rect(Rect2(cx - 2, cy - 1, 3, 3), color, false, 1.0)
	else:
		# Fallback/generic gun silhouette
		draw_rect(Rect2(cx - 10, cy - 4, 20, 8), color, true)

func _draw_bullet(w: float, h: float) -> void:
	# Center position
	var cx = w / 2.0
	var cy = h / 2.0
	
	# Draw bullet body (casing + projectile)
	# Casing (rectangle)
	draw_rect(Rect2(cx - 4, cy - 3, 6, 6), icon_color * 0.8, true)
	
	# Projectile tip (triangle points left)
	var points = PackedVector2Array([
		Vector2(cx - 4, cy - 3),
		Vector2(cx - 8, cy),
		Vector2(cx - 4, cy + 3)
	])
	draw_polygon(points, [icon_color])
	
	# Base rim
	draw_rect(Rect2(cx + 2, cy - 3.5, 1.5, 7), Color(0.9, 0.7, 0.2), true)

func _draw_item(w: float, h: float) -> void:
	var cx = w / 2.0
	var cy = h / 2.0
	
	if "grenade" in icon_name:
		# Draw grenade body
		draw_circle(Vector2(cx, cy + 1), 6, icon_color)
		# Pin/Cap on top
		draw_rect(Rect2(cx - 2, cy - 7, 4, 3), icon_color * 1.2, true)
		# Lever
		draw_line(Vector2(cx + 1, cy - 6), Vector2(cx + 5, cy - 2), icon_color * 1.2, 1.5)
	elif "landmine" in icon_name:
		# Draw landmine flat body
		draw_rect(Rect2(cx - 10, cy + 2, 20, 4), icon_color, true)
		draw_rect(Rect2(cx - 7, cy - 1, 14, 3), icon_color * 1.2, true)
		# Red indicator light blinking/glowing
		var light_color = Color(1.0, 0.2, 0.2)
		draw_circle(Vector2(cx, cy - 1), 1.5, light_color)
	elif "ice" in icon_name or "freeze" in icon_name:
		# Draw a round cryo bomb with ice spikes
		draw_circle(Vector2(cx, cy), 5, icon_color)
		# Spikes (ice burst pattern)
		for i in range(8):
			var angle = i * PI / 4.0
			var start = Vector2(cx, cy) + Vector2(cos(angle), sin(angle)) * 5
			var end = Vector2(cx, cy) + Vector2(cos(angle), sin(angle)) * 8
			draw_line(start, end, Color(0.6, 0.9, 1.0), 1.5)
	elif "skill" in icon_name:
		# Draw glowing gold circle
		draw_circle(Vector2(cx, cy), 6, icon_color)
		# Draw a small plus (+) in the center
		draw_line(Vector2(cx - 3, cy), Vector2(cx + 3, cy), Color.BLACK, 1.5)
		draw_line(Vector2(cx, cy - 3), Vector2(cx, cy + 3), Color.BLACK, 1.5)
	elif "giant" in icon_name:
		# Draw a giant/upward arrow
		var points = PackedVector2Array([
			Vector2(cx, cy - 7),
			Vector2(cx - 5, cy - 2),
			Vector2(cx - 2, cy - 2),
			Vector2(cx - 2, cy + 5),
			Vector2(cx + 2, cy + 5),
			Vector2(cx + 2, cy - 2),
			Vector2(cx + 5, cy - 2)
		])
		draw_polygon(points, [icon_color])
	else:
		# Generic explosive icon
		draw_circle(Vector2(cx, cy), 6, icon_color)
