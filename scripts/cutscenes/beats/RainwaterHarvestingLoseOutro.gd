## RainwaterHarvesting - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/RainwaterHarvestingLoseOutro.tscn

extends MicrogameOutroBase

## Rainwater Harvesting — LOSE clip.
## res://scenes/ui/cutscenes/beats/RainwaterHarvestingLoseOutro.tscn
##
## BEAT 1  A barrel tips and spills — the harvest is lost.
## BEAT 2  (impact) The duo spins and POINTS at each other — the
##         accusatory pose lands on the tick.
## BEAT 3  The unimpressed town lowers BOTH of them off the cliff together
##         on a single rope.

const Props := preload("res://scripts/cutscenes/beats/RainwaterHarvestingProps.gd")

const CLIFF_X := 0.94

var barrels: Array = []
var partner: CartoonActor
var rope: Polygon2D
var rope_anchor: Vector2

func _setup_stage() -> void:
	get_node("Backdrop").color = Color(0.82, 0.88, 0.86)
	_stage_townsfolk(2, _vp.x * 0.18, _vp.x * 0.28)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.76, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.44)
	var skins: Array[Color] = CastFactory.TOWNSFOLK_SKINS
	partner = _stage_actor(CastFactory.make_townsfolk(1)[0], _vp.x * 0.56)
	partner.set_skin(skins[0])
	# Two barrels: one upright-but-empty, one tipped and spilling.
	var b1 := Props.make_barrel(_vp.y * 0.24)
	b1.position = Vector2(_vp.x * 0.66, _vp.y * GROUND_FRACTION)
	b1.z_index = 4
	world.add_child(b1)
	var b2 := Props.make_barrel(_vp.y * 0.24)
	b2.position = Vector2(_vp.x * 0.76, _vp.y * GROUND_FRACTION)
	b2.z_index = 4
	b2.rotation = 1.35  # tipped on its side
	b2.position.y -= _vp.y * 0.05
	world.add_child(b2)
	var fill2 := b2.get_node("Fill") as Polygon2D
	fill2.scale = Vector2(1.0, 0.02)
	barrels = [b1, b2]
	# Spill puddle under the tipped barrel.
	var spill := Polygon2D.new()
	spill.name = "Spill"
	spill.polygon = Props._ellipse(_vp.x * 0.05, _vp.y * 0.012, 14)
	spill.position = Vector2(_vp.x * 0.79, _vp.y * GROUND_FRACTION - 4.0 * _content_scale)
	spill.color = Props.WATER_SOFT
	spill.z_index = 3
	world.add_child(spill)
	# The shared rope hangs from off-screen above the cliff.
	rope_anchor = Vector2(_vp.x * CLIFF_X, -_vp.y * 0.06)
	rope = Props.make_rope(10.0, 5.0 * _content_scale)
	rope.position = rope_anchor
	rope.z_index = 2
	rope.visible = false
	world.add_child(rope)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.set_arm_pose(CartoonActor.ArmPose.DROOP)
		t.start_idle()
	# The upright barrel gives up and tips over during the setup beat.
	var b1 := barrels[0] as Node2D
	var tip := _ct(b1)
	tip.tween_property(b1, "rotation", 1.5, _setup_sec() * 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tip.parallel().tween_property(b1, "position:y", b1.position.y - _vp.y * 0.05, _setup_sec() * 0.8)
	tip.parallel().tween_property(b1, "position:x", b1.position.x + _vp.x * 0.045, _setup_sec() * 0.8)
	# Spill puddle widens.
	var spill := world.get_node("Spill") as Polygon2D
	var spread := _ct(spill)
	spread.tween_property(spill, "scale", Vector2(1.7, 1.0), _setup_sec())

## Impact frame: the accusatory midpoint between the two.
func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.50, _vp.y * GROUND_FRACTION - _vp.y * 0.12)

