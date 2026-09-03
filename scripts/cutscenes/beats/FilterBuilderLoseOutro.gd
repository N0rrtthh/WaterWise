## FilterBuilder - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/FilterBuilderLoseOutro.tscn

extends MicrogameOutroBase

## Filter Builder — LOSE outro.
## res://scenes/ui/cutscenes/beats/FilterBuilderLoseOutro.tscn
##
## BEAT 1  The botched filter sits on the table; Mayor Ripple waits, glass
##         held high, trusting.
## BEAT 2  IMPACT — BROWN SLUDGE pours out instead and plops into the mayor's
##         glass (the plop is the impact frame: flash + burst + stinger).
## BEAT 3  The mayor grabs the muddy filter, swings it overhead and CHASES
##         Dribble off toward the cliff while the town looks on.

const Props := preload("res://scripts/cutscenes/beats/FilterBuilderProps.gd")

const CLIFF_EDGE_X := 0.88
const HAND_DY := -42.0

var table: Node2D
var jug: Node2D
var mayor_glass: Node2D
var stream: Line2D
var swing_filter: Node2D

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.SKY
	_stage_townsfolk(3, _vp.x * 0.06, _vp.x * 0.22)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.64, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.40)
	table = Props.make_table(200.0 * _content_scale)
	table.position = Vector2(_vp.x * 0.50, _vp.y * GROUND_FRACTION - 78.0 * _content_scale)
	table.z_index = -1
	world.add_child(table)
	jug = Props.make_jug(_content_scale * 1.15, true)
	jug.position = Vector2(_vp.x * 0.45, table.position.y + 2.0)
	jug.z_index = 1
	world.add_child(jug)
	# The botched stack — messy, layers out of order.
	for i in range(4):
		var layer := Props.make_layer(["gravel", "cloth", "sand", "charcoal"][i])
		layer.scale = Vector2.ONE * _content_scale
		layer.position = Vector2(
			_vp.x * (0.52 + 0.02 * float(i % 2)),
			table.position.y - (2.0 + 9.0 * float(i))
		)
		layer.rotation = 0.25 - 0.17 * float(i)
		layer.z_index = 2
		world.add_child(layer)
	mayor_glass = Props.make_glass(_content_scale * CastFactory.MAYOR_SCALE.x)
	mayor_glass.position = mayor.position \
		+ Vector2(24.0 * CastFactory.MAYOR_SCALE.x, HAND_DY * CastFactory.MAYOR_SCALE.x) \
		* _content_scale
	mayor_glass.z_index = 5
	world.add_child(mayor_glass)

func _impact_point() -> Vector2:
	return mayor_glass.position + Vector2(0.0, -30.0) * mayor_glass.scale.y

## BEAT 1 — confidence: the mayor raises his glass, ready for a clean drink.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.HAPPY)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	for t in townsfolk:
		t.start_idle()

