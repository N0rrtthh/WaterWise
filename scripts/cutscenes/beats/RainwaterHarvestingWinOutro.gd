## RainwaterHarvesting - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/RainwaterHarvestingWinOutro.tscn

extends MicrogameOutroBase

## Rainwater Harvesting — WIN clip.
## res://scenes/ui/cutscenes/beats/RainwaterHarvestingWinOutro.tscn
##
## BEAT 1  The barrels brim under a softening drizzle.
## BEAT 2  (impact) They OVERFLOW — droplets burst outward in a heart-
##         shaped splash pattern above the barrels.
## BEAT 3  The town gives the duo a synchronized clap.

const Props := preload("res://scripts/cutscenes/beats/RainwaterHarvestingProps.gd")

var barrels: Array = []
var partner: CartoonActor

func _setup_stage() -> void:
	get_node("Backdrop").color = Color(0.82, 0.88, 0.86)
	_stage_townsfolk(2, _vp.x * 0.18, _vp.x * 0.28)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.78, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.36)
	var skins: Array[Color] = CastFactory.TOWNSFOLK_SKINS
	partner = _stage_actor(CastFactory.make_townsfolk(1)[0], _vp.x * 0.68)
	partner.set_skin(skins[0])
	for x in [0.47, 0.59]:
		var barrel := Props.make_barrel(_vp.y * 0.24)
		barrel.position = Vector2(_vp.x * x, _vp.y * GROUND_FRACTION)
		barrel.z_index = 4
		world.add_child(barrel)
		var fill := barrel.get_node("Fill") as Polygon2D
		fill.scale = Vector2(1.0, 0.95)  # brimming
		barrels.append(barrel)
	# Drizzle left over from the storm.
	var cloud := Props.make_cloud(_vp.x * 0.22)
	cloud.position = Vector2(_vp.x * 0.53, _vp.y * 0.14)
	cloud.z_index = 6
	world.add_child(cloud)
	var rain := Props.make_rain(_content_scale, _dot_texture())
	rain.position = cloud.position + Vector2(0.0, _vp.y * 0.05)
	rain.z_index = 5
	rain.scale = Vector2(0.6, 0.6)
	world.add_child(rain)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	partner.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	for t in townsfolk:
		t.start_idle()

## Impact frame: mid-air between the two brimming barrels.
func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.53, _vp.y * GROUND_FRACTION - _vp.y * 0.34)

## BEAT 2 — the overflow. Full impact stack while droplets burst outward
## along a heart curve above the barrels.
func _on_impact() -> void:
	super._on_impact()
	# Heart-curve droplet burst: x = 16 sin³t, y = 13cos t − 5cos 2t
	# − 2cos 3t − cos 4t (cartographic heart, y-up). Droplets start on the
	# curve and fly outward along their normal-ish radial direction.
	var centre := _impact_point()
	var scale_f := _vp.y * 0.011
	for i in range(20):
		var t := TAU * float(i) / 20.0
		var hx := 16.0 * pow(sin(t), 3.0)
		var hy := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		var on_curve := centre + Vector2(hx, -hy) * scale_f
		var drop := Polygon2D.new()
		drop.polygon = Props._ellipse(8.0 * _content_scale, 6.0 * _content_scale, 10)
		drop.position = on_curve
		drop.color = Props.WATER_SOFT if i % 2 == 0 else Props.WATER
		drop.z_index = 9
		world.add_child(drop)
		var radial := (on_curve - centre).normalized()
		if radial == Vector2.ZERO:
			radial = Vector2.UP
		var far := on_curve + radial * 46.0 * _content_scale + Vector2(0.0, 20.0 * _content_scale)
		var fly := _ct(drop)
		fly.tween_property(drop, "position", far, 0.40) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(drop, "modulate:a", 0.0, 0.40) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.tween_callback(drop.queue_free)
	# Barrels slosh with pride.
	for b in range(barrels.size()):
		var barrel := barrels[b] as Node2D
		var slosh := _ct(barrel)
		slosh.tween_property(barrel, "rotation", 0.06, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		slosh.tween_property(barrel, "rotation", -0.06, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		slosh.tween_property(barrel, "rotation", 0.0, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	partner.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)

## BEAT 3 — the synchronized clap: the whole town claps on the same beat,
## the duo takes a bow.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	partner.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_expression(CartoonActor.Mood.SMUG)
	# The entire cast hops ON THE SAME BEAT — one synchronized clap rhythm.
	var cast: Array = [dribble, partner, mayor]
	for t in townsfolk:
		cast.append(t)
	for i in range(cast.size()):
		var member := cast[i] as CartoonActor
		member.set_arm_pose(CartoonActor.ArmPose.CHEER)
		var clap := _ct(member).set_loops(4)
		clap.tween_interval(0.02 * float(i))  # tiny stagger, same tempo
		clap.tween_callback(member.hop.bind(14.0, 0.18))
		clap.tween_interval(0.22)
	# The duo bows to each other: mirrored leans.
	var bow_l := _ct(dribble)
	bow_l.tween_property(dribble, "rotation", 0.12, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bow_l.tween_property(dribble, "rotation", 0.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var bow_r := _ct(partner)
	bow_r.tween_property(partner, "rotation", -0.12, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bow_r.tween_property(partner, "rotation", 0.0, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The drizzle fades to nothing as the town celebrates.

