extends RefCounted

## Timing Tap shared props for the beat tier.
## Flat-fill set: a wall-mounted tap with a turnable handle, a glass tank
## with a rising water body and a flaring target line, folding chairs for
## the spectator crowd, a latte-art water swirl, a serving tray, a broom
## and a tsunami floodwave.
##
## Colours taken from the minigame: warm kitchen wall, brown counter,
## steel tap, translucent water, red target line.

const WALL := Color(0.9, 0.88, 0.85)
const COUNTER := Color(0.45, 0.35, 0.25)
const COUNTER_TOP := Color(0.62, 0.5, 0.36)
const FLOOR := Color(0.72, 0.6, 0.5)
const STEEL := Color(0.72, 0.76, 0.8)
const STEEL_DARK := Color(0.52, 0.56, 0.62)
const WATER := Color(0.3, 0.6, 1.0, 0.75)
const GLASS := Color(0.75, 0.88, 1.0, 0.30)
const TARGET := Color(0.95, 0.3, 0.3)
const CHAIR := Color(0.85, 0.55, 0.2)
const SWIRL := Color(0.95, 0.98, 1.0, 0.95)
const TRAY := Color(0.82, 0.66, 0.3)
const BROOM := Color(0.7, 0.5, 0.25)
const WAVE := Color(0.35, 0.7, 1.0, 0.9)
const WAVE_FOAM := Color(0.85, 0.95, 1.0)

static func _ellipse(rx: float, ry: float, points: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(points):
		var a := i * TAU / float(points)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A water body for the glass: a tapered rect. `height` is absolute
## (scripts re-run this to raise/lower the fill every frame or tween).
static func water_poly(size: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-size * 0.235, 0.0), Vector2(size * 0.235, 0.0),
		Vector2(size * 0.285, -height), Vector2(-size * 0.285, -height),
	])

