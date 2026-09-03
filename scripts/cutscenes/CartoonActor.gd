class_name CartoonActor
extends Node2D

## Procedural cartoon character for "Dumb Ways to Die"-style stage cutscenes.
##
## Why this exists: the old outcome cutscenes rendered a single emoji inside a
## Label and scaled it. An emoji cannot act — it has no limbs, no brows and no
## mouth we can reshape — so every outcome looked like the same tiny pop.
## This actor is built from ~30 Polygon2D/Line2D primitives with *named parts*,
## so gags can move an arm, widen an eye, or flip the mouth independently.
##
## Performance contract (low-end Android, see GOdot.md/Performance and Memory):
##   * All parts are allocated ONCE in build(). Nothing is created per frame.
##   * Expressions mutate existing polygons; they never add/remove nodes.
##   * Motion is Tween-driven, so there is no _process() on this node at all.

enum Mood {
	HAPPY,
	NEUTRAL,
	WORRIED,
	PANIC,
	SHOCKED,
	SAD,
	SMUG,
	DIZZY,
	DEAD,
}

const BODY_RX: float = 46.0
const BODY_RY: float = 56.0

## Resting offset of the ground shadow from the actor's origin. Kept as a const
## so airborne motion can counter-animate the shadow back onto the ground.
const SHADOW_REST_Y: float = BODY_RY + 10.0

# Palette
const SKIN_DEFAULT: Color = Color(0.36, 0.76, 1.0)
const SKIN_SHADE: Color = Color(0.24, 0.58, 0.86)
const INK: Color = Color(0.09, 0.11, 0.14)
const BLUSH: Color = Color(1.0, 0.48, 0.52, 0.55)

# ── Parts (allocated once) ────────────────────────────────────────────────
var rig: Node2D                  # everything that squashes/stretches
var shadow: Polygon2D
var body: Polygon2D
var shade: Polygon2D
var shine: Polygon2D
var arm_l: Line2D
var arm_r: Line2D
var leg_l: Line2D
var leg_r: Line2D
var eye_l: Node2D
var eye_r: Node2D
var pupil_l: Polygon2D
var pupil_r: Polygon2D
var lid_l: Polygon2D
var lid_r: Polygon2D
var brow_l: Line2D
var brow_r: Line2D
var mouth: Polygon2D
var mouth_line: Line2D
var blush_l: Polygon2D
var blush_r: Polygon2D
var sweat: Node2D
var stars: Node2D
var prop_slot: Node2D            # attach per-game props here (in front of body)
var prop_slot_back: Node2D       # behind the body

var _built: bool = false
var _skin: Color = SKIN_DEFAULT
var _expression: int = Mood.NEUTRAL
var _idle_tween: Tween = null
var _bob_tween: Tween = null
var _blink_tween: Tween = null
## Y the actor stands at, in parent space. hop() used to capture position.y at
## call time, so a hop that fired while the entrance drop-in was still animating
## captured the *airborne* start value and tweened back to it — the actor landed
## in mid-air and stayed there for the rest of the clip. Set once via mark_rest().
var _rest_y: float = 0.0
var _has_rest: bool = false

## The pose build() authored for the rig, the lid line the current expression authored, and the
## sweat beads' home positions. Every loop below used to re-read these off the live nodes, so a
## primitive fired while an earlier one was still running captured a value the tween had already
## moved and then "restored" to it. Measured before the fix: six mid-cycle idle restarts sank
## the actor 16.79 px, an overlapping shake left it 3.24 px off centre, and a blink landing on a
## blink left the eyes 12.61 px from open — shut for the rest of the clip. The gag loops
## (stars, sweat) had no stop at all and stacked one set of tweens per call.
## See tools/VerifyCartoonMotion.gd for the numbers.
var _rig_rest_pos: Vector2 = Vector2.ZERO
var _lid_open_y: float = -17.0
var _sweat_rest: PackedVector2Array = PackedVector2Array()
var _rest_tween: Tween = null
var _shake_tween: Tween = null
var _blink_anim: Tween = null
var _stars_tween: Tween = null
var _sweat_tweens: Array[Tween] = []


