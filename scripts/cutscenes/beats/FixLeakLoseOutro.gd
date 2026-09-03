## FixLeak - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/FixLeakLoseOutro.tscn

extends MicrogameOutroBase

## Fix The Leak — LOSE outro.
## res://scenes/ui/cutscenes/beats/FixLeakLoseOutro.tscn
##
## BEAT 1  The pipe's one big hole hisses; Dribble stands right over it; the
##         waste meter's needle quivers in the red.
## BEAT 2  A GEYSER erupts and launches Dribble straight up and off past the
##         town skyline — the FULL impact stack (punch + flash + burst +
##         stinger) fires AT PEAK LAUNCH, not on the beat tick.
## BEAT 3  His hat, shaken loose mid-flight, lands on the ground; a townsperson
##         picks it up and patches the hole with it. The geyser dies, the
##         needle sinks back out of the red, the town approves.

const Props := preload("res://scripts/cutscenes/beats/FixLeakProps.gd")

const PIPE_Y := 0.40
const METER_POS := Vector2(0.10, 0.16)
const APEX_Y := -0.18

var pipe: Node2D
var hole: Polygon2D
var meter: Node2D
var needle: Polygon2D
var column: Polygon2D
var geyser: GPUParticles2D
var hat: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.WALL
	get_node("World/Ground").color = Props.FLOOR
	get_node("World/Dirt").color = Props.FLOOR.darkened(0.25)
	var skyline := Props.make_skyline(_vp.x * 0.8)
	skyline.position = Vector2(_vp.x * 0.5, _vp.y * 0.24)
	world.add_child(skyline)
	_stage_townsfolk(3, _vp.x * 0.64, _vp.x * 0.84)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.74, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	pipe = Props.make_pipe(_vp.x * 0.40, [0.0])
	pipe.position = Vector2(_vp.x * 0.34, _vp.y * PIPE_Y)
	world.add_child(pipe)
	hole = pipe.get_node("Hole0")
	hole.scale = Vector2(1.6, 1.6)
	# Dribble stands directly over the hole. Bad idea.
	dribble = _stage_actor(CastFactory.make_dribble(), pipe.position.x)
	meter = Props.make_waste_meter(1.15 * _content_scale)
	meter.position = Vector2(_vp.x * METER_POS.x, _vp.y * METER_POS.y)
	meter.z_index = 8
	world.add_child(meter)
	needle = meter.get_node("Needle")

func _impact_point() -> Vector2:
	return Vector2(pipe.position.x, _vp.y * APEX_Y)

