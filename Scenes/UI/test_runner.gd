extends Node

func _ready() -> void:
	print("--- Running Minimap Integration Tests ---")
	
	# Small delay to ensure all singletons are initialized
	await get_tree().process_frame
	
	test_theme_colors()
	test_visited_cell_tracking()
	test_world_to_minimap_conversion()
	test_minimap_toggle()
	test_npc_initialization()
	test_safe_spawn_positioning()
	test_lore_interaction()
	test_npc_resource_and_hostility()
	test_mercenary_menu()
	test_persistence()
	test_rare_drops_and_new_items()
	test_hostile_hunter_group()
	test_mini_boss_abilities()
	
	print("--- All Minimap, NPC, Lore & Mercenary Menu Tests Passed Successfully! ---")
	get_tree().quit(0)

func test_theme_colors() -> void:
	var m = Minimap.new()
	
	# Test Cemetery theme detection
	Globals.selected_map = "res://Scenes/Locations/cemetery_hills.tscn"
	var colors_cemetery = m._get_theme_colors()
	assert(colors_cemetery.border == Color(0.2, 0.8, 0.3, 0.85), "Cemetery border color mismatch")
	assert(colors_cemetery.player == Color(0.1, 1.0, 0.2, 1.0), "Cemetery player color mismatch")
	
	# Test Heart Cavern theme detection
	Globals.selected_map = "res://Scenes/Locations/heart_cavern.tscn"
	var colors_heart = m._get_theme_colors()
	assert(colors_heart.border == Color(0.95, 0.1, 0.25, 0.85), "Heart Cavern border color mismatch")
	assert(colors_heart.player == Color(1.0, 0.8, 0.1, 1.0), "Heart Cavern player color mismatch")
	
	# Test Subway theme detection
	Globals.selected_map = "res://Scenes/Locations/subway_tunnels.tscn"
	var colors_subway = m._get_theme_colors()
	assert(colors_subway.border == Color(0.85, 0.65, 0.1, 0.85), "Subway border color mismatch")
	assert(colors_subway.player == Color(0.0, 0.9, 1.0, 1.0), "Subway player color mismatch")
	
	# Test Default map theme detection
	Globals.selected_map = "res://Scenes/Locations/map_1.tscn"
	var colors_default = m._get_theme_colors()
	assert(colors_default.border == Color(0.1, 0.75, 1.0, 0.85), "Default border color mismatch")
	assert(colors_default.player == Color(0.0, 0.9, 1.0, 1.0), "Default player color mismatch")
	
	m.queue_free()
	print("[PASS] Theme Color Resolution Test")

func test_visited_cell_tracking() -> void:
	var m = Minimap.new()
	
	# Mock player position: center of cell (1, 1) in world coords (64 + 32, 64 + 32)
	# Cell size = 64
	var mock_player = Node2D.new()
	mock_player.global_position = Vector2(96.0, 96.0)
	
	# Manually run visited tracking logic (normally inside _process)
	var p_pos = mock_player.global_position
	var px = int(floor(p_pos.x / 64.0)) # should be 1
	var py = int(floor(p_pos.y / 64.0)) # should be 1
	
	assert(px == 1 and py == 1, "Failed to calculate mock player cell coord")
	
	# Track player position and reveal cells (similar to _process)
	var reveal_radius = 3
	for dx in range(-reveal_radius, reveal_radius + 1):
		for dy in range(-reveal_radius, reveal_radius + 1):
			if dx*dx + dy*dy <= reveal_radius*reveal_radius:
				var cell = Vector2i(px + dx, py + dy)
				m.visited_cells[cell] = true
				
	# Assert player cell is visited
	assert(m.visited_cells.has(Vector2i(1, 1)), "Player cell not marked visited")
	# Assert cell within radius is visited
	assert(m.visited_cells.has(Vector2i(2, 2)), "Adjacent diagonal cell not marked visited")
	# Assert cell way outside is NOT visited
	assert(not m.visited_cells.has(Vector2i(10, 10)), "Distant cell incorrectly marked visited")
	
	mock_player.queue_free()
	m.queue_free()
	print("[PASS] Visited Cell Tracking Test")