## Speed the clip that staged this actor is running at, handed over by
## MicrogameOutroBase._stage_actor() / CartoonStage._build_world(). 1.0 when nobody sets it, so an
## actor used outside a clip behaves exactly as authored.
var anim_speed: float = 1.0

## All of this actor's animation is created through here. See MicrogameOutroBase._ct(): a clip
## compressed to 5.1x divides its beat intervals but a plain create_tween() keeps its authored
## duration, so the sway, blink and squash would still be running when the clip is already gone.
func _ct() -> Tween:
	return create_tween().set_speed_scale(anim_speed)

func _ready() -> void:
	build()

## Safe to call before or after the node enters the tree.
func build() -> void:
	if _built:
		return
	_built = true

	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)

	# Ground shadow lives OUTSIDE the rig so squashing the body does not
	# squash the shadow (that reads as the floor moving).
	shadow = Polygon2D.new()
	shadow.name = "Shadow"
	shadow.polygon = _ellipse(BODY_RX * 0.86, 11.0, 18)
	shadow.position = Vector2(0.0, SHADOW_REST_Y)
	shadow.color = Color(0.0, 0.0, 0.0, 0.22)
	add_child(shadow)
	move_child(shadow, 0)

	prop_slot_back = Node2D.new()
	prop_slot_back.name = "PropSlotBack"
	rig.add_child(prop_slot_back)

	_build_limbs()
	_build_body()
	_build_face()

	prop_slot = Node2D.new()
	prop_slot.name = "PropSlot"
	rig.add_child(prop_slot)

	_build_accents()
	set_expression(Mood.NEUTRAL)

	# The authored rest pose, read once. Nothing else in build() moves the rig, and no primitive
	# may re-read these off the live node — see the block comment on _rig_rest_pos.
	_rig_rest_pos = rig.position
	_sweat_rest.resize(sweat.get_child_count())
	for i in range(sweat.get_child_count()):
		_sweat_rest[i] = (sweat.get_child(i) as Node2D).position

func _build_limbs() -> void:
	# Drawn before the body so they appear to come from behind it.
	# Thicker limbs read as chubby cartoon stubs; the old 9/10 px lines
	# looked like toothpicks at stage scale.
	arm_l = _make_limb("ArmL", 12.0)
	arm_l.position = Vector2(-BODY_RX * 0.72, -4.0)
	_set_limb_shape(arm_l, Vector2(-26.0, 14.0), Vector2(-40.0, 30.0))

	arm_r = _make_limb("ArmR", 12.0)
	arm_r.position = Vector2(BODY_RX * 0.72, -4.0)
	_set_limb_shape(arm_r, Vector2(26.0, 14.0), Vector2(40.0, 30.0))

	leg_l = _make_limb("LegL", 13.0)
	leg_l.position = Vector2(-17.0, BODY_RY * 0.82)
	_set_limb_shape(leg_l, Vector2(-4.0, 18.0), Vector2(-9.0, 34.0))

	leg_r = _make_limb("LegR", 13.0)
	leg_r.position = Vector2(17.0, BODY_RY * 0.82)
	_set_limb_shape(leg_r, Vector2(4.0, 18.0), Vector2(9.0, 34.0))

func _make_limb(part_name: String, width: float) -> Line2D:
	var limb := Line2D.new()
	limb.name = part_name
	limb.width = width
	limb.default_color = SKIN_SHADE
	limb.joint_mode = Line2D.LINE_JOINT_ROUND
	limb.begin_cap_mode = Line2D.LINE_CAP_ROUND
	limb.end_cap_mode = Line2D.LINE_CAP_ROUND
	rig.add_child(limb)
	return limb

func _set_limb_shape(limb: Line2D, mid: Vector2, tip: Vector2) -> void:
	limb.clear_points()
	limb.add_point(Vector2.ZERO)
	limb.add_point(mid)
	limb.add_point(tip)

