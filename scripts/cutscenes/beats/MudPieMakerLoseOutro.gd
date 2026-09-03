## MudPieMaker - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/MudPieMakerLoseOutro.tscn

extends MicrogameOutroBase

## Mud Pie Maker — LOSE clip.
## res://scenes/ui/cutscenes/beats/MudPieMakerLoseOutro.tscn
##
## BEAT 1  A pie lifts off the stand and arcs toward Dribble's face —
##         beat 1 ends exactly as it arrives.
## BEAT 2  (impact) SPLAT. The pie detonates directly in Dribble's face:
##         super() lands ON the splat with a custom mud burst. Dribble is
##         replaced by a frozen mud statue of himself.
## BEAT 3  The town tips the statue over; it rolls away down the cliff.

const Props := preload("res://scripts/cutscenes/beats/MudPieMakerProps.gd")

const CLIFF_X := 0.94

var stand: Node2D
var flying_pie: Node2D
var statue: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.MEADOW
	_stage_townsfolk(3, _vp.x * 0.48, _vp.x * 0.68)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.58, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.82)
	stand = Props.make_stand(_vp.x * 0.16)
	stand.position = Vector2(_vp.x * 0.26, _vp.y * GROUND_FRACTION)
	stand.z_index = 3
	world.add_child(stand)
	var table_y := _vp.y * GROUND_FRACTION + Props.TABLE_TOP_Y() * _content_scale
	for i in range(2):
		var tin := Props.make_tin(_content_scale * 1.5)
		tin.position = Vector2(_vp.x * 0.26 + (float(i) - 0.5) * 40.0 * _content_scale, table_y)
		tin.z_index = 4
		world.add_child(tin)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.drip_sweat()
	for t in townsfolk:
		t.start_idle()
	_impact_arrival()

## BEAT 1 — the pie launches. A finished pie arcs off the stand toward
## Dribble's face; its flight lands exactly on the impact tick.
func _impact_arrival() -> void:
	flying_pie = Props.make_pie(_content_scale * 1.5)
	flying_pie.position = stand.position + Vector2(0.0, Props.TABLE_TOP_Y() * _content_scale)
	flying_pie.z_index = 8
	world.add_child(flying_pie)
	var face := dribble.position + Vector2(0.0, -96.0 * _content_scale)
	var start := flying_pie.position
	var flight := _ct()
	flight.tween_method(
		func(t: float) -> void:
			var pos := start.lerp(face, t)
			pos.y -= sin(t * PI) * _vp.y * 0.14
			(flying_pie as Node2D).position = pos,
		0.0, 1.0, _setup_sec()
	)
	flight.parallel().tween_property(flying_pie, "rotation", TAU, _setup_sec())

## BEAT 2 — the splat. Impact frame ON the detonation; Dribble becomes a
## mud statue on the same tick.
func _on_impact() -> void:
	super()
	# Mud detonation: radial splats in the mud palette (custom burst).
	var centre := dribble.position + Vector2(0.0, -96.0 * _content_scale)
	for i in range(10):
		var splat := Polygon2D.new()
		splat.polygon = Props._ellipse(3.0 + 2.0 * float(i % 3), 2.5, 8)
		splat.position = centre
		splat.color = Props.MUD if i % 2 == 0 else Props.MUD_WET
		splat.z_index = 9
		world.add_child(splat)
		var a := TAU * float(i) / 10.0 - PI * 0.5
		var far := centre + Vector2(cos(a), sin(a)) * (52.0 + 14.0 * float(i % 4)) * _content_scale
		var fly := _ct(splat)
		fly.tween_property(splat, "position", far, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(splat, "modulate:a", 0.0, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.tween_callback(splat.queue_free)
	# Crust scraps: the tin pings off.
	if flying_pie != null and is_instance_valid(flying_pie):
		var tin_ping := _ct(flying_pie)
		tin_ping.tween_property(flying_pie, "position",
			centre + Vector2(-70.0 * _content_scale, 40.0 * _content_scale), 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tin_ping.parallel().tween_property(flying_pie, "rotation", TAU * 2.0, 0.25)
		tin_ping.tween_callback(flying_pie.queue_free)
	# The swap: Dribble out, statue in — frozen mid-SPLAT face.
	dribble.visible = false
	statue = Props.make_mud_statue(_content_scale * 1.1)
	statue.position = dribble.position
	statue.z_index = 3
	world.add_child(statue)
	# A ground splat patch beneath him.
	var patch := Polygon2D.new()
	patch.polygon = Props._ellipse(34.0 * _content_scale, 7.0 * _content_scale, 14)
	patch.position = dribble.position
	patch.color = Props.MUD_WET
	patch.z_index = 2
	world.add_child(patch)

## BEAT 3 — the town tips the statue over; it rolls down the cliff.
func _beat_payoff() -> void:
	mayor.set_expression(CartoonActor.Mood.SMUG)
	# Two townsfolk flank the statue; the third waves it goodbye.
	var flanks := [0, 2]
	for j in range(flanks.size()):
		var side := 1 if j == 1 else -1
		var mover := _ct()
		mover.tween_property(townsfolk[flanks[j]], "position:x",
			statue.position.x + 40.0 * _content_scale * float(side), 0.20) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		mover.tween_callback(townsfolk[flanks[j]].set_arm_pose.bind(CartoonActor.ArmPose.BRACE))
	townsfolk[1].set_arm_pose(CartoonActor.ArmPose.CHEER)
	townsfolk[1].hop(14.0, 0.28)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.hop(14.0, 0.28)
	_tip_statue()

## The tip-and-roll: pivot over on its base, then roll (rotation keeps
## increasing) right off the cliff edge and down out of frame.
func _tip_statue() -> void:
	var tip := _ct(statue)
	tip.tween_interval(0.16)
	tip.tween_property(statue, "rotation", PI * 0.5, 0.26) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tip.tween_callback(_roll_statue)

func _roll_statue() -> void:
	# Deferred impact stack at the tipping (non-tick frame). super._on_impact()
	# delivers all of it -- flash, camera punch, stinger, burst -- so the explicit punch and
	# stinger that used to bracket this line were duplicates: two pool players on
	# the identical stinger stream in one frame (measured simul=2 in
	# tools/VerifyOutroImpact.tscn) and two tweens fighting over camera.zoom.
	super._on_impact()
	# Roll: pivot swings around, statue runs right and falls off the cliff.
	var edge_x := _vp.x * CLIFF_X
	var roll := _ct(statue)
	roll.tween_property(statue, "position:x", edge_x, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	roll.parallel().tween_property(statue, "rotation", PI * 1.5, 0.30)
	# Off the edge — falls away while still rolling.
	roll.tween_property(statue, "position",
		Vector2(_vp.x * (CLIFF_X + 0.06), _vp.y * 1.15), 0.42) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	roll.parallel().tween_property(statue, "rotation", TAU * 1.5, 0.42)
	roll.tween_callback(statue.queue_free)
	# Town + mayor watch it go, then deadpan-cheer the clean-up.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.40 + 0.07 * float(i))
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.CHEER))
		tw.tween_callback(townsfolk[i].hop.bind(14.0, 0.26))
	var mayor_tw := _ct()
	mayor_tw.tween_interval(0.55)
	mayor_tw.tween_callback(mayor.hop.bind(12.0, 0.26))