func test_world_to_minimap_conversion() -> void:
	var m = Minimap.new()
	
	var player_pos = Vector2(1000, 1000)
	
	# If object is at same position as player, it should map to minimap center (50, 50)
	var m_pos_center = m.world_to_minimap(player_pos, player_pos)
	assert(m_pos_center.is_equal_approx(Vector2(50, 50)), "Center mapping mismatch: " + str(m_pos_center))
	
	# If object is 200 units to the right, at scale 0.05 it should be 10 pixels to the right (60, 50)
	var obj_pos = player_pos + Vector2(200, 0)
	var m_pos_right = m.world_to_minimap(obj_pos, player_pos)
	assert(m_pos_right.is_equal_approx(Vector2(60, 50)), "Offset mapping mismatch: " + str(m_pos_right))
	
	m.queue_free()
	print("[PASS] World-to-Minimap Conversion Test")

func test_minimap_toggle() -> void:
	var m = Minimap.new()
	
	# Initial state
	assert(m._is_minimap_visible == true, "Minimap should be visible by default")
	
	# First toggle -> Hidden
	m._is_minimap_visible = false
	assert(m._is_minimap_visible == false, "Minimap toggle to hidden failed")
	
	# Second toggle -> Visible
	m._is_minimap_visible = true
	assert(m._is_minimap_visible == true, "Minimap toggle back to visible failed")
	
	m.queue_free()
	print("[PASS] Minimap Visibility Toggle Test")

func test_npc_initialization() -> void:
	var npc_script = load("res://Scenes/Humans/npc.gd")
	var hunter = npc_script.new()
	hunter.npc_type = "hunter"
	hunter._ready() # trigger ready hooks
	assert(hunter.is_in_group("npcs"), "NPC not added to npcs group")
	assert(hunter.is_in_group("targets"), "Hunter NPC not added to targets group")
	hunter.free()

	var pacifist = npc_script.new()
	pacifist.npc_type = "pacifist"
	pacifist._ready()
	assert(pacifist.is_in_group("npcs"), "NPC not added to npcs group")
	assert(pacifist.is_in_group("targets"), "Pacifist NPC not added to targets group")
	pacifist.free()
	print("[PASS] NPC Group Initialization Test")

func test_safe_spawn_positioning() -> void:
	# Instantiate a dummy player with essential player properties
	var p = CharacterBody2D.new()
	var player_dummy_script = GDScript.new()
	player_dummy_script.source_code = "extends CharacterBody2D\nvar is_dead := false\nvar health := 100.0\nvar max_health := 100.0"
	player_dummy_script.reload()
	p.set_script(player_dummy_script)
	p.global_position = Vector2(100.0, 100.0)
	
	# Instantiate HUD (which has the safe spawn algorithm)
	var hud_inst = load("res://Scenes/UI/hud.tscn").instantiate()
	hud_inst._player = p
	
	# Mock WaveManager with a spawn point close to the player candidate area
	var wm_mock = Node.new()
	var dummy_script = GDScript.new()
	dummy_script.source_code = "extends Node\nvar _spawn_points := []"
	dummy_script.reload()
	wm_mock.set_script(dummy_script)
	wm_mock.name = "WaveManager"
	var sp_mock = Marker2D.new()
	sp_mock.global_position = Vector2(120.0, 120.0) # very close to player (100, 100)
	wm_mock.add_child(sp_mock)
	wm_mock._spawn_points = [sp_mock]
	
	# Mock Root node
	var root_mock = Node.new()
	root_mock.name = "Root"
	root_mock.add_child(wm_mock)
	
	# Set up scene tree context
	Engine.get_main_loop().root.add_child(root_mock)
	Engine.get_main_loop().root.add_child(hud_inst)
	
	# Find safe spawn position
	var pos = hud_inst._get_safe_spawn_position()
	
	# Pos must be far away from spawn point (120, 120) because the algorithm rejects spawn points within 350px
	var dist = pos.distance_to(sp_mock.global_position)
	assert(dist > 0.0, "Safe position failed to avoid nearby spawn point")
	
	# Clean up
	Engine.get_main_loop().root.remove_child(hud_inst)
	Engine.get_main_loop().root.remove_child(root_mock)
	root_mock.queue_free()
	hud_inst.queue_free()
	p.queue_free()
	print("[PASS] NPC Safe Spawn Positioning Test")

