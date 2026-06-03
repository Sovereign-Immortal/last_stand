extends Node
## Central game state — score, waves, combo, and persistent high score.

const SAVE_PATH := "user://last_stand_save.dat"

# ---------------------------------------------------------------------------
# Game State
# ---------------------------------------------------------------------------
var score: int = 0
var current_wave: int = 1
var high_score: int = 0

# Kill streak
var combo: int = 1          # current multiplier
var _combo_timer: float = 0.0
const COMBO_WINDOW: float = 2.5   # seconds before combo resets
const COMBO_MAX: int = 5

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal score_changed(new_score: int)
signal wave_changed(new_wave: int)
signal combo_changed(multiplier: int)

func _ready() -> void:
	load_save()

# ---------------------------------------------------------------------------
# Score
# ---------------------------------------------------------------------------
func add_score(amount: int) -> void:
	var awarded := amount * combo
	score += awarded
	if score > high_score:
		high_score = score
		save()  # persist new record immediately
	# Advance combo
	var old_combo := combo
	combo = min(combo + 1, COMBO_MAX)
	_combo_timer = COMBO_WINDOW
	if combo != old_combo:
		emit_signal("combo_changed", combo)
	emit_signal("score_changed", score)

func _process(delta: float) -> void:
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo = 1
			emit_signal("combo_changed", combo)

# ---------------------------------------------------------------------------
# Wave
# ---------------------------------------------------------------------------
func advance_wave() -> void:
	current_wave += 1
	emit_signal("wave_changed", current_wave)

# ---------------------------------------------------------------------------
# Reset (call on new game)
# ---------------------------------------------------------------------------
func reset() -> void:
	score = 0
	current_wave = 1
	combo = 1
	_combo_timer = 0.0
	emit_signal("score_changed", score)
	emit_signal("wave_changed", current_wave)
	emit_signal("combo_changed", combo)

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------
func save() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var(high_score)

func load_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			high_score = int(f.get_var())
