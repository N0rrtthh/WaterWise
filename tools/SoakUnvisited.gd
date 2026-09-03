extends Node

## ═══════════════════════════════════════════════════════════════════
## SOAK: THE MINIGAMES THE FULL-POOL SOAK NEVER REACHED
## ═══════════════════════════════════════════════════════════════════
## The 480s full-pool soak reached 18 of the 24 singleplayer games across 24
## completions. Random selection from a 24-game bag simply never got to the rest
## inside the run, so those games had never had a round played end to end — no
## _process, no input handling, no end_game, no tally, no transition, and
## therefore no chance for a script error in any of them to be seen. That is how
## ScrubToSave's phantom-success corruption stayed hidden until coverage opened
## up: it was found the very first time the game was reached.
##
## GreywaterSorter is already covered by SoakV2Games; RainwaterHarvesting is not
## in ALL_SINGLEPLAYER_MINIGAMES at all (it is a multiplayer-only game), so the
## remaining gap is exactly the five pinned below.
##
## Same mechanism as SoakV2Games: pin GameManager.available_minigames so the
## random bag can only draw from this list, then let the real session flow drive
## real navigation. Nothing here stubs or shortcuts the game.
##
## Usage:
##   godot --headless --path <project> res://tools/SoakUnvisited.tscn
## ═══════════════════════════════════════════════════════════════════

const SOAK_SECONDS: float = 300.0
const UNVISITED_GAMES: PackedStringArray = [
	"DropletDash",
	"ThirstyPlant",
	"ToiletTankFix",
	"TracePipePath",
	"VegetableBath"
]


func _ready() -> void:
	print("[SOAKUNVISITED] boot")
	await get_tree().process_frame
	await get_tree().process_frame

	var apm := get_node_or_null("/root/AutoPlayManager")
	if apm and apm.has_method("set_auto_play_enabled"):
		if apm.has_method("set_auto_play_duration"):
			apm.set_auto_play_duration(SOAK_SECONDS / 60.0 + 1.0)
		# persist=false: a run killed by `timeout` never reaches the restore below, and a
		# persisted flag then hijacks the next process (see AutoPlayManager:104).
		apm.set_auto_play_enabled(true, false)
		print("[SOAKUNVISITED] autoplay on")
	else:
		push_warning("[SOAKUNVISITED] AutoPlayManager unavailable")

	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("start_session"):
		# Pin BEFORE start_session and AGAIN after: start_session re-runs
		# _refresh_available_minigames() from save data, which would wipe the pin.
		_pin_pool(gm)
		gm.start_session(0)  # GameMode.SINGLE_PLAYER
		_pin_pool(gm)
		if gm.has_method("_rebuild_minigame_random_bag"):
			gm._rebuild_minigame_random_bag()
		print("[SOAKUNVISITED] pool pinned to: ", gm.available_minigames)
		print("[SOAKUNVISITED] session started")
	else:
		push_error("[SOAKUNVISITED] GameManager unavailable")

	# The lambda that used to sit here was owned by THIS node, and this node is the
	# current scene -- so the session's first change_scene_to_file() freed it and
	# silently dropped the connection. The shutdown never fired: the run had to be
	# killed from outside, and an externally killed soak reports nothing at all. A child
	# of /root is not part of the current scene, so the Callable stays valid.
	var quitter := SoakQuitter.new()
	quitter.name = "SoakQuitter"
	quitter.apm = apm
	get_tree().root.add_child(quitter)
	get_tree().create_timer(SOAK_SECONDS).timeout.connect(quitter.finish)


func _pin_pool(gm: Node) -> void:
	gm.available_minigames.clear()
	for game_id in UNVISITED_GAMES:
		gm.available_minigames.append(game_id)


## Outlives the scene swap so the soak can end itself and say so.
class SoakQuitter extends Node:
	var apm: Node = null

	func finish() -> void:
		# AutoPlayManager PERSISTS its enabled flag into the player's save, so it has to
		# go back off before quit or the next real play session has the AI at the wheel.
		if apm and apm.has_method("set_auto_play_enabled"):
			apm.set_auto_play_enabled(false)
		print("[SOAKUNVISITED] done")
		get_tree().quit(0)
