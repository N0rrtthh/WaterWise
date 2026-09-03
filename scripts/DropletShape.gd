class_name DropletShape
extends RefCounted

## Single source of truth for the water-droplet silhouette.
##
## Why this is its own class: the droplet is drawn in two unrelated places —
## CartoonActor (cutscene character) and DropletSprite (gameplay entity). When
## each owned its own geometry they drifted, and gameplay fell back to a 💧 emoji
## Label, which meant the "water droplet" the player moves did not match the
## character in the cutscene and rendered differently on every platform's font.
##
## Geometry, per vertex angle `a` (y grows downward; the walk starts at the tip):
##   s     = -sin(a)             1.0 at the top, 0.0 at the widest point
##   taper = sqrt(1 - s)         collapses x to exactly 0 at the tip
##   y is scaled by TIP_STRETCH on the upper half so the point rises
## The lower half is an untouched ellipse, so the droplet sits flat. |x| falls
## monotonically from the equator up to the tip on each side, so the polygon
## cannot self-intersect for any rx/ry.

const TIP_STRETCH: float = 1.22

static func outline(rx: float, ry: float, segments: int = 30) -> PackedVector2Array:
	# Vertex phase matters. Stepping from angle 0 only lands a vertex exactly on
	# the tip when segments is a multiple of 4; at any other count the two
	# nearest vertices straddle it and Polygon2D draws a blunt, chopped-off
	# point — the droplet reads as a blob again. Same at the bottom, which fell
	# short of ry and made the shape look slightly deflated.
	#
	# So: start at the tip (a = -PI/2) and force an even count. i = 0 is then the
	# tip and i = segments/2 is the lowest point, at every size and resolution.
	var count: int = maxi(8, segments)
	if count % 2 == 1:
		count += 1

	var pts := PackedVector2Array()
	for i in range(count):
		var a: float = -PI * 0.5 + float(i) * TAU / float(count)
		var cx: float = cos(a)
		var sy: float = sin(a)
		var s: float = -sy
		if s > 0.0:
			var taper: float = sqrt(maxf(0.0, 1.0 - s))
			pts.append(Vector2(cx * rx * taper, sy * ry * TIP_STRETCH))
		else:
			pts.append(Vector2(cx * rx, sy * ry))
	return pts

## Vertex count outline() will actually emit for a requested count. Callers that
## need to size a buffer, and the verification gate, use this instead of
## re-deriving the rounding rule.
static func vertex_count(segments: int) -> int:
	var count: int = maxi(8, segments)
	return count + (count % 2)

## Highest point of the silhouette, for anchoring things above the tip.
static func tip_y(ry: float) -> float:
	return -ry * TIP_STRETCH

## Small comma-shaped highlight, sized relative to the body.
static func highlight(rx: float, ry: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-rx * 0.35, -ry * 0.54),
		Vector2(-rx * 0.13, -ry * 0.64),
		Vector2(rx * 0.04, -ry * 0.50),
		Vector2(-rx * 0.15, -ry * 0.34),
	])
