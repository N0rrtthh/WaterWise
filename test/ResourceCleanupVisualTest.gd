extends Control

## Visual test for resource cleanup system
##
## This test demonstrates:
## - Multiple cutscenes playing in sequence
## - Memory usage monitoring
## - Object pool statistics
## - Cache management

@onready var memory_label: Label = $MemoryLabel
@onready var pool_label: Label = $PoolLabel
@onready var cutscene_container: Control = $CutsceneContainer

var cutscene_count: int = 0
var test_running: bool = false


func _ready() -> void:
	# Create UI
	_setup_ui()
	
	# Start test
	_start_test()


func _setup_ui() -> void:
	# Memory label
	if not memory_label:
		memory_label = Label.new()
		memory_label.name = "MemoryLabel"
		memory_label.position = Vector2(10, 10)
		add_child(memory_label)
	
	# Pool label
	if not pool_label:
		pool_label = Label.new()
		pool_label.name = "PoolLabel"
		pool_label.position = Vector2(10, 40)
		add_child(pool_label)
	
	# Cutscene container
	if not cutscene_container:
		cutscene_container = Control.new()
		cutscene_container.name = "CutsceneContainer"
		cutscene_container.anchors_preset = Control.PRESET_FULL_RECT
		add_child(cutscene_container)


func _start_test() -> void:
	test_running = true
	print("=== Resource Cleanup Visual Test ===")
	print("Playing 10 cutscenes in sequence...")
	print("Watch memory and pool stats")
	
	# Play multiple cutscenes
	for i in range(10):
		await _play_test_cutscene(i)
		await get_tree().create_timer(0.5).timeout
	
	print("\n=== Test Complete ===")
	print("Final memory stats:")
	_print_memory_stats()
	
	test_running = false


func _play_test_cutscene(index: int) -> void:
	cutscene_count += 1
	print("\n--- Cutscene %d ---" % cutscene_count)
	
	# Create cutscene player
	var player = AnimatedCutscenePlayer.new()
	cutscene_container.add_child(player)
	
	# Print stats before
	print("Before:")
	_print_memory_stats()
	
	# Play cutscene (will use default if minigame doesn't exist)
	var cutscene_type = [
		CutsceneTypes.CutsceneType.WIN,
		CutsceneTypes.CutsceneType.FAIL,
		CutsceneTypes.CutsceneType.INTRO
	][index % 3]
	
	await player.play_cutscene("TestMinigame", cutscene_type)
	
	# Print stats after
	print("After:")
	_print_memory_stats()
	
	# Clean up player
	player.queue_free()


func _print_memory_stats() -> void:
	var stats = AnimatedCutscenePlayer.get_memory_stats()
	print("  Memory: %.2f MB (%.1f%%)" % [
		stats["static_memory_mb"],
		stats["memory_ratio"] * 100
	])
	print("  Cached: %d animations, %d textures, %d particle scenes" % [
		stats["cached_animations"],
		stats["cached_textures"],
		stats["cached_particle_scenes"]
	])
	print("  Pooled particles: %d" % stats["pooled_particles"])


func _process(_delta: float) -> void:
	if not test_running:
		return
	
	# Update UI labels
	var stats = AnimatedCutscenePlayer.get_memory_stats()
	
	memory_label.text = "Memory: %.2f MB (%.1f%%)" % [
		stats["static_memory_mb"],
		stats["memory_ratio"] * 100
	]
	
	pool_label.text = "Pooled Particles: %d | Cached: %d anims, %d textures" % [
		stats["pooled_particles"],
		stats["cached_animations"],
		stats["cached_textures"]
	]


func _input(event: InputEvent) -> void:
	# Press SPACE to manually clear caches
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("\n=== Manual Cache Clear ===")
		print("Before:")
		_print_memory_stats()
		
		AnimatedCutscenePlayer.clear_caches()
		
		print("After:")
		_print_memory_stats()
	
	# Press ESCAPE to quit
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
