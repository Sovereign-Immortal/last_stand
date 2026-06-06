extends CanvasLayer

# Lightweight Dialog Manager
# Call DialogManager.show_dialog(lines) to display dialog and pause the game.
#
# Each line in the lines array can be:
# - A String: "Hello!"
# - A Dictionary: {"speaker": "Player", "text": "Hello!", "color": Color(0, 1, 1)}

var _dialog_lines: Array = []
var _current_line_idx: int = -1
var _is_typing: bool = false
var _last_visible_chars: int = 0
var _visible_char_ratio: float = 0.0

# UI Controls
var _panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _prompt_label: Label
var _type_tween: Tween

func _ready() -> void:
	# Ensure the dialog manager runs even when the game is paused!
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120 # Draw above HUD and menus
	
	_create_ui()

func _create_ui() -> void:
	# Main container
	_panel = PanelContainer.new()
	_panel.visible = false
	
	# Premium glassmorphic styling
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.08, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.05, 0.05, 0.8) # neon red borders
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	_panel.add_theme_stylebox_override("panel", style)
	
	# Size and layout (Bottom center of viewport)
	_panel.custom_minimum_size = Vector2(520, 95)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -260
	_panel.offset_right = 260
	_panel.offset_top = -110
	_panel.offset_bottom = -15
	
	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 10)
	margin_container.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin_container)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin_container.add_child(vbox)
	
	# Speaker Name
	_speaker_label = Label.new()
	_speaker_label.text = "SPEAKER"
	_speaker_label.add_theme_font_size_override("font_size", 12)
	_speaker_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	vbox.add_child(_speaker_label)
	
	# Dialogue Text
	_text_label = Label.new()
	_text_label.text = "Dialogue text goes here..."
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(488, 42)
	_text_label.add_theme_font_size_override("font_size", 11)
	_text_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	vbox.add_child(_text_label)
	
	# Prompt (e.g. Press SPACE to continue)
	_prompt_label = Label.new()
	_prompt_label.text = "Press SPACE to continue..."
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt_label.add_theme_font_size_override("font_size", 8)
	_prompt_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(_prompt_label)
	
	UIStyler.style_scene(_panel)
	add_child(_panel)

func show_dialog(lines: Array) -> void:
	if lines.is_empty():
		return
		
	# Pause the entire game
	get_tree().paused = true
	
	_dialog_lines = lines
	_current_line_idx = 0
	_panel.visible = true
	_display_current_line()

func _input(event: InputEvent) -> void:
	if not _panel.visible:
		return
		
	if event.is_action_pressed("shoot") or event.is_action_pressed("ui_accept"):
		# Get viewport input consumption
		get_viewport().set_input_as_handled()
		
		if _is_typing:
			# Skip typewriter animation
			_finish_typing()
		else:
			# Advance dialogue
			_current_line_idx += 1
			if _current_line_idx < _dialog_lines.size():
				_display_current_line()
			else:
				_close_dialog()

func _display_current_line() -> void:
	var line = _dialog_lines[_current_line_idx]
	var speaker = "???"
	var text = ""
	var speaker_color = Color(1.0, 0.2, 0.2)
	
	if line is Dictionary:
		speaker = line.get("speaker", "???")
		text = line.get("text", "")
		speaker_color = line.get("color", Color(1.0, 0.2, 0.2))
	elif line is String:
		text = line
		speaker = "SYSTEM"
		speaker_color = Color(0.3, 0.8, 1.0)
		
	# Trigger zombie noise sound effect if the dialogue contains it
	if text.contains("zombie noises") or text.contains("ZOMBIE NOISES"):
		AudioManager.play_zombie_groan()
		
	_speaker_label.text = speaker.to_upper()
	_speaker_label.add_theme_color_override("font_color", speaker_color)
	
	# Start typewriter effect
	_text_label.text = text
	_text_label.visible_characters = 0
	_last_visible_chars = 0
	_is_typing = true
	
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
		
	_type_tween = create_tween()
	# Slow/fast typewriter speed based on text length
	var duration = clampf(text.length() * 0.03, 0.3, 2.0)
	_type_tween.tween_property(_text_label, "visible_ratio", 1.0, duration).from(0.0)
	_type_tween.tween_callback(func(): _is_typing = false)

func _finish_typing() -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	_text_label.visible_ratio = 1.0
	_is_typing = false

func _close_dialog() -> void:
	_panel.visible = false
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
		
	# Unpause the game
	get_tree().paused = false

func _process(_delta: float) -> void:
	if _panel.visible and _is_typing:
		var current_chars = _text_label.visible_characters
		if current_chars > _last_visible_chars:
			var play_beep := false
			for i in range(_last_visible_chars, current_chars):
				if i < _text_label.text.length():
					var c = _text_label.text[i]
					# Skip whitespaces and newlines for natural audio cadence
					if c != " " and c != "\n" and c != "\t":
						# Play on every second character to avoid overlapping beeps
						if i % 2 == 0:
							play_beep = true
							break
			if play_beep:
				AudioManager.play_dialog_beep()
			_last_visible_chars = current_chars

func is_active() -> bool:
	return _panel.visible if _panel else false
