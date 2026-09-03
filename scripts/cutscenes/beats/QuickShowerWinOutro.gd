## QuickShower - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/QuickShowerWinOutro.tscn

extends MicrogameOutroBase

## Quick Shower — WIN clip.
## res://scenes/ui/cutscenes/beats/QuickShowerWinOutro.tscn
##
## BEAT 1  The street outside the bathroom, queue hopeful.
## BEAT 2  (impact) The "30-SECOND SHOWER RECORD!" banner unfurls with a
##         SNAP — poles pop, cloth drops — full impact stack on the tick.
## BEAT 3  A towel-clad parade marches down the main street, carrying
##         Dribble on a giant towel.

const Props := preload("res://scripts/cutscenes/beats/QuickShowerProps.gd")

var banner: Node2D
var doorway: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG_BATH
	_stage_townsfolk(3, _vp.x * 0.56, _vp.x * 0.72)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.50, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.42)
	# The bathroom door stands at the right as the parade's origin.
	var door_w := _vp.x * 0.12
	var door_h := _vp.y * 0.28
	doorway = Props.make_door(door_w, door_h)
	doorway.position = Vector2(_vp.x * 0.84, _vp.y * GROUND_FRACTION)
	doorway.z_index = 3
	world.add_child(doorway)
	# Record banner, dormant above the street until the snap.
	banner = Props.make_banner(_vp.x * 0.30, _vp.y * 0.11)
	banner.position = Vector2(_vp.x * 0.42, _vp.y * 0.18)
	banner.z_index = 6
	banner.scale = Vector2(0.01, 0.01)
	world.add_child(banner)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.BRACE)
		t.start_idle()

## Impact frame is the banner snap, dead centre over the street.
func _impact_point() -> Vector2:
	return banner.position

## BEAT 2 — SNAP: the record banner unfurls. Full impact stack on the tick.
func _on_impact() -> void:
	super._on_impact()
	# Poles pop first, then the cloth unfurls downward with overshoot.
	var poles := _ct(banner)
	poles.tween_property(banner, "scale", Vector2(1.0, 0.01), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	poles.tween_property(banner, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var cloth := banner.get_node("Cloth") as Polygon2D
	cloth.scale = Vector2(1.0, 0.01)
	var unfurl := _ct(cloth)
	unfurl.tween_interval(0.07)
	unfurl.tween_property(cloth, "scale", Vector2(1.06, 1.0), 0.13) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	unfurl.tween_property(cloth, "scale", Vector2.ONE, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The whole cast snaps to attention.
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.set_expression(CartoonActor.Mood.SMUG)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.hop(18.0, 0.30)
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.05 * float(i))
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.CHEER))
		tw.tween_callback(townsfolk[i].hop.bind(16.0, 0.26))

## BEAT 3 — the towel parade. Two towel-clad marchers carry a giant towel
## with Dribble riding it, down the main street.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	var towel_size := _vp.y * 0.30
	# Marchers enter from the left, already walking.
	var m1 := Props.make_towel_marcher(towel_size, Props.TOWEL)
	var m2 := Props.make_towel_marcher(towel_size, Props.TOWEL_STRIPE)
	var carrier_gap := _vp.x * 0.10
	var start_left := _vp.x * 0.24
	m1.position = Vector2(start_left, _vp.y * GROUND_FRACTION)
	m2.position = Vector2(start_left + carrier_gap, _vp.y * GROUND_FRACTION)
	m1.z_index = 8
	m2.z_index = 8
	world.add_child(m1)
	world.add_child(m2)
	# Giant towel sagging between the carriers.
	var towel := Polygon2D.new()
	towel.name = "GiantTowel"
	towel.polygon = PackedVector2Array([
		Vector2(0.0, -towel_size * 0.24), Vector2(carrier_gap, -towel_size * 0.24),
		Vector2(carrier_gap, -towel_size * 0.16), Vector2(0.0, -towel_size * 0.16),
	])
	towel.color = Props.TOWEL
	towel.position = m1.position
	towel.z_index = 7
	world.add_child(towel)
	# The march: everything glides right together, walk-bounce included.
	var travel := _vp.x * 0.62
	var march_time := _payoff_sec()
	var m1_go := _ct(m1)
	m1_go.tween_property(m1, "position:x", m1.position.x + travel, march_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var m2_go := _ct(m2)
	m2_go.tween_property(m2, "position:x", m2.position.x + travel, march_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Towel tracks the carriers and sags deeper mid-step.
	var towel_go := _ct()
	towel_go.tween_method(
		func(t: float) -> void:
			var lx := m1.position.x
			var rx := m2.position.x
			var sag := sin(t * PI) * 8.0 * _content_scale
			var pts := PackedVector2Array([
				Vector2(0.0, -towel_size * 0.24), Vector2(rx - lx, -towel_size * 0.24),
				Vector2(rx - lx, -towel_size * 0.16 + sag), Vector2(0.0, -towel_size * 0.16 + sag),
			])
			towel.polygon = pts
			towel.position = Vector2(lx, _vp.y * GROUND_FRACTION),
		0.0, 1.0, march_time
	)
	# Dribble rides the towel, bobbing with the walk.
	var ride_start := Vector2(start_left + carrier_gap * 0.5, _vp.y * GROUND_FRACTION - towel_size * 0.20)
	var ride_end := ride_start + Vector2(travel, 0.0)
	dribble.position = ride_start
	var ride := _ct()
	ride.tween_method(
		func(t: float) -> void:
			var pos := ride_start.lerp(ride_end, t)
			pos.y -= absf(sin(t * PI * 6.0)) * 7.0 * _content_scale
			(dribble as Node2D).position = pos,
		0.0, 1.0, march_time
	)
	# Marchers' walk cycle.
	for m in [m1, m2]:
		var marcher := m as Node2D
		var bob := _ct(marcher).set_loops(int(march_time / 0.24))
		bob.tween_property(marcher, "rotation", 0.08, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(marcher, "rotation", -0.08, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Banner waves overhead; town + mayor cheer the parade on.
	var wave := _ct(banner).set_loops(6)
	wave.tween_property(banner, "rotation", 0.035, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wave.tween_property(banner, "rotation", -0.035, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.07 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(16.0, 0.26))
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.hop(16.0, 0.28)