func _build_body() -> void:
	body = Polygon2D.new()
	body.name = "Body"
	# Droplet silhouette, not a blob — see _droplet().
	body.polygon = _droplet(BODY_RX, BODY_RY, 30)
	body.color = _skin
	rig.add_child(body)

	# Darker underside gives volume without a shader. Kept LOW and translucent:
	# the old version sat centred at y≈26 — exactly where the mouth is drawn —
	# so it read as a giant muzzle/snout instead of belly shading.
	shade = Polygon2D.new()
	shade.name = "Shade"
	shade.polygon = _ellipse(BODY_RX * 0.74, BODY_RY * 0.24, 18)
	shade.position = Vector2(0.0, BODY_RY * 0.72)
	shade.color = Color(SKIN_SHADE, 0.42)
	rig.add_child(shade)

	shine = Polygon2D.new()
	shine.name = "Shine"
	# Sized off the body radii by DropletShape, so it stays inside the tapered
	# upper half. The old hand-placed points assumed an ellipse and poked
	# outside the silhouette near the tip.
	shine.polygon = DropletShape.highlight(BODY_RX, BODY_RY)
	shine.color = Color(1.0, 1.0, 1.0, 0.5)
	rig.add_child(shine)

func _build_face() -> void:
	eye_l = _make_eye("EyeL", -17.0)
	eye_r = _make_eye("EyeR", 17.0)
	pupil_l = eye_l.get_node("Pupil") as Polygon2D
	pupil_r = eye_r.get_node("Pupil") as Polygon2D
	lid_l = eye_l.get_node("Lid") as Polygon2D
	lid_r = eye_r.get_node("Lid") as Polygon2D

	brow_l = _make_brow("BrowL", -17.0)
	brow_r = _make_brow("BrowR", 17.0)

	# Filled mouth (for open shapes: gasp, scream, grin) …
	mouth = Polygon2D.new()
	mouth.name = "Mouth"
	mouth.position = Vector2(0.0, 20.0)
	mouth.color = Color(0.14, 0.07, 0.10)
	rig.add_child(mouth)

	# … plus a stroked mouth (for closed shapes: smile, frown, flat line).
	mouth_line = Line2D.new()
	mouth_line.name = "MouthLine"
	mouth_line.position = Vector2(0.0, 20.0)
	mouth_line.width = 3.4
	mouth_line.default_color = INK
	mouth_line.joint_mode = Line2D.LINE_JOINT_ROUND
	mouth_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	mouth_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	rig.add_child(mouth_line)

func _make_eye(part_name: String, x_offset: float) -> Node2D:
	var eye := Node2D.new()
	eye.name = part_name
	eye.position = Vector2(x_offset, -11.0)
	rig.add_child(eye)

	var white := Polygon2D.new()
	white.name = "White"
	white.polygon = _ellipse(14.0, 15.0, 18)
	white.color = Color(1.0, 1.0, 1.0)
	eye.add_child(white)

	var pupil := Polygon2D.new()
	pupil.name = "Pupil"
	pupil.polygon = _ellipse(6.6, 6.6, 14)
	pupil.color = INK
	eye.add_child(pupil)

	var glint := Polygon2D.new()
	glint.name = "Glint"
	glint.polygon = _ellipse(2.6, 2.6, 8)
	glint.position = Vector2(-3.4, -4.2)
	glint.color = Color(1.0, 1.0, 1.0, 0.95)
	eye.add_child(glint)

	# Eyelid: a rect parked above the eye. Sliding it down = blink / squint.
	# Cheaper and more reliable than animating polygon points.
	var lid := Polygon2D.new()
	lid.name = "Lid"
	lid.polygon = PackedVector2Array([
		Vector2(-15.0, -17.0),
		Vector2(15.0, -17.0),
		Vector2(15.0, 0.0),
		Vector2(-15.0, 0.0),
	])
	lid.color = _skin
	lid.position = Vector2(0.0, -17.0)
	eye.add_child(lid)

	return eye

func _make_brow(part_name: String, x_offset: float) -> Line2D:
	var brow := Line2D.new()
	brow.name = part_name
	brow.width = 4.0
	brow.default_color = INK
	brow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	brow.end_cap_mode = Line2D.LINE_CAP_ROUND
	brow.add_point(Vector2(-10.0, 0.0))
	brow.add_point(Vector2(10.0, 0.0))
	brow.position = Vector2(x_offset, -30.0)
	rig.add_child(brow)
	return brow

