extends MicrogameShell

## FixLeak v2 — DWTD-style rebuild on MicrogameShell (thesis rehaul).
##
##   * ZERO allocation in the loop — all leak nodes live in a fixed EntityPool
##     (built once); each round only acquires num_leaks of them. `leaks` is a
##     pre-sized Array so the AutoPlay driver reads it without growing.
##   * ZERO input latency — taps land via the shell's event-driven layer with
##     fat hitboxes; the leak is patched the same frame. No Area2D.
##   * Pressure readout — wasted water rises up the wall as a red polygon
##     (scale write only, like CatchTheRain's water level). Drips bob via sin;
##     unfixed leaks pulse a ring. Fixing = pop + green patch.
##
## AutoPlay contract preserved: `leaks` (nodes with `fixed` meta) and
## `_on_leak_clicked(leak)` — the fix_leak driver works unchanged.

const LEAK_POOL_SIZE: int = 5            # num_leaks caps at 5
const TAP_RADIUS: float = 74.0            # 148-unit target: the 48dp floor on WVGA is 147
const WASTE_MAX_FRAC: float = 0.62       # how far up the screen waste rises
const SLOT_MIN_DIST_SQ: float = 19600.0  # 140px^2 between leaks
## WHERE A LEAK CAN APPEAR, AS A FRACTION OF THE SCREEN

##
## The slot search used absolute units — x[110, vp.x-110], y[210, vp.y-260] — against a scene whose
## Background and Wall were authored as fixed 1920x1080 / 1920x750 ColorRects with a Camera2D
## parked at (960, 540). At the design size those three agreed. Under stretch/aspect="expand" they
## did not: on a 2560x1080 landscape phone the camera centred the 1920-wide art, leaving 320 units
## of bare window down each side, while the slot search still read the 2560 the viewport reported
## and dropped leaks up to 210 units past the visible right edge — unreachable, and an unpatched
## leak wastes water until the round is lost. The camera is gone (it was inert at the design size
## and wrong everywhere else, and the other three shell scenes never had one), the two ColorRects
## are sized from the viewport in _shell_setup(), and the band below keeps leaks on the wall.
const WALL_TOP_FRAC: float = 0.139       # 150/1080 in the authored scene
const WALL_BOTTOM_FRAC: float = 0.833    # 900/1080
const LEAK_BAND_TOP_FRAC: float = 0.195  # 210/1080, inset inside the wall
const LEAK_BAND_BOTTOM_FRAC: float = 0.759  # (1080-260)/1080
const LEAK_SIDE_MARGIN: float = 110.0    # keeps the 148-unit tap target fully on screen
## Fraction of the round at which an untouched set of leaks fills the waste bar.

const WASTE_FAIL_FRACTION: float = 0.65
## One drop's fall: seconds per drop, distance covered, and the crack it exits.
const DRIP_PERIOD: float = 0.75
const DRIP_FALL: float = 46.0
const DRIP_SPOUT_Y: float = 14.0
## Grace window after patching a leak. A second tap on the same leak inside this
## window is the eager double-tap every kid on a laggy phone produces, not a wrong
## judgement, so it stays free; a tap on a leak that has visibly worn a patch for
## longer than this is a real misread of the screen and counts as a mistake.
## Without this the game had NO wrong action at all: accuracy was structurally
## 1.00 and mistakes_made structurally 0, so two of the three inputs to the
## rule-based difficulty score S = 0.6A + 0.3Spd - 0.1E were constants and only
## speed could ever move the difficulty. See tools/VerifyV2Signals.
const REPEAT_GRACE_SEC: float = 0.3

var leaks: Array = []                    # AutoPlay reads this
var leak_pool: EntityPool

var num_leaks: int = 3
var fixed_leaks: int = 0
var water_wasted: float = 0.0
var max_water_wasted: float = 100.0
var drip_speed: float = 1.0
## Waste units one unfixed leak adds per second; set by the difficulty table.
var waste_per_leak: float = 0.1
## Round-local animation clock. The drips and rings used to run off
## Time.get_ticks_msec(), which keeps advancing while the game is paused, so
## every leak jumped to a new phase the moment play resumed.
var _anim_t: float = 0.0

var waste_fill: Polygon2D
var _vp_size: Vector2
var _placed: PackedVector2Array = PackedVector2Array()
var _placed_count: int = 0


