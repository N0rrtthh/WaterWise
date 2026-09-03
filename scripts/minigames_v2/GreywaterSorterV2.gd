extends MicrogameShell

## GreywaterSorter v2 — DWTD-style rebuild on MicrogameShell (thesis rehaul).
##
##   * ZERO allocation in the loop — all buckets live in a fixed EntityPool
##     (built once); falling = position writes, misses = release to pool.
##     `buckets` is pre-sized so the AutoPlay driver reads it without growing.
##   * ZERO input latency — grab/drag/release come straight from the shell's
##     event layer; the bucket tracks the finger's x the same frame (held
##     buckets freeze their fall, DWTD-style). No polling, no lerp.
##   * Juice — correct sort = zone punch + bucket zooms into the zone; wrong
##     sort = full-game shake + red flash + combo reset. No queue_free.
##
## AutoPlay contract preserved: `buckets` (nodes with `safe`/`being_sorted`
## meta), `current_bucket`, `is_swiping` and `_sort_bucket(bucket, to_garden)`
## — the greywater_sorter driver works unchanged.

const BUCKET_POOL_SIZE: int = 8
const GRAB_RADIUS: float = 80.0
const ZONE_LEFT_X: float = 0.30    # release left of this → garden
const ZONE_RIGHT_X: float = 0.70   # release right of this → drain

var buckets: Array = []            # AutoPlay reads this
var bucket_pool: EntityPool
var current_bucket: Node2D = null  # AutoPlay reads/writes this
var is_swiping: bool = false       # AutoPlay resets this

var sorted_correct: int = 0
var target_sort: int = 8
var spawn_timer: float = 0.0
var spawn_interval: float = 0.7
## Authored difficulty knob: the SECONDS a bucket takes to cross the board.
## bucket_speed is derived from it per round — see _shell_start().
var bucket_fall_time: float = 5.73
## Derived, never authored. Kept as a member because the hot loop reads it
## every frame and tools/VerifyAspectSupply.gd measures it.
var bucket_speed: float = 220.0
var max_on_screen: int = 4

var garden_zone: Node2D
var drain_zone: Node2D
var _vp_size: Vector2


func _init() -> void:
	# Localized: hardcoded English until now, so the HUD title ignored the chosen
	# language. has_text() guard rather than _loc() because _init() can run before
	# Localization is ready -- see FixLeakV2._init for the same idiom.
	game_name = (
		Localization.get_text("greywater_sorter")
		if Localization and Localization.has_text("greywater_sorter")
		else "Greywater Sorter"
	)
	# Hardcoded English until now, so the banner ignored the chosen language. Shares
	# the key with scenes/minigames/GreywaterSorter.gd, which is the same interaction.
	# has_text() guard: see FixLeakV2._init.
	game_instruction_text = (
		Localization.get_text("greywater_sorter_instructions")
		if Localization and Localization.has_text("greywater_sorter_instructions")
		else "SWIPE buckets left or right!\n🌿 Garden = Blue | 🚿 Drain = Brown"
	)
	game_duration = 15.0
	game_mode = "quota"


func _shell_verb() -> String:
	return "SWIPE"


func _apply_difficulty_settings() -> void:
	# super() is what queues the chaos_effects the algorithm picked for this round
	# — one of the four adaptive outputs the thesis specifies. Without it this game
	# silently ran clean at every difficulty. It also seeds game_duration from
	# difficulty_settings["time_limit"]; the table below deliberately overrides
	# that with this game's own pacing.
	super._apply_difficulty_settings()
	# Legacy tuning table, with ONE deliberate change of units: the fall is
	# authored as the SECONDS a bucket spends crossing the board, not as px/s.
	# bucket_speed is derived from it in _shell_start(). The seconds below are the
	# exact dwell the old px/s figures produced on the 1920x1080 design base
	# ((1080 + 180) / 150, / 220, / 320), so the soak balance the comment protects
	# is unchanged on that panel and now holds on every other one too.
	#
	# Why it mattered: project.godot stretches "canvas_items" with aspect "expand",
	# so in landscape the visible height runs 1080 on a phone up to 1440 on a 4:3
	# tablet. At the old fixed 150 px/s an Easy bucket took (1440 + 180) / 150 =
	# 10.8 s to cross a tablet, and with only 3 slots that caps the round at
	# 18 x 3 / 10.8 = 5.0 buckets against a quota of 6 — an Easy round that cannot
	# be won, on the tier the adaptive algorithm sends a STRUGGLING player to.
	# Measured in tools/logs/aspect.log before this change.
	match current_difficulty:
		"Easy":
			spawn_interval = 1.0
			bucket_fall_time = 8.4
			target_sort = 6
			# 4, not 3. This is the forgiveness knob — how many buckets may
			# coexist — and it is the only lever that widens the starved case
			# without touching speed or quota, so the authored demand ladder
			# (6/18s, 8/15s, 10/12s sorts per second) is left exactly as it was.
			# At 3 slots the fully-clogged ceiling cleared the quota by 1.07x on
			# the design base and fell UNDER it on a tablet; at 4 it clears by
			# 1.43x at every aspect.
			max_on_screen = 4
			game_duration = 18.0
		"Hard":
			spawn_interval = 0.4
			bucket_fall_time = 3.94
			target_sort = 10
			max_on_screen = 5
			game_duration = 12.0
		_:
			spawn_interval = 0.7
			bucket_fall_time = 5.73
			target_sort = 8
			max_on_screen = 4
			game_duration = 15.0

