extends RefCounted

## Cover The Drum shared props for the beat tier.
## Flat-fill cartoon water drums with slammable lids, mosquitoes (plain and
## sad-marching-band variants) and the game's dusk sky dressing.
##
## The drum's origin is its BASE CENTRE. The lid is a separate child (Lid)
## pivoted at the drum's top-centre so the win clip can slam it shut with one
## rotation tween: open = Lid.rotation ≈ -1.35, closed = 0, Lid.visible toggled.

const DRUM_BLUE := Color(0.20, 0.40, 0.65)
const DRUM_DARK := Color(0.14, 0.30, 0.50)
const WATER := Color(0.30, 0.60, 1.00, 0.9)
const LID_WOOD := Color(0.55, 0.35, 0.20)
const LID_DARK := Color(0.42, 0.26, 0.14)
const MOSQ := Color(0.16, 0.16, 0.18)
const MOSQ_DARK := Color(0.10, 0.10, 0.12)
const MOSQ_WING := Color(1, 1, 1, 0.38)
const BRASS := Color(0.85, 0.68, 0.25)
const DUSK_SKY := Color(0.25, 0.20, 0.35)

static func _ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## The dusk-sky star sprinkle — deterministic, lives in the top 45% of frame.
static func make_stars(frame: Vector2, count := 16) -> Node2D:
	var sky := Node2D.new()
	sky.name = "Stars"
	sky.z_index = -6
	for i in range(count):
		var star := Polygon2D.new()
		star.polygon = _ellipse(2.2, 2.2, 8)
		var fx := float((i * 197) % 1000) / 1000.0
		var fy := float((i * 743) % 1000) / 1000.0
		star.position = Vector2(frame.x * (0.04 + 0.92 * fx), frame.y * (0.03 + 0.42 * fy))
		star.color = Color(1, 1, 0.85, 0.35 + 0.3 * fy)
		sky.add_child(star)
	return sky

## Water drum, open (Lid hidden). Origin base centre, ~60 px tall.
static func make_drum(size := 1.0) -> Node2D:
	var d := Node2D.new()
	d.name = "Drum"

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-26, 0), Vector2(26, 0), Vector2(30, -60), Vector2(-30, -60),
	])
	body.color = DRUM_BLUE
	d.add_child(body)

	for i in range(2):
		var y := -40.0 + 26.0 * float(i)
		var band := Polygon2D.new()
		band.name = "Band%d" % (i + 1)
		band.polygon = PackedVector2Array([
			Vector2(-28.4, y), Vector2(28.4, y),
			Vector2(28.8, y + 6.0), Vector2(-28.8, y + 6.0),
		])
		band.color = DRUM_DARK
		d.add_child(band)

	var water := Polygon2D.new()
	water.name = "Water"
	water.polygon = PackedVector2Array([
		Vector2(-29.6, -58), Vector2(29.6, -58), Vector2(29.9, -48), Vector2(-29.9, -48),
	])
	water.color = WATER
	d.add_child(water)

	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = PackedVector2Array([
		Vector2(-31, -62), Vector2(31, -62), Vector2(30, -57), Vector2(-30, -57),
	])
	rim.color = DRUM_DARK
	d.add_child(rim)

	# Flip lid: pivots at the top-centre; closed lies flat over the rim.
	var lid := Node2D.new()
	lid.name = "Lid"
	lid.position = Vector2(0.0, -60.0)
	lid.visible = false
	var plank := Polygon2D.new()
	plank.name = "Plank"
	plank.polygon = PackedVector2Array([
		Vector2(-33, -2), Vector2(33, -2), Vector2(29, -9), Vector2(-29, -9),
	])
	plank.color = LID_WOOD
	lid.add_child(plank)
	var handle := Polygon2D.new()
	handle.name = "Handle"
	handle.polygon = _ellipse(4.5, 3.0, 10)
	handle.position = Vector2(0.0, -12.0)
	handle.color = LID_DARK
	lid.add_child(handle)
	d.add_child(lid)

	d.scale = Vector2.ONE * size
	return d

## Mosquito — dark blob body, round head, white-translucent wings, dangly legs.
## Origin body-centre so circling/hover tweens pivot on the critter itself.
## Wings are WingL/WingR children so clips can flap them with a loop tween.
## `instrument` adds a tiny mournful brass horn hanging from the proboscis
## (the sad marching-band variant for the win outro).
static func make_mosquito(size := 1.0, instrument := false) -> Node2D:
	var m := Node2D.new()
	m.name = "Mosquito"

	var wing_l := Polygon2D.new()
	wing_l.name = "WingL"
	wing_l.polygon = _ellipse(10.0, 4.0, 10)
	wing_l.position = Vector2(-7.0, -13.0)
	wing_l.rotation = -0.55
	wing_l.color = MOSQ_WING
	m.add_child(wing_l)
	var wing_r := Polygon2D.new()
	wing_r.name = "WingR"
	wing_r.polygon = _ellipse(10.0, 4.0, 10)
	wing_r.position = Vector2(7.0, -13.0)
	wing_r.rotation = 0.55
	wing_r.color = MOSQ_WING
	m.add_child(wing_r)

	var abdomen := Polygon2D.new()
	abdomen.name = "Abdomen"
	abdomen.polygon = _ellipse(10.0, 5.5, 14)
	abdomen.position = Vector2(3.0, 2.0)
	abdomen.color = MOSQ_DARK
	m.add_child(abdomen)

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = _ellipse(9.0, 6.0, 14)
	body.color = MOSQ
	m.add_child(body)

	var head := Polygon2D.new()
	head.name = "Head"
	head.polygon = _ellipse(5.0, 4.5, 10)
	head.position = Vector2(-2.0, -8.0)
	head.color = MOSQ
	m.add_child(head)

	var eye := Polygon2D.new()
	eye.name = "Eye"
	eye.polygon = _ellipse(1.4, 1.4, 6)
	eye.position = Vector2(-4.0, -9.5)
	eye.color = Color(1, 1, 1, 0.85)
	m.add_child(eye)

	var proboscis := Line2D.new()
	proboscis.name = "Proboscis"
	proboscis.points = PackedVector2Array([Vector2(-4.5, -7.0), Vector2(-11.0, -3.5)])
	proboscis.width = 1.6
	proboscis.default_color = MOSQ_DARK
	m.add_child(proboscis)

	for i in range(2):
		var leg := Line2D.new()
		leg.name = "Leg%d" % (i + 1)
		leg.points = PackedVector2Array([
			Vector2(-2.0 + 6.0 * float(i), 4.0),
			Vector2(-4.0 + 8.0 * float(i), 11.0),
		])
		leg.width = 1.4
		leg.default_color = MOSQ_DARK
		m.add_child(leg)

	if instrument:
		var horn := Polygon2D.new()
		horn.name = "Horn"
		horn.polygon = PackedVector2Array([
			Vector2(9.0, 3.0), Vector2(15.0, 7.5), Vector2(15.0, 11.5), Vector2(9.0, 7.0),
		])
		horn.color = BRASS
		m.add_child(horn)

	m.scale = Vector2.ONE * size
	return m