func _init() -> void:
	# _init() is the CONSTRUCTOR, and Localization fills its translations dictionary
	# in _ready(). In normal play autoloads are ready long before a minigame scene is
	# instantiated, so the lookup succeeds — but it is not guaranteed to be, and when
	# it is not, get_text() pushes "Missing translation key: fix_leak" and returns the
	# RAW KEY, which would then be displayed to the player as the game's title.
	# tools/SceneLoadCheck.gd instantiates scenes before autoload _ready() and showed
	# exactly that. has_text() is the project's own idiom for a lookup that has a
	# hardcoded fallback (see Localization.has_text and MiniGameBase._loc): it keeps
	# the Filipino/English title in the shipped game and falls back to readable
	# English instead of a key when the table is not up yet.
	game_name = (
		Localization.get_text("fix_leak")
		if Localization and Localization.has_text("fix_leak")
		else "Fix the Leak"
	)
	# Hardcoded English until now, so the banner did not follow the language the
	# player picked. Same has_text() idiom as game_name above; the key is new
	# ("fix_leak_instructions", plural) because the older singular one is a two-line
	# slogan that never names the objective — several leaks, one waste bar.
	game_instruction_text = (
		Localization.get_text("fix_leak_instructions")
		if Localization and Localization.has_text("fix_leak_instructions")
		else "TAP every leaking pipe to patch it!\nPatch them all before the water is wasted! 🔧"
	)
	game_duration = 18.0
	game_mode = "quota"


func _shell_verb() -> String:
	return "FIX"


func _apply_difficulty_settings() -> void:
	# Legacy FixLeak tuning, kept 1:1 (incl. the super call for time/chaos).
	super._apply_difficulty_settings()
	var complexity := int(get_difficulty_multiplier("task_complexity", 2))
	var speed_mult := get_difficulty_multiplier("speed_multiplier", 1.0)
	var base_time := get_difficulty_multiplier("time_limit", game_duration)

	num_leaks = clampi(complexity + 1, 2, LEAK_POOL_SIZE)
	drip_speed = clampf(speed_mult, 0.8, 1.3)
	game_duration = base_time + float(num_leaks) * 2.5
	max_water_wasted = 55.0 + float(num_leaks) * 15.0

	if current_difficulty == "Hard":
		drip_speed = minf(drip_speed * 1.15, 1.45)
		max_water_wasted = maxf(70.0, max_water_wasted * 0.85)
		game_duration = maxf(14.0, game_duration - 2.0)

	# Derive the bleed rate from the round length instead of a flat 0.1/s per leak.
	# At the old rate an untouched Easy round needed 531s to fill an 85-unit bar
	# inside a 25s clock, so the waste fail path was unreachable at every tier and
	# the rising red "pressure" readout climbed 4% in a whole round -- the game's one
	# educational point (an unfixed leak keeps costing you) had neither consequence
	# nor a visible slope. Now leaving every leak dripping fills the bar at
	# WASTE_FAIL_FRACTION of the clock, while each leak patched removes its share, so
	# a player who actually works never reaches it.
	waste_per_leak = max_water_wasted / maxf(
		game_duration * WASTE_FAIL_FRACTION * float(num_leaks), 0.001)

# ── Build (once) ────────────────────────────────────────────────────────────

func _shell_setup() -> void:
	_vp_size = get_viewport_rect().size
	_placed.resize(LEAK_POOL_SIZE)

	# The scene's two authored ColorRects are the whole backdrop, and they were sized
	# 1920x1080 / y[150,900] to agree with a Camera2D that no longer exists. Sizing them
	# from the live viewport does two things: the sky covers the window on a wider or
	# taller device instead of letting the grey clear-colour show down the sides, and the
	# wall band tracks the same fraction of screen height the leak band below does — with
	# the wall pinned at 900 and the band running to _vp_size.y - 260, a 1920x1440 tablet
	# put leaks at y up to 1180, i.e. floating in the sky under the wall.
	var sky: ColorRect = $Background
	sky.size = _vp_size
	var wall: ColorRect = $Wall
	wall.position = Vector2(0.0, _vp_size.y * WALL_TOP_FRAC)
	wall.size = Vector2(_vp_size.x, _vp_size.y * (WALL_BOTTOM_FRAC - WALL_TOP_FRAC))

	# Rising waste water — origin at bottom-centre, points upward, so scale.y
	# IS the fill fraction. Same trick as CatchTheRain's water level.
	waste_fill = Polygon2D.new()
	var h := _vp_size.y * WASTE_MAX_FRAC
	waste_fill.polygon = PackedVector2Array([
		Vector2(-_vp_size.x * 0.5, 0.0), Vector2(_vp_size.x * 0.5, 0.0),
		Vector2(_vp_size.x * 0.5, -h), Vector2(-_vp_size.x * 0.5, -h)])
	waste_fill.color = Color(0.85, 0.25, 0.2, 0.55)
	waste_fill.position = Vector2(_vp_size.x * 0.5, _vp_size.y)
	add_child(waste_fill)

	leak_pool = _make_pool(_make_leak_factory(), LEAK_POOL_SIZE)
	leaks.resize(LEAK_POOL_SIZE)           # pre-sized once for AutoPlay
	for i in range(LEAK_POOL_SIZE):
		leaks[i] = leak_pool.get_item(i)


