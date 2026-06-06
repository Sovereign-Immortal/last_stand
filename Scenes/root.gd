extends Node2D

func _ready() -> void:
	# If a custom map is selected, load it and replace Map1
	if Globals.selected_map != "res://Scenes/Locations/map_1.tscn":
		var map_node := get_node_or_null("Map1")
		if map_node:
			var parent := map_node.get_parent()
			var idx := map_node.get_index()
			map_node.free()
			
			var custom_map_scene = load(Globals.selected_map)
			if custom_map_scene:
				var custom_map = custom_map_scene.instantiate() as Node2D
				custom_map.name = "Map1"
				parent.add_child(custom_map)
				parent.move_child(custom_map, idx)
		_spawn_wanderers()
	else:
		_spawn_map1_lore()



func _spawn_map1_lore() -> void:
	var positions = [
		Vector2(-200, 100),
		Vector2(200, -100),
		Vector2(-300, -200),
		Vector2(350, 250),
		Vector2(0, 450)
	]
	var lore_pickup_scene = load("res://Scenes/Objects/lore_pickup.tscn")
	for i in range(5):
		if not Globals.discovered_lore.has(i):
			var lp = lore_pickup_scene.instantiate()
			lp.lore_id = i
			lp.global_position = positions[i]
			add_child.call_deferred(lp)

	_spawn_wanderers()

func _spawn_wanderers() -> void:
	# Spawn 3-5 wanderers per map session, mixed types
	var base_scene = load("res://Scenes/Zombies/zombie_base.tscn")
	if not base_scene: return

	var types := ["merchant", "scholar", "cultist", "escapee"]
	var count := randi_range(3, 5)
	var spawned_types: Array = []

	# Ensure at least one merchant and one scholar
	spawned_types.append("merchant")
	spawned_types.append("scholar")
	for i in range(count - 2):
		spawned_types.append(types.pick_random())

	for t in spawned_types:
		var npc := CharacterBody2D.new()
		npc.set_script(load("res://Scenes/Humans/wanderer_npc.gd"))
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(350.0, 900.0)
		npc.global_position = Vector2(cos(angle), sin(angle)) * dist
		add_child.call_deferred(npc)
		await get_tree().process_frame
		if is_instance_valid(npc) and npc.has_method("setup"):
			npc.setup(t)

func _on_map_ready() -> void:
	# Called after non-map1 scenes load — spawn wanderers there too
	await get_tree().process_frame
	_spawn_wanderers()

