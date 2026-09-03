extends RefCounted

## Greywater Sorter shared props for the beat tier.
## Flat-fill yard dressing: the labeled sorting buckets, the drop chute,
## water blobs of both kinds, prize/mutant vegetables, the backyard fence,
## the drain bucket's thumbs-up, and the catapult.
##
## Buckets, vegetables and the thumb use BASE-CENTRE origins so they can pop,
## bounce and tip naturally. Mutant vegetables carry a "Mouth" child for the
## cartoon scream loop.

const SKY := Color(0.85, 0.90, 0.95)
const GARDEN_GREEN := Color(0.30, 0.70, 0.30)
const GARDEN_DARK := Color(0.20, 0.50, 0.20)
const DRAIN_BROWN := Color(0.50, 0.40, 0.40)
const DRAIN_DARK := Color(0.40, 0.30, 0.30)
const BUCKET_RIM := Color(0.35, 0.45, 0.55)
const CHUTE := Color(0.55, 0.55, 0.58)
const CHUTE_DARK := Color(0.42, 0.42, 0.46)
const WATER_CLEAN := Color(0.40, 0.75, 1.00, 0.85)
const WATER_GREY := Color(0.50, 0.45, 0.40, 0.85)
const VEG_ORANGE := Color(0.90, 0.50, 0.15)
const VEG_GREEN := Color(0.35, 0.65, 0.25)
const VEG_RED := Color(0.85, 0.25, 0.25)
const VEG_LEAF := Color(0.40, 0.70, 0.30)
const MUTANT_PURPLE := Color(0.55, 0.35, 0.75)
const MUTANT_DARK := Color(0.40, 0.22, 0.58)
const FENCE_WOOD := Color(0.75, 0.62, 0.45)
const FENCE_DARK := Color(0.60, 0.48, 0.34)
const CATAPULT_WOOD := Color(0.55, 0.40, 0.25)

static func _ellipse(rx: float, ry: float, points: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A labeled sorting bucket. Origin base-centre; the label plate sits on the
## front face, the Fill child (scale.y) is the water level.
static func make_bucket(color: Color, label: String, size := 1.0) -> Node2D:
	var b := Node2D.new()
	b.name = label + "Bucket"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-20.0, 0.0), Vector2(20.0, 0.0), Vector2(26.0, -34.0), Vector2(-26.0, -34.0),
	])
	body.color = color
	b.add_child(body)
	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = PackedVector2Array([
		Vector2(-28.0, -34.0), Vector2(28.0, -34.0), Vector2(28.0, -40.0), Vector2(-28.0, -40.0),
	])
	rim.color = BUCKET_RIM
	b.add_child(rim)
	var plate := Polygon2D.new()
	plate.name = "Plate"
	plate.polygon = PackedVector2Array([
		Vector2(-16.0, -22.0), Vector2(16.0, -22.0), Vector2(16.0, -10.0), Vector2(-16.0, -10.0),
	])
	plate.color = Color(0.94, 0.94, 0.90)
	b.add_child(plate)
	# Tiny label tick marks — reads as text at beat-tier scale.
	for i in range(3):
		var tick := Polygon2D.new()
		tick.name = "Tick%d" % i
		tick.polygon = PackedVector2Array([
			Vector2(-12.0 + 8.0 * float(i), -19.0), Vector2(-4.0 + 8.0 * float(i), -19.0),
			Vector2(-4.0 + 8.0 * float(i), -16.0), Vector2(-12.0 + 8.0 * float(i), -16.0),
		])
		tick.color = color.darkened(0.2)
		b.add_child(tick)
	var handle := Line2D.new()
	handle.name = "Handle"
	handle.points = PackedVector2Array([
		Vector2(-26.0, -37.0), Vector2(0.0, -50.0), Vector2(26.0, -37.0),
	])
	handle.width = 3.0
	handle.default_color = BUCKET_RIM
	b.add_child(handle)
	b.scale = Vector2.ONE * size
	return b

## The drop chute. Origin CENTRE of the run; rotate to aim the spout end.
static func make_chute(length: float) -> Node2D:
	var c := Node2D.new()
	c.name = "Chute"
	var run := Polygon2D.new()
	run.name = "Run"
	run.polygon = PackedVector2Array([
		Vector2(-length * 0.5, -10.0), Vector2(length * 0.5, -10.0),
		Vector2(length * 0.5, 10.0), Vector2(-length * 0.5, 10.0),
	])
	run.color = CHUTE
	c.add_child(run)
	for x_f in [-0.42, 0.42]:
		var band := Polygon2D.new()
		band.name = "Band"
		band.polygon = PackedVector2Array([
			Vector2(length * x_f - 5.0, -12.0), Vector2(length * x_f + 5.0, -12.0),
			Vector2(length * x_f + 5.0, 12.0), Vector2(length * x_f - 5.0, 12.0),
		])
		band.color = CHUTE_DARK
		c.add_child(band)
	return c

