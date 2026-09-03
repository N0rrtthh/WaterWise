## CloudCatcher - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/CloudCatcherLoseOutro.tscn

extends MicrogameOutroBase

## Cloud Catcher — LOSE outro.
## res://scenes/ui/cutscenes/beats/CloudCatcherLoseOutro.tscn
##
## BEAT 1  The thirsty row waits; a gang of grumpy grey clouds gathers over
##         Dribble specifically.
## BEAT 2  IMPACT — the gang opens up and rains ONLY on Dribble.
## BEAT 3  The plants give up, curl into tumbleweeds and roll away; the puddle
##         under Dribble swells until it sweeps him off the cliff. The town
##         watches, deadpan-amused.

const Props := preload("res://scripts/cutscenes/beats/CloudCatcherProps.gd")

const CLIFF_EDGE_X := 0.88  # fraction of viewport width

var plants: Array[Node2D] = []
var gang: Array[Node2D] = []
var rain: GPUParticles2D
var puddle: Node2D

func _setup_stage() -> void:
	(get_node("Backdrop") as ColorRect).color = Color(0.53, 0.81, 0.92)
	_build_cliff()
	_stage_townsfolk(3, _vp.x * 0.10, _vp.x * 0.26)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.78, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.46)
	_make_plants()
	_make_gang()
	puddle = Props.make_puddle(1.0)
	puddle.name = "Puddle"
	puddle.position = Vector2(dribble.position.x, _vp.y * GROUND_FRACTION + 4.0)
	puddle.scale = Vector2(0.3, 0.3)
	puddle.z_index = -1
	puddle.visible = false
	world.add_child(puddle)

## The cliff the puddle sweeps Dribble over: ground stops at CLIFF_EDGE_X.
func _build_cliff() -> void:
	var ground_y := _vp.y * GROUND_FRACTION
	var cliff := Polygon2D.new()
	cliff.name = "CliffFace"
	cliff.polygon = PackedVector2Array([
		Vector2(_vp.x * CLIFF_EDGE_X, ground_y), Vector2(_vp.x, ground_y),
		Vector2(_vp.x, _vp.y), Vector2(_vp.x * (CLIFF_EDGE_X + 0.03), ground_y + 60.0 * _content_scale),
	])
	cliff.color = Color(0.40, 0.32, 0.22)
	cliff.z_index = 2
	world.add_child(cliff)

func _make_plants() -> void:
	for i in range(5):
		var size := (0.95 + 0.14 * float(i % 3)) * _content_scale
		var plant := Props.make_plant("thirsty", size)
		plant.name = "Plant%d" % (i + 1)
		# Keep the row left of Dribble so the cliff runway stays clear.
		plant.position = Vector2(_vp.x * (0.10 + 0.13 * float(i)), _vp.y * GROUND_FRACTION + 2.0)
		plant.z_index = -2
		world.add_child(plant)
		plants.append(plant)

## Two grumpy grey clouds drifting in from opposite sides.
func _make_gang() -> void:
	for i in range(2):
		var c := Props.make_puff_cloud(1.0 + 0.15 * float(i), true)
		c.name = "GangCloud%d" % (i + 1)
		c.position = Vector2(
			_vp.x * (0.12 if i == 0 else 0.92), _vp.y * (0.11 + 0.03 * float(i))
		)
		c.z_index = -4
		world.add_child(c)
		gang.append(c)

## BEAT 1 — the gang converges into a tight cell right above Dribble.
func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	var gather := _ct().set_parallel(true)
	gather.tween_property(gang[0], "position", Vector2(_vp.x * 0.40, _vp.y * 0.11), _setup_sec()) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	gather.tween_property(gang[1], "position", Vector2(_vp.x * 0.53, _vp.y * 0.09), _setup_sec()) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _impact_point() -> Vector2:
	if is_instance_valid(dribble):
		return dribble.position + Vector2(0.0, -70.0 * _content_scale)
	return super()

