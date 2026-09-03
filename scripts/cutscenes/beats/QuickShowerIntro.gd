## QuickShower - CAUSE beat clip.
## Scene: res://scenes/ui/cutscenes/beats/QuickShowerIntro.tscn

extends MicrogameIntroBase

## Quick Shower — CAUSE clip.
## res://scenes/ui/cutscenes/beats/QuickShowerIntro.tscn
##
## BEAT 1  The bathroom queue. An hourglass timer hangs over the door; the
##         fill gauge under it sweeps; the town taps its feet.
## BEAT 2  (flash-only impact) The gauge redlines — the queue moans,
##         Dribble crosses his legs.
## BEAT 3  Dribble panic-knocks; the door shudders. SNAP into gameplay.

const Props := preload("res://scripts/cutscenes/beats/QuickShowerProps.gd")

const DOOR_W_FRAC := 0.14
const DOOR_H_FRAC := 0.30

var doorway: Node2D
var door_panel: Node2D
var hourglass: Node2D
var gauge: Node2D
var indicator: Polygon2D
var gauge_zone: Polygon2D
var gauge_width: float

func _setup_stage() -> void:
	get_node("Backdrop").color = Props.BG_BATH
	_stage_townsfolk(3, _vp.x * 0.26, _vp.x * 0.38)
	dribble = _stage_actor(CastFactory.make_dribble(), _vp.x * 0.44)
	mayor = _stage_actor(CastFactory.make_mayor(), _vp.x * 0.55, CastFactory.MAYOR_SCALE)
	CastFactory.dress_mayor(mayor)
	var door_w := _vp.x * DOOR_W_FRAC
	var door_h := _vp.y * DOOR_H_FRAC
	doorway = Props.make_door(door_w, door_h)
	doorway.position = Vector2(_vp.x * 0.70, _vp.y * GROUND_FRACTION)
	doorway.z_index = 4
	world.add_child(doorway)
	door_panel = doorway.get_node("Door") as Node2D
	# Fill gauge visible in the gap under the door.
	gauge_width = door_w * 0.9
	gauge = Props.make_gauge(gauge_width, _vp.y * 0.022)
	gauge.position = Vector2(doorway.position.x - gauge_width * 0.5, doorway.position.y + 2.0)
	gauge.z_index = 5
	world.add_child(gauge)
	indicator = gauge.get_node("Indicator") as Polygon2D
	gauge_zone = gauge.get_node("GreenZone") as Polygon2D
	# Giant hourglass timer mounted above the door.
	var hg_size := door_w * 0.55
	hourglass = Props.make_hourglass(hg_size)
	hourglass.position = Vector2(
		doorway.position.x,
		doorway.position.y - (door_h + 22.0) * _content_scale - hg_size - 6.0 * _content_scale
	)
	hourglass.z_index = 4
	world.add_child(hourglass)
	camera.zoom = Vector2(1.4, 1.4)
	camera.position = hourglass.position
	# Timer sweep: indicator crosses the gauge over the whole setup so the
	# redline lands exactly on the impact tick.
	indicator.position = Vector2(0.0, 0.0)
	var sweep := _ct()
	sweep.tween_property(indicator, "position:x", gauge_width, _setup_sec()) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## BEAT 1 — the queue. Sand runs, feet tap.
func _beat_setup() -> void:
	dribble.set_expression(CartoonActor.Mood.NEUTRAL)
	mayor.set_expression(CartoonActor.Mood.WORRIED)
	for t in townsfolk:
		t.set_expression(CartoonActor.Mood.WORRIED)
		t.start_idle()
	# Sand falls: top bulb drains, bottom pile hops up in pulses.
	var sand_top := hourglass.get_node("SandTop") as Polygon2D
	var sand_bot := hourglass.get_node("SandBottom") as Polygon2D
	var drain := _ct(sand_top)
	drain.tween_property(sand_top, "scale:y", 0.15, _setup_sec()) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var pile := _ct(sand_bot).set_loops(5)
	pile.tween_property(sand_bot, "scale:y", 1.12, _setup_sec() / 5.0)
	pile.tween_property(sand_bot, "scale:y", 1.0, 0.06)
	# The whole queue taps feet: tiny staggered hops.
	for i in range(townsfolk.size()):
		var tw := _ct().set_loops(6)
		tw.tween_interval(0.18 + 0.09 * float(i))
		tw.tween_callback(townsfolk[i].hop.bind(5.0, 0.12))
	var mayor_tw := _ct().set_loops(6)
	mayor_tw.tween_interval(0.24)
	mayor_tw.tween_callback(mayor.hop.bind(5.0, 0.12))

## BEAT 2 — redline. Intro contract: flash only. The indicator hits the end
## of the gauge as the tick lands; the queue groans; Dribble crosses legs.
func _on_impact() -> void:
	_impact_flash()
	# Gauge flips to the over-fill red.
	gauge_zone.color = Props.RED_ZONE
	indicator.color = Props.RED_ZONE
	# The hourglass wobbles — time is up.
	var wob := _ct(hourglass)
	wob.tween_property(hourglass, "rotation", 0.10, 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wob.tween_property(hourglass, "rotation", -0.10, 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wob.tween_property(hourglass, "rotation", 0.0, 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Queue reaction chain: SHOCKED hops back-to-front.
	var queue: Array = [dribble, mayor]
	for t in townsfolk:
		queue.append(t)
	for i in range(queue.size()):
		var member := queue[i] as CartoonActor
		member.set_expression(CartoonActor.Mood.SHOCKED)
		var tw := _ct()
		tw.tween_interval(0.05 * float(i))
		tw.tween_callback(member.hop.bind(14.0, 0.24))
	mayor.drip_sweat()
	# Dribble crosses his legs: squash-and-hold.
	var squeeze := _ct(dribble)
	squeeze.tween_property(dribble, "scale", Vector2(0.92, 1.08) * _content_scale, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	squeeze.tween_property(dribble, "scale", Vector2.ONE * _content_scale, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## BEAT 3 — Dribble panic-knocks; the door shudders.
func _beat_payoff() -> void:
	dribble.set_expression(CartoonActor.Mood.PANIC)
	dribble.set_arm_pose(CartoonActor.ArmPose.REACH)
	# He darts to the door and knocks.
	var knock_x := doorway.position.x - _vp.x * DOOR_W_FRAC * 0.5 - 24.0 * _content_scale
	var dart := _ct()
	dart.tween_property(dribble, "position:x", knock_x, 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dart.tween_callback(func() -> void: dribble.hop(12.0, 0.22))
	# Knock knocks: door panel judders on its hinge.
	var knock := _ct(door_panel).set_loops(3)
	knock.tween_property(door_panel, "rotation", -0.05, 0.06)
	knock.tween_property(door_panel, "rotation", 0.0, 0.06)
	# The queue braces behind him.
	for i in range(townsfolk.size()):
		var tw := _ct()
		tw.tween_interval(0.10 + 0.06 * float(i))
		tw.tween_callback(townsfolk[i].set_arm_pose.bind(CartoonActor.ArmPose.BRACE))
	mayor.set_arm_pose(CartoonActor.ArmPose.BRACE)

