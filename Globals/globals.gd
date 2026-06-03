extends Node
## Central game state — score, waves, combo, and persistent high score.

const SAVE_PATH := "user://last_stand_save.dat"

# ---------------------------------------------------------------------------
# Game State
# ---------------------------------------------------------------------------
var score: int = 0 # Represents Experience Points (EXP) and shop currency
var current_wave: int = 1
var high_score: int = 0
var discovered_lore: Array = []
var is_continuing_game: bool = false
var selected_map: String = "res://Scenes/Locations/map_1.tscn"
var unlocked_endings: Array = []

const LORE_FRAGMENTS: Array[Dictionary] = [
	{
		"id": 0,
		"category": "heritage",
		"title": "The Veil of Flesh",
		"dialogue": [
			{"speaker": "Ancient King", "text": "\"You will walk among them. Your bones will shrink. Your voice will soften.\"", "color": Color(1.0, 0.8, 0.1)},
			{"speaker": "Ancient King", "text": "\"Your ears will forget the sound of the earth's heartbeat. You will be small, and frightened, and alone. But you will live.\"", "color": Color(1.0, 0.8, 0.1)},
			{"speaker": "Narrator", "text": "A spell older than the mountains. The prince screamed as his body folded into itself.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 1,
		"category": "world",
		"title": "Project Chimera Log",
		"dialogue": [
			{"speaker": "Military Scientist", "text": "\"We extracted Giant's Marrow from the ancient remains. We thought it would grant immortality.\"", "color": Color(1.0, 0.2, 0.2)},
			{"speaker": "Military Scientist", "text": "\"We were wrong. It does not heal. It reanimates. The first injection created Subject Zero – a thing that rose and did not speak.\"", "color": Color(1.0, 0.2, 0.2)},
			{"speaker": "Narrator", "text": "The infection spread not through bites, but through proximity to the marrow residue.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 2,
		"category": "heritage",
		"title": "Specimen 73 Dossier",
		"dialogue": [
			{"speaker": "Lab Record", "text": "\"Soldiers dragged the stone sarcophagus here. Inside: a young man, breathing, dreaming.\"", "color": Color(1.0, 0.8, 0.1)},
			{"speaker": "Lab Record", "text": "\"Labeled Specimen 73. Injected with marrow twice. He did not turn. He only screamed about high-frequency noises.\"", "color": Color(1.0, 0.8, 0.1)},
			{"speaker": "Narrator", "text": "A giant prince hidden in human bones. Immune, because his very blood is giant.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 3,
		"category": "implanted",
		"title": "Implanted Memories",
		"dialogue": [
			{"speaker": "Psychologist", "text": "\"We wiped his true memory. In its place, we loaded fake childhood scenarios.\"", "color": Color(1.0, 0.2, 0.2)},
			{"speaker": "Psychologist", "text": "\"A quiet school, a warm home, a mother... a voice whispering: 'I am sorry mom I won't be able to go to school tomorrow.'\"", "color": Color(1.0, 0.2, 0.2)},
			{"speaker": "Narrator", "text": "They wanted a blank slate. Instead, they loaded a time bomb.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 4,
		"category": "heritage",
		"title": "The Stone Sarcophagus",
		"dialogue": [
			{"speaker": "Father's Echo", "text": "\"Forgive me. When the Veil breaks, you will remember. And you will have to choose what kind of king you want to be.\"", "color": Color(1.0, 0.8, 0.1)},
			{"speaker": "Narrator", "text": "The stasis chamber has opened. Your ears ring with static. The dead crawl near.", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "Narrator", "text": "Deep beneath the laboratory ruins, the Giant Heart is still pulsing. Waiting for its prince.", "color": Color(0.0, 0.8, 1.0)}
		]
	}
]

# Leveling System
var player_level: int = 1
var skill_points: int = 0
var hp_stat_level: int = 0
var speed_stat_level: int = 0
var damage_stat_level: int = 0

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
signal level_up_available
signal player_leveled_up

func _ready() -> void:
	load_save()

# ---------------------------------------------------------------------------
# Level Up Calculation & Operations
# ---------------------------------------------------------------------------
func get_next_level_cost() -> int:
	return 100 + (player_level - 1) * 75

func check_level_up_available() -> bool:
	return score >= get_next_level_cost()

func level_up() -> bool:
	var cost := get_next_level_cost()
	if score >= cost:
		score -= cost
		player_level += 1
		skill_points += 1
		emit_signal("score_changed", score)
		emit_signal("player_leveled_up")
		save()
		return true
	return false

func upgrade_stat(stat_name: String) -> bool:
	if skill_points > 0:
		skill_points -= 1
		if stat_name == "hp":
			hp_stat_level += 1
		elif stat_name == "speed":
			speed_stat_level += 1
		elif stat_name == "damage":
			damage_stat_level += 1
		emit_signal("player_leveled_up")
		save()
		return true
	return false

# ---------------------------------------------------------------------------
# Score (EXP) Addition
# ---------------------------------------------------------------------------
func add_score(amount: int) -> void:
	var old_can_lvl = check_level_up_available()
	var awarded := amount * combo
	score += awarded
	if score > high_score:
		high_score = score
	save()  # persist progress immediately
	# Advance combo
	var old_combo := combo
	combo = min(combo + 1, COMBO_MAX)
	_combo_timer = COMBO_WINDOW
	if combo != old_combo:
		emit_signal("combo_changed", combo)
	emit_signal("score_changed", score)
	
	if not old_can_lvl and check_level_up_available():
		emit_signal("level_up_available")

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
	save()

# ---------------------------------------------------------------------------
# Reset (call on new game)
# ---------------------------------------------------------------------------
func reset() -> void:
	score = 0
	current_wave = 1
	combo = 1
	_combo_timer = 0.0
	player_level = 1
	skill_points = 0
	hp_stat_level = 0
	speed_stat_level = 0
	damage_stat_level = 0
	emit_signal("score_changed", score)
	emit_signal("wave_changed", current_wave)
	emit_signal("combo_changed", combo)
	emit_signal("player_leveled_up")

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------
func save() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		var data := {
			"high_score": high_score,
			"score": score,
			"current_wave": current_wave,
			"player_level": player_level,
			"skill_points": skill_points,
			"hp_stat_level": hp_stat_level,
			"speed_stat_level": speed_stat_level,
			"damage_stat_level": damage_stat_level,
			"discovered_lore": discovered_lore,
			"selected_map": selected_map,
			"unlocked_endings": unlocked_endings
		}
		f.store_var(data)

func load_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var data = f.get_var()
			if data is Dictionary:
				high_score = data.get("high_score", 0)
				score = data.get("score", 0)
				current_wave = data.get("current_wave", 1)
				player_level = data.get("player_level", 1)
				skill_points = data.get("skill_points", 0)
				hp_stat_level = data.get("hp_stat_level", 0)
				speed_stat_level = data.get("speed_stat_level", 0)
				damage_stat_level = data.get("damage_stat_level", 0)
				discovered_lore = data.get("discovered_lore", [])
				selected_map = data.get("selected_map", "res://Scenes/Locations/map_1.tscn")
				unlocked_endings = data.get("unlocked_endings", [])

func has_save_file() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var data = f.get_var()
		if data is Dictionary and data.get("current_wave", 1) > 1:
			return true
	return false

func discover_lore(id: int) -> void:
	if not discovered_lore.has(id):
		discovered_lore.append(id)
		save()
		
		# Check for memory contradictions: Specimen 73 Dossier (2) vs Implanted Memories (3)
		if discovered_lore.has(2) and discovered_lore.has(3):
			if id == 2 or id == 3:
				# Trigger sensory headache flashback dialogue and heavy tinnitus
				get_tree().create_timer(1.5).timeout.connect(func():
					DialogManager.show_dialog([
						{
							"speaker": "Kaelan",
							"text": "AHHHHH MY HEAD!!",
							"color": Color(0.2, 0.9, 1.0)
						},
						{
							"speaker": "Kaelan",
							"text": "ShUTUpp!!",
							"color": Color(0.2, 0.9, 1.0)
						},
						{
							"speaker": "Kaelan",
							"text": "None of these school memories make sense... who am I really?",
							"color": Color(0.2, 0.9, 1.0)
						}
					])
					AudioManager.trigger_tinnitus(4.0)
				)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	high_score = 0
	score = 0
	current_wave = 1
	player_level = 1
	skill_points = 0
	hp_stat_level = 0
	speed_stat_level = 0
	damage_stat_level = 0
	discovered_lore = []
	unlocked_endings = []
	selected_map = "res://Scenes/Locations/map_1.tscn"
