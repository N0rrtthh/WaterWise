## DropletDash - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/DropletDashIntro.tscn

extends MicrogameIntroBase

## Droplet Dash — CAUSE clip.
## res://scenes/ui/cutscenes/beats/DropletDashIntro.tscn
##
## BEAT 1  Camera pans down the obstacle course onto the starting line where
##         Dribble crouches ready; the crowd is already cheering.
## BEAT 2  (flash-only impact) The race flag DROPS — the round is on.
## BEAT 3  Dribble does his get-ready bounce; the mayor shouts the GO; the
##         crowd goes wild. SNAP: whip-pan into gameplay.

const Props := preload("res://scripts/cutscenes/beats/DropletDashProps.gd")

const OBSTACLE_XS := [0.58, 0.72, 0.86]
const OBSTACLE_KINDS := ["crate", "barrel", "wall"]

var start_line: Node2D
var flag: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.COURSE_SKY
	world.get_node("Ground").color = Props.TRACK
	world.get_node("Dirt").color = Props.TRACK_DARK
	_stage_townsfolk(4, _vp.x * 0.06, _vp.x * 0.24)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.14, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.40)
	start_line = Props.make_start_line(70.0 * _content_scale)
	start_line.position = Vector2(_vp.x * 0.40, _vp.y * GROUND_FRACTION + 2.0)
	start_line.z_index = -1
	world.add_child(start_line)
	for i in range(OBSTACLE_XS.size()):
		var o := Props.make_obstacle(OBSTACLE_KINDS[i])
		o.scale = Vector2.ONE * _content_scale
		o.position = Vector2(_vp.x * float(OBSTACLE_XS[i]), _vp.y * GROUND_FRACTION)
		o.z_index = -2
		world.add_child(o)
	flag = Props.make_flag(96.0 * _content_scale)
	flag.position = Vector2(_vp.x * 0.33, _vp.y * GROUND_FRACTION)
	flag.z_index = 2
	world.add_child(flag)
	# Beat 1 starts high and tight on the far end of the course, then pans back
	# to the start line.
	camera.zoom = Vector2(1.24, 1.24)
	camera.position = _vp * 0.5 + Vector2(180.0, -140.0) * _content_scale

## BEAT 1 — course reveal; the crowd is mid-cheer; Dribble sets his stance.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.UP)
		t.start_idle()
		_cheer(t, 0.10 * float(t.get_index() % 4))
	var pan := _ct().set_parallel(true)
	pan.tween_property(camera, "position", _vp * 0.5, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan.tween_property(camera, "zoom", Vector2.ONE, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## BEAT 2 — the situation becomes clear. Intro contract: flash only, no punch,
## no burst, no stinger. The pennant drops and the crowd surges.
func _on_impact() -> void:
	_impact_flash()
	var pennant: Polygon2D = flag.get_node("Pennant")
	var raised: Vector2 = pennant.position
	pennant.position = raised + Vector2(0.0, -34.0) * _content_scale
	var drop := _ct()
	drop.tween_property(pennant, "position", raised, 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for t in townsfolk:
		_cheer(t, randf_range(0.0, 0.14))

## BEAT 3 — the get-ready bounce; the mayor roars the GO; the crowd peaks
## just as the whip-pan snaps in.
func _beat_payoff() -> void:
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.hop(30.0, 0.30)
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.hop(34.0, 0.28)
	var tw := _ct()
	tw.tween_interval(0.14)
	tw.tween_callback(dribble.hop.bind(20.0, 0.22))
	for i in range(townsfolk.size()):
		_cheer(townsfolk[i], 0.08 * float(i))

## Sideline cheer burst: hop plus a quick shudder.
func _cheer(who: CartoonActor, delay: float) -> void:
	var t := _ct()
	t.tween_interval(delay)
	t.tween_callback(who.hop.bind(30.0, 0.34))
