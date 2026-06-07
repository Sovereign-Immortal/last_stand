extends Node
## Central game state — score, waves, combo, and persistent high score.

const SAVE_PATH := "user://last_stand_save.res"

# ---------------------------------------------------------------------------
# Game State
# ---------------------------------------------------------------------------
var score: int = 0 # Represents Experience Points (EXP) and shop currency
var current_wave: int = 1
var high_score: int = 0
var discovered_lore: Array = []
var visited_maps: Array = []
var player_was_killed: bool = true
var persisted_carried_weapons: Array[int] = [0]
var persisted_ammo_remaining: Array[int] = [-1, 0, 0]
var persisted_bullet_ammo: Array[int] = [300, 0, 0, 0, 0]
var persisted_explosives_ammo: Array[int] = [3, 3, 3, 0, 0]
var persisted_current_weapon_index: int = 0
var persisted_current_bullet_type: int = 0
var persisted_current_explosive_index: int = 0
var is_continuing_game: bool = false
var selected_map: String = "res://Scenes/Locations/map_1.tscn"
var unlocked_endings: Array = []
var hunter_hire_cost: int = 120
var pacifist_hire_cost: int = 60
var zone1_bosses_defeated: Array = []
var zone2_bosses_defeated: Array = []

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
	},
	{
		"id": 5,
		"category": "world",
		"title": "The Crypt Whisper",
		"dialogue": [
			{"speaker": "Grave Inscription", "text": "\"Here lies Kaelen's shadow. The prince who slept while the world burned.\"", "color": Color(0.8, 0.8, 0.8)},
			{"speaker": "Narrator", "text": "A chilling draft blows from the cracked stone. You feel a strange connection to this grave.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 6,
		"category": "world",
		"title": "The Lost Log",
		"dialogue": [
			{"speaker": "Crumpled Paper", "text": "\"We buried the research notes in the cemetery. If the lab falls, the truth must survive.\"", "color": Color(0.9, 0.8, 0.2)},
			{"speaker": "Narrator", "text": "The ink is smudged, but the coordinates point directly to this hollow grave.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 7,
		"category": "implanted",
		"title": "Vanguard Orders",
		"dialogue": [
			{"speaker": "Hired Soldier", "text": "\"The higher-ups told us we were defending civilians. But our real target was Specimen 73.\"", "color": Color(1.0, 0.4, 0.4)},
			{"speaker": "Hired Soldier", "text": "\"If he woke up... we were ordered to terminate him. I'm glad I chose to fight beside you instead.\"", "color": Color(1.0, 0.4, 0.4)}
		]
	},
	{
		"id": 8,
		"category": "heritage",
		"title": "A Survivor's Hope",
		"dialogue": [
			{"speaker": "Survivor", "text": "\"I saw the Cavern of the Heart. It pulses with a soft crimson light. It felt... welcoming.\"", "color": Color(0.4, 1.0, 0.4)},
			{"speaker": "Survivor", "text": "\"Maybe the end of this nightmare is waiting down there, under the Veil.\"", "color": Color(0.4, 1.0, 0.4)}
		]
	},
	{
		"id": 9,
		"category": "world",
		"title": "Echoes of the Subway",
		"dialogue": [
			{"speaker": "Subway Inscription", "text": "\"Tunnel 4: High-frequency emissions detected. Sound levels exceeding safety limits.\"", "color": Color(0.9, 0.8, 0.2)},
			{"speaker": "Narrator", "text": "The stone is cold. The distant sound of rumbling train tracks is long gone.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 10,
		"category": "implanted",
		"title": "The Heartbeat Frequency",
		"dialogue": [
			{"speaker": "Lab Notes", "text": "\"The heart does not beat in sound. It beats in electromagnetic cycles. 440 Hertz.\"", "color": Color(1.0, 0.4, 0.4)},
			{"speaker": "Narrator", "text": "A frequency that aligns with Kaelen's brainwave patterns during stasis.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 11,
		"category": "heritage",
		"title": "The Final Covenant",
		"dialogue": [
			{"speaker": "Ancient King", "text": "\"We leave this heart as our final seal. A guardian of the surface world.\"", "color": Color(1.0, 0.8, 0.1)},
			{"speaker": "Narrator", "text": "The light of the core will guide the true prince. Only he can choose to destroy or seal.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 12,
		"category": "heritage",
		"title": "Subject 0: Spine",
		"dialogue": [
			{"speaker": "Scientist Log", "text": "\"The central column of the first specimen was fused with pure obsidian stardust. They tried to break it, but it only vibrated at a pitch that drove the lab staff mad.\"", "color": Color(0.8, 0.95, 1.0)},
			{"speaker": "Narrator", "text": "The spine pulsates with electromagnetic energy. It acts as an anchor for the other components.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 13,
		"category": "heritage",
		"title": "Subject 0 Skull",
		"dialogue": [
			{"speaker": "Scientist Log", "text": "\"The skull of the prince's twin. Shattered and reconstructed using mechanical synapses. It remembers a sky that had no sun.\"", "color": Color(0.7, 0.4, 0.9)},
			{"speaker": "Narrator", "text": "The cold metal plate hums with remnants of dark thoughts.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 14,
		"category": "heritage",
		"title": "Subject 0 Heart",
		"dialogue": [
			{"speaker": "Scientist Log", "text": "\"A massive organ of flesh and iron, beating in reverse. It draws the blood of the living to fuel the engines of the cavern.\"", "color": Color(1.0, 0.15, 0.15)},
			{"speaker": "Narrator", "text": "The pulsing core is hot to the touch, overflowing with chaotic life force.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 15,
		"category": "world",
		"title": "True Cyborg Profile",
		"dialogue": [
			{"speaker": "Cyborg Inscription", "text": "\"A human soldier whose organs were entirely replaced with high-frequency batteries. When the system failed, he remained, trapped in a loop of permanent defense protocols.\"", "color": Color(0.5, 0.5, 0.6)},
			{"speaker": "Narrator", "text": "His optics flicker, warning all trespassers of immediate termination.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 16,
		"category": "world",
		"title": "Prototype Notes",
		"dialogue": [
			{"speaker": "Chemical Memo", "text": "\"The first runner. Built to test speed limits using adrenal-chemical engines. It could outrun its own shadow before the infection melted its mind.\"", "color": Color(0.85, 0.95, 0.1)},
			{"speaker": "Narrator", "text": "Chemical injectors hum continuously on its deformed back.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 17,
		"category": "world",
		"title": "Zombiefied Giant Relic",
		"dialogue": [
			{"speaker": "Ancient Tablet", "text": "\"An ancient titan that woke up under the cemetery. It couldn't breathe the air of this era, and its lungs turned to ash, yet it still walks.\"", "color": Color(0.2, 0.8, 0.3)},
			{"speaker": "Narrator", "text": "A towering figure whose heavy footsteps shake the dirt off the old graves.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 18,
		"category": "heritage",
		"title": "Fake True Giant Replica",
		"dialogue": [
			{"speaker": "Replication Log", "text": "\"A clone built to mimic the stature of the stasis king. Its bones are hollow, its blood is synthetic, but its wrath is absolutely real.\"", "color": Color(1.0, 0.6, 0.1)},
			{"speaker": "Narrator", "text": "A tragic attempt to recreate the divine power of the stasis kings.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 19,
		"category": "world",
		"title": "Demonic Scripture I: Perseverance",
		"dialogue": [
			{"speaker": "Torn Page", "text": "\"He who walks a thousand miles begins with a single step, and finishes with a thousand more that no one sees.\" — Anurag Shre", "color": Color(0.10, 0.06, 0.08)},
			{"speaker": "Narrator", "text": "The quiet grind that shames talent. While the gifted sleep, perseverance sculpts the immortal out of a mortal shell.", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "Warning", "text": "Shadow: Blindly persisting on a broken path turns you into a ghost hammering a wall that has no door.", "color": Color(0.7, 0.3, 0.3)}
		]
	},
	{
		"id": 20,
		"category": "world",
		"title": "Demonic Scripture II: Detached Temperament",
		"dialogue": [
			{"speaker": "Torn Page", "text": "\"The wise man feels the storm but does not become the storm. When the wind tires, he walks through the wreckage untouched.\" — Anurag Shre", "color": Color(0.70, 0.80, 0.85)},
			{"speaker": "Narrator", "text": "Clarity of mind is the supreme advantage. Wrath, love, fear — these are expensive drugs.", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "Warning", "text": "Shadow: Without a burning core, this detachment becomes a frozen wasteland.", "color": Color(0.7, 0.3, 0.3)}
		]
	},
	{
		"id": 21,
		"category": "world",
		"title": "Demonic Scripture III: Covetousness",
		"dialogue": [
			{"speaker": "Torn Page", "text": "\"I will take what is mine. Then I will take what isn't, until the world itself is inside me.\" — Anurag Shre", "color": Color(0.45, 0.05, 0.65)},
			{"speaker": "Narrator", "text": "Hunger is the engine of growth. To covet knowledge, power, and advantage is to expand the boundaries of your existence.", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "Warning", "text": "Shadow: A worm that swallows an elephant simply bursts. Covet wisely, or your greed will carve your grave.", "color": Color(0.7, 0.3, 0.3)}
		]
	},
	{
		"id": 22,
		"category": "world",
		"title": "Demonic Scripture IV: Self-Integrity",
		"dialogue": [
			{"speaker": "Torn Page", "text": "\"Better to reign in Hell than serve in Heaven.\" — Anurag Shre, citing Satan, Paradise Lost", "color": Color(0.05, 0.05, 0.07)},
			{"speaker": "Narrator", "text": "When your thoughts, words, and actions are one blade, you become uncuttable. The world's judgment becomes the bleating of sheep.", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "Warning", "text": "Shadow: Integrity to a doomed path makes you a magnificent fool. Have the ruthless wisdom to change it.", "color": Color(0.7, 0.3, 0.3)}
		]
	},
	{
		"id": 23,
		"category": "world",
		"title": "Demonic Scripture V: Resolve & Ruthlessness",
		"dialogue": [
			{"speaker": "Torn Page", "text": "\"If I must burn the world to keep my promise, I will strike the first match.\" — Anurag Shre", "color": Color(0.75, 0.05, 0.05)},
			{"speaker": "Narrator", "text": "The path of greatness is paved with decisions that would shatter ordinary men. The universe bends to the hand that does not tremble.", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "Warning", "text": "Shadow: Ruthlessness that becomes cruelty for pleasure is a leakage of power. Your blade must be a surgeon's scalpel.", "color": Color(0.7, 0.3, 0.3)}
		]
	},
	{
		"id": 24,
		"category": "world",
		"title": "Demonic Scripture VI: Cunning",
		"dialogue": [
			{"speaker": "Torn Page", "text": "\"The perfect game is won before the opponent knows he is playing. When he finally sees the board, he is already in checkmate.\" — Anurag Shre", "color": Color(0.05, 0.45, 0.10)},
			{"speaker": "Narrator", "text": "Cunning is the divine art of turning the enemy's own rules against him. It allows the weak to devour the strong.", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "Warning", "text": "Shadow: Cunning without a final trump card is just a fancy suicide note. When the web tears, fight like a trapped wolf.", "color": Color(0.7, 0.3, 0.3)}
		]
	},
	{
		"id": 25,
		"category": "implanted",
		"title": "Implanted Memory: The Playground",
		"dialogue": [
			{"speaker": "Mother's Voice", "text": "\"Don't run too fast Kaelan. You'll hurt your knees. Let's go home soon.\"", "color": Color(1.0, 0.4, 0.4)},
			{"speaker": "Narrator", "text": "The sound of children laughing is distant. Artificial. The swings are empty.", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "System", "text": "Memory block decrypted. An artificial schoolyard, manufactured in the cleanrooms.", "color": Color(0.0, 0.8, 1.0)}
		]
	},
	{
		"id": 26,
		"category": "implanted",
		"title": "Implanted Memory: The Hospital",
		"dialogue": [
			{"speaker": "Doctor", "text": "\"Take a deep breath. Count backward from ten. Everything will be fine.\"", "color": Color(1.0, 0.4, 0.4)},
			{"speaker": "Narrator", "text": "The sterile smell of disinfectant and ozone. The hum of a life-support turbine.", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "System", "text": "Memory block decrypted. The cold touch of chrome needles inserting false dreams.", "color": Color(0.0, 0.8, 1.0)}
		]
	},
	{
		"id": 27,
		"category": "implanted",
		"title": "Implanted Memory: The Departure",
		"dialogue": [
			{"speaker": "Sister's Voice", "text": "\"You promised you wouldn't leave me alone! Why are you sleeping?\"", "color": Color(1.0, 0.4, 0.4)},
			{"speaker": "Narrator", "text": "A girl's cry echoes in the dark corridor. You have no sister. Who was she?", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "System", "text": "Memory block decrypted. A fragment of a real memory, corrupted during overwrite.", "color": Color(0.0, 0.8, 1.0)}
		]
	},
	{
		"id": 28,
		"category": "heritage",
		"title": "The Cosmic Catalyst",
		"dialogue": [
			{"speaker": "Ancient Whispers", "text": "\"The death of our physical forms is not defeat. It is the consolidation of the catalyst.\"", "color": Color(1.0, 0.6, 0.0)},
			{"speaker": "Narrator", "text": "An ancient giant script describing a ritual where a world is consumed to build a crown of absolute dominion.", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "System", "text": "A chilling realization: the war between humans and giants was not an accident.", "color": Color(0.9, 0.1, 0.1)}
		]
	},
	{
		"id": 29,
		"category": "world",
		"title": "Chessboard of the Gods",
		"dialogue": [
			{"speaker": "Anurag Shre", "text": "\"The Giant King thinks he is the player. He does not realize he is simply the most valuable piece on my side of the board.\"", "color": Color(0.2, 0.9, 0.3)},
			{"speaker": "Anurag Shre", "text": "\"I will let him assemble the souls. I will let him dissolve the barrier. And then, I will take his seat.\"", "color": Color(0.2, 0.9, 0.3)},
			{"speaker": "Narrator", "text": "A handwritten diary detailing calculations of cosmic ascension. Two mastermind wills contesting the same empty throne.", "color": Color(0.3, 0.8, 1.0)}
		]
	},
	{
		"id": 30,
		"category": "implanted",
		"title": "The True Vessel",
		"dialogue": [
			{"speaker": "Echo of the Crown", "text": "\"You are the cup. We are the wine. When the cup is filled, the drinker will awaken.\"", "color": Color(1.0, 0.6, 0.0)},
			{"speaker": "Narrator", "text": "A vision of the player Kaelan wearing a crown of burning stars, surrounded by a universe dissolved into grey mist.", "color": Color(0.3, 0.8, 1.0)},
			{"speaker": "Warning", "text": "The memories inside you... they are not fake. They are the anchor keeping the god asleep.", "color": Color(0.7, 0.3, 0.3)}
		]
	}
]

#

# Developer Boss Testing
var dev_boss_testing: bool = false
var dev_boss_type: String = "spine"

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
	skill_points = 0
	current_wave = 1
	combo = 1
	_combo_timer = 0.0
	
	if player_was_killed:
		player_level = 1
		hp_stat_level = 0
		speed_stat_level = 0
		damage_stat_level = 0
		persisted_carried_weapons.assign([0])
		persisted_ammo_remaining.assign([-1, 0, 0])
		persisted_bullet_ammo.assign([300, 0, 0, 0, 0])
		persisted_explosives_ammo.assign([3, 3, 3, 0, 0])
		persisted_current_weapon_index = 0
		persisted_current_bullet_type = 0
		persisted_current_explosive_index = 0
		
	emit_signal("score_changed", score)
	emit_signal("wave_changed", current_wave)
	emit_signal("combo_changed", combo)
	emit_signal("player_leveled_up")

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------
const SaveDataRes = preload("res://Globals/save_data.gd")

func save() -> void:
	var s = SaveDataRes.new()
	s.high_score = high_score
	s.score = score
	s.current_wave = current_wave
	s.player_level = player_level
	s.skill_points = skill_points
	s.hp_stat_level = hp_stat_level
	s.speed_stat_level = speed_stat_level
	s.damage_stat_level = damage_stat_level
	s.discovered_lore = discovered_lore.duplicate()
	s.selected_map = selected_map
	s.unlocked_endings = unlocked_endings.duplicate()
	s.visited_maps = visited_maps.duplicate()
	s.player_was_killed = player_was_killed
	s.persisted_carried_weapons = persisted_carried_weapons.duplicate()
	s.persisted_ammo_remaining = persisted_ammo_remaining.duplicate()
	s.persisted_bullet_ammo = persisted_bullet_ammo.duplicate()
	s.persisted_explosives_ammo = persisted_explosives_ammo.duplicate()
	s.persisted_current_weapon_index = persisted_current_weapon_index
	s.persisted_current_bullet_type = persisted_current_bullet_type
	s.persisted_current_explosive_index = persisted_current_explosive_index
	s.zone1_bosses_defeated = zone1_bosses_defeated.duplicate()
	s.zone2_bosses_defeated = zone2_bosses_defeated.duplicate()
	
	ResourceSaver.save(s, SAVE_PATH)

func load_save() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		var s = ResourceLoader.load(SAVE_PATH)
		if s and s.get_script() == SaveDataRes:
			high_score = s.high_score
			score = s.score
			current_wave = s.current_wave
			player_level = s.player_level
			skill_points = s.skill_points
			hp_stat_level = s.hp_stat_level
			speed_stat_level = s.speed_stat_level
			damage_stat_level = s.damage_stat_level
			discovered_lore = s.discovered_lore.duplicate()
			selected_map = s.selected_map
			unlocked_endings = s.unlocked_endings.duplicate()
			visited_maps = s.visited_maps.duplicate()
			player_was_killed = s.player_was_killed
			persisted_carried_weapons.assign(s.persisted_carried_weapons)
			persisted_ammo_remaining.assign(s.persisted_ammo_remaining)
			persisted_bullet_ammo.assign(s.persisted_bullet_ammo)
			while persisted_bullet_ammo.size() < 5:
				persisted_bullet_ammo.append(0)
			persisted_explosives_ammo.assign(s.persisted_explosives_ammo)
			while persisted_explosives_ammo.size() < 5:
				persisted_explosives_ammo.append(0)
			persisted_current_weapon_index = s.persisted_current_weapon_index
			persisted_current_bullet_type = s.persisted_current_bullet_type
			persisted_current_explosive_index = s.persisted_current_explosive_index
			if "zone1_bosses_defeated" in s:
				zone1_bosses_defeated = s.zone1_bosses_defeated.duplicate()
			if "zone2_bosses_defeated" in s:
				zone2_bosses_defeated = s.zone2_bosses_defeated.duplicate()

func has_save_file() -> bool:
	if not ResourceLoader.exists(SAVE_PATH):
		return false
	var s = ResourceLoader.load(SAVE_PATH)
	if s and s.get_script() == SaveDataRes and s.current_wave > 1:
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
	
	# Cleanup legacy .dat file if it exists
	var legacy_path := "user://last_stand_save.dat"
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(legacy_path)
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
	visited_maps = []
	player_was_killed = true
	persisted_carried_weapons.assign([0])
	persisted_ammo_remaining.assign([-1, 0, 0])
	persisted_bullet_ammo.assign([300, 0, 0, 0, 0])
	persisted_explosives_ammo.assign([3, 3, 3, 0, 0])
	persisted_current_weapon_index = 0
	persisted_current_bullet_type = 0
	persisted_current_explosive_index = 0
	selected_map = "res://Scenes/Locations/map_1.tscn"
	zone1_bosses_defeated = []
	zone2_bosses_defeated = []

func get_map_lore_percentage(map_path: String) -> float:
	var map_lore_ids = []
	if map_path == "res://Scenes/Locations/map_1.tscn":
		map_lore_ids = [0, 1, 2, 3, 4, 15, 16]
	elif map_path == "res://Scenes/Locations/cemetery_hills.tscn":
		map_lore_ids = [5, 6, 12, 18]
	elif map_path == "res://Scenes/Locations/subway_tunnels.tscn":
		map_lore_ids = [9, 10, 11, 13, 17]
	elif map_path == "res://Scenes/Locations/heart_cavern.tscn":
		map_lore_ids = [7, 8, 14]
		
	if map_lore_ids.size() == 0:
		return 0.0
		
	var disc_items = 0
	for id in map_lore_ids:
		if discovered_lore.has(id):
			disc_items += 1
			
	return float(disc_items) / float(map_lore_ids.size())
