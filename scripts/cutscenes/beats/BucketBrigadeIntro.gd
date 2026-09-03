## BucketBrigade - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/BucketBrigadeIntro.tscn

extends MicrogameIntroBase

## Bucket Brigade — CAUSE clip.
## res://scenes/ui/cutscenes/beats/BucketBrigadeIntro.tscn
##
## BEAT 1  The camera pans down onto a wilting garden patch while Mayor
##         Ripple gestures urgently at the dry soil; the brigade stands ready.
## BEAT 2  (flash-only impact) The mayor points down the line; Dribble clocks
##         the dead garden — the "uh oh" that explains the round.
## BEAT 3  The hand-off: the first bucket arcs from the mayor into Dribble's
##         hands, who hops, ready. SNAP: whip-pan straight into gameplay.

const Props := preload("res://scripts/cutscenes/beats/BucketBrigadeProps.gd")

func _setup_stage() -> void:
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.34, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	_stage_townsfolk(4, _vp.x * 0.48, _vp.x * 0.66)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.84)
	_make_garden()
	# Beat 1 starts high and tight, then pans down onto the patch.
	camera.zoom = Vector2(1.22, 1.22)
	camera.position = _vp * 0.5 + Vector2(-40.0, -150.0) * _content_scale

## The wilting patch: dark dry mound, three droopy desaturated stems and
## cracked-soil accents. All background (z -2), behind the cast.
func _make_garden() -> void:
	var ground_y := _vp.y * GROUND_FRACTION
	var patch := Polygon2D.new()
	patch.name = "GardenPatch"
	patch.polygon = PackedVector2Array([
		Vector2(_vp.x * 0.26, ground_y + 4.0 * _content_scale),
		Vector2(_vp.x * 0.46, ground_y + 4.0 * _content_scale),
		Vector2(_vp.x * 0.44, ground_y + 34.0 * _content_scale),
		Vector2(_vp.x * 0.28, ground_y + 34.0 * _content_scale),
	])
	patch.color = Color(0.36, 0.27, 0.18)
	patch.z_index = -2
	world.add_child(patch)

	var wilt := Color(0.42, 0.52, 0.30)
	for i in range(3):
		var stem := Polygon2D.new()
		stem.name = "WiltedPlant%d" % (i + 1)
		var base_x := _vp.x * (0.30 + 0.06 * float(i))
		var h := 46.0 * _content_scale
		stem.polygon = PackedVector2Array([
			Vector2(base_x - 3.0, ground_y + 2.0),
			Vector2(base_x + 3.0, ground_y + 2.0),
			Vector2(base_x + 16.0, ground_y - h),
			Vector2(base_x + 9.0, ground_y - h * 0.9),
		])
		stem.color = wilt
		stem.z_index = -2
		world.add_child(stem)

	for i in range(4):
		var crack := Line2D.new()
		crack.name = "SoilCrack%d" % (i + 1)
		var cx := _vp.x * (0.29 + 0.045 * float(i))
		var cy := ground_y + (8.0 + 6.0 * float(i % 2)) * _content_scale
		crack.points = PackedVector2Array([
			Vector2(cx, cy), Vector2(cx + 9.0, cy + 5.0), Vector2(cx + 20.0, cy + 3.0),
		])
		crack.width = 2.0 * _content_scale
		crack.default_color = Color(0.2, 0.14, 0.1)
		crack.z_index = -2
		world.add_child(crack)

## BEAT 1 — urgent gestures + ready brigade + pan-down onto the patch.
func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.drip_sweat()
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
		t.start_idle()
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	var pan := _ct().set_parallel(true)
	pan.tween_property(camera, "position", _vp * 0.5, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan.tween_property(camera, "zoom", Vector2.ONE, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## BEAT 2 — the situation becomes clear. Intro contract: flash only, no punch,
## no burst, no stinger.
func _on_impact() -> void:
	_impact_flash()
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	dribble.drip_sweat()

## BEAT 3 — the hand-off: the first bucket arcs from mayor to Dribble.
func _beat_payoff() -> void:
	var bucket := Props.make_bucket()
	bucket.name = "HandoffBucket"
	world.add_child(bucket)
	bucket.scale = Vector2.ONE * _content_scale * 1.25
	bucket.position = mayor.position + Vector2(46.0, -60.0) * _content_scale
	var to := dribble.position + Vector2(6.0, -48.0) * _content_scale
	var t := _ct()
	t.tween_property(
		bucket, "position",
		(bucket.position + to) * 0.5 + Vector2(0.0, -60.0 * _content_scale),
		0.22
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(bucket, "position", to, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_bucket_caught.bind(bucket))
	# The brigade signals "ready" behind the hand-off.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.08 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(30.0, 0.28))

func _bucket_caught(bucket: Node2D) -> void:
	bucket.queue_free()
	var held := Props.make_bucket()
	held.name = "HeldBucket"
	held.position = Vector2(26.0, -14.0)
	dribble.prop_slot.add_child(held)
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	dribble.hop(44.0, 0.3)
