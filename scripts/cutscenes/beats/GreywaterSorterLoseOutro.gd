## GreywaterSorter - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/GreywaterSorterLoseOutro.tscn

extends MicrogameOutroBase

## Greywater Sorter — LOSE clip.
## res://scenes/ui/cutscenes/beats/GreywaterSorterLoseOutro.tscn
##
## BEAT 1  MUTANT vegetables pop out of the garden bucket — the grey water
##         went to the garden.
## BEAT 2  (impact) super() punch lands ON the reveal: the mutants let out a
##         cartoon scream (mouths pump, bodies shudder); Dribble and the town
##         recoil.
## BEAT 3  The town has had enough: the catapult flings Dribble into the drain
##         bucket, which tips over the cliff edge with him in it.

const Props := preload("res://scripts/cutscenes/beats/GreywaterSorterProps.gd")

const CLIFF_X := 0.88

var garden_bucket: Node2D
var drain_bucket: Node2D
var fence: Node2D
var catapult: Node2D
var mutants: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.SKY
	_stage_townsfolk(3, _vp.x * 0.58, _vp.x * 0.74)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.66, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.44)
	garden_bucket = Props.make_bucket(Props.GARDEN_GREEN, "Garden", _content_scale * 1.3)
	garden_bucket.position = Vector2(_vp.x * 0.58, _vp.y * GROUND_FRACTION)
	garden_bucket.z_index = 3
	world.add_child(garden_bucket)
	drain_bucket = Props.make_bucket(Props.DRAIN_BROWN, "Drain", _content_scale * 1.3)
	drain_bucket.position = Vector2(_vp.x * CLIFF_X, _vp.y * GROUND_FRACTION)
	drain_bucket.z_index = 3
	world.add_child(drain_bucket)
	var chute := Props.make_chute(_vp.x * 0.18)
	chute.position = Vector2(_vp.x * 0.24, _vp.y * 0.24)
	chute.rotation = 0.5
	chute.z_index = 4
	world.add_child(chute)
	fence = Props.make_fence(_vp.x * 0.26)
	fence.position = Vector2(_vp.x * 0.66, _vp.y * GROUND_FRACTION)
	fence.z_index = 5
	world.add_child(fence)
	catapult = Props.make_catapult(_content_scale * 1.2)
	catapult.position = Vector2(_vp.x * 0.40, _vp.y * GROUND_FRACTION)
	catapult.z_index = 4
	world.add_child(catapult)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()

## Impact frame lands AT the garden bucket's mouth, where the mutants appear.
func _impact_point() -> Vector2:
	return garden_bucket.position + Vector2(0.0, -40.0 * _content_scale)

## BEAT 1 — the reveal. Three mutants pop out of the garden bucket; the
## impact stack lands exactly as they appear.
func _on_impact() -> void:
	super._on_impact()
	var kinds := ["tomato", "carrot", "pumpkin"]
	for i in range(kinds.size()):
		var veg := Props.make_veg(kinds[i], true, _content_scale * 1.9)
		veg.position = garden_bucket.position \
			+ Vector2((float(i) - 1.0) * 28.0 * _content_scale, -6.0 * _content_scale)
		veg.z_index = 4
		veg.scale = Vector2.ONE * 0.01
		world.add_child(veg)
		mutants.append(veg)
		var pop := _ct(veg)
		pop.tween_interval(0.05 * float(i))
		pop.tween_property(veg, "scale", Vector2.ONE * _content_scale * 1.9, 0.20) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## BEAT 2 — the cartoon scream. Each mutant pumps its Mouth child while the
## body shudders; Dribble PANIC, town SHOCKED behind the fence.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.drip_sweat()
	for veg in mutants:
		var mouth := veg.get_node_or_null("Mouth") as Polygon2D
		if mouth != null:
			var scream := _ct(mouth).set_loops(3)
			scream.tween_property(mouth, "scale", Vector2(1.5, 2.4), 0.09) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			scream.tween_property(mouth, "scale", Vector2.ONE, 0.09) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var shudder := _ct(veg as Node2D).set_loops(4)
		shudder.tween_property(veg as Node2D, "position:x", (veg as Node2D).position.x + 3.0 * _content_scale, 0.05)
		shudder.tween_property(veg as Node2D, "position:x", (veg as Node2D).position.x - 3.0 * _content_scale, 0.05)
		shudder.tween_property(veg as Node2D, "position:x", (veg as Node2D).position.x, 0.05)
	# Town recoils.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.05 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(20.0, 0.28))
	# The mayor points at the catapult.
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.hop(16.0, 0.30)
	_fling_dribble()

## BEAT 3 payoff — the catapult flings Dribble into the drain bucket at the
## cliff edge, which tips over the edge with him inside.
func _fling_dribble() -> void:
	# Dribble hops onto the cup, the arm winds back, then SNAPS forward.
	dribble.position = catapult.position + Vector2(0.0, -60.0 * _content_scale)
	var wind := _ct()
	wind.tween_property(catapult.get_node("Arm"), "rotation", 0.9, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	wind.parallel().tween_property(catapult.get_node("Cup"), "rotation", 0.9, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	wind.tween_property(catapult.get_node("Arm"), "rotation", -0.95, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wind.parallel().tween_property(catapult.get_node("Cup"), "rotation", -0.95, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Deferred impact pieces at the fling (non-tick frame).
	wind.tween_callback(_camera_punch)
	wind.tween_callback(_impact_flash)
	wind.tween_callback(_play_stinger)
	# Parabolic flight into the drain bucket.
	var start := dribble.position
	var target := drain_bucket.position + Vector2(0.0, -42.0 * _content_scale)
	var flight := _ct()
	flight.tween_method(
		func(t: float) -> void:
			var pos := start.lerp(target, t)
			pos.y -= sin(t * PI) * _vp.y * 0.30
			dribble.position = pos,
		0.0, 1.0, 0.42
	)
	flight.parallel().tween_property(dribble, "rotation", TAU * 1.5, 0.42)
	flight.tween_callback(_bucket_tips)

func _bucket_tips() -> void:
	_spawn_burst(drain_bucket.position + Vector2(0.0, -40.0 * _content_scale), false)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	# Squash on landing, then tip over the edge — bucket and Dribble share the
	# same deltas (multi-node, same-delta pattern).
	var squash := _ct(drain_bucket)
	squash.tween_property(drain_bucket, "scale", Vector2(1.15, 0.85) * _content_scale * 1.3, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	squash.tween_property(drain_bucket, "scale", Vector2.ONE * _content_scale * 1.3, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tip := _ct(drain_bucket)
	tip.tween_interval(0.10)
	tip.tween_property(drain_bucket, "rotation", 1.5, 0.40) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tip.parallel().tween_property(drain_bucket, "position",
		drain_bucket.position + Vector2(_vp.x * 0.10, _vp.y * 0.24), 0.40) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var dribble_tip := _ct(dribble)
	dribble_tip.tween_interval(0.10)
	dribble_tip.tween_property(dribble, "rotation", 2.2, 0.40) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dribble_tip.parallel().tween_property(dribble, "position",
		drain_bucket.position + Vector2(_vp.x * 0.10, _vp.y * 0.24) + Vector2(0.0, -20.0 * _content_scale), 0.40) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The town waves goodbye, deadpan.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.30 + 0.07 * float(i))
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.CHEER))
		tw.tween_callback(townsfolk[i].hop.bind(12.0, 0.24))
	mayor.set_expression(CartoonActor.Mood.SMUG)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)

