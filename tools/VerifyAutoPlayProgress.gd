extends Node
##
## VerifyAutoPlayProgress - does the bot actually PLAY each single-player game on a
## host with no mouse cursor?
##
## WHY THIS EXISTS
##   "the autoplay doesnt work on rice wash" - reported from a real Android phone.
##   The existing autoplay harnesses measure the wiring: VerifyAutoPlayDrive proves
##   every roster game registers under an id the dispatch table knows and that the
##   bot cannot deadlock itself on a pause, and AutoPlayHarness soaks the round loop
##   looking for error spam. Neither measures the only thing a player can see: did
##   the game's own counters move while the bot was driving.
##
##   That gap hid a whole class of defect. A driver whose only lever is
##   Input.warp_mouse() is driving the CURSOR - a DisplayServer call that Android
##   implements as nothing, because a phone has no cursor. The game then reads a
##   pointer that never moved, the bot's "play" is a no-op, and every existing check
##   still passes: it registered, it dispatched, it logged a round, it raised no
##   errors. Headless has no cursor either, which is exactly what makes the phone's
##   bug reproducible here.
##
## WHAT IS ASSERTED
##   [progress]  every roster game reports at least one CORRECT action while the bot
##               drives it. correct_actions, not total_actions: RiceWashRescue counts
##               a missed drop with record_action(false), so a bot that never moves
##               still runs the counter up. Only the correct column means played.
##   [follow]    a pointer-follower converges on its target. A catcher can score by
##               luck - the pot in RiceWashRescue bounces off the same wall a dead
##               basin is clamped to - so the follower games are also measured on the
##               tracking error and on whether the follower moved at all.
##   [pointer]   the mechanism the drivers use to point actually reaches a game on
##               this host: TouchInputManager sees a finger, and an _unhandled_input
##               handler shaped like MP_CatchTheRain._note_pointer receives the same
##               screen position. Those two are how the pointer-followers in the
##               project read input, and neither can be reached by a cursor warp.
##
## Run: godot --headless --path . tools/VerifyAutoPlayProgress.tscn
## Exit 0 = every game progressed, 1 = at least one did not.

## Wall-clock seconds every game is driven for, whatever it scores.
##
## Under the shortest round on the roster (RiceWashRescue Easy is 10s) so a pass is
## measured inside the round rather than after it ended, and long enough for the
## slowest authored cooldown to fire more than once (QuickShower waits 1.2s between
## taps). Also the sampling window for [follow], which needs enough frames for a mean
## to mean anything.
const DRIVE_SECONDS: float = 6.0
## Ceiling the window may stretch to while the game has still scored NOTHING.
##
## A fixed 6s window cannot measure DropletDash: its items spawn at y=-50 and the
## droplet sits at 0.75 * height, so on Easy (160px/s) the FIRST item needs 5.4s just
## to arrive, and only 30% of items are the collectibles that record a correct action.
## It reported correct=0 total=0 - which reads exactly like a bot that never moved,
## from a round where nothing had reached the player yet. Extending only while the
## count is zero keeps the fast games at ~6s instead of paying this for all 24.
##
## The stretch is necessary but NOT sufficient: the loop below breaks the moment
## game_active goes false, and the DropletDash round clock (20s on Easy) expires before
## this ceiling, so a round the bot survived can still close with a zero count. That
## residual case is measured by BOT_ONLY_STATE, not by widening this further.
const MAX_DRIVE_SECONDS: float = 24.0
## Frames allowed for _ready() -> AutoPlayManager.register_game().
const READY_FRAMES: int = 8
## Grace period for start_game() to actually make the round live.
##
## The four minigames_v2 games make start_game() a COROUTINE: MicrogameShell awaits a
## 1.0s single-verb flash before super.start_game() sets game_active. Sampling one
## frame after the call reads a game that has not started, so the window closed
## instantly and reported total=0 for games that were about to play fine.
const WAIT_ACTIVE_SECONDS: float = 3.0
const SCENE_FMT: String = "res://scenes/minigames/%s.tscn"