# ── Build (once) ────────────────────────────────────────────────────────────

func _shell_setup() -> void:
	_vp_size = get_viewport_rect().size

	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(_vp_size.x, 0),
		Vector2(_vp_size.x, _vp_size.y), Vector2(0, _vp_size.y)])
	bg.color = Color(0.85, 0.9, 0.95)
	add_child(bg)

	garden_zone = _build_zone(0.0, 0.25, Color(0.3, 0.7, 0.3, 0.35), "🌿 GARDEN")
	drain_zone = _build_zone(0.75, 0.25, Color(0.5, 0.4, 0.4, 0.35), "🚿 DRAIN")

	bucket_pool = _make_pool(_make_bucket_factory(), BUCKET_POOL_SIZE)
	buckets.resize(BUCKET_POOL_SIZE)      # pre-sized once for AutoPlay
	for i in range(BUCKET_POOL_SIZE):
		buckets[i] = bucket_pool.get_item(i)


func _build_zone(x0_frac: float, width_frac: float, col: Color, label_text: String) -> Node2D:
	var zw := _vp_size.x * width_frac
	var zc := Node2D.new()
	zc.position = Vector2(_vp_size.x * x0_frac + zw * 0.5, _vp_size.y * 0.5)
	var panel := Polygon2D.new()
	var hw := zw * 0.5
	var hh := _vp_size.y * 0.5
	panel.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh),
		Vector2(hw, hh), Vector2(-hw, hh)])
	panel.color = col
	zc.add_child(panel)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.position = Vector2(-110.0, -hh + 40.0)
	zc.add_child(lbl)
	add_child(zc)
	return zc


func _make_bucket_factory() -> Callable:
	var factory := func(_i: int) -> Node:
		var b := Node2D.new()
		var body := Polygon2D.new()
		body.name = "Body"
		body.polygon = PackedVector2Array([
			Vector2(-45, -50), Vector2(45, -50),
			Vector2(40, 50), Vector2(-40, 50)])
		var water := Polygon2D.new()
		water.name = "Water"
		water.polygon = PackedVector2Array([
			Vector2(-40, -40), Vector2(40, -40),
			Vector2(35, 45), Vector2(-35, 45)])
		water.color = Color(0.4, 0.75, 1.0, 0.7)
		var rim := Polygon2D.new()
		rim.name = "Rim"
		rim.polygon = PackedVector2Array([
			Vector2(-48, -55), Vector2(48, -55),
			Vector2(48, -45), Vector2(-48, -45)])
		b.add_child(body)
		b.add_child(water)
		b.add_child(rim)
		b.set_meta("safe", true)
		b.set_meta("being_sorted", false)
		return b
	return factory

# ── Round lifecycle ─────────────────────────────────────────────────────────

func _shell_start() -> void:
	bucket_pool.release_all()
	sorted_correct = 0
	current_bucket = null
	is_swiping = false
	spawn_timer = 0.3
	# Speed is DERIVED from the live viewport, never authored. A bucket must take
	# bucket_fall_time to cross from its spawn at SPAWN_Y = -90 to the release line
	# at vp.y + 90, whatever panel the game is on — the same correction
	# CatchTheRainV2 needed, for the same reason: authoring px/s makes the round's
	# winnability a function of screen height. Re-read here rather than trusting
	# _vp_size so a mid-session resize is picked up on the next round.
	var vp := get_viewport_rect().size
	_vp_size = vp
	bucket_speed = maxf(80.0, (vp.y + 180.0) / maxf(bucket_fall_time, 0.5))

