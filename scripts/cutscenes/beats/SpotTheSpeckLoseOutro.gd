## SpotTheSpeck - LOSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/SpotTheSpeckLoseOutro.tscn

extends MicrogameOutroBase

## Spot The Speck — LOSE clip.
## res://scenes/ui/cutscenes/beats/SpotTheSpeckLoseOutro.tscn
##
## BEAT 1  A town member thumbs their nose at the warnings and drinks
##         from a dirty glass.
## BEAT 2  (impact) They comically FAINT, glass rolling away.
## BEAT 3  The town hangs Dribble upside down over the cliff edge and
##         shakes them until the specks fall out.

const Props := preload("res://scripts/cutscenes/beats/SpotTheSpeckProps.gd")

const CLIFF_X := 0.94

var dirty_glass: Node2D
var drinker: CartoonActor

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG
	_stage_townsfolk(2, _vp.x * 0.30, _vp.x * 0.44)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.62, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.16)
	var table := Props.make_table(_vp.x * 0.24, _vp.y * 0.16)
	table.position = Vector2(_vp.x * 0.34, _vp.y * GROUND_FRACTION)
	table.z_index = 3
	world.add_child(table)
	# The fateful dirty glass, waiting on the table.
	dirty_glass = Props.make_glass(_vp.y * 0.16, true)
	dirty_glass.position = Vector2(_vp.x * 0.34,
		_vp.y * GROUND_FRACTION - _vp.y * 0.16)
	dirty_glass.z_index = 4
	world.add_child(dirty_glass)
	# The reckless drinker steps forward to take it.
	drinker = townsfolk[0]
	drinker.position = Vector2(_vp.x * 0.26, _vp.y * GROUND_FRACTION)
	camera.position = _vp * 0.5