## Games whose input is a position rather than a discrete action. These are the ones a
## cursor warp used to steer, so they get the extra tracking measurement.
## Value = [follower_property, target_property].
##
## A target property holding an ARRAY is resolved each frame to its lowest (largest y)
## member. RiceWashRescue is measured against water_drops, not against pot_node: the
## game scores abs(drop.x - basin.x) < 85 at the moment a drop lands, and a drop is in
## the air 1.3s while the pot walks on, so a basin welded to the pot lands 156px off
## and misses everything. Tracking the pot is the defect, not the goal.
const FOLLOWERS: Dictionary = {
	"RiceWashRescue": ["basin_node", "water_drops"],
}
## Follower must have moved at least this far (px) across the window. A dead follower
## parks on one clamp bound and its range is 0.
const FOLLOW_MIN_RANGE: float = 100.0
## Mean |follower.x - target.x| that still counts as following. The basin lerps at
## 15*delta toward the pot, so it trails by a few px at pot_speed 120-260; 250 is
## generous and still far under the several hundred a parked basin reports.
const FOLLOW_MAX_MEAN_ERR: float = 250.0
## Slack allowed when comparing an injected aim with the position a reader reports.
const POS_TOL_PX: float = 2.0

## Games whose progress CANNOT be read from correct_actions/current_score.
## Value = an int property that only the bot writes, so any change in it is proof the
## bot acted. Reported beside the counters, never instead of them.
##
## DropletDash: current_lane. The game is game_mode "survival" and record_action()
## fires once, on catching a clean-water token - 30% of spawns, obstacle_interval 1.2s
## on Easy, first arrival 5.4s - while the round itself ends on distance reached
## (DropletDash.gd:325) or 3 hits (:329). A round the bot dodged perfectly therefore
## ends correct=0 total=0 score=0, indistinguishable from a bot that never moved.
## Measured: two back-to-back runs of this harness on identical code reported
## FAIL correct=0 total=0 score=0 and PASS correct=1 total=1 score=10.
##
## distance_traveled is NOT the substitute: DropletDash.gd:251 accumulates it from
## obstacle_speed * delta every frame whether or not anything steers, so it would pass
## a dead bot - exactly the failure mode this file exists to catch. current_lane is
## written in two places only (DropletDash.gd:12 init, :240 inside _move_lane), and
## _move_lane is reached from the drag handler at :236 or from
## AutoPlayManager._play_droplet_dash. Headless has no drag, so every change is the bot.
const BOT_ONLY_STATE: Dictionary = {
	"DropletDash": "current_lane",
}

var _pass: int = 0
var _fail: int = 0
var _rows: Array = []

## Probe for [pointer]: the shape the MP pointer-followers use to read input
## (MP_CatchTheRain._unhandled_input -> _note_pointer). A cursor warp reaches this on
## desktop and nothing at all on a phone.
class PointerProbe extends Node:
	var last_pos: Vector2 = Vector2(-1, -1)
	var touch_events: int = 0
	var drag_events: int = 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed:
				touch_events += 1
				last_pos = event.position
		elif event is InputEventScreenDrag:
			drag_events += 1
			last_pos = event.position

