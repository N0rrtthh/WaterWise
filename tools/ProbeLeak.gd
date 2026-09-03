extends Node

func _ready() -> void:
		await get_tree().process_frame
		var game: Node = load("res://scenes/minigames/FixLeak.tscn").instantiate()
		add_child(game)
		await get_tree().process_frame
		await get_tree().process_frame
		print("[P] class=", game.get_class(), " script=", game.get_script().resource_path)
		print("[P] 'waste_per_leak' in game -> ", ("waste_per_leak" in game))
		print("[P] game.get() -> ", game.get("waste_per_leak"))
		game.current_difficulty = "Easy"
		game._apply_difficulty_settings()
		print("[P] after apply: waste_per_leak=", game.waste_per_leak, " num_leaks=", game.num_leaks, " dur=", game.game_duration, " thresh=", game.max_water_wasted, " drip_speed=", game.drip_speed)
		print("[P] difficulty_settings=", game.difficulty_settings)
		# now force a round and inspect leaks
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		Input.parse_input_event(click)
		var waited: float = 0.0
		while not game.game_active and waited < 8.0:
				await get_tree().process_frame
				waited += get_process_delta_time()
		var rel := InputEventMouseButton.new()
		rel.button_index = MOUSE_BUTTON_LEFT
		rel.pressed = false
		Input.parse_input_event(rel)
		await get_tree().process_frame
		print("[P] game_active=", game.game_active, " leaks=", game.leaks.size())
		if game.leaks.size() > 0:
				var l: Node = game.leaks[0]
				print("[P] leaks[0]=", l, " name=", l.name, " metas=", l.get_meta_list())
				print("[P] runtime waste_per_leak=", game.waste_per_leak, " num_leaks=", game.num_leaks)
		print("[P] done")
		get_tree().quit(0)
