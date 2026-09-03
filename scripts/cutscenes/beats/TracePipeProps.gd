extends RefCounted

## Trace Pipe Path shared props for the beat tier.
## Flat-fill set: scattered steel pipe segments (cracked ends, hidden
## "Flow" water core), a glowing dotted trace path, a fountain with
## fanned spray arcs, deck chairs with drinks, a pipe lasso and a pair
## of slingshot arms for the launch.
##
## Colours from the minigame: pale work-site backdrop, steel pipe grey,
## traced water blue, glowing path dots.

const SITE := Color(0.85, 0.85, 0.9)
const STEEL := Color(0.6, 0.62, 0.66)
const STEEL_DARK := Color(0.45, 0.47, 0.52)
const STEEL_LIGHT := Color(0.72, 0.74, 0.78)
const WATER := Color(0.2, 0.7, 0.9, 0.85)
const GLOW := Color(0.7, 0.95, 1.0)
const FABRIC_A := Color(0.85, 0.55, 0.2)
const FABRIC_B := Color(0.95, 0.9, 0.8)
const DRINK := Color(0.95, 0.8, 0.3)
const STRAW := Color(0.9, 0.35, 0.3)

static func ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A pipe segment. Origin CENTRE, `size` is the LENGTH along x.
## Named parts: "Flow" (inner water core, alpha 0 until water runs) and,
## when cracked, a jagged "Break" edge biting the right cap.
static func make_pipe_segment(size: float, cracked := false) -> Node2D:
	var root := Node2D.new()
	root.name = "Pipe"
	var r := size * 0.11
	var half := size * 0.5
	var flange := size * 0.06
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-half + flange, -r), Vector2(half - flange, -r),
		Vector2(half - flange, r), Vector2(-half + flange, r),
	])
	body.color = STEEL
	root.add_child(body)
	var shine := Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-half + flange, -r), Vector2(half - flange, -r),
		Vector2(half - flange, -r * 0.35), Vector2(-half + flange, -r * 0.35),
	])
	shine.color = STEEL_LIGHT
	root.add_child(shine)
	for sx in [-1.0, 1.0]:
		var cap := Polygon2D.new()
		cap.polygon = PackedVector2Array([
			Vector2(sx * half, -r * 1.25),
			Vector2(sx * (half - flange), -r * 1.25),
			Vector2(sx * (half - flange), r * 1.25),
			Vector2(sx * half, r * 1.25),
		])
		cap.color = STEEL_DARK
		root.add_child(cap)
	# The water core, revealed when the line connects.
	var flow := Polygon2D.new()
	flow.name = "Flow"
	flow.polygon = PackedVector2Array([
		Vector2(-half + flange, -r * 0.5), Vector2(half - flange, -r * 0.5),
		Vector2(half - flange, r * 0.5), Vector2(-half + flange, r * 0.5),
	])
	flow.color = WATER
	flow.modulate.a = 0.0
	root.add_child(flow)
	if cracked:
		var bite := Polygon2D.new()
		bite.name = "Break"
		bite.polygon = PackedVector2Array([
			Vector2(half - flange * 0.5, -r * 1.25),
			Vector2(half - flange * 1.4, -r * 0.4),
			Vector2(half - flange * 0.6, r * 0.2),
			Vector2(half - flange * 1.5, r * 1.25),
			Vector2(half - flange * 0.5, r * 1.25),
		])
		bite.color = STEEL_DARK
		root.add_child(bite)
	return root

## The glowing dotted trace path. `points` is the polyline to dot along;
## endcaps get slightly bigger dots. Pulse the node's modulate to glow.
static func make_dotted_path(points: PackedVector2Array, dot: float) -> Node2D:
	var root := Node2D.new()
	root.name = "TracePath"
	var step := dot * 2.4
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var n := maxi(int(a.distance_to(b) / step), 1)
		for j in range(n):
			var p := a.lerp(b, float(j) / float(n))
			var d := Polygon2D.new()
			d.polygon = ellipse(dot, dot, 8)
			d.position = p
			d.color = GLOW
			root.add_child(d)
	for p in [points[0], points[points.size() - 1]]:
		var d := Polygon2D.new()
		d.polygon = ellipse(dot * 1.7, dot * 1.7, 10)
		d.position = p
		d.color = GLOW
		root.add_child(d)
	return root
