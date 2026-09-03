extends Node

## Focused soak for the MicrogameShell v2 ports (Phase 3).
##
## Same as AutoPlayHarness but pins GameManager.available_minigames to the
## four v2 games so the run PROVABLY exercises BucketBrigade, CatchTheRain,
## FixLeak and GreywaterSorter (the full-pool soak may never reach them in time).
##
## CatchTheRain joined this list when its scene was repointed at CatchTheRainV2;
## the pool had still been the original three, so the one shell game with a
## drag-driven paddle had no pinned coverage.
##
## Usage:
##   godot --headless --path E:\waterwise res://tools/SoakV2Games.tscn

const SOAK_SECONDS: float = 210.0
const V2_GAMES: PackedStringArray = [
	"BucketBrigade", "CatchTheRain", "FixLeak", "GreywaterSorter"
]


func _ready() -> void:
	print("[SOAKV2] boot")
	await get_tree().process_frame
	await get_tree().process_frame

	var apm := get_node_or_null("/root/AutoPlayManager")
	if apm and apm.has_method("set_auto_play_enabled"):
		if apm.has_method("set_auto_play_duration"):
			apm.set_auto_play_duration(SOAK_SECONDS / 60.0 + 1.0)
		# persist=false: a run killed by `timeout` never reaches the restore below, and a
		# persisted flag then hijacks the next process (see AutoPlayManager:104).
		apm.set_auto_play_enabled(true, false)
		print("[SOAKV2] autoplay on")
	else:
		push_warning("[SOAKV2] AutoPlayManager unavailable")

	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("start_session"):
		# Pin BEFORE start_session, then pin AGAIN after it returns —
		# start_session re-runs _refresh_available_minigames() from save data
		# (GameManager.gd:989), which would otherwise wipe the pin.
		gm.available_minigames.clear()
		for game_id in V2_GAMES:
			gm.available_minigames.append(game_id)
		gm.start_session(0)  # GameMode.SINGLE_PLAYER
		gm.available_minigames.clear()
		for game_id in V2_GAMES:
			gm.available_minigames.append(game_id)
		if gm.has_method("_rebuild_minigame_random_bag"):
			gm._rebuild_minigame_random_bag()
		print("[SOAKV2] pool pinned to: ", gm.available_minigames)
		print("[SOAKV2] session started")
	else:
		push_error("[SOAKV2] GameManager unavailable")

	# The session flow REPLACES the current scene, which frees this harness
	# node and silently kills any awaited coroutine — so do NOT await the
	# quit timer. Attach the shutdown to the SceneTreeTimer itself so it
	# fires even after this node is freed. AutoPlayManager PERSISTS the
	# auto_play_enabled flag into the player's save; leaving it on hijacks
	# real play sessions (the AI plays every minigame and the human's input
	# appears dead), so always switch it off before quitting.
	var tree := get_tree()
	var shutdown := func() -> void:
		if apm and apm.has_method("set_auto_play_enabled"):
			apm.set_auto_play_enabled(false)
		print("[SOAKV2] done")
		tree.quit(0)
	tree.create_timer(SOAK_SECONDS).timeout.connect(shutdown)