# ── Hot loop: position writes + visibility toggles only ─────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	if not game_active:
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		if bucket_pool.active_count < max_on_screen:
			_spawn_bucket()
			spawn_timer = spawn_interval
		else:
			# A BLOCKED spawn used to reset the full interval, so a board that was
			# briefly full cost a whole bucket even if a slot freed a frame later.
			# Retry soon instead: the gate is meant to cap how many buckets coexist,
			# not to punish the moment one is sorted. Not zero — that would spawn on
			# the very next frame and turn the cap into a burst.
			spawn_timer = 0.1

	for i in range(BUCKET_POOL_SIZE):
		var b: Node2D = bucket_pool.get_item(i)
		if not b.visible:
			continue
		if b == current_bucket:
			continue  # held: x follows the finger, y frozen
		b.position.y += bucket_speed * delta
		if b.position.y > _vp_size.y + 90.0:
			bucket_pool.release_index(i)  # missed bucket: no penalty (legacy)

# ── Input (event-driven, zero latency) ──────────────────────────────────────

func _shell_tap(pos: Vector2) -> void:
	if current_bucket != null:
		return
	for i in range(BUCKET_POOL_SIZE - 1, -1, -1):  # topmost first
		var b: Node2D = bucket_pool.get_item(i)
		if not b.visible:
			continue
		if hit_test(pos, b.position, GRAB_RADIUS):
			current_bucket = b
			is_swiping = true
			b.scale = Vector2.ONE * 1.15
			return


func _shell_drag(pos: Vector2) -> void:
	if current_bucket != null:
		current_bucket.position.x = clampf(pos.x, 50.0, _vp_size.x - 50.0)


func _shell_release(_pos: Vector2) -> void:
	if current_bucket == null:
		return
	var b := current_bucket
	current_bucket = null
	is_swiping = false
	b.scale = Vector2.ONE
	# Judge the drop by where the BUCKET is, not where the finger is. The two
	# disagree in two real cases: control_reverse mirrors drag input, so a finger
	# on the right leaves the bucket over the garden on the left (deciding by
	# finger would score the drum the player can plainly see over the garden as a
	# drain drop); and a grab inside the fat 106 px hitbox followed by a release
	# with no drag never moved the bucket at all. What you see is what you get.
	var bx := b.position.x
	if bx < _vp_size.x * ZONE_LEFT_X:
		_sort_bucket(b, true)
	elif bx > _vp_size.x * ZONE_RIGHT_X:
		_sort_bucket(b, false)
	else:
		_release_bucket(b)  # dropped mid-screen: bucket is lost (legacy)

# ── Outcomes ────────────────────────────────────────────────────────────────

func _spawn_bucket() -> void:
	var b := bucket_pool.acquire() as Node2D
	if b == null:
		return  # pool exhausted = density cap
	var safe := randf() > 0.5
	b.set_meta("safe", safe)
	b.set_meta("being_sorted", false)
	var body := b.get_node("Body") as Polygon2D
	var water := b.get_node("Water") as Polygon2D
	var rim := b.get_node("Rim") as Polygon2D
	if safe:
		body.color = Color(0.3, 0.6, 0.9)
		water.color = Color(0.4, 0.75, 1.0, 0.7)
	else:
		body.color = Color(0.55, 0.4, 0.3)
		water.color = Color(0.5, 0.45, 0.4, 0.7)
	rim.color = body.color.darkened(0.2)
	b.position = Vector2(randf_range(_vp_size.x * 0.34, _vp_size.x * 0.66), -90.0)
	b.scale = Vector2.ONE
	b.modulate = Color.WHITE


## Public: AutoPlayManager._play_greywater_sorter calls this with the correct
## destination for each bucket.
func _sort_bucket(bucket: Node2D, to_garden: bool) -> void:
	if not game_active or not is_instance_valid(bucket):
		return
	if not bucket.visible:
		return
	var safe: bool = bucket.get_meta("safe")
	var correct := (safe == to_garden)
	var zone: Node2D = garden_zone if to_garden else drain_zone
	if correct:
		sorted_correct += 1
		record_hit(zone)  # action + score punch + zone pop
		var dest_x := -140.0 if to_garden else _vp_size.x + 140.0
		var tw := create_tween()
		tw.tween_property(bucket, "position:x", dest_x, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(_release_bucket.bind(bucket))
		if sorted_correct >= target_sort:
			end_game(true)
	else:
		record_miss(bucket)  # shake + red flash + combo reset
		var tw := create_tween()
		tw.tween_property(bucket, "modulate:a", 0.0, 0.3)
		tw.tween_callback(_release_bucket.bind(bucket))


## Partial credit: buckets already sorted correctly count toward the algorithm's
## accuracy signal even when the round times out short of the quota.
func _get_objective_progress(success: bool) -> float:
	if success:
		return 1.0
	if target_sort <= 0:
		return 0.0
	return clampf(float(sorted_correct) / float(target_sort), 0.0, 1.0)


func _release_bucket(b: Node2D) -> void:
	b.scale = Vector2.ONE
	b.modulate = Color.WHITE
	bucket_pool.release(b)
