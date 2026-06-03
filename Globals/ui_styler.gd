class_name UIStyler
extends Object

static var _theme: Theme = null

static func get_theme() -> Theme:
	if _theme != null:
		return _theme

	_theme = Theme.new()

	# -----------------------------------------------------------------------
	# 1. BUTTON STYLES
	# -----------------------------------------------------------------------
	# Normal stylebox
	var normal_box := StyleBoxFlat.new()
	normal_box.bg_color = Color(0.08, 0.08, 0.1, 0.65)
	normal_box.border_width_left = 1
	normal_box.border_width_top = 1
	normal_box.border_width_right = 1
	normal_box.border_width_bottom = 1
	normal_box.border_color = Color(0.3, 0.3, 0.35, 0.4)
	normal_box.corner_radius_top_left = 10
	normal_box.corner_radius_top_right = 10
	normal_box.corner_radius_bottom_right = 10
	normal_box.corner_radius_bottom_left = 10
	normal_box.shadow_color = Color(0, 0, 0, 0.3)
	normal_box.shadow_size = 4
	normal_box.shadow_offset = Vector2(0, 2)
	normal_box.content_margin_left = 16
	normal_box.content_margin_right = 16
	normal_box.content_margin_top = 8
	normal_box.content_margin_bottom = 8

	# Hover stylebox (dark red theme with vibrant border)
	var hover_box := StyleBoxFlat.new()
	hover_box.bg_color = Color(0.15, 0.03, 0.03, 0.75)
	hover_box.border_width_left = 2
	hover_box.border_width_top = 2
	hover_box.border_width_right = 2
	hover_box.border_width_bottom = 2
	hover_box.border_color = Color(0.85, 0.05, 0.05, 0.9)
	hover_box.corner_radius_top_left = 10
	hover_box.corner_radius_top_right = 10
	hover_box.corner_radius_bottom_right = 10
	hover_box.corner_radius_bottom_left = 10
	hover_box.shadow_color = Color(0.85, 0.05, 0.05, 0.25)
	hover_box.shadow_size = 6
	hover_box.shadow_offset = Vector2(0, 0)
	hover_box.content_margin_left = 16
	hover_box.content_margin_right = 16
	hover_box.content_margin_top = 8
	hover_box.content_margin_bottom = 8

	# Pressed stylebox
	var pressed_box := StyleBoxFlat.new()
	pressed_box.bg_color = Color(0.2, 0.02, 0.02, 0.9)
	pressed_box.border_width_left = 2
	pressed_box.border_width_top = 2
	pressed_box.border_width_right = 2
	pressed_box.border_width_bottom = 2
	pressed_box.border_color = Color(1.0, 0.1, 0.1, 1.0)
	pressed_box.corner_radius_top_left = 10
	pressed_box.corner_radius_top_right = 10
	pressed_box.corner_radius_bottom_right = 10
	pressed_box.corner_radius_bottom_left = 10
	pressed_box.shadow_color = Color(0, 0, 0, 0.5)
	pressed_box.shadow_size = 2
	pressed_box.content_margin_left = 16
	pressed_box.content_margin_right = 16
	pressed_box.content_margin_top = 8
	pressed_box.content_margin_bottom = 8

	# Focus stylebox
	var focus_box := StyleBoxFlat.new()
	focus_box.bg_color = Color(0.08, 0.08, 0.1, 0.65)
	focus_box.border_width_left = 1
	focus_box.border_width_top = 1
	focus_box.border_width_right = 1
	focus_box.border_width_bottom = 1
	focus_box.border_color = Color(0.85, 0.05, 0.05, 0.5)
	focus_box.corner_radius_top_left = 10
	focus_box.corner_radius_top_right = 10
	focus_box.corner_radius_bottom_right = 10
	focus_box.corner_radius_bottom_left = 10

	# Disabled stylebox
	var disabled_box := StyleBoxFlat.new()
	disabled_box.bg_color = Color(0.05, 0.05, 0.05, 0.3)
	disabled_box.border_width_left = 1
	disabled_box.border_width_top = 1
	disabled_box.border_width_right = 1
	disabled_box.border_width_bottom = 1
	disabled_box.border_color = Color(0.15, 0.15, 0.15, 0.2)
	disabled_box.corner_radius_top_left = 10
	disabled_box.corner_radius_top_right = 10
	disabled_box.corner_radius_bottom_right = 10
	disabled_box.corner_radius_bottom_left = 10

	# Assign to Theme
	_theme.set_stylebox("normal", "Button", normal_box)
	_theme.set_stylebox("hover", "Button", hover_box)
	_theme.set_stylebox("pressed", "Button", pressed_box)
	_theme.set_stylebox("focus", "Button", focus_box)
	_theme.set_stylebox("disabled", "Button", disabled_box)

	_theme.set_color("font_color", "Button", Color(0.9, 0.9, 0.9, 1))
	_theme.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.95, 1))
	_theme.set_color("font_pressed_color", "Button", Color(1.0, 0.7, 0.7, 1))
	_theme.set_color("font_focus_color", "Button", Color(0.9, 0.9, 0.9, 1))

	# -----------------------------------------------------------------------
	# 2. TOOLTIP STYLES
	# -----------------------------------------------------------------------
	var tooltip_panel := StyleBoxFlat.new()
	tooltip_panel.bg_color = Color(0.04, 0.04, 0.06, 0.95)
	tooltip_panel.border_width_left = 1
	tooltip_panel.border_width_top = 1
	tooltip_panel.border_width_right = 1
	tooltip_panel.border_width_bottom = 1
	tooltip_panel.border_color = Color(0.85, 0.05, 0.05, 0.7)
	tooltip_panel.corner_radius_top_left = 8
	tooltip_panel.corner_radius_top_right = 8
	tooltip_panel.corner_radius_bottom_right = 8
	tooltip_panel.corner_radius_bottom_left = 8
	tooltip_panel.shadow_color = Color(0, 0, 0, 0.5)
	tooltip_panel.shadow_size = 6
	tooltip_panel.content_margin_left = 12
	tooltip_panel.content_margin_right = 12
	tooltip_panel.content_margin_top = 8
	tooltip_panel.content_margin_bottom = 8

	_theme.set_stylebox("panel", "TooltipPanel", tooltip_panel)
	_theme.set_color("font_color", "TooltipLabel", Color(0.9, 0.9, 0.92, 1))
	_theme.set_font_size("font_size", "TooltipLabel", 12)

	# -----------------------------------------------------------------------
	# 3. LABEL STYLES
	# -----------------------------------------------------------------------
	_theme.set_color("font_color", "Label", Color(0.95, 0.95, 0.95, 1))
	_theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.85))
	_theme.set_constant("shadow_offset_x", "Label", 1)
	_theme.set_constant("shadow_offset_y", "Label", 1)

	return _theme

