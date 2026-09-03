class_name CartoonStage
extends Control

## Full-screen "Dumb Ways to Die"-style stage for a single scenario beat.
##
## Replaces the old approach of scaling one emoji in a Label. A stage owns:
##   * a painted environment (sky/ground/props built from Polygon2D)
##   * one or more CartoonActor rigs that can actually act
##   * a caption bar
##   * a beat scheduler so gags are authored as data, not hand-rolled tweens
##
## Three beat types map onto the requested loop:
##   CAUSE  — the setup gag that explains *why* you're about to play
##   EFFECT_WIN / EFFECT_LOSE — the payoff after the minigame resolves
##
## Performance: everything is built in build_scene() and freed on exit. Beats
## are Tween/await driven so there is no per-frame script work.

signal cutscene_finished

enum Kind { CAUSE, EFFECT_WIN, EFFECT_LOSE }

const CAPTION_HEIGHT: float = 132.0

## Reference viewport the stage art was authored against. _content_scale is
## derived from the live viewport relative to this.
const DESIGN_SIZE: Vector2 = Vector2(1152.0, 648.0)

## Ground line as a fraction of the *stage area* (viewport minus caption bar).
const GROUND_FRACTION: float = 0.72

## Fraction of DESIGN_SIZE.y the ground sat at when the prop/beat data was
## authored. Prop `y` values in CartoonScenarios are relative to this, so they
## stay planted when the real ground line moves.
const DESIGN_GROUND_FRACTION: float = 0.68

## Distance from the actor's origin down to its shadow/feet, unscaled.
const ACTOR_FOOT_OFFSET: float = 66.0

## Natural magnitudes for beat actions, before the beat's `power` multiplier and
## _content_scale are applied.
const HOP_HEIGHT: float = 46.0
const SHAKE_STRENGTH: float = 9.0
const SQUASH_AMOUNT: float = 0.55

## The actor is the star of the frame; the rig's natural size reads small against
## a full-screen stage, so it gets an extra multiplier on top of _content_scale.
const ACTOR_SCALE: float = 1.35

## A tap is only honoured after this much of the clip has played. Without it a
## stray tap left over from the previous screen (or an autoplay driver) cancels
## the clip on frame one, which is why outcome animations appeared to vanish.
const SKIP_LOCKOUT_SEC: float = 0.45

## When a clip is skipped we still hold the final beat this long, so the payoff
## frame is always seen. Cause precedes effect even in the skipped path.
const SKIP_PAYOFF_HOLD_SEC: float = 0.4

## Caption reading floor. See _beat_hold(): a beat never holds for less than the time needed to
## read its own caption, and that floor is not compressed by speed_scale.
##
## The cap bounds a pathological line rather than budgeting a real one — it sits just above the
## longest authored caption (65 characters, which lands at 21 chars/sec), so no shipping caption
## is truncated in time, and a longer one trips the claim in tools/BeatTimingReport.gd instead of
## being silently sped past.
const READ_CHARS_PER_SEC: float = 18.0
const READ_FIXATION_SEC: float = 0.35
const READ_FLOOR_MAX_SEC: float = 3.1

## Length of the drop-in landing in _intro_flourish(). The first beat used to
## fire the frame after the drop-in *started*; a `cheer`/`hop` on that beat
## captured the airborne position and the actor landed in the sky (visible in
## the win-frame probe where the droplet floats with its shadow off the ground).
const INTRO_LAND_SEC: float = 0.34

var kind: int = Kind.CAUSE
var scenario_id: String = ""
var speed_scale: float = 1.0

var world: Node2D
var backdrop: ColorRect
var caption_panel: PanelContainer
var caption_label: Label
var actor: CartoonActor
var flash: ColorRect

var _scenario: Dictionary = {}
var _skipped: bool = false
var _finished: bool = false
var _props: Node2D
var _vp: Vector2 = Vector2(1152.0, 648.0)
## The stage art was authored against a 1152x648 viewport. On a taller/larger
## viewport the actor and props are drawn at the same pixel size and read as
## tiny specks in the middle of an empty screen, which is what made the clips
## look unfinished. Actor and props are scaled by this instead of scaling the
## whole world (the ground/hill polygons are already built in viewport units).
var _content_scale: float = 1.0
## Seconds of clip actually played. Drives the skip lockout.
var _elapsed_sec: float = 0.0

func configure(beat_kind: int, id: String, options: Dictionary = {}) -> void:
	kind = beat_kind
	scenario_id = id
	speed_scale = float(options.get("speed", 1.0))
	if speed_scale <= 0.05:
		speed_scale = 1.0

func _ready() -> void:
	# set_anchors_and_offsets_preset, NOT set_anchors_preset. The latter keeps the
	# existing offsets, and a Control created with `new()` has size 0x0, so it
	# resolved to offset_right/bottom = -parent_size and the stage stayed 0x0 for
	# its whole life. Consequences on screen: the sky ColorRect had no area (the
	# host's black background showed through instead of the painted sky) and the
	# caption Label was 1 px wide, so AUTOWRAP_WORD_SMART broke the text into one
	# letter per line down the left edge.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = get_viewport_rect().size