func _build_accents() -> void:
	blush_l = _make_blush(-30.0)
	blush_r = _make_blush(30.0)

	# Sweat beads (panic) — three drops, hidden until used.
	# Arced around the tapered tip rather than sat on a flat line: with the
	# droplet silhouette the centre of the head is the *highest* point, so a
	# straight row put the middle bead behind the tip.
	sweat = Node2D.new()
	sweat.name = "Sweat"
	sweat.visible = false
	rig.add_child(sweat)
	var sweat_y: Array[float] = [-34.0, -52.0, -34.0]
	for i in range(3):
		var bead := Polygon2D.new()
		bead.polygon = PackedVector2Array([
			Vector2(0.0, -7.0),
			Vector2(4.6, 2.0),
			Vector2(0.0, 6.0),
			Vector2(-4.6, 2.0),
		])
		bead.color = Color(0.62, 0.88, 1.0, 0.92)
		bead.position = Vector2(-40.0 + float(i) * 40.0, sweat_y[i])
		sweat.add_child(bead)

	# Dizzy stars — orbit above the head when knocked out. Anchored off _tip_y()
	# so they clear the point instead of intersecting it.
	stars = Node2D.new()
	stars.name = "Stars"
	stars.visible = false
	stars.position = Vector2(0.0, _tip_y() - 14.0)
	rig.add_child(stars)
	for i in range(3):
		var star := Polygon2D.new()
		star.polygon = _star(9.0, 4.0, 5)
		star.color = Color(1.0, 0.87, 0.30)
		star.position = Vector2(-26.0 + float(i) * 26.0, 0.0)
		stars.add_child(star)

func _make_blush(x_offset: float) -> Polygon2D:
	var b := Polygon2D.new()
	b.polygon = _ellipse(10.0, 5.6, 12)
	b.position = Vector2(x_offset, 6.0)
	b.color = BLUSH
	b.visible = false
	rig.add_child(b)
	return b

# ── Geometry helpers ──────────────────────────────────────────────────────