static func style_scene(root: Control) -> void:
	root.theme = get_theme()
	_apply_styles_recursive(root)

static func _apply_styles_recursive(node: Node) -> void:
	if node is Button:
		var btn := node as Button
		# Clear all inline style and color overrides so it inherits theme styling
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_color_override("font_hover_color")
		btn.remove_theme_color_override("font_pressed_color")
		btn.remove_theme_color_override("font_focus_color")
		btn.remove_theme_color_override("font_disabled_color")
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_stylebox_override("pressed")
		btn.remove_theme_stylebox_override("focus")
		btn.remove_theme_stylebox_override("disabled")

		# Apply dynamic micro-animations (scale on hover)
		btn.pivot_offset = btn.size * 0.5
		if not btn.resized.is_connected(_update_pivot.bind(btn)):
			btn.resized.connect(_update_pivot.bind(btn))

		# Check if already connected to avoid duplicate connections
		if not btn.mouse_entered.is_connected(_on_btn_hover.bind(btn)):
			btn.mouse_entered.connect(_on_btn_hover.bind(btn))
		if not btn.mouse_exited.is_connected(_on_btn_unhover.bind(btn)):
			btn.mouse_exited.connect(_on_btn_unhover.bind(btn))

	elif node is Label:
		var lbl := node as Label
		# Custom shadow styles to make titles/text stand out premium
		lbl.remove_theme_color_override("font_shadow_color")
		lbl.remove_theme_constant_override("shadow_offset_x")
		lbl.remove_theme_constant_override("shadow_offset_y")

	for child in node.get_children():
		_apply_styles_recursive(child)

static func _update_pivot(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5

static func _on_btn_hover(btn: Button) -> void:
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)
	AudioManager.play_empty()

static func _on_btn_unhover(btn: Button) -> void:
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
