extends RefCounted

## Mud Pie Maker shared props for the beat tier.
## Flat-fill bake-sale dressing: empty pie tins, finished pies, the sale
## stand, the fill gauge, Mayor Ripple's wrist-watch, and the mud statue.
##
## Tins, pies and the statue use BASE-CENTRE origins so they can pop, squat
## and roll naturally. The gauge carries a "Fill" child (scale.y) and the
## statue a frozen SPLAT face for the lose gag.

const MEADOW := Color(0.55, 0.75, 0.45)
const GROUND_BROWN := Color(0.45, 0.30, 0.18)
const POT := Color(0.60, 0.35, 0.20)
const POT_RIM := Color(0.70, 0.45, 0.30)
const MUD := Color(0.45, 0.25, 0.10)
const MUD_WET := Color(0.32, 0.18, 0.08)
const TIN_BLUE := Color(0.30, 0.50, 0.70)
const TIN_DARK := Color(0.22, 0.38, 0.55)
const PIE_CRUST := Color(0.85, 0.60, 0.30)
const PIE_DARK := Color(0.70, 0.48, 0.22)
const STEAM := Color(1, 1, 1, 0.85)
const TABLE_WOOD := Color(0.70, 0.52, 0.32)
const TABLE_DARK := Color(0.55, 0.40, 0.24)
const AWNING_RED := Color(0.85, 0.35, 0.35)
const AWNING_STRIPE := Color(0.94, 0.88, 0.80)
const GAUGE_GREY := Color(0.30, 0.30, 0.30)
const GAUGE_INNER := Color(0.15, 0.15, 0.15)
const FILL_GREEN := Color(0.20, 0.90, 0.30)
const FILL_ORANGE := Color(0.90, 0.60, 0.20)
const FILL_RED := Color(0.90, 0.20, 0.20)
const WATCH_GOLD := Color(0.90, 0.75, 0.30)
const WATCH_BAND := Color(0.35, 0.30, 0.28)

static func _ellipse(rx: float, ry: float, points: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## An empty pie tin. Origin base-centre.
static func make_tin(size := 1.0) -> Node2D:
	var t := Node2D.new()
	t.name = "Tin"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-14.0, 0.0), Vector2(14.0, 0.0), Vector2(17.0, -8.0), Vector2(-17.0, -8.0),
	])
	body.color = TIN_DARK
	t.add_child(body)
	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = _ellipse(18.0, 4.0, 12)
	rim.position = Vector2(0.0, -8.0)
	rim.color = TIN_BLUE
	t.add_child(rim)
	var shine := Polygon2D.new()
	shine.name = "Shine"
	shine.polygon = _ellipse(6.0, 1.6, 8)
	shine.position = Vector2(-5.0, -8.0)
	shine.color = Color(1, 1, 1, 0.55)
	t.add_child(shine)
	t.scale = Vector2.ONE * size
	return t

## A finished pie: crust dome in a tin. Origin base-centre.
static func make_pie(size := 1.0) -> Node2D:
	var p := Node2D.new()
	p.name = "Pie"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-14.0, 0.0), Vector2(14.0, 0.0), Vector2(17.0, -8.0), Vector2(-17.0, -8.0),
	])
	body.color = TIN_DARK
	p.add_child(body)
	var dome := Polygon2D.new()
	dome.name = "Dome"
	dome.polygon = _ellipse(16.0, 11.0, 14)
	dome.position = Vector2(0.0, -9.0)
	dome.color = PIE_CRUST
	p.add_child(dome)
	for i in range(3):
		var lattice := Polygon2D.new()
		lattice.name = "Lattice%d" % i
		lattice.polygon = PackedVector2Array([
			Vector2(-14.0 + 9.0 * float(i), -4.0), Vector2(-10.0 + 9.0 * float(i), -4.0),
			Vector2(-6.0 + 9.0 * float(i), -17.0), Vector2(-10.0 + 9.0 * float(i), -17.0),
		])
		lattice.color = PIE_DARK
		p.add_child(lattice)
	var vent := Polygon2D.new()
	vent.name = "Vent"
	vent.polygon = _ellipse(2.0, 2.0, 8)
	vent.position = Vector2(0.0, -14.0)
	vent.color = MUD
	p.add_child(vent)
	p.scale = Vector2.ONE * size
	return p

