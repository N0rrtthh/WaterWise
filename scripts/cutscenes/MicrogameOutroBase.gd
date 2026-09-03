class_name MicrogameOutroBase
extends Control

## Shared stage for AUTHORED "Dumb Ways to Waste" beat clips.
##
## Every win/lose outro is a .tscn under res://scenes/ui/cutscenes/beats/
## whose root script extends this class, so MiniGameBase can call
## play_win() / play_lose() identically on any of them.
##
## The 4-beat rhythm is owned here (per-game scenes only override hooks):
##   1. SETUP        0.40 s  — cast settles; TRANS_BACK/ELASTIC entrances
##   2. IMPACT HOLD  0.20 s  — frozen peak frame. Camera punch (<150 ms),
##                             white flash, GPUParticles2D burst and the
##                             audio stinger ALL fire on this exact tick.
##   3. PAYOFF       1.20 s  — consequence, reactions, punchline
##   4. SNAP         0.25 s  — TransitionLayer whip/zoom/flash cut out
##   Total ≈ 2.05 s (spec: 2.0–2.5 s)
##
## Tone contract for LOSE clips: the crowd reads deadpan/slapstick-amused,
## never cruel — chirpy staging over Dribble's bad time.
##
## Performance: nodes are allocated once in _ensure_built(); the timeline is
## a single Tween; bursts are one-shot GPUParticles2D that free themselves.

signal outro_finished

const DESIGN_SIZE: Vector2 = Vector2(1152.0, 648.0)
const GROUND_FRACTION: float = 0.72
const ACTOR_SCALE: float = 1.35
const SKIP_LOCKOUT_SEC: float = 0.45
const CAMERA_PUNCH_SEC: float = 0.14  # hard contract: under 150 ms

## A skipped clip still holds its payoff frame this long before snapping out. Same principle and
## same number as CartoonStage.SKIP_PAYOFF_HOLD_SEC: a tap ends the WAITING, not the punchline.
## Not divided by speed_scale — it is a perceptual minimum, not a beat length.
const SKIP_PAYOFF_HOLD_SEC: float = 0.4

## Placeholder stinger paths — drop real audio in at these exact filenames.
const STINGER_WIN_PATH := "res://audio/sfx/cutscenes/stinger_win_impact.ogg"
const STINGER_LOSE_PATH := "res://audio/sfx/cutscenes/stinger_lose_impact.ogg"

## Low-end devices play clips FASTER, never skipped (same policy as
## CartoonStage). MiniGameBase sets this from _get_cartoon_speed(), and
## MiniGameIntroBridge from its own; both can ask for 5.1x (1.7 low-end x 3.0 reduced motion).
##
## The setter refuses the part of that request that would destroy the punchline. Every beat
## interval is divided by this value, so at 5.1x the payoff beat is 1.20 / 5.1 = 0.235s - below
## SKIP_PAYOFF_HOLD_SEC, the 0.4s this class already treats as the minimum time the payoff frame
## needs on screen when a player SKIPS the clip. A frame that is too short to read when skipped is
## just as unreadable when compressed, so the cap comes from that same number rather than a new
## one: _payoff_sec() / SKIP_PAYOFF_HOLD_SEC, which is 3.0x for an outro and 1.5x for the shorter
## intro. Measured before the cap: 0.284s from payoff to finish on outros and 0.167s on intros
## (tools/VerifyOutroCompression.tscn).
##
## Deliberately a cap and not a rejection: the low-end 1.7x is honoured in full, and the request
## is only trimmed where it would cost comprehension. CartoonStage needs no equivalent - its holds
## carry a caption reading floor that is pre-multiplied by speed_scale, so they cannot be
## compressed below readability either.
var speed_scale: float = 1.0:
	set(value):
		speed_scale = minf(maxf(value, 0.05), _max_speed())

## Fastest this clip may be asked to play. See speed_scale.
func _max_speed() -> float:
	return maxf(_payoff_sec() / SKIP_PAYOFF_HOLD_SEC, 1.0)

# Stage nodes
var world: Node2D
var camera: Camera2D
var stinger: AudioStreamPlayer
var flash_rect: ColorRect
var transition: TransitionLayer

# Cast (staged by per-game scenes via _setup_stage)
var dribble: CartoonActor
var mayor: CartoonActor
var townsfolk: Array[CartoonActor] = []

