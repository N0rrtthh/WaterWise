## TracePipePath - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/TracePipePathLoseOutro.tscn

extends MicrogameOutroBase

## Trace Pipe Path - LOSE clip.
## res://scenes/ui/cutscenes/beats/TracePipePathLoseOutro.tscn
##
## BEAT 1  The pipe springs a leak, sprays jetting from its joints;
##         Dribble eyes it nervously; two spare segments wait nearby.
## BEAT 2  (impact on the blowout) The pipe DETONATES - a shock ring and
##         shrapnel blast out, and the shockwave hurls Dribble sky-high.
## BEAT 3  Dribble hangs at the apex, then drops out of the world with
##         the burst still raining down; the town ducks for cover.

const Props := preload("res://scripts/cutscenes/beats/TracePipeProps.gd")

var sprays: Array = []
var spare_pipes: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.SITE
	var ground_y := _vp.y * GROUND_FRACTION
	var pipe_size := _vp.y * 0.28
	var pipe := Props.make_pipe_segment(pipe_size, true)
	pipe.position = Vector2(_vp.x * 0.26, ground_y - pipe_size * 0.11)
	pipe.rotation = 0.06
	pipe.z_index = 2
	world.add_child(pipe)
	for i in range(2):
		var spray := Props.make_spray(_vp.y * 0.22)
		spray.position = Vector2(
			pipe.position.x + (float(i) * 2.0 - 1.0) * pipe_size * 0.36,
			pipe.position.y - pipe_size * 0.14
		)
		spray.rotation = -1.2 + 1.4 * float(i)
		spray.z_index = 3
		world.add_child(spray)
		sprays.append(spray)
	for i in range(2):
		var spare := Props.make_pipe_segment(_vp.y * 0.30, false)
		spare.position = Vector2(
			_vp.x * (0.78 + 0.05 * float(i)), ground_y - _vp.y * 0.03)
		spare.rotation = 0.9 - 1.8 * float(i)
		spare.z_index = 2
		world.add_child(spare)
		spare_pipes.append(spare)
	_stage_townsfolk(2, _vp.x * 0.58, _vp.x * 0.66)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.86, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.50)
	camera.position = _vp * 0.5

func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.26, _vp.y * GROUND_FRACTION - _vp.y * 0.12)

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)
	for t in townsfolk:
		t.start_idle()
	for spray in sprays:
		var s := spray as Node2D
		s.scale = Vector2(0.6, 0.6)
		var pulse := _ct(s).set_loops(3)
		pulse.tween_property(s, "scale", Vector2(1.0, 1.0), 0.28)
		pulse.tween_property(s, "scale", Vector2(0.75, 0.75), 0.24)
func _on_impact() -> void:
	super._on_impact()
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.hop(8.0, 0.22)
	# THE BLOWOUT: white shock ring blooms from the burst point.
	var ring := Polygon2D.new()
	ring.polygon = Props.ellipse(30.0 * _content_scale, 14.0 * _content_scale, 24)
	ring.color = Color(0.75, 0.92, 1.0, 0.6)
	ring.position = _impact_point()
	ring.z_index = 8
	world.add_child(ring)
	var boom := _ct(ring)
	boom.set_parallel(true)
	boom.tween_property(ring, "scale", Vector2(8.0, 6.0), 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	boom.tween_property(ring, "modulate:a", 0.0, 0.4)
	boom.chain().tween_callback(ring.queue_free)
	# Shrapnel: the spare segments blast apart and tumble down.
	for i in range(spare_pipes.size()):
		var chunk := spare_pipes[i] as Node2D
		var dir := -1.0 + 2.0 * float(i)
		var start_y := chunk.position.y
		var debris := _ct(chunk)
		debris.set_parallel(true)
		debris.tween_property(chunk, "position",
			chunk.position + Vector2(dir * _vp.x * 0.16, -_vp.y * 0.30), 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		debris.tween_property(chunk, "rotation", chunk.rotation + dir * 5.0, 0.9)
		debris.chain().tween_property(chunk, "position:y",
			start_y + _vp.y * 0.4, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# THE HURL: the shockwave rockets Dribble straight up, spinning.
	dribble.set_arm_pose(CartoonActor.ArmPose.UP)
	var up := _ct()
	up.tween_property(dribble, "position:y",
		dribble.position.y - _vp.y * 0.42, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var spin := _ct(dribble)
	spin.tween_property(dribble, "rotation", TAU * 1.5, 0.5)
func _beat_payoff() -> void:
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.REACH)
		t.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	dribble.set_expression(CartoonActor.Mood.DIZZY)
	# Hang at the apex, wobbling...
	var hover := _ct(dribble)
	hover.tween_property(dribble, "rotation", TAU * 2.0, 0.4)
	hover.tween_property(dribble, "position:x",
		dribble.position.x + 8.0 * _content_scale, 0.1)
	hover.tween_property(dribble, "position:x",
		dribble.position.x - 8.0 * _content_scale, 0.1)
	# ...then gravity wins and he drops out of frame.
	var drop_off := _ct()
	drop_off.tween_interval(0.30)
	drop_off.tween_callback(_drop_dribble)
	# The burst keeps raining on the stunned town.
	var rain := _ct().set_loops(4)
	rain.tween_callback(_spawn_burst_drop)
	rain.tween_interval(0.18)

func _drop_dribble() -> void:
	var fly := _ct(dribble)
	fly.set_parallel(true)
	fly.tween_property(dribble, "position",
		Vector2(dribble.position.x + _vp.x * 0.14, _vp.y * 1.25), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(dribble, "rotation", TAU * 3.0, 0.5)
	fly.tween_property(dribble, "modulate:a", 0.0, 0.2).set_delay(0.3)
	fly.chain().tween_callback(func() -> void: dribble.visible = false)
	# The town gawks after the falling droplet.
	var watches := _ct()
	watches.tween_interval(0.5)
	watches.tween_callback(func() -> void:
		for t in townsfolk:
			t.set_expression(CartoonActor.Mood.SHOCKED)
		mayor.set_arm_pose(CartoonActor.ArmPose.UP))

func _spawn_burst_drop() -> void:
	var droplet := Polygon2D.new()
	droplet.polygon = Props.ellipse(7.0 * _content_scale, 9.0 * _content_scale, 8)
	droplet.color = Props.WATER
	droplet.position = _impact_point()
	droplet.z_index = 6
	world.add_child(droplet)
	var tw := _ct(droplet)
	tw.set_parallel(true)
	tw.tween_property(droplet, "position",
		droplet.position + Vector2(
			randf_range(-90.0, 90.0) * _content_scale,
			-_vp.y * randf_range(0.05, 0.16)), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(droplet, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(droplet.queue_free)