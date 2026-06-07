extends CanvasLayer

# ---------------------------------------------------------------------------
# Touch Controls Overlay
# Provides:
#   - Left virtual joystick  → injects move_left/right/up/down actions
#   - Right side aim/shoot   → injects "shoot" action + rotates player to touch
#   - Action buttons         → interact, throw explosive, cycle bullet, cycle weapon, pause
#
# Only shown when a touchscreen is detected. Safe to include on desktop (hidden).
# ---------------------------------------------------------------------------

# -- Joystick state
var _joy_touch_idx: int = -1        # which finger is on the joystick
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_current: Vector2 = Vector2.ZERO
var _joy_radius: float = 44.0       # max drag distance (pixels in viewport)
var _joy_dead_zone: float = 6.0

# Joystick visual nodes
var _joy_base: Control = null
var _joy_knob: Control = null

# -- Right-side shoot zone state
var _shoot_touch_idx: int = -1
var _shoot_touch_pos: Vector2 = Vector2.ZERO   # screen position for aiming

# Published properties for player to read
var move_vector: Vector2 = Vector2.ZERO         # normalised movement direction
var aim_screen_pos: Vector2 = Vector2.ZERO      # screen position to aim at
var is_shooting: bool = false

# Buttons container
var _buttons_container: Control = null

# Reference back to HUD player (set by hud.gd)
var _player_ref = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	layer = 20  # above HUD (layer 10)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Only show on actual touch devices
	if not DisplayServer.is_touchscreen_available():
		# Still create it (so _player_ref etc work), just hide
		visible = false
		_build_ui()
		return

	_build_ui()
	visible = true

func _build_ui() -> void:
	_build_joystick()
	_build_shoot_zone()
	_build_action_buttons()

# ---------------------------------------------------------------------------
# Joystick (left side)
# ---------------------------------------------------------------------------
func _build_joystick() -> void:
	# Base ring
	_joy_base = _make_circle_control(Vector2(68, 68), Color(0.1, 0.1, 0.12, 0.55))
	_joy_base.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_base.offset_left   = 24
	_joy_base.offset_bottom = -24
	_joy_base.offset_right  = _joy_base.offset_left + 136
	_joy_base.offset_top    = _joy_base.offset_bottom - 136
	_joy_base.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_joy_base)

	# Knob
	_joy_knob = _make_circle_control(Vector2(44, 44), Color(0.85, 0.2, 0.2, 0.85))
	_joy_knob.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_knob.offset_left   = 24 + 46  # centered in base
	_joy_knob.offset_bottom = -24 - 46
	_joy_knob.offset_right  = _joy_knob.offset_left + 44
	_joy_knob.offset_top    = _joy_knob.offset_bottom - 44
	_joy_knob.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_joy_knob)

func _make_circle_control(size: Vector2, color: Color) -> Control:
	var c := ColorRect.new()
	c.custom_minimum_size = size
	c.color = color
	c.pivot_offset = size / 2.0
	# Make it round via shader
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 circle_color : source_color = vec4(1.0);
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = dot(uv, uv);
	float edge = fwidth(d) * 2.0;
	float alpha = 1.0 - smoothstep(1.0 - edge, 1.0, d);
	COLOR = vec4(circle_color.rgb, circle_color.a * alpha);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("circle_color", color)
	c.material = mat
	return c

# ---------------------------------------------------------------------------
# Shoot zone (invisible — right half of screen)
# ---------------------------------------------------------------------------
func _build_shoot_zone() -> void:
	# Invisible overlay on the right half — captures touches for shooting
	var zone := ColorRect.new()
	zone.color = Color(0, 0, 0, 0)  # fully transparent
	zone.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	zone.anchor_left = 0.35         # right 65% of screen
	zone.anchor_top  = 0.0
	zone.anchor_right = 1.0
	zone.anchor_bottom = 0.85       # leave bottom for buttons
	zone.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE  # we handle raw touch events
	add_child(zone)

