## VegetableBath - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/VegetableBathIntro.tscn

extends MicrogameIntroBase

## Vegetable Bath — CAUSE clip.
## res://scenes/ui/cutscenes/beats/VegetableBathIntro.tscn
##
## BEAT 1  Muddy veggies pile in the dirty basket beside a filled wash
##         basin and an empty clean crate; the empty market stall waits
##         behind them while the first customers shuffle in.
## BEAT 2  (flash-only impact) The dirt spots FLARE on every veggie —
##         filthy beyond salvation. The queue freezes.
## BEAT 3  Dribble marches to the basin and the veggies line up.

const Props := preload("res://scripts/cutscenes/beats/VegetableProps.gd")

const VEG_COLORS := [
	Color(1.0, 0.4, 0.2), Color(0.2, 0.7, 0.2), Color(0.8, 0.2, 0.2),
	Color(0.5, 0.3, 0.6), Color(0.9, 0.8, 0.2),
]

var veggies: Array = []
var basket: Node2D
var basin: Node2D
var crate: Node2D
var stall: Node2D
var veg_size: float

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
	edge.name = "CounterEdge"
	edge.width = 4.0 * _content_scale
	edge.default_color = Props.COUNTER_EDGE
	var gy := _vp.y * GROUND_FRACTION
	edge.points = PackedVector2Array([Vector2(0.0, gy), Vector2(_vp.x, gy)])
	edge.z_index = 0
	world.add_child(edge)
	veg_size = _vp.y * 0.05
	# The stations, left to right: dirty basket, wash basin, empty
	# clean crate, and the empty market stall waiting behind them.
	basket = Props.make_basket(_vp.y * 0.2, Props.WOOD)
	basket.position = Vector2(_vp.x * 0.28, gy)
	basket.z_index = 2
	world.add_child(basket)
	basin = Props.make_basin(_vp.y * 0.24)
	basin.position = Vector2(_vp.x * 0.47, gy)
	basin.z_index = 2
	world.add_child(basin)
	crate = Props.make_basket(_vp.y * 0.2, Props.BASKET_CLEAN)
	crate.position = Vector2(_vp.x * 0.65, gy)
	crate.z_index = 2
	world.add_child(crate)
	stall = Props.make_stall(_vp.y * 0.55)
	stall.position = Vector2(_vp.x * 0.84, gy)
	stall.z_index = 1
	world.add_child(stall)
	# The muddy pile, heaped in the dirty basket.
	var heap := [Vector2(-0.35, -0.5), Vector2(0.3, -0.55),
		Vector2(-0.05, -0.75), Vector2(0.1, -0.35)]
	for i in range(4):
		var veg := Props.make_veggie(veg_size, VEG_COLORS[i], true)
		veg.position = basket.position + heap[i] * _vp.y * 0.2
		veg.z_index = 3
		world.add_child(veg)
		veggies.append(veg)
	_stage_townsfolk(2, _vp.x * 0.03, _vp.x * 0.09)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.95, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.14)
	camera.position = _vp * 0.5

## BEAT 1 — the muddy pile waits; the basin ripples; the stall looms.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	for t in townsfolk:
		t.start_idle()
	# The veggies wobble in the basket, hopeless.
	for i in range(veggies.size()):
		var veg := veggies[i] as Node2D
		veg.rotation_degrees = -8.0 if i % 2 == 0 else 8.0
		var wobble := _ct(veg).set_loops(3)
		wobble.tween_property(veg, "rotation_degrees",
			8.0 if i % 2 == 0 else -8.0, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wobble.tween_property(veg, "rotation_degrees", veg.rotation_degrees, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The basin water ripples invitingly.
	var water := basin.get_node("Water") as Polygon2D
	var ripple := _ct(water).set_loops(3)
	ripple.tween_property(water, "scale:x", 1.06, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ripple.tween_property(water, "scale:x", 1.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The mayor peers into the empty stall.
	var peer := _ct(mayor)
	peer.tween_property(mayor, "rotation", 0.14, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	peer.tween_interval(0.2)
	peer.tween_property(mayor, "rotation", 0.0, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — the dirt flares. Flash only; the queue freezes.
func _on_impact() -> void:
	_impact_flash()
	for veg: Node2D in veggies:
		var dirt := veg.get_node("Dirt") as Node2D
		var flare := _ct(dirt)
		flare.tween_property(dirt, "modulate", Color(2.0, 1.7, 1.0), 0.07)
		flare.tween_property(dirt, "modulate", Color.WHITE, 0.16)
		var shake := _ct(veg)
		shake.tween_property(veg, "position:x",
			veg.position.x + 5.0 * _content_scale, 0.045)
		shake.tween_property(veg, "position:x",
			veg.position.x - 5.0 * _content_scale, 0.045)
		shake.tween_property(veg, "position:x", veg.position.x, 0.05)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — Dribble marches to the basin; the veggies line up.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	var march := _ct(dribble)
	march.tween_property(dribble, "position:x", _vp.x * 0.38, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The veggies queue up along the basket rim, ready for the bath.
	for i in range(veggies.size()):
		var veg := veggies[i] as Node2D
		var line_up := _ct(veg)
		line_up.tween_interval(0.05 * float(i))
		line_up.tween_property(veg, "position",
			basket.position + Vector2(_vp.y * 0.18,
				-_vp.y * 0.06 - _vp.y * 0.055 * float(i)), 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		line_up.parallel().tween_property(veg, "rotation_degrees", 0.0, 0.25)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
