extends RefCounted

## Plug The Leak shared props for the beat tier.
## Flat-fill plumbing: multi-hole pipes, spray jets, corks, floating music
## notes, and leftover spray mist.
##
## Pipes use CENTRE origins with named "Hole%d" children at caller-chosen
## x offsets (each hole gets a distinct x — no shared positions). Jets aim
## down +X; rotate the jet node to aim the spray.

const BG_PALE := Color(0.85, 0.90, 0.85)
const PIPE := Color(0.50, 0.50, 0.55)
const PIPE_DARK := Color(0.40, 0.40, 0.45)
const WATER := Color(0.30, 0.60, 1.00, 0.85)
const WATER_SOFT := Color(0.55, 0.78, 1.00, 0.6)
const GOOD_GREEN := Color(0.30, 0.70, 0.30)
const BAD_RED := Color(0.60, 0.30, 0.30)
const CORK := Color(0.75, 0.58, 0.35)
const CORK_DARK := Color(0.60, 0.45, 0.26)
const NOTE := Color(0.25, 0.35, 0.55)
const MIST := Color(1, 1, 1, 0.32)

static func _ellipse(rx: float, ry: float, points: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A pipe run with named "Hole%d" leak anchors. Origin CENTRE of the run;
## `hole_xs` are x offsets from centre (keep them distinct per pipe).
static func make_pipe(length: float, hole_xs: Array) -> Node2D:
	var p := Node2D.new()
	p.name = "Pipe"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-length * 0.5, -13.0), Vector2(length * 0.5, -13.0),
		Vector2(length * 0.5, 13.0), Vector2(-length * 0.5, 13.0),
	])
	body.color = PIPE
	p.add_child(body)
	for x_f in [-0.34, 0.34]:
		var flange := Polygon2D.new()
		flange.name = "Flange"
		flange.polygon = PackedVector2Array([
			Vector2(length * x_f - 5.0, -16.0), Vector2(length * x_f + 5.0, -16.0),
			Vector2(length * x_f + 5.0, 16.0), Vector2(length * x_f - 5.0, 16.0),
		])
		flange.color = PIPE_DARK
		p.add_child(flange)
	for i in range(hole_xs.size()):
		var hx := float(hole_xs[i])
		var hole := Polygon2D.new()
		hole.name = "Hole%d" % i
		hole.polygon = _ellipse(5.5, 6.5, 10)
		hole.position = Vector2(hx, 0.0)
		hole.color = BAD_RED
		p.add_child(hole)
		var crack := Polygon2D.new()
		crack.name = "Crack%d" % i
		crack.polygon = PackedVector2Array([
			Vector2(hx - 2.0, -13.0), Vector2(hx + 2.0, -13.0),
			Vector2(hx + 5.0, -20.0), Vector2(hx + 1.0, -20.0),
		])
		crack.color = PIPE_DARK
		p.add_child(crack)
	return p

## A continuous spray jet: one-shot-never GPUParticles2D cone aimed down +X.
## Rotate the returned node to aim. Texture comes from the stage's dot tex.
static func make_jet(size: float, tex: Texture2D) -> GPUParticles2D:
	var j := GPUParticles2D.new()
	j.name = "Jet"
	j.amount = 26
	j.lifetime = 0.5
	j.local_coords = false
	j.texture = tex
	j.position = Vector2.ZERO
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 3.0
	m.direction = Vector3(1, 0, 0)
	m.spread = 16.0
	m.initial_velocity_min = 340.0 * size
	m.initial_velocity_max = 520.0 * size
	m.gravity = Vector3(0, 700, 0)
	m.scale_min = 0.4 * size
	m.scale_max = 0.9 * size
	m.color = WATER
	j.process_material = m
	j.emitting = true
	return j

## A cork. Origin base-centre; pops base-first into holes.
static func make_cork(size := 1.0) -> Node2D:
	var c := Node2D.new()
	c.name = "Cork"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-7.0, 0.0), Vector2(7.0, 0.0), Vector2(9.0, -16.0), Vector2(-9.0, -16.0),
	])
	body.color = CORK
	c.add_child(body)
	var cap := Polygon2D.new()
	cap.name = "Cap"
	cap.polygon = _ellipse(9.0, 3.0, 10)
	cap.position = Vector2(0.0, -16.0)
	cap.color = CORK_DARK
	c.add_child(cap)
	c.scale = Vector2.ONE * size
	return c

## A floating music note (head + stem + flag). Origin centre of the head.
static func make_note(size := 1.0) -> Node2D:
	var n := Node2D.new()
	n.name = "Note"
	var head := Polygon2D.new()
	head.name = "Head"
	head.polygon = _ellipse(6.0, 4.5, 12)
	head.rotation = 0.35
	head.color = NOTE
	n.add_child(head)
	var stem := Polygon2D.new()
	stem.name = "Stem"
	stem.polygon = PackedVector2Array([
		Vector2(4.0, -3.0), Vector2(6.5, -3.0), Vector2(6.5, -22.0), Vector2(4.0, -22.0),
	])
	stem.color = NOTE
	n.add_child(stem)
	var flag := Polygon2D.new()
	flag.name = "Flag"
	flag.polygon = PackedVector2Array([
		Vector2(6.5, -22.0), Vector2(15.0, -18.0), Vector2(13.0, -13.0), Vector2(6.5, -16.0),
	])
	flag.color = NOTE
	n.add_child(flag)
	n.scale = Vector2.ONE * size
	return n

## A patch of leftover spray mist — translucent white ellipse cluster.
## Origin centre; lay it where the spray settled.
static func make_mist(width: float) -> Node2D:
	var m := Node2D.new()
	m.name = "Mist"
	var n := int(width / 30.0)
	for i in range(n):
		var puff := Polygon2D.new()
		puff.name = "Puff%d" % i
		var rx := 14.0 + 8.0 * float(i % 3)
		puff.polygon = _ellipse(rx, rx * 0.6, 12)
		puff.position = Vector2(
			-width * 0.5 + float(i) * (width / float(n)) + 8.0,
			-6.0 + 7.0 * float((i * 7) % 5)
		)
		puff.color = MIST if i % 2 == 0 else Color(1, 1, 1, 0.2)
		m.add_child(puff)
	return m
