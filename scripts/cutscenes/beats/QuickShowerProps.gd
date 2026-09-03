extends RefCounted

## Quick Shower shared props for the beat tier.
## Flat-fill bathroom street set: door with hinge-pivoted panel, hourglass
## timer, under-door fill gauge, bathtub, record banner, towel marchers.
##
## All origins noted per prop. Colours come from the live game's palette.

const BG_BATH := Color(0.85, 0.90, 0.95)
const TILE_A := Color(0.80, 0.85, 0.90)
const TILE_B := Color(0.75, 0.80, 0.85)
const DOOR := Color(0.55, 0.68, 0.78)
const DOOR_FRAME := Color(0.45, 0.38, 0.32)
const KNOB := Color(0.85, 0.75, 0.45)
const SAND := Color(0.90, 0.75, 0.40)
const GLASS := Color(1, 1, 1, 0.30)
const GAUGE_DARK := Color(0.30, 0.30, 0.30)
const GREEN_ZONE := Color(0.20, 0.80, 0.20)
const RED_ZONE := Color(0.80, 0.25, 0.25)
const WATER := Color(0.45, 0.70, 0.95, 0.80)
const WATER_SOFT := Color(0.55, 0.78, 0.95, 0.55)
const TUB := Color(0.92, 0.94, 0.96)
const TUB_RIM := Color(0.75, 0.82, 0.88)
const TOWEL := Color(0.90, 0.85, 0.70)
const TOWEL_STRIPE := Color(0.65, 0.78, 0.90)
const BANNER_RED := Color(0.80, 0.30, 0.28)
const BANNER_CREAM := Color(0.95, 0.92, 0.82)
const POLE := Color(0.55, 0.50, 0.42)

static func _ellipse(rx: float, ry: float, points: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A door with frame. Origin BASE-CENTRE of the opening. The panel hangs
## from a hinge at the left jamb: rotate the "Door" child to swing it open.
static func make_door(w: float, h: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Doorway"
	var post_l := Polygon2D.new()
	post_l.name = "PostL"
	post_l.polygon = PackedVector2Array([
		Vector2(-w * 0.5 - 8.0, 0.0), Vector2(-w * 0.5, 0.0),
		Vector2(-w * 0.5, -h - 12.0), Vector2(-w * 0.5 - 8.0, -h - 12.0),
	])
	post_l.color = DOOR_FRAME
	root.add_child(post_l)
	var post_r := Polygon2D.new()
	post_r.name = "PostR"
	post_r.polygon = PackedVector2Array([
		Vector2(w * 0.5, 0.0), Vector2(w * 0.5 + 8.0, 0.0),
		Vector2(w * 0.5 + 8.0, -h - 12.0), Vector2(w * 0.5, -h - 12.0),
	])
	post_r.color = DOOR_FRAME
	root.add_child(post_r)
	var lintel := Polygon2D.new()
	lintel.name = "Lintel"
	lintel.polygon = PackedVector2Array([
		Vector2(-w * 0.5 - 8.0, -h - 12.0), Vector2(w * 0.5 + 8.0, -h - 12.0),
		Vector2(w * 0.5 + 8.0, -h - 22.0), Vector2(-w * 0.5 - 8.0, -h - 22.0),
	])
	lintel.color = DOOR_FRAME
	root.add_child(lintel)
	# Panel pivots from the LEFT jamb: its origin sits at the hinge.
	var door := Node2D.new()
	door.name = "Door"
	door.position = Vector2(-w * 0.5, 0.0)
	root.add_child(door)
	var panel := Polygon2D.new()
	panel.name = "Panel"
	panel.polygon = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, -h), Vector2(0.0, -h),
	])
	panel.color = DOOR
	door.add_child(panel)
	var groove := Polygon2D.new()
	groove.name = "Groove"
	groove.polygon = PackedVector2Array([
		Vector2(w * 0.18, -h * 0.12), Vector2(w * 0.82, -h * 0.12),
		Vector2(w * 0.82, -h * 0.45), Vector2(w * 0.18, -h * 0.45),
	])
	groove.color = DOOR.darkened(0.15)
	door.add_child(groove)
	var knob := Polygon2D.new()
	knob.name = "Knob"
	knob.polygon = _ellipse(4.0, 4.0, 10)
	knob.position = Vector2(w * 0.84, -h * 0.52)
	knob.color = KNOB
	door.add_child(knob)
	return root