func _p(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s%s" % [name, ("  " + detail) if detail != "" else ""])
	else:
		_fail += 1
		print("  [FAIL] %s%s" % [name, ("  " + detail) if detail != "" else ""])

func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame

func _ready() -> void:
	await get_tree().process_frame
	var apm: Node = get_node_or_null("/root/AutoPlayManager")
	if apm == null:
		print("FATAL: AutoPlayManager autoload missing")
		get_tree().quit(1)
		return

	print("=== AUTOPLAY PROGRESS (cursor-free host: %s) ===" % DisplayServer.get_name())
	_check_progress_rule()
	await _check_pointer_mechanism(apm)

	var only: PackedStringArray = OS.get_cmdline_user_args()
	for id in GameManager.ALL_SINGLEPLAYER_MINIGAMES:
		if only.size() > 0 and not only.has(str(id)):
			continue
		await _drive_one(apm, str(id))

	print("--- per game ---")
	for r in _rows:
		print("  %-18s %-24s correct=%-4d total=%-4d score=%-5d by=%-18s %s" % [
			r["id"], r["handler"], r["correct"], r["total"], r["score"],
			r["by"], r["note"]])
	print("=== %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)

## Truth table for _progressed(). The zero-score branch is the whole point of
## BOT_ONLY_STATE, and five measured DropletDash rounds after the fix all happened to
## score (correct 1-4, lane changes 3-8), so the branch that rescues a scoreless round
## is not exercised by driving the game. Asserting the rule directly is the difference
## between a branch that is verified and one that is assumed.
func _check_progress_rule() -> void:
	_p("rule:score_alone_progresses",
		_progressed(0, 10, "", 0) and _progressed(1, 0, "", 0),
		"score>0 or correct>0 passes with no state property")
	_p("rule:nothing_is_not_progress",
		not _progressed(0, 0, "", 0),
		"no counters and no state property fails")
	_p("rule:state_property_with_no_change_is_not_progress",
		not _progressed(0, 0, "current_lane", 0),
		"a bot that never moved still fails")
	_p("rule:state_change_rescues_a_scoreless_round",
		_progressed(0, 0, "current_lane", 1),
		"one bot-caused change passes a survival round that scored nothing")

## Did the bot demonstrably do something this round? Counters first; a bot-only state
## change only ever ADDS a way to pass, so no game loses coverage by being listed.
func _progressed(correct: int, score: int, state_prop: String, changes: int) -> bool:
	return correct > 0 or score > 0 or (state_prop != "" and changes > 0)

## One game, driven by the real AutoPlayManager._process (the engine ticks the
## autoload; nothing here calls the driver by hand, so cooldown decay and the
## dispatch guards are the shipped ones).
func _drive_one(apm: Node, id: String) -> void:
	var path: String = SCENE_FMT % id
	if not ResourceLoader.exists(path):
		_p("progress:%s" % id, false, "scene missing: %s" % path)
		return
	var packed := load(path) as PackedScene
	var g: Node = packed.instantiate() if packed != null else null
	if g == null:
		_p("progress:%s" % id, false, "instantiate failed")
		return

	# Enabled before the game enters the tree: register_game() returns early unless
	# auto-play is already on, and that call is in the game's own _ready(). The flag is
	# set directly rather than through set_auto_play_enabled() so nothing is written to
	# the save file and no real session is started.
	apm.auto_play_enabled = true
	apm.auto_play_duration = 0.0
	apm.auto_play_start_time = 0
	apm.current_game = null
	apm.game_name = ""

	# Added under root, not as the current scene: this harness IS the current scene, and
	# a game that ends its round mid-window would take the harness down with the
	# transition its end chain runs.
	get_tree().root.add_child(g)
	await _frames(READY_FRAMES)

	var handler: String = ""
	if str(apm.game_name) != "":
		handler = str(apm.HANDLERS.get(apm.call("_canon", str(apm.game_name)), "(fallback)"))
	if g.has_method("_hide_instruction_overlay"):
		g.call("_hide_instruction_overlay")
	if g.has_method("start_game"):
		g.call("start_game")

	# Wait for the round to actually go live rather than assuming one frame is enough.
	var w0: int = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - w0) < int(WAIT_ACTIVE_SECONDS * 1000.0):
		await get_tree().process_frame
		if not is_instance_valid(g) or not g.is_inside_tree():
			break
		if "game_active" in g and g.game_active:
			break
	var went_active: bool = (
		is_instance_valid(g) and g.is_inside_tree()
		and ("game_active" in g) and bool(g.game_active)
	)

	var follower: Node2D = null
	var target_prop: String = ""
	if FOLLOWERS.has(id):
		var props: Array = FOLLOWERS[id]
		follower = g.get(props[0])
		target_prop = str(props[1])

	var f_min: float = INF
	var f_max: float = -INF
	var err_sum: float = 0.0
	var err_n: int = 0
	var had_follower: bool = follower != null

	# Bot-only state sampler. state_last starts unset rather than at 0 so lane 0 is not
	# read as a change on the first sample.
	var state_prop: String = str(BOT_ONLY_STATE.get(id, ""))
	var state_changes: int = 0
	var state_last: int = 0
	var state_seen: bool = false

	var t0: int = Time.get_ticks_msec()
	var ended_early: bool = false
	var deadline: int = int(DRIVE_SECONDS * 1000.0)
	while (Time.get_ticks_msec() - t0) < deadline:
		await get_tree().process_frame
		if not is_instance_valid(g) or not g.is_inside_tree():
			ended_early = true
			break
		if went_active and "game_active" in g and not g.game_active:
			ended_early = true
			break
		# Stretched only while the game has scored nothing, so a slow-arriving playfield
		# is given the time it needs without charging every other game for it.
		if (deadline < int(MAX_DRIVE_SECONDS * 1000.0)
				and int(g.correct_actions if "correct_actions" in g else 0) == 0):
			deadline = int(MAX_DRIVE_SECONDS * 1000.0)
		if state_prop != "" and state_prop in g:
			var sv: int = int(g.get(state_prop))
			if state_seen and sv != state_last:
				state_changes += 1
			state_last = sv
			state_seen = true
		if follower != null and is_instance_valid(follower):
			f_min = minf(f_min, follower.position.x)
			f_max = maxf(f_max, follower.position.x)
			var tx: float = _target_x(g, target_prop)
			if not is_nan(tx):
				err_sum += absf(follower.position.x - tx)
				err_n += 1

	# Snapshotted before the free below: g.free() takes the follower and target with it,
	# and a freed reference in a typed variable reads as null, which sent a window with
	# 811 samples in it to the "no samples" branch.
	var sampled: bool = had_follower and err_n > 0
	var f_range: float = (f_max - f_min) if err_n > 0 else 0.0
	var f_mean_err: float = (err_sum / float(err_n)) if err_n > 0 else 0.0

	var correct: int = 0
	var total: int = 0
	var score: int = 0
	if is_instance_valid(g):
		correct = int(g.correct_actions) if "correct_actions" in g else 0
		total = int(g.total_actions) if "total_actions" in g else 0
		score = int(g.current_score) if "current_score" in g else 0

	# Detached the frame the window closes. The end chain awaits a tally and a score
	# page and then calls GameManager.start_next_minigame(), which changes the scene out
	# from under this harness; freeing the game first strands that chain on a dead
	# instance exactly as a real scene change does.
	apm.current_game = null
	apm.auto_play_enabled = false
	if apm.has_method("_release_pointer"):
		apm.call("_release_pointer")
	if is_instance_valid(g):
		if g.is_inside_tree():
			get_tree().root.remove_child(g)
		g.free()
	get_tree().paused = false
	await _frames(2)

	var note: String = "round ended inside the window" if ended_early else ""
	if not went_active:
		note = "never went active within %.1fs of start_game()" % WAIT_ACTIVE_SECONDS
	# Which signal actually carried the row. A survival game scores nothing for the thing
	# it asks the bot to do, so a pass earned by lane changes must not be read as
	# accuracy evidence: the log says which one it was.
	var acted_via_state: bool = state_prop != "" and state_changes > 0
	var progressed: bool = _progressed(correct, score, state_prop, state_changes)
	var proved_by: String = "nothing"
	if correct > 0 or score > 0:
		proved_by = "score"
	elif acted_via_state:
		proved_by = "%s+%d" % [state_prop, state_changes]
	var state_extra: String = ""
	if state_prop != "":
		state_extra = " %s_changes=%d" % [state_prop, state_changes]
	_rows.append({"id": id, "handler": handler, "correct": correct, "total": total,
		"score": score, "by": proved_by, "note": note})
	_p("progress:%s" % id, progressed,
		"handler=%s correct=%d total=%d score=%d%s by=%s%s" % [
			handler, correct, total, score, state_extra, proved_by,
			("  " + note) if note != "" else ""])

	if sampled:
		_p("follow:%s" % id, f_range >= FOLLOW_MIN_RANGE and f_mean_err <= FOLLOW_MAX_MEAN_ERR,
			"range=%.0fpx mean_err=%.0fpx samples=%d" % [f_range, f_mean_err, err_n])
	elif FOLLOWERS.has(id):
		_p("follow:%s" % id, false, "no samples: follower=%s target=%s active=%s" % [
			str(had_follower), target_prop, str(went_active)])

## X coordinate the follower is supposed to be at this frame.
##
## A Node2D property is read straight. An ARRAY property is resolved to its lowest
## member - the one about to reach the follower's row and therefore the one the game
## will score against. NAN means "nothing to track this frame", which is a skipped
## sample rather than a zero-error one: counting frames with an empty playfield as
## perfect tracking would let a dead follower average its way to a pass.
func _target_x(g: Node, prop: String) -> float:
	if prop == "" or not (prop in g):
		return NAN
	var v: Variant = g.get(prop)
	if v is Array:
		var low_y: float = -INF
		var low_x: float = NAN
		for it in (v as Array):
			if not is_instance_valid(it) or not (it is Node2D):
				continue
			if (it as Node2D).position.y > low_y:
				low_y = (it as Node2D).position.y
				low_x = (it as Node2D).position.x
		return low_x
	if v is Node2D and is_instance_valid(v):
		return (v as Node2D).position.x
	return NAN

## The pointing mechanism itself, measured against the two readers every
## pointer-follower in the project uses. Deliberately ahead of the game loop: if this
## fails, every follower failure below it has one cause.
func _check_pointer_mechanism(apm: Node) -> void:
	var tim: Node = get_node_or_null("/root/TouchInputManager")
	if tim == null:
		_p("pointer:touch_input_manager_present", false, "autoload missing")
		return
	if not apm.has_method("_drive_pointer"):
		_p("pointer:driver_can_point_without_a_cursor", false,
			"AutoPlayManager has no _drive_pointer()")
		return
	var probe := PointerProbe.new()
	get_tree().root.add_child(probe)
	await get_tree().process_frame

	var a := Vector2(300, 700)
	var b := Vector2(520, 700)
	apm.call("_drive_pointer", a)
	await get_tree().process_frame
	var count_after_press: int = int(tim.call("get_touch_count"))
	var pos_after_press: Vector2 = tim.call("get_touch_position", 0)
	apm.call("_drive_pointer", b)
	await get_tree().process_frame
	var pos_after_drag: Vector2 = tim.call("get_touch_position", 0)
	var mouse_after_drag: Vector2 = get_viewport().get_mouse_position()
	var probe_pos: Vector2 = probe.last_pos
	var probe_touches: int = probe.touch_events
	var probe_drags: int = probe.drag_events
	apm.call("_release_pointer")
	await get_tree().process_frame
	var count_after_release: int = int(tim.call("get_touch_count"))

	# Compared with a tolerance, not for equality: the aim is given in viewport space and
	# the injected event carries window space, so it makes one round trip through
	# get_final_transform() and its inverse. On this host that scale is 30 (a 64x36
	# window behind a 1920x1080 viewport) and the return trip lands within a float
	# rounding of the aim. A space MISTAKE is off by that factor of 30, not by 2px.
	_p("pointer:touch_manager_sees_a_finger",
		count_after_press == 1 and pos_after_press.distance_to(a) <= POS_TOL_PX,
		"count=%d pos=%s aim=%s" % [count_after_press, str(pos_after_press), str(a)])
	_p("pointer:drag_moves_the_finger", pos_after_drag.distance_to(b) <= POS_TOL_PX,
		"pos=%s aim=%s" % [str(pos_after_drag), str(b)])
	_p("pointer:unhandled_input_receives_it",
		probe_touches == 1 and probe_drags >= 1 and probe_pos.distance_to(b) <= POS_TOL_PX,
		"touch=%d drag=%d pos=%s" % [probe_touches, probe_drags, str(probe_pos)])
	# The third reader: a poller calling get_mouse_position(). RiceWashRescue falls back
	# to it when no finger is registered, and it only tracks an injected touch because
	# project.godot leaves pointing/emulate_mouse_from_touch at its default true.
	#
	# Only observable on a host with no OS pointer. Where one exists,
	# Viewport.get_mouse_position() resolves through DisplayServer.mouse_get_position(),
	# so the physical cursor owns the value and overwrites whatever
	# emulate_mouse_from_touch put there. Measured on a windowed run of this same build:
	# mouse=(100, 194) - my actual cursor - against aim=(520, 700), while the two event
	# readers above both passed. That is the host winning, not the emulation failing, and
	# reporting it as a FAIL would be blaming the project for the test environment.
	# Headless and a phone are both cursor-free, and cursor-free is the case the shipped
	# game runs in, so the check still runs where its answer means something. If the
	# feature probe is ever wrong the headless total drops by one and says so, rather than
	# passing silently.
	if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE):
		# Not a pass and not a fail: the host decides this one, not the project.
		print("  [SKIP] pointer:get_mouse_position_follows_it  %s owns the cursor"
			% DisplayServer.get_name())
		print("         mouse=%s aim=%s - the emulated position is not observable here"
			% [str(mouse_after_drag), str(b)])
	else:
		_p("pointer:get_mouse_position_follows_it",
			mouse_after_drag.distance_to(b) <= POS_TOL_PX,
			"mouse=%s aim=%s" % [str(mouse_after_drag), str(b)])
	# A finger that is never lifted is the phantom touch TouchInputManager documents:
	# get_touch_count() would report it forever and every follower would lock to its
	# last position after auto-play stopped.
	_p("pointer:release_clears_the_finger", count_after_release == 0,
		"count=%d" % count_after_release)

	probe.queue_free()
	await get_tree().process_frame