## BEAT 2 — the blame. Full impact stack as both spin and POINT.
func _on_impact() -> void:
	super._on_impact()
	# Spin to face each other, then jab the accusing finger.
	for pair in [[dribble, -1.0], [partner, 1.0]]:
		var actor := pair[0] as CartoonActor
		var dir := pair[1] as float
		actor.set_expression(CartoonActor.Mood.PANIC)
		actor.set_arm_pose(CartoonActor.ArmPose.REACH)
		var jab := _ct(actor)
		jab.tween_property(actor, "rotation", 0.22 * dir, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		jab.tween_property(actor, "rotation", -0.06 * dir, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		jab.tween_property(actor, "rotation", 0.0, 0.10) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dribble.hop(18.0, 0.26)
	partner.hop(18.0, 0.26)
	# The town is NOT impressed: DROOP, deadpan.
	mayor.set_arm_pose(CartoonActor.ArmPose.DROOP)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.NEUTRAL)
	# The tipped barrels roll a little more, defeated.
	for b in range(barrels.size()):
		var barrel := barrels[b] as Node2D
		var settle := _ct(barrel)
		settle.tween_property(barrel, "rotation", barrel.rotation + 0.08, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		settle.tween_property(barrel, "rotation", barrel.rotation, 0.12) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 3 — the shared rope. The town lowers BOTH off the cliff together,
## unimpressed.
func _beat_payoff() -> void:
	mayor.set_expression(CartoonActor.Mood.SMUG)
	_rope_lowering()

func _rope_lowering() -> void:
	rope.visible = true
	# Harness bands strap around each of them.
	for actor in [dribble, partner]:
		var node := actor as CartoonActor
		var band := Props.make_harness(30.0 * _content_scale)
		band.position = Vector2(0.0, -_vp.y * 0.045)
		node.add_child(band)
	# Path: swing up to the cliff edge, then down over it.
	var start_mid := Vector2(_vp.x * 0.50, _vp.y * GROUND_FRACTION - _vp.y * 0.10)
	var edge := Vector2(_vp.x * CLIFF_X, _vp.y * GROUND_FRACTION - _vp.y * 0.16)
	var below := Vector2(_vp.x * (CLIFF_X + 0.03), _vp.y * 1.25)
	var gap := 26.0 * _content_scale
	var ride_time := _payoff_sec()
	# Dribble + partner ride the same parametric path, offset left/right.
	for pair in [[dribble, -gap], [partner, gap]]:
		var actor := pair[0] as CartoonActor
		var sway := _ct(actor).set_loops(int(ride_time / 0.3))
		sway.tween_property(actor, "rotation", 0.08, 0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(actor, "rotation", -0.08, 0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pair_go := _ct()
	pair_go.tween_method(
		func(t: float) -> void:
			var centre: Vector2
			if t < 0.45:
				var k := t / 0.45
				centre = start_mid.lerp(edge, k)
				centre.y -= sin(k * PI) * _vp.y * 0.06
			else:
				centre = edge.lerp(below, (t - 0.45) / 0.55)
			(dribble as Node2D).position = centre + Vector2(-gap, _vp.y * 0.02)
			(partner as Node2D).position = centre + Vector2(gap, _vp.y * 0.02)
			# Redraw the rope from the anchor to the pair's midpoint.
			var top := rope_anchor
			var rlen := centre.distance_to(top)
			rope.polygon = PackedVector2Array([
				Vector2(-2.5 * _content_scale, 0.0), Vector2(2.5 * _content_scale, 0.0),
				Vector2(2.5 * _content_scale, rlen), Vector2(-2.5 * _content_scale, rlen),
			])
			rope.rotation = (centre - top).angle() - PI * 0.5,
		0.0, 1.0, ride_time
	)
	var gone := _ct()
	gone.tween_interval(ride_time)
	gone.tween_callback(func() -> void:
		dribble.visible = false
		partner.visible = false
		rope.visible = false)
	# The town watches, unimpressed: DROOP, slow head-shakes.
	mayor.set_arm_pose(CartoonActor.ArmPose.DROOP)
	var shake := _ct(mayor).set_loops(3)
	shake.tween_property(mayor, "rotation", 0.06, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shake.tween_property(mayor, "rotation", -0.06, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.3 + 0.2 * float(i))
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.DROOP))

