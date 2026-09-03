extends MicrogameShell

## BucketBrigade v2 — DWTD-style rebuild on MicrogameShell (thesis rehaul).
##
##   * ZERO allocation in the loop — every bucket lives in a fixed EntityPool
##     (built once in _shell_setup); people/source/garden are one-time nodes.
##     `bucket_at_person` is a pre-sized Array of nodes/null swapped in place.
##   * ZERO input latency — taps arrive through the shell's event-driven input
##     layer; the bucket leaves the person the same frame. No Area2D, no
##     polling, no lerp.
##   * Juice — pass = person pop + score punch; delivery = garden growth stage
##     + big pop. The DWTD timer bar is the pressure; stray taps stay
##     unpunished (kid-friendly legacy rule).
##
## AutoPlay contract preserved: `people` (Node2D array), `bucket_at_person`
## (bucket node or null per person) and `_handle_tap(pos)` — the
## bucket_brigade driver works unchanged.

const NUM_PEOPLE: int = 4
const BUCKET_POOL_SIZE: int = 6           # 4 waiting + 2 in transit
const TAP_RADIUS: float = 85.0            # fat, kid-friendly target
const BUCKET_SPEED: float = 700.0
const PERSON_ROW_OFF: float = 260.0       # people row above the bottom edge
const TARGET_GARDEN: int = NUM_PEOPLE     # bucket "target" meta value = garden

var people: Array = []                    # AutoPlay reads this
var bucket_at_person: Array = []          # AutoPlay reads this (node or null)
var bucket_pool: EntityPool

var buckets_delivered: int = 0
var target_buckets: int = 4
var spawn_timer: float = 0.0
var spawn_interval: float = 1.0

var garden_node: Node2D
var garden_face: Label
var _garden_pos: Vector2
var _source_pos: Vector2
var _vp_size: Vector2
## Round-local animation clock. The bucket sway ran off Time.get_ticks_msec(),
## which keeps advancing while the tree is paused (MobileUIManager pauses on focus
## loss), so every bucket in flight snapped to a new sway phase the moment play
## resumed — and the phase was a function of app uptime, so it never reset between
## rounds. Same defect class as FixLeakV2's drip clock.
var _anim_t: float = 0.0
## Per-person time of their last successful pass, on the _anim_t clock. Used only
## to tell an eager double-tap apart from a genuinely mistimed one.
var _passed_at: Array = []
## Grace window after a pass. See FixLeakV2 for why a wrong action has to exist at
## all: without one, accuracy is structurally 1.00 and mistakes_made structurally
## 0, so two of the three inputs to the rule-based difficulty score are constants.
const REPEAT_GRACE_SEC: float = 0.3

const GARDEN_STAGES: Array = ["🌱", "🌿", "🌼", "🌳", "🌳"]
const PERSON_FACES: Array = ["👦", "👧", "👨", "👩"]


func _init() -> void:
	# Before base _ready: AutoPlayManager.register_game reads game_name.
	# Localized: hardcoded English until now, so the HUD title ignored the chosen
	# language. has_text() guard rather than _loc() because _init() can run before
	# Localization is ready -- see FixLeakV2._init for the same idiom.
	game_name = (
		Localization.get_text("bucket_brigade")
		if Localization and Localization.has_text("bucket_brigade")
		else "Bucket Brigade"
	)
	# Hardcoded English until now, so the banner ignored the chosen language. The
	# wording also comes from the shared key rather than being a second copy of it:
	# scenes/minigames/BucketBrigade.gd already reads the same entry, and the two
	# families are the same interaction. has_text() guard: see FixLeakV2._init.
	game_instruction_text = (
		Localization.get_text("bucket_brigade_instructions")
		if Localization and Localization.has_text("bucket_brigade_instructions")
		else "TAP the person holding the bucket!\nPass it down the line to the garden! 🏺"
	)
	game_duration = 20.0
	game_mode = "quota"


func _shell_verb() -> String:
	return "PASS"


func _apply_difficulty_settings() -> void:
	# super() is what queues the chaos_effects the algorithm picked for this round
	# — one of the four adaptive outputs the thesis specifies. Without it this game
	# silently ran clean at every difficulty. It also seeds game_duration from
	# difficulty_settings["time_limit"]; the table below deliberately overrides
	# that with this game's own pacing.
	super._apply_difficulty_settings()
	# Legacy tuning table, kept 1:1 (the soak balance depends on it).
	match current_difficulty:
		"Easy":
			target_buckets = 3
			spawn_interval = 1.5
			game_duration = 20.0
		"Hard":
			target_buckets = 5
			spawn_interval = 0.8
			game_duration = 20.0
		_:
			target_buckets = 4
			spawn_interval = 1.0
			game_duration = 20.0