func _make_leak_factory() -> Callable:
	var factory := func(_i: int) -> Node:
		var leak := Node2D.new()
		var pipe := Polygon2D.new()
		pipe.polygon = PackedVector2Array([
			Vector2(-70, -16), Vector2(70, -16),
			Vector2(70, 16), Vector2(-70, 16)])
		pipe.color = Color(0.52, 0.52, 0.58)
		var ring := Polygon2D.new()
		ring.name = "Ring"
		ring.polygon = _octagon(52.0)
		ring.color = Color(1.0, 0.75, 0.2, 0.5)
		var crack := Line2D.new()
		crack.name = "Crack"
		crack.points = PackedVector2Array([
			Vector2(-14, -14), Vector2(-4, -4), Vector2(-10, 4), Vector2(2, 14)])
		crack.width = 7
		crack.default_color = Color(0.85, 0.2, 0.15)
		var drip := ColorRect.new()
		drip.name = "Drip"
		drip.size = Vector2(12, 18)
		drip.position = Vector2(-6, 16)
		drip.color = Color(0.3, 0.7, 1.0)
		# Controls STOP clicks by default; a Drip sits dead-centre on its
		# leak, so without this it would eat taps aimed at the leak itself.
		drip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# scale grows from the top edge, so a falling drop stretches downward.
		drip.pivot_offset = Vector2(drip.size.x * 0.5, 0.0)
		var patch := Polygon2D.new()
		patch.name = "Patch"
		patch.polygon = _octagon(34.0)
		patch.color = Color(0.25, 0.75, 0.4)
		patch.visible = false
		leak.add_child(pipe)
		leak.add_child(ring)
		leak.add_child(crack)
		leak.add_child(drip)
		leak.add_child(patch)
		leak.set_meta("fixed", false)
		return leak
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
	leak_pool.release_all()
	fixed_leaks = 0
	water_wasted = 0.0
	_anim_t = 0.0
	_placed_count = 0
	for i in range(num_leaks):
		var leak := leak_pool.acquire() as Node2D
		if leak == null:
			break  # pool exhausted = leak count cap
		leak.position = _find_slot()
		leak.set_meta("fixed", false)
		(leak.get_node("Drip") as ColorRect).visible = true
		(leak.get_node("Crack") as Line2D).visible = true
		(leak.get_node("Ring") as Node2D).visible = true
		(leak.get_node("Patch") as Node2D).visible = false
	_update_waste_fill()


## Non-overlapping slot search writing into a pre-sized PackedVector2Array —
## no per-round Array allocation (runs once per round, kept clean anyway).
func _find_slot() -> Vector2:
	var c := Vector2.ZERO
	for _attempt in range(20):
		c = Vector2(
			randf_range(LEAK_SIDE_MARGIN, _vp_size.x - LEAK_SIDE_MARGIN),
			randf_range(_vp_size.y * LEAK_BAND_TOP_FRAC,
				_vp_size.y * LEAK_BAND_BOTTOM_FRAC))
		var ok := true
		var j := 0
		while j < _placed_count:
			if c.distance_squared_to(_placed[j]) < SLOT_MIN_DIST_SQ:
				ok = false
				break
			j += 1
		if ok:
			break
	_placed[_placed_count] = c
	_placed_count += 1
	return c

# ── Hot loop: sin writes + scale writes only ────────────────────────────────

