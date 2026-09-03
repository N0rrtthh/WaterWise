class_name DropletSprite
extends Node2D

## The water droplet the player actually moves during gameplay.
##
## Replaces the `Label` with a 💧 emoji that minigames used to spawn. That
## approach had three problems: the glyph is drawn by whatever emoji font the
## platform ships (so it looked different on every device and could render as a
## hollow box), a Label cannot squash, stretch or blink, and it did not match the
## CartoonActor droplet from the cutscenes — the character in the story and the
## thing under your finger were visibly different objects.
##
## Shares its silhouette with CartoonActor via DropletShape, plus a face, so the
## gameplay droplet reads as the same character, just smaller.
##
## Performance contract (low-end Android):
##   * All parts are built once in _ready(). Nothing allocates per frame.
##   * No _process(); wobble and reactions are Tween-driven.

const INK: Color = Color(0.09, 0.11, 0.14)

## Body radii. 26×32 fills roughly the same screen area as the 52 px emoji it
## replaces, so existing collision radii in the minigames stay valid.
@export var body_rx: float = 26.0
@export var body_ry: float = 32.0
@export var skin: Color = Color(0.36, 0.76, 1.0)

var rig: Node2D
var body: Polygon2D
var shine: Polygon2D
var eye_l: Polygon2D
var eye_r: Polygon2D
var pupil_l: Polygon2D
var pupil_r: Polygon2D
var mouth: Line2D

var _wobble: Tween = null
var _react: Tween = null

func _ready() -> void:
	_build()
	start_wobble()

func _build() -> void:
	rig = Node2D.new()
	rig.name = "Rig"
	add_child(rig)

	body = Polygon2D.new()
	body.name = "Body"
	body.polygon = DropletShape.outline(body_rx, body_ry, 26)
	body.color = skin
	rig.add_child(body)

	shine = Polygon2D.new()
	shine.name = "Shine"
	shine.polygon = DropletShape.highlight(body_rx, body_ry)
	shine.color = Color(1.0, 1.0, 1.0, 0.5)
	rig.add_child(shine)

	eye_l = _make_eye(-body_rx * 0.36)
	eye_r = _make_eye(body_rx * 0.36)
	pupil_l = eye_l.get_child(0) as Polygon2D
	pupil_r = eye_r.get_child(0) as Polygon2D

	mouth = Line2D.new()
	mouth.name = "Mouth"
	mouth.width = 2.2
	mouth.default_color = INK
	mouth.begin_cap_mode = Line2D.LINE_CAP_ROUND
	mouth.end_cap_mode = Line2D.LINE_CAP_ROUND
	mouth.joint_mode = Line2D.LINE_JOINT_ROUND
	mouth.position = Vector2(0.0, body_ry * 0.36)
	mouth.points = _smile(body_rx * 0.30, 3.0)
	rig.add_child(mouth)

func _make_eye(x_offset: float) -> Polygon2D:
	var white := Polygon2D.new()
	white.polygon = _ellipse(body_rx * 0.26, body_rx * 0.28, 12)
	white.color = Color.WHITE
	white.position = Vector2(x_offset, -body_ry * 0.10)
	rig.add_child(white)

	var pupil := Polygon2D.new()
	pupil.polygon = _ellipse(body_rx * 0.13, body_rx * 0.13, 10)
	pupil.color = INK
	white.add_child(pupil)

	return white

func _ellipse(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var a: float = float(i) * TAU / float(segments)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _smile(width: float, curve: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(7):
		var t: float = float(i) / 6.0
		pts.append(Vector2(lerp(-width, width, t), sin(t * PI) * curve))
	return pts

# ── Motion ────────────────────────────────────────────────────────────────
# Every tween is stored and killed before a new one starts. Two Tweens on the
# same property means the later one silently wins, which showed up as the
# droplet freezing mid-squash after a few hits.

## Idle bob so the droplet never looks like a static decal.
func start_wobble(speed: float = 1.0) -> void:
	stop_wobble()
	_wobble = create_tween().set_loops()
	var half: float = 0.5 / maxf(speed, 0.05)
	_wobble.tween_property(rig, "scale", Vector2(1.05, 0.95), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_wobble.tween_property(rig, "scale", Vector2(0.96, 1.04), half) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_wobble() -> void:
	if _wobble and _wobble.is_valid():
		_wobble.kill()
	_wobble = null

## Squash-and-stretch pop for a good hit. Restarts the idle bob afterwards so
## the two never animate `rig:scale` at the same time.
func react_happy() -> void:
	_play_react(Vector2(1.35, 0.72), _smile(body_rx * 0.34, 4.5))

## Recoil for a mistake: taller and narrower reads as a flinch.
func react_hurt() -> void:
	_play_react(Vector2(0.72, 1.32), _smile(body_rx * 0.30, -3.5))

func _play_react(peak: Vector2, mouth_points: PackedVector2Array) -> void:
	stop_wobble()
	if _react and _react.is_valid():
		_react.kill()
	mouth.points = mouth_points
	_react = create_tween()
	_react.tween_property(rig, "scale", peak, 0.08).set_trans(Tween.TRANS_QUAD)
	_react.tween_property(rig, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_react.tween_callback(func() -> void:
		mouth.points = _smile(body_rx * 0.30, 3.0)
		start_wobble()
	)

## Aim both pupils at a point in this node's local space, so the droplet
## visibly tracks whatever it is about to hit or catch.
func look_at_local(target: Vector2) -> void:
	var shift: float = body_rx * 0.09
	_aim(eye_l, pupil_l, target, shift)
	_aim(eye_r, pupil_r, target, shift)

func _aim(eye: Polygon2D, pupil: Polygon2D, target: Vector2, shift: float) -> void:
	var dir: Vector2 = target - eye.position
	pupil.position = dir.normalized() * shift if dir.length() > 0.001 else Vector2.ZERO

func set_skin(color: Color) -> void:
	skin = color
	if body:
		body.color = color