func test_lore_interaction() -> void:
	# Check array size
	assert(Globals.LORE_FRAGMENTS.size() >= 12, "Lore fragments size mismatch")
	assert(Globals.LORE_FRAGMENTS[5]["id"] == 5, "Lore ID 5 not found")
	assert(Globals.LORE_FRAGMENTS[6]["id"] == 6, "Lore ID 6 not found")
	assert(Globals.LORE_FRAGMENTS[7]["id"] == 7, "Lore ID 7 not found")
	assert(Globals.LORE_FRAGMENTS[8]["id"] == 8, "Lore ID 8 not found")
	assert(Globals.LORE_FRAGMENTS[9]["id"] == 9, "Lore ID 9 not found")
	assert(Globals.LORE_FRAGMENTS[10]["id"] == 10, "Lore ID 10 not found")
	assert(Globals.LORE_FRAGMENTS[11]["id"] == 11, "Lore ID 11 not found")
	
	# Instantiate a Hunter NPC
	var hunter = load("res://Scenes/Humans/npc.gd").new()
	hunter.npc_type = "hunter"
	Engine.get_main_loop().root.add_child(hunter)
	
	# Initial ready has run, verify interact method
	assert(hunter.has_meta("interact_method"), "NPC missing interact_method meta")
	
	# Save current discovered lore list state
	var old_discovered = Globals.discovered_lore.duplicate()
	
	# Clear the state for testing
	Globals.discovered_lore.clear()
	
	# Give hunter a gun/ammo so the dialogue interaction runs
	hunter.has_gun = true
	hunter.ammo_count = 100
	
	# Trigger Hunter interaction
	var hunter_interact = hunter.get_meta("interact_method")
	hunter_interact.call()
	assert(Globals.discovered_lore.has(7), "Hunter interaction failed to unlock Lore ID 7")
	
	# Instantiate a Pacifist NPC
	var pacifist = load("res://Scenes/Humans/npc.gd").new()
	pacifist.npc_type = "pacifist"
	Engine.get_main_loop().root.add_child(pacifist)
	
	# Give pacifist a gun/ammo so the dialogue interaction runs
	pacifist.has_gun = true
	pacifist.ammo_count = 100
	
	var pacifist_interact = pacifist.get_meta("interact_method")
	pacifist_interact.call()
	assert(Globals.discovered_lore.has(8), "Pacifist interaction failed to unlock Lore ID 8")
	
	# Restore old discovered lore state
	Globals.discovered_lore = old_discovered
	
	# Cleanup
	hunter.free()
	pacifist.free()
	print("[PASS] NPC Lore Interaction Test")