func _process(delta: float) -> void:
	super._process(delta)
	if not game_active:
		return
	_anim_t += delta
	var unfixed := 0
	for i in range(LEAK_POOL_SIZE):
		var leak: Node2D = leak_pool.get_item(i)
		if not leak.visible:
			continue
		if leak.get_meta("fixed"):
			continue
		unfixed += 1
		var ring: Node2D = leak.get_node("Ring")
		var pulse := 1.0 + sin(_anim_t * 8.0 + float(i) * 1.7) * 0.14
		ring.scale = Vector2(pulse, pulse)

		# A drop falls, then the next one starts at the crack. The old version bobbed
		# position.y on sin() between 10 and 22 while fading on a SECOND sine of an
		# unrelated period carrying no per-leak offset, so every leak in the scene
		# blinked in unison and none of them ever read as water leaving the pipe.
		var drip: ColorRect = leak.get_node("Drip")
		var ph: float = fmod(
			_anim_t * drip_speed / DRIP_PERIOD + float(i) * 0.31, 1.0)
		drip.position.y = DRIP_SPOUT_Y + ph * DRIP_FALL
		# Gone before it lands, so the next drop reads as a new one.
		drip.modulate.a = clampf((1.0 - ph) * 2.5, 0.0, 1.0)
		# Thins and lengthens as it accelerates: the standard falling-water read.
		drip.scale = Vector2(1.0 - ph * 0.35, 1.0 + ph * 0.8)
	if unfixed > 0:
		water_wasted = minf(
			water_wasted + delta * waste_per_leak * float(unfixed), max_water_wasted)
		_update_waste_fill()
		if water_wasted >= max_water_wasted:
			_fail()

# ── Input (event-driven, fat hitboxes) ──────────────────────────────────────

func _shell_tap(pos: Vector2) -> void:
	if not game_active:
		return
	# Two passes, not one: an unfixed leak under the same fat 74 px hitbox is always
	# the target the player meant, whichever pool slot it happens to occupy. And within
	# the unfixed ones it is the NEAREST, not the first: slots sit 140 units apart
	# (SLOT_MIN_DIST_SQ) and the radius is 74, so two leaks can share the finger.
	var patched: Node2D = null
	var nearest: Node2D = null
	var nearest_d: float = INF
	for i in range(LEAK_POOL_SIZE):
		var leak: Node2D = leak_pool.get_item(i)
		if not leak.visible:
			continue
		if not hit_test(pos, leak.position, TAP_RADIUS):
			continue
		if not leak.get_meta("fixed"):
			var d: float = pos.distance_squared_to(leak.position)
			if d < nearest_d:
				nearest_d = d
				nearest = leak
			continue
		if patched == null:
			patched = leak
	if nearest != null:
		_on_leak_clicked(nearest)
		return
	if patched == null:
		return  # bare wall: a wasted swipe costs nothing, as in every other game here
	if _anim_t - float(patched.get_meta("fixed_at", -999.0)) <= REPEAT_GRACE_SEC:
		return  # double-tap on the leak just patched
	# Patching the same pipe twice: shake, red flash, combo reset, mistake counted.
	record_miss(patched)


## Public: AutoPlayManager._play_fix_leak calls this for each unfixed leak.
func _on_leak_clicked(leak: Node2D) -> void:
	if not game_active or leak.get_meta("fixed"):
		return
	leak.set_meta("fixed", true)
	leak.set_meta("fixed_at", _anim_t)  # arms the double-tap grace in _shell_tap
	fixed_leaks += 1
	(leak.get_node("Drip") as ColorRect).visible = false
	(leak.get_node("Crack") as Line2D).visible = false
	(leak.get_node("Ring") as Node2D).visible = false
	(leak.get_node("Patch") as Node2D).visible = true
	record_hit(leak)  # action + score punch + elastic pop
	if fixed_leaks >= num_leaks:
		end_game(true)

# ── Outcomes ────────────────────────────────────────────────────────────────

func _fail() -> void:
	# Time/waste failure is not a player action — no accuracy penalty, just
	# the juice: shake + flash, then the base tally handles the rest.
	Juice.shake(self, Juice.SHAKE_STRENGTH, 0.35)
	Juice.flash(shell_flash_rect, Color(0.93, 0.29, 0.26, 0.35), 0.3)
	end_game(false)


## Partial credit: 2 of 3 leaks patched before the waste bar filled is 0.667,
## not the binary 0.0 the base class would report for a loss.
func _get_objective_progress(success: bool) -> float:
	if success:
		return 1.0
	if num_leaks <= 0:
		return 0.0
	return clampf(float(fixed_leaks) / float(num_leaks), 0.0, 1.0)


func _update_waste_fill() -> void:
	var frac := clampf(water_wasted / maxf(max_water_wasted, 0.001), 0.0, 1.0)
	waste_fill.scale = Vector2(1.0, maxf(frac, 0.001))
