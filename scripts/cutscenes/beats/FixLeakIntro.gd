## FixLeak - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/FixLeakIntro.tscn

extends MicrogameIntroBase

## Fix The Leak — CAUSE clip.
## res://scenes/ui/cutscenes/beats/FixLeakIntro.tscn
##
## BEAT 1  A grey pipe run sprays three jets across the frame; the waste
##         meter's needle twitches upward in the corner; the town assembles.
## BEAT 2  (flash-only impact) One jet BURSTS wider and the needle jumps —
##         that's the round: seal the leaks before the meter pegs red.
## BEAT 3  Mayor Ripple points frantically at each leak in turn while the
##         needle keeps climbing. SNAP: whip-pan into gameplay.

const Props := preload("res://scripts/cutscenes/beats/FixLeakProps.gd")

const PIPE_Y := 0.34
const METER_POS := Vector2(0.10, 0.16)

var pipe: Node2D
var meter: Node2D
var needle: Polygon2D
var jets: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.WALL
	get_node("World/Ground").color = Props.FLOOR
	get_node("World/Dirt").color = Props.FLOOR.darkened(0.25)
	_stage_townsfolk(3, _vp.x * 0.62, _vp.x * 0.80)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.70, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.44)
	pipe = Props.make_pipe(_vp.x * 0.46, [-0.30, 0.02, 0.30])
	pipe.position = Vector2(_vp.x * 0.38, _vp.y * PIPE_Y)
	pipe.rotation = 0.0
	world.add_child(pipe)
	for i in range(3):
		var hole: Polygon2D = pipe.get_node("Hole%d" % i)
		var jet := Props.make_jet(_dot_texture(), 1.0)
		jet.position = pipe.position + hole.position
		jet.rotation = 0.55 * PI + 0.14 * float(i)  # fanning down/outward
		jet.z_index = 6
		world.add_child(jet)
		jets.append(jet)
	meter = Props.make_waste_meter(1.15 * _content_scale)
	meter.position = Vector2(_vp.x * METER_POS.x, _vp.y * METER_POS.y)
	meter.z_index = 8
	world.add_child(meter)
	needle = meter.get_node("Needle")
	# Beat 1 opens close on the worst jet, then settles wide.
	camera.zoom = Vector2(1.3, 1.3)
	camera.position = _vp * 0.5 + Vector2(-160.0, -60.0) * _content_scale

## BEAT 1 — the leak reveals itself; the needle starts to creep.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()
	var pan := _ct().set_parallel(true)
	pan.tween_property(camera, "position", _vp * 0.5, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan.tween_property(camera, "zoom", Vector2.ONE, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Needle creep: bound to the meter so it dies with it.
	var creep := _ct(needle)
	creep.tween_property(needle, "rotation", 0.7, _setup_sec()) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — the situation becomes clear. Intro contract: flash only, no punch,
## no burst, no stinger. The worst jet surges and the needle jumps.
func _on_impact() -> void:
	_impact_flash()
	var worst: GPUParticles2D = jets[1]
	worst.amount = int(40)
	worst.restart()
	var hop := _ct(needle)
	hop.tween_property(needle, "rotation", 1.35, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.drip_sweat()

## BEAT 3 — the mayor scrambles leak to leak frantically while the needle
## keeps climbing toward red. The whip-pan snaps in mid-scramble.
func _beat_payoff() -> void:
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	dribble.hop(26.0, 0.26)
	# The mayor darts toward the pipe, hopping leak to leak.
	var my := _vp.y * GROUND_FRACTION
	var dart := _ct()
	for i in range(3):
		var hole: Polygon2D = pipe.get_node("Hole%d" % i)
		dart.tween_property(mayor, "position",
			Vector2(pipe.position.x + hole.position.x + _vp.x * 0.06, my), 0.15) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		dart.parallel().tween_property(mayor, "rotation",
			-0.22 if i % 2 == 0 else 0.22, 0.09)
		dart.tween_property(mayor, "rotation", 0.0, 0.06)
	# Needle races for the red zone.
	var race := _ct(needle)
	race.tween_property(needle, "rotation", 2.3, _payoff_sec()) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
