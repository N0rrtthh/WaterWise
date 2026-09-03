## FilterBuilder - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/FilterBuilderIntro.tscn

extends MicrogameIntroBase

## Filter Builder — CAUSE clip.
## res://scenes/ui/cutscenes/beats/FilterBuilderIntro.tscn
##
## BEAT 1  The work table: a jug of MUDDY water beside a jumble of filter
##         layers; the town waits nearby, empty glasses in hand.
## BEAT 2  (flash-only impact) A muddy drip plops out of the jug — that's the
##         round: build the filter, or drink mud.
## BEAT 3  Dribble grabs for the layers; the crowd lifts their empty glasses;
##         the mayor hammers the point. SNAP: whip-pan into gameplay.

const Props := preload("res://scripts/cutscenes/beats/FilterBuilderProps.gd")

const LAYER_KINDS := ["charcoal", "sand", "gravel", "cloth"]
const HAND_DY := -42.0

var table: Node2D
var jug: Node2D
var layers: Array = []
var glasses: Array = []

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.SKY
	_stage_townsfolk(3, _vp.x * 0.08, _vp.x * 0.26)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.17, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.42)
	table = Props.make_table(220.0 * _content_scale)
	table.position = Vector2(_vp.x * 0.64, _vp.y * GROUND_FRACTION - 78.0 * _content_scale)
	table.z_index = -1
	world.add_child(table)
	jug = Props.make_jug(_content_scale * 1.2, true)
	jug.position = Vector2(_vp.x * 0.585, table.position.y + 2.0)
	jug.z_index = 1
	world.add_child(jug)
	_scatter_layers()
	for member: CartoonActor in townsfolk:
		_give_glass(member, 1.0)
	_give_glass(mayor, CastFactory.MAYOR_SCALE.x)
	# Beat 1 starts tight on the jumbled layers, then pulls out.
	camera.zoom = Vector2(1.24, 1.24)
	camera.position = _vp * 0.5 + Vector2(120.0, -110.0) * _content_scale

## The jumbled pile: four layers scattered across the table at messy angles.
func _scatter_layers() -> void:
	for i in range(LAYER_KINDS.size()):
		var layer := Props.make_layer(LAYER_KINDS[i])
		layer.scale = Vector2.ONE * _content_scale
		layer.position = Vector2(
			_vp.x * (0.625 + 0.045 * float(i)),
			table.position.y - (26.0 + 6.0 * float(i % 3)) * _content_scale
		)
		layer.rotation = -0.5 + 0.33 * float(i)
		layer.z_index = 2 - (i % 2)
		world.add_child(layer)
		layers.append(layer)

## Empty glass in hand: parked beside the actor at hand height.
func _give_glass(who: CartoonActor, scale_f: float) -> void:
	var g := Props.make_glass(_content_scale * scale_f)
	g.position = who.position \
		+ Vector2(24.0 * scale_f, HAND_DY * scale_f) * _content_scale
	g.z_index = 5
	world.add_child(g)
	glasses.append(g)

## BEAT 1 — the setup: town waits, glasses empty, mud standing by.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.NEUTRAL)
	for t in townsfolk:
		t.start_idle()
	var pan := _ct().set_parallel(true)
	pan.tween_property(camera, "position", _vp * 0.5, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pan.tween_property(camera, "zoom", Vector2.ONE, _setup_sec() * 0.95) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## BEAT 2 — the situation becomes clear. Intro contract: flash only, no punch,
## no burst, no stinger. A muddy drip plops onto the table.
func _on_impact() -> void:
	_impact_flash()
	_muddy_drip()
	dribble.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.drip_sweat()

## One muddy drop falls from the jug lip and plops on the table.
func _muddy_drip() -> void:
	var drop := Polygon2D.new()
	drop.polygon = Props._ellipse(5.0, 7.0, 10)
	drop.color = Props.MUDDY
	drop.z_index = 6
	var lip := jug.position + Vector2(-8.0, -60.0) * _content_scale
	drop.position = lip
	world.add_child(drop)
	var t := _ct()
	t.tween_property(drop, "position", lip + Vector2(0.0, 60.0) * _content_scale, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		var plop := _ct(drop)
		plop.tween_property(drop, "scale", Vector2(1.8, 0.4), 0.07) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		plop.tween_property(drop, "modulate:a", 0.0, 0.12)
		plop.tween_callback(drop.queue_free)
	)

## BEAT 3 — Dribble grabs for the layers; the crowd lifts the empties; the
## mayor points at the jug. The whip-pan snaps in mid-grab.
func _beat_payoff() -> void:
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	dribble.hop(26.0, 0.28)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	for i in range(layers.size()):
		var layer: Node2D = layers[i]
		var wiggle := _ct(layer)
		wiggle.tween_interval(0.05 * float(i))
		wiggle.tween_property(layer, "rotation", layer.rotation + 0.12, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		wiggle.tween_property(layer, "rotation", layer.rotation - 0.08, 0.10) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		wiggle.tween_property(layer, "rotation", layer.rotation, 0.08) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(glasses.size()):
		var g: Node2D = glasses[i]
		var raise := _ct(g)
		raise.tween_interval(0.06 * float(i))
		raise.tween_property(g, "position:y", g.position.y - 26.0 * _content_scale, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
