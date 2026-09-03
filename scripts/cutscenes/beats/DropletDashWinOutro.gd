## DropletDash - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/DropletDashWinOutro.tscn

extends MicrogameOutroBase

## Droplet Dash — WIN outro.
## res://scenes/ui/cutscenes/beats/DropletDashWinOutro.tscn
##
## BEAT 1  The finish: the champion's glass sits on its gold podium; the crowd
##         packs the sidelines; Dribble sizes up the leap.
## BEAT 2  IMPACT — Dribble takes off in slow motion and SPLASH-LANDS in the
##         glass (the splash is the impact frame: flash + burst + stinger).
## BEAT 3  A confetti wave rolls across the crowd; Dribble waves from inside
##         his trophy glass like a proper champion.

const Props := preload("res://scripts/cutscenes/beats/DropletDashProps.gd")

var podium: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.COURSE_SKY
	world.get_node("Ground").color = Props.TRACK
	world.get_node("Dirt").color = Props.TRACK_DARK
	_stage_townsfolk(4, _vp.x * 0.08, _vp.x * 0.30)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.16, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.34)
	podium = Props.make_trophy_podium(_content_scale * 1.25)
	podium.position = Vector2(_vp.x * 0.64, _vp.y * GROUND_FRACTION)
	podium.z_index = -1
	world.add_child(podium)

## Local position of the glass water surface, in world space.
func _glass_target() -> Vector2:
	var glass: Node2D = podium.get_node("Glass")
	return podium.position + glass.position * podium.scale \
		+ Vector2(0.0, -18.0) * podium.scale

func _impact_point() -> Vector2:
	return _glass_target()

## BEAT 1 — pre-leap tension; the crowd hushes.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()

## BEAT 2 — the slow-motion champion leap. super() fires punch + flash +
## confetti burst + stinger at the glass; Dribble arcs over in slow-mo and
## SPLASH-LANDS: second flash + droplet burst on the splash frame.
func _on_impact() -> void:
	super()
	_slow_mo_leap()

## Quadratic arc from Dribble's mark into the glass, ~2x slower than any
## other beat move so it reads as slow-motion.
func _slow_mo_leap() -> void:
	var start := dribble.position
	var end := _glass_target() + Vector2(0.0, -20.0) * _content_scale
	var peak := 190.0 * _content_scale
	var fly := _ct()
	fly.tween_method(func(t: float) -> void:
		var p := start.lerp(end, t)
		p.y -= sin(t * PI) * peak
		dribble.position = p
		dribble.rig.rotation = sin(t * PI) * 0.45
	, 0.0, 1.0, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fly.tween_callback(_splash_land)

## The splash-landing: shrink into the glass, flash again, droplet burst,
## glass wobble.
func _splash_land() -> void:
	super._on_impact()
	dribble.rig.rotation = 0.0
	var in_glass := _glass_target()
	var shrink := _ct().set_parallel(true)
	shrink.tween_property(dribble, "position", in_glass, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shrink.tween_property(dribble, "scale", dribble.scale * 0.5, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_splash_burst(in_glass)
	var glass: Node2D = podium.get_node("Glass")
	var wobble := _ct(glass)
	wobble.tween_property(glass, "rotation", 0.12, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wobble.tween_property(glass, "rotation", -0.09, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	wobble.tween_property(glass, "rotation", 0.0, 0.10) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## One-shot droplet splash exploding upward out of the glass rim.
func _splash_burst(at: Vector2) -> void:
	var p := GPUParticles2D.new()
	p.name = "SplashBurst"
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.amount = 32
	p.lifetime = 0.7
	p.position = at
	p.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 42.0
	m.initial_velocity_min = 260.0
	m.initial_velocity_max = 520.0
	m.gravity = Vector3(0, 1100, 0)
	m.color_initial_ramp = _ramp([
		Props.WATER_FILL, Props.FALL, Color(1, 1, 1),
	])
	m.scale_min = 0.4
	m.scale_max = 0.9
	p.process_material = m
	p.z_index = 12
	world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var safety := _ct()
	safety.tween_interval(2.0)
	safety.tween_callback(p.queue_free)

## BEAT 3 — the confetti wave rolls across the crowd and everybody hops in a
## right-to-left ripple; Dribble waves from inside his glass.
func _beat_payoff() -> void:
	_confetti_wave()
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.set_expression(CartoonActor.Mood.SMUG)
	# Wave order: nearest the podium first, rolling left.
	var crowd: Array = townsfolk.duplicate()
	crowd.append(mayor)
	for member in crowd:
		var actor := member as CartoonActor
		var delay := clampf((actor.position.x) / _vp.x * 0.4, 0.0, 0.4)
		var tw := _ct()
		tw.tween_interval(delay)
		tw.tween_callback(actor.hop.bind(30.0, 0.34))
	# Champion's wave: little bobs above the glass rim.
	var wave := _ct().set_loops()
	wave.tween_property(dribble, "position:y", dribble.position.y - 8.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	wave.tween_property(dribble, "position:y", dribble.position.y, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## One-shot GPUParticles2D — a wide confetti sheet sweeping the crowd leftwards.
func _confetti_wave() -> void:
	var p := GPUParticles2D.new()
	p.name = "ConfettiWave"
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.amount = 60
	p.lifetime = 1.1
	p.position = Vector2(_vp.x * 0.34, _vp.y * GROUND_FRACTION - 60.0 * _content_scale)
	p.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(12.0, _vp.y * 0.16, 1.0)
	m.direction = Vector3(-1, -0.3, 0)
	m.spread = 24.0
	m.initial_velocity_min = 420.0
	m.initial_velocity_max = 760.0
	m.gravity = Vector3(0, 260, 0)
	m.color_initial_ramp = _ramp([
		Props.GOLD, Color(1, 1, 1), Props.WATER_FILL, Props.PENNANT,
	])
	m.scale_min = 0.5
	m.scale_max = 1.0
	p.process_material = m
	p.z_index = 11
	world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var safety := _ct()
	safety.tween_interval(2.5)
	safety.tween_callback(p.queue_free)

