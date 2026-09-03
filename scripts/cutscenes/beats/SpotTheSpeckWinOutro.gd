## SpotTheSpeck - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/SpotTheSpeckWinOutro.tscn

extends MicrogameOutroBase

## Spot The Speck — WIN clip.
## res://scenes/ui/cutscenes/beats/SpotTheSpeckWinOutro.tscn
##
## BEAT 1  The washed glasses sit gleaming on the table.
## BEAT 2  (impact) They stack THEMSELVES into a gleaming tower — the
##         final glass lands on the tick with a shine burst.
## BEAT 3  A glass balances on top and the town toasts.

const Props := preload("res://scripts/cutscenes/beats/SpotTheSpeckProps.gd")

var glasses: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	_stage_townsfolk(2, _vp.x * 0.74, _vp.x * 0.86)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.95, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.22)
	var table := Props.make_table(_vp.x * 0.36, _vp.y * 0.16)
	table.position = Vector2(_vp.x * 0.42, _vp.y * GROUND_FRACTION)
	table.z_index = 3
	world.add_child(table)
	# Four clean glasses, scattered loose on the tabletop.
	var top_y := _vp.y * GROUND_FRACTION - _vp.y * 0.16
	for setup in [[0.28, 0.0], [0.38, -0.06], [0.46, 0.04], [0.54, 0.0]]:
		var glass := Props.make_glass(_vp.y * 0.16, false)
		glass.position = Vector2(_vp.x * setup[0],
			top_y + _vp.y * 0.02 * setup[1])
		glass.rotation = setup[1] * 0.4
		glass.z_index = 4
		world.add_child(glass)
		glasses.append(glass)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	# The glasses hum with anticipation: a gentle ripple of wobbles.
	for i in range(glasses.size()):
		var glass := glasses[i] as Node2D
		var wobble := _ct(glass).set_loops(2)
		wobble.tween_interval(0.12 * float(i))
		wobble.tween_property(glass, "rotation", 0.03, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wobble.tween_property(glass, "rotation", -0.03, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wobble.tween_property(glass, "rotation", 0.0, 0.10)

## Impact frame: the top of the finished tower.
func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.42, _vp.y * GROUND_FRACTION - _vp.y * 0.62)

## BEAT 2 — the self-stacking tower. Full impact stack as the final
## glass lands on the tick.
func _on_impact() -> void:
	super._on_impact()
	# Stack slots on the tabletop, one glass per slot, bottom-up.
	var base := Vector2(_vp.x * 0.42, _vp.y * GROUND_FRACTION - _vp.y * 0.16)
	var step := _vp.y * 0.125
	for i in range(glasses.size()):
		var glass := glasses[i] as Node2D
		var slot := base + Vector2(0.0, -step * float(i))
		var stack := _ct(glass)
		if i < glasses.size() - 1:
			# Earlier glasses hop into place first.
			stack.tween_property(glass, "position", slot, 0.09) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			# The final glass lands EXACTLY on the tick.
			stack.tween_property(glass, "position", slot, 0.03)
		stack.parallel().tween_property(glass, "rotation", 0.0, 0.06)
		stack.parallel().tween_property(glass, "scale", Vector2(1.0, 1.0), 0.06)
	# Shine burst at the tower top on the final placement.
	for i in range(10):
		var spark := Polygon2D.new()
		spark.polygon = Props._ellipse(7.0 * _content_scale, 5.0 * _content_scale, 8)
		spark.position = _impact_point()
		spark.color = Props.SHINE if i % 2 == 0 else Color(1.0, 1.0, 1.0, 0.9)
		spark.z_index = 8
		world.add_child(spark)
		var dir := Vector2(cos(float(i) * TAU / 10.0), sin(float(i) * TAU / 10.0) * 0.7 - 0.3)
		var far := _impact_point() + dir * 70.0 * _content_scale
		var fly := _ct(spark)
		fly.tween_property(spark, "position", far, 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(spark, "modulate:a", 0.0, 0.30)
		fly.tween_callback(spark.queue_free)
	# The tower does a proud settle.
	var tower_root := glasses[0] as Node2D
	var settle := _ct(tower_root)
	settle.tween_property(tower_root, "scale", Vector2(1.04, 0.97), 0.08)
	settle.tween_property(tower_root, "scale", Vector2(1.0, 1.0), 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dribble.set_arm_pose(CartoonActor.ArmPose.UP)
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(14.0, 0.24)

## BEAT 3 — a glass balances on top; the town toasts.
func _beat_payoff() -> void:
	mayor.set_expression(CartoonActor.Mood.SMUG)
	# A fifth glass drops in and balances on the tower's crown.
	var crown := Props.make_glass(_vp.y * 0.15, false)
	crown.position = _impact_point() + Vector2(0.0, _vp.y * 0.14)
	crown.z_index = 5
	world.add_child(crown)
	var perch := _ct(crown)
	perch.tween_property(crown, "position", _impact_point(), 0.16) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# It teeters... and settles.
	var teeter := _ct(crown)
	teeter.tween_interval(0.16)
	teeter.tween_property(crown, "rotation", 0.09, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	teeter.tween_property(crown, "rotation", -0.09, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	teeter.tween_property(crown, "rotation", 0.0, 0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The town toasts: everyone raises their glass to the tower.
	var cast: Array = []
	for t in townsfolk:
		cast.append(t)
	for i in range(cast.size()):
		var toster := cast[i] as CartoonActor
		toster.set_arm_pose(CartoonActor.ArmPose.UP)
		toster.set_expression(CartoonActor.Mood.HAPPY)
		var toast := _ct(toster).set_loops(3)
		toast.tween_interval(0.02 * float(i))
		toast.tween_callback(toster.hop.bind(14.0, 0.18))
		toast.tween_interval(0.24)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.hop(12.0, 0.26)
	# Dribble takes a bow beside the tower.
	var bow := _ct(dribble)
	bow.tween_property(dribble, "rotation", 0.15, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bow.tween_property(dribble, "rotation", 0.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# One final gleam sweeps the crown glass.
	var sweep := _ct(crown)
	sweep.tween_interval(0.35)
	sweep.tween_property(crown, "modulate", Color(1.25, 1.25, 1.3), 0.10)
	sweep.tween_property(crown, "modulate", Color(1.0, 1.0, 1.0), 0.14)

