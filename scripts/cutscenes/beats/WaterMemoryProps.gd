extends Object

## Shared polygon props for the Water Memory beat clips (#23).
## Palette lifted from res://scenes/minigames/WaterMemory.gd.

const BG := Color(0.15, 0.25, 0.4)
const BACK := Color(0.2, 0.45, 0.7)
const BACK_BORDER := Color(0.3, 0.6, 0.9)
const FACE := Color(0.85, 0.92, 1.0)
const FACE_BORDER := Color(0.4, 0.7, 1.0)
const MATCH := Color(0.6, 0.95, 0.6)
const MATCH_BORDER := Color(0.3, 0.9, 0.3)
const TABLE := Color(0.45, 0.3, 0.18)
const TABLE_EDGE := Color(0.35, 0.22, 0.12)
const BOARD := Color(0.95, 0.9, 0.85)
const INK := Color(0.12, 0.2, 0.32)
const BLANK := Color(0.78, 0.78, 0.8)

## Rounded-corner rectangle polygon (clockwise from the top-left arc).
static func rounded_rect(w: float, h: float, r: float, seg: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hx := w * 0.5
	var hy := h * 0.5
	r = minf(r, minf(hx, hy))
	var centers := [
		Vector2(-hx + r, -hy + r), Vector2(hx - r, -hy + r),
		Vector2(hx - r, hy - r), Vector2(-hx + r, hy - r),
	]
	for c in range(4):
		for s in range(seg + 1):
			var a := PI * (1.0 + 0.5 * float(c) + 0.5 * float(s) / float(seg))
			pts.append(centers[c] + Vector2(cos(a), sin(a)) * r)
	return pts

## Water-drop polygon, tip up.
static func drop_poly(size: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0.0, -size * 0.6)])
	for i in range(13):
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a) * 0.85 + 0.32) * size * 0.42)
	return pts

## Four-point sparkle star.
static func star_poly(size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(8):
		var a := TAU * float(i) / 8.0 - PI * 0.5
		pts.append(Vector2(cos(a), sin(a))
			* (size * 0.35 if i % 2 == 1 else size * 0.5))
	return pts

## A memory card, width `size`, height 1.4x, rounded corners.
## Children: BackEdge + Back (face-down look with a drop emblem) and
## Face + Mark (the reveal side; caller drives visibility).
static func make_card(size: float) -> Node2D:
	var card := Node2D.new()
	card.name = "Card"
	var h := size * 1.4
	var back_edge := Polygon2D.new()
	back_edge.name = "BackEdge"
	back_edge.polygon = rounded_rect(size, h, size * 0.14)
	back_edge.color = BACK_BORDER
	card.add_child(back_edge)
	var back := Polygon2D.new()
	back.name = "Back"
	back.polygon = rounded_rect(size * 0.92, h * 0.92, size * 0.12)
	back.color = BACK
	back.position = Vector2.ZERO
	card.add_child(back)
	var emblem := Polygon2D.new()
	emblem.name = "Emblem"
	emblem.polygon = drop_poly(size * 0.4)
	emblem.color = BACK_BORDER
	emblem.modulate.a = 0.9
	card.add_child(emblem)
	var face := Polygon2D.new()
	face.name = "Face"
	face.polygon = rounded_rect(size, h, size * 0.14)
	face.color = FACE
	face.visible = false
	card.add_child(face)
	var mark := Polygon2D.new()
	mark.name = "Mark"
	mark.polygon = drop_poly(size * 0.55)
	mark.color = FACE_BORDER
	mark.visible = false
	card.add_child(mark)
	return card

## The WATER-SAVING CHAMPION billboard: two posts, cream board, two
## ink headline bars, and a star up top.
static func make_billboard(size: float) -> Node2D:
	var bb := Node2D.new()
	bb.name = "Billboard"
	for side in range(2):
		var post := Polygon2D.new()
		post.name = "Post%d" % side
		post.polygon = PackedVector2Array([
			Vector2(-size * 0.03, 0.0), Vector2(size * 0.03, 0.0),
			Vector2(size * 0.03, -size * 0.58), Vector2(-size * 0.03, -size * 0.58),
		])
		post.position = Vector2(size * (0.3 if side == 0 else -0.3), 0.0)
		post.color = TABLE_EDGE
		bb.add_child(post)
	var board := Polygon2D.new()
	board.name = "Board"
	board.polygon = rounded_rect(size * 0.86, size * 0.5, size * 0.06)
	board.color = BOARD
	board.position = Vector2(0.0, -size * 0.82)
	bb.add_child(board)
	var head := Polygon2D.new()
	head.name = "HeadLine"
	head.polygon = rounded_rect(size * 0.62, size * 0.09, size * 0.03, 3)
	head.color = INK
	head.position = Vector2(0.0, -size * 0.92)
	bb.add_child(head)
	var head2 := Polygon2D.new()
	head2.name = "HeadLine2"
	head2.polygon = rounded_rect(size * 0.42, size * 0.07, size * 0.03, 3)
	head2.color = FACE_BORDER
	head2.position = Vector2(0.0, -size * 0.78)
	bb.add_child(head2)
	var star := Polygon2D.new()
	star.name = "Star"
	star.polygon = star_poly(size * 0.16)
	star.color = Color(1.0, 0.85, 0.3)
	star.position = Vector2(size * 0.3, -size * 1.1)
	bb.add_child(star)
	return bb