func play_cutscene() -> void:
	_vp = get_viewport_rect().size
	# Uniform so the droplet never distorts. The min of the two axes keeps a
	# tall (portrait phone) viewport from blowing the actor up past the frame.
	_content_scale = clampf(
		minf(_vp.x / DESIGN_SIZE.x, _vp.y / DESIGN_SIZE.y), 0.75, 3.0
	)
	_scenario = CartoonScenarios.get_scenario(scenario_id, kind)
	_build_scene()
	_play_audio_cue()
	await _run_beats()
	if not _finished:
		_finished = true
		cutscene_finished.emit()

# ── Scene construction ────────────────────────────────────────────────────

func _build_scene() -> void:
	var palette: Dictionary = _scenario.get("palette", {})

	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = palette.get("sky", Color(0.42, 0.72, 0.92))
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	_build_environment(palette)

	_props = Node2D.new()
	_props.name = "Props"
	world.add_child(_props)

	actor = CartoonActor.new()
	actor.name = "Actor"
	# Feet on the ground line rather than a fixed 0.56 of the viewport height:
	# with a non-16:9 viewport the old constant left the droplet floating well
	# above the hill (visible in the reported screenshot).
	actor.position = Vector2(_vp.x * 0.5, _ground_y() - ACTOR_FOOT_OFFSET * _actor_scale())
	actor.scale = Vector2.ONE * _actor_scale()
	# Record the standing line BEFORE _intro_flourish() yanks the actor up into
	# the air — hop() and friends return to this Y, not to wherever the actor
	# happens to be mid-entrance.
	actor.mark_rest()
	actor.set_skin(palette.get("skin", CartoonActor.SKIN_DEFAULT))
	world.add_child(actor)
	# Compression is applied through anim_speed, not through start_idle()'s own speed argument -
	# that argument divides the loop's durations, so doing both would compress the idle twice.
	actor.anim_speed = speed_scale
	actor.set_expression(int(_scenario.get("start_expression", CartoonActor.Mood.NEUTRAL)))
	actor.start_idle()
	actor.start_blinking()

	_build_props()

	# White flash for impact frames — sits above the world, below the caption.
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	_build_caption()

func _build_environment(palette: Dictionary) -> void:
	var ground_y: float = _ground_y()
	var ground_col: Color = palette.get("ground", Color(0.30, 0.62, 0.34))
	var sky_col: Color = palette.get("sky", Color(0.42, 0.72, 0.92))

	# Vertical sky gradient. The flat ColorRect left the top half of the frame
	# reading as empty dead space; a light band near the horizon gives depth for
	# one extra polygon and no per-frame cost.
	var sky_grad := Polygon2D.new()
	sky_grad.polygon = PackedVector2Array([
		Vector2(-40.0, -40.0),
		Vector2(_vp.x + 40.0, -40.0),
		Vector2(_vp.x + 40.0, ground_y),
		Vector2(-40.0, ground_y),
	])
	sky_grad.vertex_colors = PackedColorArray([
		sky_col.darkened(0.18),
		sky_col.darkened(0.18),
		sky_col.lightened(0.20),
		sky_col.lightened(0.20),
	])
	world.add_child(sky_grad)

	# Distant hill band adds depth for almost no cost.
	var hill := Polygon2D.new()
	hill.polygon = PackedVector2Array([
		Vector2(-40.0, ground_y),
		Vector2(_vp.x * 0.26, ground_y - 88.0 * _content_scale),
		Vector2(_vp.x * 0.58, ground_y - 34.0 * _content_scale),
		Vector2(_vp.x * 0.82, ground_y - 96.0 * _content_scale),
		Vector2(_vp.x + 40.0, ground_y),
		Vector2(_vp.x + 40.0, ground_y + 20.0),
		Vector2(-40.0, ground_y + 20.0),
	])
	hill.color = ground_col.darkened(0.22)
	world.add_child(hill)

	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([
		Vector2(-40.0, ground_y),
		Vector2(_vp.x + 40.0, ground_y),
		Vector2(_vp.x + 40.0, _vp.y + 40.0),
		Vector2(-40.0, _vp.y + 40.0),
	])
	ground.color = ground_col
	world.add_child(ground)

	# Ground highlight strip where the actor stands.
	var strip := Polygon2D.new()
	strip.polygon = PackedVector2Array([
		Vector2(-40.0, ground_y),
		Vector2(_vp.x + 40.0, ground_y),
		Vector2(_vp.x + 40.0, ground_y + 9.0 * _content_scale),
		Vector2(-40.0, ground_y + 9.0 * _content_scale),
	])
	strip.color = ground_col.lightened(0.26)
	world.add_child(strip)

