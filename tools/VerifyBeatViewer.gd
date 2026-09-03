extends Node

## BeatViewer is the dev tool that plays authored beat clips straight from Settings, and its
## playback is a coroutine: _play_clip() awaits process_frame until the clip reports finished or a
## 10 s wall-clock cap expires, then runs a tail that hides preview_holder, clears _playing and
## unlocks the buttons.
##
## STOP frees the clip and unlocks the buttons immediately, but the coroutine keeps awaiting until
## it notices - one frame later, when queue_free() takes effect. Anything started inside that frame
## is running when the OLD coroutine's tail fires, and that tail hides the holder and unlocks the
## buttons under it: the new clip plays invisibly while the UI claims nothing is playing.
##
## The three claims below are the state a user can see: a clip on screen while playing, a clip
## still on screen after STOP-then-play, and a clean idle state once it ends.

const VIEWER := "res://scenes/ui/BeatViewer.tscn"

var _pass: int = 0
var _fail: int = 0

func _check(ok: bool, label: String, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [ok]   %s%s" % [label, "" if detail.is_empty() else "  " + detail])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [label, "" if detail.is_empty() else "  " + detail])

func _ready() -> void:
	await get_tree().process_frame
	print("\n=== VerifyBeatViewer ===")
	var packed: PackedScene = load(VIEWER)
	if packed == null:
		_check(false, "BeatViewer loads")
		get_tree().quit(1)
		return
	var v := packed.instantiate()
	add_child(v)
	await get_tree().process_frame

	# Pick the first listed game that actually has a win clip, the way a user would.
	var games: Array = v.get("_games")
	var pick: String = ""
	var pick_i: int = -1
	for i in range(games.size()):
		if String(v.call("_clip_path", String(games[i]), "WinOutro")) != "":
			pick = String(games[i])
			pick_i = i
			break
	_check(pick != "", "the viewer lists a game with an authored win clip", pick)
	if pick == "":
		get_tree().quit(1)
		return
	var holder: Control = v.get("preview_holder")
	v.get("game_list").call("select", pick_i)
	v.call("_on_game_selected", pick_i)

	# CLAIM 1 (control) - a plain playback puts a clip on screen and locks the UI.
	v.call("_play_clip", pick, "WinOutro", "play_win")
	await get_tree().process_frame
	_check(holder.get_child_count() == 1 and holder.visible and bool(v.get("_playing")),
		"a playing clip is on screen and the UI is locked",
		"children=%d visible=%s _playing=%s" % [holder.get_child_count(), holder.visible, v.get("_playing")])

	# CLAIM 2 - STOP, then start another clip in the SAME frame. The first coroutine is still
	# awaiting; its tail must not touch the second clip's state.
	v.call("_stop_preview")
	v.call("_play_clip", pick, "LoseOutro", "play_lose")
	var alive_after: int = 0
	var visible_after: bool = true
	var locked_after: bool = true
	# Three frames is past the point the stale coroutine notices its clip is gone and runs its tail.
	for _i in range(3):
		await get_tree().process_frame
		alive_after = holder.get_child_count()
		visible_after = visible_after and holder.visible
		locked_after = locked_after and bool(v.get("_playing"))
	_check(alive_after >= 1 and visible_after and locked_after,
		"a clip started right after STOP keeps playing and stays visible",
		"children=%d holder stayed visible=%s stayed locked=%s" % [alive_after, visible_after, locked_after])

	# CLAIM 3 - once that clip really ends, the viewer returns to a usable idle state.
	var t0: float = Time.get_ticks_msec() / 1000.0
	while bool(v.get("_playing")) and Time.get_ticks_msec() / 1000.0 - t0 < 15.0:
		await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not bool(v.get("_playing")) and not holder.visible and holder.get_child_count() == 0,
		"the viewer returns to idle after the clip ends",
		"_playing=%s visible=%s children=%d" % [v.get("_playing"), holder.visible, holder.get_child_count()])
	var stop_btn: Button = v.get("stop_button")
	var back_btn: Button = v.get("back_button")
	_check(stop_btn.disabled and not back_btn.disabled,
		"idle leaves STOP disabled and Back usable",
		"stop.disabled=%s back.disabled=%s" % [stop_btn.disabled, back_btn.disabled])

	v.queue_free()
	await get_tree().process_frame
	print("=== %d passed / %d failed ===" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
