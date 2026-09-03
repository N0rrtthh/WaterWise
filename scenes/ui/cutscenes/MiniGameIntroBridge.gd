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

	# Preferred path: "Dumb Ways to Die"-style CAUSE clip — an animated scene
	# showing *why* this round matters, instead of a static title card.
	# On weak devices it plays compressed rather than being cut, because the
	# cause clip is the educational payload of the loop.
	#
	# Tier 1: authored 4-beat clips (MicrogameIntroBase subclasses) at
	# res://scenes/ui/cutscenes/beats/<Game>Intro.tscn.
	var beat_path := "res://scenes/ui/cutscenes/beats/%sIntro.tscn" % game_name
	if ResourceLoader.exists(beat_path):
		var clip = (load(beat_path) as PackedScene).instantiate()
		if "speed_scale" in clip:
			# Compression from a weak device and compression the player asked for are
			# separate reasons and multiply: 1.7 x 3.0 on a low-end phone with reduced
			# motion on. speed_scale is a divisor inside the clip.
			clip.speed_scale = (1.7 if is_low_end else 1.0) * _motion_speed()
		host.add_child(clip)
		await clip.play_cutscene()
		clip.queue_free()
		await get_tree().process_frame
		await _launch(game_path)
		return

	if CartoonScenarios.has_scenario(game_name):
		var stage := CartoonStage.new()
		stage.configure(
			CartoonStage.Kind.CAUSE,
			game_name,
			{"speed": (1.7 if is_low_end else 1.0) * _motion_speed()}
		)
		host.add_child(stage)
		await stage.play_cutscene()
		stage.queue_free()
		await get_tree().process_frame
		await _launch(game_path)
		return

	var scene := null if is_low_end else _resolve_intro_scene(game_name)

	if scene:
		var intro = scene.instantiate()
		host.add_child(intro)
		if intro.has_method("configure"):
			intro.configure(
				game_name,
				"Get ready...",
				_with_motion_speed(_get_intro_anim_profile(game_name))
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

	await _launch(game_path)

## Shared tail for every intro path (cartoon clip, legacy intro, or no intro).
func _launch(game_path: String) -> void:
	# Wait for GameManager's previous fade-in to settle before starting the next
	# transition (transition_to_scene guards against re-entry with
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

## AccessibilityManager.get_animation_speed(), guarded, never zero. Every cutscene in
## this bridge divides its durations by a speed number, so returning 1.0 when the
## accessibility layer is unavailable leaves the pacing exactly as authored.
##
## Duplicated deliberately from MiniGameBase rather than shared through a new autoload:
## the bridge is a standalone scene that runs when no minigame exists yet, so it cannot
## reach MiniGameBase's copy, and one guarded read is smaller than a new global.
func _motion_speed() -> float:
	if AccessibilityManager and AccessibilityManager.has_method("get_animation_speed"):
		var reported := float(AccessibilityManager.get_animation_speed())
		if reported > 0.0:
			return reported
	return 1.0

## Fold the reduced-motion factor into an authored intro profile, leaving the per-game
## pacing it carries intact. Copied, not mutated, so a future cached profile cannot
## accumulate the multiplier once per round.
func _with_motion_speed(profile: Dictionary) -> Dictionary:
	var out: Dictionary = profile.duplicate()
	out["speed"] = float(out.get("speed", 1.0)) * _motion_speed()
	return out
