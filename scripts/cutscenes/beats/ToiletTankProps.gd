extends RefCounted

## Toilet Tank Fix shared props for the beat tier.
## Flat-fill set: a porcelain toilet with a tank (lid seated or leaning
## off), a pushable flush lever, a rising tank water body with the green
## target line, a singable bowl mouth, music notes, porcelain shards, a
## burst geyser and the cliff-side sewer outlet.
##
## Colours from the minigame: pale bathroom wall, porcelain white,
## translucent tank water, green target line.

const WALL := Color(0.9, 0.9, 0.95)
const TILE := Color(0.78, 0.8, 0.85)
const TILE_LINE := Color(0.66, 0.68, 0.74)
const PORCELAIN := Color(0.95, 0.95, 0.95)
const PORCELAIN_SHADE := Color(0.82, 0.84, 0.88)
const OUTLINE := Color(0.7, 0.7, 0.7)
const WATER := Color(0.3, 0.6, 0.9, 0.7)
const LINE := Color(0.2, 0.8, 0.2)
const MOUTH := Color(0.25, 0.3, 0.4)
const NOTE := Color(0.95, 0.8, 0.3)
const SHARD := Color(0.9, 0.9, 0.92)
const SEWER := Color(0.3, 0.32, 0.36)
const FLUSH := Color(0.4, 0.75, 1.0, 0.8)

static func _ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## Tank water body anchored at the tank's BOTTOM-CENTRE (tank-local
## coords). `height` is absolute — re-run to raise/lower the fill.
static func tank_poly(size: float, height: float) -> PackedVector2Array:
	var h := minf(height, size * 0.5)
	return PackedVector2Array([
		Vector2(-size * 0.27, 0.0), Vector2(size * 0.27, 0.0),
		Vector2(size * 0.27, -h), Vector2(-size * 0.27, -h),
	])

## The toilet. Origin FLOOR BASE-CENTRE, `size` is total height.
## Named parts: "Tank" (origin bottom-centre) with "TankWater" +
## "TargetLine" + "Handle" (lever rotates down to flush), "Lid", "Seat",
## "Mouth" (the bowl opening — scale it to sing) and "BowlWater".
static func make_toilet(size: float, lid_off := false, singer := false) -> Node2D:
	var root := Node2D.new()
	root.name = "Toilet"
	# The tank, mounted at the back, origin bottom-centre.
	var tank := Node2D.new()
	tank.name = "Tank"
	tank.position = Vector2(-size * 0.04, -size * 0.46)
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-size * 0.3, 0.0), Vector2(size * 0.3, 0.0),
		Vector2(size * 0.3, -size * 0.5), Vector2(-size * 0.3, -size * 0.5),
	])
	body.color = PORCELAIN
	tank.add_child(body)
	var shading := Polygon2D.new()
	shading.polygon = PackedVector2Array([
		Vector2(size * 0.14, 0.0), Vector2(size * 0.3, 0.0),
		Vector2(size * 0.3, -size * 0.5), Vector2(size * 0.14, -size * 0.5),
	])
	shading.color = PORCELAIN_SHADE
	tank.add_child(shading)
	var rim := Line2D.new()
	rim.width = size * 0.012
	rim.closed = true
	rim.default_color = OUTLINE
	rim.points = body.polygon
	tank.add_child(rim)
	# Tank water + the green mark everyone must hit.
	var water := Polygon2D.new()
	water.name = "TankWater"
	water.polygon = tank_poly(size, size * 0.1)
	water.color = WATER
	tank.add_child(water)
	var target := Line2D.new()
	target.name = "TargetLine"
	target.width = size * 0.022
	target.default_color = LINE
	target.points = PackedVector2Array([
		Vector2(-size * 0.3, -size * 0.37), Vector2(size * 0.3, -size * 0.37),
	])
	tank.add_child(target)
	# The flush lever, top right of the tank. Rotates down to flush.
	var handle := Node2D.new()
	handle.name = "Handle"
	handle.position = Vector2(size * 0.26, -size * 0.42)
	var lever := Polygon2D.new()
	lever.polygon = PackedVector2Array([
		Vector2(0.0, -size * 0.02), Vector2(size * 0.12, -size * 0.05),
		Vector2(size * 0.12, size * 0.02), Vector2(0.0, size * 0.03),
	])
	lever.color = Color(0.85, 0.7, 0.25)
	handle.add_child(lever)
	tank.add_child(handle)
	root.add_child(tank)
	# The lid: seated on top, or leaning against the tank when off.
	var lid := Polygon2D.new()
	lid.name = "Lid"
	lid.polygon = PackedVector2Array([
		Vector2(-size * 0.32, 0.0), Vector2(size * 0.32, 0.0),
		Vector2(size * 0.32, -size * 0.07), Vector2(-size * 0.32, -size * 0.07),
	])
	lid.color = PORCELAIN_SHADE
	if lid_off:
		lid.position = Vector2(-size * 0.42, -size * 0.36)
		lid.rotation = 0.9
	else:
		lid.position = Vector2(-size * 0.04, -size * 0.96)
	root.add_child(lid)
	# The pedestal and foot.
	var foot := Polygon2D.new()
	foot.polygon = _ellipse(size * 0.24, size * 0.05, 12)
	foot.position = Vector2(0.0, -size * 0.02)
	foot.color = PORCELAIN_SHADE
	root.add_child(foot)
	var pedestal := Polygon2D.new()
	pedestal.polygon = PackedVector2Array([
		Vector2(-size * 0.17, 0.0), Vector2(size * 0.17, 0.0),
		Vector2(size * 0.23, -size * 0.48), Vector2(-size * 0.23, -size * 0.48),
	])
	pedestal.color = PORCELAIN
	root.add_child(pedestal)
	# The seat and the bowl mouth. The Mouth scales when singing.
	var seat := Polygon2D.new()
	seat.name = "Seat"
	seat.polygon = _ellipse(size * 0.34, size * 0.13, 16)
	seat.position = Vector2(0.0, -size * 0.5)
	seat.color = PORCELAIN
	root.add_child(seat)
	var mouth_scale := 1.12 if singer else 1.0
	var mouth := Polygon2D.new()
	mouth.name = "Mouth"
	mouth.polygon = _ellipse(size * 0.23 * mouth_scale, size * 0.08 * mouth_scale, 16)
	mouth.position = Vector2(0.0, -size * 0.505)
	mouth.color = MOUTH
	root.add_child(mouth)
	var bowl_water := Polygon2D.new()
	bowl_water.name = "BowlWater"
	bowl_water.polygon = _ellipse(size * 0.16 * mouth_scale, size * 0.05 * mouth_scale, 14)
	bowl_water.position = Vector2(0.0, -size * 0.505)
	bowl_water.color = FLUSH
	root.add_child(bowl_water)
	return root
