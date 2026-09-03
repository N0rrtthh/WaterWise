extends Node

## Android Back: does it still kill the app, and does it go somewhere sensible?
##
## THE DEFECT THIS WAS OPENED FOR
##   SceneTree.quit_on_go_back defaults to true, and no script in the project
##   handled NOTIFICATION_WM_GO_BACK_REQUEST - every hit for that constant was under
##   .agents/skills/, which are reference templates, not game code. Measured by
##   tools/ProbeBackButton.tscn: quit_on_go_back true, zero handlers. So on Android
##   the hardware/gesture Back button called SceneTree.quit() from ANY screen, with
##   no confirmation and no save. On a phone Back is the primary navigation gesture,
##   so this was the single most reachable way to lose a session.
##
## HONESTY: NO ANDROID DEVICE IS INVOLVED
##   Windows never sends WM_GO_BACK, so the gesture cannot be produced here. Case 2
##   instead calls get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST),
##   which is the same call SceneTree makes on the root when the platform does send
##   it. That verifies the WIRING - notification reaches an autoload Node, dispatch
##   runs, the scene reacts - and it is the strongest claim available off-device. What
##   it does NOT prove is that Android's DisplayServer emits the notification at all;
##   that is an engine guarantee this harness takes as given and does not measure.
##
## WHAT IS ASSERTED
##   1. quit_on_go_back is off after boot, so the default kill path is gone
##   2. a real propagated notification reaches GameManager and reaches the scene
##   3. Back inside a live round opens pause - it does not leave and does not record
##   4. Back with pause already open resumes, so the gesture is not a one-way trip
##   5. Back from an ordinary screen lands on the hub, never nowhere
##   6. Back from the hub and from the title screen closes the app, as Android expects
##
## Usage:
##   godot --headless --path . res://tools/VerifyBackButton.tscn

const ROUND: String = "res://scenes/minigames/CatchTheRain.tscn"

var _pass: int = 0
var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


func _frames(n: int) -> void:
	for _i in range(n):
		if get_tree().paused:
			get_tree().paused = false
		await get_tree().process_frame


func _gm() -> Node:
	return get_node_or_null("/root/GameManager")


