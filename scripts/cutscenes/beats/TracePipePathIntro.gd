## TracePipePath - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/TracePipePathIntro.tscn

extends MicrogameIntroBase

## Trace Pipe Path — CAUSE clip.
## res://scenes/ui/cutscenes/beats/TracePipePathIntro.tscn
##
## BEAT 1  Broken pipe segments lie scattered; a glowing dotted path
##         connects them; Dribble kneels to trace; Mayor Ripple holds
##         a wrench hopefully.
## BEAT 2  (flash-only impact) The dotted path FLARES white-hot; the
##         pipes rattle; the town freezes and stares.
## BEAT 3  The pipes snap one by one into line along the path; Dribble
##         traces the last stretch; the mayor cheers.

const Props := preload("res://scripts/cutscenes/beats/TracePipeProps.gd")

var pipes: Array = []
var path_node: Node2D
var pipe_size: float

func _setup_stage() -> void:
	# Pale work-site backdrop like the minigame.
	get_node("Backdrop").color = Props.SITE
	pipe_size = _vp.y * 0.24
	var ground_y := _vp.y * GROUND_FRACTION
	# The glowing dotted trace path winding across the site.
	var trace := PackedVector2Array([
		Vector2(_vp.x * 0.10, ground_y),
		Vector2(_vp.x * 0.24, ground_y - _vp.y * 0.06),
		Vector2(_vp.x * 0.38, ground_y - _vp.y * 0.02),
		Vector2(_vp.x * 0.52, ground_y - _vp.y * 0.08),
		Vector2(_vp.x * 0.64, ground_y),
	])
	path_node = Props.make_dotted_path(trace, _vp.y * 0.012)
	path_node.modulate.a = 0.0
	path_node.z_index = 1
	world.add_child(path_node)
	# Broken pipe segments scattered along the path.
	var specs := [
		[0.26, -0.35, 0.03], [0.38, 0.30, 0.02], [0.50, -0.20, 0.035],
	]
	for spec in specs:
		var pipe := Props.make_pipe_segment(pipe_size, true)
		pipe.position = Vector2(_vp.x * spec[0], ground_y - _vp.y * spec[2])
		pipe.rotation = spec[1]
		pipe.z_index = 2
		world.add_child(pipe)
		pipes.append(pipe)
	# The town watches from the side; the mayor holds the wrench out.
	_stage_townsfolk(2, _vp.x * 0.03, _vp.x * 0.14)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.88, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.68)
	camera.position = _vp * 0.5

## BEAT 1 — Dribble kneels to trace; the mayor hopes; the path pulses.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	for t in townsfolk:
		t.start_idle()
	# The dotted path pulses awake; the pipes rattle in place.
	var glow := _ct(path_node).set_loops(3)
	glow.tween_property(path_node, "modulate:a", 1.0, 0.35)
	glow.tween_property(path_node, "modulate:a", 0.55, 0.35)
	for pipe: Node2D in pipes:
		var base_rot: float = pipe.rotation
		var rattle := _ct(pipe).set_loops(2)
		rattle.tween_property(pipe, "rotation", base_rot + 0.04, 0.18)
		rattle.tween_property(pipe, "rotation", base_rot - 0.04, 0.18)
		rattle.tween_property(pipe, "rotation", base_rot, 0.12)

## BEAT 2 — the path FLARES white-hot. Flash only; the town freezes.
func _on_impact() -> void:
	_impact_flash()
	path_node.modulate = Color(1.9, 1.9, 2.1, 1.0)
	for pipe: Node2D in pipes:
		var bounce := _ct(pipe)
		bounce.tween_property(pipe, "position:y",
			pipe.position.y - _vp.y * 0.02, 0.08)
		bounce.tween_property(pipe, "position:y", pipe.position.y, 0.14)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.hop(12.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.SHOCKED)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

## BEAT 3 — the pipes snap into line along the glowing path; Dribble
## traces the last stretch; the town points and cheers.
func _beat_payoff() -> void:
	for i in range(pipes.size()):
		var pipe: Node2D = pipes[i]
		var slot := Vector2(
			_vp.x * (0.26 + 0.12 * float(i)),
			_vp.y * GROUND_FRACTION - pipe_size * 0.11
		)
		var tw := _ct(pipe).set_parallel(true) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pipe, "position", slot, 0.3).set_delay(0.08 * float(i))
		tw.tween_property(pipe, "rotation", 0.0, 0.3).set_delay(0.08 * float(i))
	var slide := _ct(dribble)
	slide.tween_property(dribble, "position:x", _vp.x * 0.60, 0.45)
	dribble.set_expression(CartoonActor.Mood.SMUG)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.HAPPY)
		t.set_arm_pose(CartoonActor.ArmPose.REACH)
