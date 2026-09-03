## VegetableBath - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/VegetableBathWinOutro.tscn

extends MicrogameOutroBase

## Vegetable Bath — WIN clip.
## res://scenes/ui/cutscenes/beats/VegetableBathWinOutro.tscn
##
## BEAT 1  The stall counter fills with gleaming, sparkling veggies.
## BEAT 2  (impact on the sign-flip) The stall flips its SOLD OUT sign.
## BEAT 3  The town storms the stall, waving coins overhead.

const Props := preload("res://scripts/cutscenes/beats/VegetableProps.gd")

const VEG_COLORS := [
	Color(1.0, 0.4, 0.2), Color(0.2, 0.7, 0.2), Color(0.8, 0.2, 0.2),
	Color(0.5, 0.3, 0.6), Color(0.9, 0.8, 0.2),
]

var veggies: Array = []
var stall: Node2D
var stall_size: float
var coins: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.CREAM
	# The wooden counter over the default grass.
	var floor_poly := Polygon2D.new()
	floor_poly.name = "Counter"
	floor_poly.polygon = PackedVector2Array([
		Vector2(0.0, _vp.y * GROUND_FRACTION), Vector2(_vp.x, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x, _vp.y), Vector2(0.0, _vp.y),
	])
	floor_poly.color = Props.COUNTER
	floor_poly.z_index = 0
	world.add_child(floor_poly)
	var edge := Line2D.new()
	edge.width = 4.0 * _content_scale
	edge.default_color = Props.COUNTER_EDGE
	var gy := _vp.y * GROUND_FRACTION
	edge.points = PackedVector2Array([Vector2(0.0, gy), Vector2(_vp.x, gy)])
	edge.z_index = 0
	world.add_child(edge)
	# The market stall, ready to stock up.
	stall_size = _vp.y * 0.55
	stall = Props.make_stall(stall_size)
	stall.position = Vector2(_vp.x * 0.80, gy)
	stall.z_index = 1
	world.add_child(stall)
	# Five gleaming veggies, waiting to be laid out on the counter.
	for i in range(5):
		var veg := Props.make_veggie(_vp.y * 0.045, VEG_COLORS[i], false)
		veg.position = stall.position + Vector2(
			(-0.5 + 0.25 * float(i)) * stall_size,
			-stall_size * 0.42)
		veg.z_index = 3
		world.add_child(veg)
		veggies.append(veg)
	_stage_townsfolk(2, _vp.x * 0.06, _vp.x * 0.16)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.94, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.32)
	camera.position = _vp * 0.5

## Impact frame: the hanging sign, mid-flip.
func _impact_point() -> Vector2:
	var sign_root := stall.get_node("Sign") as Node2D
	return sign_root.global_position + Vector2(0.0, stall_size * 0.15)

## BEAT 1 — the gleaming stock goes up on the counter.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# Each veggie pops onto the counter with a shine.
	for i in range(veggies.size()):
		var veg := veggies[i] as Node2D
		var target := veg.position
		veg.position = target + Vector2(0.0, -_vp.y * 0.16)
		veg.scale = Vector2(0.2, 0.2)
		var drop := _ct(veg)
		drop.tween_interval(0.06 * float(i))
		drop.set_parallel(true)
		drop.tween_property(veg, "position", target, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		drop.tween_property(veg, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var gleam := _ct(veg)
		gleam.tween_interval(0.28 + 0.06 * float(i))
		gleam.tween_property(veg, "modulate", Color(1.5, 1.5, 1.35), 0.12)
		gleam.tween_property(veg, "modulate", Color.WHITE, 0.2)
		gleam.tween_property(veg, "modulate", Color(1.35, 1.35, 1.2), 0.12)
		gleam.tween_property(veg, "modulate", Color.WHITE, 0.2)

## BEAT 2 — THE SIGN FLIP: SOLD OUT.
func _on_impact() -> void:
	super._on_impact()
	var sign_root := stall.get_node("Sign") as Node2D
	var board := sign_root.get_node("Board") as Polygon2D
	var sold := sign_root.get_node("SoldText") as Polygon2D
	var sold2 := sign_root.get_node("SoldText2") as Polygon2D
	# The flip: the board spins over and lands with the message out.
	var flip := _ct(board)
	flip.tween_property(board, "scale:x", -0.08, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flip.tween_property(board, "scale:x", 1.0, 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var msg := _ct(sold)
	msg.tween_interval(0.09)
	msg.tween_property(sold, "modulate:a", 1.0, 0.06)
	var msg2 := _ct(sold2)
	msg2.tween_interval(0.12)
	msg2.tween_property(sold2, "modulate:a", 1.0, 0.06)
	# The stock hops with pride.
	for veg: Node2D in veggies:
		var jump := _ct(veg)
		jump.tween_interval(0.10)
		jump.tween_property(veg, "position:y",
			veg.position.y - 8.0 * _content_scale, 0.08)
		jump.tween_property(veg, "position:y", veg.position.y, 0.14)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the town storms the stall, waving coins overhead.
func _beat_payoff() -> void:
	# Coins pop up over every head, bobbing for coins.
	var cast := [dribble, mayor]
	for t in townsfolk:
		cast.append(t)
	for i in range(cast.size()):
		var actor := cast[i] as Node2D
		var coin := Props.make_coin(_vp.y * 0.03)
		coin.position = actor.position + Vector2(
			10.0 * _content_scale, -_vp.y * 0.115)
		coin.z_index = 8
		world.add_child(coin)
		coins.append(coin)
		var bob := _ct(coin).set_loops(3)
		bob.tween_property(coin, "position:y",
			coin.position.y - 7.0 * _content_scale, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(coin, "position:y", coin.position.y, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The whole town rushes the counter.
	var rush_x := [0.62, 0.70, 0.52, 0.58]
	for i in range(cast.size()):
		var actor := cast[i] as Node2D
		var rush := _ct(actor)
		rush.tween_property(actor, "position:x",
			_vp.x * rush_x[i % rush_x.size()], 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for t: CartoonActor in townsfolk:
		t.set_expression(CartoonActor.Mood.HAPPY)
		t.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	dribble.set_expression(CartoonActor.Mood.SMUG)
	dribble.set_arm_pose(CartoonActor.ArmPose.UP)
	# The SOLD OUT sign pulses, sell-out complete.
	var board := (stall.get_node("Sign") as Node2D).get_node("Board") as Polygon2D
	var pulse := _ct(board).set_loops(3)
	pulse.tween_property(board, "modulate", Color(1.4, 1.2, 1.2), 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(board, "modulate", Color.WHITE, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
