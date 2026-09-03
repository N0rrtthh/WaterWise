class_name CastFactory
extends RefCounted

## Recurring-cast builders for the "Dumb Ways to Waste" beat tier.
##
## The cast is a FIXED roster that must look identical no matter which
## minigame's beat scene stages it:
##   * Dribble      — the bean-shaped blue droplet, player in every clip
##   * Mayor Ripple — rounder town-leader, gold sash, reacts to the outcome
##   * The Town     — 1–5 palette-swapped blob townsfolk (crowd/reaction; 3–5 for a crowd shot)
##
## Visual contract (flat fills, thick-or-no outlines, dot eyes, no surface
## detail) is enforced by CartoonActor itself — these helpers only fix
## IDENTITY: skin colour, silhouette scale, and the mayor's sash. Personality
## comes from the beat scripts' motion, never from texture.

const DRIBBLE_SKIN := Color(0.36, 0.76, 1.0)
const MAYOR_SKIN := Color(0.28, 0.60, 0.92)
const SASH_COLOR := Color(0.96, 0.78, 0.24)

const TOWNSFOLK_SKINS: Array[Color] = [
	Color(0.45, 0.82, 0.94),   # pale teal
	Color(0.55, 0.90, 0.62),   # mint
	Color(1.00, 0.82, 0.45),   # peach
	Color(0.93, 0.60, 0.70),   # rose
	Color(0.72, 0.62, 0.95),   # lavender
]

## Silhouette scales. The mayor is deliberately the roundest/largest civilian
## on screen; townsfolk read slightly smaller so Dribble stays the focal point
## even in a full crowd shot.
const MAYOR_SCALE := Vector2(1.18, 1.12)
const TOWNSFOLK_SCALE := Vector2(0.82, 0.82)

static func make_dribble() -> CartoonActor:
	var a := CartoonActor.new()
	a.name = "Dribble"
	a.set_skin(DRIBBLE_SKIN)
	return a

static func make_mayor() -> CartoonActor:
	var a := CartoonActor.new()
	a.name = "MayorRipple"
	a.set_skin(MAYOR_SKIN)
	return a

## Adds the mayor's sash + rosette. Call AFTER the actor is in the tree (the
## rig parts are allocated in build(), which _ready() triggers).
static func dress_mayor(a: CartoonActor) -> void:
	if not is_instance_valid(a):
		return
	if not a._built:
		a.build()
	if a.rig == null or a.rig.has_node("Belt"):
		return

	# IDENTITY: a gold belt-sash worn LOW on the body + rosette, and a small
	# bow tie under the mouth. The old shoulder-to-hip diagonal sash could
	# never work on this rig: the droplet body has no neck, so the torso IS
	# the face and any diagonal band stabbed across the eyes/mouth like a
	# spear. Everything below is confined to y >= 28, under the mouth.
	var belt := Polygon2D.new()
	belt.name = "Belt"
	# Edges follow the droplet's narrowing bottom half (half-width ~33 at
	# y=38, ~23 at y=48) so the belt never pokes outside the silhouette.
	belt.polygon = PackedVector2Array([
		Vector2(-33, 38), Vector2(33, 37), Vector2(22, 48), Vector2(-23, 49),
	])
	belt.color = SASH_COLOR
	a.rig.add_child(belt)
	# Layer BEHIND the face parts (right after the body's shine) so an open
	# mouth draws over the bow tie, not under it.
	a.rig.move_child(belt, a.rig.get_node("Shine").get_index() + 1)

	# Bow tie: two triangles meeting at a knot, centred at (0, 33) — just
	# under the mouth (mouth centre is y=20).
	var bow := Polygon2D.new()
	bow.name = "BowTie"
	bow.polygon = PackedVector2Array([
		Vector2(-3, 31), Vector2(-13, 25), Vector2(-13, 40), Vector2(0, 34),
		Vector2(13, 40), Vector2(13, 25), Vector2(3, 31),
	])
	bow.color = SASH_COLOR.darkened(0.15)
	a.rig.add_child(bow)
	a.rig.move_child(bow, belt.get_index() + 1)

	# Rosette pinned to the belt: a small ink-outlined disc.
	var rosette := Polygon2D.new()
	rosette.name = "Rosette"
	var pts := PackedVector2Array()
	for i in range(12):
		var ang := i * TAU / 12.0
		pts.append(Vector2(cos(ang) * 7.0, sin(ang) * 7.0))
	rosette.polygon = pts
	rosette.color = Color(0.85, 0.2, 0.25)
	rosette.position = Vector2(13, 43)
	a.rig.add_child(rosette)
	a.rig.move_child(rosette, bow.get_index() + 1)

## Crowd sizes are the CALLER's choice. This used to clamp the floor to 3, which silently
## overrode every explicit request below it: 39 clips ask _stage_townsfolk(2) and were handed a
## third body positioned by lerpf() in the middle of a span the author picked for two, and the 3
## RainwaterHarvesting clips ask make_townsfolk(1) for a single companion, keep [0], and left the
## other two built actors unparented - 72 orphan nodes per play, because set_skin() calls build()
## so every actor arrives with its whole 36-node rig allocated. CartoonActor extends Node2D and is
## not reference-counted, so nothing ever collected them. MicrogameOutroBase._stage_townsfolk()
## already carries an "if n == 1" guard that was unreachable under the old floor.
## The upper bound is real: TOWNSFOLK_SKINS holds 5 palette swaps.
static func make_townsfolk(count: int = 4) -> Array[CartoonActor]:
	var crowd: Array[CartoonActor] = []
	var n := clampi(count, 1, 5)
	for i in range(n):
		var a := CartoonActor.new()
		a.name = "Townsperson%d" % (i + 1)
		a.set_skin(TOWNSFOLK_SKINS[i % TOWNSFOLK_SKINS.size()])
		crowd.append(a)
	return crowd