## An hourglass timer. Origin CENTRE of the glass. Children "SandTop" and
## "SandBottom" for running-sand gags.
static func make_hourglass(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Hourglass"
	var cap_top := Polygon2D.new()
	cap_top.name = "CapTop"
	cap_top.polygon = PackedVector2Array([
		Vector2(-size * 0.55, -size), Vector2(size * 0.55, -size),
		Vector2(size * 0.55, -size * 0.88), Vector2(-size * 0.55, -size * 0.88),
	])
	cap_top.color = DOOR_FRAME
	root.add_child(cap_top)
	var cap_bot := Polygon2D.new()
	cap_bot.name = "CapBot"
	cap_bot.polygon = PackedVector2Array([
		Vector2(-size * 0.55, size * 0.88), Vector2(size * 0.55, size * 0.88),
		Vector2(size * 0.55, size), Vector2(-size * 0.55, size),
	])
	cap_bot.color = DOOR_FRAME
	root.add_child(cap_bot)
	for side in [-1.0, 1.0]:
		var post := Polygon2D.new()
		post.name = "Post"
		post.polygon = PackedVector2Array([
			Vector2(side * size * 0.5, -size * 0.92), Vector2(side * size * 0.38, -size * 0.92),
			Vector2(side * size * 0.38, size * 0.92), Vector2(side * size * 0.5, size * 0.92),
		])
		post.color = DOOR_FRAME
		root.add_child(post)
	# Glass: upper and lower bulbs as translucent wedges.
	var bulb_top := Polygon2D.new()
	bulb_top.name = "BulbTop"
	bulb_top.polygon = PackedVector2Array([
		Vector2(-size * 0.45, -size * 0.88), Vector2(size * 0.45, -size * 0.88),
		Vector2(size * 0.05, 0.0), Vector2(-size * 0.05, 0.0),
	])
	bulb_top.color = GLASS
	root.add_child(bulb_top)
	var bulb_bot := Polygon2D.new()
	bulb_bot.name = "BulbBot"
	bulb_bot.polygon = PackedVector2Array([
		Vector2(-size * 0.05, 0.0), Vector2(size * 0.05, 0.0),
		Vector2(size * 0.45, size * 0.88), Vector2(-size * 0.45, size * 0.88),
	])
	bulb_bot.color = GLASS
	root.add_child(bulb_bot)
	var sand_top := Polygon2D.new()
	sand_top.name = "SandTop"
	sand_top.polygon = PackedVector2Array([
		Vector2(-size * 0.34, -size * 0.86), Vector2(size * 0.34, -size * 0.86),
		Vector2(size * 0.04, -size * 0.30), Vector2(-size * 0.04, -size * 0.30),
	])
	sand_top.color = SAND
	root.add_child(sand_top)
	var sand_bot := Polygon2D.new()
	sand_bot.name = "SandBottom"
	sand_bot.polygon = PackedVector2Array([
		Vector2(-size * 0.14, size * 0.30), Vector2(size * 0.14, size * 0.30),
		Vector2(size * 0.30, size * 0.86), Vector2(-size * 0.30, size * 0.86),
	])
	sand_bot.color = SAND
	root.add_child(sand_bot)
	return root

## Under-door fill gauge (mirrors the live game's GaugeBG). Origin
## LEFT-BOTTOM, laid along the door's base gap. Children "GreenZone" and
## "Indicator".
static func make_gauge(width: float, height: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Gauge"
	var bg := Polygon2D.new()
	bg.name = "BG"
	bg.polygon = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(width, 0.0),
		Vector2(width, -height), Vector2(0.0, -height),
	])
	bg.color = GAUGE_DARK
	root.add_child(bg)
	var zone := Polygon2D.new()
	zone.name = "GreenZone"
	zone.polygon = PackedVector2Array([
		Vector2(width * 0.62, 0.0), Vector2(width * 0.86, 0.0),
		Vector2(width * 0.86, -height), Vector2(width * 0.62, -height),
	])
	zone.color = GREEN_ZONE
	root.add_child(zone)
	var ind := Polygon2D.new()
	ind.name = "Indicator"
	ind.polygon = PackedVector2Array([
		Vector2(-2.5, 2.0), Vector2(2.5, 2.0),
		Vector2(2.5, -height - 5.0), Vector2(-2.5, -height - 5.0),
	])
	ind.position = Vector2(width * 0.2, 0.0)
	ind.color = Color.WHITE
	root.add_child(ind)
	return root