## The fountain. Origin BASE-CENTRE; "Jet" holds the column plus three
## "SprayN" arcs (alpha 0 until the show starts).
static func make_fountain(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Fountain"
	var basin := Polygon2D.new()
	basin.polygon = ellipse(size * 0.5, size * 0.14, 16)
	basin.position = Vector2(0.0, -size * 0.1)
	basin.color = STEEL_DARK
	root.add_child(basin)
	var basin_top := Polygon2D.new()
	basin_top.polygon = ellipse(size * 0.42, size * 0.10, 16)
	basin_top.position = Vector2(0.0, -size * 0.12)
	basin_top.color = STEEL
	root.add_child(basin_top)
	var pedestal := Polygon2D.new()
	pedestal.polygon = PackedVector2Array([
		Vector2(-size * 0.10, -size * 0.1), Vector2(size * 0.10, -size * 0.1),
		Vector2(size * 0.07, -size * 0.48), Vector2(-size * 0.07, -size * 0.48),
	])
	pedestal.color = STEEL
	root.add_child(pedestal)
	var bowl := Polygon2D.new()
	bowl.polygon = ellipse(size * 0.26, size * 0.07, 14)
	bowl.position = Vector2(0.0, -size * 0.5)
	bowl.color = STEEL_DARK
	root.add_child(bowl)
	var jet := Node2D.new()
	jet.name = "Jet"
	jet.position = Vector2(0.0, -size * 0.52)
	var column := Polygon2D.new()
	column.polygon = PackedVector2Array([
		Vector2(-size * 0.05, 0.0), Vector2(size * 0.05, 0.0),
		Vector2(size * 0.02, -size * 0.34), Vector2(-size * 0.02, -size * 0.34),
	])
	column.color = WATER
	jet.add_child(column)
	for i in range(3):
		var spray := Polygon2D.new()
		spray.name = "Spray%d" % i
		spray.polygon = PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(-size * 0.06, -size * 0.10),
			Vector2(size * 0.30, -size * 0.30), Vector2(size * 0.34, -size * 0.24),
			Vector2(size * 0.10, -size * 0.04),
		])
		spray.color = WATER
		spray.rotation = -0.5 + 0.5 * float(i)
		spray.modulate.a = 0.0
		jet.add_child(spray)
	root.add_child(jet)
	return root

## A striped deck chair. Origin FLOOR BASE-CENTRE.
static func make_deck_chair(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "DeckChair"
	var leg_l := Polygon2D.new()
	leg_l.polygon = PackedVector2Array([
		Vector2(-size * 0.30, -size * 0.24), Vector2(-size * 0.22, -size * 0.24),
		Vector2(-size * 0.14, 0.0), Vector2(-size * 0.22, 0.0),
	])
	leg_l.color = STEEL_DARK
	root.add_child(leg_l)
	var leg_r := Polygon2D.new()
	leg_r.polygon = PackedVector2Array([
		Vector2(size * 0.22, -size * 0.24), Vector2(size * 0.30, -size * 0.24),
		Vector2(size * 0.22, 0.0), Vector2(size * 0.14, 0.0),
	])
	leg_r.color = STEEL_DARK
	root.add_child(leg_r)
	var backrest := Polygon2D.new()
	backrest.polygon = PackedVector2Array([
		Vector2(size * 0.14, -size * 0.26), Vector2(size * 0.28, -size * 0.26),
		Vector2(size * 0.42, -size * 0.50), Vector2(size * 0.30, -size * 0.52),
	])
	backrest.color = FABRIC_A
	root.add_child(backrest)
	var seat := Polygon2D.new()
	seat.polygon = PackedVector2Array([
		Vector2(-size * 0.30, -size * 0.20), Vector2(size * 0.30, -size * 0.20),
		Vector2(size * 0.30, -size * 0.28), Vector2(-size * 0.30, -size * 0.28),
	])
	seat.color = FABRIC_B
	root.add_child(seat)
	for i in range(3):
		var stripe := Polygon2D.new()
		var x := (-0.18 + 0.16 * float(i)) * size
		stripe.polygon = PackedVector2Array([
			Vector2(x, -size * 0.20), Vector2(x + size * 0.08, -size * 0.20),
			Vector2(x + size * 0.08, -size * 0.28), Vector2(x, -size * 0.28),
		])
		stripe.color = FABRIC_A
		root.add_child(stripe)
	return root

## A drink glass with a straw. Origin BASE-CENTRE.
static func make_drink(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Drink"
	var glass := Polygon2D.new()
	glass.polygon = PackedVector2Array([
		Vector2(-size * 0.18, 0.0), Vector2(size * 0.18, 0.0),
		Vector2(size * 0.12, -size * 0.5), Vector2(-size * 0.12, -size * 0.5),
	])
	glass.color = Color(1.0, 1.0, 1.0, 0.55)
	root.add_child(glass)
	var liquid := Polygon2D.new()
	liquid.polygon = PackedVector2Array([
		Vector2(-size * 0.14, -size * 0.06), Vector2(size * 0.14, -size * 0.06),
		Vector2(size * 0.10, -size * 0.42), Vector2(-size * 0.10, -size * 0.42),
	])
	liquid.color = DRINK
	root.add_child(liquid)
	var straw := Line2D.new()
	straw.width = size * 0.06
	straw.default_color = STRAW
	straw.points = PackedVector2Array([
		Vector2(size * 0.04, -size * 0.40), Vector2(size * 0.16, -size * 0.74),
	])
	root.add_child(straw)
	return root

## A pipe lasso loop. Origin CENTRE — park it on whoever gets caught.
static func make_lasso(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Lasso"
	var ring := Line2D.new()
	ring.closed = true
	ring.width = size * 0.09
	ring.default_color = STEEL
	ring.points = ellipse(size * 0.5, size * 0.42, 18)
	root.add_child(ring)
	var sheen := Polygon2D.new()
	sheen.polygon = ellipse(size * 0.2, size * 0.16, 12)
	sheen.color = Color(0.7, 0.95, 1.0, 0.25)
	root.add_child(sheen)
	return root

## A tapered water spray. Origin at the NOZZLE; extends +x (caller
## rotates into place). Scale x to grow the jet.
static func make_spray(length: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Spray"
	var jet := Polygon2D.new()
	jet.polygon = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.0, length * 0.08),
		Vector2(length * 0.55, length * 0.30), Vector2(length * 0.85, length * 0.14),
		Vector2(length * 0.5, length * 0.02),
	])
	jet.color = WATER
	root.add_child(jet)
	return root
