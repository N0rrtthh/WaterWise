## GreywaterSorter - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/GreywaterSorterIntro.tscn

extends MicrogameIntroBase

## Greywater Sorter — CAUSE clip.
## res://scenes/ui/cutscenes/beats/GreywaterSorterIntro.tscn
##
## BEAT 1  The chute drops its first blob — clean water — straight into the
##         labeled garden bucket; the town watches over the fence.
## BEAT 2  (flash-only impact) A GREY blob drops and splats on the ground
##         between the buckets — sorting just got hard.
## BEAT 3  More blobs queue at the spout; Dribble panic-shuffles between the
##         buckets while the mayor leans over the fence. SNAP into gameplay.

const Props := preload("res://scripts/cutscenes/beats/GreywaterSorterProps.gd")

const CLIFF_EDGE_X := 0.88

var chute: Node2D
var spout: Vector2
var garden_bucket: Node2D
var drain_bucket: Node2D
var fence: Node2D
var queued: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.SKY
	_stage_townsfolk(3, _vp.x * 0.62, _vp.x * 0.84)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.72, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.34)
	garden_bucket = Props.make_bucket(Props.GARDEN_GREEN, "Garden", _content_scale * 1.3)
	garden_bucket.position = Vector2(_vp.x * 0.24, _vp.y * GROUND_FRACTION)
	garden_bucket.z_index = 3
	world.add_child(garden_bucket)
	drain_bucket = Props.make_bucket(Props.DRAIN_BROWN, "Drain", _content_scale * 1.3)
	drain_bucket.position = Vector2(_vp.x * 0.46, _vp.y * GROUND_FRACTION)
	drain_bucket.z_index = 3
	world.add_child(drain_bucket)
	chute = Props.make_chute(_vp.x * 0.18)
	chute.position = Vector2(_vp.x * 0.28, _vp.y * 0.24)
	chute.rotation = 0.5
	chute.z_index = 4
	world.add_child(chute)
	spout = chute.position + Vector2(
		_vp.x * 0.09 * cos(chute.rotation),
		_vp.x * 0.09 * sin(chute.rotation)
	)
	fence = Props.make_fence(_vp.x * 0.34)
	fence.position = Vector2(_vp.x * 0.74, _vp.y * GROUND_FRACTION)
	fence.z_index = 5
	world.add_child(fence)
	# Open tight on the chute mouth, then settle wide.
	camera.zoom = Vector2(1.35, 1.35)
	camera.position = spout + Vector2(0.0, -30.0)

## BEAT 1 — first drop: a clean blob arcs from the spout and plops into the
## garden bucket, which squashes happily. The camera settles wide.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	var pan := _ct().set_parallel(true)
	pan.tween_property(camera, "position", _vp * 0.5, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan.tween_property(camera, "zoom", Vector2.ONE, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drop_blob("clean", garden_bucket.position.x, true, 0.0)

## Spawn a blob at the spout and drop it to `target_x`. Into a bucket it
## plops inside (bucket squash); onto the ground it splats flat.
func _drop_blob(kind: String, target_x: float, into_bucket: bool, delay: float) -> void:
	var blob := Props.make_blob(kind, _content_scale)
	blob.position = spout
	blob.z_index = 12
	world.add_child(blob)
	var land_y := _vp.y * GROUND_FRACTION \
		- (40.0 if into_bucket else 2.0) * _content_scale
	var fall := _ct(blob)
	fall.tween_interval(delay)
	fall.tween_property(blob, "position", Vector2(target_x, land_y), 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(blob, "scale", blob.scale * 0.8, 0.26)
	fall.tween_callback(_blob_lands.bind(blob, into_bucket))

func _blob_lands(blob: Node2D, into_bucket: bool) -> void:
	if into_bucket:
		var squash := _ct(blob)
		squash.tween_property(blob, "scale:y", 0.15, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		squash.tween_property(blob, "modulate:a", 0.0, 0.10)
		squash.tween_callback(blob.queue_free)
	else:
		var splat := _ct(blob)
		splat.tween_property(blob, "scale", Vector2(2.2, 0.25) * _content_scale, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		splat.tween_property(blob, "modulate:a", 0.0, 0.14)
		splat.tween_callback(blob.queue_free)

## BEAT 2 — the situation becomes clear. Intro contract: flash only, no punch,
## no burst, no stinger. A GREY blob misses everything and splats on the dirt.
func _on_impact() -> void:
	_impact_flash()
	_drop_blob("grey", _vp.x * 0.40, false, 0.0)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.drip_sweat()
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.06 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(18.0, 0.26))

## BEAT 3 — two more blobs queue at the spout, wobbling; Dribble
## panic-shuffles between the buckets; the mayor leans over the fence.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	# Queued blobs teeter at the spout mouth.
	for i in range(2):
		var blob := Props.make_blob("grey" if i == 1 else "clean", _content_scale)
		blob.position = spout + Vector2(
			-14.0 * _content_scale * float(i + 1) * cos(chute.rotation),
			-14.0 * _content_scale * float(i + 1) * sin(chute.rotation)
		)
		blob.z_index = 12
		world.add_child(blob)
		queued.append(blob)
		var teeter := _ct(blob).set_loops()
		teeter.tween_property(blob, "rotation", 0.12, 0.11) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		teeter.tween_property(blob, "rotation", -0.12, 0.11) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Dribble shuffles bucket to bucket.
	var shuffle := _ct()
	shuffle.tween_property(dribble, "position:x", garden_bucket.position.x, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shuffle.tween_property(dribble, "position:x", drain_bucket.position.x, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shuffle.tween_property(dribble, "position:x", _vp.x * 0.36, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The mayor hops at the fence, pointing.
	var lean := _ct()
	lean.tween_property(mayor, "rotation", -0.18, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lean.tween_property(mayor, "rotation", 0.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.hop(20.0, 0.30)

