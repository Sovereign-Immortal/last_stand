extends Control

@onready var score_label: Label  = $VBox/ScoreLabel
@onready var wave_label: Label   = $VBox/WaveLabel
@onready var hi_label: Label     = $VBox/HiScoreLabel

func _ready() -> void:
	score_label.text = "SCORE  %06d" % Globals.score
	wave_label.text  = "WAVE REACHED  %d" % Globals.current_wave
	hi_label.text    = "BEST  %06d" % Globals.high_score
	UIStyler.style_scene(self)

func _on_retry_pressed() -> void:
	Globals.reset()
	SceneTransition.fade_to("res://Scenes/root.tscn")

func _on_menu_pressed() -> void:
	Globals.reset()
	SceneTransition.fade_to("res://Scenes/menue.tscn")
