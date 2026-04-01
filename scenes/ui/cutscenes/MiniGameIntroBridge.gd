extends Control

@onready var host: Control = $Root

func _ready() -> void:
	await get_tree().process_frame
	if not GameManager:
		get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")
		return

	var game_name := GameManager.pending_next_minigame_name
	if game_name.is_empty():
		GameManager.start_next_minigame()
		return

	var scene := _resolve_intro_scene(game_name)
	if scene:
		var intro = scene.instantiate()
		host.add_child(intro)
		if intro.has_method("configure"):
			intro.configure(
				game_name,
				"Get ready...",
				_get_intro_anim_profile(game_name)
			)
		if intro.has_method("play_cutscene"):
			await intro.play_cutscene()
		else:
			await get_tree().create_timer(1.1).timeout
		intro.queue_free()
	else:
		await get_tree().create_timer(0.45).timeout

	GameManager.launch_pending_minigame()

func _resolve_intro_scene(game_name: String) -> PackedScene:
	var specific_path := "res://scenes/ui/cutscenes/intro/%sIntro.tscn" % game_name
	var generic_path := "res://scenes/ui/cutscenes/MiniGameIntroCutscene.tscn"

	if ResourceLoader.exists(specific_path):
		return load(specific_path) as PackedScene
	if ResourceLoader.exists(generic_path):
		return load(generic_path) as PackedScene
	return null

func _get_intro_anim_profile(game_name: String) -> Dictionary:
	if (
		"Rain" in game_name
		or "Leak" in game_name
		or "Tap" in game_name
		or "Pipe" in game_name
	):
		return {"speed": 1.12, "distance": 1.18, "pop": 1.05}

	if (
		"Plant" in game_name
		or "Scrub" in game_name
		or "Filter" in game_name
		or "Vegetable" in game_name
	):
		return {"speed": 0.95, "distance": 0.9, "pop": 1.2}

	return {"speed": 1.0, "distance": 1.0, "pop": 1.0}
