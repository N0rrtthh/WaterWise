extends RefCounted

## Vegetable Bath shared props for the beat tier.
## Flat-fill set: decagon veggies with pentagon dirt spots, woven
## baskets, a wash basin, a striped market stall with a flippable
## SOLD OUT sign, coins, a mud pool and protest tomato splats.
##
## Colours from the minigame: cream background, wood counter, basin
## water, basket browns/greens and the five veggie hues.

const CREAM := Color(0.95, 0.9, 0.85)
const COUNTER := Color(0.55, 0.35, 0.2)
const COUNTER_EDGE := Color(0.68, 0.47, 0.3)
const WOOD := Color(0.6, 0.4, 0.2)
const WOOD_DARK := Color(0.45, 0.28, 0.14)
const BASKET_CLEAN := Color(0.4, 0.7, 0.4)
const BASIN := Color(0.7, 0.7, 0.75)
const BASIN_DARK := Color(0.58, 0.58, 0.64)
const BASIN_WATER := Color(0.3, 0.6, 0.9, 0.7)
const DIRT := Color(0.4, 0.3, 0.15, 0.7)
const LEAF := Color(0.25, 0.65, 0.25)
const CARROT := Color(1.0, 0.4, 0.2)
const LETTUCE := Color(0.2, 0.7, 0.2)
const TOMATO := Color(0.8, 0.2, 0.2)
const EGGPLANT := Color(0.5, 0.3, 0.6)
const CORN := Color(0.9, 0.8, 0.2)
const MUD := Color(0.42, 0.32, 0.18, 0.9)
const COIN := Color(0.95, 0.8, 0.2)
const COIN_EDGE := Color(0.75, 0.58, 0.1)
const AWNING_RED := Color(0.8, 0.25, 0.25)
const AWNING_CREAM := Color(0.95, 0.92, 0.85)
const SIGN_BOARD := Color(0.92, 0.9, 0.82)
const SIGN_TEXT := Color(0.55, 0.12, 0.12)

static func ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## An oval pool body: width `w`, height `h`, centred on x, base on y=0.
static func pool_poly(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-w * 0.5, 0.0),
		Vector2(-w * 0.42, -h * 0.6),
		Vector2(-w * 0.25, -h),
		Vector2(w * 0.25, -h),
		Vector2(w * 0.42, -h * 0.6),
		Vector2(w * 0.5, 0.0),
	])

## A decagon veggie with a leaf accent and pentagon dirt spots.
## Origin CENTRE. "Dirt" visibility marks the muddy state.
static func make_veggie(size: float, color: Color, muddy := false) -> Node2D:
	var root := Node2D.new()
	root.name = "Veggie"
	var visual := Polygon2D.new()
	visual.name = "Visual"
	var pts := PackedVector2Array()
	for j in range(10):
		var a := j * TAU / 10.0
		pts.append(Vector2(cos(a) * size, sin(a) * size))
	visual.polygon = pts
	visual.color = color
	root.add_child(visual)
	var leaf := Polygon2D.new()
	leaf.polygon = PackedVector2Array([
		Vector2(0.0, -size * 0.8), Vector2(size * 0.38, -size * 1.3),
		Vector2(size * 0.12, -size * 0.72),
	])
	leaf.color = LEAF
	root.add_child(leaf)
	var dirt := Node2D.new()
	dirt.name = "Dirt"
	var offsets := [
		Vector2(-0.4, -0.3), Vector2(0.35, -0.25),
		Vector2(-0.1, 0.4), Vector2(0.4, 0.3),
	]
	for off: Vector2 in offsets:
		var spot := Polygon2D.new()
		var sp := PackedVector2Array()
		for k in range(5):
			var a2 := k * TAU / 5.0
			sp.append(Vector2(cos(a2) * size * 0.22, sin(a2) * size * 0.22))
		spot.polygon = sp
		spot.color = DIRT
		spot.position = off * size
		dirt.add_child(spot)
	dirt.visible = muddy
	root.add_child(dirt)
	return root

## A woven basket or crate. Origin BASE-CENTRE.
static func make_basket(size: float, color: Color) -> Node2D:
	var root := Node2D.new()
	root.name = "Basket"
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-size * 0.5, -size * 0.25), Vector2(size * 0.5, -size * 0.25),
		Vector2(size * 0.44, size * 0.3), Vector2(-size * 0.44, size * 0.3),
	])
	body.color = color
	root.add_child(body)
	var rim := Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-size * 0.54, -size * 0.34), Vector2(size * 0.54, -size * 0.34),
		Vector2(size * 0.54, -size * 0.2), Vector2(-size * 0.54, -size * 0.2),
	])
	rim.color = color.darkened(0.2)
	root.add_child(rim)
	for i in range(3):
		var weave := Line2D.new()
		weave.width = 2.0
		weave.default_color = color.darkened(0.35)
		var y := -size * 0.12 + size * 0.14 * float(i)
		weave.points = PackedVector2Array([
			Vector2(-size * (0.47 - 0.015 * float(i)), y),
			Vector2(size * (0.47 - 0.015 * float(i)), y),
		])
		root.add_child(weave)
	return root