## Y of the ground line in viewport pixels. Measured inside the stage area
## (viewport minus the caption bar) so the horizon never hides behind the
## caption on a short viewport.
func _ground_y() -> float:
	return (_vp.y - _caption_height()) * GROUND_FRACTION

func _build_caption() -> void:
	var caption_h: float = _caption_height()
	caption_panel = PanelContainer.new()
	caption_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption_panel.custom_minimum_size = Vector2(0.0, caption_h)
	caption_panel.offset_top = -caption_h
	caption_panel.offset_bottom = 0.0
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.07, 0.10, 0.90)
	box.corner_radius_top_left = int(22.0 * _content_scale)
	box.corner_radius_top_right = int(22.0 * _content_scale)
	box.content_margin_left = 34.0 * _content_scale
	box.content_margin_right = 34.0 * _content_scale
	box.content_margin_top = 18.0 * _content_scale
	box.content_margin_bottom = 18.0 * _content_scale
	caption_panel.add_theme_stylebox_override("panel", box)
	add_child(caption_panel)

	caption_label = Label.new()
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Autowrap needs a width to wrap against. Without SIZE_FILL the Label
	# reports its full single-line width as its minimum and the PanelContainer
	# grows to match instead of wrapping.
	caption_label.size_flags_horizontal = Control.SIZE_FILL | Control.SIZE_EXPAND
	caption_label.add_theme_font_size_override("font_size", int(34.0 * _content_scale))
	caption_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	caption_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	caption_label.add_theme_constant_override("outline_size", int(5.0 * _content_scale))
	caption_panel.add_child(caption_label)

	caption_panel.modulate.a = 0.0

func _caption_height() -> float:
	return CAPTION_HEIGHT * _content_scale

func _actor_scale() -> float:
	return _content_scale * ACTOR_SCALE

# ── Props ─────────────────────────────────────────────────────────────────

## Props are declared as data in CartoonScenarios so a new scenario needs no
## new code — just an entry naming which shapes to place and where.
func _build_props() -> void:
	var specs: Array = _scenario.get("props", [])
	for spec_variant in specs:
		var spec: Dictionary = spec_variant
		var kind_name: String = str(spec.get("type", ""))
		var node := _make_prop(kind_name, spec.get("color", Color(0.55, 0.72, 0.85)))
		if node == null:
			continue
		node.name = str(spec.get("id", kind_name))
		# Prop `y` in the scenario data is a fraction of the *design* viewport,
		# where the ground sat at DESIGN_GROUND_FRACTION. Re-anchor it to the
		# real ground line so props keep their relationship to the horizon
		# instead of drifting into the sky on a taller viewport.
		var design_y: float = float(spec.get("y", 0.6)) * DESIGN_SIZE.y
		var offset_from_ground: float = design_y - DESIGN_SIZE.y * DESIGN_GROUND_FRACTION
		node.position = Vector2(
			_vp.x * float(spec.get("x", 0.5)),
			_ground_y() + offset_from_ground * _content_scale
		)
		node.scale = Vector2.ONE * float(spec.get("scale", 1.0)) * _content_scale
		_props.add_child(node)

func _make_prop(kind_name: String, tint: Color) -> Node2D:
	match kind_name:
		"tap":
			return _prop_tap(tint)
		"bucket":
			return _prop_bucket(tint)
		"puddle":
			return _prop_puddle(tint)
		"pipe":
			return _prop_pipe(tint)
		"plant":
			return _prop_plant(tint)
		"cloud":
			return _prop_cloud(tint)
		"drum":
			return _prop_drum(tint)
		"showerhead":
			return _prop_showerhead(tint)
		"sun":
			return _prop_sun(tint)
		_:
			return null

