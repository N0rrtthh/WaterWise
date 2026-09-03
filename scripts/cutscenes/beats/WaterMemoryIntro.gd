## WaterMemory - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/WaterMemoryIntro.tscn

extends MicrogameIntroBase

## Water Memory — CAUSE clip.
## res://scenes/ui/cutscenes/beats/WaterMemoryIntro.tscn
##
## BEAT 1  Face-down memory cards wait on the table under deep-blue
##         light; the town crowds in like a game-show audience.
## BEAT 2  (flash impact) The cards SHIVER in sequence, emblems flaring —
##         the host raises the game.
## BEAT 3  Dribble steps up to the table as the town leans in.

const Props := preload("res://scripts/cutscenes/beats/WaterMemoryProps.gd")

var cards: Array = []
var table: Node2D
var card_w: float

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	var gy := _vp.y * GROUND_FRACTION
	# The card table, front and centre.
	table = Node2D.new()
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
	# Six face-down cards in a 3x2 grid on the tabletop.
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
	# The game-show audience packs the floor.
	_stage_townsfolk(3, _vp.x * 0.03, _vp.x * 0.13)
	# The host, miked up beside the table.
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.86, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.32)
	camera.position = _vp * 0.5

## BEAT 1 — cards idle-shuffle; the audience buzzes; the host gestures.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	for t in townsfolk:
		t.start_idle()
	# Each card does a slow nervous shuffle in place.
	for i in range(cards.size()):
		var card := cards[i] as Node2D
		var base := -3.0 if i % 2 == 0 else 3.0
		card.rotation_degrees = base
		var wobble := _ct(card).set_loops(3)
		wobble.tween_property(card, "rotation_degrees", -base, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wobble.tween_property(card, "rotation_degrees", base, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The host hypes the crowd with a little bounce.
	var hype := _ct(mayor).set_loops(2)
	hype.tween_property(mayor, "scale", Vector2(1.03, 1.03), 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hype.tween_property(mayor, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — the cards shiver in sequence; the host raises the stakes.
func _on_impact() -> void:
	_impact_flash()
	for i in range(cards.size()):
		var card := cards[i] as Node2D
		var emblem := card.get_node("Emblem") as Polygon2D
		var flare := _ct(emblem)
		flare.tween_interval(0.03 * float(i))
		flare.tween_property(emblem, "modulate", Color(1.8, 1.8, 1.5), 0.06)
		flare.tween_property(emblem, "modulate",
			Color(1.0, 1.0, 1.0, 0.9), 0.15)
		var shiver := _ct(card)
		shiver.tween_interval(0.03 * float(i))
		shiver.tween_property(card, "position:y",
			card.position.y - 5.0 * _content_scale, 0.05)
		shiver.tween_property(card, "position:y", card.position.y, 0.07)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — Dribble steps up to the table; the town leans in.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	var step := _ct(dribble)
	step.tween_property(dribble, "position:x", _vp.x * 0.38, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The first card lifts, inviting the pick.
	var pick := cards[4] as Node2D
	var lift := _ct(pick)
	lift.tween_interval(0.2)
	lift.tween_property(pick, "position:y", pick.position.y - card_w * 0.5, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lift.tween_property(pick, "rotation_degrees", 0.0, 0.1)
	# The audience leans toward the table.
	var lean_x := [0.2, 0.26, 0.14]
	for i in range(townsfolk.size()):
		var t := townsfolk[i] as Node2D
		var lean := _ct(t)
		lean.tween_property(t, "position:x", _vp.x * lean_x[i % lean_x.size()], 0.26) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
