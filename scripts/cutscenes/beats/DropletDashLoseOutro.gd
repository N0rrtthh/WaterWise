## DropletDash - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/DropletDashLoseOutro.tscn

extends MicrogameOutroBase

## Droplet Dash — LOSE outro.
## res://scenes/ui/cutscenes/beats/DropletDashLoseOutro.tscn
##
## BEAT 1  Mid-course: obstacles line the track, the current streaks flow,
##         Dribble dashes toward the brick wall.
## BEAT 2  IMPACT — he SPLATS flat against the wall (pancake on the impact
##         frame: flash + burst + stinger on the wall face).
## BEAT 3  He peels back off the wall, the current grabs him, and he is swept
##         toward the cliff-edge waterfall — screaming (comedically) the
##         whole way — while the town can only watch.

const Props := preload("res://scripts/cutscenes/beats/DropletDashProps.gd")

const CLIFF_EDGE_X := 0.88

var wall: Node2D
var streaks: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.COURSE_SKY
	world.get_node("Ground").color = Props.TRACK
	world.get_node("Dirt").color = Props.TRACK_DARK
	world.add_child(Props.make_waterfall(_vp, CLIFF_EDGE_X))
	_stage_townsfolk(3, _vp.x * 0.06, _vp.x * 0.20)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.13, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.38)
	wall = Props.make_obstacle("wall")
	wall.scale = Vector2.ONE * _content_scale * 1.3
	wall.position = Vector2(_vp.x * 0.58, _vp.y * GROUND_FRACTION)
	wall.z_index = -1
	world.add_child(wall)
	# Flow streaks skimming the track surface, rightward.
	for i in range(3):
		var s := Line2D.new()
		s.name = "Flow%d" % (i + 1)
		var sy := _vp.y * GROUND_FRACTION + (14.0 + 18.0 * float(i)) * _content_scale
		s.points = PackedVector2Array([
			Vector2(_vp.x * 0.02, sy), Vector2(_vp.x * 0.22, sy),
		])
		s.width = 3.0
		s.default_color = Color(1, 1, 1, 0.30)
		s.z_index = -2
		world.add_child(s)
		streaks.append(s)
		_flow(s)

## Endless rightward flow; bound to the streak so the loop dies with it.
func _flow(s: Line2D) -> void:
	var flow := _ct(s).set_loops()
	var span := _vp.x * 0.24
	flow.tween_method(func(t: float) -> void:
		var off := t * _vp.x * 0.9
		s.points[0] = Vector2(_vp.x * 0.02 + off, s.points[0].y)
		s.points[1] = Vector2(_vp.x * 0.02 + span + off, s.points[1].y)
	, 0.0, 1.0, 1.1)

## BEAT 1 — the dash: Dribble sprints for the wall, the town winces.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.drip_sweat()
	for t in townsfolk:
		t.start_idle()
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.hop(22.0, 0.2)

func _impact_point() -> Vector2:
	return wall.position + Vector2(-34.0 * wall.scale.x, -30.0 * wall.scale.y)

## BEAT 2 — the splat: super() fires punch + flash + burst + stinger at the
## wall face as Dribble slams in; the pancake lands right on the frame.
func _on_impact() -> void:
	dribble.position = _impact_point() + Vector2(6.0 * _content_scale, 14.0 * _content_scale)
	dribble.rig.rotation = 0.0
	# The pancake: flattened wide against the wall face.
	dribble.rig.scale = Vector2(1.55, 0.35)
	super._on_impact()
	_splat_burst(_impact_point())
	mayor.set_expression(CartoonActor.Mood.SHOCKED)

## Droplet spray exploding off the wall face.
func _splat_burst(at: Vector2) -> void:
	var p := GPUParticles2D.new()
	p.name = "SplatBurst"
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.amount = 26
	p.lifetime = 0.6
	p.position = at
	p.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(-1, -0.6, 0)
	m.spread = 50.0
	m.initial_velocity_min = 240.0
	m.initial_velocity_max = 480.0
	m.gravity = Vector3(0, 1000, 0)
	m.color_initial_ramp = _ramp([
		Props.WATER_FILL, Props.FALL, Color(1, 1, 1),
	])
	m.scale_min = 0.4
	m.scale_max = 0.8
	p.process_material = m
	p.z_index = 12
	world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var safety := _ct()
	safety.tween_interval(2.0)
	safety.tween_callback(p.queue_free)

## BEAT 3 — peel off the wall, get grabbed by the current, and go over the
## waterfall edge — screaming all the way — while the town watches, helpless.
func _beat_payoff() -> void:
	_peel_off()
	_sweep_to_fall()
	_watch_helplessly()

## Elastic un-pancake: pops back into shape, peeling off the wall face.
func _peel_off() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	dribble.drip_sweat()
	# Comedy screaming loop: panicked shudders, bound to Dribble.
	var scream := _ct(dribble).set_loops()
	scream.tween_callback(dribble.shake.bind(6.0, 0.3))
	scream.tween_interval(0.45)
	var peel := _ct().set_parallel(true)
	peel.tween_property(dribble, "rig:scale", Vector2.ONE, 0.30) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	peel.tween_property(dribble, "position",
		dribble.position + Vector2(-40.0 * _content_scale, 6.0 * _content_scale), 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## The current grabs him: accelerating tumble rightward with a panic wiggle,
## then straight over the cliff-edge waterfall and down out of frame.
func _sweep_to_fall() -> void:
	var ground_y := _vp.y * GROUND_FRACTION
	var grab := Vector2(_vp.x * 0.50, ground_y)
	var fast := Vector2(_vp.x * 0.70, ground_y - 16.0 * _content_scale)
	var edge := Vector2(_vp.x * (CLIFF_EDGE_X - 0.02), ground_y - 22.0 * _content_scale)
	var bottom := Vector2(_vp.x * (CLIFF_EDGE_X + 0.06), _vp.y * 1.15)
	var sweep := _ct()
	sweep.tween_interval(0.34)
	sweep.tween_method(_sweep_step, dribble.position, grab, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sweep.tween_method(_sweep_step, grab, fast, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sweep.tween_method(_sweep_step, fast, edge, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sweep.tween_method(_sweep_step, edge, bottom, 0.42) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Tumble: two full panic rotations across the sweep.
	var tumble := _ct()
	tumble.tween_interval(0.34)
	tumble.tween_method(func(t: float) -> void:
		dribble.rig.rotation = -t * TAU * 2.0
	, 0.0, 1.0, 1.24)

## One step of the sweep: position plus a comic panic wiggle.
## The wiggle rides _elapsed (the beat-local clock MicrogameOutroBase advances in
## _process) rather than Time.get_ticks_msec(): app uptime keeps running while the
## tree is paused, so a notification pulled down mid-sweep froze the tween and left
## the wiggle phase to race ahead, and Dribble jumped up to 18 px on resume. Same
## 28 rad/s as before, now in the same time base as the sweep it decorates.
func _sweep_step(p: Vector2) -> void:
	dribble.position = p + Vector2(0.0, sin(_elapsed * 28.0) * 9.0)

## The town can only watch the little guy go over.
func _watch_helplessly() -> void:
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.12 * float(i))
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.REACH))
		tw.tween_callback(townsfolk[i].hop.bind(18.0, 0.26))

