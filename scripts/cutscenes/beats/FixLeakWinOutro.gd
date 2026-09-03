## FixLeak - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/FixLeakWinOutro.tscn

extends MicrogameOutroBase

## Fix The Leak — WIN outro.
## res://scenes/ui/cutscenes/beats/FixLeakWinOutro.tscn
##
## BEAT 1  The sealed pipe gleams; the waste meter sits back in the green.
## BEAT 2  IMPACT — light sweeps across the pipe like a polish pass (the
##         "light-sweep shader" frame) while super() fires punch + confetti
##         + stinger.
## BEAT 3  Mayor Ripple christens the pipe: he smashes a water bottle against
##         it — shards + a second flash — and the town cheers.

const Props := preload("res://scripts/cutscenes/beats/FixLeakProps.gd")

const PIPE_Y := 0.36

var pipe: Node2D
var meter: Node2D
var needle: Polygon2D
var bottle: Node2D
var gleam: Polygon2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.WALL
	get_node("World/Ground").color = Props.FLOOR
	get_node("World/Dirt").color = Props.FLOOR.darkened(0.25)
	_stage_townsfolk(3, _vp.x * 0.10, _vp.x * 0.30)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.72, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.46)
	pipe = Props.make_pipe(_vp.x * 0.46, [])
	pipe.position = Vector2(_vp.x * 0.44, _vp.y * PIPE_Y)
	world.add_child(pipe)
	# The gleam band — parked off the pipe's left end until the impact tick.
	gleam = Polygon2D.new()
	gleam.name = "Gleam"
	var half := _vp.x * 0.23
	gleam.polygon = PackedVector2Array([
		Vector2(-14.0, -13.0), Vector2(0.0, -13.0),
		Vector2(14.0, 13.0), Vector2(0.0, 13.0),
	])
	gleam.color = Color(1.0, 0.98, 0.82, 0.0)
	gleam.position = pipe.position + Vector2(-half, 0.0)
	gleam.z_index = 7
	world.add_child(gleam)
	meter = Props.make_waste_meter(1.15 * _content_scale)
	meter.position = Vector2(_vp.x * 0.10, _vp.y * 0.16)
	meter.z_index = 8
	world.add_child(meter)
	needle = meter.get_node("Needle")
	# Bottle held at the mayor's side, ready for the christening.
	bottle = Props.make_bottle(_content_scale * CastFactory.MAYOR_SCALE.x)
	bottle.position = mayor.position \
		+ Vector2(30.0, -34.0) * CastFactory.MAYOR_SCALE.x * _content_scale
	bottle.rotation = 0.5
	bottle.z_index = 5
	world.add_child(bottle)

func _impact_point() -> Vector2:
	return pipe.position

## BEAT 1 — quiet pride before the christening.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_expression(CartoonActor.Mood.SMUG)
	for t in townsfolk:
		t.start_idle()
	needle.rotation = 0.15

## BEAT 2 — the light sweep. super() fires punch + confetti + stinger; a
## gold gleam band wipes across the full pipe length on the same tick.
func _on_impact() -> void:
	super()
	_light_sweep()

func _light_sweep() -> void:
	var half := _vp.x * 0.23
	var sweep := _ct(gleam)
	sweep.set_parallel(true)
	sweep.tween_property(gleam, "position:x", pipe.position.x + half, 0.26) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sweep.tween_property(gleam, "color:a", 0.9, 0.08)
	sweep.tween_property(gleam, "color:a", 0.0, 0.18).set_delay(0.08)

## BEAT 3 — the christening: the mayor smashes the bottle against the pipe
## (shards + second flash), then the whole town cheers.
func _beat_payoff() -> void:
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	_christen()

## Bottle arcs from the mayor's hand into the pipe and shatters on it.
func _christen() -> void:
	var hit := pipe.position + Vector2(_vp.x * 0.13, 0.0)
	var swing := _ct(bottle)
	swing.tween_property(bottle, "rotation", -0.9, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swing.tween_property(bottle, "position", hit, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	swing.parallel().tween_property(bottle, "rotation", 0.6, 0.16)
	swing.tween_callback(_smash.bind(hit))

func _smash(hit: Vector2) -> void:
	super._on_impact()
	bottle.visible = false
	_glass_shards(hit)
	# The pipe rings from the christening blow.
	var ring := _ct(pipe)
	ring.tween_property(pipe, "scale", Vector2(1.03, 0.95), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring.tween_property(pipe, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_cheer()

func _glass_shards(at: Vector2) -> void:
	var p := GPUParticles2D.new()
	p.name = "Shards"
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.amount = 24
	p.lifetime = 0.7
	p.position = at
	p.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 70.0
	m.initial_velocity_min = 220.0
	m.initial_velocity_max = 460.0
	m.gravity = Vector3(0, 1100, 0)
	m.color_initial_ramp = _ramp([
		Color(0.85, 0.95, 0.88), Color(1, 1, 1), Props.BOTTLE_GLASS,
	])
	m.scale_min = 0.3
	m.scale_max = 0.6
	p.process_material = m
	p.z_index = 12
	world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var safety := _ct()
	safety.tween_interval(2.0)
	safety.tween_callback(p.queue_free)

func _cheer() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.CHEER)
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.10 * float(i))
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.CHEER))
		tw.tween_callback(townsfolk[i].hop.bind(30.0, 0.34))
	mayor.hop(32.0, 0.36)
	dribble.hop(34.0, 0.34)

