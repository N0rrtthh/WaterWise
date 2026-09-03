extends MicrogameShell

## CatchTheRain v2 — DWTD-style rebuild on MicrogameShell (thesis rehaul).
##
## Differences from the legacy version, all measured against the thesis
## constraints:
##   * ZERO allocation in the loop. All drops come from a fixed EntityPool
##     (built once); `drops` is a pre-sized Array filled at setup so AutoPlay's
##     omniscient driver can read it without the game ever resizing anything.
##   * ZERO input latency. The drum snaps to the finger in _shell_drag the frame
##     the event arrives — the legacy lerp(12*delta) smoothing is gone.
##   * Input is event-driven (gui_input on the shell layer), not _process
##     polling of get_mouse_position().
##   * Juice everywhere: catch = squash + score punch + water rise; dirty drop
##     = aggressive shake + red flash + combo reset. No emoji Labels.
##
## AutoPlay contract preserved: `drum_node`, `drops` (Array of nodes with
## `good` meta), drops named Drop_* with `type` = "raindrop".

const DROP_POOL_SIZE: int = 20
const DRUM_HALF_WIDTH: float = 70.0
## Where a drop is born, above the top edge.
const SPAWN_Y: float = -30.0
## The catch band's lower lip, relative to drum_node.position.y. Below this the
## drop has passed the rim and is gone.
const CATCH_BAND_BOTTOM: float = -55.0
## How long a drop stays catchable. The band was a fixed 40 px, which is a TIME
## window only while the fall speed is fixed too — at Hard's 500 px/s a drop
## crossed it in 80 ms, under 5 frames, and the speeds derived in _shell_start()
## are faster still. Sizing the band from the speed pins the window at 0.12 s on
## every tier and every screen, so "it fell straight through the drum" cannot
## happen just because one frame straddled the band.
const CATCH_WINDOW_S: float = 0.12
const CATCH_BAND_MIN_H: float = 40.0
const DRUM_MARGIN: float = 80.0

var drum_node: Node2D            # name kept for AutoPlayManager._play_catcher
var drops: Array = []            # pre-sized; AutoPlay reads this
var drop_pool: EntityPool
var water_level: Polygon2D
var cloud_pool: EntityPool

var drop_speed: float = 350.0
var drop_speed_current: float = 350.0
## Seconds a drop takes to fall from SPAWN_Y to the drum. This is the authored
## difficulty knob; drop_speed is derived from it in _shell_start().
var fall_time: float = 2.0
## Derived in _shell_start() so the catch window is a constant time, not a
## constant pixel height. See CATCH_WINDOW_S.
var catch_band_height: float = CATCH_BAND_MIN_H
var spawn_timer: float = 0.0
var spawn_interval: float = 0.35
var target_score: int = 8
## Quota counter, deliberately separate from current_score: the base awards
## 10 + floor(streak/3)*5 per hit, so the score is not a count of catches. The
## water level draws THIS; the HUD number stays the score.
var caught_count: int = 0
var vp_y_limit: float = 100000.0


func _init() -> void:
	# Set BEFORE base _ready: AutoPlayManager.register_game reads game_name,
	# and _shell_verb() reads game_instruction_text during _setup_ui.
	# Localized: hardcoded English until now, so the HUD title ignored the chosen
	# language. has_text() guard rather than _loc() because _init() can run before
	# Localization is ready -- see FixLeakV2._init for the same idiom.
	game_name = (
		Localization.get_text("catch_the_rain")
		if Localization and Localization.has_text("catch_the_rain")
		else "Catch The Rain"
	)
	# The instruction banner was the bare word "CATCH" — no objective, and a duplicate
	# of what _shell_verb() already flashes on screen, so a first-time player was never
	# told which drops to catch or that the red ones cost them. It was also hardcoded
	# English, so the banner read identically in Filipino. has_text() guard because
	# _init() is the CONSTRUCTOR and get_text() returns the RAW KEY (plus a "Missing
	# translation key" push) if the table is not filled yet, which tools/SceneLoadCheck.gd
	# reproduces by instantiating scenes before autoload _ready(); see FixLeakV2._init.
	game_instruction_text = (
		Localization.get_text("catch_the_rain_instructions")
		if Localization and Localization.has_text("catch_the_rain_instructions")
		else "DRAG to move the drum!\nCatch BLUE drops! Avoid RED drops!"
	)
	game_duration = 10.0
	game_mode = "quota"