func _beat_setup() -> void:
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	mayor.set_arm_pose(CartoonActor.ArmPose.DROOP)
	for t in townsfolk:
		t.start_idle()
	dribble.set_expression(CartoonActor.Mood.WORRIED)
	dribble.set_arm_pose(CartoonActor.ArmPose.BRACE)
	# The drinker grabs the glass and eyes it defiantly.
	var grab := _ct(drinker)
	grab.tween_property(drinker, "position:x", _vp.x * 0.32, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	grab.tween_callback(func() -> void:
		drinker.set_arm_pose(CartoonActor.ArmPose.UP))
	var glass_hover := _ct(dirty_glass).set_loops(2)
	glass_hover.tween_property(dirty_glass, "rotation", 0.06, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glass_hover.tween_property(dirty_glass, "rotation", -0.06, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Impact frame: the drinker's crumple point.
func _impact_point() -> Vector2:
	return drinker.position + Vector2(0.0, -_vp.y * 0.08)

## BEAT 2 — the faint. Full impact stack ON the crumple.
func _on_impact() -> void:
	super._on_impact()
	# Bottoms up... then sideways.
	drinker.set_expression(CartoonActor.Mood.DIZZY)
	var chug := _ct(drinker)
	chug.tween_property(dirty_glass, "rotation", -1.9, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	chug.tween_callback(func() -> void:
		# Gulp. A beat. Then the eyes roll.
		drinker.set_expression(CartoonActor.Mood.SHOCKED))
	# The glass drops and rolls away.
	var drop_glass := _ct(dirty_glass)
	drop_glass.tween_interval(0.20)
	drop_glass.tween_property(dirty_glass, "rotation", 1.5, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop_glass.parallel().tween_property(dirty_glass, "position:y",
		_vp.y * GROUND_FRACTION - _vp.y * 0.03, 0.14)
	drop_glass.parallel().tween_property(dirty_glass, "position:x",
		dirty_glass.position.x + _vp.x * 0.06, 0.40) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# THE FAINT: a stiff board-fall with a comic little bounce.
	var faint := _ct(drinker)
	faint.tween_interval(0.16)
	faint.tween_callback(func() -> void:
		drinker.hop(10.0, 0.14))
	faint.tween_property(drinker, "rotation", PI * 0.5 * 1.0, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	faint.tween_property(drinker, "scale:y", 0.94, 0.08)
	faint.tween_property(drinker, "scale:y", 1.0, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# The town gasps.
	mayor.set_expression(CartoonActor.Mood.SHOCKED)
	mayor.hop(14.0, 0.24)
	for t in townsfolk:
		if t != drinker:
			t.set_expression(CartoonActor.Mood.PANIC)
			t.set_arm_pose(CartoonActor.ArmPose.BRACE)

## BEAT 3 — the town hangs Dribble upside down over the cliff edge and
## shakes them until the "specks" fall out.
func _beat_payoff() -> void:
	_hang_and_shake()

func _hang_and_shake() -> void:
	var ride_time := _payoff_sec()
	mayor.set_expression(CartoonActor.Mood.SMUG)
	# The hold: the remaining townsperson + the Mayor at the cliff edge.
	var holder := townsfolk[1]
	var hold_x := _vp.x * (CLIFF_X - 0.08)
	var haul := _ct()
	haul.tween_property(holder, "position:x", hold_x, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var mayor_go := _ct()
	mayor_go.tween_property(mayor, "position:x", hold_x + _vp.x * 0.06, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mayor_go.parallel().tween_property(mayor, "rotation", 0.0, 0.20)
	# Dribble is carried to the edge and flipped upside down.
	var carry := _ct()
	carry.tween_interval(0.18)
	carry.tween_property(dribble, "position",
		Vector2(_vp.x * CLIFF_X, _vp.y * GROUND_FRACTION - _vp.y * 0.06), 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	carry.parallel().tween_property(dribble, "rotation", PI, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	carry.tween_callback(func() -> void:
		dribble.set_expression(CartoonActor.Mood.DIZZY)
		dribble.set_arm_pose(CartoonActor.ArmPose.DROOP))
	# Dangle just past the lip.
	var dangle := _ct()
	dangle.tween_interval(0.36)
	dangle.tween_property(dribble, "position",
		Vector2(_vp.x * (CLIFF_X + 0.01), _vp.y * GROUND_FRACTION + _vp.y * 0.14), 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# THE SHAKE: brisk horizontal jolts; a speck shakes loose per jolt.
	var shake := _ct()
	shake.tween_interval(0.50)
	shake.tween_callback(func() -> void:
		dribble.set_arm_pose(CartoonActor.ArmPose.BRACE))
	var jolts := int(ride_time * 2.4)
	for j in range(jolts):
		var jolt := _ct()
		jolt.tween_interval(0.50 + 0.22 * float(j))
		jolt.tween_property(dribble, "position:x",
			_vp.x * (CLIFF_X + 0.01) + 12.0 * _content_scale, 0.05) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		jolt.tween_property(dribble, "position:x",
			_vp.x * (CLIFF_X + 0.01) - 10.0 * _content_scale, 0.05) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		jolt.tween_property(dribble, "position:x",
			_vp.x * (CLIFF_X + 0.01), 0.05)
		jolt.tween_callback(func() -> void:
			# A speck pops loose and tumbles into the abyss.
			var speck := Props.make_speck(9.0 * _content_scale)
			speck.position = dribble.position + Vector2(
				randf_range(-12.0, 12.0) * _content_scale, 0.0)
			speck.z_index = 7
			world.add_child(speck)
			var fall := _ct(speck)
			fall.tween_property(speck, "position:y", speck.position.y + _vp.y * 0.5, 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			fall.parallel().tween_property(speck, "modulate:a", 0.0, 0.5)
			fall.tween_callback(speck.queue_free))
	# The holders strain on every shake.
	var strain := _ct(mayor).set_loops(jolts)
	strain.tween_interval(0.50)
	strain.tween_property(mayor, "rotation", 0.05, 0.07)
	strain.tween_property(mayor, "rotation", 0.0, 0.07)
	mayor.set_arm_pose(CartoonActor.ArmPose.REACH)
	holder.set_arm_pose(CartoonActor.ArmPose.REACH)

