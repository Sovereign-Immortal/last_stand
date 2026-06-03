extends CanvasLayer
## Global scene transition overlay — fades to black between scene changes.
## Usage: SceneTransition.fade_to("res://path/to/scene.tscn")

var _rect: ColorRect
var _do_fade_in: bool = false

func _ready() -> void:
	layer = 100  # always on top
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color.BLACK
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 1.0  # start opaque, then fade in
	add_child(_rect)
	# Auto fade-in when scene loads
	_do_fade_in = true

func _process(_delta: float) -> void:
	if _do_fade_in:
		_do_fade_in = false
		fade_in()

func fade_to(path: String, duration: float = 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 1.0, duration)
	tw.tween_callback(func():
		Engine.time_scale = 1.0   # always restore — guards against slow-mo leak
		get_tree().change_scene_to_file(path)
		_do_fade_in = true
	)

func fade_in(duration: float = 0.4) -> void:
	var tw := create_tween()
	tw.tween_property(_rect, "modulate:a", 0.0, duration)