## A falling water blob. kind: "clean" | "grey". Origin centre.
static func make_blob(kind := "clean", size := 1.0) -> Node2D:
	var w := Node2D.new()
	w.name = "Blob"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = _ellipse(9.0, 11.0, 10)
	body.position = Vector2(0.0, -1.0)
	body.color = WATER_CLEAN if kind == "clean" else WATER_GREY
	w.add_child(body)
	var shine := Polygon2D.new()
	shine.name = "Shine"
	shine.polygon = _ellipse(2.5, 3.5, 8)
	shine.position = Vector2(-3.0, -4.0)
	shine.color = Color(1, 1, 1, 0.7)
	w.add_child(shine)
	w.scale = Vector2.ONE * size
	return w

## An oversized vegetable. kind: "carrot" | "tomato" | "pumpkin".
## `mutant` swaps to the purple mutant palette and adds dot EYES and a
## "Mouth" child (an open dark ellipse the lose clip can pump for a scream).
static func make_veg(kind := "carrot", mutant := false, size := 1.0) -> Node2D:
	var v := Node2D.new()
	v.name = "Veg"
	var main_color: Color = MUTANT_PURPLE if mutant else VEG_ORANGE
	var dark_color: Color = MUTANT_DARK if mutant else VEG_GREEN
	match kind:
		"tomato":
			main_color = MUTANT_PURPLE if mutant else VEG_RED
			var body := Polygon2D.new()
			body.name = "Body"
			body.polygon = _ellipse(18.0, 15.0, 14)
			body.position = Vector2(0.0, -13.0)
			body.color = main_color
			v.add_child(body)
			for i in range(3):
				var leaf := Polygon2D.new()
				leaf.name = "Leaf"
				leaf.polygon = _ellipse(5.0, 2.5, 8)
				var a := -TAU * 0.25 + (float(i) - 1.0) * 0.7
				leaf.position = Vector2(cos(a) * 8.0, -27.0 + sin(a) * 3.0)
				leaf.rotation = a + TAU * 0.25
				leaf.color = dark_color
				v.add_child(leaf)
		"pumpkin":
			var body := Polygon2D.new()
			body.name = "Body"
			body.polygon = _ellipse(20.0, 15.0, 14)
			body.position = Vector2(0.0, -13.0)
			body.color = main_color
			v.add_child(body)
			for i in range(2):
				var rib := Polygon2D.new()
				rib.name = "Rib"
				rib.polygon = _ellipse(20.0 - 6.0 * float(i + 1), 15.0, 14)
				rib.position = Vector2(0.0, -13.0)
				rib.color = main_color.darkened(0.12 * float(i + 1))
				v.add_child(rib)
			var stalk := Polygon2D.new()
			stalk.name = "Stalk"
			stalk.polygon = PackedVector2Array([
				Vector2(-3.0, -26.0), Vector2(3.0, -26.0), Vector2(4.0, -33.0), Vector2(-4.0, -33.0),
			])
			stalk.color = VEG_LEAF if not mutant else MUTANT_DARK
			v.add_child(stalk)
		_:
			var body := Polygon2D.new()
			body.name = "Body"
			body.polygon = PackedVector2Array([
				Vector2(-9.0, 0.0), Vector2(9.0, 0.0), Vector2(4.0, -30.0), Vector2(-4.0, -30.0),
			])
			body.color = main_color
			v.add_child(body)
			for i in range(3):
				var frond := Polygon2D.new()
				frond.name = "Frond"
				frond.polygon = _ellipse(2.5, 7.0, 8)
				frond.position = Vector2(-6.0 + 6.0 * float(i), -36.0)
				frond.rotation = -0.5 + 0.5 * float(i)
				frond.color = dark_color
				v.add_child(frond)
	if mutant:
		for side in [-1, 1]:
			var eye := Polygon2D.new()
			eye.name = "Eye"
			eye.polygon = _ellipse(3.5, 3.5, 8)
			eye.position = Vector2(7.0 * float(side), -16.0)
			eye.color = Color(1, 1, 1)
			v.add_child(eye)
			var pupil := Polygon2D.new()
			pupil.name = "Pupil"
			pupil.polygon = _ellipse(1.6, 1.6, 6)
			pupil.position = Vector2(7.0 * float(side), -16.0)
			pupil.color = Color(0.1, 0.1, 0.12)
			v.add_child(pupil)
		var mouth := Polygon2D.new()
		mouth.name = "Mouth"
		mouth.polygon = _ellipse(4.5, 3.0, 10)
		mouth.position = Vector2(0.0, -8.0)
		mouth.color = Color(0.15, 0.08, 0.18)
		v.add_child(mouth)
	v.scale = Vector2.ONE * size
	return v