# ---------------------------------------------------------------------------
# Action buttons (right side)
# ---------------------------------------------------------------------------
func _build_action_buttons() -> void:
	_buttons_container = Control.new()
	_buttons_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_buttons_container.offset_left   = -260
	_buttons_container.offset_bottom = -16
	_buttons_container.offset_right  = -16
	_buttons_container.offset_top    = _buttons_container.offset_bottom - 110
	_buttons_container.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_buttons_container)

	# Button definitions: [label, color, callback_name]
	var btns = [
		["⟳ RELOAD",   Color(0.2, 0.7, 1.0),  "_btn_reload"],
		["[E] USE",     Color(0.2, 1.0, 0.5),  "_btn_interact"],
		["[G] WEAPON",  Color(1.0, 0.75, 0.1), "_btn_weapon_menu"],
		["[F] ITEM",    Color(0.8, 0.3, 1.0),  "_btn_cycle_explosive"],
		["[X] THROW",   Color(1.0, 0.35, 0.2), "_btn_throw"],
		["[Q] BULLET",  Color(0.4, 0.8, 1.0),  "_btn_cycle_bullet"],
		["⏸ PAUSE",    Color(0.7, 0.7, 0.7),  "_btn_pause"],
	]

	var COLS := 4
	var BTN_W := 56.0
	var BTN_H := 28.0
	var GAP := 4.0
	var total_w := COLS * (BTN_W + GAP) - GAP
	var start_x := -total_w

	for i in range(btns.size()):
		var col := i % COLS
		var row := i / COLS
		var bx := start_x + col * (BTN_W + GAP)
		var by := -(btns.size() / COLS + 1) * (BTN_H + GAP) + row * (BTN_H + GAP)

		var btn := Button.new()
		btn.text = btns[i][0]
		var col_val: Color = btns[i][1]

		var s := StyleBoxFlat.new()
		s.bg_color = Color(col_val.r * 0.12, col_val.g * 0.12, col_val.b * 0.12, 0.88)
		s.border_color = col_val
		s.border_width_left   = 1
		s.border_width_top    = 1
		s.border_width_right  = 1
		s.border_width_bottom = 1
		s.corner_radius_top_left     = 5
		s.corner_radius_top_right    = 5
		s.corner_radius_bottom_left  = 5
		s.corner_radius_bottom_right = 5
		btn.add_theme_stylebox_override("normal", s)
		var sh := s.duplicate(); sh.bg_color = Color(col_val.r * 0.3, col_val.g * 0.3, col_val.b * 0.3, 0.95)
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_stylebox_override("pressed", sh)
		btn.add_theme_color_override("font_color", col_val)
		btn.add_theme_font_size_override("font_size", 8)
		btn.custom_minimum_size = Vector2(BTN_W, BTN_H)

		# Position relative to container bottom-right
		btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		btn.offset_right  = int(bx + BTN_W)
		btn.offset_bottom = int(by + BTN_H)
		btn.offset_left   = int(bx)
		btn.offset_top    = int(by)

		var cb_name: String = btns[i][2]
		btn.pressed.connect(Callable(self, cb_name))
		_buttons_container.add_child(btn)

# ---------------------------------------------------------------------------
# Touch Input Handling
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _get_joy_center() -> Vector2:
	# Center of joystick base in screen coords
	if not _joy_base:
		return Vector2(92, get_viewport().get_visible_rect().size.y - 92)
	# PRESET_BOTTOM_LEFT means we compute from bottom
	var vp := get_viewport().get_visible_rect().size
	return Vector2(24 + 68, vp.y - 24 - 68)

func _is_left_side(pos: Vector2) -> bool:
	return pos.x < get_viewport().get_visible_rect().size.x * 0.4

func _handle_touch(ev: InputEventScreenTouch) -> void:
	if ev.pressed:
		if _is_left_side(ev.position) and _joy_touch_idx == -1:
			_joy_touch_idx = ev.index
			_joy_origin    = ev.position
			_joy_current   = ev.position
			_update_joystick()
		elif not _is_left_side(ev.position) and _shoot_touch_idx == -1:
			_shoot_touch_idx = ev.index
			_shoot_touch_pos = ev.position
			aim_screen_pos   = ev.position
			is_shooting      = true
			_inject_shoot(true)
	else:
		if ev.index == _joy_touch_idx:
			_joy_touch_idx = -1
			_joy_origin    = Vector2.ZERO
			_joy_current   = Vector2.ZERO
			move_vector    = Vector2.ZERO
			_update_joystick()
			_clear_move_actions()
		elif ev.index == _shoot_touch_idx:
			_shoot_touch_idx = -1
			is_shooting      = false
			_inject_shoot(false)

func _handle_drag(ev: InputEventScreenDrag) -> void:
	if ev.index == _joy_touch_idx:
		_joy_current = ev.position
		_update_joystick()
	elif ev.index == _shoot_touch_idx:
		_shoot_touch_pos = ev.position
		aim_screen_pos   = ev.position