func _rect_poly(w: float, h: float, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var hw: float = w * 0.5
	var hh: float = h * 0.5
	return PackedVector2Array([
		Vector2(-hw, -hh) + offset,
		Vector2(hw, -hh) + offset,
		Vector2(hw, hh) + offset,
		Vector2(-hw, hh) + offset,
	])

func _oval_poly(rx: float, ry: float, segments: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a: float = float(i) * TAU / float(segments)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _add_poly(parent: Node2D, points: PackedVector2Array, color: Color, part: String = "") -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	if part != "":
		p.name = part
	parent.add_child(p)
	return p

func _prop_tap(tint: Color) -> Node2D:
	var root := Node2D.new()
	_add_poly(root, _rect_poly(28.0, 52.0, Vector2(0.0, -20.0)), tint.darkened(0.25))
	_add_poly(root, _rect_poly(40.0, 16.0, Vector2(14.0, -22.0)), tint)
	_add_poly(root, _rect_poly(20.0, 14.0, Vector2(0.0, -53.0)), Color(0.92, 0.36, 0.32), "Handle")
	return root

func _prop_bucket(tint: Color) -> Node2D:
	var root := Node2D.new()
	_add_poly(root, PackedVector2Array([
		Vector2(-30.0, -26.0), Vector2(30.0, -26.0),
		Vector2(22.0, 30.0), Vector2(-22.0, 30.0),
	]), tint)
	# Water level is scaled on the Y axis by beats to "fill" the bucket.
	var water := _add_poly(root, PackedVector2Array([
		Vector2(-27.0, -18.0), Vector2(27.0, -18.0),
		Vector2(23.0, 8.0), Vector2(-23.0, 8.0),
	]), Color(0.35, 0.72, 0.95, 0.92), "Water")
	water.scale.y = 0.02
	_add_poly(root, _rect_poly(64.0, 6.0, Vector2(0.0, -26.0)), tint.darkened(0.3))
	return root

func _prop_puddle(tint: Color) -> Node2D:
	var root := Node2D.new()
	var pts := PackedVector2Array()
	for i in range(20):
		var a: float = float(i) * TAU / 20.0
		pts.append(Vector2(cos(a) * (58.0 + sin(a * 3.0) * 9.0), sin(a) * 15.0))
	var pool := _add_poly(root, pts, tint, "Pool")
	pool.scale = Vector2(0.15, 0.15)
	return root

func _prop_pipe(tint: Color) -> Node2D:
	var root := Node2D.new()
	_add_poly(root, _rect_poly(140.0, 32.0), tint)
	_add_poly(root, _rect_poly(12.0, 38.0, Vector2(-46.0, 0.0)), tint.darkened(0.3))
	_add_poly(root, _rect_poly(12.0, 38.0, Vector2(46.0, 0.0)), tint.darkened(0.3))

	var crack := Line2D.new()
	crack.name = "Crack"
	crack.width = 4.0
	crack.default_color = Color(0.10, 0.10, 0.12)
	crack.add_point(Vector2(2.0, -14.0))
	crack.add_point(Vector2(-6.0, 0.0))
	crack.add_point(Vector2(4.0, 14.0))
	root.add_child(crack)
	return root

func _prop_plant(tint: Color) -> Node2D:
	var root := Node2D.new()
	_add_poly(root, PackedVector2Array([
		Vector2(-26.0, 6.0), Vector2(26.0, 6.0),
		Vector2(20.0, 44.0), Vector2(-20.0, 44.0),
	]), Color(0.72, 0.42, 0.28))

	var stem := Line2D.new()
	stem.name = "Stem"
	stem.width = 6.0
	stem.default_color = tint.darkened(0.2)
	stem.add_point(Vector2(0.0, 6.0))
	stem.add_point(Vector2(0.0, -34.0))
	root.add_child(stem)

	var leaves := Node2D.new()
	leaves.name = "Leaves"
	root.add_child(leaves)
	_add_poly(leaves, PackedVector2Array([
		Vector2(0.0, -12.0), Vector2(-34.0, -34.0), Vector2(-14.0, -6.0),
	]), tint)
	_add_poly(leaves, PackedVector2Array([
		Vector2(0.0, -12.0), Vector2(34.0, -34.0), Vector2(14.0, -6.0),
	]), tint)
	return root

func _prop_cloud(tint: Color) -> Node2D:
	var root := Node2D.new()
	for offset in [Vector2(-26.0, 4.0), Vector2(0.0, -10.0), Vector2(26.0, 4.0)]:
		var puff := _add_poly(root, _oval_poly(28.0, 22.0, 14), tint)
		puff.position = offset
	return root

func _prop_drum(tint: Color) -> Node2D:
	var root := Node2D.new()
	_add_poly(root, _rect_poly(76.0, 90.0, Vector2(0.0, 1.0)), tint)
	# Fillable water body drawn AFTER the drum body so it reads on top of it.
	# Anchored to the drum's bottom interior so scale:y grows it upward. Starts
	# as a sliver; fill_bucket tweens it toward 1.0.
	var water := _add_poly(
		root, _rect_poly(64.0, 70.0, Vector2(0.0, -35.0)),
		Color(0.36, 0.62, 0.86, 0.9), "Water"
	)
	water.position = Vector2(0.0, 38.0)
	water.scale = Vector2(1.0, 0.05)
	_add_poly(root, _rect_poly(82.0, 10.0, Vector2(0.0, -20.0)), tint.darkened(0.3))
	_add_poly(root, _rect_poly(82.0, 10.0, Vector2(0.0, 12.0)), tint.darkened(0.3))
	var lid := _add_poly(root, _oval_poly(42.0, 11.0), tint.lightened(0.25), "Lid")
	lid.position = Vector2(0.0, -44.0)
	return root

func _prop_showerhead(tint: Color) -> Node2D:
	var root := Node2D.new()
	var arm := Line2D.new()
	arm.width = 8.0
	arm.default_color = tint.darkened(0.3)
	arm.add_point(Vector2(0.0, -60.0))
	arm.add_point(Vector2(0.0, -22.0))
	root.add_child(arm)
	_add_poly(root, PackedVector2Array([
		Vector2(-30.0, -22.0), Vector2(30.0, -22.0),
		Vector2(22.0, -2.0), Vector2(-22.0, -2.0),
	]), tint, "Head")
	return root

func _prop_sun(tint: Color) -> Node2D:
	var root := Node2D.new()
	var rays := Node2D.new()
	rays.name = "Rays"
	root.add_child(rays)
	for i in range(8):
		var a: float = float(i) * TAU / 8.0
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x)
		_add_poly(rays, PackedVector2Array([
			dir * 34.0 + perp * 6.0,
			dir * 58.0,
			dir * 34.0 - perp * 6.0,
		]), tint)
	_add_poly(root, _oval_poly(32.0, 32.0, 18), tint.lightened(0.2), "Disc")
	return root

# ── Beat scheduler ────────────────────────────────────────────────────────

## Each beat is a Dictionary: {caption, expression, arms, action, hold}.
## The scheduler owns timing so scenarios stay declarative and every clip
## honours the same skip behaviour.
func _run_beats() -> void:
	var beats: Array = _scenario.get("beats", [])
	if beats.is_empty():
		await _wait(0.6)
		return

	# Camera-ish push-in gives the whole clip motion even on still beats. Scaled
	# about the stage centre — scaling a Node2D scales about its origin (0,0),
	# which slid the whole scene down-right instead of pushing in.
	var zoom_to: float = 1.06
	var centre := Vector2(_vp.x * 0.5, _ground_y())
	var zoom := create_tween()
	zoom.tween_property(world, "scale", Vector2(zoom_to, zoom_to), _total_length(beats)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	zoom.parallel().tween_property(
		world, "position", centre * (1.0 - zoom_to), _total_length(beats)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_intro_flourish()
	# Let the drop-in land before the first beat runs. Beats used to fire the
	# frame after the entrance *started*, so a hop/cheer on beat 0 raced the
	# landing tween and stranded the actor in the sky (its "landing" tween then
	# returned it to the airborne position for the rest of the clip).
	await get_tree().create_timer(INTRO_LAND_SEC / speed_scale, true, false, true).timeout

	for beat_variant in beats:
		if _skipped:
			# A skip must not swallow the payoff. Jumping straight out used to
			# leave outcome clips ~1 s long and ending on a setup beat, so the
			# player saw the cause and never the effect. Snap to the final beat
			# and hold it briefly instead.
			_apply_beat_state(beats[beats.size() - 1])
			await _hold_unskippable(SKIP_PAYOFF_HOLD_SEC)
			break
		var beat: Dictionary = beat_variant
		await _play_beat(beat)

	if zoom.is_valid():
		zoom.kill()

	if not _skipped:
		await _wait(0.25)

## Clip length used to span the slow zoom across the whole clip. It has to agree with what
## _play_beat actually waits, floor included — otherwise the zoom lands early and the world sits
## frozen at full zoom for the remainder of the reading time.
func _total_length(beats: Array) -> float:
	var total: float = 0.0
	for beat_variant in beats:
		var beat: Dictionary = beat_variant
		total += _beat_hold(beat)
	return total / speed_scale

## Entrance beat. Nothing used to move until the first action fired, so the clip
## opened on a still frame. Props scale up from nothing and the actor drops in
## with a landing squash, which reads as "the scene starts" rather than "the
## scene was already there".
func _intro_flourish() -> void:
	var t: float = 0.34 / speed_scale

	var actor_rest: float = actor.position.y
	actor.position.y = actor_rest - 180.0 * _actor_scale()
	actor.modulate.a = 0.0
	# The shadow is a child, so it drops from the sky with the body. Plant it on
	# the ground line for the whole entrance and fade it in with the body; the
	# shadow growing/shrinking is what sells the height of the fall.
	var shadow_rest: float = actor.shadow.position.y
	var drop_dist: float = 180.0 * _actor_scale()
	actor.shadow.position.y = shadow_rest + drop_dist
	actor.shadow.modulate.a = 0.0
	var enter := create_tween()
	enter.tween_property(actor, "modulate:a", 1.0, t * 0.5)
	enter.parallel().tween_property(actor, "position:y", actor_rest, t) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	enter.parallel().tween_property(actor.shadow, "position:y", shadow_rest, t) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	enter.parallel().tween_property(actor.shadow, "modulate:a", 1.0, t)
	enter.tween_callback(func() -> void:
		actor.squash(0.4, 0.26 / speed_scale)
	)

	var index: int = 0
	for child in _props.get_children():
		var prop := child as Node2D
		if prop == null:
			continue
		var rest_scale: Vector2 = prop.scale
		prop.scale = rest_scale * 0.2
		prop.modulate.a = 0.0
		var pop := create_tween()
		pop.tween_interval(float(index) * 0.07 / speed_scale)
		pop.tween_property(prop, "modulate:a", 1.0, t * 0.4)
		pop.parallel().tween_property(prop, "scale", rest_scale, t) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		index += 1

	# Ambient drift for anything in the sky, so the backdrop is never frozen.
	_start_sky_drift()

## Slow horizontal drift + bob for cloud/sun props. Looped Tweens, no _process.
func _start_sky_drift() -> void:
	for child in _props.get_children():
		var prop := child as Node2D
		if prop == null:
			continue
		if not (prop.name.begins_with("cloud") or prop.name.begins_with("sun")):
			continue
		var rest: Vector2 = prop.position
		var span: float = 26.0 * _content_scale
		var period: float = (3.4 + randf() * 1.6) / speed_scale
		var drift := create_tween().set_loops()
		drift.tween_property(prop, "position:x", rest.x + span, period) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		drift.tween_property(prop, "position:x", rest.x, period) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var bob := create_tween().set_loops()
		bob.tween_property(prop, "position:y", rest.y - span * 0.35, period * 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(prop, "position:y", rest.y, period * 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _play_beat(beat: Dictionary) -> void:
	_apply_beat_state(beat)
	await _wait(_beat_hold(beat))

## How long a beat holds. This is the authored hold OR long enough to read the caption,
## whichever is longer.
##
## Why the max() is here: _wait() divides by speed_scale, and speed_scale carries BOTH the
## low-end-device compression (1.7x) and the player's reduced-motion preference (3.0x) — up to
## 5.1x together. Compressing the MOTION for either reason is the point. Compressing the time a
## sentence is on screen is not: at 5.1x a 52-character caption held 1.10s gets 0.216s, which is
## 241 characters per second. MiniGameIntroBridge's own comment says the cause clip "plays
## compressed rather than being cut, because the cause clip is the educational payload of the
## loop" — that payload is the caption, so the caption is exactly what must survive the divisor.
## The floor is pre-multiplied by speed_scale so it passes through _wait()'s division intact.
##
## A tap still cuts any hold short (see _wait / _skipped), so a fast reader loses nothing.
func _beat_hold(beat: Dictionary) -> float:
	var hold: float = float(beat.get("hold", 0.9))
	var reading: float = _reading_sec(str(beat.get("caption", "")))
	return maxf(hold, reading * speed_scale)

## Reading time for one caption, capped so a single long line cannot stall the loop. The rate is
## the low end of the adult subtitle range; the audience here is schoolchildren, and the measured
## authored rates ran to 47 characters per second (tools/BeatTimingReport.gd).
func _reading_sec(caption: String) -> float:
	if caption.strip_edges().is_empty():
		return 0.0
	return minf(
		READ_FIXATION_SEC + float(caption.length()) / READ_CHARS_PER_SEC,
		READ_FLOOR_MAX_SEC
	)

## Applies a beat's visual state (caption, pose, action) without holding.
## Shared by the normal playback path and the skip path, so a skipped clip still
## lands on the same final frame the full clip would have ended on.
func _apply_beat_state(beat: Dictionary) -> void:
	if beat.has("caption"):
		_set_caption(str(beat["caption"]))
	if beat.has("expression"):
		actor.set_expression(int(beat["expression"]))
	if beat.has("arms"):
		actor.set_arm_pose(int(beat["arms"]))
	if beat.has("action"):
		_run_action(str(beat["action"]), beat)

## `power` in the scenario data is a 0..~1.5 *multiplier*, not an absolute
## magnitude: CartoonScenarios._beat() defaults it to 1.0 for every action. The
## old code read it as absolute pixels (`beat.get("power", 46.0)`), so a hop
## authored as power 1.0 moved the actor one pixel and a shake wobbled by one
## pixel. That is why the clips looked static — the beats were firing correctly,
## the motion was just a thousandth of its intended size. Natural magnitudes now
## live here and power scales them.
##
## "spin", "flash" and "stars" have no producer in the current scenario data - checked
## across scripts/cutscenes/beats/ and CartoonScenarios.gd. They stay: each maps to a
## CartoonActor capability the hand-written clips already drive directly (spin(),
## spin_stars()) or to this stage's own _impact_flash(), so they are the data path to
## working code rather than orphaned branches, and deleting them would turn a future
## `{"action": "flash"}` from a working beat into a warned no-op.
func _run_action(action: String, beat: Dictionary) -> void:
	var power: float = float(beat.get("power", 1.0))
	match action:
		"hop":
			actor.hop(HOP_HEIGHT * power * _actor_scale())
		"squash":
			actor.squash(clampf(SQUASH_AMOUNT * power, 0.1, 0.9))
		"shake":
			actor.shake(SHAKE_STRENGTH * power * _actor_scale(), 0.5)
		"spin":
			actor.spin(power, 0.55)
		"panic":
			actor.stop_idle()
			actor.shake(SHAKE_STRENGTH * 1.2 * power * _actor_scale(), 0.7)
			actor.drip_sweat()
		"faint":
			_faint()
		"cheer":
			actor.hop(HOP_HEIGHT * 1.25 * power * _actor_scale(), 0.46)
			_burst(Color(1.0, 0.86, 0.35), 16)
		"splash":
			_burst(Color(0.42, 0.78, 1.0), 18)
			actor.squash(clampf(0.5 * power, 0.1, 0.9))
		"flash":
			_impact_flash()
		"fill_bucket":
			# power is a fill fraction here, not a magnitude multiplier.
			_fill_prop("bucket", power)
		"grow_puddle":
			_fill_prop("puddle", power)
		"rain":
			_rain()
		"leak":
			_leak()
		"wilt":
			_wilt()
		"stars":
			actor.spin_stars()
		"look_up":
			actor.look_at_local(Vector2(0.0, -160.0))
		"look_side":
			actor.look_at_local(Vector2(150.0, 0.0))
		_:
			# Was a silent `pass`. An action string is authored by hand in
			# CartoonScenarios, so a typo ("shakee", "hoop") produced a beat that held its
			# caption for the full read floor and animated nothing - visually identical to a
			# beat that was never given an action at all, and no harness could tell them
			# apart. tools/VerifyCartoonCutscenes checks the actions it knows about; this
			# catches the ones nobody thought to write down.
			push_warning("CartoonStage: beat action '%s' is not in the vocabulary - nothing played" % action)

func _set_caption(text: String) -> void:
	caption_label.text = text
	var caption_h: float = _caption_height()
	var tw := create_tween()
	tw.tween_property(caption_panel, "modulate:a", 1.0, 0.18)
	# Small vertical nudge so successive captions feel typed in, not swapped.
	caption_panel.offset_top = -caption_h + 12.0
	tw.parallel().tween_property(caption_panel, "offset_top", -caption_h, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── Effects ───────────────────────────────────────────────────────────────

func _impact_flash() -> void:
	flash.color = Color(1.0, 1.0, 1.0, 0.85)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.28)

## One-shot particle burst. Nodes are freed by the tween callback, so nothing
## accumulates across repeated plays.
func _burst(color: Color, count: int) -> void:
	var origin: Vector2 = actor.position
	for i in range(count):
		var bit := Polygon2D.new()
		bit.polygon = _oval_poly(6.0, 6.0, 8)
		bit.color = color
		bit.position = origin
		bit.scale = Vector2.ONE * _content_scale
		world.add_child(bit)

		var angle: float = float(i) * TAU / float(count) + randf() * 0.4
		var distance: float = (110.0 + randf() * 90.0) * _content_scale
		var target: Vector2 = origin + Vector2(cos(angle), sin(angle)) * distance

		var tw := create_tween()
		tw.tween_property(bit, "position", target, 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(bit, "scale", Vector2.ONE * _content_scale * 0.2, 0.55)
		tw.parallel().tween_property(bit, "modulate:a", 0.0, 0.55)
		tw.tween_callback(bit.queue_free)

func _fill_prop(prop_name: String, amount: float) -> void:
	var target := _find_prop_part(prop_name, "Water")
	if target == null:
		target = _find_prop_part(prop_name, "Pool")
	# Many clips stage a drum where a bucket was authored; any container with a
	# Water part can take the fill so the payoff gag never silently no-ops.
	if target == null and prop_name == "bucket":
		target = _find_prop_part("drum", "Water")
	if target == null:
		return
	var tw := create_tween()
	if target.name == "Pool":
		tw.tween_property(target, "scale", Vector2.ONE * clampf(amount, 0.1, 1.6), 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(target, "scale:y", clampf(amount, 0.02, 1.0), 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _find_prop_part(prop_name: String, part: String) -> Node2D:
	var prop := _props.get_node_or_null(NodePath(prop_name))
	if prop == null:
		return null
	return prop.get_node_or_null(NodePath(part)) as Node2D

## Falling rain streaks from the top of the stage. Recycled, not respawned.
func _rain() -> void:
	var ground_y: float = _ground_y()
	for i in range(14):
		var drop := Polygon2D.new()
		drop.polygon = PackedVector2Array([
			Vector2(0.0, -10.0), Vector2(3.4, 0.0),
			Vector2(0.0, 9.0), Vector2(-3.4, 0.0),
		])
		drop.color = Color(0.62, 0.86, 1.0, 0.9)
		drop.scale = Vector2.ONE * _content_scale
		var start := Vector2(_vp.x * (0.08 + randf() * 0.84), -30.0 - randf() * 120.0)
		drop.position = start
		world.add_child(drop)

		var tw := create_tween().set_loops()
		tw.tween_property(drop, "position:y", ground_y, 0.6 + randf() * 0.35) \
			.set_trans(Tween.TRANS_LINEAR)
		tw.tween_callback(func() -> void:
			drop.position = start
		)

func _leak() -> void:
	var pipe := _props.get_node_or_null(NodePath("pipe"))
	var origin: Vector2 = pipe.position if pipe != null else actor.position
	for i in range(8):
		var jet := Polygon2D.new()
		jet.polygon = _oval_poly(7.0, 7.0, 8)
		jet.color = Color(0.55, 0.84, 1.0, 0.9)
		jet.position = origin
		jet.scale = Vector2.ONE * _content_scale
		world.add_child(jet)

		var tw := create_tween().set_loops()
		tw.tween_interval(float(i) * 0.09)
		tw.tween_property(
			jet, "position",
			origin + Vector2(-70.0 - randf() * 60.0, 60.0) * _content_scale, 0.5
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(jet, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func() -> void:
			jet.position = origin
			jet.modulate.a = 1.0
		)

func _wilt() -> void:
	var leaves := _find_prop_part("plant", "Leaves")
	if leaves == null:
		return
	var tw := create_tween()
	tw.tween_property(leaves, "rotation", 0.55, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(leaves, "modulate", Color(0.72, 0.58, 0.30), 0.8)

func _faint() -> void:
	actor.stop_idle()
	actor.stop_blinking()
	actor.set_expression(CartoonActor.Mood.DEAD)
	actor.set_arm_pose(CartoonActor.ArmPose.DROOP)
	var tw := create_tween()
	tw.tween_property(actor, "rotation", PI * 0.5, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(
		actor, "position:y", actor.position.y + 34.0 * _actor_scale(), 0.45
	)
	tw.tween_callback(func() -> void:
		actor.squash(0.35, 0.24)
	)

# ── Skip / timing ─────────────────────────────────────────────────────────

## Every clip is tap-skippable. Kids replay these dozens of times; forcing the
## full animation each round is the fastest way to make a game feel slow.
func _input(event: InputEvent) -> void:
	if _skipped or _finished:
		return
	# Skip lockout: ignore taps in the opening moments of the clip. A tap that
	# was really meant for the previous screen used to land here and truncate
	# the animation to a single frame.
	if _elapsed_sec < SKIP_LOCKOUT_SEC:
		return
	var is_tap: bool = (
		(event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
		or (event is InputEventKey and (event as InputEventKey).pressed)
	)
	if is_tap:
		_skipped = true
		accept_event()

func _wait(seconds: float) -> void:
	var remaining: float = seconds / speed_scale
	var step: float = 0.05
	# Polled in small slices so a tap during a long hold cuts it short instead
	# of waiting out the whole timer. Subtract the slice actually awaited, not
	# the full step: the old code charged 0.05 for a shorter final slice, so
	# every beat finished slightly early and the whole clip drifted fast.
	while remaining > 0.0 and not _skipped:
		var slice: float = minf(step, remaining)
		await get_tree().create_timer(slice, true, false, true).timeout
		remaining -= slice
		_elapsed_sec += slice

## Like _wait() but ignores the skip flag. Used for the payoff hold so the final
## frame of a skipped clip is still on screen long enough to read.
func _hold_unskippable(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds, true, false, true).timeout
	_elapsed_sec += seconds

## Sound for this clip's beat, including the music bed.
##
## The music bed is paired with this node's lifetime rather than left running.
## AudioManager.music_player is a child of the AudioManager autoload, so freeing this
## stage does not silence it, and nothing else here stopped it: the three play_music
## calls below had no stop_music anywhere in this file. On the normal path the score
## page's "scoring" track supersedes the bed a few seconds later - but if the scene is
## torn down inside the clip, the bed carries on over the next screen, and
## InitialScreen (the hub) starts no music of its own to replace it. Same reasoning
## and same shape as MiniGameBase._play_scoped_music(); written out here rather than
## shared because CartoonStage is not a MiniGameBase.
##
## Reachability, stated because it decides how much this matters: every shipped
## minigame has an authored beat clip under res://scenes/ui/cutscenes/beats/, so
## MiniGameBase._play_beat_outro() takes the outro and this Tier-2 fallback does not
## run today (measured by tools/VerifyStrayAudio.tscn, which saw no track at all
## during a real outro). It is fixed because a game added without a beat clip falls
## straight back to here.
func _play_audio_cue() -> void:
	if not AudioManager:
		return
	var bed: String = ""
	match kind:
		Kind.CAUSE:
			AudioManager.play_whoosh()
			bed = "instruction"
		Kind.EFFECT_WIN:
			AudioManager.play_success()
			bed = "outcome_win"
		Kind.EFFECT_LOSE:
			AudioManager.play_failure()
			bed = "outcome_fail"
		_:
			return
	AudioManager.play_music(bed, 0.3 if kind == Kind.CAUSE else 0.2)
	# Guarded on current_music so a bed that has already been superseded - by the
	# score page, or by the screen replacing this one - is left alone.
	tree_exiting.connect(func() -> void:
		if is_instance_valid(AudioManager) and AudioManager.current_music == bed:
			AudioManager.stop_music(0.15))






