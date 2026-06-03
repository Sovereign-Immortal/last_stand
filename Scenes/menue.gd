extends Control

func _ready() -> void:
	UIStyler.style_scene(self)

# ---------------------------------------------------------------------------
# Button signals
# ---------------------------------------------------------------------------
func _on_button_pressed() -> void:
	SceneTransition.fade_to("res://Scenes/root.tscn")

func _on_button_2_pressed() -> void:
	# TRUTH — placeholder for lore/story screen
	# TODO: replace with Dialogic timeline when authored
	pass

func _on_button_3_pressed() -> void:
	# QUIT
	get_tree().quit()
