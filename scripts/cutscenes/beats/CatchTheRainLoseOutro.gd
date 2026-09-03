## CatchTheRain - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/CatchTheRainLoseOutro.tscn

extends MicrogameOutroBase

## Catch The Rain — LOSE outro.
## res://scenes/ui/cutscenes/beats/CatchTheRainLoseOutro.tscn
##
## BEAT 1  The drum sits brim-full but the water has gone MURKY — dirty drops
##         got through. Dribble sweats it; the town watches deadpan.
## BEAT 2  IMPACT — the drum splits down the middle (impact frame on the
##         crack; punch/flash/burst/stinger fire from the base class).
## BEAT 3  The dirty drops that got through form a small angry mob and chase
##         Dribble, who leaps into the broken bottom half and rolls downhill
##         toward the cliff, mob hot on his heels. Tone: slapstick, not cruel.

const Props := preload("res://scripts/cutscenes/beats/CatchTheRainProps.gd")

var drum: Node2D
var mob: Array[Node2D] = []
var mound_top_x: float
var mound_top_y: float

func _setup_stage() -> void:
	_stage_townsfolk(3, _vp.x * 0.06, _vp.x * 0.18)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.26, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	mound_top_x = _vp.x * 0.46
	var ground_y := _vp.y * GROUND_FRACTION
	mound_top_y = ground_y - 46.0 * _content_scale
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.58)
	_make_mound(ground_y)
	_make_cliff(ground_y)

	drum = Props.make_drum(true, true)
	drum.name = "RainDrum"
	drum.position = Vector2(mound_top_x, mound_top_y)
	drum.scale = Vector2.ONE * _content_scale * 1.15
	drum.z_index = -1
	world.add_child(drum)
	_make_mob()

## BEAT 1 — murk rising, nerves setting in, deadpan gallery.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.drip_sweat()
	mayor.set_expression(CartoonActor.Mood.SAD)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.NEUTRAL)
		t.start_idle()
	# The drum shivers under its bad water.
	_shiver()

func _shiver() -> void:
	var base_x: float = drum.position.x
	var t := _ct()
	for i in range(4):
		var dir := 2.6 * _content_scale if i % 2 == 0 else -2.6 * _content_scale
		t.tween_property(drum, "position:x", base_x + dir, 0.05)
	t.tween_property(drum, "position:x", base_x, 0.05)

func _impact_point() -> Vector2:
	if is_instance_valid(drum):
		return drum.position + Vector2(0.0, -84.0 * _content_scale)
	return super()

## BEAT 2 — the crack. super() fires punch + flash + splash burst + stinger;
## the two hinged halves swing apart around their bottom corners and the
## murky water spills away (alpha fade on each half's Water polygon).
func _on_impact() -> void:
	super._on_impact()
	_split_drum()
	dribble.set_expression(CartoonActor.Mood.SHOCKED)

