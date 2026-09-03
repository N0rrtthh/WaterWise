extends RefCounted

## Filter Builder shared props for the beat tier.
## Flat-fill workshop dressing: the work table, the muddy-water jug, drinking
## glasses, and the four filter layers (cloth / charcoal / sand / gravel).
##
## Standing props use BASE-CENTRE origins. The jug's water fill is a child
## (Fill) so the win clip can swap muddy -> clean on the impact frame, and the
## glass fill (Fill) so pours can rise it with a scale tween.

const SKY := Color(0.70, 0.85, 0.90)
const WOOD := Color(0.62, 0.45, 0.28)
const WOOD_DARK := Color(0.48, 0.34, 0.20)
const JUG_BODY := Color(0.80, 0.90, 1.00, 0.85)
const JUG_RIM := Color(0.40, 0.50, 0.60)
const MUDDY := Color(0.48, 0.32, 0.16)
const CLEAN := Color(0.30, 0.80, 1.00, 0.75)
const GLASS := Color(0.80, 0.90, 1.00, 0.40)
const GLASS_RIM := Color(0.40, 0.50, 0.60)
const CLOTH := Color(0.90, 0.90, 0.85)
const CLOTH_DARK := Color(0.80, 0.80, 0.74)
const CHARCOAL := Color(0.20, 0.20, 0.20)
const CHARCOAL_DARK := Color(0.12, 0.12, 0.12)
const SAND := Color(0.90, 0.80, 0.60)
const SAND_DARK := Color(0.78, 0.66, 0.44)
const GRAVEL := Color(0.50, 0.50, 0.50)
const GRAVEL_DARK := Color(0.38, 0.38, 0.38)
const SHIMMER := Color(1.00, 0.98, 0.80)

static func _ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## The work table. Origin TOP-CENTRE (the surface) so props sit on it by
## placing them at the same position.
static func make_table(width := 220.0) -> Node2D:
	var t := Node2D.new()
	t.name = "Table"
	var top := Polygon2D.new()
	top.name = "Top"
	top.polygon = PackedVector2Array([
		Vector2(-width * 0.5, 0), Vector2(width * 0.5, 0),
		Vector2(width * 0.5, 14.0), Vector2(-width * 0.5, 14.0),
	])
	top.color = WOOD
	t.add_child(top)
	for x_off in [-width * 0.4, width * 0.4]:
		var leg := Polygon2D.new()
		leg.name = "Leg"
		leg.polygon = PackedVector2Array([
			Vector2(x_off - 7.0, 14.0), Vector2(x_off + 7.0, 14.0),
			Vector2(x_off + 7.0, 78.0), Vector2(x_off - 7.0, 78.0),
		])
		leg.color = WOOD_DARK
		t.add_child(leg)
	return t

## Water jug. Origin base-centre. `muddy` picks the fill colour; the Fill
## child can be recoloured by clips for the clean-water swap.
static func make_jug(size := 1.0, muddy := true) -> Node2D:
	var j := Node2D.new()
	j.name = "Jug"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-22, 0), Vector2(22, 0), Vector2(26, -34),
		Vector2(14, -48), Vector2(6, -58), Vector2(-6, -58), Vector2(-14, -48), Vector2(-26, -34),
	])
	body.color = JUG_BODY
	j.add_child(body)
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = PackedVector2Array([
		Vector2(-20, -4), Vector2(20, -4), Vector2(23, -30), Vector2(-23, -30),
	])
	fill.color = MUDDY if muddy else CLEAN
	j.add_child(fill)
	var lip := Polygon2D.new()
	lip.name = "Lip"
	lip.polygon = PackedVector2Array([
		Vector2(-9, -58), Vector2(15, -58), Vector2(15, -62), Vector2(-9, -62),
	])
	lip.color = JUG_RIM
	j.add_child(lip)
	var handle := Line2D.new()
	handle.name = "Handle"
	handle.points = PackedVector2Array([Vector2(26, -34), Vector2(34, -44), Vector2(20, -56)])
	handle.width = 4.0
	handle.default_color = JUG_RIM
	j.add_child(handle)
	j.scale = Vector2.ONE * size
	return j