## The tank float on its arm. Origin at the ARM BASE (tank floor).
static func make_float(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Float"
	var arm := Line2D.new()
	arm.width = size * 0.02
	arm.default_color = Color(0.55, 0.58, 0.62)
	arm.points = PackedVector2Array([Vector2.ZERO, Vector2(0.0, -size)])
	root.add_child(arm)
	var ball := Polygon2D.new()
	ball.name = "Ball"
	ball.polygon = _ellipse(size * 0.22, size * 0.22, 14)
	ball.position = Vector2(0.0, -size)
	ball.color = Color(0.9, 0.55, 0.25)
	root.add_child(ball)
	return root

## A music note. Origin at the NOTEHEAD CENTRE.
static func make_note(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Note"
	var head := Polygon2D.new()
	head.polygon = _ellipse(size * 0.28, size * 0.2, 12)
	head.rotation = -0.4
	head.color = NOTE
	root.add_child(head)
	var stem := Line2D.new()
	stem.width = size * 0.07
	stem.default_color = NOTE
	stem.points = PackedVector2Array([
		Vector2(size * 0.22, -size * 0.04), Vector2(size * 0.22, -size * 0.95),
	])
	root.add_child(stem)
	var flag := Polygon2D.new()
	flag.polygon = PackedVector2Array([
		Vector2(size * 0.22, -size * 0.95), Vector2(size * 0.52, -size * 0.78),
		Vector2(size * 0.42, -size * 0.58), Vector2(size * 0.22, -size * 0.72),
	])
	flag.color = NOTE
	root.add_child(flag)
	return root

## A porcelain shard. Origin CENTRE.
static func make_shard(size: float) -> Polygon2D:
	var shard := Polygon2D.new()
	shard.name = "Shard"
	shard.polygon = PackedVector2Array([
		Vector2(-size * 0.5, size * 0.2), Vector2(size * 0.1, -size * 0.5),
		Vector2(size * 0.5, size * 0.1), Vector2(-size * 0.1, size * 0.4),
	])
	shard.color = SHARD
	return shard

## A burst geyser. Origin BASE-CENTRE; "Crest" marks the foam apex.
static func make_geyser(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Geyser"
	var column := Polygon2D.new()
	column.polygon = PackedVector2Array([
		Vector2(-size * 0.16, 0.0), Vector2(size * 0.16, 0.0),
		Vector2(size * 0.07, -size * 0.8), Vector2(-size * 0.07, -size * 0.8),
	])
	column.color = FLUSH
	root.add_child(column)
	var foam := Polygon2D.new()
	foam.polygon = _ellipse(size * 0.22, size * 0.13, 12)
	foam.position = Vector2(0.0, -size * 0.82)
	foam.color = Color(0.85, 0.95, 1.0)
	root.add_child(foam)
	var crest := Node2D.new()
	crest.name = "Crest"
	crest.position = Vector2(0.0, -size * 0.82)
	root.add_child(crest)
	return root

## The cliff-side sewer outlet. Origin BASE-CENTRE of the arch.
static func make_sewer(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Sewer"
	var lip := Polygon2D.new()
	lip.polygon = PackedVector2Array([
		Vector2(-size * 0.5, 0.0), Vector2(size * 0.5, 0.0),
		Vector2(size * 0.5, -size * 0.14), Vector2(-size * 0.5, -size * 0.14),
	])
	lip.color = Color(0.42, 0.44, 0.48)
	root.add_child(lip)
	var arch := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(13):
		var a := PI - PI * float(i) / 12.0
		pts.append(Vector2(cos(a) * size * 0.36,
			-size * 0.14 + sin(a) * size * 0.36))
	pts.append(Vector2(size * 0.36, 0.0))
	pts.append(Vector2(-size * 0.36, 0.0))
	arch.polygon = pts
	arch.color = SEWER
	root.add_child(arch)
	return root