var win: bool = false

var _vp: Vector2 = DESIGN_SIZE
var _content_scale: float = 1.0
var _built: bool = false
var _finished: bool = false
var _elapsed: float = 0.0
var _timeline: Tween

## Skip bookkeeping. _beat_reached is which of the four beats has fired (0 none, 1 setup,
## 2 impact, 3 payoff) and _payoff_at is the clip time the payoff opened, so _run_skip_tail()
## can work out what the player has not seen yet instead of firing everything at once.
var _skipping: bool = false
var _beat_reached: int = 0
var _payoff_at: float = 0.0

static var _dot_tex: GradientTexture2D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = get_viewport_rect().size

# ── Public API ────────────────────────────────────────────────────────────

func play_win() -> void:
	win = true
	_run()

func play_lose() -> void:
	win = false
	_run()

func _run() -> void:
	_ensure_built()
	_setup_stage()
	_run_timeline()

# ── Beat timeline ─────────────────────────────────────────────────────────

## Beat lengths are virtual so MicrogameIntroBase can compress the same
## rhythm into its 1.0–1.5 s budget without touching this file.
func _setup_sec() -> float: return 0.40
func _impact_hold_sec() -> float: return 0.20
func _payoff_sec() -> float: return 1.20
func _snap_sec() -> float: return 0.25

func _run_timeline() -> void:
	_timeline = create_tween()
	# BEAT 1 — SETUP
	_timeline.tween_callback(_do_setup)
	_timeline.tween_interval(_setup_sec() / speed_scale)
	# BEAT 2 — IMPACT: punch + flash + burst + stinger fire EXACTLY here,
	# then the frame HOLDS.
	_timeline.tween_callback(_do_impact)
	_timeline.tween_interval(_impact_hold_sec() / speed_scale)
	# BEAT 3 — PAYOFF
	_timeline.tween_callback(_do_payoff)
	_timeline.tween_interval(_payoff_sec() / speed_scale)
	# BEAT 4 — SNAP
	_timeline.tween_callback(_beat_snap)
	_timeline.tween_interval(_snap_sec() / speed_scale)
	_timeline.tween_callback(_finish)

## The first three beats are fired through these wrappers so the skip path knows how far the clip
## actually got. Per-game scenes override the hooks these call (_beat_setup / _on_impact /
## _beat_payoff), never these.
func _do_setup() -> void:
	_beat_reached = 1
	_beat_setup()

func _do_impact() -> void:
	_beat_reached = 2
	_on_impact()

func _do_payoff() -> void:
	_beat_reached = 3
	_payoff_at = _elapsed
	_beat_payoff()

## Per-game scenes stage their cast, props and palette here.
func _setup_stage() -> void: pass

## BEAT 1 hook: entrances (use TRANS_BACK/ELASTIC — never TRANS_LINEAR).
func _beat_setup() -> void: pass

## BEAT 2 hook. Outro default satisfies the win/lose requirements (punch,
## flash, burst, stinger). Intros override to skip the punch/burst.
func _on_impact() -> void:
	_impact_flash()
	_camera_punch()
	_play_stinger()
	_spawn_burst(_impact_point(), not win)

## BEAT 3 hook: the consequence.
func _beat_payoff() -> void: pass

## BEAT 4 hook: never a plain fade.
func _beat_snap() -> void:
	var kind := TransitionLayer.Snap.ZOOM_SNAP if win else TransitionLayer.Snap.WHIP_PAN
	transition.snap_out(kind, _snap_sec())

func _finish() -> void:
	if _finished:
		return
	_finished = true
	outro_finished.emit()


# ── Impact helpers (all fire on the SAME tick from _on_impact) ────────────

## Camera punch: quick zoom-in and bouncy settle, 2x70 ms = 140 ms total.
func _camera_punch() -> void:
	# Both halves are compressed with the beat they live in. Beat 2 is _impact_hold_sec() /
	# speed_scale — 39 ms at the worst compression — while these are authored at 70 ms each, so
	# unscaled the camera was still zoomed when the payoff opened: measured zoom 1.0566 at the
	# payoff frame (tools/VerifyOutroSkip.tscn). An effect that outlives its beat is playing over
	# the next one.
	var half: float = CAMERA_PUNCH_SEC * 0.5 / speed_scale
	var t := create_tween()
	t.tween_property(camera, "zoom", Vector2(1.07, 1.07), half) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(camera, "zoom", Vector2.ONE, half) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Brief white bloom exactly on the impact frame — sells the "freeze". Compressed with beat 2 for