func _ellipse(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a: float = float(i) * TAU / float(segments)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## Slightly irregular ellipse. Kept for props/accents that want a hand-drawn
## edge; the character body no longer uses it (see _droplet()).
func _blob(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a: float = float(i) * TAU / float(segments)
		var wobble_x: float = rx + sin(a * 3.0) * 2.6
		var wobble_y: float = ry + cos(a * 2.0) * 2.2
		pts.append(Vector2(cos(a) * wobble_x, sin(a) * wobble_y))
	return pts

## Water-droplet silhouette. Geometry lives in DropletShape so the cutscene
## character and the gameplay droplet cannot drift apart — see that class for
## the construction and why it can't self-intersect.
const TIP_STRETCH: float = DropletShape.TIP_STRETCH

func _droplet(rx: float, ry: float, segments: int) -> PackedVector2Array:
	return DropletShape.outline(rx, ry, segments)

## Highest point of the silhouette — accents (stars, sweat) key off this so they
## stay clear of the tip if TIP_STRETCH is ever retuned.
func _tip_y() -> float:
	return DropletShape.tip_y(BODY_RY)

func _star(outer: float, inner: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var total: int = points * 2
	for i in range(total):
		var a: float = float(i) * TAU / float(total) - PI * 0.5
		var r: float = outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts

func _arc(width: float, curve: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var t: float = float(i) / float(segments - 1)
		var x: float = lerp(-width, width, t)
		pts.append(Vector2(x, sin(t * PI) * curve))
	return pts

# ── Appearance ────────────────────────────────────────────────────────────

func set_skin(color: Color) -> void:
	build()
	_skin = color
	body.color = color
	# Shade stays translucent (see _build_body); limbs stay opaque or they
	# would look see-through against the background.
	shade.color = Color(color.darkened(0.24), 0.42)
	var limb_color := color.darkened(0.28)
	arm_l.default_color = limb_color
	arm_r.default_color = limb_color
	leg_l.default_color = limb_color
	leg_r.default_color = limb_color
	lid_l.color = color
	lid_r.color = color

func get_expression() -> int:
	return _expression

## Reshapes existing polygons — allocates no nodes.
func set_expression(expression: int) -> void:
	build()
	_expression = expression

	# Defaults, overridden per case below.
	var lid_drop: float = 0.0
	var pupil_scale: float = 1.0
	var brow_angle: float = 0.0
	var brow_lift: float = 0.0
	var show_blush: bool = false
	var show_sweat: bool = false
	var show_stars: bool = false

	match expression:
		Mood.HAPPY:
			_set_mouth_open(_arc(19.0, 15.0, 11), true)
			brow_lift = -3.0
			show_blush = true
		Mood.NEUTRAL:
			_set_mouth_stroke(_arc(13.0, 3.0, 7))
		Mood.WORRIED:
			_set_mouth_stroke(_arc(12.0, -5.0, 7))
			brow_angle = 0.26
			pupil_scale = 1.12
		Mood.PANIC:
			# Wide open screaming mouth.
			_set_mouth_open(_ellipse(15.0, 19.0, 14), false)
			brow_angle = 0.42
			brow_lift = -6.0
			pupil_scale = 1.3
			show_sweat = true
		Mood.SHOCKED:
			_set_mouth_open(_ellipse(11.0, 14.0, 12), false)
			brow_lift = -9.0
			pupil_scale = 0.55
		Mood.SAD:
			_set_mouth_stroke(_arc(14.0, -9.0, 9))
			brow_angle = 0.34
			lid_drop = 6.0
			pupil_scale = 0.9
		Mood.SMUG:
			_set_mouth_stroke(_smirk())
			brow_angle = -0.2
			lid_drop = 7.0
			show_blush = true
		Mood.DIZZY:
			_set_mouth_stroke(_wavy_mouth())
			lid_drop = 4.0
			pupil_scale = 0.75
			show_stars = true
		Mood.DEAD:
			_set_mouth_stroke(_arc(12.0, -4.0, 7))
			lid_drop = 0.0
			# X-eyes: collapse the whites, cross the pupils.
			pupil_scale = 1.0
			show_stars = false
		_:
			_set_mouth_stroke(_arc(13.0, 3.0, 7))

	# The open line for this mood, recorded so blink() can reopen to it instead of re-reading
	# the lids mid-blink. See the block comment on _lid_open_y.
	_lid_open_y = -17.0 + lid_drop
	lid_l.position.y = _lid_open_y
	lid_r.position.y = _lid_open_y
	pupil_l.scale = Vector2.ONE * pupil_scale
	pupil_r.scale = Vector2.ONE * pupil_scale
	brow_l.rotation = brow_angle
	brow_r.rotation = -brow_angle
	brow_l.position.y = -30.0 + brow_lift
	brow_r.position.y = -30.0 + brow_lift
	blush_l.visible = show_blush
	blush_r.visible = show_blush
	sweat.visible = show_sweat
	stars.visible = show_stars

	_apply_dead_eyes(expression == Mood.DEAD)

func _apply_dead_eyes(is_dead: bool) -> void:
	# DWTD's signature "X" eyes. Reuses the pupil polygons rather than
	# spawning cross sprites.
	if is_dead:
		pupil_l.polygon = _cross(11.0, 3.2)
		pupil_r.polygon = _cross(11.0, 3.2)
		eye_l.get_node("Glint").visible = false
		eye_r.get_node("Glint").visible = false
	else:
		pupil_l.polygon = _ellipse(6.6, 6.6, 14)
		pupil_r.polygon = _ellipse(6.6, 6.6, 14)
		eye_l.get_node("Glint").visible = true
		eye_r.get_node("Glint").visible = true

func _cross(arm: float, thick: float) -> PackedVector2Array:
	# Single concave polygon shaped like an X (12 points).
	var a: float = arm
	var t: float = thick
	return PackedVector2Array([
		Vector2(-a, -a + t), Vector2(-a + t, -a), Vector2(0.0, -t),
		Vector2(a - t, -a), Vector2(a, -a + t), Vector2(t, 0.0),
		Vector2(a, a - t), Vector2(a - t, a), Vector2(0.0, t),
		Vector2(-a + t, a), Vector2(-a, a - t), Vector2(-t, 0.0),
	])

func _smirk() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(8):
		var t: float = float(i) / 7.0
		pts.append(Vector2(lerp(-14.0, 12.0, t), sin(t * PI * 0.7) * 7.0 - 2.0))
	return pts

func _wavy_mouth() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(11):
		var t: float = float(i) / 10.0
		pts.append(Vector2(lerp(-14.0, 14.0, t), sin(t * PI * 3.0) * 3.4))
	return pts

func _set_mouth_stroke(points: PackedVector2Array) -> void:
	mouth.visible = false
	mouth_line.visible = true
	mouth_line.points = points

func _set_mouth_open(points: PackedVector2Array, close_with_line: bool) -> void:
	mouth.visible = true
	mouth.polygon = points
	mouth_line.visible = close_with_line
	if close_with_line:
		mouth_line.points = points

# ── Poses ─────────────────────────────────────────────────────────────────

enum ArmPose { REST, UP, CHEER, REACH, BRACE, DROOP }

func set_arm_pose(pose: int) -> void:
	build()
	match pose:
		ArmPose.UP:
			_set_limb_shape(arm_l, Vector2(-20.0, -18.0), Vector2(-26.0, -42.0))
			_set_limb_shape(arm_r, Vector2(20.0, -18.0), Vector2(26.0, -42.0))
		ArmPose.CHEER:
			_set_limb_shape(arm_l, Vector2(-28.0, -14.0), Vector2(-46.0, -34.0))
			_set_limb_shape(arm_r, Vector2(28.0, -14.0), Vector2(46.0, -34.0))
		ArmPose.REACH:
			_set_limb_shape(arm_l, Vector2(-24.0, 2.0), Vector2(-48.0, -6.0))
			_set_limb_shape(arm_r, Vector2(24.0, 2.0), Vector2(48.0, -6.0))
		ArmPose.BRACE:
			# Arms crossed in front of the face.
			_set_limb_shape(arm_l, Vector2(-16.0, -8.0), Vector2(10.0, -22.0))
			_set_limb_shape(arm_r, Vector2(16.0, -8.0), Vector2(-10.0, -22.0))
		ArmPose.DROOP:
			_set_limb_shape(arm_l, Vector2(-20.0, 24.0), Vector2(-24.0, 46.0))
			_set_limb_shape(arm_r, Vector2(20.0, 24.0), Vector2(24.0, 46.0))
		_:
			_set_limb_shape(arm_l, Vector2(-26.0, 14.0), Vector2(-40.0, 30.0))
			_set_limb_shape(arm_r, Vector2(26.0, 14.0), Vector2(40.0, 30.0))

## Aim both pupils at a local point (e.g. an incoming object) for "reacting" beats.
func look_at_local(target: Vector2) -> void:
	build()
	var max_shift: float = 4.2
	_aim_pupil(eye_l, pupil_l, target, max_shift)
	_aim_pupil(eye_r, pupil_r, target, max_shift)

func _aim_pupil(eye: Node2D, pupil: Polygon2D, target: Vector2, max_shift: float) -> void:
	var dir: Vector2 = target - eye.position
	if dir.length() > 0.001:
		pupil.position = dir.normalized() * max_shift
	else:
		pupil.position = Vector2.ZERO

func reset_look() -> void:
	build()
	pupil_l.position = Vector2.ZERO
	pupil_r.position = Vector2.ZERO

## Record the Y the actor stands at. Call after the actor has been positioned and
## BEFORE any entrance animation moves it, so hop() knows where the floor is.
func mark_rest() -> void:
	_rest_y = position.y
	_has_rest = true

# ── Motion (all Tween-driven; no _process) ───────────────────────────────

## Gentle breathing loop. Call once when the actor appears. Safe to re-call mid-cycle now:
## every target below is absolute, so a restart eases back onto the authored line instead of
## adopting wherever the last loop happened to be cut. Six mid-cycle restarts used to sink the
## character 16.79 px — a slow, unexplained slide downward across a clip. 76 beat scripts call
## this, and TracePipePathWinOutro calls it twice on the same cast.
func start_idle(speed: float = 1.0) -> void:
	build()
	_kill_idle_tweens()
	_idle_tween = _ct().set_loops()
	var half: float = 0.85 / maxf(speed, 0.05)
	_idle_tween.tween_property(rig, "scale", Vector2(1.03, 0.97), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(rig, "scale", Vector2(0.98, 1.02), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Breathing alone is nearly invisible at a glance — the character read as a
	# still image between beats. A small counter-phase bob on the rig sells it as
	# alive without touching the node's own position (which hop() animates).
	_bob_tween = _ct().set_loops()
	var bob_y: float = _rig_rest_pos.y
	_bob_tween.tween_property(rig, "position:y", bob_y - 5.0, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(rig, "position:y", bob_y, half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Ends the breathing loop and eases the body back to its authored pose. Killing the loops was
## all this used to do, which froze the character mid-breath: the rig kept whatever scale and
## bob the tween had reached, and that leftover pose is what the next restart built on.
func stop_idle() -> void:
	_kill_idle_tweens()
	if not _built or not is_inside_tree():
		return
	_rest_tween = _ct()
	_rest_tween.tween_property(rig, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_rest_tween.parallel().tween_property(rig, "position:y", _rig_rest_pos.y, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Drops the breathing loops and any settle-back in flight, without starting a new one. This is
## what start_idle() and _exit_tree() want; stop_idle() is the version that also settles.
func _kill_idle_tweens() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = null
	if _rest_tween and _rest_tween.is_valid():
		_rest_tween.kill()
	_rest_tween = null

func start_blinking() -> void:
	build()
	stop_blinking()
	_blink_tween = _ct().set_loops()
	_blink_tween.tween_interval(2.4)
	_blink_tween.tween_callback(blink)

func stop_blinking() -> void:
	if _blink_tween and _blink_tween.is_valid():
		_blink_tween.kill()
	_blink_tween = null

## One blink. The eyes reopen to the line the current expression authored (_lid_open_y), not
## to whatever the lids read at call time: a blink fired while an earlier blink was still
## closing captured the CLOSED value and left the character's eyes shut for the rest of the
## clip (measured 12.61 px from open — very nearly all the way down).
func blink() -> void:
	if not _built or _expression == Mood.DEAD:
		return
	if _blink_anim and _blink_anim.is_valid():
		_blink_anim.kill()
	var open_y: float = _lid_open_y
	var tw := _ct()
	_blink_anim = tw
	tw.tween_property(lid_l, "position:y", -1.0, 0.07)
	tw.parallel().tween_property(lid_r, "position:y", -1.0, 0.07)
	tw.tween_property(lid_l, "position:y", open_y, 0.09)
	tw.parallel().tween_property(lid_r, "position:y", open_y, 0.09)
## Squash-and-stretch impact. `amount` 0..1, higher = flatter.
func squash(amount: float = 0.5, duration: float = 0.22) -> void:
	build()
	var flat := Vector2(1.0 + amount * 0.9, 1.0 - amount * 0.75)
	var tw := _ct()
	tw.tween_property(rig, "scale", flat, duration * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rig, "scale", Vector2(1.0 - amount * 0.28, 1.0 + amount * 0.34), duration * 0.3)
	tw.tween_property(rig, "scale", Vector2.ONE, duration * 0.35) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func hop(height: float = 46.0, duration: float = 0.42) -> void:
	build()
	# Always return to the standing line, not to wherever the actor happens to
	# be right now. See _rest_y.
	var base_y: float = _rest_y if _has_rest else position.y
	var tw := _ct()
	tw.tween_property(self, "position:y", base_y - height, duration * 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rig, "scale", Vector2(0.9, 1.14), duration * 0.45)
	# The shadow is a child, so it rises with the actor and read as the character
	# dragging the floor upward. Push it back down by the same amount and shrink
	# it, which is the cue that sells height.
	tw.parallel().tween_property(
		shadow, "position:y", SHADOW_REST_Y + height, duration * 0.45
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(shadow, "scale", Vector2(0.66, 0.66), duration * 0.45)
	tw.parallel().tween_property(shadow, "modulate:a", 0.55, duration * 0.45)
	tw.tween_property(self, "position:y", base_y, duration * 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(rig, "scale", Vector2(1.0, 1.0), duration * 0.55)
	tw.parallel().tween_property(
		shadow, "position:y", SHADOW_REST_Y, duration * 0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(shadow, "scale", Vector2.ONE, duration * 0.55)
	tw.parallel().tween_property(shadow, "modulate:a", 1.0, duration * 0.55)
	tw.tween_callback(squash.bind(0.42, 0.2))

## Sideways rattle. The rig returns to the pose build() authored, not to wherever an earlier
## shake happened to be: capturing rig.position.x at call time parked every overlapping shake
## on the previous one's midpoint (measured 3.24 px off centre, and it accumulates).
func shake(strength: float = 8.0, duration: float = 0.5) -> void:
	build()
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	var base_x: float = _rig_rest_pos.x
	var tw := _ct()
	_shake_tween = tw
	var steps: int = 8
	for i in range(steps):
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		var falloff: float = 1.0 - float(i) / float(steps)
		tw.tween_property(rig, "position:x", base_x + dir * strength * falloff, duration / float(steps))
	tw.tween_property(rig, "position:x", base_x, 0.05)

func spin(turns: float = 1.0, duration: float = 0.6) -> void:
	build()
	var tw := _ct()
	tw.tween_property(rig, "rotation", rig.rotation + TAU * turns, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## Dizzy stars. Repeatable: the previous spin is dropped rather than left to fight this one.
func spin_stars(duration: float = 1.2) -> void:
	build()
	stop_stars()
	stars.visible = true
	_stars_tween = _ct().set_loops()
	_stars_tween.tween_property(stars, "rotation", TAU, duration).from(0.0)

## Switches the dizzy-stars gag off. set_expression() owns the stars' visibility for a MOOD;
## this owns it for the GAG, and the gag is the one that was left spinning forever.
func stop_stars() -> void:
	if _stars_tween and _stars_tween.is_valid():
		_stars_tween.kill()
	_stars_tween = null
	if not _built:
		return
	stars.rotation = 0.0
	stars.visible = false

## Nervous sweat beads, one looping drip each. Repeatable: the previous run's loops are
## dropped first, so firing the gag twice no longer leaves two sets of tweens writing the
## same beads (three calls used to leave nine loops running).
func drip_sweat() -> void:
	build()
	stop_sweat()
	sweat.visible = true
	for i in range(mini(sweat.get_child_count(), _sweat_rest.size())):
		var bead: Node2D = sweat.get_child(i)
		var start_pos: Vector2 = _sweat_rest[i]
		bead.position = start_pos
		var tw := _ct().set_loops()
		_sweat_tweens.append(tw)
		tw.tween_interval(float(i) * 0.18)
		tw.tween_property(bead, "position:y", start_pos.y + 34.0, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(bead, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func() -> void:
			bead.position = start_pos
			bead.modulate.a = 1.0
		)

## Switches the sweat gag off and puts the beads back where build() left them. There was no
## way to stop this gag at all before: it ran for the rest of the clip, and _exit_tree()
## did not stop it either.
func stop_sweat() -> void:
	for tw in _sweat_tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_sweat_tweens.clear()
	if not _built:
		return
	sweat.visible = false
	for i in range(mini(sweat.get_child_count(), _sweat_rest.size())):
		var bead: Node2D = sweat.get_child(i)
		bead.position = _sweat_rest[i]
		bead.modulate.a = 1.0

func _exit_tree() -> void:
	# Kill, don't animate: a tween created while the node is leaving the tree is an error, and
	# there is nothing left to see anyway. Every loop this class owns is dropped here now,
	# including the two gags (stars, sweat) that used to keep running after the actor was gone.
	_kill_idle_tweens()
	stop_blinking()
	stop_stars()
	stop_sweat()
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	if _blink_anim and _blink_anim.is_valid():
		_blink_anim.kill()
	_blink_anim = null