## BEAT 1 — the hiss builds under Dribble's feet.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.start_idle()
	needle.rotation = 2.3
	var quiver := _ct(needle).set_loops()
	quiver.tween_property(needle, "rotation", 2.5, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	quiver.tween_property(needle, "rotation", 2.3, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## BEAT 2 — eruption. We deliberately do NOT call super() here: the whole
## impact stack is deferred to the apex callback so it lands at PEAK LAUNCH.
func _on_impact() -> void:
	_start_geyser()
	_launch_dribble()

## The water column bursts out of the hole under Dribble.
func _start_geyser() -> void:
	column = Polygon2D.new()
	column.name = "GeyserColumn"
	var h := _vp.y * PIPE_Y
	column.polygon = PackedVector2Array([
		Vector2(-14.0, 0.0), Vector2(14.0, 0.0), Vector2(8.0, -h), Vector2(-8.0, -h),
	])
	column.color = Props.WATER_LIGHT
	column.position = pipe.position + hole.position + Vector2(0.0, -6.0)
	column.scale = Vector2(1.0, 0.05)
	column.z_index = 11
	world.add_child(column)
	var burst := _ct(column)
	burst.tween_property(column, "scale:y", 1.0, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	geyser = Props.make_jet(_dot_texture(), 1.4)
	geyser.position = column.position
	geyser.rotation = -0.5 * PI
	geyser.z_index = 12
	world.add_child(geyser)

## Dribble rides the geyser up and off frame; his hat shakes loose en route.
func _launch_dribble() -> void:
	var apex := Vector2(pipe.position.x + _vp.x * 0.01, _vp.y * APEX_Y)
	dribble.set_expression(CartoonActor.Mood.PANIC)
	var fly := _ct()
	fly.tween_property(dribble, "position", apex, 0.46) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(dribble, "rotation", TAU * 1.5, 0.46)
	fly.tween_callback(_apex_impact)
	# Hat comes loose a beat after liftoff and tumbles back to the ground.
	var drop := _ct()
	drop.tween_interval(0.16)
	drop.tween_callback(_drop_hat)

func _apex_impact() -> void:
	# super._on_impact() IS the whole stack: flash, camera punch, stinger and a
	# burst at _impact_point(). The punch, stinger and burst that used to sit
	# around this line repeated three of those four in the same frame -- two pool
	# players pushing the identical stinger stream (measured simul=2 in
	# tools/VerifyOutroImpact.tscn), two tweens fighting over camera.zoom, and 60
	# particles at one point instead of 30 on the heaviest frame of the clip. The
	# deferral to the launch apex is the authored intent and is kept; only the
	# duplicates are gone.
	super._on_impact()

## The hat falls from mid-flight and lands tipped over near the pipe.
func _drop_hat() -> void:
	hat = Props.make_hat(_content_scale * 1.3)
	hat.position = dribble.position + Vector2(10.0 * _content_scale, 20.0 * _content_scale)
	hat.rotation = 0.4
	hat.z_index = 12
	world.add_child(hat)
	var ground_y := _vp.y * GROUND_FRACTION
	var fall := _ct(hat)
	fall.tween_property(hat, "position", Vector2(hat.position.x + _vp.x * 0.04, ground_y), 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(hat, "rotation", -1.9, 0.34)
	fall.tween_callback(func() -> void:
		hat.rotation = -PI * 0.5
	)

## BEAT 3 — the town patches the hole with Dribble's fallen hat; the geyser
## dies and the meter sinks back out of the red.
func _beat_payoff() -> void:
	var patcher: CartoonActor = townsfolk[0]
	patcher.set_arm_pose(CartoonActor.ArmPose.REACH)
	if hat == null or not is_instance_valid(hat):
		_drop_hat()  # payoff can race the deferred hat drop under frame spikes
	# Walk to the fallen hat...
	var walk := _ct(patcher)
	walk.tween_property(patcher, "position",
		Vector2(hat.position.x + _vp.x * 0.05, _vp.y * GROUND_FRACTION), 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# ...pick it up and slap it over the hole.
	walk.tween_callback(_lift_hat.bind(patcher))
	walk.tween_interval(0.10)
	walk.tween_callback(_patch_hole)

func _lift_hat(patcher: CartoonActor) -> void:
	var grab := _ct(hat)
	grab.tween_property(hat, "position", patcher.position \
		+ Vector2(20.0, -44.0) * _content_scale, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grab.parallel().tween_property(hat, "rotation", 0.0, 0.12)

func _patch_hole() -> void:
	var target := pipe.position + hole.position + Vector2(0.0, -10.0)
	var slap := _ct(hat)
	slap.tween_property(hat, "position", target, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slap.tween_callback(_seal)

func _seal() -> void:
	hat.rotation = -PI * 0.5
	hat.z_index = 11
	# Hat squashes flat over the hole and the geyser chokes out.
	var squash := _ct(hat)
	squash.tween_property(hat, "scale", Vector2(1.5, 0.5) * _content_scale, 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var kill := _ct(column)
	kill.tween_property(column, "modulate:a", 0.0, 0.30)
	if geyser != null and is_instance_valid(geyser):
		var fade := _ct(geyser)
		fade.tween_property(geyser, "modulate:a", 0.0, 0.30)
		fade.tween_callback(geyser.queue_free)
	# The needle sinks back out of the red.
	var settle := _ct(needle)
	settle.tween_property(needle, "rotation", 0.5, 0.40) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_approve()

func _approve() -> void:
	mayor.set_expression(CartoonActor.Mood.SMUG)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.hop(24.0, 0.32)
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.12 * float(i))
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.UP))
		tw.tween_callback(townsfolk[i].hop.bind(22.0, 0.30))