## the same reason as the punch: unscaled, the payoff played under a 0.5-alpha white wash.
func _impact_flash() -> void:
	flash_rect.color = Color(1, 1, 1, 0)
	var t := create_tween()
	t.tween_property(flash_rect, "color:a", 0.55, 0.05 / speed_scale) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(flash_rect, "color:a", 0.0, 0.14 / speed_scale) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Stinger fires ON the impact frame, not after it. Falls back to the
## generated AudioManager cue until real stinger files are dropped in at
## STINGER_WIN_PATH / STINGER_LOSE_PATH.
func _play_stinger() -> void:
	var path := STINGER_WIN_PATH if win else STINGER_LOSE_PATH
	if ResourceLoader.exists(path):
		stinger.stream = load(path)
		stinger.play()
	elif AudioManager:
		if win:
			AudioManager.play_success()
		else:
			AudioManager.play_failure()

## Confetti (win) or splash (lose), one-shot, self-freeing.
func _spawn_burst(at: Vector2, lose: bool) -> void:
	var p := GPUParticles2D.new()
	p.name = "Burst"
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.amount = 30 if lose else 42
	p.lifetime = 0.9
	# The particle sim runs at the clip's rate too. A 0.9 s burst inside a 0.40 s compressed clip
	# was cut off mid-flight when the scene freed; one property keeps the arc inside the clip
	# instead of shortening the lifetime and losing the shape.
	p.speed_scale = speed_scale
	p.position = at
	p.texture = _dot_texture()
	p.process_material = _burst_material(lose)
	p.z_index = 20
	world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	# Belt-and-braces free in case `finished` is missed under speed_scale.
	var safety := create_tween()
	safety.tween_interval(2.5)
	safety.tween_callback(p.queue_free)

func _burst_material(lose: bool) -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 12.0
	m.direction = Vector3(0, -1, 0)
	if lose:
		# Splash: tighter cone, softer launch, water blues.
		m.spread = 50.0
		m.initial_velocity_min = 260.0
		m.initial_velocity_max = 430.0
		m.gravity = Vector3(0, 900, 0)
		m.color_initial_ramp = _ramp([
			Color(0.55, 0.82, 1.0), Color(0.75, 0.92, 1.0),
			Color(0.36, 0.76, 1.0), Color(1, 1, 1),
		])
	else:
		# Confetti: wide fan, punchy launch, celebratory mix.
		m.spread = 75.0
		m.initial_velocity_min = 320.0
		m.initial_velocity_max = 560.0
		m.gravity = Vector3(0, 1150, 0)
		m.color_initial_ramp = _ramp([
			Color(1.0, 0.84, 0.3), Color(0.45, 0.9, 0.62),
			Color(0.55, 0.82, 1.0), Color(0.93, 0.6, 0.7),
			Color(1, 1, 1),
		])
	m.scale_min = 0.5
	m.scale_max = 1.1
	return m

# ── Construction ──────────────────────────────────────────────────────────

func _ensure_built() -> void:
	if _built:
		return
	_built = true

	_content_scale = clampf(
		minf(_vp.x / DESIGN_SIZE.x, _vp.y / DESIGN_SIZE.y), 0.75, 3.0
	)

	# Flat sky — per-game scenes may recolour $World/Backdrop.
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.42, 0.72, 0.92)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	world = Node2D.new()
	world.name = "World"
	add_child(world)
	_build_ground()

	camera = Camera2D.new()
	camera.name = "BeatCamera"
	camera.position = _vp * 0.5
	world.add_child(camera)
	camera.make_current()

	# Impact bloom sits above everything world-side but below transitions.
	flash_rect = ColorRect.new()
	flash_rect.name = "ImpactFlash"
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.z_index = 50
	add_child(flash_rect)

	stinger = AudioStreamPlayer.new()
	stinger.name = "Stinger"
	add_child(stinger)

	transition = TransitionLayer.new()
	transition.name = "Snap"
	add_child(transition)