## The bake-sale stand: tabletop, legs, striped awning. Origin bottom-centre;
## tins and pies sit at y = TABLE_TOP_Y on the surface.
static func make_stand(width: float) -> Node2D:
	var s := Node2D.new()
	s.name = "Stand"
	for side in [-1, 1]:
		var leg := Polygon2D.new()
		leg.name = "Leg"
		leg.polygon = PackedVector2Array([
			Vector2(width * 0.5 * float(side) - 5.0, 0.0),
			Vector2(width * 0.5 * float(side) + 5.0, 0.0),
			Vector2(width * 0.5 * float(side) + 3.0, -46.0),
			Vector2(width * 0.5 * float(side) - 3.0, -46.0),
		])
		leg.color = TABLE_DARK
		s.add_child(leg)
	var top := Polygon2D.new()
	top.name = "Top"
	top.polygon = PackedVector2Array([
		Vector2(-width * 0.5 - 8.0, -46.0), Vector2(width * 0.5 + 8.0, -46.0),
		Vector2(width * 0.5 + 8.0, -54.0), Vector2(-width * 0.5 - 8.0, -54.0),
	])
	top.color = TABLE_WOOD
	s.add_child(top)
	# Striped awning above the tabletop.
	var n := 5
	for i in range(n):
		var stripe := Polygon2D.new()
		stripe.name = "Stripe%d" % i
		var x0 := -width * 0.5 + float(i) * (width / float(n))
		var x1 := -width * 0.5 + float(i + 1) * (width / float(n))
		stripe.polygon = PackedVector2Array([
			Vector2(x0, -86.0), Vector2(x1, -86.0),
			Vector2(x1 - 8.0, -66.0), Vector2(x0 - 8.0, -66.0),
		])
		stripe.color = AWNING_RED if i % 2 == 0 else AWNING_STRIPE
		s.add_child(stripe)
	return s

## Height of the tabletop surface above the stand origin (tins/pies sit here).
static func TABLE_TOP_Y() -> float: return -54.0

## The fill gauge: vertical tube with green/orange/red zones and a "Fill"
## child (scale.y from the bottom) that starts at zero. Origin bottom-centre.
static func make_gauge(size := 1.0) -> Node2D:
	var g := Node2D.new()
	g.name = "Gauge"
	var tube := Polygon2D.new()
	tube.name = "Tube"
	tube.polygon = PackedVector2Array([
		Vector2(-9.0, 0.0), Vector2(9.0, 0.0), Vector2(9.0, -70.0), Vector2(-9.0, -70.0),
	])
	tube.color = GAUGE_INNER
	g.add_child(tube)
	for i in range(3):
		var zone := Polygon2D.new()
		zone.name = "Zone%d" % i
		var y0 := -24.0 * float(i) - 22.0
		zone.polygon = PackedVector2Array([
			Vector2(-7.0, y0), Vector2(7.0, y0), Vector2(7.0, y0 - 22.0), Vector2(-7.0, y0 - 22.0),
		])
		zone.color = (FILL_GREEN if i == 2 else (FILL_ORANGE if i == 1 else FILL_RED))
		zone.color.a = 0.25
		g.add_child(zone)
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = PackedVector2Array([
		Vector2(-7.0, 0.0), Vector2(7.0, 0.0), Vector2(7.0, -66.0), Vector2(-7.0, -66.0),
	])
	fill.color = FILL_GREEN
	fill.scale = Vector2(1.0, 0.001)  # zeroed
	g.add_child(fill)
	var frame := Polygon2D.new()
	frame.name = "Frame"
	frame.polygon = PackedVector2Array([
		Vector2(-11.0, 2.0), Vector2(11.0, 2.0), Vector2(11.0, -72.0), Vector2(-11.0, -72.0),
		Vector2(-11.0, -66.0), Vector2(5.0, -66.0), Vector2(5.0, -4.0), Vector2(-11.0, -4.0),
	])
	frame.color = GAUGE_GREY
	g.add_child(frame)
	g.scale = Vector2.ONE * size
	return g

