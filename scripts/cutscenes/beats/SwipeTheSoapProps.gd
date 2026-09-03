extends RefCounted

## Swipe The Soap shared props for the beat tier.
## Flat-fill set: giant soap bar, pedestal, directional arrows, bleachers,
## market stalls, a door, surf bubbles, and a bubble-firework burst.
##
## Colours taken from the minigame: cool blue-white bg, pale sink fixture,
## green soap, translucent white bubbles.

const BG := Color(0.9, 0.95, 1.0)
const SINK := Color(0.9, 0.9, 0.95)
const SINK_DARK := Color(0.78, 0.78, 0.86)
const SOAP := Color(0.4, 0.8, 0.5)
const SOAP_DARK := Color(0.32, 0.68, 0.42)
const SOAP_SHEEN := Color(1.0, 1.0, 1.0, 0.45)
const BUBBLE := Color(1.0, 1.0, 1.0, 0.35)
const BUBBLE_RIM := Color(0.75, 0.88, 1.0, 0.7)
const ARROW := Color(0.35, 0.5, 0.85)
const WOOD := Color(0.55, 0.35, 0.2)
const AWNING_A := Color(0.85, 0.35, 0.3)
const AWNING_B := Color(0.95, 0.92, 0.88)

static func _ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A soap bar. Origin BASE-CENTRE. `Sheen` is exposed for gleam sweeps.
static func make_soap(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Soap"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-size * 0.5, 0.0), Vector2(size * 0.5, 0.0),
		Vector2(size * 0.5, -size * 0.42), Vector2(-size * 0.5, -size * 0.42),
	])
	body.color = SOAP
	root.add_child(body)
	var ridge := Polygon2D.new()
	ridge.name = "Ridge"
	ridge.polygon = PackedVector2Array([
		Vector2(-size * 0.5, -size * 0.18), Vector2(size * 0.5, -size * 0.18),
		Vector2(size * 0.5, -size * 0.42), Vector2(-size * 0.5, -size * 0.42),
	])
	ridge.color = SOAP_DARK
	root.add_child(ridge)
	var sheen := Polygon2D.new()
	sheen.name = "Sheen"
	sheen.polygon = PackedVector2Array([
		Vector2(-size * 0.36, -size * 0.06), Vector2(-size * 0.22, -size * 0.06),
		Vector2(-size * 0.13, -size * 0.38), Vector2(-size * 0.27, -size * 0.38),
	])
	sheen.color = SOAP_SHEEN
	root.add_child(sheen)
	return root

## A display pedestal. Origin BASE-CENTRE.
static func make_pedestal(width: float, height: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Pedestal"
	var column := Polygon2D.new()
	column.name = "Column"
	column.polygon = PackedVector2Array([
		Vector2(-width * 0.32, -height), Vector2(width * 0.32, -height),
		Vector2(width * 0.32, 0.0), Vector2(-width * 0.32, 0.0),
	])
	column.color = SINK
	root.add_child(column)
	var cap := Polygon2D.new()
	cap.name = "Cap"
	cap.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -height), Vector2(width * 0.5, -height),
		Vector2(width * 0.5, -height * 0.9), Vector2(-width * 0.5, -height * 0.9),
	])
	cap.color = SINK_DARK
	root.add_child(cap)
	return root

## A chunky directional arrow (a filled chevron + shaft).
## Origin CENTRE; points +x; flip with rotation = PI.
static func make_arrow(size: float) -> Polygon2D:
	var arrow := Polygon2D.new()
	arrow.name = "Arrow"
	arrow.polygon = PackedVector2Array([
		Vector2(-size * 0.5, -size * 0.10), Vector2(size * 0.1, -size * 0.10),
		Vector2(size * 0.1, -size * 0.28), Vector2(size * 0.5, 0.0),
		Vector2(size * 0.1, size * 0.28), Vector2(size * 0.1, size * 0.10),
		Vector2(-size * 0.5, size * 0.10),
	])
	arrow.color = ARROW
	return arrow

## Bleacher stands: stepped rows. Origin BASE-CENTRE.
static func make_bleachers(width: float, height: float, rows: int = 3) -> Node2D:
	var root := Node2D.new()
	root.name = "Bleachers"
	var step_w := width / float(rows)
	for i in range(rows):
		var h := height * float(i + 1) / float(rows)
		var step := Polygon2D.new()
		step.name = "Row"
		step.polygon = PackedVector2Array([
			Vector2(-width * 0.5 + step_w * float(i), -h),
			Vector2(-width * 0.5 + step_w * float(i + 1), -h),
			Vector2(-width * 0.5 + step_w * float(i + 1), 0.0),
			Vector2(-width * 0.5 + step_w * float(i), 0.0),
		])
		step.color = SINK if i % 2 == 0 else SINK_DARK
		root.add_child(step)
	return root