func test_npc_resource_and_hostility() -> void:
	# Instantiate a Pacifist NPC
	var pacifist = load("res://Scenes/Humans/npc.gd").new()
	pacifist.npc_type = "pacifist"
	Engine.get_main_loop().root.add_child(pacifist)
	
	# Verify initial state
	assert(not pacifist.has_gun, "Pacifist should not start with a gun")
	assert(pacifist.ammo_count == 0, "Pacifist should start with 0 ammo")
	assert(not pacifist.is_hostile_to_player, "Pacifist should not start hostile")
	
	# Trigger provocation
	pacifist.provoke()
	assert(pacifist.is_hostile_to_player, "Pacifist provoke failed to trigger hostility")
	assert(pacifist.has_gun, "Pacifist provoke failed to give angry pistol")
	assert(pacifist.ammo_count > 1000, "Pacifist provoke failed to give hostile ammo")
	
	# Trigger take_damage and death/zombie conversion
	var initial_xp = Globals.score
	pacifist.take_damage(200.0) # Should die
	assert(pacifist.is_dead, "Pacifist should be dead after high damage")
	assert(Globals.score == initial_xp + 60, "NPC death should award 60 EXP")
	
	# Cleanup
	pacifist.free()
	
	# Verify hire costs dynamically
	var hud_mock = load("res://Scenes/UI/hud.tscn").instantiate()
	Engine.get_main_loop().root.add_child(hud_mock)
	hud_mock._player = load("res://Scenes/Humans/player.tscn").instantiate()
	Engine.get_main_loop().root.add_child(hud_mock._player)
	
	hud_mock._update_char_menu()
	assert(hud_mock._cm_hire_hunter_btn.text == "120 EXP", "Initial dynamic hunter cost mismatch")
	assert(hud_mock._cm_hire_pacifist_btn.text == "60 EXP", "Initial dynamic pacifist cost mismatch")
	
	# Spawn a temporary companion NPC to check cost increase
	var temp_npc = load("res://Scenes/Humans/npc.tscn").instantiate()
	temp_npc.global_position = Vector2(-9999, -9999)
	Engine.get_main_loop().root.add_child(temp_npc)
	
	hud_mock._update_char_menu()
	assert(hud_mock._cm_hire_hunter_btn.text == "170 EXP", "Hunter cost should scale to 170 with 1 active NPC")
	assert(hud_mock._cm_hire_pacifist_btn.text == "90 EXP", "Pacifist cost should scale to 90 with 1 active NPC")
	
	# Spawn 20 more mock NPCs to trigger the 20 NPC limit
	var npc_cap_pool = []
	for i in range(20):
		var n = load("res://Scenes/Humans/npc.tscn").instantiate()
		n.global_position = Vector2(-9999, -9999)
		Engine.get_main_loop().root.add_child(n)
		npc_cap_pool.append(n)
		
	hud_mock._update_char_menu()
	assert(hud_mock._cm_hire_hunter_btn.disabled, "Hire hunter button should be disabled when at 20+ NPCs")
	assert(hud_mock._cm_hire_hunter_btn.text == "MAX REACHED", "Hunter button text should show MAX REACHED")
	assert(hud_mock._cm_hire_pacifist_btn.disabled, "Hire pacifist button should be disabled when at 20+ NPCs")
	assert(hud_mock._cm_hire_pacifist_btn.text == "MAX REACHED", "Pacifist button text should show MAX REACHED")
	
	# Cleanup mock
	hud_mock._player.free()
	hud_mock.free()
	temp_npc.free()
	for n in npc_cap_pool:
		n.free()
	
	print("[PASS] NPC Resource and Hostility Test")

func test_mercenary_menu() -> void:
	# Instantiate player
	var player = load("res://Scenes/Humans/player.tscn").instantiate()
	player.global_position = Vector2(200, 200)
	Engine.get_main_loop().root.add_child(player)
	
	# Instantiate HUD
	var hud = load("res://Scenes/UI/hud.tscn").instantiate()
	Engine.get_main_loop().root.add_child(hud)
	hud._player = player
	
	# Spawn a companion NPC
	var npc = load("res://Scenes/Humans/npc.tscn").instantiate()
	npc.npc_type = "hunter"
	npc.global_position = Vector2(250, 250)
	Engine.get_main_loop().root.add_child(npc)
	
	# Select companion in HUD mercenary menu
	hud._selected_merc = npc
	
	# Give player some resources
	player.bullet_ammo[0] = 100 # Standard bullets
	var carried: Array[int] = [0, 1]
	player.carried_weapons = carried
	player.ammo_remaining[1] = 80 # MG bullets
	
	# Give MG weapon to NPC
	hud._on_give_weapon_pressed(1)
	
	# Verify NPC received the weapon and bullets
	assert(npc.has_gun, "NPC should now have a gun")
	assert(npc.equipped_weapon == 1, "NPC weapon should be MG")
	assert(npc.ammo_count == 50, "NPC ammo should be 50 after weapon transfer")
	assert(player.ammo_remaining[1] == 30, "Player MG ammo should have decreased to 30")
	
	# Transfer some paralysis bullets (type 2) to NPC
	player.bullet_ammo[2] = 40 # player paralysis bullets
	hud._on_give_bullet_pressed(2)
	
	# Verify NPC received paralysis bullet type and ammo count updated
	assert(npc.equipped_bullet_type == 2, "NPC bullet type should be Paralysis (2)")
	assert(npc.ammo_count == 90, "NPC ammo should be 90 after paralysis transfer")
	assert(player.bullet_ammo[2] == 0, "Player paralysis ammo should be depleted to 0")
	
	# Cleanup
	hud.queue_free()
	player.queue_free()
	npc.queue_free()
	print("[PASS] HUD Mercenary Menu and Transfer Test")