func _shell_verb() -> String:
	return "CATCH"


func _apply_difficulty_settings() -> void:
	# super() is what queues the chaos_effects the algorithm picked for this round
	# — one of the four adaptive outputs the thesis specifies. Without it this game
	# silently ran clean at every difficulty. It also seeds game_duration from
	# difficulty_settings["time_limit"]; the table below deliberately overrides
	# that with this game's own pacing.
	super._apply_difficulty_settings()
	# Thesis Table 6: time {10,15,20}s; speed scales via difficulty. Difficulty is
	# authored as REACTION TIME per drop, not as px/s — see _shell_start() for why a
	# hardcoded speed made the round's fairness a function of screen height. What the
	# tiers demand of the player stays monotone in catches per second: Easy 6/15s =
	# 0.40, Medium 8/10s = 0.80, Hard 11/10s = 1.10, on top of a shorter look-ahead
	# and, at Hard, reversed controls.
	var speed_mult := get_difficulty_multiplier("speed_multiplier", 1.0)
	var item_count := int(get_difficulty_multiplier("item_count", 5))

	# No mobile difficulty discount here, deliberately. This block used to divide
	# fall_time by MobileUIManager.get_game_speed_multiplier() (0.85) and
	# spawn_interval by get_spawn_rate_multiplier() (0.9). Three reasons it is gone,
	# all measured in tools/logs/mobilepath.log:
	#
	#  1. It ran BACKWARDS. MiniGameBase reports reaction_time as the round's ELAPSED
	#     time and AdaptiveDifficulty divides it by the tier's time_limit (20/15/10 s),
	#     which the accommodation did not touch. Slower drops therefore take longer to
	#     reach the same quota and the thesis speed term 1 - T_r/T_max FELL on mobile:
	#     0.745 → 0.708 Easy, 0.703 → 0.662 Medium, 0.676 → 0.653 Hard. An
	#     accommodation that lowers the mobile player's score S is defeating itself.
	#  2. CatchTheRain was the only one of 25 minigames that pulled it, so a phone
	#     player's (Accuracy, ReactionTime) samples were not comparable between this
	#     game and the other 24 on the same device — and those samples ARE the
	#     research data, not a game feature.
	#  3. The thesis specifies touch input handling and the 16 ms frame budget for
	#     low-end Android; it specifies no difficulty discount for mobile. The right
	#     answer to a small screen is the screen-independent authoring already in
	#     _shell_start (fall_time in seconds, catch band derived from drop speed),
	#     which holds on every panel without moving the measurement.

	match current_difficulty:
		"Easy":
			fall_time = 2.6
			spawn_interval = 0.5
			target_score = 6
			game_duration = 15.0
		"Hard":
			# 1.2 s is a fairness floor, not a tuning whim: speed_multiplier is 1.5 at
			# Hard, which would cut the authored 1.45 s to 0.97 s — and Hard is also
			# the tier that reverses the controls, so the player is tracking a drop
			# they steer backwards. A drop still crosses the whole screen in about a
			# second; the demand rises through density and the mirror, not through a
			# reaction time no thumb can meet.
			fall_time = maxf(1.2, 1.45 / maxf(speed_mult, 0.1))
			spawn_interval = clampf(0.30 - float(item_count) * 0.012, 0.14, 0.30)
			target_score = 11
			game_duration = 10.0
		_:
			fall_time = 2.0
			spawn_interval = 0.35
			target_score = 8
			game_duration = 10.0


# ── Build (once) ────────────────────────────────────────────────────────────