# ── Build (once) ────────────────────────────────────────────────────────────

func _shell_setup() -> void:
	_vp_size = get_viewport_rect().size
	_build_backdrop()
	_build_people()
	_build_ends()
	bucket_pool = _make_pool(_make_bucket_factory(), BUCKET_POOL_SIZE)


func _build_backdrop() -> void:
	var sky := Polygon2D.new()
	sky.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(_vp_size.x, 0),
		Vector2(_vp_size.x, _vp_size.y), Vector2(0, _vp_size.y)])
	sky.color = Color(0.55, 0.8, 0.95)
	add_child(sky)
	var grass := Polygon2D.new()
	grass.polygon = PackedVector2Array([
		Vector2(0, _vp_size.y - 170.0), Vector2(_vp_size.x, _vp_size.y - 170.0),
		Vector2(_vp_size.x, _vp_size.y), Vector2(0, _vp_size.y)])
	grass.color = Color(0.42, 0.68, 0.32)
	add_child(grass)


func _build_people() -> void:
	people.resize(NUM_PEOPLE)
	bucket_at_person.resize(NUM_PEOPLE)
	var start_x := _vp_size.x * 0.18
	var spacing := (_vp_size.x * 0.64) / float(NUM_PEOPLE - 1)
	for i in range(NUM_PEOPLE):
		var p := Node2D.new()
		p.position = Vector2(start_x + spacing * float(i), _vp_size.y - PERSON_ROW_OFF)
		var body := Label.new()
		body.text = PERSON_FACES[i]
		body.add_theme_font_size_override("font_size", 74)
		body.position = Vector2(-38, -54)
		p.add_child(body)
		var ring := Polygon2D.new()
		ring.name = "Ring"
		ring.polygon = _octagon(78.0)
		ring.color = Color(1.0, 0.78, 0.25, 0.55)
		ring.visible = false
		p.add_child(ring)
		add_child(p)
		people[i] = p
		bucket_at_person[i] = null


func _build_ends() -> void:
	_source_pos = Vector2(84.0, _vp_size.y - PERSON_ROW_OFF - 24.0)
	_garden_pos = Vector2(_vp_size.x - 84.0, _vp_size.y - PERSON_ROW_OFF - 24.0)
	var source := Label.new()
	source.text = "🚰"
	source.add_theme_font_size_override("font_size", 72)
	source.position = _source_pos + Vector2(-36, -50)
	add_child(source)
	garden_node = Node2D.new()
	garden_node.position = _garden_pos
	add_child(garden_node)
	garden_face = Label.new()
	garden_face.text = GARDEN_STAGES[0]
	garden_face.add_theme_font_size_override("font_size", 72)
	garden_face.position = Vector2(-36, -50)
	garden_node.add_child(garden_face)


func _make_bucket_factory() -> Callable:
	var factory := func(_i: int) -> Node:
		var b := Node2D.new()
		var water := Polygon2D.new()
		water.polygon = PackedVector2Array([
			Vector2(-26, -28), Vector2(26, -28),
			Vector2(22, 26), Vector2(-22, 26)])
		water.color = Color(0.4, 0.8, 1.0, 0.85)
		var body := Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-30, -35), Vector2(30, -35),
			Vector2(25, 30), Vector2(-25, 30)])
		body.color = Color(0.4, 0.5, 0.9)
		var rim := Polygon2D.new()
		rim.polygon = PackedVector2Array([
			Vector2(-33, -41), Vector2(33, -41),
			Vector2(30, -35), Vector2(-30, -35)])
		rim.color = Color(0.3, 0.4, 0.8)
		var handle := Line2D.new()
		handle.points = PackedVector2Array([
			Vector2(-22, -41), Vector2(0, -57), Vector2(22, -41)])
		handle.width = 5
		handle.default_color = Color(0.55, 0.55, 0.62)
		b.add_child(water)
		b.add_child(body)
		b.add_child(rim)
		b.add_child(handle)
		b.set_meta("target", -1)
		return b
	return factory


