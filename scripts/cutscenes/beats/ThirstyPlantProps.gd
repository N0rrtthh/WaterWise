extends RefCounted

## Thirsty Plant shared props for the beat tier.
## Flat-fill set: identical buckets (with a secret green twin), a potted
## plant with a droopable head, an enormous bloom flower, water arcs and
## a seed sprout.
##
## Colours taken from the minigame: green field bg, brown ground, clay
## pot, green stem/leaves, blue vs secret-green buckets, translucent water.

const BG := Color(0.6, 0.8, 0.5)
const GROUND := Color(0.5, 0.35, 0.2)
const POT := Color(0.7, 0.4, 0.2)
const POT_DARK := Color(0.58, 0.32, 0.15)
const STEM := Color(0.3, 0.5, 0.2)
const LEAF := Color(0.5, 0.6, 0.3)
const BUCKET_BLUE := Color(0.3, 0.4, 0.8)
const BUCKET_GREEN := Color(0.2, 0.9, 0.3)
const BUCKET_RED := Color(0.9, 0.3, 0.3)
const WATER := Color(0.3, 0.6, 1.0, 0.7)
const GLOW := Color(0.5, 1.0, 0.55, 0.85)
const BLOOM := Color(0.95, 0.75, 0.85)
const BLOOM_HEART := Color(0.95, 0.45, 0.6)

static func _ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A bucket. Origin BASE-CENTRE. The "Body" polygon is exposed for
## colour swaps (secret green reveal / wrong-bucket red reveal).
static func make_bucket(size: float, color: Color) -> Node2D:
	var root := Node2D.new()
	root.name = "Bucket"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-size * 0.34, 0.0), Vector2(size * 0.34, 0.0),
		Vector2(size * 0.42, -size * 0.75), Vector2(-size * 0.42, -size * 0.75),
	])
	body.color = color
	root.add_child(body)
	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = PackedVector2Array([
		Vector2(-size * 0.46, -size * 0.75), Vector2(size * 0.46, -size * 0.75),
		Vector2(size * 0.46, -size * 0.66), Vector2(-size * 0.46, -size * 0.66),
	])
	rim.color = color.lightened(0.25)
	root.add_child(rim)
	# Handle: an arc drawn as a line above the rim.
	var handle := Line2D.new()
	handle.name = "Handle"
	handle.width = size * 0.05
	handle.default_color = color.darkened(0.25)
	var arc := PackedVector2Array()
	for i in range(9):
		var a := PI - PI * float(i) / 8.0
		arc.append(Vector2(cos(a) * size * 0.44, -size * 0.70 + sin(a) * size * 0.16))
	handle.points = arc
	root.add_child(handle)
	return root

## A soft radial glow disc for the secretly-marked bucket.
static func make_glow(size: float) -> Polygon2D:
	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.polygon = _ellipse(size * 0.55, size * 0.55, 16)
	glow.color = GLOW
	return glow

## A tapered water arc. Origin at the SPOUT; extends +x/+y (caller
## rotates into place). `Flow` scales x to extend/retract the pour.
static func make_water_arc(length: float) -> Node2D:
	var root := Node2D.new()
	root.name = "WaterArc"
	var flow := Polygon2D.new()
	flow.name = "Flow"
	flow.polygon = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.0, length * 0.30),
		Vector2(length, length * 0.62), Vector2(length, length * 0.86),
		Vector2(0.0, length * 0.52),
	])
	flow.color = WATER
	root.add_child(flow)
	return root