func _build_ground() -> void:
	var ground_y := _vp.y * GROUND_FRACTION
	var grass := Polygon2D.new()
	grass.name = "Ground"
	grass.polygon = PackedVector2Array([
		Vector2(0, ground_y), Vector2(_vp.x, ground_y), Vector2(_vp.x, _vp.y), Vector2(0, _vp.y),
	])
	grass.color = Color(0.52, 0.78, 0.42)
	world.add_child(grass)
	var dirt := Polygon2D.new()
	dirt.name = "Dirt"
	dirt.polygon = PackedVector2Array([
		Vector2(0, ground_y + 26.0 * _content_scale),
		Vector2(_vp.x, ground_y + 26.0 * _content_scale),
		Vector2(_vp.x, _vp.y), Vector2(0, _vp.y),
	])
	dirt.color = Color(0.42, 0.62, 0.35)
	world.add_child(dirt)

# ── Cast staging helpers ──────────────────────────────────────────────────

## Places a cast member with its feet on the ground line and remembers rest
## Y (so hop() lands correctly later in the beat script).
func _stage_actor(actor: CartoonActor, x: float, actor_scale: Vector2 = Vector2.ONE) -> CartoonActor:
	world.add_child(actor)
	var foot_y := _vp.y * GROUND_FRACTION
	actor.position = Vector2(x, foot_y - 66.0 * _content_scale)
	actor.scale = actor_scale * _content_scale * ACTOR_SCALE
	# Foreground by default. Without this, any prop staged at z >= 1 (chairs,
	# pipes, drums, mud blobs…) painted OVER the characters' faces. Per-clip
	# props that genuinely belong in front of an actor should use z > 10.
	actor.z_index = 10
	actor.mark_rest()
	# The actor owns its own loops (idle sway, blink, bob, stars) and creates them internally, so
	# the clip's speed has to be handed over rather than applied at the call site.
	actor.anim_speed = speed_scale
	return actor

## Smallest distance between neighbouring townsfolk that keeps their torsos distinct, in the
## same design units the beat scripts author their spans in.
##
## A townsperson body is a droplet 2 * CartoonActor.BODY_RX wide, staged through _stage_actor()
## at CastFactory.TOWNSFOLK_SCALE * ACTOR_SCALE: 2 * 46 * 0.82 * 1.35 = 101.8 units, which
## _content_scale then multiplies - 1.667 at a 1920-wide window against the 1152x648
## DESIGN_SIZE, so 169.7 device px. At exactly this pitch neighbouring torsos touch without
## merging, while arms, hair and props still overlap, which is what makes a crowd read as a
## crowd rather than as a row.
const CROWD_PITCH: float = 2.0 * CartoonActor.BODY_RX * 0.82 * ACTOR_SCALE

## Crowds are background: behind Dribble, slightly smaller.
##
## The span a caller asks for is a hint, not a contract. Each beat script authored its crowd as
## a pair of _vp.x fractions picked by eye, and several are tighter than a single body is wide:
## WaterMemoryIntro asks for 3 townsfolk across _vp.x * 0.03 .. 0.13, which is a 96px pitch for
## 169.7px bodies, so each torso sat 57% buried in its neighbour.
## tools/VerifyCutsceneCast.tscn measured the tightest neighbour clearance at -72.8px, with 35
## of 75 clips overlapping. The span is widened here about its own centre until the bodies clear
## and then slid back inside the frame, so the authored staging - which side of the frame,
## roughly how tight - survives, the merging does not, and no beat script needs retuning.
func _stage_townsfolk(count: int, left_x: float, right_x: float) -> void:
	townsfolk = CastFactory.make_townsfolk(count)
	var n := townsfolk.size()
	if n > 1:
		var pitch := CROWD_PITCH * _content_scale
		var need := pitch * float(n - 1)
		if right_x - left_x < need:
			var mid := (left_x + right_x) * 0.5
			left_x = mid - need * 0.5
			right_x = mid + need * 0.5
		# Slide rather than squeeze, so a crowd authored against an edge keeps the pitch it was
		# just given instead of being compressed straight back out of it. make_townsfolk() clamps
		# the count to 5, and 5 bodies span 4 * 169.7 = 679px of the 1920 available, so there is
		# always room to slide into. The margin is half a body: a townsperson is positioned by its
		# centre, so anything closer than that to an edge is drawn partly outside the frame - which
		# is where the leftmost of WaterMemoryIntro three (x = 0.03 * 1920 = 58px) already was.
		var margin := pitch * 0.5
		if left_x < margin:
			var shift := margin - left_x
			left_x += shift
			right_x += shift
		if right_x > _vp.x - margin:
			var shift_back := right_x - (_vp.x - margin)
			left_x -= shift_back
			right_x -= shift_back
	for i in range(n):
		var x := left_x if n == 1 else lerpf(left_x, right_x, float(i) / float(n - 1))
		_stage_actor(townsfolk[i], x, CastFactory.TOWNSFOLK_SCALE)
		townsfolk[i].z_index = -1