## BEAT 2 — the betrayal: brown sludge streams out and PLOPS into the mayor's
## glass. super() fires punch + flash + burst + stinger as the stream bursts
## out; the PLOP lands a beat later with its own flash — the strongest frame.
func _on_impact() -> void:
	super()
	var lip := jug.position + Vector2(-6.0, -60.0) * _content_scale
	var target := _impact_point()
	stream = Line2D.new()
	stream.name = "SludgeStream"
	stream.points = PackedVector2Array([lip, target])
	stream.width = 8.0
	stream.default_color = Props.MUDDY
	stream.z_index = 8
	world.add_child(stream)
	# The stream wavers as it pours; bound to the stream.
	var flow := _ct(stream).set_loops()
	flow.tween_property(stream, "width", 9.5, 0.11) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flow.tween_property(stream, "width", 8.0, 0.11) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var plop := Polygon2D.new()
	plop.name = "SludgePlop"
	plop.polygon = Props._ellipse(9.0, 12.0, 12)
	plop.color = Props.MUDDY
	plop.z_index = 9
	plop.position = lip
	world.add_child(plop)
	var fall := _ct(plop)
	fall.tween_property(plop, "position", target, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_callback(_plop_impact.bind(plop, target))

## The plop frame: flash again, splat burst, the glass fills with sludge,
## and the mayor realises what he is holding.
func _plop_impact(plop: Polygon2D, target: Vector2) -> void:
	super._on_impact()
	plop.queue_free()
	_sludge_splat(target)
	var fill: Polygon2D = mayor_glass.get_node("Fill")
	fill.color = Props.MUDDY
	var rise := _ct(fill)
	rise.tween_property(fill, "scale:y", 0.85, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.drip_sweat()

## Brown splash exploding out of the glass rim.
func _sludge_splat(at: Vector2) -> void:
	var p := GPUParticles2D.new()
	p.name = "SludgeSplat"
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.amount = 22
	p.lifetime = 0.6
	p.position = at
	p.texture = _dot_texture()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 46.0
	m.initial_velocity_min = 200.0
	m.initial_velocity_max = 420.0
	m.gravity = Vector3(0, 1000, 0)
	m.color_initial_ramp = _ramp([
		Props.MUDDY, Color(0.36, 0.24, 0.12), Color(1, 1, 1),
	])
	m.scale_min = 0.4
	m.scale_max = 0.8
	p.process_material = m
	p.z_index = 12
	world.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	var safety := _ct()
	safety.tween_interval(2.0)
	safety.tween_callback(p.queue_free)

## BEAT 3 — the mayor grabs the muddy filter, swings it overhead, and chases
## Dribble off toward the cliff while the town scrambles clear.
func _beat_payoff() -> void:
	_stop_stream()
	_drop_glass()
	_arm_swing_filter()
	_chase()
	_watch_horror()

## The mayor flings the sludged glass down in disgust — it lands tipped over.
func _drop_glass() -> void:
	var ground_y := _vp.y * GROUND_FRACTION
	var drop := _ct(mayor_glass)
	drop.set_parallel(true)
	drop.tween_property(mayor_glass, "position:y", ground_y, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_property(mayor_glass, "rotation", PI * 0.5, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The muddy filter parked in the mayor's raised hand, ready to swing.
func _arm_swing_filter() -> void:
	var f := Props.make_layer("cloth")
	f.scale = Vector2.ONE * _content_scale * CastFactory.MAYOR_SCALE.x
	f.position = mayor.position + Vector2(14.0, -100.0) \
		* CastFactory.MAYOR_SCALE.x * _content_scale
	# Dip it in the evidence first.
	var fill: Polygon2D = f.get_node("Disc")
	fill.color = Props.MUDDY.lerp(fill.color, 0.35)
	f.z_index = 6
	world.add_child(f)
	swing_filter = f
	# Overhead swing loop; bound to the filter.
	var swing := _ct(f).set_loops()
	swing.tween_property(f, "rotation", 0.9, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	swing.tween_property(f, "rotation", -0.9, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Dribble bolts for the cliff with the filter-wielding mayor hot on his
## heels; the mayor skids at the edge and shakes the filter as Dribble drops.
func _chase() -> void:
	var ground_y := _vp.y * GROUND_FRACTION
	var d_run := Vector2(_vp.x * 0.74, ground_y)
	var d_edge := Vector2(_vp.x * (CLIFF_EDGE_X - 0.01), ground_y)
	var d_gone := Vector2(_vp.x * (CLIFF_EDGE_X + 0.07), _vp.y * 1.12)
	var m_run := Vector2(_vp.x * 0.68, ground_y)
	var m_edge := Vector2(_vp.x * (CLIFF_EDGE_X - 0.05), ground_y)
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	mayor.set_expression(CartoonActor.Mood.PANIC)
	mayor.set_arm_pose(CartoonActor.ArmPose.UP)
	# Dribble: two sprint hops to the edge, then off the cliff.
	var run_d := _ct()
	run_d.tween_property(dribble, "position", d_run, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	run_d.tween_property(dribble, "position", d_edge, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	run_d.tween_property(dribble, "position", d_gone, 0.44) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var hop_d := _ct(dribble).set_loops()
	hop_d.tween_callback(dribble.hop.bind(24.0, 0.22))
	hop_d.tween_interval(0.24)
	# The mayor trails a beat behind and skids at the edge.
	var run_m := _ct()
	run_m.tween_interval(0.16)
	run_m.tween_property(mayor, "position", m_run, 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	run_m.tween_property(mayor, "position", m_edge, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	run_m.tween_callback(func() -> void:
		mayor.shake(7.0, 0.5)
	)
	# The filter follows the mayor's hand, still swinging.
	var follow_f := _ct()
	follow_f.tween_interval(0.16)
	follow_f.tween_property(swing_filter, "position", m_run \
		+ Vector2(14.0, -100.0) * CastFactory.MAYOR_SCALE.x * _content_scale, 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	follow_f.tween_property(swing_filter, "position", m_edge \
		+ Vector2(14.0, -100.0) * CastFactory.MAYOR_SCALE.x * _content_scale, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## The pour ribbon dies as the chase starts.
func _stop_stream() -> void:
	if stream == null or not is_instance_valid(stream):
		return
	var out := _ct(stream)
	out.tween_property(stream, "modulate:a", 0.0, 0.15)
	out.tween_callback(stream.queue_free)

## The town scrambles back from the angry mayor.
func _watch_horror() -> void:
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.30 + 0.10 * float(i))
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.BRACE))
		tw.tween_callback(townsfolk[i].hop.bind(20.0, 0.28))


