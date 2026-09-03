extends Node

## Two-finger contact on the swipe-driven minigames.
##
## A phone is held in two hands and a resting thumb is a second contact, so the
## gesture code has to say WHICH finger owns the gesture. DropletDash's _input
## ignores InputEventScreenTouch.index entirely, and this probe drives its real
## _input() with synthesized events - the same call the engine makes - to see what
## a second finger actually does to the lane the player is in.
##
## Usage (headless is fine, no window geometry involved):
##   godot --headless --path . res://tools/ProbeMultitouch.tscn

const SWIPE := 60.0  # > DropletDash.SWIPE_THRESHOLD (40)

var _fails: int = 0


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _touch(idx: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	return e


func _drag(idx: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	return e


func _check(label: String, got: int, want: int) -> void:
	var ok := got == want
	if not ok:
		_fails += 1
	print("      %s %-56s lane=%d expected=%d" % ["PASS" if ok else "FAIL", label, got, want])


func _check_v(label: String, got: Vector2, want: Vector2) -> void:
	var ok := got.distance_to(want) < 0.5
	if not ok: _fails += 1
	print("      %s %-56s got=%s expected=%s" % ["PASS" if ok else "FAIL", label, str(got), str(want)])


func _check_f(label: String, got: float, want: float) -> void:
	var ok := absf(got - want) < 0.5
	if not ok: _fails += 1
	print("      %s %-56s got=%.1f expected=%.1f" % ["PASS" if ok else "FAIL", label, got, want])


func _check_b(label: String, got: bool, want: bool) -> void:
	var ok := got == want
	if not ok: _fails += 1
	print("      %s %-56s got=%s expected=%s" % ["PASS" if ok else "FAIL", label, str(got), str(want)])


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== MULTITOUCH: SECOND FINGER DURING A SWIPE ===")
	var game: Node = (load("res://scenes/minigames/DropletDash.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(game)
	await _frames(6)
	# Drive input directly rather than through the game's own start flow, so the
	# test isolates the gesture code from timers and the intro cutscene.
	game.game_active = true
	game.current_lane = 1
	var start := Vector2(400.0, 600.0)

	# 1. One finger, a real swipe right. Baseline: the control must work at all.
	game._input(_touch(0, start, true))
	game._input(_drag(0, start + Vector2(SWIPE, 0.0)))
	_check("finger 0 swipes right", game.current_lane, 2)
	game._input(_touch(0, start + Vector2(SWIPE, 0.0), false))

	# 2. Finger 0 holds, finger 1 lands far away, then finger 0 nudges 10px -
	#    well under the swipe threshold. The lane must not move: a 10px wobble is
	#    not a swipe. If _swipe_start was re-seeded from finger 1, finger 0's next
	#    drag measures across BOTH contacts and fires a phantom lane change.
	game.current_lane = 1
	game._input(_touch(0, start, true))
	game._input(_touch(1, Vector2(1500.0, 600.0), true))
	game._input(_drag(0, start + Vector2(10.0, 0.0)))
	_check("2nd finger down, finger 0 nudges 10px", game.current_lane, 1)

	# 3. Finger 1 lifts while finger 0 is still down and still swiping. Finger 0's
	#    swipe must still register: a second finger leaving is not the player
	#    letting go.
	game._input(_touch(1, Vector2(1500.0, 600.0), false))
	game._input(_drag(0, start + Vector2(SWIPE, 0.0)))
	_check("finger 1 lifts, finger 0 completes swipe", game.current_lane, 2)

	game.queue_free()
	await _frames(4)

	# FilterBuilder: the carried layer must stay with the finger that picked it up.
	print("  -- FilterBuilder: second finger during a carry --")
	var fb: Node = (load("res://scenes/minigames/FilterBuilder.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(fb)
	await _frames(6)
	fb.game_active = true
	fb._unhandled_input(_touch(0, Vector2(300.0, 500.0), true))
	fb._unhandled_input(_drag(0, Vector2(320.0, 520.0)))
	var carried_pos: Vector2 = fb.touch_pos
	fb._unhandled_input(_touch(1, Vector2(1600.0, 200.0), true))
	fb._unhandled_input(_drag(1, Vector2(1650.0, 220.0)))
	_check_v("2nd finger cannot steal touch_pos", fb.touch_pos, carried_pos)
	fb._unhandled_input(_touch(1, Vector2(1650.0, 220.0), false))
	_check_b("2nd finger lifting keeps the carry alive", fb.touch_active, true)
	fb._unhandled_input(_touch(0, Vector2(320.0, 520.0), false))
	_check_b("owning finger lifting ends the carry", fb.touch_active, false)
	fb.queue_free()
	await _frames(4)

	# PlayerBucket: a resting thumb must not pin the bucket.
	print("  -- PlayerBucket: resting thumb at the screen edge --")
	var pb: Node = (load("res://scripts/multiplayer/PlayerBucket.gd") as GDScript).new()
	get_tree().root.add_child(pb)
	await _frames(4)
	pb.is_active = true
	pb._input(_touch(0, Vector2(600.0, 900.0), true))
	pb._input(_drag(0, Vector2(650.0, 900.0)))
	_check_f("finger 0 steers", pb.target_x, 650.0)
	pb._input(_touch(1, Vector2(20.0, 900.0), true))
	pb._input(_drag(1, Vector2(20.0, 900.0)))
	_check_f("resting thumb at x=20 does not pin the bucket", pb.target_x, 650.0)
	pb._input(_touch(1, Vector2(20.0, 900.0), false))
	pb._input(_drag(0, Vector2(700.0, 900.0)))
	_check_f("finger 0 still steers after the thumb lifts", pb.target_x, 700.0)
	pb.queue_free()
	await _frames(4)

	# ── MicrogameShell contact ownership, observed through GreywaterSorterV2 ──
	#
	# GreywaterSorterV2 is the only v2 game that CARRIES something between tap and
	# release, so it is the only one where the shell's routing is observable. Its
	# _shell_release judges the drop by bucket x and a mid-screen drop is scored as
	# lost, so a second contact reaching _shell_release used to cost the player a
	# bucket. Fixing the shell covers all six v2 games, not just this one.
	print("  -- MicrogameShell / GreywaterSorterV2: second contact during a carry --")
	var gs: Node = (load("res://scenes/minigames/GreywaterSorter.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(gs)
	await _frames(12)
	gs.game_active = true
	await _frames(10)
	var bucket: Node2D = null
	for i in range(gs.BUCKET_POOL_SIZE):
		var cand: Node2D = gs.bucket_pool.get_item(i)
		if cand != null and cand.visible:
			bucket = cand
			break
	if bucket == null:
		print("      FAIL no bucket spawned - cannot exercise the carry")
		_fails += 1
	else:
		var start_x: float = bucket.position.x
		gs._on_shell_gui_input(_touch(0, bucket.position, true))
		_check_b("finger 0 grabs a bucket", gs.current_bucket == bucket, true)

		# A resting thumb: down and up somewhere else entirely.
		gs._on_shell_gui_input(_touch(1, Vector2(60.0, 620.0), true))
		gs._on_shell_gui_input(_drag(1, Vector2(90.0, 640.0)))
		gs._on_shell_gui_input(_touch(1, Vector2(90.0, 640.0), false))
		_check_b("thumb lifting does not drop the carried bucket",
			gs.current_bucket == bucket, true)
		_check_f("thumb dragging does not move the carried bucket",
			bucket.position.x, start_x)

		# The owning contact still drives it. Which side is CORRECT depends on the
		# bucket's own `safe` meta - _spawn_bucket randomises it - so aim at the
		# zone that matches this bucket rather than assuming the garden.
		var safe: bool = bucket.get_meta("safe")
		var drop_x: float = 80.0 if safe else gs._vp_size.x - 80.0
		gs._on_shell_gui_input(_drag(0, Vector2(drop_x, bucket.position.y)))
		_check_b("owning finger still drags it", not is_equal_approx(bucket.position.x, start_x), true)
		var before: int = gs.sorted_correct
		gs._on_shell_gui_input(_touch(0, Vector2(drop_x, bucket.position.y), false))
		_check_b("owning finger's release sorts it", gs.current_bucket == null, true)
		_check_b("released into the matching zone, scored correct",
			gs.sorted_correct == before + 1, true)

		# emulate_mouse_from_touch: on Android every finger ALSO arrives as a mouse
		# button, so the pair must produce ONE grab and ONE sort, not two of each.
		await _frames(6)
		var b2: Node2D = null
		for i in range(gs.BUCKET_POOL_SIZE):
			var c2: Node2D = gs.bucket_pool.get_item(i)
			if c2 != null and c2.visible:
				b2 = c2
				break
		if b2 == null:
			print("      SKIP no second bucket for the emulated-mouse pair")
		else:
			var mb_down := InputEventMouseButton.new()
			mb_down.button_index = MOUSE_BUTTON_LEFT
			mb_down.pressed = true
			mb_down.position = b2.position
			var mb_up := InputEventMouseButton.new()
			mb_up.button_index = MOUSE_BUTTON_LEFT
			mb_up.pressed = false
			var safe2: bool = b2.get_meta("safe")
			var drop2: float = 80.0 if safe2 else gs._vp_size.x - 80.0
			mb_up.position = Vector2(drop2, b2.position.y)
			var n_before: int = gs.sorted_correct
			gs._on_shell_gui_input(_touch(0, b2.position, true))
			gs._on_shell_gui_input(mb_down)
			_check_b("emulated mouse press does not disturb the grab",
				gs.current_bucket == b2, true)
			gs._on_shell_gui_input(_drag(0, Vector2(drop2, b2.position.y)))
			gs._on_shell_gui_input(_touch(0, Vector2(drop2, b2.position.y), false))
			gs._on_shell_gui_input(mb_up)
			_check_b("the touch+mouse pair sorts exactly one bucket",
				gs.sorted_correct == n_before + 1, true)
	gs.queue_free()
	await _frames(4)

	print("  -- %d failing case(s) --" % _fails)
	print("")
	get_tree().quit(0)