## A soap-surf bubble. Origin CENTRE.
static func make_bubble(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Bubble"
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = _ellipse(size * 0.5, size * 0.5, 18)
	fill.color = BUBBLE
	root.add_child(fill)
	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = _ellipse(size * 0.06, size * 0.06, 8)
	rim.position = Vector2(-size * 0.22, -size * 0.20)
	rim.color = Color(1.0, 1.0, 1.0, 0.9)
	root.add_child(rim)
	return root

## A market stall: posts + striped awning. Origin BASE-CENTRE; the
## awning is a child node named "Awning" for wobble gags.
static func make_stall(width: float, height: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Stall"
	for x in [-0.36, 0.36]:
		var post := Polygon2D.new()
		post.name = "Post"
		post.polygon = PackedVector2Array([
			Vector2(width * x - width * 0.03, -height * 0.72),
			Vector2(width * x + width * 0.03, -height * 0.72),
			Vector2(width * x + width * 0.03, 0.0),
			Vector2(width * x - width * 0.03, 0.0),
		])
		post.color = WOOD
		root.add_child(post)
	var counter := Polygon2D.new()
	counter.name = "Counter"
	counter.polygon = PackedVector2Array([
		Vector2(-width * 0.42, -height * 0.30), Vector2(width * 0.42, -height * 0.30),
		Vector2(width * 0.42, -height * 0.20), Vector2(-width * 0.42, -height * 0.20),
	])
	counter.color = WOOD
	root.add_child(counter)
	var awning := Polygon2D.new()
	awning.name = "Awning"
	awning.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -height * 0.68), Vector2(width * 0.5, -height * 0.68),
		Vector2(width * 0.5, -height * 0.86), Vector2(-width * 0.5, -height * 0.86),
	])
	awning.color = AWNING_A
	root.add_child(awning)
	for s in range(4):
		var stripe := Polygon2D.new()
		stripe.name = "Stripe"
		var x0 := -width * 0.5 + width * 0.25 * float(s) + width * 0.125
		stripe.polygon = PackedVector2Array([
			Vector2(x0, -height * 0.68), Vector2(x0 + width * 0.125, -height * 0.68),
			Vector2(x0 + width * 0.125, -height * 0.86),
			Vector2(x0, -height * 0.86),
		])
		stripe.color = AWNING_B
		awning.add_child(stripe)
	return root

## A door frame. Origin BASE-CENTRE.
static func make_door(width: float, height: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Door"
	var frame := Polygon2D.new()
	frame.name = "Frame"
	frame.polygon = PackedVector2Array([
		Vector2(-width * 0.5, 0.0), Vector2(width * 0.5, 0.0),
		Vector2(width * 0.5, -height), Vector2(-width * 0.5, -height),
	])
	frame.color = WOOD
	root.add_child(frame)
	var panel := Polygon2D.new()
	panel.name = "Panel"
	panel.polygon = PackedVector2Array([
		Vector2(-width * 0.38, 0.0), Vector2(width * 0.38, 0.0),
		Vector2(width * 0.38, -height * 0.88), Vector2(-width * 0.38, -height * 0.88),
	])
	panel.color = SINK_DARK
	root.add_child(panel)
	var knob := Polygon2D.new()
	knob.name = "Knob"
	knob.polygon = _ellipse(width * 0.05, width * 0.05, 8)
	knob.position = Vector2(width * 0.26, -height * 0.45)
	knob.color = Color(0.85, 0.7, 0.2)
	root.add_child(knob)
	return root

## A soft round dot texture for particle bursts.
static func make_dot_tex(size: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - r, y - r).length() / r
			if d <= 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d * d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

## A ONE-SHOT bubble-firework burst. Caller positions it and calls
## `emitting = true`; the node frees itself after its last bubbles die.
static func make_bubble_burst(dot_tex: Texture2D, scale_px: float) -> GPUParticles2D:
	var burst := GPUParticles2D.new()
	burst.name = "BubbleBurst"
	burst.one_shot = true
	burst.emitting = false
	burst.amount = 26
	burst.lifetime = 0.9
	burst.explosiveness = 0.95
	burst.local_coords = false
	burst.texture = dot_tex
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = scale_px * 0.12
	m.direction = Vector3(0.0, -1.0, 0.0)
	m.spread = 180.0
	m.initial_velocity_min = scale_px * 0.35
	m.initial_velocity_max = scale_px * 0.85
	m.gravity = Vector3(0.0, scale_px * 0.5, 0.0)
	m.scale_min = 0.5
	m.scale_max = 1.3
	burst.process_material = m
	var mod := CanvasItemMaterial.new()
	mod.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	burst.material = mod
	burst.modulate = Color(1.0, 1.0, 1.0, 0.7)
	burst.finished.connect(burst.queue_free)
	return burst
