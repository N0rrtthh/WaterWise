## WaterMemory - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/WaterMemoryWinOutro.tscn

extends MicrogameOutroBase

## Water Memory — WIN clip.
## res://scenes/ui/cutscenes/beats/WaterMemoryWinOutro.tscn
##
## BEAT 1  The six matched cards gleam on the table, then fly up into a
##         house-of-cards trophy (final card lands at the impact frame).
## BEAT 2  (impact on the final card placement) The trophy locks in with
##         a gleam and the town gasps.
## BEAT 3  A "WATER-SAVING CHAMPION" billboard rises behind Dribble and
##         the town gathers to read it.

const Props := preload("res://scripts/cutscenes/beats/WaterMemoryProps.gd")

var cards: Array = []
var stack: Array = []          # target transforms for the house of cards
var trophy_x: float
var card_h: float
var billboard: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	var gy := _vp.y * GROUND_FRACTION
	# The card table, front and centre.
	var table := Node2D.new()
	table.name = "Table"
	table.position = Vector2(_vp.x * 0.36, 0.0)
	table.z_index = 1
	world.add_child(table)
	var top := Polygon2D.new()
	top.name = "Top"
	top.polygon = Props.rounded_rect(_vp.x * 0.44, _vp.y * 0.06, _vp.y * 0.02)
	top.color = Props.TABLE
	top.position = Vector2(0.0, _vp.y * 0.66)
	table.add_child(top)
	for side in range(2):
		var leg := Polygon2D.new()
		leg.name = "Leg%d" % side
		leg.polygon = PackedVector2Array([
			Vector2(-_vp.y * 0.018, 0.0), Vector2(_vp.y * 0.018, 0.0),
			Vector2(_vp.y * 0.018, gy - _vp.y * 0.69),
			Vector2(-_vp.y * 0.018, gy - _vp.y * 0.69),
		])
		leg.position = Vector2(_vp.x * (0.14 if side == 0 else -0.14), _vp.y * 0.69)
		leg.color = Props.TABLE_EDGE
		table.add_child(leg)
	# Six MATCHED cards (green faces up) on the tabletop.
	card_h = _vp.y * 0.115
	var card_w := card_h / 1.4
	for i in range(6):
		var card := Props.make_card(card_w)
		var col := i % 3
		var row := int(i / 3.0)
		card.position = Vector2(
			_vp.x * 0.36 + (-0.12 + 0.12 * float(col)) * _vp.x,
			_vp.y * (0.625 if row == 0 else 0.655))
		card.z_index = 2
		var back := card.get_node("Back") as Polygon2D
		var edge := card.get_node("BackEdge") as Polygon2D
		back.visible = false
		edge.visible = false
		var face := card.get_node("Face") as Polygon2D
		var mark := card.get_node("Mark") as Polygon2D
		face.visible = true
		face.color = Props.MATCH
		mark.visible = true
		world.add_child(card)
		cards.append(card)
	# House-of-cards stack target, right of the table on the ground.
	trophy_x = _vp.x * 0.62
	stack = [
		{"pos": Vector2(trophy_x - card_h * 0.62, gy - card_h * 0.48),
			"rot": -0.14},
		{"pos": Vector2(trophy_x, gy - card_h * 0.48), "rot": 0.0},
		{"pos": Vector2(trophy_x + card_h * 0.62, gy - card_h * 0.48),
			"rot": 0.14},
		{"pos": Vector2(trophy_x - card_h * 0.31, gy - card_h * 1.44),
			"rot": -0.1},
		{"pos": Vector2(trophy_x + card_h * 0.31, gy - card_h * 1.44),
			"rot": 0.1},
		{"pos": Vector2(trophy_x, gy - card_h * 2.28), "rot": PI * 0.5},
	]
	_stage_townsfolk(2, _vp.x * 0.04, _vp.x * 0.12)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.90, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.34)
	# The champion billboard waits BELOW the ground line, out of sight
	# (z -1 tucks it behind the ground polygon until it rises).
	billboard = Props.make_billboard(_vp.y * 0.52)
	billboard.position = Vector2(_vp.x * 0.38, gy + _vp.y * 0.95)
	billboard.z_index = -1
	world.add_child(billboard)
	camera.position = _vp * 0.5

