extends Node

## ═══════════════════════════════════════════════════════════════════════════════
## VerifyMPBucketLayout — steering and playfield bounds of MP_CatchRainAquarium
## ═══════════════════════════════════════════════════════════════════════════════
## This game is P1 of the shipping `rain_aquarium` level set, and it used to steer its bucket by
## polling get_global_mouse_position() with the playfield hardcoded to a 1152x648 authoring
## viewport (bucket at x=576, clamp 60..1092, spawn 100..1052, miss line y>700) while the project
## ships 1920x1080 with stretch/aspect=expand and the scene's Camera2D sits at (576, 324).
##
## Two consequences, both measured here:
##   - the emulated mouse reads (0, 0) until the first tap on a touch build, so the poll clamped
##     the bucket to the far-left edge from frame one: every opening drop was a loss by
##     construction, and the player never touched the screen to cause it;
##   - drops were counted as missed 164 px above the visible bottom, so they popped out of
##     existence in mid-air below the bucket.
##
## Only a host is opened: MultiplayerMiniGameBase gates on connection_active, which host_game()
## sets on its own, and nothing measured here needs a partner peer. game_active is written
## directly because the base normally opens it behind an instruction overlay and a countdown, and
## the steering under test only runs while it is true.
## Headless cannot move the OS mouse (verified: push_input, warp_mouse and parse_input_event all
## leave get_mouse_position() at (0, 0)) — which is exactly why the fix records the pointer from
## the event instead of polling, and what makes the drag path measurable at all.

const PORT: int = 7804
const SCENE: String = "res://scenes/multiplayer/MP_CatchRainAquarium.tscn"

var results: Array = []
var game: Node = null