# ---------------------------------------------------------------------------
# Joystick logic → inject Input actions
# ---------------------------------------------------------------------------
func _update_joystick() -> void:
	if _joy_touch_idx == -1:
		move_vector = Vector2.ZERO
		_joy_knob_to_center()
		return

	var offset: Vector2 = _joy_current - _joy_origin
	var dist: float = offset.length()

	if dist < _joy_dead_zone:
		move_vector = Vector2.ZERO
		_joy_knob_to_center()
		_clear_move_actions()
		return

	var clamped := offset.limit_length(_joy_radius)
	move_vector = clamped / _joy_radius   # -1..1 per axis, normalised

	# Move knob visually
	if _joy_knob:
		var vp := get_viewport().get_visible_rect().size
		var center := Vector2(24 + 68, vp.y - 24 - 68)
		var knob_center := center + clamped
		_joy_knob.offset_left   = knob_center.x - 22
		_joy_knob.offset_right  = knob_center.x + 22
		_joy_knob.offset_bottom = -(vp.y - knob_center.y) - 22 + vp.y - (vp.y)
		# Simpler: reposition using position
		_joy_knob.position = knob_center - Vector2(22, 22)
		_joy_knob.set_anchors_preset(Control.PRESET_TOP_LEFT)

	# Inject input actions
	_set_action("move_left",  move_vector.x < -0.1)
	_set_action("move_right", move_vector.x >  0.1)
	_set_action("move_up",    move_vector.y < -0.1)
	_set_action("move_down",  move_vector.y >  0.1)

func _joy_knob_to_center() -> void:
	if not _joy_knob:
		return
	_joy_knob.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var vp := get_viewport().get_visible_rect().size
	var center := Vector2(24 + 68, vp.y - 24 - 68)
	_joy_knob.position = center - Vector2(22, 22)

func _clear_move_actions() -> void:
	_set_action("move_left",  false)
	_set_action("move_right", false)
	_set_action("move_up",    false)
	_set_action("move_down",  false)

# ---------------------------------------------------------------------------
# Shoot injection
# ---------------------------------------------------------------------------
func _inject_shoot(pressed: bool) -> void:
	_set_action("shoot", pressed)

# ---------------------------------------------------------------------------
# Action button callbacks
# ---------------------------------------------------------------------------
func _btn_reload() -> void:
	_pulse_action("reload")

func _btn_interact() -> void:
	_pulse_action("interact")

func _btn_pause() -> void:
	_pulse_action("pause_game")

func _btn_weapon_menu() -> void:
	# Open weapon switch menu in HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("open_weapon_switch_menu"):
		hud.open_weapon_switch_menu()

func _btn_cycle_explosive() -> void:
	# Calls cycle explosive on the player directly
	if _player_ref and is_instance_valid(_player_ref):
		if _player_ref.has_method("_cycle_explosive"):
			_player_ref._cycle_explosive()

func _btn_throw() -> void:
	if _player_ref and is_instance_valid(_player_ref):
		if _player_ref.has_method("_throw_explosive"):
			_player_ref._throw_explosive()

func _btn_cycle_bullet() -> void:
	if _player_ref and is_instance_valid(_player_ref):
		if _player_ref.has_method("_cycle_bullet_type"):
			_player_ref._cycle_bullet_type()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _set_action(action: String, active: bool) -> void:
	if not InputMap.has_action(action):
		return
	if active:
		var e := InputEventAction.new()
		e.action  = action
		e.pressed = true
		Input.parse_input_event(e)
	else:
		var e := InputEventAction.new()
		e.action  = action
		e.pressed = false
		Input.parse_input_event(e)

func _pulse_action(action: String) -> void:
	if not InputMap.has_action(action):
		return
	var ep := InputEventAction.new()
	ep.action  = action
	ep.pressed = true
	Input.parse_input_event(ep)
	await get_tree().create_timer(0.05).timeout
	var er := InputEventAction.new()
	er.action  = action
	er.pressed = false
	Input.parse_input_event(er)

# ---------------------------------------------------------------------------
# Per-frame: update player aim from touch position
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if not visible:
		return
	if _shoot_touch_idx != -1 and _player_ref and is_instance_valid(_player_ref):
		# Convert screen pos → world pos for player look_at
		var cam: Camera2D = _player_ref.get_node_or_null("Camera2D")
		if cam:
			var world_pos := cam.get_screen_center_position() + \
				(aim_screen_pos - get_viewport().get_visible_rect().size / 2.0) / cam.zoom
			_player_ref.look_at(world_pos)
