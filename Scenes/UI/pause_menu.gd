extends Control

func _ready() -> void:
	# This panel should always process even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
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