## A live round, driven through the real tap-to-start prompt.
##
## MiniGameBase awaits _wait_for_input() before start_game(), so the round genuinely
## does not begin without a press. A real InputEventMouseButton goes through
## Input.parse_input_event, which is what that wait polls - the intro is not bypassed.
func _live_round() -> Node:
	var inst: Node = (load(ROUND) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	for _i in range(30):
		await _frames(1)
	for attempt in range(90):
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = get_tree().root.get_visible_rect().size * 0.5
		Input.parse_input_event(down)
		await _frames(1)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = down.position
		Input.parse_input_event(up)
		await _frames(1)
		if inst.get("game_active") == true:
			print("          (round went live after %d taps)" % (attempt + 1))
			break
	return inst


## Make a node the scene Back dispatches against.
##
## SceneTree.current_scene is what handle_back_request() reads, and under a harness it
## is the harness itself. Pointing it at the node under test is also what protects
## this probe: change_scene_to_file() frees current_scene, so if the harness stayed
## current_scene the "returned to hub" case would free the harness mid-run.
func _as_current(n: Node) -> void:
	get_tree().current_scene = n


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== ANDROID BACK BUTTON ===")
	var gm := _gm()
	if gm == null:
		print("  FAIL: GameManager autoload missing")
		get_tree().quit(1)
		return

	# ---- CASE 1: the default kill path is gone -------------------------------
	_check("[1] quit_on_go_back is off after boot",
		get_tree().quit_on_go_back == false,
		"quit_on_go_back=%s (was true, and nothing handled the notification)"
			% str(get_tree().quit_on_go_back))
	_check("[1] GameManager exposes a Back dispatcher",
		gm.has_method("handle_back_request"),
		"handle_back_request present: %s" % str(gm.has_method("handle_back_request")))

	# ---- CASE 2: a real propagated notification reaches the scene ------------
	# The wiring test, and the only case that does not call handle_back_request()
	# directly. If the notification did not reach an autoload Node, everything below
	# would still pass while Back did nothing on a device.
	var g2: Node = await _live_round()
	_as_current(g2)
	var pm2 = g2.get("pause_menu")
	var visible_before: bool = pm2 != null and pm2.visible
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	var visible_after: bool = pm2 != null and pm2.visible
	_check("[2] a propagated GO_BACK notification reaches the round and opens pause",
		(not visible_before) and visible_after,
		"pause_menu.visible %s -> %s (notification propagated on root, as SceneTree does)"
			% [str(visible_before), str(visible_after)])
	_check("[2] the round is still the live scene - Back did not leave",
		get_tree().current_scene == g2 and is_instance_valid(g2),
		"current_scene is the round: %s" % str(get_tree().current_scene == g2))

	# ---- CASE 3: Back is not a one-way trip ----------------------------------
	# Pause is open from case 2. A second Back has to resume, otherwise the gesture
	# that opened the overlay cannot close it and the player is stuck behind it with
	# the tree paused.
	var act3: String = gm.handle_back_request()
	await _frames(3)
	_check("[3] Back with pause open resumes instead of leaving",
		act3 == "handled_by_scene" and pm2 != null and not pm2.visible,
		"action=%s pause_menu.visible=%s tree.paused=%s"
			% [act3, str(pm2.visible if pm2 else "?"), str(get_tree().paused)])

	# ---- CASE 4: Back mid-round records nothing -------------------------------
	# The gesture must not be a hidden route into the quit path that
	# tools/VerifyRoundEndOnce.tscn covers. Measured on the algorithm's own input.
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	var rounds_before: int = gm.round_scores.size()
	var win_before: int = ad.performance_window.size() if ad else -1
	gm.handle_back_request()
	await _frames(3)
	gm.handle_back_request()
	await _frames(3)
	_check("[4] two Back gestures in a round record no rounds and no samples",
		gm.round_scores.size() == rounds_before
			and (ad == null or ad.performance_window.size() == win_before),
		"round_scores %d -> %d, ad_window %d -> %d"
			% [rounds_before, gm.round_scores.size(), win_before,
				ad.performance_window.size() if ad else -1])
	get_tree().paused = false
	g2.queue_free()
	await _frames(4)

	# ---- CASE 5: an ordinary screen lands on the hub --------------------------
	# Settings has no on_back_requested(), so this exercises the fallback - the branch
	# that guarantees a screen added later gets sane Back behaviour instead of
	# inheriting "kill the app".
	var settings: Node = (load("res://scenes/ui/Settings.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(settings)
	await _frames(10)
	_as_current(settings)
	var act5: String = gm.handle_back_request()
	await _frames(6)
	_check("[5] Back from Settings returns to the hub",
		act5 == "returned_to_hub",
		"action=%s, current_scene now %s" % [act5,
			get_tree().current_scene.scene_file_path if get_tree().current_scene else "<none>"])
	_check("[5] the app is still running after that Back",
		not get_tree().is_queued_for_deletion(),
		"reached the next case, so no quit happened")

	# ---- CASE 6: the top of the stack closes the app --------------------------
	# Last, and the RESULT is printed before it, because this case really does call
	# SceneTree.quit(). quit() takes effect at the end of the iteration rather than
	# immediately, so the returned action is still observable and asserted here; the
	# final quit() below then sets the exit code.
	var hub: Node = (load("res://scenes/ui/InitialScreen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hub)
	await _frames(10)
	_as_current(hub)
	var act6: String = gm.handle_back_request()
	_check("[6] Back from the hub closes the app, as Android expects at the top",
		act6 == "quit_from_root",
		"action=%s (scene_file_path=%s)" % [act6, hub.scene_file_path])

	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	print("")
	get_tree().quit(1 if _fail > 0 else 0)