## Every authored animation in a clip is created through here, not through create_tween().
##
## Why: the four beat intervals in _run_timeline() are divided by speed_scale, so at the 5.1x the
## bridge can ask for (1.7 low-end x 3.0 reduced motion) the timeline is 0.40s long - but a tween
## made with create_tween() keeps its authored duration, so a 0.26s move is still 0.26s inside a
## 0.08s beat. Measured before this existed: at 5.1x only 27-32% of a clip's authored animation
## seconds ever played and 24-40 tweens were still mid-flight when the scene was freed
## (tools/VerifyOutroCompression.tscn). The clip was not compressed, it was cut - the opposite of
## what MiniGameIntroBridge says it does ("plays compressed rather than being cut, because the
## cause clip is the educational payload of the loop").
##
## `host` keeps a tween bound to the node it animates: <node>.create_tween() dies with that node,
## which is what a clip wants for a prop it may free mid-beat. Passing nothing binds to the clip.
##
## Not used for the timeline itself, the impact flash, the camera punch or the skip tail - those
## divide by speed_scale explicitly, and scaling them here too would compress them twice.
func _ct(host: Node = null) -> Tween:
	var owner_node: Node = host if host != null else self
	return owner_node.create_tween().set_speed_scale(speed_scale)

## Screen point the burst blooms from — default: just above Dribble's head.
func _impact_point() -> Vector2:
	if is_instance_valid(dribble):
		return dribble.position + Vector2(0, -60.0 * _content_scale)
	return _vp * 0.5

# ── Skip + misc ───────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_try_skip()
	elif event is InputEventScreenTouch and event.pressed:
		_try_skip()

func _try_skip() -> void:
	if _finished or _skipping or _elapsed < SKIP_LOCKOUT_SEC:
		return
	_skipping = true
	if _timeline and _timeline.is_valid():
		_timeline.kill()
	_run_skip_tail()

## What a tap actually does: drop the WAITING, keep the beats.
##
## This used to be _timeline.custom_step(999.0), which advances the whole timeline in one call —
## so _do_payoff(), _beat_snap() and _finish() all ran inside a single frame. The payoff tweens
## were created and the scene was freed before one frame rendered them: measured 0.000 s of payoff
## on all four sampled clips, win, lose and intro alike (tools/VerifyOutroSkip.tscn). CartoonStage
## already holds its last beat on skip and says why — "the payoff frame is always seen. Cause
## precedes effect even in the skipped path." This is that rule for the authored tier.
##
## What is owed depends on how far the clip got, so a player who has already watched the payoff is
## not made to sit through the hold a second time.
func _run_skip_tail() -> void:
	var tail := create_tween()
	if _beat_reached < 2:
		tail.tween_callback(_do_impact)
		tail.tween_interval(_impact_hold_sec() / speed_scale)
	if _beat_reached < 3:
		tail.tween_callback(_do_payoff)
		tail.tween_interval(SKIP_PAYOFF_HOLD_SEC)
	else:
		var owed: float = SKIP_PAYOFF_HOLD_SEC - maxf(_elapsed - _payoff_at, 0.0)
		if owed > 0.0:
			tail.tween_interval(owed)
	tail.tween_callback(_beat_snap)
	tail.tween_interval(_snap_sec() / speed_scale)
	tail.tween_callback(_finish)

func _process(delta: float) -> void:
	if not _finished:
		_elapsed += delta

# ── Small shared resources ────────────────────────────────────────────────

func _dot_texture() -> Texture2D:
	if _dot_tex:
		return _dot_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 10
	t.height = 10
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	_dot_tex = t
	return t

func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in range(colors.size()):
		offsets.append(float(i) / float(maxi(colors.size() - 1, 1)))
	g.offsets = offsets
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
