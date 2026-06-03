extends Node2D

func _ready() -> void:
	# If a custom map is selected, load it and replace Map1
	if Globals.selected_map != "res://Scenes/Locations/map_1.tscn":
		var map_node := get_node_or_null("Map1")
		if map_node:
			var parent := map_node.get_parent()
			var idx := map_node.get_index()
			map_node.free() # Free immediately to avoid duplicate name search
			
			var custom_map_scene = load(Globals.selected_map)
			if custom_map_scene:
				var custom_map = custom_map_scene.instantiate() as Node2D
				custom_map.name = "Map1" # Keep same name for wave_manager.gd compatibility
				parent.add_child(custom_map)
				parent.move_child(custom_map, idx)