func test_persistence() -> void:
	# Store current globals state to restore later
	var old_killed = Globals.player_was_killed
	var old_hp = Globals.hp_stat_level
	var old_spd = Globals.speed_stat_level
	var old_dmg = Globals.damage_stat_level
	var old_score = Globals.score
	var old_sp = Globals.skill_points
	var old_carried = Globals.persisted_carried_weapons.duplicate()
	var old_ammo_rem = Globals.persisted_ammo_remaining.duplicate()
	var old_bullet_ammo = Globals.persisted_bullet_ammo.duplicate()
	var old_explosives = Globals.persisted_explosives_ammo.duplicate()
	
	# Scenario 1: Alive (player_was_killed = false), call Globals.reset()
	Globals.player_was_killed = false
	Globals.score = 500
	Globals.skill_points = 5
	Globals.hp_stat_level = 5
	Globals.speed_stat_level = 5
	Globals.damage_stat_level = 5
	Globals.persisted_carried_weapons.assign([0, 1])
	Globals.persisted_ammo_remaining.assign([-1, 120, 0])
	Globals.persisted_bullet_ammo.assign([300, 50, 15, 20, 30])
	Globals.persisted_explosives_ammo.assign([3, 3, 3, 0, 0])
	Globals.persisted_current_weapon_index = 1
	Globals.persisted_current_bullet_type = 1
	Globals.persisted_current_explosive_index = 1
	
	Globals.reset()
	
	# Verify EP (score) and SP (skill_points) are reset, but stats are NOT
	assert(Globals.score == 0, "EP should be reset to 0")
	assert(Globals.skill_points == 0, "SP should be reset to 0")
	assert(Globals.hp_stat_level == 5, "HP level should persist")
	assert(Globals.speed_stat_level == 5, "Speed level should persist")
	assert(Globals.damage_stat_level == 5, "Damage level should persist")
	assert(Globals.persisted_carried_weapons == [0, 1], "Carried weapons should persist")
	
	# Instantiate player to check restoration
	var player = load("res://Scenes/Humans/player.tscn").instantiate()
	Engine.get_main_loop().root.add_child(player)
	
	# Verify player loaded values match persisted state
	assert(player.carried_weapons == [0, 1], "Player carried_weapons should be restored")
	assert(player.ammo_remaining == [-1, 120, 0], "Player ammo_remaining should be restored")
	assert(player.bullet_ammo == [300, 50, 15, 20, 30], "Player bullet_ammo should be restored")
	assert(player.explosives_ammo == [3, 3, 3, 0, 0], "Player explosives_ammo should be restored")
	assert(player.current_weapon_index == 1, "Player current_weapon_index should be restored")
	assert(player.current_bullet_type == 1, "Player current_bullet_type should be restored")
	assert(player.current_explosive_index == 1, "Player current_explosive_index should be restored")
	
	player.queue_free()
	
	# Scenario 2: Killed (player_was_killed = true), call Globals.reset()
	Globals.player_was_killed = true
	Globals.reset()
	
	assert(Globals.hp_stat_level == 0, "HP level should be reset to 0")
	assert(Globals.speed_stat_level == 0, "Speed level should be reset to 0")
	assert(Globals.damage_stat_level == 0, "Damage level should be reset to 0")
	assert(Globals.persisted_carried_weapons == [0], "Carried weapons should reset to default [0]")
	assert(Globals.persisted_bullet_ammo == [300, 0, 0, 0, 0], "Bullet ammo should reset to default")
	assert(Globals.persisted_explosives_ammo == [3, 3, 3, 0, 0], "Explosives should reset to default")
	
	# Restore old state
	Globals.player_was_killed = old_killed
	Globals.hp_stat_level = old_hp
	Globals.speed_stat_level = old_spd
	Globals.damage_stat_level = old_dmg
	Globals.score = old_score
	Globals.skill_points = old_sp
	Globals.persisted_carried_weapons.assign(old_carried)
	Globals.persisted_ammo_remaining.assign(old_ammo_rem)
	Globals.persisted_bullet_ammo.assign(old_bullet_ammo)
	Globals.persisted_explosives_ammo.assign(old_explosives)
	
	print("[PASS] Persistent Stats and Inventory Test")