## Impact frame: the cap card of the house of cards.
func _impact_point() -> Vector2:
	return Vector2(trophy_x, _vp.y * GROUND_FRACTION - card_h * 2.28)

## BEAT 1 — the matched cards fly up into the house of cards.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.SMUG)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# Gleam pass over the matched faces while they wait.
	for card: Node2D in cards:
		var face := card.get_node("Face") as Polygon2D
		var gleam := _ct(face).set_loops(2)
		gleam.tween_property(face, "modulate", Color(1.25, 1.45, 1.25), 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		gleam.tween_property(face, "modulate", Color.WHITE, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Then the cards arc up into the stack, cap card LAST.
	for i in range(cards.size()):
		var card := cards[i] as Node2D
		var target: Dictionary = stack[i]
		var start := card.position
		var fly := _ct(card)
		fly.tween_interval(0.55 + 0.09 * float(i))
		fly.tween_method(func(v: float):
			card.position = start.lerp(target.pos, v)
			card.position.y -= _vp.y * 0.1 * sin(v * PI)
			card.rotation = lerpf(card.rotation, target.rot, v),
			0.0, 1.0, 0.26) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — the cap card lands: the trophy LOCKS IN.
func _on_impact() -> void:
	super._on_impact()
	# The whole trophy does a settle-bounce, cap card gleaming.
	for i in range(cards.size()):
		var card := cards[i] as Node2D
		var settle := _ct(card)
		settle.tween_property(card, "scale", Vector2(1.08, 1.08), 0.06) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		settle.tween_property(card, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var face := card.get_node("Face") as Polygon2D
		var flare := _ct(face)
		flare.tween_property(face, "modulate", Color(1.5, 1.8, 1.5), 0.08)
		flare.tween_property(face, "modulate", Color.WHITE, 0.2)
	# Golden stars pop around the finished trophy.
	for s in range(4):
		var star := Polygon2D.new()
		star.polygon = Props.star_poly(_vp.y * (0.03 + 0.012 * float(s % 2)))
		star.color = Color(1.0, 0.85, 0.3)
		star.position = _impact_point() + Vector2(
			(-40.0 + 26.0 * float(s)) * _content_scale,
			(-14.0 + 11.0 * float(s % 3)) * _content_scale)
		star.z_index = 8
		world.add_child(star)
		var pop := _ct(star)
		pop.set_parallel(true)
		pop.tween_property(star, "rotation", 1.2, 0.4)
		pop.tween_property(star, "modulate:a", 0.0, 0.4)
		pop.chain().tween_callback(star.queue_free)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.HAPPY)

## BEAT 3 — the WATER-SAVING CHAMPION billboard rises behind Dribble.
func _beat_payoff() -> void:
	var gy := _vp.y * GROUND_FRACTION
	# The billboard hoists up out of the ground behind the champion.
	var hoist := _ct(billboard)
	hoist.tween_property(billboard, "position:y", gy, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The star on top spins and shines.
	var star := billboard.get_node("Star") as Polygon2D
	var shine := _ct(star).set_loops(3)
	shine.tween_property(star, "rotation", TAU * 0.25, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shine.tween_property(star, "rotation", 0.0, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The town gathers in front of the billboard to read it.
	var read_x := [0.28, 0.48, 0.22]
	for i in range(townsfolk.size()):
		var t := townsfolk[i] as Node2D
		var walk := _ct(t)
		walk.tween_property(t, "position:x", _vp.x * read_x[i % read_x.size()], 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var gather := _ct(mayor)
	gather.tween_property(mayor, "position:x", _vp.x * 0.54, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for t: CartoonActor in townsfolk:
		t.set_expression(CartoonActor.Mood.HAPPY)
		t.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	dribble.set_expression(CartoonActor.Mood.SMUG)
	dribble.set_arm_pose(CartoonActor.ArmPose.UP)
	dribble.hop(14.0, 0.3)
	# The champion's trophy shines on behind him.
	var cap := cards[5] as Node2D
	var cap_gleam := _ct(cap).set_loops(2)
	cap_gleam.tween_property(cap, "modulate", Color(1.4, 1.5, 1.3), 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cap_gleam.tween_property(cap, "modulate", Color.WHITE, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
