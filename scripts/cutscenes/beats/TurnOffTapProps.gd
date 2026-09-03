extends RefCounted

## Turn Off Tap shared props for the beat tier.
## Flat-fill set: chrome faucets with twistable handles and hidden
## water streams, a rising floor puddle, a comically small framed
## water bill, and a rocket-boosted loose faucet for the launch.
##
## Colours from the minigame: bathroom tiles, running-faucet blue,
## closed-tap green.

const WALL := Color(0.85, 0.9, 0.92)
const TILE := Color(0.82, 0.87, 0.89)
const TILE_ALT := Color(0.85, 0.9, 0.92)
const TILE_LINE := Color(0.75, 0.8, 0.83)
const CHROME := Color(0.72, 0.76, 0.8)
const CHROME_DARK := Color(0.5, 0.54, 0.6)
const CHROME_LIGHT := Color(0.85, 0.88, 0.91)
const HANDLE_RED := Color(0.85, 0.3, 0.25)
const STREAM := Color(0.3, 0.6, 1.0, 0.8)
const CLOSED_GREEN := Color(0.5, 0.8, 0.5)
const PUDDLE := Color(0.35, 0.65, 0.95, 0.65)
const FLAME := Color(1.0, 0.65, 0.2)
const FLAME_CORE := Color(1.0, 0.9, 0.4)

static func ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A rising puddle body: width `w`, height `h`, centred on x, base on y=0.
static func puddle_poly(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-w * 0.5, 0.0),
		Vector2(-w * 0.42, -h * 0.6),
		Vector2(-w * 0.25, -h),
		Vector2(w * 0.25, -h),
		Vector2(w * 0.42, -h * 0.6),
		Vector2(w * 0.5, 0.0),
	])

## A chrome faucet. Origin BASE-CENTRE (the pipe foot, on the ground);
## `size` is the overall height. The spout points +x (flip scale.x to
## face the other way). Named parts: "Handle" (twists shut), "Mouth"
## (empty node at the spout opening), "Stream" + "Splash" (alpha 0
## until the tap runs) and, on rockets, a hidden "Boost" exhaust.
static func make_faucet(size: float, on := false, rocket := false) -> Node2D:
	var root := Node2D.new()
	root.name = "Faucet"
	# Pedestal pipe up from the floor.
	var pipe := Polygon2D.new()
	pipe.polygon = PackedVector2Array([
		Vector2(-size * 0.09, 0.0), Vector2(size * 0.09, 0.0),
		Vector2(size * 0.09, -size * 0.32), Vector2(-size * 0.09, -size * 0.32),
	])
	pipe.color = CHROME_DARK
	root.add_child(pipe)
	# Horizontal spout with a tip.
	var spout := Polygon2D.new()
	spout.polygon = PackedVector2Array([
		Vector2(-size * 0.09, -size * 0.44), Vector2(size * 0.40, -size * 0.44),
		Vector2(size * 0.44, -size * 0.40), Vector2(size * 0.44, -size * 0.34),
		Vector2(size * 0.40, -size * 0.30), Vector2(-size * 0.09, -size * 0.30),
	])
	spout.color = CHROME
	root.add_child(spout)
	var shine := Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-size * 0.09, -size * 0.43), Vector2(size * 0.38, -size * 0.43),
		Vector2(size * 0.38, -size * 0.395), Vector2(-size * 0.09, -size * 0.395),
	])
	shine.color = CHROME_LIGHT
	root.add_child(shine)
	# Twistable cross handle on a red hub.
	var handle := Node2D.new()
	handle.name = "Handle"
	handle.position = Vector2(-size * 0.02, -size * 0.46)
	var hub := Polygon2D.new()
	hub.polygon = ellipse(size * 0.035, size * 0.035, 10)
	hub.color = HANDLE_RED
	handle.add_child(hub)
	for i in range(4):
		var spoke := Polygon2D.new()
		var dir := Vector2(1, 0).rotated(TAU * 0.25 * float(i) + TAU * 0.125)
		spoke.polygon = PackedVector2Array([
			dir * size * 0.03, dir.rotated(0.25) * size * 0.115,
			dir.rotated(-0.25) * size * 0.115,
		])
		spoke.color = CHROME
		handle.add_child(spoke)
	root.add_child(handle)
	# The spout mouth marker.
	var mouth := Node2D.new()
	mouth.name = "Mouth"
	mouth.position = Vector2(size * 0.42, -size * 0.37)
	root.add_child(mouth)
	# The water stream, falling from the mouth to the floor.
	var stream := Polygon2D.new()
	stream.name = "Stream"
	stream.polygon = PackedVector2Array([
		Vector2(size * 0.39, -size * 0.37), Vector2(size * 0.45, -size * 0.37),
		Vector2(size * 0.44, size * 0.02), Vector2(size * 0.40, size * 0.02),
	])
	stream.color = STREAM
	stream.modulate.a = 1.0 if on else 0.0
	root.add_child(stream)
	var splash := Polygon2D.new()
	splash.name = "Splash"
	splash.polygon = ellipse(size * 0.10, size * 0.025, 12)
	splash.position = Vector2(size * 0.42, size * 0.02)
	splash.color = STREAM
	splash.modulate.a = 1.0 if on else 0.0
	root.add_child(splash)
	if rocket:
		# Hidden exhaust flame stack for the rocket-pony launch.
		var boost := Polygon2D.new()
		boost.name = "Boost"
		boost.polygon = PackedVector2Array([
			Vector2(-size * 0.08, 0.0), Vector2(size * 0.08, 0.0),
			Vector2(size * 0.05, size * 0.18), Vector2(0.0, size * 0.30),
			Vector2(-size * 0.05, size * 0.18),
		])
		boost.color = FLAME
		boost.modulate.a = 0.0
		root.add_child(boost)
		var core := Polygon2D.new()
		core.name = "BoostCore"
		core.polygon = PackedVector2Array([
			Vector2(-size * 0.04, 0.0), Vector2(size * 0.04, 0.0),
			Vector2(0.0, size * 0.16),
		])
		core.color = FLAME_CORE
		core.modulate.a = 0.0
		root.add_child(core)
	return root

