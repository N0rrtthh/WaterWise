extends Control

@onready var host: Control = $Root

## If the device's average FPS (after warmup) is below this value,
## skip the procedural intro cutscene entirely to avoid a 1-2 second freeze
## on weak SoCs (e.g. Snapdragon 425 / Cortex-A53 @ 1.4GHz).
const LOW_END_FPS_THRESHOLD: float = 27.0

func _ready() -> void:
	await get_tree().process_frame
	if not GameManager:
		get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")
		return

	var game_name: String = GameManager.pending_next_minigame_name
	if game_name.is_empty():
		GameManager.start_next_minigame()
		return

	# Kick off a background load immediately — the OS warms the file cache
	# while the intro animation / 0.3-second delay runs.
	var game_path := "res://scenes/minigames/%s.tscn" % game_name
	if ResourceLoader.exists(game_path):
		ResourceLoader.load_threaded_request(game_path)

	# Detect low-end device: skip intro if fps_avg is already struggling.
	var is_low_end := _is_low_end_device()
	var scene := null if is_low_end else _resolve_intro_scene(game_name)

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
		# Low-end or no scene: show a brief 0.3s gap so the scene transition
		# doesn't feel instant, then launch immediately.
		await get_tree().create_timer(0.3).timeout

	# Wait for GameManager's previous fade-in to settle before starting
	# the next transition (transition_to_scene guards against re-entry with
	# _is_transitioning, so we must wait for it to become false first).
	var safety_iters := 0
	while GameManager.is_scene_transitioning() and safety_iters < 90:
		await get_tree().process_frame
		safety_iters += 1

	# Clear the pending name now; if anything calls launch_pending_minigame
	# as a fallback it won't double-launch.
	GameManager.pending_next_minigame_name = ""

	# Use GameManager's overlay transition — hides the scene-instantiation
	# freeze (all _ready() calls) behind a smooth fade so the user sees a
	# black wipe instead of a randomly frozen screen.
	# The load_threaded_request started above has almost certainly finished
	# during the intro/delay, so transition_to_scene's internal request will
	# find the resource already in the thread queue (THREAD_LOAD_LOADED) and
	# retrieve it without hitting the disk again.
	if ResourceLoader.exists(game_path):
		GameManager.transition_to_scene(game_path, 0.3)
	else:
		push_warning("MiniGameIntroBridge: game scene not found: %s" % game_path)
		GameManager.start_next_minigame()

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

func _is_low_end_device() -> bool:
	# Check profiler's running fps average after warmup.
	# If the device can't hit 27fps on the main menu it won't handle
	# an additional procedural cutscene scene (15+ Polygon2D nodes).
	if PerformanceProfiler and PerformanceProfiler.session_elapsed_sec > STARTUP_WARMUP_SEC_CHECK:
		if PerformanceProfiler.fps_avg < LOW_END_FPS_THRESHOLD:
			print("⚡ MiniGameIntroBridge: low-end device (fps_avg=%.1f < %.0f), skipping intro" % [
				PerformanceProfiler.fps_avg, LOW_END_FPS_THRESHOLD
			])
			return true
	return false

const STARTUP_WARMUP_SEC_CHECK: float = 5.0
