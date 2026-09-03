extends RefCounted

## Catch The Rain shared props for the beat tier.
## Flat-fill cartoon rain drum, storm clouds and droplets.
##
## The drum's origin is its BASE CENTRE (sits on ground lines naturally) and
## it is built as two hinged halves (HalfL/HalfR, pivots at the bottom outer
## corners) so the lose clip can split it down the middle with two tweens.

const WOOD := Color(0.58, 0.40, 0.24)
const WOOD_DARK := Color(0.42, 0.28, 0.16)
const WATER := Color(0.50, 0.80, 1.00)
const MURK := Color(0.52, 0.45, 0.24)
const CLOUD := Color(0.44, 0.47, 0.58)
const CLOUD_DARK := Color(0.35, 0.38, 0.48)

static func _ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## Rain drum: 80 px tall, top wider than the base. Hinged halves so the lose
## clip can crack it apart around the bottom corners.
static func make_drum(with_water := true, dirty_water := false) -> Node2D:
	var drum := Node2D.new()
	drum.name = "Drum"
	var fill := MURK if dirty_water else WATER

	var left := Node2D.new()
	left.name = "HalfL"
	left.position = Vector2(-28.0, 0.0)
	left.add_child(_half(false, fill, with_water))
	drum.add_child(left)

	var right := Node2D.new()
	right.name = "HalfR"
	right.position = Vector2(28.0, 0.0)
	right.add_child(_half(true, fill, with_water))
	drum.add_child(right)

	# Front lip used by the lose clip to hide Dribble's legs once he sits
	# inside the broken bottom half.
	var front := Polygon2D.new()
	front.name = "FrontRim"
	front.polygon = PackedVector2Array([
		Vector2(-31, -8), Vector2(31, -8), Vector2(27, 8), Vector2(-27, 8),
	])
	front.color = WOOD_DARK
	front.visible = false
	front.z_index = 6
	drum.add_child(front)
	return drum

static func _half(mirror: bool, fill: Color, with_water: bool) -> Node2D:
	var s := -1.0 if mirror else 1.0
	var half := Node2D.new()
	half.name = "Polys"

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-8.0 * s, -80), Vector2(28.0 * s, -80),
		Vector2(28.0 * s, 0), Vector2(0, 0),
	])
	body.color = WOOD
	half.add_child(body)

	for i in range(2):
		var y := -60.0 + 36.0 * float(i)
		var band := Polygon2D.new()
		band.name = "Band%d" % (i + 1)
		band.polygon = PackedVector2Array([
			Vector2(-6.0 * s, y), Vector2(27.0 * s, y),
			Vector2(27.0 * s, y + 7.0), Vector2(-4.0 * s, y + 7.0),
		])
		band.color = WOOD_DARK
		half.add_child(band)

	if with_water:
		var w := Polygon2D.new()
		w.name = "Water"
		w.polygon = PackedVector2Array([
			Vector2(-8.0 * s, -80), Vector2(28.0 * s, -80),
			Vector2(28.0 * s, -66), Vector2(-2.0 * s, -66),
		])
		w.color = fill
		half.add_child(w)

	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = PackedVector2Array([
		Vector2(-9.0 * s, -82), Vector2(29.0 * s, -82),
		Vector2(28.0 * s, -76), Vector2(-8.0 * s, -76),
	])
	rim.color = WOOD_DARK
	half.add_child(rim)
	return half

## A single falling droplet. Clean = rain blue, dirty = storm-runoff murk.
static func make_droplet(clean := true, size := 1.0) -> Node2D:
	var d := Node2D.new()
	d.name = "Droplet"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(6, -3), Vector2(7, 3), Vector2(4, 8),
		Vector2(-4, 8), Vector2(-7, 3), Vector2(-6, -3),
	])
	body.color = WATER if clean else MURK
	d.add_child(body)
	var shine := Polygon2D.new()
	shine.name = "Shine"
	shine.polygon = _ellipse(1.8, 2.6, 8)
	shine.position = Vector2(-2.6, -2.0)
	shine.color = Color(1, 1, 1, 0.75)
	d.add_child(shine)
	d.scale = Vector2.ONE * size
	return d

## One of the dirty-drop mob: a murky droplet with angry dot eyes + brows.
static func make_mob_member() -> Node2D:
	var m := make_droplet(false, 1.45)
	m.name = "MobDroplet"
	for x_off in [-4.0, 4.0]:
		var white := Polygon2D.new()
		white.polygon = _ellipse(3.0, 3.4, 10)
		white.position = Vector2(x_off, -2.0)
		white.color = Color.WHITE
		m.add_child(white)
		var pupil := Polygon2D.new()
		pupil.polygon = _ellipse(1.4, 1.6, 8)
		pupil.position = Vector2(x_off, -1.4)
		pupil.color = Color(0.09, 0.11, 0.14)
		m.add_child(pupil)
		var brow := Line2D.new()
		brow.width = 1.6
		brow.default_color = Color(0.09, 0.11, 0.14)
		var inward := -2.6 if x_off < 0.0 else 2.6
		brow.points = PackedVector2Array([
			Vector2(x_off - 2.4, -7.0), Vector2(x_off + inward, -5.0),
		])
		m.add_child(brow)
	return m

## A murky puddle splat for dirty drops that miss the drum.
static func make_splat(size := 1.0) -> Node2D:
	var s := Node2D.new()
	s.name = "Splat"
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-9, 0), Vector2(-6, -3), Vector2(-1, -4), Vector2(5, -2),
		Vector2(9, 0), Vector2(5, 2), Vector2(-4, 2),
	])
	body.color = Color(MURK.r, MURK.g, MURK.b, 0.85)
	s.add_child(body)
	s.scale = Vector2.ONE * size
	return s

## A storm cloud: three overlapping grey blobs with a darker underside.
static func make_cloud(size := 1.0) -> Node2D:
	var c := Node2D.new()
	c.name = "Cloud"
	for blob in [[-34.0, 0.0, 30.0, 16.0], [0.0, -8.0, 36.0, 19.0], [34.0, 0.0, 28.0, 15.0]]:
		var p := Polygon2D.new()
		p.polygon = _ellipse(blob[2], blob[3])
		p.position = Vector2(blob[0], blob[1])
		p.color = CLOUD
		c.add_child(p)
	var shade := Polygon2D.new()
	shade.polygon = _ellipse(52.0, 9.0)
	shade.position = Vector2(0.0, 10.0)
	shade.color = CLOUD_DARK
	c.add_child(shade)
	c.scale = Vector2.ONE * size
	return c
