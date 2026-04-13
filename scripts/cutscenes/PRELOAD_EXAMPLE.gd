extends Node

## Example script demonstrating asset preloading for animated cutscenes
## This script can be attached to a loading screen or game initialization node

# List of all minigames in the game
const MINIGAMES = [
	"CatchTheRain",
	"FixLeak",
	"WaterPlant",
	"ThirstyPlant",
	"FilterBuilder",
	"RiceWashRescue",
	"VegetableBath",
	"BucketBrigade",
	"QuickShower",
	"WringItOut"
]

# Preload progress signal
signal preload_progress(current: int, total: int, minigame_key: String)
signal preload_complete()


## Preload all cutscene assets during game initialization
func preload_all_cutscenes() -> void:
	print("[PreloadExample] Starting cutscene asset preloading...")
	var start_time = Time.get_ticks_msec()
	
	# Create a single cutscene player for preloading
	var cutscene_player = AnimatedCutscenePlayer.new()
	
	# Preload texture atlas first (only once)
	WaterDropletCharacter.preload_atlas()
	print("[PreloadExample] Texture atlas preloaded")
	
	# Preload each minigame
	var total = MINIGAMES.size()
	for i in range(total):
		var minigame_key = MINIGAMES[i]
		cutscene_player.preload_cutscene(minigame_key)
		
		# Emit progress signal
		preload_progress.emit(i + 1, total, minigame_key)
		print("[PreloadExample] Preloaded: ", minigame_key, " (", i + 1, "/", total, ")")
		
		# Yield to prevent frame drops
		await get_tree().process_frame
	
	# Clean up
	cutscene_player.queue_free()
	
	var elapsed = Time.get_ticks_msec() - start_time
	print("[PreloadExample] Preloading complete in ", elapsed, "ms")
	preload_complete.emit()


## Preload only the next few minigames (adaptive loading)
## Useful for memory-constrained devices
func preload_next_minigames(current_index: int, lookahead: int = 3) -> void:
	print("[PreloadExample] Preloading next ", lookahead, " minigames...")
	
	var cutscene_player = AnimatedCutscenePlayer.new()
	
	for i in range(lookahead):
		var index = (current_index + i) % MINIGAMES.size()
		var minigame_key = MINIGAMES[index]
		cutscene_player.preload_cutscene(minigame_key)
		print("[PreloadExample] Preloaded: ", minigame_key)
		
		# Yield to prevent frame drops
		await get_tree().process_frame
	
	cutscene_player.queue_free()
	print("[PreloadExample] Adaptive preloading complete")


## Preload a specific minigame
func preload_minigame(minigame_key: String) -> void:
	print("[PreloadExample] Preloading minigame: ", minigame_key)
	var start_time = Time.get_ticks_msec()
	
	var cutscene_player = AnimatedCutscenePlayer.new()
	cutscene_player.preload_cutscene(minigame_key)
	cutscene_player.queue_free()
	
	var elapsed = Time.get_ticks_msec() - start_time
	print("[PreloadExample] Preloaded ", minigame_key, " in ", elapsed, "ms")


## Example: Preload during loading screen
func _ready() -> void:
	# Option 1: Preload all at once (best for desktop/high-end devices)
	# await preload_all_cutscenes()
	
	# Option 2: Preload adaptively (best for mobile/low-end devices)
	# await preload_next_minigames(0, 3)
	
	# Option 3: Preload specific minigame
	# preload_minigame("CatchTheRain")
	
	pass


## Example: Connect to loading screen UI
func connect_to_loading_screen(loading_screen: Node) -> void:
	# Connect progress signal to update loading bar
	preload_progress.connect(func(current, total, minigame_key):
		var progress = float(current) / float(total)
		if loading_screen.has_method("update_progress"):
			loading_screen.update_progress(progress, "Loading " + minigame_key + "...")
	)
	
	# Connect complete signal to transition to game
	preload_complete.connect(func():
		if loading_screen.has_method("on_loading_complete"):
			loading_screen.on_loading_complete()
	)


## Example: Measure preload performance
func measure_preload_performance() -> Dictionary:
	var results = {}
	
	for minigame_key in MINIGAMES:
		var start_time = Time.get_ticks_msec()
		
		var cutscene_player = AnimatedCutscenePlayer.new()
		cutscene_player.preload_cutscene(minigame_key)
		cutscene_player.queue_free()
		
		var elapsed = Time.get_ticks_msec() - start_time
		results[minigame_key] = elapsed
		
		await get_tree().process_frame
	
	# Print results
	print("[PreloadExample] Performance Results:")
	var total_time = 0
	for minigame_key in results:
		var time = results[minigame_key]
		total_time += time
		print("  ", minigame_key, ": ", time, "ms")
	
	print("  Total: ", total_time, "ms")
	print("  Average: ", total_time / MINIGAMES.size(), "ms")
	
	return results


## Example: Check if preloading is needed
func should_preload() -> bool:
	# Check if running on mobile
	var is_mobile = OS.get_name() in ["Android", "iOS"]
	
	# Check available memory
	var available_memory = OS.get_static_memory_usage()
	var memory_threshold = 100 * 1024 * 1024  # 100 MB
	
	# Preload if not on mobile or if memory is sufficient
	return not is_mobile or available_memory < memory_threshold