## Drinking glass. Origin base-centre. Fill child scale.y is the water level
## (0 = empty); `sludge` tints the fill brown for the lose clip.
static func make_glass(size := 1.0, sludge := false) -> Node2D:
	var g := Node2D.new()
	g.name = "Glass"
	var bowl := Polygon2D.new()
	bowl.name = "Bowl"
	bowl.polygon = PackedVector2Array([
		Vector2(-13, 0), Vector2(13, 0), Vector2(10, -30), Vector2(-10, -30),
	])
	bowl.color = GLASS
	g.add_child(bowl)
	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = PackedVector2Array([
		Vector2(-11.5, -3), Vector2(11.5, -3), Vector2(9.5, -26), Vector2(-9.5, -26),
	])
	fill.color = MUDDY if sludge else CLEAN
	fill.scale = Vector2(1.0, 0.0)
	fill.position = Vector2(0.0, -1.5)
	g.add_child(fill)
	var rim := Line2D.new()
	rim.name = "Rim"
	rim.points = PackedVector2Array([Vector2(-10, -30), Vector2(10, -30)])
	rim.width = 2.5
	rim.default_color = GLASS_RIM
	g.add_child(rim)
	g.scale = Vector2.ONE * size
	return g

## One round filter layer. kind: "cloth" | "charcoal" | "sand" | "gravel".
## Origin centre (disc), so stacks/scatters pivot naturally.
static func make_layer(kind := "cloth") -> Node2D:
	var l := Node2D.new()
	l.name = "Layer"
	var disc := Polygon2D.new()
	disc.name = "Disc"
	disc.polygon = _ellipse(26.0, 26.0, 18)
	disc.position = Vector2(0.0, -4.0)
	l.add_child(disc)
	match kind:
		"charcoal":
			disc.color = CHARCOAL
			for i in range(4):
				var lump := Polygon2D.new()
				lump.polygon = _ellipse(4.0, 3.0, 8)
				var a := float(i) * TAU / 4.0 + 0.4
				lump.position = Vector2(cos(a) * 12.0, -4.0 + sin(a) * 9.0)
				lump.color = CHARCOAL_DARK
				l.add_child(lump)
		"sand":
			disc.color = SAND
			for i in range(5):
				var grain := Polygon2D.new()
				grain.polygon = _ellipse(2.0, 2.0, 6)
				var a := float(i) * TAU / 5.0
				grain.position = Vector2(cos(a) * 13.0, -4.0 + sin(a) * 10.0)
				grain.color = SAND_DARK
				l.add_child(grain)
		"gravel":
			disc.color = GRAVEL
			for i in range(4):
				var rock := Polygon2D.new()
				rock.polygon = _ellipse(5.5, 4.5, 7)
				var a := float(i) * TAU / 4.0 + 0.8
				rock.position = Vector2(cos(a) * 11.0, -4.0 + sin(a) * 8.0)
				rock.color = GRAVEL_DARK
				rock.rotation = a
				l.add_child(rock)
		_:
			disc.color = CLOTH
			disc.polygon = _ellipse(26.0, 26.0, 18)
			var weave := Line2D.new()
			weave.name = "Weave"
			weave.points = PackedVector2Array([
				Vector2(-16, -4), Vector2(0, -14), Vector2(16, -4),
			])
			weave.width = 2.0
			weave.default_color = CLOTH_DARK
			l.add_child(weave)
	return l

## The win clip's neat stack: cloth under, charcoal, sand, gravel on top —
## bottom-up build order, discs stacked at `gap` intervals.
static func make_filter_stack(size := 1.0) -> Node2D:
	var s := Node2D.new()
	s.name = "FilterStack"
	var kinds := ["cloth", "charcoal", "sand", "gravel"]
	for i in range(kinds.size()):
		var layer := make_layer(kinds[i])
		layer.position = Vector2(0.0, -float(i) * 10.0)
		layer.rotation = 0.0
		s.add_child(layer)
	s.scale = Vector2.ONE * size
	return s

