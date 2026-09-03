extends Node

## Integration gate for the DWTD loop wiring (not just the clip data).
##
## Run:
##   godot --path . res://tools/VerifyCartoonLoop.tscn
##
## Checks, for a sample of real minigame scenes:
##   1. the scene's script key resolves to a CartoonScenarios entry
##   2. _play_cartoon_outro() actually runs and reports true for win and lose
##   3. no CartoonStage node survives afterwards (no leak into the score page)
##   4. _get_cartoon_speed() returns a usable speed dictionary
##
## Exits 0 on success, 1 on any failure, so it can gate a build.

const SAMPLE: Array[String] = [
	"CatchTheRain",
	"TurnOffTap",
	"RiceWashRescue",
	"BucketBrigade",
	"QuickShower",
	"SpotTheSpeck",
]

var _failures: Array[String] = []
var _checked: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("▶ Verifying cartoon loop wiring for %d minigames" % SAMPLE.size())

	for game_name in SAMPLE:
		await _check_game(game_name)

	print("— checked %d outro plays" % _checked)
	if _failures.is_empty():
		print("✅ VerifyCartoonLoop: all checks passed")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("❌ %s" % f)
		printerr("❌ VerifyCartoonLoop: %d failure(s)" % _failures.size())
		get_tree().quit(1)

func _check_game(game_name: String) -> void:
	var path := "res://scenes/minigames/%s.tscn" % game_name
	if not ResourceLoader.exists(path):
		_failures.append("%s: scene missing at %s" % [game_name, path])
		return

	var packed := load(path) as PackedScene
	if packed == null:
		_failures.append("%s: could not load PackedScene" % game_name)
		return

	var game := packed.instantiate()
	add_child(game)
	await get_tree().process_frame

	if not game.has_method("_play_cartoon_outro"):
		_failures.append("%s: no _play_cartoon_outro (not a MiniGameBase?)" % game_name)
		# Detach and spend a frame before freeing, so the parked _wait_for_input() coroutine can return.
		remove_child(game)
		await get_tree().process_frame
		game.free()
		return

	# The cause side keys off the pending name, the effect side off the script
	# name. Both must resolve or one half of the loop silently falls back.
	var key: String = game._get_minigame_key()
	if not CartoonScenarios.has_scenario(key):
		_failures.append(
			"%s: effect key '%s' has no scenario" % [game_name, key]
		)
	if not CartoonScenarios.has_scenario(game_name):
		_failures.append(
			"%s: cause key '%s' has no scenario" % [game_name, game_name]
		)

	var speed: Dictionary = game._get_cartoon_speed()
	if not speed.has("speed") or float(speed["speed"]) <= 0.0:
		_failures.append("%s: bad _get_cartoon_speed() -> %s" % [game_name, speed])

	# Stop gameplay so timers/spawners don't fight the cutscene during the test.
	game.game_active = false

	for success in [true, false]:
		var label := "win" if success else "lose"
		var played: bool = await game._play_cartoon_outro(success)
		_checked += 1
		if not played:
			_failures.append("%s/%s: _play_cartoon_outro returned false" % [game_name, label])
		if _find_stage(game) != null:
			_failures.append("%s/%s: CartoonStage still in tree after outro" % [game_name, label])

	# Detach, let the parked coroutine notice, then free.
	#
	# The round is still blocked on the instruction overlay here, so
	# MiniGameBase._wait_for_input() is parked on `await get_tree().process_frame`. Freeing
	# the node destroys the tree connection that would have resumed it, and the orphaned
	# GDScriptFunctionState is never released - one per game instantiated, named by
	# `Orphan StringName: _wait_for_input` in a --verbose exit dump. Detaching first and
	# spending one frame lets the loop resume, see is_inside_tree() go false and return.
	remove_child(game)
	await get_tree().process_frame
	game.free()

## Depth-first search for a surviving CartoonStage under `root`.
func _find_stage(root: Node) -> Node:
	for child in root.get_children():
		if child is CartoonStage:
			return child
		var found := _find_stage(child)
		if found != null:
			return found
	return null
