extends Resource
class_name SaveData

@export var high_score: int = 0
@export var score: int = 0
@export var current_wave: int = 1
@export var player_level: int = 1
@export var skill_points: int = 0
@export var hp_stat_level: int = 0
@export var speed_stat_level: int = 0
@export var damage_stat_level: int = 0
@export var discovered_lore: Array = []
@export var selected_map: String = "res://Scenes/Locations/map_1.tscn"
@export var unlocked_endings: Array = []
@export var visited_maps: Array = []
@export var player_was_killed: bool = true
@export var persisted_carried_weapons: Array[int] = [0]
@export var persisted_ammo_remaining: Array[int] = [-1, 0, 0]
@export var persisted_bullet_ammo: Array[int] = [300, 0, 0, 0, 0]
@export var persisted_explosives_ammo: Array[int] = [3, 3, 3, 0, 0]
@export var persisted_current_weapon_index: int = 0
@export var persisted_current_bullet_type: int = 0
@export var persisted_current_explosive_index: int = 0
@export var zone1_bosses_defeated: Array = []
@export var zone2_bosses_defeated: Array = []