## The tap. Origin at the SPOUT TIP (water spawns at 0,0 and pours +y).
## The "Handle" child rotates when the tap is turned.
static func make_tap(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Tap"
	var spout := Polygon2D.new()
	spout.name = "Spout"
	spout.polygon = PackedVector2Array([
		Vector2(-size * 0.10, 0.0), Vector2(size * 0.10, 0.0),
		Vector2(size * 0.10, -size * 0.22), Vector2(-size * 0.10, -size * 0.22),
	])
	spout.color = STEEL_DARK
	root.add_child(spout)
	var arm := Polygon2D.new()
	arm.polygon = PackedVector2Array([
		Vector2(-size * 0.62, -size * 0.22), Vector2(size * 0.12, -size * 0.22),
		Vector2(size * 0.12, -size * 0.40), Vector2(-size * 0.62, -size * 0.40),
	])
	arm.color = STEEL
	root.add_child(arm)
	var riser := Polygon2D.new()
	riser.polygon = PackedVector2Array([
		Vector2(-size * 0.70, -size * 0.40), Vector2(-size * 0.54, -size * 0.40),
		Vector2(-size * 0.54, -size * 0.95), Vector2(-size * 0.70, -size * 0.95),
	])
	riser.color = STEEL_DARK
	root.add_child(riser)
	var handle := Node2D.new()
	handle.name = "Handle"
	handle.position = Vector2(-size * 0.62, -size * 0.98)
	var bar := Polygon2D.new()
	bar.polygon = PackedVector2Array([
		Vector2(-size * 0.16, -size * 0.05), Vector2(size * 0.16, -size * 0.05),
		Vector2(size * 0.16, size * 0.05), Vector2(-size * 0.16, size * 0.05),
	])
	bar.color = Color(0.9, 0.35, 0.3)
	handle.add_child(bar)
	var knob := Polygon2D.new()
	knob.polygon = _ellipse(size * 0.07, size * 0.07, 10)
	knob.color = Color(0.9, 0.35, 0.3).lightened(0.2)
	handle.add_child(knob)
	root.add_child(handle)
	return root

## The glass tank. Origin BASE-CENTRE. The "Water" polygon is exposed for
## rising/overflowing fills; "TargetLine" is THE mark and flares on cue.
static func make_glass(size: float, fill: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Glass"
	var interior_h := size * 0.72
	var water := Polygon2D.new()
	water.name = "Water"
	water.polygon = water_poly(size, interior_h * fill)
	water.color = WATER
	root.add_child(water)
	var shell := Polygon2D.new()
	shell.name = "Shell"
	shell.polygon = PackedVector2Array([
		Vector2(-size * 0.26, 0.0), Vector2(size * 0.26, 0.0),
		Vector2(size * 0.32, -interior_h), Vector2(-size * 0.32, -interior_h),
	])
	shell.color = GLASS
	root.add_child(shell)
	var outline := Line2D.new()
	outline.width = size * 0.035
	outline.default_color = Color(0.6, 0.75, 0.9, 0.9)
	outline.points = PackedVector2Array([
		Vector2(-size * 0.26, 0.0), Vector2(-size * 0.32, -interior_h),
		Vector2(size * 0.32, -interior_h), Vector2(size * 0.26, 0.0),
	])
	root.add_child(outline)
	var line := Line2D.new()
	line.name = "TargetLine"
	line.width = size * 0.045
	line.default_color = TARGET
	line.points = PackedVector2Array([
		Vector2(-size * 0.38, -interior_h * 0.8),
		Vector2(size * 0.38, -interior_h * 0.8),
	])
	root.add_child(line)
	return root## A folding chair for the spectator crowd. Origin BASE-CENTRE, backrest
## on the right (the crowd faces left, toward the tap).
static func make_chair(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Chair"
	var seat := Polygon2D.new()
	seat.polygon = PackedVector2Array([
		Vector2(-size * 0.30, -size * 0.36), Vector2(size * 0.30, -size * 0.36),
		Vector2(size * 0.30, -size * 0.28), Vector2(-size * 0.30, -size * 0.28),
	])
	seat.color = CHAIR
	root.add_child(seat)
	var back := Polygon2D.new()
	back.polygon = PackedVector2Array([
		Vector2(size * 0.22, -size * 0.95), Vector2(size * 0.32, -size * 0.95),
		Vector2(size * 0.32, -size * 0.28), Vector2(size * 0.22, -size * 0.28),
	])
	back.color = CHAIR.darkened(0.15)
	root.add_child(back)
	for side in [-1.0, 1.0]:
		var leg := Polygon2D.new()
		leg.polygon = PackedVector2Array([
			Vector2(side * size * 0.24 - size * 0.03, -size * 0.30),
			Vector2(side * size * 0.24 + size * 0.03, -size * 0.30),
			Vector2(side * size * 0.24 + size * 0.03, 0.0),
			Vector2(side * size * 0.24 - size * 0.03, 0.0),
		])
		leg.color = CHAIR.darkened(0.35)
		root.add_child(leg)
	return root

## Latte-art water swirl. Origin CENTRE; caller scales from zero for the
## bloom. The spiral + foam heart read as barista-art made of water.
static func make_swirl(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Swirl"
	var spiral := Line2D.new()
	spiral.name = "Spiral"
	spiral.width = size * 0.09
	spiral.default_color = SWIRL
	var pts := PackedVector2Array()
	for i in range(33):
		var t := float(i) / 32.0
		var a := t * TAU * 1.75
		var r := size * (0.12 + 0.72 * t)
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.45))
	spiral.points = pts
	root.add_child(spiral)
	var heart := Polygon2D.new()
	heart.polygon = PackedVector2Array([
		Vector2(0.0, size * 0.10), Vector2(-size * 0.10, 0.0),
		Vector2(-size * 0.10, -size * 0.05), Vector2(-size * 0.05, -size * 0.08),
		Vector2(0.0, -size * 0.05), Vector2(size * 0.05, -size * 0.08),
		Vector2(size * 0.10, -size * 0.05), Vector2(size * 0.10, 0.0),
	])
	heart.color = SWIRL
	root.add_child(heart)
	return root

## A serving tray for the mayor's surf. Origin CENTRE.
static func make_tray(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Tray"
	var rim := Polygon2D.new()
	rim.polygon = _ellipse(size * 0.56, size * 0.16, 14)
	rim.color = TRAY.darkened(0.2)
	root.add_child(rim)
	var plate := Polygon2D.new()
	plate.polygon = _ellipse(size * 0.5, size * 0.13, 14)
	plate.color = TRAY
	root.add_child(plate)
	var cup := Polygon2D.new()
	cup.polygon = _ellipse(size * 0.10, size * 0.10, 10)
	cup.position = Vector2(-size * 0.2, -size * 0.08)
	cup.color = TRAY.lightened(0.3)
	root.add_child(cup)
	return root

## A broom. Origin at the BRISTLE BASE (floor contact).
static func make_broom(size: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Broom"
	var bristles := Polygon2D.new()
	bristles.polygon = PackedVector2Array([
		Vector2(-size * 0.14, 0.0), Vector2(size * 0.14, 0.0),
		Vector2(size * 0.10, -size * 0.24), Vector2(-size * 0.10, -size * 0.24),
	])
	bristles.color = Color(0.9, 0.75, 0.4)
	root.add_child(bristles)
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([
		Vector2(-size * 0.10, -size * 0.24), Vector2(size * 0.10, -size * 0.24),
		Vector2(size * 0.10, -size * 0.32), Vector2(-size * 0.10, -size * 0.32),
	])
	band.color = Color(0.6, 0.3, 0.2)
	root.add_child(band)
	var handle := Line2D.new()
	handle.width = size * 0.055
	handle.default_color = BROOM
	handle.points = PackedVector2Array([
		Vector2(0.0, -size * 0.30), Vector2(size * 0.42, -size * 1.05),
	])
	root.add_child(handle)
	return root

## The tsunami floodwave. Origin BASE-LEFT; sweeps along +x. The "Crest"
## child marks the foam apex for framing.
static func make_wave(length: float) -> Node2D:
	var root := Node2D.new()
	root.name = "Wave"
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(length * 0.18, -length * 0.38),
		Vector2(length * 0.38, -length * 0.60),
		Vector2(length * 0.55, -length * 0.66),
		Vector2(length * 0.78, -length * 0.42),
		Vector2(length * 1.0, -length * 0.10),
		Vector2(length * 1.0, 0.0),
	])
	body.color = WAVE
	root.add_child(body)
	var foam := Polygon2D.new()
	foam.polygon = _ellipse(length * 0.14, length * 0.10, 12)
	foam.position = Vector2(length * 0.5, -length * 0.68)
	foam.color = WAVE_FOAM
	root.add_child(foam)
	var crest := Node2D.new()
	crest.name = "Crest"
	crest.position = Vector2(length * 0.5, -length * 0.66)
	root.add_child(crest)
	return root

## A tapered water arc. Origin at the SPOUT; extends +x/+y (caller
## rotates into place). "Flow" scales x to extend/retract the pour.
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

## A tiny foam heart for the trophy lift. Origin CENTRE.
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
	heart.color = Color(0.95, 0.45, 0.6)
	return heart