func _shell_setup() -> void:
	var vp := get_viewport_rect().size

	_build_backdrop(vp)
	_build_drum(vp)

	# Drop pool: every drop fully built here, nothing during the loop.
	drop_pool = _make_pool(_make_drop_factory(), DROP_POOL_SIZE)
	drops.resize(DROP_POOL_SIZE)          # pre-sized once, never resized again
	for i in range(DROP_POOL_SIZE):
		drops[i] = drop_pool.get_item(i)  # AutoPlay reads this array

	# Ambient clouds, pooled and drifting on looping tweens.
	cloud_pool = _make_pool(_make_cloud_factory(), 4)
	for i in range(4):
		var cloud := cloud_pool.acquire() as Node2D
		if cloud == null:
			continue
		_start_cloud_drift(cloud)

	vp_y_limit = vp.y + 40.0


func _build_backdrop(vp: Vector2) -> void:
	# Vertical sky gradient polygon (same technique as CartoonStage).
	var sky := Polygon2D.new()
	sky.name = "Sky"
	sky.polygon = PackedVector2Array([
		Vector2(-40, -40), Vector2(vp.x + 40, -40),
		Vector2(vp.x + 40, vp.y + 40), Vector2(-40, vp.y + 40),
	])
	sky.color = Color(0.42, 0.68, 0.92)
	sky.vertex_colors = PackedColorArray([
		Color(0.22, 0.42, 0.68), Color(0.22, 0.42, 0.68),
		Color(0.62, 0.82, 0.95), Color(0.62, 0.82, 0.95),
	])
	sky.z_index = -20
	add_child(sky)


func _build_drum(vp: Vector2) -> void:
	drum_node = Node2D.new()
	drum_node.name = "Drum"
	drum_node.position = Vector2(vp.x * 0.5, vp.y - 130.0)
	drum_node.z_index = 5
	add_child(drum_node)

	# The drum is NOT scaled up on mobile, deliberately. This used to call
	# MobileUIManager.apply_game_object_scaling(drum_node), which multiplies
	# drum_node.scale by 1.4. Measured consequences (tools/logs/mobilepath.log):
	#
	#  * The drum lied about its own hitbox. The catch test in _process compares
	#    against the constant DRUM_HALF_WIDTH (70 px); scaling the node moved only
	#    the drawing. The drum appeared 98 px wide either side and caught 70 — 28 px
	#    of solid, visible drum let drops fall straight through, on the target
	#    platform and nowhere else.
	#  * It pushed the drum off screen. _shell_drag clamps the drum's POSITION to
	#    DRUM_MARGIN (80 px), not its extent, so at the clamp limit a 98 px
	#    half-width drum hung 18 px past the edge.
	#  * There was nothing to gain. _shell_drag teleports the drum to the pointer x,
	#    so the drum is never touched directly and a larger touch target buys
	#    nothing. And project.godot already stretches "canvas_items" from a
	#    1920x1080 base, so a 140 px drum is 7.3% of the screen width on every
	#    device — the proportional sizing a small panel needs is already done.
	#    Scaling here was compensating a second time for something already handled,
	#    and widening the catch to match would have made mobile accuracy
	#    incomparable with desktop accuracy in the research data.

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-60, -80), Vector2(60, -80),
		Vector2(70, 0), Vector2(60, 80),
		Vector2(-60, 80), Vector2(-70, 0),
	])
	body.color = Color(0.20, 0.42, 0.80)
	drum_node.add_child(body)

	# Water level: a FIXED polygon scaled from the drum bottom — fills are a
	# scale/position write, never a PackedVector2Array rebuild. Added BEFORE
	# the rim so the rim lip draws over the water surface.
	water_level = Polygon2D.new()
	water_level.polygon = PackedVector2Array([
		Vector2(-54, -60), Vector2(54, -60), Vector2(54, 76), Vector2(-54, 76),
	])
	water_level.color = Color(0.30, 0.70, 1.0, 0.65)
	water_level.scale = Vector2(1.0, 0.001)
	drum_node.add_child(water_level)

	var rim := Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-66, -86), Vector2(66, -86), Vector2(66, -74), Vector2(-66, -74),
	])
	rim.color = Color(0.14, 0.30, 0.60)
	drum_node.add_child(rim)


