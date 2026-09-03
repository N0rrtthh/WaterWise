extends RefCounted

## Cloud Catcher shared props for the beat tier.
## Flat-fill cartoon plants (thirsty/lush states), white puff clouds,
## tumbleweeds and a growing puddle.
##
## Plants: origin at the BASE of the stem (sits on ground lines naturally).
## The win clip swaps thirsty → lush by spawning a lush plant over each
## thirsty one at tiny scale and ELASTIC-popping it up (rapid jungle growth).

const STEM_OK := Color(0.36, 0.64, 0.30)
const LEAF_OK := Color(0.30, 0.72, 0.35)
const LEAF_PALE := Color(0.58, 0.66, 0.34)
const STEM_PALE := Color(0.62, 0.58, 0.32)
const PETAL := Color(0.96, 0.62, 0.75)
const PETAL_2 := Color(0.98, 0.80, 0.40)
const PUFF := Color(0.94, 0.96, 1.00)
const PUFF_SHADE := Color(0.78, 0.84, 0.94)
const WEED := Color(0.55, 0.44, 0.22)
const WEED_DARK := Color(0.42, 0.33, 0.16)
const PUDDLE := Color(0.55, 0.75, 0.90, 0.92)

const CONFETTI := [
	Color(1.0, 0.84, 0.3), Color(0.45, 0.9, 0.62),
	Color(0.55, 0.82, 1.0), Color(0.93, 0.6, 0.7),
	Color(1, 1, 1),
]

static func _ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## One plant. state: "thirsty" (sagged, pale) or "lush" (tall, vivid, bloom).
static func make_plant(state := "thirsty", size := 1.0) -> Node2D:
	var lush := state == "lush"
	var p := Node2D.new()
	p.name = "Plant"

	var stem_h := 54.0 if lush else 30.0
	var lean := 0.0 if lush else 0.35
	var stem := Polygon2D.new()
	stem.name = "Stem"
	var tip := Vector2(sin(lean) * stem_h, -stem_h)
	var tip_w := 3.4 if lush else 2.6
	var base := Vector2(-tip_w * 1.4, 0.0)
	stem.polygon = PackedVector2Array([
		base + Vector2(-1.6, 0), tip + Vector2(-tip_w, 0),
		tip + Vector2(tip_w, 0), base + Vector2(3.4, 0),
	])
	stem.color = STEM_OK if lush else STEM_PALE
	p.add_child(stem)

	# Two droopy leaves for thirsty, four upward leaves for lush.
	if lush:
		_leaf(p, Vector2(-4, -20), -2.25, 20.0, LEAF_OK)
		_leaf(p, Vector2(4, -26), -0.9, 22.0, LEAF_OK)
		_leaf(p, Vector2(-4, -34), -2.5, 17.0, LEAF_OK)
		_leaf(p, Vector2(4, -42), -0.65, 18.0, LEAF_OK)
		_bloom(p, tip)
	else:
		_leaf(p, Vector2(-3, -12), 2.6, 15.0, LEAF_PALE)
		_leaf(p, Vector2(3, -18), 0.5, 15.0, LEAF_PALE)
	p.scale = Vector2.ONE * size
	return p

static func _leaf(parent: Node2D, at: Vector2, angle: float, len: float, color: Color) -> void:
	var leaf := Polygon2D.new()
	leaf.polygon = _ellipse(len * 0.5, len * 0.22, 12)
	leaf.position = at + Vector2(cos(angle + PI) * len * 0.42, sin(angle + PI) * len * 0.42)
	leaf.rotation = angle
	leaf.color = color
	parent.add_child(leaf)

