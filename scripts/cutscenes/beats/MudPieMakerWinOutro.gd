## MudPieMaker - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/MudPieMakerWinOutro.tscn

extends MicrogameOutroBase

## Mud Pie Maker — WIN clip.
## res://scenes/ui/cutscenes/beats/MudPieMakerWinOutro.tscn
##
## BEAT 1  The stand and tins ready; the gauge primed.
## BEAT 2  (impact) super() punch AT the stand as the tins turn into
##         perfectly baked pies that line up — steam puffs rise on the
##         impact frame; the gauge fills to green.
## BEAT 3  A queue of town members forms instantly; the mayor buys a dozen.

const Props := preload("res://scripts/cutscenes/beats/MudPieMakerProps.gd")

var stand: Node2D
var tins: Array = []
var pies: Array = []
var gauge: Node2D
var dozen: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.MEADOW
	_stage_townsfolk(3, _vp.x * 0.66, _vp.x * 0.88)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.46, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.55)
	stand = Props.make_stand(_vp.x * 0.16)
	stand.position = Vector2(_vp.x * 0.30, _vp.y * GROUND_FRACTION)
	stand.z_index = 3
	world.add_child(stand)
	var table_y := _vp.y * GROUND_FRACTION + Props.TABLE_TOP_Y() * _content_scale
	for i in range(3):
		var tin := Props.make_tin(_content_scale * 1.5)
		tin.position = Vector2(_vp.x * 0.30 + (float(i) - 1.0) * 40.0 * _content_scale, table_y)
		tin.z_index = 4
		world.add_child(tin)
		tins.append(tin)
	gauge = Props.make_gauge(_content_scale * 1.3)
	gauge.position = Vector2(_vp.x * 0.41, _vp.y * GROUND_FRACTION)
	gauge.z_index = 3
	world.add_child(gauge)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()

## Impact frame lands AT the stand's tabletop, where the pies appear.
func _impact_point() -> Vector2:
	return stand.position + Vector2(0.0, Props.TABLE_TOP_Y() * _content_scale - 20.0 * _content_scale)

## BEAT 2 — the bake. Full impact stack at the stand while each tin swaps to
## a finished pie and steam puffs rise on the very same frame.
func _on_impact() -> void:
	super._on_impact()
	var table_y := _vp.y * GROUND_FRACTION + Props.TABLE_TOP_Y() * _content_scale
	for i in range(tins.size()):
		var tin := tins[i] as Node2D
		var pie := Props.make_pie(_content_scale * 1.5)
		pie.position = tin.position
		pie.z_index = 4
		pie.scale = Vector2.ONE * 0.01
		world.add_child(pie)
		pies.append(pie)
		var swap := _ct(tin)
		swap.tween_property(tin, "scale:y", 0.01, 0.07) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		swap.tween_callback(tin.queue_free)
		var pop := _ct(pie)
		pop.tween_interval(0.06)
		pop.tween_property(pie, "scale", Vector2.ONE * _content_scale * 1.5, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Steam puffs on the impact frame — flat circles rising and fading.
		for k in range(3):
			var puff := Polygon2D.new()
			puff.polygon = Props._ellipse(5.0 + 1.5 * float(k), 4.0, 10)
			puff.position = pie.position + Vector2((float(k) - 1.0) * 7.0 * _content_scale, -22.0 * _content_scale)
			puff.color = Props.STEAM
			puff.z_index = 8
			world.add_child(puff)
			var rise := _ct(puff)
			rise.tween_interval(0.05 * float(k))
			rise.tween_property(puff, "position:y", puff.position.y - 34.0 * _content_scale, 0.55) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			rise.parallel().tween_property(puff, "scale", Vector2(1.6, 1.6), 0.55)
			rise.parallel().tween_property(puff, "modulate:a", 0.0, 0.55) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			rise.tween_callback(puff.queue_free)
	# The gauge fills to green.
	var fill := gauge.get_node("Fill") as Polygon2D
	fill.color = Props.FILL_GREEN
	var fill_up := _ct(fill)
	fill_up.tween_property(fill, "scale:y", 0.75, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## BEAT 3 — the queue forms instantly and the mayor buys a dozen.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.set_expression(CartoonActor.Mood.SMUG)
	# The queue snaps into line — instant, orderly, hungry.
	var queue_x := [0.60, 0.68, 0.76]
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_property(townsfolk[i], "position:x", _vp.x * queue_x[i], 0.22) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.CHEER))
		tw.tween_callback(townsfolk[i].hop.bind(16.0, 0.26))
	# The mayor steps up and buys a dozen.
	var step := _ct()
	step.tween_property(mayor, "position:x", _vp.x * 0.40, 0.20) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	step.tween_callback(mayor.set_arm_pose.bind(CartoonActor.ArmPose.REACH))
	step.tween_callback(mayor.hop.bind(14.0, 0.26))
	# A dozen mini-pies stack up in front of him.
	for i in range(12):
		var mini := Props.make_pie(_content_scale * 0.55)
		var col := i % 4
		var row := int(i / 4.0)
		mini.position = stand.position + Vector2(
			-40.0 * _content_scale + 20.0 * float(col) * _content_scale,
			(Props.TABLE_TOP_Y() - 8.0 - 10.0 * float(row)) * _content_scale
		)
		mini.z_index = 5
		mini.scale = Vector2.ONE * 0.01
		world.add_child(mini)
		dozen.append(mini)
		var stack := _ct(mini)
		stack.tween_interval(0.04 * float(i))
		stack.tween_property(mini, "scale", Vector2.ONE * _content_scale * 0.55, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The finished pies jiggle proudly.
	for i in range(pies.size()):
		var pie := pies[i] as Node2D
		var wob := _ct(pie)
		wob.tween_interval(0.05 * float(i))
		wob.tween_property(pie, "rotation", 0.07, 0.09) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wob.tween_property(pie, "rotation", -0.07, 0.09) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		wob.tween_property(pie, "rotation", 0.0, 0.09) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mayor.hop(16.0, 0.30)

