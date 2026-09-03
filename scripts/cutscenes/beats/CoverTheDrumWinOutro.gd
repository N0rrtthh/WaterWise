## CoverTheDrum - WIN beat clip.
## Scene: res://scenes/ui/cutscenes/beats/CoverTheDrumWinOutro.tscn

extends MicrogameOutroBase

## Cover The Drum — WIN outro.
## res://scenes/ui/cutscenes/beats/CoverTheDrumWinOutro.tscn
##
## BEAT 1  Dusk sky; three open drums stand in a row; the town gathers with
##         the lids stacked nearby; mosquitoes still circle, unaware.
## BEAT 2  IMPACT — drum 1's lid SLAMS shut on the impact frame; the drum
##         takes the punch. The swarm scatters.
## BEAT 3  The rhythm: drums 2 and 3 slam in parade time while the mosquitoes
##         flee in a tiny sad marching band — trumpets and all. The town
##         waves the funeral parade off.

const Props := preload("res://scripts/cutscenes/beats/CoverTheDrumProps.gd")

const DRUM_XS := [0.30, 0.50, 0.70]
const SLAM_GAP := 0.14

var drums: Array[Node2D] = []
var mosqs: Array = []
var band: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.DUSK_SKY
	world.get_node("Ground").color = Color(0.30, 0.34, 0.22)
	world.get_node("Dirt").color = Color(0.25, 0.20, 0.15)
	world.add_child(Props.make_stars(_vp, 14))
	_stage_townsfolk(3, _vp.x * 0.08, _vp.x * 0.24)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.86, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.50)
	for i in range(DRUM_XS.size()):
		var d := Props.make_drum(_content_scale)
		d.position = Vector2(_vp.x * float(DRUM_XS[i]), _vp.y * GROUND_FRACTION)
		d.z_index = -1
		world.add_child(d)
		drums.append(d)
	# A couple of stragglers still buzzing when the clip opens.
	for i in range(2):
		var m := Props.make_mosquito(_content_scale)
		m.position = drums[i].position + Vector2(0.0, -150.0) * _content_scale
		m.z_index = 4
		world.add_child(m)
		mosqs.append(m)
		_flap(m)

func _flap(m: Node2D) -> void:
	for side in ["WingL", "WingR"]:
		var wing: Polygon2D = m.get_node(side)
		var rest := wing.position.y
		var flap := _ct(wing).set_loops()
		flap.tween_property(wing, "position:y", rest - 4.0, 0.07) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		flap.tween_property(wing, "position:y", rest, 0.07) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## BEAT 1 — hopeful cast, oblivious swarm.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	for i in range(mosqs.size()):
		var hover: Tween = _ct(mosqs[i] as Node2D).set_loops()
		var base_y: float = mosqs[i].position.y
		hover.tween_property(mosqs[i], "position:y", base_y + 12.0, 0.32) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hover.tween_property(mosqs[i], "position:y", base_y, 0.32) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _impact_point() -> Vector2:
	return drums[0].position + Vector2(0.0, -60.0) * _content_scale

## BEAT 2 — the first lid slams ON the impact frame. super() fires punch +
## flash + confetti burst + stinger; the drum takes the hit like a parade drum.
func _on_impact() -> void:
	super._on_impact()
	_slam(0, 0.0, true)

## One slam: lid flips closed, drum squashes, dust puffs out under the rim.
func _slam(i: int, delay: float, big: bool) -> void:
	var drum := drums[i]
	var lid: Node2D = drum.get_node("Lid")
	var t := _ct()
	t.tween_interval(delay)
	t.tween_callback(func() -> void:
		lid.visible = true
		lid.rotation = -1.35
	)
	t.tween_property(lid, "rotation", 0.0, 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		var squash := _ct(drum)
		squash.tween_property(drum, "scale:y", drum.scale.y * (0.86 if big else 0.92), 0.05) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		squash.tween_property(drum, "scale:y", drum.scale.y, 0.16) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	)
	_dust_puff(drum)

## Little dust ring at the drum base that puffs out and fades.
func _dust_puff(drum: Node2D) -> void:
	var p := GPUParticles2D.new()
	p.name = "DustPuff"
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.amount = 14
	p.lifetime = 0.5
	p.position = Vector2(0.0, -2.0)
	p.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 6.0
	m.direction = Vector3(0, -1, 0)
	m.spread = 60.0
	m.initial_velocity_min = 90.0
	m.initial_velocity_max = 190.0
	m.gravity = Vector3(0, -60, 0)
	m.color_initial_ramp = _ramp([Color(0.45, 0.40, 0.32), Color(0.55, 0.50, 0.42)])
	m.scale_min = 0.4
	m.scale_max = 0.9
	p.process_material = m
	p.z_index = 6
	drum.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

## BEAT 3 — the mournful procession: drums 2 and 3 slam in parade time while
## the mosquitoes regroup into a tiny sad band and buzz off, trumpets first.
func _beat_payoff() -> void:
	_slam(1, 0.0, false)
	_slam(2, SLAM_GAP, false)
	dribble.set_expression(CartoonActor.Mood.HAPPY)
	dribble.set_arm_pose(CartoonActor.ArmPose.CHEER)
	mayor.set_expression(CartoonActor.Mood.SMUG)
	mayor.hop(34.0, 0.38)
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.12 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(26.0, 0.30))
	_scare_off_stragglers()
	_sad_parade()

## The two stragglers bolt off-frame the moment the first lid claps shut.
func _scare_off_stragglers() -> void:
	for i in range(mosqs.size()):
		var m: Node2D = mosqs[i]
		var flee := _ct()
		flee.tween_interval(0.05 + 0.06 * float(i))
		flee.tween_property(m, "position", m.position + Vector2(-_vp.x * 0.4, -_vp.y * 0.22), 0.34) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		flee.tween_callback(m.queue_free)

## Four instrument mosquitos rise into a sad 2x2 wedge (trumpets up top) and
## drone off the upper-left, bobbing in step — a funeral march for lost blood.
func _sad_parade() -> void:
	band = Node2D.new()
	band.name = "SadBand"
	band.position = Vector2(_vp.x * 0.50, _vp.y * 0.42)
	band.z_index = 12
	var offsets := [
		Vector2(-26.0, 10.0), Vector2(26.0, 10.0),
		Vector2(-13.0, -8.0), Vector2(13.0, -8.0),
	]
	for i in range(offsets.size()):
		var m := Props.make_mosquito(_content_scale * 0.85, true)
		m.position = offsets[i] * _content_scale
		band.add_child(m)
		_flap(m)
		m.scale = Vector2.ONE * 0.1
		var pop := _ct()
		pop.tween_property(m, "scale", Vector2.ONE * _content_scale * 0.85, 0.22) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	world.add_child(band)
	var march := _ct()
	march.tween_interval(0.45)
	march.tween_property(band, "position",
		Vector2(_vp.x * 0.44, _vp.y * 0.36), 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	march.tween_property(band, "position",
		Vector2(-_vp.x * 0.18, _vp.y * 0.22), 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	march.tween_callback(band.queue_free)
	# The mournful bob — the whole band dips in step, twice per leg.
	# Bound to the band so it dies with the band when the march ends.
	var bob := _ct(band).set_loops()
	bob.tween_property(band, "position:y", band.position.y + 10.0 * _content_scale, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bob.tween_property(band, "position:y", band.position.y, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