func _make_drop_factory() -> Callable:
	return func(idx: int) -> Node2D:
		var drop := Node2D.new()
		drop.name = "Drop_%d" % idx
		drop.set_meta("type", "raindrop")
		drop.set_meta("good", true)
		drop.z_index = 2

		var visual := Polygon2D.new()
		visual.name = "Visual"
		visual.polygon = PackedVector2Array([
			Vector2(0, -22), Vector2(13, 0), Vector2(9, 16),
			Vector2(0, 22), Vector2(-9, 16), Vector2(-13, 0),
		])
		visual.color = Color(0.25, 0.62, 1.0)
		drop.add_child(visual)

		# Dirty-drop X mark built from polygons — no Label, no font cost.
		var x_mark := Node2D.new()
		x_mark.name = "XMark"
		for dir in [-1.0, 1.0]:
			var stroke := Polygon2D.new()
			stroke.polygon = PackedVector2Array([
				Vector2(-11 * dir, -11), Vector2(-7 * dir, -11),
				Vector2(11 * dir, 11), Vector2(7 * dir, 11),
			])
			stroke.color = Color(0.55, 0.05, 0.05)
			x_mark.add_child(stroke)
		drop.add_child(x_mark)
		return drop


func _make_cloud_factory() -> Callable:
	return func(_idx: int) -> Node2D:
		var cloud := Node2D.new()
		cloud.z_index = -10
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-40, 0), Vector2(-30, -20), Vector2(0, -25),
			Vector2(30, -20), Vector2(40, 0), Vector2(30, 15),
			Vector2(-30, 15),
		])
		poly.color = Color(1, 1, 1, 0.85)
		cloud.add_child(poly)
		return cloud


## Slow looping drift+bob, tween-driven — the sky is never frozen.
func _start_cloud_drift(cloud: Node2D) -> void:
	var vp := get_viewport_rect().size
	cloud.position = Vector2(randf_range(60.0, vp.x - 60.0), randf_range(50.0, 190.0))
	var drift := cloud.create_tween().set_loops()
	var span := randf_range(18.0, 34.0)
	var period := randf_range(3.2, 5.0)
	drift.tween_property(cloud, "position:x", cloud.position.x + span, period) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(cloud, "position:x", cloud.position.x - span, period) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ── Round lifecycle ─────────────────────────────────────────────────────────

func _shell_start() -> void:
	drop_pool.release_all()
	# Fall speed is DERIVED from the screen, never authored. A drop must take
	# fall_time to travel from where it spawns to the drum, whatever the display is.
	# Authoring px/s instead made the round's fairness a function of screen height:
	# at Medium's 350 px/s, a 1920-tall portrait viewport put the drum 1725 px below
	# the clouds, so the first catchable drop arrived 4.9 s into a 10 s round. Half
	# the round was dead air, and the 8-catch quota needed 8 of the ~10 good drops
	# that could physically arrive. The soak log is the proof: AutoPlay's omniscient
	# driver — which snaps the drum onto the target every frame — lost every Medium
	# round 7-of-8 with zero mistakes. It also made the tiers non-monotone, since
	# Hard's faster drops delivered MORE supply than Medium's.
	var band_bottom := drum_node.position.y + CATCH_BAND_BOTTOM
	drop_speed = maxf(120.0, (band_bottom - SPAWN_Y) / maxf(fall_time, 0.2))
	drop_speed_current = drop_speed
	catch_band_height = maxf(CATCH_BAND_MIN_H, drop_speed * CATCH_WINDOW_S)
	spawn_timer = 0.0                     # first drop leaves the cloud on frame one
	vp_y_limit = get_viewport_rect().size.y + 40.0
	_update_water_fill()


# ── Input (event-driven, zero latency) ──────────────────────────────────────

func _shell_drag(pos: Vector2) -> void:
	# Snap directly — no lerp. This is THE feel fix.
	drum_node.position.x = clampf(
		pos.x, DRUM_MARGIN, get_viewport_rect().size.x - DRUM_MARGIN
	)