func _ready() -> void:
	print("\n=== VerifyMPBucketLayout ===")
	await get_tree().process_frame
	await _run()
	var failed: int = results.count(false)
	print("  RESULT: %d passed, %d failed" % [results.count(true), failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append(ok)
	print("  %s %s%s" % ["✓" if ok else "✗", label, "" if detail.is_empty() else "  — " + detail])


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _view() -> Rect2:
	return game.playfield_rect() as Rect2


func _bucket() -> Node2D:
	return game.get("bucket") as Node2D


## Screen position that lands on a given world x, so a synthesized drag can aim at the playfield
## rather than at raw pixels.
func _screen_for_world_x(world_x: float) -> Vector2:
	var view: Rect2 = _view()
	return get_viewport().get_canvas_transform() * Vector2(world_x, view.get_center().y)


func _run() -> void:
	_check("a session is open, which is all the base class gates on",
		GameManager.host_game(PORT),
		"connection_active=%s" % str(NetworkManager.connection_active))

	var packed := load(SCENE) as PackedScene
	game = packed.instantiate()
	get_tree().root.add_child(game)
	var waited: float = 0.0
	while _bucket() == null and waited < 8.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if _bucket() == null:
		_check("[!] the round never built its bucket, so nothing further can be measured",
			false, "waited %.1fs" % waited)
		return

	var view: Rect2 = _view()
	var bucket := _bucket()
	print("  playfield: %s  bucket: %s" % [str(view), str(bucket.position)])

	# -- layout --
	_check("the bucket was laid out from the camera, not from a hardcoded coordinate",
		bool(game.get("_layout_ready")), "_layout_ready=%s" % str(game.get("_layout_ready")))
	_check("the bucket starts at the horizontal centre of the playfield",
		absf(bucket.position.x - view.get_center().x) < 1.0,
		"bucket.x=%.1f centre=%.1f (the old poll parked it at x=%.0f, %.0f px away)"
			% [bucket.position.x, view.get_center().x,
			clampf(view.position.x, 60.0, 1092.0),
			absf(clampf(view.position.x, 60.0, 1092.0) - view.get_center().x)])
	_check("the bucket sits above the visible bottom, not at the old y=550",
		absf(bucket.position.y - (view.end.y - float(game.BUCKET_MARGIN_BOTTOM))) < 1.0,
		"bucket.y=%.1f visible_bottom=%.1f" % [bucket.position.y, view.end.y])

	# -- the defect itself: no pointer has arrived, so nothing may move --
	game.set("game_active", true)
	var before_x: float = bucket.position.x
	await _frames(20)
	_check("with no touch yet, the bucket holds the centre instead of sliding to an edge",
		absf(bucket.position.x - before_x) < 0.5 and not bool(game.get("_pointer_active")),
		"moved %.3f px over 20 frames, _pointer_active=%s"
			% [bucket.position.x - before_x, str(game.get("_pointer_active"))])

	# -- keyboard parity, which is what the instruction text promises --
	Input.action_press("ui_right")
	await _frames(15)
	Input.action_release("ui_right")
	var after_keys: float = bucket.position.x
	_check("arrow keys steer the bucket, as the instructions claim",
		after_keys > before_x + 5.0,
		"x %.1f -> %.1f" % [before_x, after_keys])

	# -- a real touch drag --
	# Two separate claims, because they fail for different reasons. First: a drag pushed through
	# the viewport actually reaches this game's handler at all.
	var target_world_x: float = view.end.x - 300.0
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _screen_for_world_x(target_world_x)
	get_viewport().push_input(drag)
	await get_tree().process_frame
	_check("a screen drag reaches the game's input handler",
		bool(game.get("_pointer_active")),
		"_pointer_active=%s after one pushed InputEventScreenDrag"
			% str(game.get("_pointer_active")))

	# Second: the screen-to-world conversion inside the handler. Delivered straight to the entry
	# point the engine calls, because push_input's own coordinate handling is what the first check
	# covers and mixing the two made a conversion bug unreadable (a window-space push was scaled a
	# second time and recorded x=48216).
	var aimed := InputEventScreenDrag.new()
	aimed.index = 0
	aimed.position = get_viewport().get_canvas_transform() * Vector2(target_world_x, view.get_center().y)
	game._unhandled_input(aimed)
	_check("the handler converts a viewport-local drag into the right world position",
		absf(float(game.get("_pointer_world_x")) - target_world_x) < 2.0,
		"event.position=%s recorded world x=%.1f, aimed at %.1f"
			% [str(aimed.position), float(game.get("_pointer_world_x")), target_world_x])
	var gap_before: float = bucket.position.x
	await get_tree().process_frame
	var one_frame_x: float = bucket.position.x
	_check("the bucket eases toward the finger instead of teleporting under it",
		one_frame_x > gap_before and absf(one_frame_x - target_world_x) > 20.0,
		"one frame moved it %.1f px of the %.1f px gap"
			% [one_frame_x - gap_before, absf(target_world_x - gap_before)])
	await _frames(90)
	_check("it does arrive where the finger is",
		absf(bucket.position.x - target_world_x) < 12.0,
		"settled at %.1f, aimed at %.1f" % [bucket.position.x, target_world_x])

	# -- bounds --
	bucket.position.x = view.end.x + 800.0
	await get_tree().process_frame
	_check("the bucket cannot be pushed off the playfield",
		bucket.position.x <= view.end.x - float(game.BUCKET_HALF_W) + 0.5
			and bucket.position.x >= view.position.x + float(game.BUCKET_HALF_W) - 0.5,
		"x=%.1f within [%.1f, %.1f]" % [bucket.position.x,
			view.position.x + float(game.BUCKET_HALF_W), view.end.x - float(game.BUCKET_HALF_W)])

	# -- spawning --
	game.set("game_active", false)
	_free_drops()
	var margin: float = float(game.SPAWN_MARGIN)
	var out_of_band: int = 0
	var below_top: int = 0
	for _i in range(40):
		game._spawn_raindrop()
	await get_tree().process_frame
	var spawned: Array = _drops()
	for d in spawned:
		if d.position.x < view.position.x + margin - 1.0 or d.position.x > view.end.x - margin + 1.0:
			out_of_band += 1
		if d.position.y >= view.position.y:
			below_top += 1
	_check("every drop spawns inside the playfield, not inside the old 100..1052 band",
		spawned.size() == 40 and out_of_band == 0,
		"%d drops, %d outside [%.0f, %.0f]"
			% [spawned.size(), out_of_band, view.position.x + margin, view.end.x - margin])
	_check("drops enter from above the visible top",
		below_top == 0, "%d of %d started on screen" % [below_top, spawned.size()])

	# -- the miss line --
	_free_drops()
	await get_tree().process_frame
	game.set("drops_missed", 0)
	game.set("game_active", true)
	var high := _park_drop(view.end.y - 40.0)
	await _frames(2)
	_check("a drop still on screen is not counted as missed",
		is_instance_valid(high) and int(game.get("drops_missed")) == 0,
		"drop alive=%s drops_missed=%s"
			% [str(is_instance_valid(high)), str(game.get("drops_missed"))])
	var low := _park_drop(view.end.y + 60.0)
	await _frames(3)
	_check("a drop that has left the screen is counted as missed",
		not is_instance_valid(low) and int(game.get("drops_missed")) == 1,
		"drop freed=%s drops_missed=%s"
			% [str(not is_instance_valid(low)), str(game.get("drops_missed"))])
	_check("the old miss line would have fired early on this camera",
		view.end.y > 700.0,
		"visible bottom y=%.0f vs the old hardcoded 700 (%.0f px of dead air)"
			% [view.end.y, view.end.y - 700.0])

	# -- rotation / resize --
	game.set("game_active", false)
	_free_drops()
	var steered_x: float = view.get_center().x + 200.0
	bucket.position.x = steered_x
	var old_size: Vector2i = get_window().size
	get_window().size = Vector2i(1080, 1920)
	await _frames(5)
	var view2: Rect2 = _view()
	# Width alone proves nothing: with stretch/aspect=expand the base width is preserved and the
	# HEIGHT is what grows, so a portrait resize shows up on the y axis only.
	if absf(view2.size.x - view.size.x) < 1.0 and absf(view2.size.y - view.size.y) < 1.0:
		_check("[!] the viewport did not resize in this build, so rotation is unmeasured here",
			false, "size still %s" % str(view2.size))
	else:
		_check("a resize re-seats the bucket on the new visible bottom",
			absf(bucket.position.y - (view2.end.y - float(game.BUCKET_MARGIN_BOTTOM))) < 1.0,
			"bucket.y=%.1f new visible_bottom=%.1f" % [bucket.position.y, view2.end.y])
		_check("a resize does not teleport a steered bucket back to the centre",
			absf(bucket.position.x - view2.get_center().x) > 1.0
				or absf(steered_x - view2.get_center().x) < 1.0,
			"x stayed %.1f, centre is %.1f" % [bucket.position.x, view2.get_center().x])
		_check("the bucket is inside the new bounds after the resize",
			bucket.position.x >= view2.position.x + float(game.BUCKET_HALF_W) - 0.5
				and bucket.position.x <= view2.end.x - float(game.BUCKET_HALF_W) + 0.5,
			"x=%.1f within [%.1f, %.1f]" % [bucket.position.x,
				view2.position.x + float(game.BUCKET_HALF_W),
				view2.end.x - float(game.BUCKET_HALF_W)])
	get_window().size = old_size
	await _frames(3)


func _drops() -> Array:
	var out: Array = []
	for c in game.get_children():
		if c is Area2D and c.has_meta("type") and String(c.get_meta("type")) == "raindrop":
			out.append(c)
	return out


func _free_drops() -> void:
	for d in _drops():
		d.free()


## A drop parked at a fixed y with zero velocity, so the miss line is sampled at a known height
## instead of wherever a falling drop happened to be on the frame the check ran.
func _park_drop(y: float) -> Area2D:
	var d := Area2D.new()
	d.position = Vector2(_view().get_center().x, y)
	d.set_meta("velocity", Vector2.ZERO)
	d.set_meta("type", "raindrop")
	game.add_child(d)
	return d