## A bathtub. Origin CENTRE of the basin interior.
static func make_tub(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Tub"
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = PackedVector2Array([
		Vector2(-size * 0.5, -size * 0.28), Vector2(size * 0.5, -size * 0.28),
		Vector2(size * 0.38, size * 0.22), Vector2(-size * 0.38, size * 0.22),
	])
	body.color = TUB
	root.add_child(body)
	var rim := Polygon2D.new()
	rim.name = "Rim"
	rim.polygon = PackedVector2Array([
		Vector2(-size * 0.54, -size * 0.34), Vector2(size * 0.54, -size * 0.34),
		Vector2(size * 0.5, -size * 0.22), Vector2(-size * 0.5, -size * 0.22),
	])
	rim.color = TUB_RIM
	root.add_child(rim)
	for side in [-1.0, 1.0]:
		var foot := Polygon2D.new()
		foot.name = "Foot"
		foot.polygon = _ellipse(size * 0.06, size * 0.05, 8)
		foot.position = Vector2(side * size * 0.36, size * 0.26)
		foot.color = TUB_RIM
		root.add_child(foot)
	return root

## A record banner on two poles. Origin CENTRE between the poles. The
## "Cloth" child scales from flat for the unfurl gag; poles stay put.
static func make_banner(width: float, height: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Banner"
	for side in [-1.0, 1.0]:
		var pole := Polygon2D.new()
		pole.name = "Pole"
		pole.polygon = PackedVector2Array([
			Vector2(side * width * 0.5 - 3.0, height * 0.5), Vector2(side * width * 0.5 + 3.0, height * 0.5),
			Vector2(side * width * 0.5 + 3.0, -height * 0.5 - 10.0), Vector2(side * width * 0.5 - 3.0, -height * 0.5 - 10.0),
		])
		pole.color = POLE
		root.add_child(pole)
	var cloth := Polygon2D.new()
	cloth.name = "Cloth"
	cloth.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -height * 0.5), Vector2(width * 0.5, -height * 0.5),
		Vector2(width * 0.5, height * 0.5), Vector2(-width * 0.5, height * 0.5),
	])
	cloth.color = BANNER_RED
	root.add_child(cloth)
	# Cream stripe + star so it reads as a "record" pennant.
	var stripe := Polygon2D.new()
	stripe.name = "Stripe"
	stripe.polygon = PackedVector2Array([
		Vector2(-width * 0.5, -height * 0.10), Vector2(width * 0.5, -height * 0.10),
		Vector2(width * 0.5, height * 0.10), Vector2(-width * 0.5, height * 0.10),
	])
	stripe.color = BANNER_CREAM
	cloth.add_child(stripe)
	var star := Polygon2D.new()
	star.name = "Star"
	var star_pts := PackedVector2Array()
	for i in range(10):
		var a := -PI * 0.5 + float(i) * PI / 5.0
		var r := height * 0.32 if i % 2 == 0 else height * 0.14
		star_pts.append(Vector2(cos(a) * r, sin(a) * r))
	star.polygon = star_pts
	star.color = BANNER_CREAM
	cloth.add_child(star)
	return root

## A towel-clad marcher: flat body wrapped in a towel, head, legs. Origin
## BASE-CENTRE.
static func make_towel_marcher(size: float, tint: Color) -> Node2D:
	var root := Node2D.new()
	root.name = "TowelMarcher"
	var legs := Polygon2D.new()
	legs.name = "Legs"
	legs.polygon = PackedVector2Array([
		Vector2(-size * 0.14, 0.0), Vector2(-size * 0.05, 0.0),
		Vector2(-size * 0.02, -size * 0.18), Vector2(-size * 0.12, -size * 0.18),
	])
	legs.color = Color(0.55, 0.45, 0.40)
	root.add_child(legs)
	var legs2 := Polygon2D.new()
	legs2.name = "Legs2"
	legs2.polygon = PackedVector2Array([
		Vector2(size * 0.05, 0.0), Vector2(size * 0.14, 0.0),
		Vector2(size * 0.12, -size * 0.18), Vector2(size * 0.02, -size * 0.18),
	])
	legs2.color = Color(0.55, 0.45, 0.40)
	root.add_child(legs2)
	var body := Polygon2D.new()
	body.name = "TowelBody"
	body.polygon = PackedVector2Array([
		Vector2(-size * 0.18, -size * 0.16), Vector2(size * 0.18, -size * 0.16),
		Vector2(size * 0.22, -size * 0.58), Vector2(-size * 0.22, -size * 0.58),
	])
	body.color = tint
	root.add_child(body)
	var stripe := Polygon2D.new()
	stripe.name = "Stripe"
	stripe.polygon = PackedVector2Array([
		Vector2(-size * 0.20, -size * 0.30), Vector2(size * 0.20, -size * 0.30),
		Vector2(size * 0.21, -size * 0.24), Vector2(-size * 0.21, -size * 0.24),
	])
	stripe.color = TOWEL_STRIPE
	body.add_child(stripe)
	var head := Polygon2D.new()
	head.name = "Head"
	head.polygon = _ellipse(size * 0.13, size * 0.13, 12)
	head.position = Vector2(0.0, -size * 0.70)
	head.color = Color(0.95, 0.80, 0.65)
	root.add_child(head)
	# Towel turban cap.
	var cap := Polygon2D.new()
	cap.name = "Turban"
	cap.polygon = PackedVector2Array([
		Vector2(-size * 0.13, -size * 0.74), Vector2(size * 0.13, -size * 0.74),
		Vector2(size * 0.09, -size * 0.88), Vector2(-size * 0.09, -size * 0.88),
	])
	cap.color = tint.lightened(0.2)
	head.add_child(cap)
	return root