## Mayor Ripple's wrist-watch. Origin centre of the face; pop it up near the
## mayor's wrist and tick the hands.
static func make_watch(size := 1.0) -> Node2D:
	var w := Node2D.new()
	w.name = "Watch"
	var band := Polygon2D.new()
	band.name = "Band"
	band.polygon = PackedVector2Array([
		Vector2(-4.0, -16.0), Vector2(4.0, -16.0), Vector2(4.0, 16.0), Vector2(-4.0, 16.0),
	])
	band.color = WATCH_BAND
	w.add_child(band)
	var face := Polygon2D.new()
	face.name = "Face"
	face.polygon = _ellipse(9.0, 9.0, 14)
	face.color = WATCH_GOLD
	w.add_child(face)
	var dial := Polygon2D.new()
	dial.name = "Dial"
	dial.polygon = _ellipse(6.5, 6.5, 12)
	dial.color = Color(0.96, 0.94, 0.86)
	w.add_child(dial)
	for i in range(2):
		var hand := Polygon2D.new()
		hand.name = "Hand%d" % i
		hand.polygon = PackedVector2Array([
			Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, -5.0), Vector2(-1.0, -5.0),
		])
		hand.color = Color(0.15, 0.15, 0.15)
		hand.rotation = TAU * 0.25 * float(i + 1)
		w.add_child(hand)
	w.scale = Vector2.ONE * size
	return w

## The frozen "mud statue" of Dribble: mud-covered silhouette with a SPLAT
## face (wide white eyes, open mouth). Origin base-centre so it can tip/roll.
static func make_mud_statue(size := 1.0) -> Node2D:
	var s := Node2D.new()
	s.name = "MudStatue"
	var legs := Polygon2D.new()
	legs.name = "Legs"
	legs.polygon = PackedVector2Array([
		Vector2(-16.0, 0.0), Vector2(-6.0, 0.0), Vector2(-4.0, -34.0), Vector2(-14.0, -34.0),
		Vector2(6.0, 0.0), Vector2(16.0, 0.0), Vector2(14.0, -34.0), Vector2(4.0, -34.0),
	])
	legs.color = MUD_WET
	s.add_child(legs)
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = _ellipse(20.0, 24.0, 14)
	body.position = Vector2(0.0, -54.0)
	body.color = MUD
	s.add_child(body)
	var head := Polygon2D.new()
	head.name = "Head"
	head.polygon = _ellipse(13.0, 12.0, 12)
	head.position = Vector2(0.0, -92.0)
	head.color = MUD
	s.add_child(head)
	for side in [-1, 1]:
		var arm := Polygon2D.new()
		arm.name = "Arm"
		arm.polygon = PackedVector2Array([
			Vector2(14.0 * float(side), -66.0), Vector2(24.0 * float(side), -56.0),
			Vector2(21.0 * float(side), -52.0), Vector2(13.0 * float(side), -60.0),
		])
		arm.color = MUD_WET
		s.add_child(arm)
		var eye := Polygon2D.new()
		eye.name = "Eye"
		eye.polygon = _ellipse(3.5, 4.5, 8)
		eye.position = Vector2(5.0 * float(side), -94.0)
		eye.color = Color(1, 1, 1)
		s.add_child(eye)
		var pupil := Polygon2D.new()
		pupil.name = "Pupil"
		pupil.polygon = _ellipse(1.5, 1.5, 6)
		pupil.position = Vector2(5.0 * float(side), -94.5)
		pupil.color = Color(0.1, 0.1, 0.12)
		s.add_child(pupil)
	var mouth := Polygon2D.new()
	mouth.name = "Mouth"
	mouth.polygon = _ellipse(4.0, 5.0, 10)
	mouth.position = Vector2(0.0, -85.0)
	mouth.color = Color(0.12, 0.07, 0.05)
	s.add_child(mouth)
	# Fresh drip running off the chin.
	var drip := Polygon2D.new()
	drip.name = "Drip"
	drip.polygon = PackedVector2Array([
		Vector2(-2.0, -80.0), Vector2(2.0, -80.0), Vector2(0.0, -72.0),
	])
	drip.color = MUD_WET
	s.add_child(drip)
	s.scale = Vector2.ONE * size
	return s