static func _bloom(parent: Node2D, at: Vector2) -> void:
	var bloom := Node2D.new()
	bloom.name = "Bloom"
	for i in range(5):
		var a := TAU * float(i) / 5.0
		var petal := Polygon2D.new()
		petal.polygon = _ellipse(4.6, 7.0, 10)
		petal.position = at + Vector2(cos(a), sin(a)) * 6.5
		petal.rotation = a
		petal.color = PETAL if i % 2 == 0 else PETAL_2
		bloom.add_child(petal)
	var centre := Polygon2D.new()
	centre.polygon = _ellipse(3.4, 3.4, 10)
	centre.position = at
	centre.color = Color(1.0, 0.92, 0.55)
	bloom.add_child(centre)
	parent.add_child(bloom)

## A white puffy cloud (the friendly game-cloud, vs the grey storm fronts in
## Catch The Rain). grumpy = grey tint + angry brows for the lose clip.
static func make_puff_cloud(size := 1.0, grumpy := false) -> Node2D:
	var c := Node2D.new()
	c.name = "PuffCloud"
	var tint := Color(0.72, 0.75, 0.84) if grumpy else Color.WHITE
	for blob in [[-30.0, 2.0, 24.0, 14.0], [2.0, -8.0, 30.0, 17.0], [32.0, 2.0, 22.0, 13.0]]:
		var p := Polygon2D.new()
		p.polygon = _ellipse(blob[2], blob[3])
		p.position = Vector2(blob[0], blob[1])
		p.color = PUFF * Color(tint.r, tint.g, tint.b) if grumpy else PUFF
		c.add_child(p)
	var shade := Polygon2D.new()
	shade.polygon = _ellipse(46.0, 8.0)
	shade.position = Vector2(0.0, 9.0)
	shade.color = PUFF_SHADE * Color(tint.r, tint.g, tint.b) if grumpy else PUFF_SHADE
	c.add_child(shade)
	if grumpy:
		for x_off in [-10.0, 10.0]:
			var brow := Line2D.new()
			brow.width = 2.4
			brow.default_color = Color(0.25, 0.27, 0.33)
			var inward := -3.0 if x_off < 0.0 else 3.0
			brow.points = PackedVector2Array([
				Vector2(x_off - 4.0, -12.0), Vector2(x_off + inward, -9.5),
			])
			c.add_child(brow)
	c.scale = Vector2.ONE * size
	return c

## A dry scraggly ball — the wilted plant's getaway vehicle. Origin centre,
## so rolling is just rotation.
static func make_tumbleweed(size := 1.0) -> Node2D:
	var t := Node2D.new()
	t.name = "Tumbleweed"
	var pts := PackedVector2Array()
	for i in range(14):
		var a := i * TAU / 14.0
		var r := 17.0 if i % 2 == 0 else 11.5
		pts.append(Vector2(cos(a), sin(a)) * r)
	var body := Polygon2D.new()
	body.polygon = pts
	body.color = WEED
	t.add_child(body)
	# A few darker chords so the spin reads while it rolls.
	for chord in [[-14.0, -6.0, 12.0, 8.0], [-6.0, 12.0, 14.0, -8.0], [-2.0, -15.0, 4.0, 14.0]]:
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = WEED_DARK
		line.points = PackedVector2Array([
			Vector2(chord[0], chord[1]), Vector2(chord[2], chord[3]),
		])
		t.add_child(line)
	t.scale = Vector2.ONE * size
	return t

## The puddle that grows under Dribble and then sweeps him away. Flat ellipse,
## origin centre, scale.x driven by the lose clip.
static func make_puddle(size := 1.0) -> Node2D:
	var p := Node2D.new()
	p.name = "Puddle"
	var body := Polygon2D.new()
	body.polygon = _ellipse(34.0, 7.0, 20)
	body.color = PUDDLE
	p.add_child(body)
	var rim := Polygon2D.new()
	rim.polygon = _ellipse(30.0, 5.2, 18)
	rim.position = Vector2(0.0, -1.0)
	rim.color = Color(0.70, 0.87, 0.97, 0.9)
	p.add_child(rim)
	p.scale = Vector2.ONE * size
	return p