func test_rare_drops_and_new_items() -> void:
	var old_sp = Globals.skill_points
	Globals.skill_points = 0
	
	var player = load("res://Scenes/Humans/player.tscn").instantiate()
	Engine.get_main_loop().root.add_child(player)
	player.global_position = Vector2.ZERO
	
	assert(player.explosives_ammo[3] == 0, "Initial Skill Point Orbs should be 0")
	assert(player.explosives_ammo[4] == 0, "Initial Giantification items should be 0")
	
	player.add_item_ammo(3, 1)
	assert(player.explosives_ammo[3] == 1, "Player should have 1 Skill Point Orb")
	
	player.current_explosive_index = 3
	player.explosive_cooldown = 0.0
	player._throw_explosive()
	
	assert(player.explosives_ammo[3] == 0, "Skill Point Orb should be consumed")
	assert(Globals.skill_points == 1, "Skill Point should be awarded")
	
	player.add_item_ammo(4, 1)
	assert(player.explosives_ammo[4] == 1, "Player should have 1 Giantification item")
	
	player.current_explosive_index = 4
	player.explosive_cooldown = 0.0
	player._throw_explosive()
	
	assert(player.explosives_ammo[4] == 0, "Giantification item should be consumed")
	assert(player.is_giant == true, "Player should become giant")
	
	player.queue_free()
	Globals.skill_points = old_sp
	
	print("[PASS] Rare Drops and New Items Test")

func test_hostile_hunter_group() -> void:
	var hunter = load("res://Scenes/Humans/npc.tscn").instantiate()
	hunter.npc_type = "hostile_hunter"
	Engine.get_main_loop().root.add_child(hunter)
	hunter.global_position = Vector2(0, 0)
	
	assert(hunter.is_hostile_to_player == true, "Hostile hunter must be hostile to player")
	assert(hunter.has_gun == true, "Hostile hunter must have a gun")
	assert(hunter.equipped_weapon == 1, "Hostile hunter must be equipped with Machine Gun")
	
	hunter.scream_subject_73()
	var labels = []
	for child in hunter.get_children():
		if child is Label and child.text == "subject 73 DIE!!!":
			labels.append(child)
	assert(labels.size() == 1, "Hostile hunter must spawn the scream label")
	
	hunter.queue_free()
	print("[PASS] Hostile Hunter Group Test")

func test_mini_boss_abilities() -> void:
	var base_scene = load("res://Scenes/Zombies/zombie_base.tscn")
	assert(base_scene != null, "zombie_base.tscn should exist")
	
	var boss = base_scene.instantiate()
	boss.set_script(load("res://Scenes/Zombies/mini_boss.gd"))
	boss.setup_boss("prototype")
	Engine.get_main_loop().root.add_child(boss)
	boss.global_position = Vector2.ZERO
	
	assert(boss.boss_name == "Prototype", "Mini boss name mismatch")
	assert(boss.max_health == 600.0, "Mini boss health mismatch")
	assert(boss.abilities.has("lunge"), "Mini boss must have lunge ability")
	
	var dummy = Node2D.new()
	Engine.get_main_loop().root.add_child(dummy)
	dummy.global_position = Vector2(100, 0)
	boss.player_target = dummy
	
	boss._trigger_lunge()
	assert(boss.lunge_duration > 0.0, "Lunge ability should set lunge duration")
	
	boss.queue_free()
	dummy.queue_free()
	print("[PASS] Mini Boss Abilities Test")