func _split_drum() -> void:
	var half_l := drum.get_node("HalfL") as Node2D
	var half_r := drum.get_node("HalfR") as Node2D
	var t := _ct().set_parallel(true)
	t.tween_property(half_l, "position", half_l.position + Vector2(-34.0, -4.0) * _content_scale, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(half_l, "rotation", -0.55, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(half_r, "position", half_r.position + Vector2(34.0, -4.0) * _content_scale, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(half_r, "rotation", 0.55, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for half in [half_l, half_r]:
		for poly in half.get_child(0).get_children():
			if poly.name == "Water":
				var wt := _ct()
				wt.tween_property(poly, "modulate:a", 0.25, 0.22)
	var recoil := _ct()
	recoil.tween_property(dribble, "position:x", dribble.position.x + 20.0 * _content_scale, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## BEAT 3 — mob forms, Dribble dives into the broken bottom half and rolls
## downhill toward the cliff, the mob scrambling after him.
func _beat_payoff() -> void:
	_form_mob()
	_dribble_leaps_in()
	_roll_to_cliff()
	_mob_gives_chase()
	mayor.set_expression(CartoonActor.Mood.SMUG)

## The dirty drops pop in with an ELASTIC entrance and grab angry poses.
func _form_mob() -> void:
	for i in range(mob.size()):
		var m := mob[i]
		var t := _ct()
		t.tween_interval(0.06 * float(i))
		t.tween_callback(m.set_visible.bind(true))
		t.tween_property(m, "scale", Vector2.ONE * _content_scale, 0.22) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## Dribble hops into the tub between the split halves; the front rim hides
## his legs so he reads as sitting INSIDE the broken drum.
func _dribble_leaps_in() -> void:
	var in_tub := drum.position + Vector2(0.0, -6.0 * _content_scale)
	var t := _ct()
	t.tween_property(dribble, "position", in_tub + Vector2(0.0, -60.0 * _content_scale), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(dribble, "position", in_tub, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		(drum.get_node("FrontRim") as Polygon2D).visible = true
		dribble.squash(0.5, 0.18)
	)

## The bumpy downhill roll: down the mound, along the flat, then over the
## cliff edge. Dribble's rig spins while the tub wobbles — reads as rolling
## without needing to rotate the rider.
func _roll_to_cliff() -> void:
	var ground_y := _vp.y * GROUND_FRACTION
	var edge := Vector2(_vp.x * 0.82, ground_y)
	var over := Vector2(_vp.x * 1.18, ground_y + 120.0 * _content_scale)
	var roll := _ct()
	roll.tween_interval(0.34) # wait for the leap-in to land
	# Segment 1 — down the mound onto the flat, picking up speed.
	roll.tween_method(_place_rider, drum.position, edge, 0.38) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Segment 2 — off the cliff, now falling.
	roll.tween_method(_place_rider, edge, over, 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var wobble := _ct()
	wobble.tween_interval(0.34)
	for i in range(5):
		wobble.tween_property(drum, "rotation", 0.13 if i % 2 == 0 else -0.13, 0.14)
	dribble.spin(2.0, 0.9)

## Moves the tub AND its rider together along the roll path.
func _place_rider(at: Vector2) -> void:
	var delta := at - drum.position
	drum.position = at
	dribble.position += delta

## The mob scrambles after him, slams to a halt at the cliff edge and bounces
## furiously at the escape (chirpy, never cruel).
func _mob_gives_chase() -> void:
	var ground_y := _vp.y * GROUND_FRACTION
	var ledge_x := _vp.x * 0.80
	for i in range(mob.size()):
		var m := mob[i]
		var t := _ct()
		t.tween_interval(0.20 + 0.07 * float(i))
		t.tween_property(m, "position:x", ledge_x - 14.0 * _content_scale * float(i + 1), 0.42) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_callback(func() -> void:
			m.position.y = ground_y - 16.0 * _content_scale
		)
		# Furious little victory-adjacent bounces at the lip.
		for b in range(3):
			t.tween_property(m, "position:y", ground_y - 30.0 * _content_scale, 0.09) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(m, "position:y", ground_y - 16.0 * _content_scale, 0.09) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## The starting knoll the drum sits on — the downhill run starts here.
func _make_mound(ground_y: float) -> void:
	var mound := Polygon2D.new()
	mound.name = "Mound"
	mound.polygon = PackedVector2Array([
		Vector2(_vp.x * 0.32, ground_y + 2.0),
		Vector2(mound_top_x, mound_top_y + 2.0),
		Vector2(_vp.x * 0.60, ground_y + 2.0),
	])
	mound.color = Color(0.46, 0.68, 0.38)
	mound.z_index = -2
	world.add_child(mound)

## The right-edge drop: a shaded dirt face so the roll reads as "toward
## (and over) a cliff".
func _make_cliff(ground_y: float) -> void:
	var face := Polygon2D.new()
	face.name = "CliffFace"
	face.polygon = PackedVector2Array([
		Vector2(_vp.x * 0.86, ground_y), Vector2(_vp.x * 0.90, ground_y),
		Vector2(_vp.x, _vp.y), Vector2(_vp.x * 0.86, _vp.y),
	])
	face.color = Color(0.33, 0.48, 0.28)
	face.z_index = -2
	world.add_child(face)

## The dirty-drop mob, hidden at the drum's base until the payoff.
func _make_mob() -> void:
	for i in range(3):
		var m := Props.make_mob_member()
		m.name = "Mob%d" % (i + 1)
		m.position = Vector2(
			drum.position.x + (10.0 + 16.0 * float(i)) * _content_scale,
			_vp.y * GROUND_FRACTION - 16.0 * _content_scale
		)
		m.scale = Vector2.ONE * _content_scale
		m.scale *= 0.0
		m.z_index = 7
		world.add_child(m)
		mob.append(m)