func _octagon(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(8)
	for k in range(8):
		var ang := TAU * float(k) / 8.0 + PI / 8.0
		pts[k] = Vector2(cos(ang), sin(ang)) * radius
	return pts

# ── Round lifecycle ─────────────────────────────────────────────────────────

func _shell_start() -> void:
	bucket_pool.release_all()
	buckets_delivered = 0
	_anim_t = 0.0
	_passed_at.resize(NUM_PEOPLE)
	_passed_at.fill(-999.0)
	for i in range(NUM_PEOPLE):
		bucket_at_person[i] = null
		(people[i] as Node2D).get_node("Ring").visible = false
	spawn_timer = 0.6
	_set_garden_stage(0)

# ── Hot loop: arithmetic + visibility toggles only ──────────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	if not game_active:
		return
	_anim_t += delta

	# Spawn only when the head of the line is free and nothing is inbound.
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		if bucket_at_person[0] == null and not _bucket_inbound(0):
			var nb := bucket_pool.acquire() as Node2D
			if nb != null:
				nb.position = _source_pos
				nb.set_meta("target", 0)
		spawn_timer = spawn_interval

	# Move / deliver. Index loop over the pool: no Array churn, no queue_free.
	for i in range(BUCKET_POOL_SIZE):
		var b: Node2D = bucket_pool.get_item(i)
		if not b.visible:
			continue
		var tgt: int = b.get_meta("target")
		if tgt < 0:
			continue  # waiting at a person
		var dest := _target_pos(tgt)
		var step := BUCKET_SPEED * delta
		if b.position.distance_squared_to(dest) <= step * step:
			b.position = dest
			b.set_meta("target", -1)
			if tgt == TARGET_GARDEN:
				_deliver(i)
			else:
				bucket_at_person[tgt] = b
				(people[tgt] as Node2D).get_node("Ring").visible = true
		else:
			b.position += (dest - b.position).normalized() * step
			b.rotation = sin(_anim_t * 6.0 + float(i)) * 0.08

	# Urgency rings pulse under waiting buckets (scale writes only).
	for pi in range(NUM_PEOPLE):
		if bucket_at_person[pi] != null:
			var ring: Polygon2D = (people[pi] as Node2D).get_node("Ring")
			var pulse := 1.0 + sin(_anim_t * 7.0) * 0.12
			ring.scale = Vector2(pulse, pulse)

# ── Input (event-driven) ────────────────────────────────────────────────────

func _shell_tap(pos: Vector2) -> void:
	_handle_tap(pos)


## Public: AutoPlayManager._play_bucket_brigade calls this with a person pos.
func _handle_tap(tap_pos: Vector2) -> void:
	if not game_active:
		return
	# Two passes, not one: with an 85 px hitbox two neighbours can both be under the
	# thumb, and whoever is actually holding a bucket is the person meant.
	var empty_handed: int = -1
	for i in range(NUM_PEOPLE):
		if not hit_test(tap_pos, (people[i] as Node2D).position, TAP_RADIUS):
			continue
		if bucket_at_person[i] != null:
			_pass_bucket(i)
			return
		if empty_handed < 0:
			empty_handed = i
	if empty_handed < 0:
		return  # thin air: a wasted swipe costs nothing, as in every other game here
	if _anim_t - float(_passed_at[empty_handed]) <= REPEAT_GRACE_SEC:
		return  # double-tap on the person who just handed their bucket on
	# Hurrying someone with nothing to pass — the one mistimed action this game has.
	record_miss(people[empty_handed])


func _pass_bucket(i: int) -> void:
	var b: Node2D = bucket_at_person[i]
	bucket_at_person[i] = null
	(people[i] as Node2D).get_node("Ring").visible = false
	_passed_at[i] = _anim_t  # arms the double-tap grace in _handle_tap
	record_hit(people[i])          # action + score punch + person pop
	b.set_meta("target", i + 1)    # next person, or the garden

# ── Helpers ─────────────────────────────────────────────────────────────────

func _bucket_inbound(target: int) -> bool:
	for i in range(BUCKET_POOL_SIZE):
		var b: Node2D = bucket_pool.get_item(i)
		if b.visible and int(b.get_meta("target")) == target:
			return true
	return false


## Partial credit: buckets already delivered count toward the algorithm's
## accuracy signal even when the round runs out of time.
func _get_objective_progress(success: bool) -> float:
	if success:
		return 1.0
	if target_buckets <= 0:
		return 0.0
	return clampf(float(buckets_delivered) / float(target_buckets), 0.0, 1.0)


func _target_pos(tgt: int) -> Vector2:
	if tgt >= NUM_PEOPLE:
		return _garden_pos
	return (people[tgt] as Node2D).position + Vector2(0.0, -20.0)


func _deliver(idx: int) -> void:
	buckets_delivered += 1
	bucket_pool.release_index(idx)
	_set_garden_stage(buckets_delivered)
	Juice.pop(garden_node, 1.45, 0.4)
	if buckets_delivered >= target_buckets:
		end_game(true)


func _set_garden_stage(n: int) -> void:
	garden_face.text = GARDEN_STAGES[mini(n, GARDEN_STAGES.size() - 1)]