## A seed with a tiny sprout. Origin BASE-CENTRE; "Sprout" scales up.
static func make_seed(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Seed"
	var mound := Polygon2D.new()
	mound.name = "Mound"
	mound.polygon = _ellipse(size * 0.4, size * 0.14, 10)
	mound.color = GROUND
	root.add_child(mound)
	var sprout := Node2D.new()
	sprout.name = "Sprout"
	var shoot := Polygon2D.new()
	shoot.name = "Shoot"
	shoot.polygon = PackedVector2Array([
		Vector2(-size * 0.03, 0.0), Vector2(size * 0.03, 0.0),
		Vector2(size * 0.02, -size * 0.30), Vector2(-size * 0.02, -size * 0.30),
	])
	shoot.color = STEM
	sprout.add_child(shoot)
	for side in [-1.0, 1.0]:
		var leaf := Polygon2D.new()
		leaf.name = "Leaf"
		leaf.polygon = _ellipse(size * 0.10, size * 0.05, 8)
		leaf.position = Vector2(side * size * 0.09, -size * 0.28)
		leaf.rotation = side * 0.6
		leaf.color = LEAF
		sprout.add_child(leaf)
	sprout.scale = Vector2(0.0, 0.0)
	root.add_child(sprout)
	return root

## A potted plant with a DROOPABLE HEAD. Origin BASE-CENTRE (pot bottom).
## Nodes exposed for gags: "Head" (stems+leaves+bud, rotates for wilt),
## "Bud" (hides under the flower bloom).
static func make_potted_plant(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Plant"
	var pot := Polygon2D.new()
	pot.name = "Pot"
	pot.polygon = PackedVector2Array([
		Vector2(-size * 0.26, 0.0), Vector2(size * 0.26, 0.0),
		Vector2(size * 0.20, -size * 0.30), Vector2(-size * 0.20, -size * 0.30),
	])
	pot.color = POT
	root.add_child(pot)
	var lip := Polygon2D.new()
	lip.name = "Lip"
	lip.polygon = PackedVector2Array([
		Vector2(-size * 0.28, -size * 0.30), Vector2(size * 0.28, -size * 0.30),
		Vector2(size * 0.28, -size * 0.38), Vector2(-size * 0.28, -size * 0.38),
	])
	lip.color = POT_DARK
	root.add_child(lip)
	# The head: everything above the pot, pivoting at the pot lip.
	var head := Node2D.new()
	head.name = "Head"
	head.position = Vector2(0.0, -size * 0.36)
	var stem := Polygon2D.new()
	stem.name = "Stem"
	stem.polygon = PackedVector2Array([
		Vector2(-size * 0.030, 0.0), Vector2(size * 0.030, 0.0),
		Vector2(size * 0.045, -size * 0.34), Vector2(-size * 0.045, -size * 0.34),
	])
	stem.color = STEM
	head.add_child(stem)
	for side in [-1.0, 1.0]:
		var leaf := Polygon2D.new()
		leaf.name = "Leaf"
		leaf.polygon = _ellipse(size * 0.14, size * 0.055, 10)
		leaf.position = Vector2(side * size * 0.13, -size * 0.14)
		leaf.rotation = side * 0.9
		leaf.color = LEAF
		head.add_child(leaf)
	var bud := Polygon2D.new()
	bud.name = "Bud"
	bud.polygon = _ellipse(size * 0.055, size * 0.075, 10)
	bud.position = Vector2(0.0, -size * 0.38)
	bud.color = LEAF.darkened(0.1)
	head.add_child(bud)
	root.add_child(head)
	return root

## The enormous bloom flower. Origin CENTRE; caller scales from zero
## for the bloom-pop. "Petal" children are exposed for burst gags.
static func make_flower(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Flower"
	for i in range(8):
		var petal := Polygon2D.new()
		petal.name = "Petal"
		petal.polygon = _ellipse(size * 0.16, size * 0.30, 12)
		petal.position = Vector2(sin(float(i) * TAU / 8.0) * size * 0.30,
			-cos(float(i) * TAU / 8.0) * size * 0.30)
		petal.rotation = float(i) * TAU / 8.0
		petal.color = BLOOM if i % 2 == 0 else BLOOM.lightened(0.12)
		root.add_child(petal)
	var centre := Polygon2D.new()
	centre.name = "Centre"
	centre.polygon = _ellipse(size * 0.20, size * 0.20, 14)
	centre.color = Color(0.95, 0.85, 0.3)
	root.add_child(centre)
	var smile := Line2D.new()
	smile.name = "Smile"
	smile.width = size * 0.03
	smile.default_color = Color(0.6, 0.45, 0.1)
	var arc := PackedVector2Array()
	for i in range(7):
		var a := PI * 0.25 + PI * 0.5 * float(i) / 6.0
		arc.append(Vector2(cos(a) * size * 0.10, sin(a) * size * 0.10))
	smile.points = arc
	root.add_child(smile)
	return root

## A tiny heart for the kiss. Origin CENTRE.
static func make_heart(size: float) -> Polygon2D:
	var heart := Polygon2D.new()
	heart.name = "Heart"
	heart.polygon = PackedVector2Array([
		Vector2(0.0, size * 0.5),
		Vector2(-size * 0.5, size * 0.05), Vector2(-size * 0.5, -size * 0.2),
		Vector2(-size * 0.25, -size * 0.4), Vector2(0.0, -size * 0.2),
		Vector2(size * 0.25, -size * 0.4), Vector2(size * 0.5, -size * 0.2),
		Vector2(size * 0.5, size * 0.05),
	])
	heart.color = BLOOM_HEART
	return heart