## The rising floor puddle. "Water" is driven via puddle_poly().
static func make_puddle() -> Node2D:
	var root := Node2D.new()
	root.name = "Puddle"
	var water := Polygon2D.new()
	water.name = "Water"
	water.polygon = puddle_poly(1.0, 1.0)
	water.color = PUDDLE
	water.scale = Vector2(0.001, 0.001)
	root.add_child(water)
	return root

## The comically small framed water bill. Origin CENTRE.
static func make_bill(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Bill"
	var frame := Polygon2D.new()
	frame.polygon = PackedVector2Array([
		Vector2(-size * 0.5, -size * 0.42), Vector2(size * 0.5, -size * 0.42),
		Vector2(size * 0.5, size * 0.42), Vector2(-size * 0.5, size * 0.42),
	])
	frame.color = CHROME_DARK
	root.add_child(frame)
	var paper := Polygon2D.new()
	paper.polygon = PackedVector2Array([
		Vector2(-size * 0.42, -size * 0.34), Vector2(size * 0.42, -size * 0.34),
		Vector2(size * 0.42, size * 0.34), Vector2(-size * 0.42, size * 0.34),
	])
	paper.color = Color(0.96, 0.96, 0.9)
	root.add_child(paper)
	for i in range(3):
		var line := Polygon2D.new()
		var y := (-0.18 + 0.14 * float(i)) * size
		line.polygon = PackedVector2Array([
			Vector2(-size * 0.30, y), Vector2(size * 0.30, y),
			Vector2(size * 0.30, y + size * 0.045),
			Vector2(-size * 0.30, y + size * 0.045),
		])
		line.color = Color(0.7, 0.72, 0.75)
		root.add_child(line)
	# The total: one tiny blue drop.
	var drop := Polygon2D.new()
	drop.polygon = PackedVector2Array([
		Vector2(0.0, -size * 0.07), Vector2(size * 0.05, 0.0),
		Vector2(0.0, size * 0.07), Vector2(-size * 0.05, 0.0),
	])
	drop.position = Vector2(0.0, size * 0.2)
	drop.color = Color(0.3, 0.6, 1.0)
	root.add_child(drop)
	return root
