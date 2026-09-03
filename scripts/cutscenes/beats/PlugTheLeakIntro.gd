## PlugTheLeak - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/PlugTheLeakIntro.tscn

extends MicrogameIntroBase

## Plug The Leak — CAUSE clip.
## res://scenes/ui/cutscenes/beats/PlugTheLeakIntro.tscn
##
## BEAT 1  Two pipes hiss and spray at once; the camera settles wide.
## BEAT 2  (flash-only impact) A jet surges — the pipes are getting worse;
##         the town covers its ears.
## BEAT 3  Dribble panic-reaches between the pipes, the mayor points, the
##         pipes shudder. SNAP into gameplay.

const Props := preload("res://scripts/cutscenes/beats/PlugTheLeakProps.gd")

var pipes: Array = []
var jets: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG_PALE
	_stage_townsfolk(3, _vp.x * 0.60, _vp.x * 0.86)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.54, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.44)
	_add_pipe(Vector2(_vp.x * 0.26, _vp.y * 0.30), 0.0,
		[-_vp.x * 0.05, _vp.x * 0.06])
	_add_pipe(Vector2(_vp.x * 0.34, _vp.y * 0.52), -0.15,
		[0.0, _vp.x * 0.05])
	camera.zoom = Vector2(1.3, 1.3)
	camera.position = pipes[0].position + Vector2(0.0, -20.0)

## One pipe with a continuous jet at each hole. Jets aim down-right; rotate
## to aim.
func _add_pipe(pos: Vector2, rot: float, hole_xs: Array) -> void:
	var pipe := Props.make_pipe(_vp.x * 0.16, hole_xs)
	pipe.position = pos
	pipe.rotation = rot
	pipe.z_index = 4
	world.add_child(pipe)
	pipes.append(pipe)
	for i in range(hole_xs.size()):
		var hole := pipe.get_node("Hole%d" % i) as Polygon2D
		var jet := Props.make_jet(_content_scale, _dot_texture())
		jet.position = pipe.position + hole.position.rotated(pipe.rotation)
		jet.rotation = PI * 0.35 + rot
		jet.z_index = 5
		world.add_child(jet)
		jets.append(jet)

## BEAT 1 — open on the spraying pipes, settle wide.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.WORRIED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
		t.start_idle()
	var pan := _ct().set_parallel(true)
	pan.tween_property(camera, "position", _vp * 0.5, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan.tween_property(camera, "zoom", Vector2.ONE, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Hisses: the pipes tremble under pressure.
	for i in range(pipes.size()):
		var pipe := pipes[i] as Node2D
		var tremble := _ct(pipe).set_loops(2)
		tremble.tween_property(pipe, "position:x", pipe.position.x + 1.5, 0.05)
		tremble.tween_property(pipe, "position:x", pipe.position.x - 1.5, 0.05)
		tremble.tween_property(pipe, "position:x", pipe.position.x, 0.05)

## BEAT 2 — the situation gets worse. Intro contract: flash only. A jet
## surges bigger; the town flinches, covering its ears.
func _on_impact() -> void:
	_impact_flash()
	var surge_jet := jets[0] as GPUParticles2D
	var surge := _ct(surge_jet)
	surge.tween_property(surge_jet, "scale", Vector2(1.5, 1.5), 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	surge.tween_property(surge_jet, "scale", Vector2(1.15, 1.15), 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.drip_sweat()
	# The town flinches — ears covered (BRACE), hopping at the noise.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.05 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(14.0, 0.24))

## BEAT 3 — Dribble panic-reaches between the pipes; the mayor points; the
## pipes shudder harder.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	# Dribble darts between the two pipes.
	var dart := _ct()
	dart.tween_property(dribble, "position:x", pipes[1].position.x + 60.0 * _content_scale, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dart.tween_property(dribble, "position:x", _vp.x * 0.42, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dribble.hop(16.0, 0.28)
	# Mayor hops, pointing at the worst pipe.
	var lean := _ct()
	lean.tween_property(mayor, "rotation", -0.16, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lean.tween_property(mayor, "rotation", 0.0, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.hop(16.0, 0.30)
	# Pipes shudder alternately — the whole wall is losing.
	for i in range(pipes.size()):
		var pipe := pipes[i] as Node2D
		var wob := _ct(pipe)
		wob.tween_interval(0.06 * float(i))
		wob.tween_property(pipe, "rotation", pipe.rotation + 0.05, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wob.tween_property(pipe, "rotation", pipe.rotation - 0.05, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wob.tween_property(pipe, "rotation", pipe.rotation, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Town covers ears harder — flinch chain.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.06 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(10.0, 0.20))

