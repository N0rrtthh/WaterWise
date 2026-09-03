## CatchTheRain - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/CatchTheRainWinOutro.tscn

extends MicrogameOutroBase

## Catch The Rain — WIN outro.
## res://scenes/ui/cutscenes/beats/CatchTheRainWinOutro.tscn
##
## BEAT 1  The drum sits brim-full; the storm front thins; the town gathers.
## BEAT 2  IMPACT — the drum overflows: a rainbow arcs out of the spilling
##         water (particle stream + rainbow gradient under a static arc).
## BEAT 3  The overflow becomes a rain shower and the whole town dances in it;
##         Mayor Ripple conducts, Dribble spins under the drops.

const Props := preload("res://scripts/cutscenes/beats/CatchTheRainProps.gd")

const RAINBOW := [
	Color(0.93, 0.30, 0.30), Color(0.96, 0.70, 0.25), Color(0.95, 0.88, 0.35),
	Color(0.45, 0.85, 0.50), Color(0.40, 0.68, 0.95), Color(0.62, 0.48, 0.90),
]

var drum: Node2D
var rainbow: Node2D
var clouds: Node2D

func _setup_stage() -> void:
	# The storm is passing: pale, drifting clouds instead of the intro's bank.
	clouds = Node2D.new()
	clouds.name = "PassingClouds"
	clouds.z_index = -4
	for i in range(3):
		var c := Props.make_cloud(1.1)
		c.modulate = Color(1, 1, 1, 0.65)
		c.position = Vector2(_vp.x * (0.20 + 0.30 * float(i)), _vp.y * 0.12)
		clouds.add_child(c)
	world.add_child(clouds)

	_stage_townsfolk(5, _vp.x * 0.10, _vp.x * 0.64)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.80, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.46)

	drum = Props.make_drum(true)
	drum.name = "RainDrum"
	drum.position = Vector2(_vp.x * 0.36, _vp.y * GROUND_FRACTION)
	drum.scale = Vector2.ONE * _content_scale * 1.15
	drum.z_index = -1
	world.add_child(drum)
	_make_rainbow()

## The static rainbow arc: concentric semicircle strokes springing from the
## drum's overflow point, hidden until the impact tick.
func _make_rainbow() -> void:
	rainbow = Node2D.new()
	rainbow.name = "Rainbow"
	rainbow.position = drum.position + Vector2(0.0, -50.0 * _content_scale)
	rainbow.z_index = -1
	rainbow.modulate.a = 0.0
	for i in range(RAINBOW.size()):
		var r := (46.0 + 13.0 * float(i)) * _content_scale
		var arc := Line2D.new()
		var pts := PackedVector2Array()
		for j in range(17):
			var a := PI - PI * float(j) / 16.0
			pts.append(Vector2(cos(a) * r, sin(a) * r))
		arc.points = pts
		arc.width = 7.0 * _content_scale
		arc.default_color = RAINBOW[i]
		rainbow.add_child(arc)
	world.add_child(rainbow)

## BEAT 1 — brim-full drum, proud Dribble, gathering town.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	for t in townsfolk:
		t.start_idle()
	# The storm front drifts off during the setup beat.
	var drift := _ct()
	drift.tween_property(clouds, "position:x", _vp.x * 0.30, _setup_sec() + _impact_hold_sec()) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _impact_point() -> Vector2:
	if is_instance_valid(drum):
		return drum.position + Vector2(0.0, -84.0 * _content_scale)
	return super()


## BEAT 2 — overflow! super() fires punch + flash + burst + stinger; on top of
## that the rainbow springs in and a rainbow-gradient stream arcs out.
func _on_impact() -> void:
	super._on_impact()
	_spring_rainbow()
	_overflow_stream()
	# The drum takes a full-body wobble as it spills over.
	var wob := _ct()
	wob.tween_property(drum, "scale", drum.scale * Vector2(1.08, 0.92), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wob.tween_property(drum, "scale", Vector2.ONE * _content_scale * 1.15, 0.16) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _spring_rainbow() -> void:
	rainbow.scale = Vector2(0.55, 0.55)
	var t := _ct().set_parallel(true)
	t.tween_property(rainbow, "modulate:a", 0.92, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(rainbow, "scale", Vector2.ONE, 0.30) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## One-shot GPUParticles2D arcing from the drum rim — the gradient carries the
## rainbow; gravity pulls the stream down and to the right like a spill arc.
func _overflow_stream() -> void:
	var p := GPUParticles2D.new()
	p.name = "Overflow"
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.amount = 42
	p.lifetime = 1.15
	p.position = _impact_point()
	p.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 8.0
	m.direction = Vector3(0, -1, 0)
	m.spread = 11.0
	m.initial_velocity_min = 340.0
	m.initial_velocity_max = 500.0
	m.gravity = Vector3(60.0, 760.0, 0)
	m.color_initial_ramp = _ramp(RAINBOW + [Color(1, 1, 1)])
	m.scale_min = 0.6
	m.scale_max = 1.1
	p.process_material = m
	p.z_index = 12
	world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var safety := _ct()
	safety.tween_interval(2.5)
	safety.tween_callback(p.queue_free)

## BEAT 3 — the overflow becomes a shower and the town dances in it.
func _beat_payoff() -> void:
	_start_shower()
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.spin(1.0, 0.55)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.hop(38.0, 0.4)
	for i in range(townsfolk.size()):
		# Two staggered dance waves across the crowd.
		for wave in range(2):
			var tw := _ct()
			tw.tween_interval(0.13 * float(i) + 0.45 * float(wave))
			tw.tween_callback(townsfolk[i].hop.bind(30.0, 0.32))

## Continuous light rain across the whole frame for the payoff; self-frees.
func _start_shower() -> void:
	var p := GPUParticles2D.new()
	p.name = "Shower"
	p.amount = 40
	p.lifetime = 0.7
	p.preprocess = 0.35
	p.position = Vector2(_vp.x * 0.5, -10.0)
	p.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(_vp.x * 0.55, 6.0, 1.0)
	m.direction = Vector3(0, -1, 0)
	m.spread = 3.0
	m.initial_velocity_min = 90.0
	m.initial_velocity_max = 150.0
	m.gravity = Vector3(0, 1250, 0)
	m.color_initial_ramp = _ramp([
		Color(0.55, 0.82, 1.0), Color(0.75, 0.92, 1.0), Color(1, 1, 1),
	])
	m.scale_min = 0.4
	m.scale_max = 0.8
	p.process_material = m
	p.z_index = 12
	world.add_child(p)
	var safety := _ct()
	safety.tween_interval(2.5)
	safety.tween_callback(p.queue_free)
