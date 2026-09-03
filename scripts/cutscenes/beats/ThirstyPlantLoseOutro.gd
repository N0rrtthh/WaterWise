## ThirstyPlant - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/ThirstyPlantLoseOutro.tscn

extends MicrogameOutroBase

## Thirsty Plant — LOSE clip.
## res://scenes/ui/cutscenes/beats/ThirstyPlantLoseOutro.tscn
##
## BEAT 1  The chosen bucket is tipped to pour.
## BEAT 2  (impact) The WRONG bucket is revealed — it turns red, and
##         the plant wilts in exaggerated slow-motion judgment.
## BEAT 3  The town waters Dribble directly, plants a seed on their
##         head, and nudges them toward the cliff.

const Props := preload("res://scripts/cutscenes/beats/ThirstyPlantProps.gd")

const CLIFF_X := 0.94

var plant: Node2D
var plant_head: Node2D
var chosen: Node2D
var arc: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	var ground := Polygon2D.new()
	ground.name = "Ground"
	ground.polygon = PackedVector2Array([
		Vector2(0.0, _vp.y * GROUND_FRACTION), Vector2(_vp.x, _vp.y * GROUND_FRACTION),
		Vector2(_vp.x, _vp.y), Vector2(0.0, _vp.y),
	])
	ground.color = Props.GROUND
	ground.z_index = 0
	world.add_child(ground)
	_stage_townsfolk(2, _vp.x * 0.30, _vp.x * 0.44)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.58, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.12)
	# The poor plant.
	plant = Props.make_potted_plant(_vp.y * 0.42)
	plant.position = Vector2(_vp.x * 0.68, _vp.y * GROUND_FRACTION)
	plant.z_index = 3
	plant_head = plant.get_node("Head") as Node2D
	plant_head.rotation = 0.30
	world.add_child(plant)
	# The bucket Dribble picked. Looks innocent. Is not.
	chosen = Props.make_bucket(_vp.y * 0.16, Props.BUCKET_BLUE)
	chosen.position = Vector2(_vp.x * 0.20, _vp.y * GROUND_FRACTION)
	chosen.rotation = -1.9
	chosen.z_index = 4
	world.add_child(chosen)
	# Its pour arc, already lashing into the pot.
	arc = Props.make_water_arc(_vp.y * 0.42)
	arc.position = chosen.position + Vector2(0.0, -_vp.y * 0.14)
	arc.rotation = 1.35
	arc.z_index = 5
	world.add_child(arc)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.UP)
	# Dribble tips the bucket proudly; the arc pours.
	var pour := _ct(arc)
	pour.tween_property(arc, "scale:x", 1.0, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.scale = Vector2(0.0, 1.0)
	# The town leans in, hopeful.
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	for i in range(townsfolk.size()):
		var lean := _ct(townsfolk[i]).set_loops(2)
		lean.tween_interval(0.22 * float(i))
		lean.tween_callback(townsfolk[i].hop.bind(5.0, 0.28))
		lean.tween_interval(0.30)

## Impact frame: the reveal on the bucket.
func _impact_point() -> Vector2:
	return chosen.position + Vector2(0.0, -_vp.y * 0.08)

## BEAT 2 — the reveal + the slow-motion wilt ON the tick.
func _on_impact() -> void:
	super._on_impact()
	# The bucket turns RED — the tell everyone missed.
	var body := chosen.get_node("Body") as Polygon2D
	var reveal := _ct(chosen)
	reveal.tween_callback(func() -> void:
		body.color = Props.BUCKET_RED)
	var shudder := _ct(chosen)
	shudder.tween_interval(0.04)
	shudder.tween_property(chosen, "rotation", -2.0, 0.06)
	shudder.tween_property(chosen, "rotation", -1.8, 0.06)
	shudder.tween_property(chosen, "rotation", -1.9, 0.06)
	# A guilty flash at the bucket.
	for i in range(6):
		var flash := Polygon2D.new()
		flash.polygon = Props._ellipse(6.0 * _content_scale, 6.0 * _content_scale, 8)
		flash.position = _impact_point() + Vector2(
			randf_range(-20.0, 20.0) * _content_scale,
			randf_range(-20.0, 20.0) * _content_scale)
		flash.color = Color(1.0, 0.45, 0.4, 0.9)
		flash.z_index = 7
		world.add_child(flash)
		var die := _ct(flash)
		die.tween_property(flash, "modulate:a", 0.0, 0.24)
		die.tween_callback(flash.queue_free)
	# THE SLOW-MOTION WILT: exaggerated, glacial judgment. The head
	# folds all the way over; the leaves sag one after the other.
	var wilt := _ct(plant_head)
	wilt.tween_interval(0.10)
	wilt.tween_property(plant_head, "rotation", 1.35, 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	wilt.parallel().tween_property(plant_head, "scale:y", 0.88, 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for i in range(2):
		var leaf := plant_head.get_child(1 + i) as Polygon2D
		var sag := _ct(leaf)
		sag.tween_interval(0.5 + 0.55 * float(i))
		sag.tween_property(leaf, "rotation", leaf.rotation + 0.7, 0.9) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		sag.parallel().tween_property(leaf, "modulate", Color(0.55, 0.62, 0.4), 0.9)
	# The pour arc dies in shame.
	var dry := _ct(arc)
	dry.tween_interval(0.06)
	dry.tween_property(arc, "scale:x", 0.0, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The town's hope dies with it.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(14.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.PANIC)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the town waters Dribble directly, plants a seed on their
## head, and nudges them toward the cliff.
func _beat_payoff() -> void:
	_hydrate_the_dribble()

func _hydrate_the_dribble() -> void:
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	# The Mayor fetches a spare bucket and stands over Dribble.
	var bucket := Props.make_bucket(_vp.y * 0.14, Props.BUCKET_BLUE)
	bucket.position = _vp * 0.5
	bucket.z_index = 6
	world.add_child(bucket)
	var fetch := _ct()
	fetch.tween_property(bucket, "position",
		dribble.position + Vector2(_vp.x * 0.05, -_vp.y * 0.02), 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# TIP: a water arc dumped straight onto Dribble's head.
	var pour_arc := Props.make_water_arc(_vp.y * 0.16)
	pour_arc.position = dribble.position + Vector2(_vp.x * 0.05, -_vp.y * 0.16)
	pour_arc.rotation = 2.4
	pour_arc.scale = Vector2(0.0, 1.0)
	pour_arc.z_index = 7
	world.add_child(pour_arc)
	var pour := _ct()
	pour.tween_interval(0.32)
	pour.tween_property(pour_arc, "scale:x", 1.0, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pour.parallel().tween_property(bucket, "rotation", bucket.rotation - 0.7, 0.18)
	# Dribble is drenched: a soggy shiver.
	var soak := _ct(dribble)
	soak.tween_interval(0.42)
	soak.tween_callback(func() -> void:
		dribble.set_expression(CartoonActor.Mood.WORRIED)
		dribble.hop(8.0, 0.16))
	soak.tween_property(dribble, "modulate", Color(0.75, 0.85, 1.0), 0.14)
	# THE SEED: a sprout lands on Dribble's head and pops up.
	var seed := Props.make_seed(30.0 * _content_scale)
	seed.position = dribble.position + Vector2(0.0, -_vp.y * 0.145)
	seed.z_index = 7
	world.add_child(seed)
	var sprout_node := seed.get_node("Sprout") as Node2D
	var sprout_in := _ct(sprout_node)
	sprout_in.tween_interval(0.60)
	sprout_in.tween_property(sprout_node, "scale", Vector2(1.0, 1.0), 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# THE NUDGE: the town herds Dribble to the cliff and off it.
	var march := _ct(dribble)
	march.tween_interval(0.95)
	march.tween_property(dribble, "position:x", _vp.x * 0.5, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	march.tween_property(dribble, "position:x", _vp.x * 0.88, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	march.tween_property(dribble, "position:x", _vp.x * CLIFF_X, 0.12)
	# Seed + arc ride along on Dribble's head (they parent-follow).
	var follow_seed := _ct()
	follow_seed.tween_interval(0.95)
	follow_seed.tween_property(seed, "position:x", _vp.x * 0.5, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	follow_seed.tween_property(seed, "position:x", _vp.x * 0.88, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	follow_seed.tween_property(seed, "position:x", _vp.x * CLIFF_X, 0.12)
	# Off the edge: teeter, then drop with the sprout still sprouting.
	var drop := _ct(dribble)
	drop.tween_interval(2.15)
	drop.tween_property(dribble, "rotation", 0.25, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drop.tween_property(dribble, "position",
		Vector2(_vp.x * (CLIFF_X + 0.03), _vp.y * 1.15), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var seed_drop := _ct()
	seed_drop.tween_interval(2.15)
	seed_drop.tween_property(seed, "rotation", 0.25, 0.18)
	seed_drop.tween_property(seed, "position",
		Vector2(_vp.x * (CLIFF_X + 0.03), _vp.y * 1.02), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The herders: gentle push gestures behind Dribble.
	for i in range(townsfolk.size()):
		var herder := townsfolk[i] as CartoonActor
		herder.set_arm_pose(CartoonActor.ArmPose.REACH)
		var push := _ct(herder).set_loops(2)
		push.tween_interval(1.0 + 0.06 * float(i))
		push.tween_property(herder, "position:x",
			herder.position.x + _vp.x * 0.02, 0.18)
		push.tween_property(herder, "position:x",
			herder.position.x - _vp.x * 0.008, 0.22)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)