## Backyard picket fence. Origin bottom-centre; put it in FRONT of the crowd.
static func make_fence(width: float) -> Node2D:
	var f := Node2D.new()
	f.name = "Fence"
	var rail_y := [-40.0, -20.0]
	for i in range(2):
		var rail := Polygon2D.new()
		rail.name = "Rail%d" % i
		rail.polygon = PackedVector2Array([
			Vector2(-width * 0.5, rail_y[i]), Vector2(width * 0.5, rail_y[i]),
			Vector2(width * 0.5, rail_y[i] + 7.0), Vector2(-width * 0.5, rail_y[i] + 7.0),
		])
		rail.color = FENCE_DARK
		f.add_child(rail)
	var n := int(width / 26.0)
	for i in range(n):
		var picket := Polygon2D.new()
		picket.name = "Picket%d" % i
		var x := -width * 0.5 + 13.0 + float(i) * 26.0
		picket.polygon = PackedVector2Array([
			Vector2(x - 8.0, 0.0), Vector2(x + 8.0, 0.0),
			Vector2(x + 8.0, -52.0), Vector2(x, -60.0), Vector2(x - 8.0, -52.0),
		])
		picket.color = FENCE_WOOD
		f.add_child(picket)
	return f

## The drain bucket's cheerful thumbs-up. Origin base-centre (wrist end);
## scale it up out of the bucket rim to "give" it.
static func make_thumb(size := 1.0) -> Node2D:
	var t := Node2D.new()
	t.name = "Thumb"
	var fist := Polygon2D.new()
	fist.name = "Fist"
	fist.polygon = PackedVector2Array([
		Vector2(-9.0, 0.0), Vector2(9.0, 0.0), Vector2(11.0, -14.0),
		Vector2(6.0, -18.0), Vector2(-7.0, -18.0), Vector2(-11.0, -12.0),
	])
	fist.color = Color(0.94, 0.78, 0.55)
	t.add_child(fist)
	var finger := Polygon2D.new()
	finger.name = "Finger"
	finger.polygon = _ellipse(6.5, 3.0, 8)
	finger.position = Vector2(3.0, -19.0)
	finger.color = Color(0.94, 0.78, 0.55)
	t.add_child(finger)
	var thumb := Polygon2D.new()
	thumb.name = "ThumbUp"
	thumb.polygon = _ellipse(3.5, 8.0, 10)
	thumb.position = Vector2(-8.0, -25.0)
	thumb.rotation = 0.35
	thumb.color = Color(0.96, 0.82, 0.62)
	t.add_child(thumb)
	t.scale = Vector2.ONE * size
	return t

## The town's catapult. Origin base-centre; the "Arm" child pivots at the
## fulcrum — rotate it hard to fling whatever is parked on its tip.
static func make_catapult(size := 1.0) -> Node2D:
	var c := Node2D.new()
	c.name = "Catapult"
	var base := Polygon2D.new()
	base.name = "Base"
	base.polygon = PackedVector2Array([
		Vector2(-26.0, 0.0), Vector2(26.0, 0.0), Vector2(14.0, -16.0), Vector2(-14.0, -16.0),
	])
	base.color = CATAPULT_WOOD
	c.add_child(base)
	var arm := Polygon2D.new()
	arm.name = "Arm"
	arm.polygon = PackedVector2Array([
		Vector2(-4.0, -14.0), Vector2(4.0, -14.0), Vector2(3.0, -58.0), Vector2(-3.0, -58.0),
	])
	arm.color = CATAPULT_WOOD.darkened(0.15)
	arm.position = Vector2(0.0, 0.0)
	arm.rotation = 0.55
	c.add_child(arm)
	var cup := Polygon2D.new()
	cup.name = "Cup"
	cup.polygon = PackedVector2Array([
		Vector2(-9.0, -56.0), Vector2(9.0, -56.0), Vector2(7.0, -48.0), Vector2(-7.0, -48.0),
	])
	cup.color = CATAPULT_WOOD.darkened(0.25)
	cup.position = Vector2(0.0, 0.0)
	cup.rotation = 0.55
	c.add_child(cup)
	c.scale = Vector2.ONE * size
	return c

