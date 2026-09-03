## BucketBrigade - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/BucketBrigadeLoseOutro.tscn

extends MicrogameOutroBase

## Bucket Brigade — LOSE outro.
## res://scenes/ui/cutscenes/beats/BucketBrigadeLoseOutro.tscn
##
## BEAT 1  Dribble (PANIC) lobs the last bucket — the lob lasts exactly one
##         beat so the bucket ARRIVES on the impact tick.
## BEAT 2  CRACK over Mayor Ripple's head, exactly on the impact frame:
##         camera punch + white flash + water splash + stinger + flying rim
##         shards. The mayor goes DIZZY with spin_stars.
## BEAT 3  The deadpan brigade hurls Dribble — and the empty bucket — off
##         screen toward the cliff. Tone: chirpy slapstick, never cruel.
## SNAP:   whip-pan.

const Props := preload("res://scripts/cutscenes/beats/BucketBrigadeProps.gd")

var _flying_bucket: Node2D

func _setup_stage() -> void:
	_make_cliff()
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.66, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	_stage_townsfolk(4, _vp.x * 0.08, _vp.x * 0.36)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.48)
	# Dribble carries the last bucket until the lob.
	var held := Props.make_bucket()
	held.name = "HeldBucket"
	held.position = Vector2(-26.0, -14.0)
	dribble.prop_slot.add_child(held)
	_flying_bucket = Props.make_bucket()
	_flying_bucket.name = "FlyingBucket"
	world.add_child(_flying_bucket)
	_flying_bucket.visible = false
	_flying_bucket.scale = Vector2.ONE * _content_scale * 1.25
	_flying_bucket.z_index = 10

## Side-view cliff at the right edge: a dark vertical face the crowd will
## hurl Dribble toward. Pure background (z -3).
func _make_cliff() -> void:
	var ground_y := _vp.y * GROUND_FRACTION
	var face := Polygon2D.new()
	face.name = "CliffFace"
	face.polygon = PackedVector2Array([
		Vector2(_vp.x * 0.86, ground_y + 4.0 * _content_scale),
		Vector2(_vp.x, ground_y + 4.0 * _content_scale),
		Vector2(_vp.x, _vp.y),
		Vector2(_vp.x * 0.86, _vp.y),
	])
	face.color = Color(0.3, 0.4, 0.3)
	face.z_index = -3
	world.add_child(face)
	var lip := Line2D.new()
	lip.name = "CliffLip"
	lip.points = PackedVector2Array([
		Vector2(_vp.x * 0.86, ground_y + 4.0 * _content_scale),
		Vector2(_vp.x, ground_y + 4.0 * _content_scale),
	])
	lip.width = 3.0 * _content_scale
	lip.default_color = Color(0.22, 0.3, 0.22)
	lip.z_index = -3
	world.add_child(lip)

## BEAT 1 — the lob. Duration == _setup_sec() so arrival lands ON beat 2.
func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.start_blinking()
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.drip_sweat()
	_lob_bucket()

func _lob_bucket() -> void:
	var held := dribble.prop_slot.get_node_or_null("HeldBucket")
	if held:
		held.visible = false
	_flying_bucket.visible = true
	_flying_bucket.rotation = 0.0
	_flying_bucket.position = dribble.position + Vector2(0.0, -70.0 * _content_scale)
	var target := mayor.position + Vector2(0.0, -104.0 * _content_scale)
	var apex := (dribble.position + target) * 0.5 + Vector2(0.0, -90.0 * _content_scale)
	var dur := _setup_sec()
	var t := _ct()
	t.tween_property(_flying_bucket, "position", apex, dur * 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_flying_bucket, "position", target, dur * 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_flying_bucket, "rotation", TAU * 1.5, dur)

## The default impact helpers aim at _impact_point(); for this clip that is
## the mayor's head, not above Dribble.
func _impact_point() -> Vector2:
	return mayor.position + Vector2(0.0, -104.0 * _content_scale)

## BEAT 2 — CRACK. super() gives punch + flash + splash stinger burst aimed
## at the mayor's head; we add the bucket shatter and the dazed reaction.
func _on_impact() -> void:
	super._on_impact()
	_flying_bucket.visible = false
	_crack_bucket()
	mayor.set_expression(CartoonActor.Mood.DIZZY)
	mayor.spin_stars(1.1)
	mayor.squash(0.55, 0.24)

## Two rim halves spinning apart, fading as they fly.
func _crack_bucket() -> void:
	for side in [-1.0, 1.0]:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(0, -10), Vector2(24 * side, -14), Vector2(18 * side, 4), Vector2(0, 6),
		])
		shard.color = Props.WOOD
		shard.position = _impact_point()
		shard.z_index = 12
		world.add_child(shard)
		var dir := Vector2(side * 150.0, -120.0) * _content_scale
		var t := _ct().set_parallel(true)
		t.tween_property(shard, "position", shard.position + dir, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(shard, "rotation", side * TAU, 0.5)
		t.tween_property(shard, "modulate:a", 0.0, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## BEAT 3 — deadpan line, then the hurl.
func _beat_payoff() -> void:
	for i in range(townsfolk.size()):
		townsfolk[i].set_expression(CartoonActor.Mood.SMUG)
		var tw := _ct()
		tw.tween_interval(0.1 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(26.0, 0.3))
	mayor.shake(4.0, 0.5)
	_hurl_dribble()

func _hurl_dribble() -> void:
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	dribble.set_arm_pose(CartoonActor.ArmPose.DROOP)
	var ground_y := _vp.y * GROUND_FRACTION
	var off := Vector2(_vp.x + 260.0, ground_y - 30.0 * _content_scale)
	var t := _ct()
	t.tween_property(
		dribble, "position",
		dribble.position + Vector2(70.0 * _content_scale, -110.0 * _content_scale),
		0.28
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(dribble, "position", off, 0.42) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(dribble, "rotation", TAU * 2.0, 0.42)
	# The empty bucket follows a beat behind, spinning toward the cliff.
	var bucket := Props.make_bucket(false)
	bucket.name = "ThrownBucket"
	bucket.scale = Vector2.ONE * _content_scale * 1.25
	bucket.z_index = 10
	bucket.position = dribble.position + Vector2(0.0, -40.0 * _content_scale)
	world.add_child(bucket)
	var bt := _ct()
	bt.tween_interval(0.12)
	bt.tween_property(bucket, "position", off + Vector2(-60.0, -60.0 * _content_scale), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	bt.parallel().tween_property(bucket, "rotation", TAU * 2.5, 0.5)

