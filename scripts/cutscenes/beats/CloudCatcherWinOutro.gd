## CloudCatcher - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/CloudCatcherWinOutro.tscn

extends MicrogameOutroBase

## Cloud Catcher — WIN outro.
## res://scenes/ui/cutscenes/beats/CloudCatcherWinOutro.tscn
##
## BEAT 1  The thirsty row stands under a clearing sky; the town gathers.
## BEAT 2  IMPACT — the plants BURST into a lush jungle: every thirsty sprout
##         pops into a tall blooming plant (rapid scale + leaf-green burst).
## BEAT 3  A tiny "pet cloud" adopts Dribble and follows him around the jungle
##         raining confetti; the town dances between the blooms.

const Props := preload("res://scripts/cutscenes/beats/CloudCatcherProps.gd")

var plants: Array[Node2D] = []
var pet_cloud: Node2D

func _setup_stage() -> void:
	(get_node("Backdrop") as ColorRect).color = Color(0.53, 0.81, 0.92)
	_stage_townsfolk(4, _vp.x * 0.10, _vp.x * 0.34)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.84, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.50)
	_make_plants()

## The row of thirsty sprouts, planted behind the cast.
func _make_plants() -> void:
	for i in range(5):
		var size := (0.95 + 0.14 * float(i % 3)) * _content_scale
		var plant := Props.make_plant("thirsty", size)
		plant.name = "Plant%d" % (i + 1)
		plant.position = Vector2(_vp.x * (0.16 + 0.17 * float(i)), _vp.y * GROUND_FRACTION + 2.0)
		plant.z_index = -2
		world.add_child(plant)
		plants.append(plant)

## BEAT 1 — clearing sky, hopeful cast.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	for t in townsfolk:
		t.start_idle()

func _impact_point() -> Vector2:
	return Vector2(_vp.x * 0.5, _vp.y * GROUND_FRACTION - 50.0 * _content_scale)

## BEAT 2 — jungle burst! super() fires punch + flash + confetti burst +
## stinger; on top of that every sprout pops lush and a leaf-green bloom
## sweeps the row.
func _on_impact() -> void:
	super._on_impact()
	_grow_jungle()
	_leaf_burst()

## Swap each thirsty sprout for a blooming plant popping up ELASTIC-style.
func _grow_jungle() -> void:
	for i in range(plants.size()):
		var old := plants[i]
		var target := old.scale * 2.1
		var lush := Props.make_plant("lush", 0.1)
		lush.position = old.position
		lush.z_index = -1
		world.add_child(lush)
		lush.scale = old.scale * 0.15
		var t := _ct()
		t.tween_property(lush, "scale", target, 0.34) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		var fade := _ct()
		fade.tween_property(old, "modulate:a", 0.0, 0.20)
		fade.tween_callback(old.queue_free)
	plants.clear()

## One-shot GPUParticles2D — the green "growth wave" rolling along the row.
func _leaf_burst() -> void:
	var p := GPUParticles2D.new()
	p.name = "LeafBurst"
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.amount = 46
	p.lifetime = 1.0
	p.position = _impact_point()
	p.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(_vp.x * 0.38, 10.0, 1.0)
	m.direction = Vector3(0, -1, 0)
	m.spread = 28.0
	m.initial_velocity_min = 200.0
	m.initial_velocity_max = 420.0
	m.gravity = Vector3(0, 620, 0)
	m.color_initial_ramp = _ramp([
		Props.LEAF_OK, Props.LEAF_PALE, Props.PETAL, Color(1, 1, 1),
	])
	m.scale_min = 0.5
	m.scale_max = 1.1
	p.process_material = m
	p.z_index = 12
	world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var safety := _ct()
	safety.tween_interval(2.5)
	safety.tween_callback(p.queue_free)


## BEAT 3 — the pet cloud adopts Dribble: he takes a victory lap around the
## jungle and the little cloud trails him, raining confetti the whole way.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	mayor.hop(38.0, 0.4)
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.14 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(30.0, 0.32))
	_spawn_pet_cloud()
	_victory_lap()

## The tiny pet cloud with a happy little face, hovering at Dribble head
## height. Its Confetti child rains from the moment it appears.
func _spawn_pet_cloud() -> void:
	pet_cloud = Props.make_puff_cloud(0.62)
	pet_cloud.name = "PetCloud"
	pet_cloud.position = Vector2(_vp.x * 0.30, _vp.y * 0.30)
	pet_cloud.z_index = 8
	for x_off in [-7.0, 7.0]:
		var eye := Polygon2D.new()
		eye.polygon = Props._ellipse(2.0, 2.4, 8)
		eye.position = Vector2(x_off, -4.0)
		eye.color = Color(0.09, 0.11, 0.14)
		pet_cloud.add_child(eye)
	var smile := Line2D.new()
	smile.width = 1.8
	smile.default_color = Color(0.09, 0.11, 0.14)
	smile.points = PackedVector2Array([Vector2(-4.0, 1.0), Vector2(0.0, 3.5), Vector2(4.0, 1.0)])
	pet_cloud.add_child(smile)
	var confetti := GPUParticles2D.new()
	confetti.name = "Confetti"
	confetti.amount = 26
	confetti.lifetime = 0.85
	confetti.preprocess = 0.3
	confetti.position = Vector2(0.0, 16.0)
	confetti.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(26.0, 4.0, 1.0)
	m.direction = Vector3(0, -1, 0)
	m.spread = 8.0
	m.initial_velocity_min = 60.0
	m.initial_velocity_max = 120.0
	m.gravity = Vector3(0, 900, 0)
	m.color_initial_ramp = _ramp(Props.CONFETTI)
	m.scale_min = 0.5
	m.scale_max = 0.9
	confetti.process_material = m
	pet_cloud.add_child(confetti)
	world.add_child(pet_cloud)
	# Pop-in.
	pet_cloud.scale = Vector2.ONE * 0.1
	var t := _ct()
	t.tween_property(pet_cloud, "scale", Vector2.ONE * 0.62, 0.26) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## Dribble's lap: three waypoints; the pet cloud trails each one a beat later
## with a gentle bob, so it reads as FOLLOWING, not teleporting.
func _victory_lap() -> void:
	var ground_y := _vp.y * GROUND_FRACTION
	var waypoints := [
		Vector2(_vp.x * 0.34, ground_y),
		Vector2(_vp.x * 0.66, ground_y),
		Vector2(_vp.x * 0.48, ground_y),
	]
	var walk := _ct()
	for wp in waypoints:
		walk.tween_property(dribble, "position:x", wp.x, 0.30) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dribble.hop(26.0, 0.3)
	var follow := _ct()
	follow.tween_interval(0.12)
	for wp in waypoints:
		follow.tween_property(pet_cloud, "position", Vector2(wp.x, _vp.y * 0.30), 0.30) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		follow.parallel().tween_property(pet_cloud, "position:y", _vp.y * 0.27, 0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		follow.tween_property(pet_cloud, "position:y", _vp.y * 0.30, 0.15) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
