## SpotTheSpeck - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/SpotTheSpeckIntro.tscn

extends MicrogameIntroBase

## Spot The Speck — CAUSE clip.
## res://scenes/ui/cutscenes/beats/SpotTheSpeckIntro.tscn
##
## BEAT 1  Glasses sit on the table, some visibly speckled; the town
##         waits eagerly to drink.
## BEAT 2  (flash-only impact) The magnifying glass hovers in and SNAPS
##         focus on a speck — the town recoils.
## BEAT 3  Dribble snatches the glasses for an emergency wash. SNAP into
##         gameplay.

const Props := preload("res://scripts/cutscenes/beats/SpotTheSpeckProps.gd")

var magnifier: Node2D
var glasses: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	_stage_townsfolk(2, _vp.x * 0.72, _vp.x * 0.84)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.94, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.24)
	var table := Props.make_table(_vp.x * 0.34, _vp.y * 0.16)
	table.position = Vector2(_vp.x * 0.42, _vp.y * GROUND_FRACTION)
	table.z_index = 3
	world.add_child(table)
	# A row of glasses: some clean, some visibly speckled.
	for setup in [[0.32, true], [0.40, false], [0.46, true], [0.54, false]]:
		var glass := Props.make_glass(_vp.y * 0.16, setup[1])
		glass.position = Vector2(_vp.x * setup[0],
			_vp.y * GROUND_FRACTION - _vp.y * 0.16)
		glass.z_index = 4
		world.add_child(glass)
		glasses.append(glass)
	# The magnifying glass starts off-screen left.
	magnifier = Props.make_magnifier(_vp.y * 0.34)
	magnifier.position = Vector2(-_vp.x * 0.12, _vp.y * 0.42)
	magnifier.rotation = -0.5
	magnifier.z_index = 7
	world.add_child(magnifier)
	camera.zoom = Vector2(1.15, 1.15)
	camera.position = _vp * 0.5

## BEAT 1 — glasses wait; the town salivates.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.HAPPY)
		t.start_idle()
	# The town leans forward, licking their lips (little eager hops).
	for i in range(townsfolk.size()):
		var eager := _ct(townsfolk[i]).set_loops(2)
		eager.tween_interval(0.3 * float(i))
		eager.tween_callback(townsfolk[i].hop.bind(8.0, 0.22))
	mayor.hop(6.0, 0.30)
	# A speckled glass shivers guiltily.
	var guilty := glasses[2] as Node2D
	var shiver := _ct(guilty).set_loops(3)
	shiver.tween_property(guilty, "rotation", 0.04, 0.10)
	shiver.tween_property(guilty, "rotation", -0.04, 0.10)
	shiver.tween_property(guilty, "rotation", 0.0, 0.08)

## BEAT 2 — the magnify-and-reveal. Intro contract: flash only.
func _on_impact() -> void:
	_impact_flash()
	# The magnifier sweeps in from off-screen and snaps over the speckled
	# glass.
	var target := (glasses[2] as Node2D).position \
		+ Vector2(0.0, -_vp.y * 0.30)
	var sweep := _ct(magnifier)
	sweep.tween_property(magnifier, "position", target, 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sweep.parallel().tween_property(magnifier, "rotation", 0.15, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sweep.tween_property(magnifier, "scale", Vector2(1.25, 1.25), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sweep.tween_property(magnifier, "scale", Vector2(1.1, 1.1), 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# The speckled glass swells under the lens — specks everywhere.
	var reveal := _ct(glasses[2] as Node2D)
	reveal.tween_property(glasses[2], "scale", Vector2(1.18, 1.18), 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(glasses[2], "scale", Vector2(1.0, 1.0), 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# The town recoils in shared horror.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(16.0, 0.24)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.PANIC)
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
	# Dribble gulps and steps up.
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)

## BEAT 3 — the snatch-and-wash.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	# Dribble dashes to the table.
	var dash := _ct()
	dash.tween_property(dribble, "position:x", _vp.x * 0.34, 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Grabs the worst offender and hauls it away.
	var haul := _ct(glasses[2] as Node2D)
	haul.tween_interval(0.16)
	haul.tween_property(glasses[2], "position",
		dribble.position + Vector2(0.0, -_vp.y * 0.12), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The town cranes forward for the verdict.
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	for i in range(townsfolk.size()):
		var crane := _ct()
		crane.tween_interval(0.2 * float(i))
		crane.tween_property(townsfolk[i], "position:x",
			townsfolk[i].position.x - _vp.x * 0.03, 0.24) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The magnifier hovers along, unconvinced.
	var follow := _ct(magnifier)
	follow.tween_interval(0.16)
	follow.tween_property(magnifier, "position",
		magnifier.position + Vector2(_vp.x * 0.10, -_vp.y * 0.02), 0.24) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
