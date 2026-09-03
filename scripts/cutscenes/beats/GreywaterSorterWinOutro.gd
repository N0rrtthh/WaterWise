## GreywaterSorter - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/GreywaterSorterWinOutro.tscn

extends MicrogameOutroBase

## Greywater Sorter — WIN clip.
## res://scenes/ui/cutscenes/beats/GreywaterSorterWinOutro.tscn
##
## BEAT 1  Perfectly sorted yard; Dribble proud between the two labeled
##         buckets, the town lined up at the fence.
## BEAT 2  (impact) super() punch + confetti AT the garden bucket as it
##         ERUPTS with oversized prize-winning vegetables.
## BEAT 3  The drain bucket gives a cheerful thumbs-up and a happy bounce;
##         the whole town cheers over the fence.

const Props := preload("res://scripts/cutscenes/beats/GreywaterSorterProps.gd")

var garden_bucket: Node2D
var drain_bucket: Node2D
var fence: Node2D
var veg_row: Array = []
var thumb: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.SKY
	_stage_townsfolk(3, _vp.x * 0.62, _vp.x * 0.84)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.74, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.36)
	garden_bucket = Props.make_bucket(Props.GARDEN_GREEN, "Garden", _content_scale * 1.3)
	garden_bucket.position = Vector2(_vp.x * 0.24, _vp.y * GROUND_FRACTION)
	garden_bucket.z_index = 3
	world.add_child(garden_bucket)
	drain_bucket = Props.make_bucket(Props.DRAIN_BROWN, "Drain", _content_scale * 1.3)
	drain_bucket.position = Vector2(_vp.x * 0.46, _vp.y * GROUND_FRACTION)
	drain_bucket.z_index = 3
	world.add_child(drain_bucket)
	var chute := Props.make_chute(_vp.x * 0.18)
	chute.position = Vector2(_vp.x * 0.28, _vp.y * 0.24)
	chute.rotation = 0.5
	chute.z_index = 4
	world.add_child(chute)
	fence = Props.make_fence(_vp.x * 0.34)
	fence.position = Vector2(_vp.x * 0.74, _vp.y * GROUND_FRACTION)
	fence.z_index = 5
	world.add_child(fence)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()

## Impact frame lands AT the garden bucket's mouth.
func _impact_point() -> Vector2:
	return garden_bucket.position + Vector2(0.0, -46.0 * _content_scale)

## BEAT 2 — eruption. Full impact stack at the garden bucket while three
## prize vegetables pop out of it, staggered, oversized.
func _on_impact() -> void:
	super._on_impact()
	var kinds := ["carrot", "tomato", "pumpkin"]
	for i in range(kinds.size()):
		var veg := Props.make_veg(kinds[i], false, _content_scale * 2.4)
		veg.position = garden_bucket.position \
			+ Vector2((float(i) - 1.0) * 30.0 * _content_scale, -6.0 * _content_scale)
		veg.z_index = 4
		veg.scale = Vector2.ONE * 0.01
		world.add_child(veg)
		veg_row.append(veg)
		var pop := _ct(veg)
		pop.tween_interval(0.07 * float(i))
		pop.tween_property(veg, "scale", Vector2.ONE * _content_scale * 2.4, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# super._on_impact() already burst at _impact_point(); a second one at the same
	# point was 84 particles stacked on one spot, not a second accent. The offset
	# burst below is the accent and stays.
	_spawn_burst(_impact_point() + Vector2(26.0 * _content_scale, -30.0 * _content_scale), false)

## BEAT 3 — the drain bucket gives a cheerful thumbs-up: the thumb pops up
## from behind the rim, the bucket bounce-tilts, the town cheers.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_expression(CartoonActor.Mood.SMUG)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)
	thumb = Props.make_thumb(_content_scale * 1.4)
	thumb.position = drain_bucket.position + Vector2(0.0, -34.0 * _content_scale)
	thumb.z_index = 2  # behind the bucket body so it grows out of the rim
	thumb.scale.y = 0.01
	world.add_child(thumb)
	var up := _ct(thumb)
	up.tween_property(thumb, "scale:y", _content_scale * 1.4, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Bucket bounce + tilt of approval.
	var bounce := _ct(drain_bucket)
	bounce.tween_property(drain_bucket, "scale", Vector2(1.1, 0.9) * _content_scale * 1.3, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(drain_bucket, "scale", Vector2.ONE * _content_scale * 1.3, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bounce.parallel().tween_property(drain_bucket, "rotation", 0.12, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bounce.tween_property(drain_bucket, "rotation", 0.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Waving thumb.
	var wag := _ct(thumb)
	wag.tween_property(thumb, "rotation", 0.14, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wag.tween_property(thumb, "rotation", -0.06, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wag.tween_property(thumb, "rotation", 0.0, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Town + mayor cheer over the fence.
	for i in range(townsfolk.size()):
		var hop := _ct()
		hop.tween_interval(0.07 * float(i))
		hop.tween_callback(townsfolk[i].hop.bind(24.0, 0.30))
	mayor.hop(18.0, 0.30)
	# Veg row does a proud wobble.
	for i in range(veg_row.size()):
		if not is_instance_valid(veg_row[i]):
			continue
		var wob := _ct(veg_row[i] as Node2D)
		wob.tween_interval(0.05 * float(i))
		wob.tween_property(veg_row[i] as Node2D, "rotation", 0.08, 0.10) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wob.tween_property(veg_row[i] as Node2D, "rotation", 0.0, 0.10) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