## The wash basin: grey bowl with a drivable "Water" surface.
static func make_basin(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Basin"
	var bowl := Polygon2D.new()
	bowl.polygon = PackedVector2Array([
		Vector2(-size * 0.5, -size * 0.2), Vector2(size * 0.5, -size * 0.2),
		Vector2(size * 0.42, size * 0.3), Vector2(-size * 0.42, size * 0.3),
	])
	bowl.color = BASIN
	root.add_child(bowl)
	var rim := Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-size * 0.55, -size * 0.3), Vector2(size * 0.55, -size * 0.3),
		Vector2(size * 0.55, -size * 0.12), Vector2(-size * 0.55, -size * 0.12),
	])
	rim.color = BASIN_DARK
	root.add_child(rim)
	var water := Polygon2D.new()
	water.name = "Water"
	water.polygon = pool_poly(size * 0.9, size * 0.22)
	water.color = BASIN_WATER
	water.position = Vector2(0.0, size * 0.24)
	root.add_child(water)
	return root

## The market stall: posts, striped awning, counter front, and a
## hanging "Sign" whose "SoldText"/"SoldText2" show after the flip.
static func make_stall(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Stall"
	var w := size * 0.62
	for side in [-1.0, 1.0]:
		var post := Polygon2D.new()
		post.polygon = PackedVector2Array([
			Vector2(side * w - size * 0.035, 0.0),
			Vector2(side * w + size * 0.035, 0.0),
			Vector2(side * w + size * 0.035, -size * 0.92),
			Vector2(side * w - size * 0.035, -size * 0.92),
		])
		post.color = WOOD_DARK
		root.add_child(post)
	var counter := Polygon2D.new()
	counter.polygon = PackedVector2Array([
		Vector2(-w - size * 0.03, -size * 0.34), Vector2(w + size * 0.03, -size * 0.34),
		Vector2(w + size * 0.03, -size * 0.5), Vector2(-w - size * 0.03, -size * 0.5),
	])
	counter.color = WOOD
	root.add_child(counter)
	for i in range(6):
		var stripe := Polygon2D.new()
		var x0 := -w - size * 0.05 + (w * 2.0 + size * 0.1) * float(i) / 6.0
		stripe.polygon = PackedVector2Array([
			Vector2(x0, -size * 0.98), Vector2(x0 + (w * 2.0 + size * 0.1) / 6.0, -size * 0.98),
			Vector2(x0 + (w * 2.0 + size * 0.1) / 6.0, -size * 0.8),
			Vector2(x0, -size * 0.8),
		])
		stripe.color = AWNING_RED if i % 2 == 0 else AWNING_CREAM
		root.add_child(stripe)
	# The hanging sign, pre-flip (blank board).
	var sign_root := Node2D.new()
	sign_root.name = "Sign"
	sign_root.position = Vector2(size * 0.34, -size * 0.62)
	var string := Line2D.new()
	string.width = 2.0
	string.default_color = WOOD_DARK
	string.points = PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, size * 0.07)])
	sign_root.add_child(string)
	var board := Polygon2D.new()
	board.name = "Board"
	board.polygon = PackedVector2Array([
		Vector2(-size * 0.17, size * 0.07), Vector2(size * 0.17, size * 0.07),
		Vector2(size * 0.17, size * 0.23), Vector2(-size * 0.17, size * 0.23),
	])
	board.color = SIGN_BOARD
	sign_root.add_child(board)
	var sold := Polygon2D.new()
	sold.name = "SoldText"
	sold.polygon = PackedVector2Array([
		Vector2(-size * 0.12, size * 0.13), Vector2(size * 0.12, size * 0.13),
		Vector2(size * 0.12, size * 0.16), Vector2(-size * 0.12, size * 0.16),
	])
	sold.color = SIGN_TEXT
	sold.modulate.a = 0.0
	sign_root.add_child(sold)
	var sold2 := Polygon2D.new()
	sold2.name = "SoldText2"
	sold2.polygon = PackedVector2Array([
		Vector2(-size * 0.12, size * 0.185), Vector2(size * 0.12, size * 0.185),
		Vector2(size * 0.12, size * 0.215), Vector2(-size * 0.12, size * 0.215),
	])
	sold2.color = SIGN_TEXT
	sold2.modulate.a = 0.0
	sign_root.add_child(sold2)
	root.add_child(sign_root)
	return root

## A fat market coin. Origin CENTRE.
static func make_coin(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Coin"
	var body := Polygon2D.new()
	body.polygon = ellipse(size, size * 0.86, 14)
	body.color = COIN
	root.add_child(body)
	var face := Polygon2D.new()
	face.polygon = ellipse(size * 0.6, size * 0.52, 12)
	face.color = COIN_EDGE
	root.add_child(face)
	var shine := Polygon2D.new()
	shine.polygon = ellipse(size * 0.28, size * 0.2, 8)
	shine.color = COIN
	shine.position = Vector2(-size * 0.18, -size * 0.12)
	root.add_child(shine)
	return root

## A protest splat: irregular blob with drips. Origin CENTRE.
static func make_splat(size: float, color: Color) -> Node2D:
	var root := Node2D.new()
	root.name = "Splat"
	var blob := Polygon2D.new()
	var pts := PackedVector2Array()
	var radii := [1.0, 0.7, 0.95, 0.65, 1.05, 0.75, 0.9, 0.7]
	for i in range(8):
		var a := i * TAU / 8.0
		pts.append(Vector2(cos(a), sin(a)) * size * radii[i])
	blob.polygon = pts
	blob.color = color
	root.add_child(blob)
	for d in range(3):
		var drip := Polygon2D.new()
		drip.polygon = ellipse(size * 0.16, size * 0.24, 8)
		var a2 := TAU * 0.15 * float(d) + 0.5
		drip.position = Vector2(cos(a2), sin(a2)) * size * 1.15
		drip.color = color
		root.add_child(drip)
	return root
