extends Control

@onready var vbox: VBoxContainer = $VBox

func _ready() -> void:
	# This panel should always process even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	# Add Settings button dynamically to Pause Menu
	var settings_btn := Button.new()
	settings_btn.text = "SETTINGS"
	settings_btn.add_theme_font_size_override("font_size", 20)
	settings_btn.add_theme_stylebox_override("normal", preload("res://btn styles/menue buttons.tres"))
	vbox.add_child(settings_btn)
	vbox.move_child(settings_btn, 2) # Position between Resume and Main Menu
	settings_btn.pressed.connect(_on_settings_pressed)
	
	UIStyler.style_scene(self)

func show_pause() -> void:
	visible = true

func hide_pause() -> void:
	visible = false

func _on_resume_pressed() -> void:
	hide_pause()
	get_tree().paused = false

func _on_menu_pressed() -> void:
	get_tree().paused = false
	Globals.reset()
	SceneTransition.fade_to("res://Scenes/menue.tscn")

func _on_settings_pressed() -> void:
	AudioManager.play_click()
	var settings = preload("res://Scenes/UI/settings_menu.tscn").instantiate()
	add_child(settings)