## BEAT 2 — the gang rains ONLY on Dribble. super() fires punch + flash +
## splash burst + stinger; the personal downpour starts on the same tick.
func _on_impact() -> void:
	super._on_impact()
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	dribble.drip_sweat()
	_start_personal_rain()

## A narrow continuous downpour anchored just above Dribble — width of one
## unfortunate cartoon guy. Anchored to RainAnchor so the payoff sweep can
## drag it along with him.
func _start_personal_rain() -> void:
	var anchor := Node2D.new()
	anchor.name = "RainAnchor"
	anchor.position = dribble.position
	anchor.z_index = 10
	rain = GPUParticles2D.new()
	rain.name = "PersonalRain"
	rain.amount = 34
	rain.lifetime = 0.55
	rain.preprocess = 0.3
	rain.position = Vector2(0.0, -_vp.y * 0.28)
	rain.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(34.0 * _content_scale, 6.0, 1.0)
	m.direction = Vector3(0, -1, 0)
	m.spread = 4.0
	m.initial_velocity_min = 200.0
	m.initial_velocity_max = 330.0
	m.gravity = Vector3(0, 1400, 0)
	m.color_initial_ramp = _ramp([
		Color(0.55, 0.82, 1.0), Color(0.75, 0.92, 1.0), Color(1, 1, 1),
	])
	m.scale_min = 0.4
	m.scale_max = 0.8
	rain.process_material = m
	anchor.add_child(rain)
	world.add_child(anchor)

## BEAT 3 — consequence cascade: weeds bail, puddle swells, Dribble sails.
func _beat_payoff() -> void:
	mayor.set_expression(CartoonActor.Mood.SMUG)
	dribble.set_expression(CartoonActor.Mood.PANIC)
	_plants_to_tumbleweeds()
	_grow_puddle()
	_sweep_dribble()

## Every thirsty plant curls into a tumbleweed that pops in and rolls away.
func _plants_to_tumbleweeds() -> void:
	for i in range(plants.size()):
		var old := plants[i]
		var weed := Props.make_tumbleweed(old.scale.x)
		weed.position = old.position
		weed.z_index = -1
		world.add_child(weed)
		weed.scale = old.scale * 0.15
		var pop := _ct()
		pop.tween_property(weed, "scale", old.scale, 0.22) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		# Roll away to the left, spinning, and free at the edge of frame.
		var roll := _ct()
		roll.tween_interval(0.22)
		roll.tween_property(weed, "position:x", weed.position.x - _vp.x * 0.35, 0.85) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		roll.parallel().tween_property(weed, "rotation", -TAU * 2.5, 0.85) \
			.set_trans(Tween.TRANS_LINEAR)
		roll.tween_callback(weed.queue_free)
		var fade := _ct()
		fade.tween_property(old, "modulate:a", 0.0, 0.16)
		fade.tween_callback(old.queue_free)
	plants.clear()

## The personal downpour pools: the puddle under Dribble swells ELASTIC-wide.
func _grow_puddle() -> void:
	puddle.visible = true
	var t := _ct()
	t.tween_property(puddle, "scale", Vector2(2.9, 1.25), 0.32) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## The sweep: puddle, Dribble and his personal rain move as ONE unit toward
## the cliff, then over the edge. tween_method moves all three by the same
## delta so nothing detaches mid-slide.
func _sweep_dribble() -> void:
	var rain_anchor := rain.get_parent() as Node2D
	var start := dribble.position
	var edge := Vector2(_vp.x * (CLIFF_EDGE_X - 0.03), start.y)
	var over := Vector2(_vp.x * (CLIFF_EDGE_X + 0.10), start.y + 200.0 * _content_scale)
	var sweep := _ct()
	sweep.tween_interval(0.38)
	sweep.tween_method(func(p: Vector2) -> void:
		var d := p - dribble.position
		dribble.position = p
		puddle.position += d
		rain_anchor.position += d
	, start, edge, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sweep.tween_method(func(p: Vector2) -> void:
		var d := p - dribble.position
		dribble.position = p
		puddle.position += d
		rain_anchor.position += d
	, edge, over, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	dribble.spin(1.0, 0.75)
