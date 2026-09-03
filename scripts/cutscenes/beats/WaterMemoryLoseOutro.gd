## WaterMemory - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/WaterMemoryLoseOutro.tscn

extends MicrogameOutroBase

## Water Memory — LOSE clip.
## res://scenes/ui/cutscenes/beats/WaterMemoryLoseOutro.tscn
##
## BEAT 1  The cards wait face-down; Dribble flips a pair, unsure.
## BEAT 2  (impact on the blank reveal) EVERY card flips over to a
##         BLANK face — nothing on any of them. The town is stunned.
## BEAT 3  The town, no longer recognizing the "stranger", politely but
##         firmly escorts Dribble off the cliff.

const Props := preload("res://scripts/cutscenes/beats/WaterMemoryProps.gd")

var cards: Array = []
var card_w: float

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	var gy := _vp.y * GROUND_FRACTION
	# The card table, front and centre.
	var table := Node2D.new()
	table.name = "Table"
	table.position = Vector2(_vp.x * 0.42, 0.0)
	table.z_index = 1
	world.add_child(table)
	var top := Polygon2D.new()
	top.name = "Top"
	top.polygon = Props.rounded_rect(_vp.x * 0.52, _vp.y * 0.06, _vp.y * 0.02)
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
		leg.position = Vector2(_vp.x * (0.18 if side == 0 else -0.18), _vp.y * 0.69)
		leg.color = Props.TABLE_EDGE
		table.add_child(leg)
	# Six face-down cards in a 3x2 grid, blank secrets inside.
	card_w = _vp.y * 0.088
	for i in range(6):
		var card := Props.make_card(card_w)
		var col := i % 3
		var row := int(i / 3.0)
		card.position = Vector2(
			_vp.x * 0.42 + (-0.15 + 0.15 * float(col)) * _vp.x,
			_vp.y * (0.615 if row == 0 else 0.665))
		card.z_index = 2
		world.add_child(card)
		cards.append(card)
	# The audience that came to watch a champion.
	_stage_townsfolk(2, _vp.x * 0.04, _vp.x * 0.12)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.90, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.38)
	camera.position = _vp * 0.5

## Impact frame: the pair of cards Dribble was mid-flip on.
func _impact_point() -> Vector2:
	return (cards[4] as Node2D).position

## BEAT 1 — Dribble nervously flips the first pair.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# Two cards flip face-up... onto nothing. Mark hidden, face pale.
	for idx in [4, 3]:
		var card := cards[idx] as Node2D
		var back := card.get_node("Back") as Polygon2D
		var edge := card.get_node("BackEdge") as Polygon2D
		var emblem := card.get_node("Emblem") as Polygon2D
		var face := card.get_node("Face") as Polygon2D
		var mark := card.get_node("Mark") as Polygon2D
		var flip := _ct(card)
		flip.tween_interval(0.25 + (0.15 if idx == 4 else 0.0))
		flip.tween_property(card, "scale:x", -0.08, 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flip.tween_callback(func():
			back.visible = false
			edge.visible = false
			emblem.visible = false
			face.visible = true
			mark.visible = false
			face.color = Props.BLANK)
		flip.tween_property(card, "scale:x", 1.0, 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The audience murmurs: little lean-and-retreats.
	for t: CartoonActor in townsfolk:
		t.set_expression(CartoonActor.Mood.WORRIED)
		var murmur := _ct(t).set_loops(2)
		murmur.tween_property(t, "position:x", t.position.x + 8.0 * _content_scale, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		murmur.tween_property(t, "position:x", t.position.x, 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — THE BLANK REVEAL: every card flips over to NOTHING.
func _on_impact() -> void:
	super._on_impact()
	# The whole table flips: backs spin away, blank faces land.
	for i in range(cards.size()):
		var card := cards[i] as Node2D
		var back := card.get_node("Back") as Polygon2D
		var edge := card.get_node("BackEdge") as Polygon2D
		var emblem := card.get_node("Emblem") as Polygon2D
		var face := card.get_node("Face") as Polygon2D
		var mark := card.get_node("Mark") as Polygon2D
		var flip := _ct(card)
		flip.tween_interval(0.04 * float(i))
		flip.tween_property(card, "scale:x", -0.08, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		flip.tween_callback(func():
			back.visible = false
			edge.visible = false
			emblem.visible = false
			face.visible = true
			mark.visible = false
			face.color = Props.BLANK)
		flip.tween_property(card, "scale:x", 1.0, 0.09) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# A cold empty shimmer across the blanks.
	for card: Node2D in cards:
		var face := card.get_node("Face") as Polygon2D
		var chill := _ct(face)
		chill.tween_interval(0.3)
		chill.tween_property(face, "modulate", Color(0.85, 0.85, 0.95), 0.18) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the town no longer recognizes the "stranger".
## Politely. Firmly. Off the cliff.
func _beat_payoff() -> void:
	var gy := _vp.y * GROUND_FRACTION
	# The escorts take their flanking positions first.
	var left := townsfolk[0] as Node2D
	var right := townsfolk[1] as Node2D
	left.set_expression(CartoonActor.Mood.WORRIED)
	left.set_arm_pose(CartoonActor.ArmPose.REACH)
	right.set_expression(CartoonActor.Mood.WORRIED)
	right.set_arm_pose(CartoonActor.ArmPose.REACH)
	var flank_l := _ct(left)
	flank_l.tween_property(left, "position:x", dribble.position.x - _vp.x * 0.07, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var flank_r := _ct(right)
	flank_r.tween_property(right, "position:x", dribble.position.x + _vp.x * 0.07, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The mayor delivers the regretful wave-off.
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	var bow := _ct(mayor)
	bow.tween_interval(0.25)
	bow.tween_property(mayor, "rotation", 0.18, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bow.tween_property(mayor, "rotation", 0.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# ...and the "stranger" is escorted, briskly but civilly, to the cliff.
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	var walk := _ct(dribble)
	walk.tween_interval(0.3)
	walk.tween_property(dribble, "position:x", _vp.x * 0.62, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	walk.tween_property(dribble, "position:x", _vp.x * 0.92, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	walk.tween_property(dribble, "position:x", _vp.x * 1.2, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	walk.tween_property(dribble, "position",
		Vector2(_vp.x * 1.45, gy + _vp.y * 0.14), 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	walk.parallel().tween_property(dribble, "modulate:a", 0.0, 0.25)
	# The escorts walk him to the edge, then stop — right at the lip.
	var step := [0.5, 0.64]
	var escorts := [left, right]
	for e in range(2):
		var t := escorts[e] as Node2D
		var follow := _ct(t)
		follow.tween_interval(0.3)
		follow.tween_property(t, "position:x", _vp.x * step[e], 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var see_off := _ct(mayor)
	see_off.tween_interval(0.3)
	see_off.tween_property(mayor, "position:x", _vp.x * 0.38, 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The town watches him go, blank-faced like the cards.
	for t: CartoonActor in townsfolk:
		var watch := _ct(t)
		watch.tween_interval(0.75)
		watch.tween_callback(func():
			t.set_expression(CartoonActor.Mood.NEUTRAL)
			t.set_arm_pose(CartoonActor.ArmPose.BRACE))
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)