func _shell_tap(pos: Vector2) -> void:
	# A tap here is not aim, it is a paddle move — the same move a drag makes. The
	# shell deliberately leaves tap positions unmirrored (a tap has no direction to
	# reverse), so mirror it here or control_reverse would make the drum jump to the
	# raw finger x on touch-down and then snap to the mirrored x on the first drag.
	_shell_drag(_shell_map_drag(pos))


# ── Hot loop: arithmetic + visibility toggles only ──────────────────────────

func _process(delta) -> void:
	super._process(delta)
	if not game_active:
		return

	# Spawn
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_drop()
		spawn_timer = spawn_interval

	# Move + catch test, iterating the pool by index. Invisible items are
	# skipped in one branch — no Array build, no erase, no queue_free.
	var band_bottom := drum_node.position.y + CATCH_BAND_BOTTOM
	var band_top := band_bottom - catch_band_height
	var drum_x := drum_node.position.x
	for i in range(DROP_POOL_SIZE):
		var drop: Node2D = drop_pool.get_item(i)
		if not drop.visible:
			continue
		drop.position.y += drop_speed_current * delta
		if drop.position.y > band_top and drop.position.y < band_bottom:
			if absf(drop.position.x - drum_x) < DRUM_HALF_WIDTH:
				_on_caught(i, drop)
				continue
		if drop.position.y > vp_y_limit:
			drop_pool.release_index(i)

# ── Outcomes ────────────────────────────────────────────────────────────────

func _spawn_drop() -> void:
	var drop := drop_pool.acquire() as Node2D
	if drop == null:
		return  # pool exhausted = density cap reached; pressure stays bounded
	var is_good: bool = randf() > 0.28
	drop.set_meta("good", is_good)
	var visual: Polygon2D = drop.get_node("Visual")
	var x_mark: Node2D = drop.get_node("XMark")
	if is_good:
		visual.color = Color(0.25, 0.62, 1.0)
		x_mark.visible = false
	else:
		visual.color = Color(0.95, 0.35, 0.30)
		x_mark.visible = true
	drop.position = Vector2(
		randf_range(60.0, get_viewport_rect().size.x - 60.0), SPAWN_Y
	)


func _on_caught(idx: int, drop: Node2D) -> void:
	var is_good: bool = drop.get_meta("good")
	drop_pool.release_index(idx)
	if is_good:
		# Quota is counted here, not read off current_score: record_action awards
		# 10 + floor(streak/3)*5, so the score is not a tally of catches.
		caught_count += 1
		record_hit(drum_node)
		if caught_count >= target_score:
			Juice.pop(drum_node, 1.5, 0.4)
			_update_water_fill()
			end_game(true)
			return
	else:
		# Dirty water: the shell shakes the whole game, flashes red, resets combo.
		# The quota drops back a notch (the water level shows it) — but the HUD
		# number is the SCORE, written by record_action, so it must not be
		# overwritten with caught_count here: it used to flicker between the two
		# quantities, reading 30 after a catch and 3 after the next dirty drop.
		record_miss(drum_node)
		caught_count = maxi(caught_count - 1, 0)
	_update_water_fill()


## Partial credit for a timed-out round: the drum really did fill part-way, so
## the algorithm should see 3-of-8 as 0.375, not the binary 0.0 the base class
## would otherwise report. Uses the same ratio the water level draws.
func _get_objective_progress(success: bool) -> float:
	if success:
		return 1.0
	if target_score <= 0:
		return 0.0
	return clampf(float(caught_count) / float(target_score), 0.0, 1.0)


## Water rise IS the quota readout — visual, no numeric label, no allocation
## (scale/position writes on a fixed polygon).
func _update_water_fill() -> void:
	var fill := clampf(float(caught_count) / float(target_score), 0.0, 1.0)
	water_level.scale = Vector2(1.0, maxf(fill, 0.001))
	water_level.position = Vector2(0.0, 76.0 * (1.0 - fill))
