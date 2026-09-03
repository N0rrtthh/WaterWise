## PlugTheLeak - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/PlugTheLeakWinOutro.tscn

extends MicrogameOutroBase

## Plug The Leak — WIN clip.
## res://scenes/ui/cutscenes/beats/PlugTheLeakWinOutro.tscn
##
## BEAT 1  The leaking wall, jets still going.
## BEAT 2  (impact) CORK-POP: every hole gets corked on the impact tick —
##         the jets die — and, absurdly, the pipes start producing
##         bagpipe-like music: notes drift off the pipes.
## BEAT 3  The town dances in the leftover spray mist.

const Props := preload("res://scripts/cutscenes/beats/PlugTheLeakProps.gd")

var pipes: Array = []
var jets: Array = []
var notes: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG_PALE
	_stage_townsfolk(3, _vp.x * 0.58, _vp.x * 0.86)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.50, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.42)
	_add_pipe(Vector2(_vp.x * 0.26, _vp.y * 0.30), 0.0,
		[-_vp.x * 0.05, _vp.x * 0.06])
	_add_pipe(Vector2(_vp.x * 0.34, _vp.y * 0.52), -0.15,
		[0.0, _vp.x * 0.05])
	camera.position = _vp * 0.5

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

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
		t.start_idle()

## Impact frame lands mid-wall, between the two pipes.
func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.30, _vp.y * 0.41)

## BEAT 2 — the cork-pop concert. Full impact stack while every hole gets
## corked and the jets die on the same tick; then the pipes sing.
func _on_impact() -> void:
	super._on_impact()
	for i in range(jets.size()):
		var jet := jets[i] as GPUParticles2D
		var cut := _ct(jet)
		cut.tween_property(jet, "emitting", false, 0.05)
	var cork_i := 0
	for p in range(pipes.size()):
		var pipe := pipes[p] as Node2D
		var hole_count := 2
		for i in range(hole_count):
			var hole := pipe.get_node("Hole%d" % i) as Polygon2D
			var cork := Props.make_cork(_content_scale * 1.3)
			cork.position = pipe.position + hole.position.rotated(pipe.rotation)
			cork.rotation = pipe.rotation + PI * 0.5  # base into the hole
			cork.z_index = 6
			cork.scale = Vector2.ONE * 0.01
			world.add_child(cork)
			var pop := _ct(cork)
			pop.tween_interval(0.04 * float(cork_i))
			pop.tween_property(cork, "scale", Vector2.ONE * _content_scale * 1.3, 0.14) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# Hole heals to the live game's fixed-state green.
			var heal := _ct(hole)
			heal.tween_interval(0.05 * float(cork_i))
			heal.tween_property(hole, "color", Props.GOOD_GREEN, 0.12)
			cork_i += 1
		# The pipe starts "singing": wobble like a drone + notes drift off.
		var sing := _ct(pipe).set_loops(4)
		sing.tween_property(pipe, "scale", Vector2(1.03, 0.97), 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sing.tween_property(pipe, "scale", Vector2(0.97, 1.03), 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sing.tween_property(pipe, "scale", Vector2.ONE, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		for k in range(3):
			var note := Props.make_note(_content_scale * 1.1)
			note.position = pipe.position \
				+ Vector2((float(k) - 1.0) * 40.0 * _content_scale, -24.0 * _content_scale) \
					.rotated(pipe.rotation)
			note.z_index = 7
			note.scale *= 0.01
			world.add_child(note)
			notes.append(note)
			var drift := _ct(note)
			drift.tween_interval(0.10 + 0.08 * float(k))
			drift.tween_property(note, "scale", Vector2.ONE * _content_scale * 1.1, 0.12) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			drift.tween_property(note, "position:y", note.position.y - 56.0 * _content_scale, 0.7) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			drift.parallel().tween_property(note, "rotation", 0.25 - 0.5 * float(k % 2), 0.7) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			drift.parallel().tween_property(note, "modulate:a", 0.0, 0.7) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			drift.tween_callback(note.queue_free)

## BEAT 3 — the town dances in the leftover spray mist.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_expression(CartoonActor.Mood.SMUG)
	# Leftover mist settles where the jets used to spray.
	var mist_spots := [_vp.x * 0.36, _vp.x * 0.44, _vp.x * 0.52]
	for i in range(mist_spots.size()):
		var mist := Props.make_mist(90.0 * _content_scale)
		mist.position = Vector2(_vp.x * mist_spots[i], _vp.y * GROUND_FRACTION - 40.0 * _content_scale)
		mist.z_index = 2
		mist.modulate.a = 0.0
		world.add_child(mist)
		var fade := _ct(mist)
		fade.tween_interval(0.06 * float(i))
		fade.tween_property(mist, "modulate:a", 1.0, 0.30)
	# Everyone dances — alternating lean-and-bounce.
	var dancers: Array = [dribble, mayor]
	for t in townsfolk:
		dancers.append(t)
	for i in range(dancers.size()):
		var d := dancers[i] as Node2D
		var dance := _ct(d).set_loops(3)
		dance.tween_property(d, "rotation", 0.16, 0.13) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		dance.tween_property(d, "rotation", -0.16, 0.13) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		dance.tween_property(d, "rotation", 0.0, 0.10) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var bounce := _ct(d)
		bounce.tween_interval(0.07 * float(i))
		bounce.tween_callback((dancers[i] as CartoonActor).hop.bind(18.0, 0.26))
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.CHEER)

