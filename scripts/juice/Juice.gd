class_name Juice
extends Object

## Static "juice" vocabulary for the DWTD-style rehaul. Every microgame calls
## these instead of hand-rolling tweens, so the whole suite shares one motion
## language: elastic overshoot on success, aggressive shake on failure.
##
## Memory contract: nodes passed in are ALWAYS pooled by the caller (EntityPool
## or pre-allocated HUD nodes). Juice itself only creates Tweens — lightweight,
## ref-counted command lists that Godot recycles automatically; no Node, Array
## or Dictionary is ever allocated here. Base scales/rest positions are cached
## in meta on first use so repeated calls never compound.

const POP_SCALE: float = 1.35
const POP_TIME: float = 0.32
const SQUASH_STRENGTH: float = 0.35
const SHAKE_STRENGTH: float = 14.0
const SHAKE_TIME: float = 0.38
const META_BASE_SCALE: String = "_juice_base_scale"
const META_REST_POS: String = "_juice_rest_pos"

## One tween slot per property group. Two live tweens on the SAME property fight:
## both keep writing it every frame, the later one merely wins the last write, and
## whichever finishes last decides where the node is left parked. That is exactly
## what fast repeats produce — a combo punches the score label every hit while the
## previous 0.28 s punch is still running, and a miss streak restarts the shake
## mid-shake. Killing the previous tween for that property first makes repeats
## restart cleanly; every function below writes its start value explicitly, so a
## kill can never strand a node part-way through a curve.
##
## Separate slots because the groups must not evict each other: a shake killing a
## half-finished pop would leave the node stuck at 1.35x scale forever.
const META_TWEEN_SCALE: String = "_juice_tw_scale"
const META_TWEEN_POS: String = "_juice_tw_pos"
const META_TWEEN_COLOR: String = "_juice_tw_color"


static func _fresh_tween(node: Node, slot: String) -> Tween:
	if node.has_meta(slot):
		var old: Tween = node.get_meta(slot)
		if old != null and old.is_valid():
			old.kill()
	var tw := node.create_tween()
	node.set_meta(slot, tw)
	return tw


## Cached rest scale for a node — captured on first call, reused forever.
static func base_scale(node: Node2D) -> Vector2:
	if node.has_meta(META_BASE_SCALE):
		return node.get_meta(META_BASE_SCALE)
	var s := node.scale
	node.set_meta(META_BASE_SCALE, s)
	return s


## Cached rest position for a Node2D that shake() may displace.
static func rest_position(node: Node2D) -> Vector2:
	if node.has_meta(META_REST_POS):
		return node.get_meta(META_REST_POS)
	var p := node.position
	node.set_meta(META_REST_POS, p)
	return p


## Elastic overshoot pop — the universal "this reacted to your tap" cue.
## Fires the exact frame it is called; the overshoot sells the impact.
static func pop(node: Node2D, amount: float = POP_SCALE, duration: float = POP_TIME) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base := base_scale(node)
	node.scale = base * amount
	var tw := _fresh_tween(node, META_TWEEN_SCALE)
	tw.tween_property(node, "scale", base, duration) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Directional squash-and-stretch: flattens along `dir` (unit vector) then
## elastic-snaps back. Use for catch impacts, landings, drum hits.
static func squash(node: Node2D, dir: Vector2 = Vector2(0.0, 1.0), strength: float = SQUASH_STRENGTH) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base := base_scale(node)
	# Decompose dir into a per-axis scale pair: squeeze along dir, stretch
	# perpendicular to it (volume roughly conserved — reads as physical).
	var flat := Vector2(
		1.0 - strength * absf(dir.x) + strength * absf(dir.y) * 0.5,
		1.0 - strength * absf(dir.y) + strength * absf(dir.x) * 0.5
	)
	node.scale = base * flat
	var tw := _fresh_tween(node, META_TWEEN_SCALE)
	tw.tween_property(node, "scale", base, 0.3) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Aggressive decaying shake for failures. Displaces `node` around its cached
## rest position; always settles exactly back home. 8 alternating steps.
static func shake(node: Node2D, strength: float = SHAKE_STRENGTH, duration: float = SHAKE_TIME) -> void:
	if node == null or not is_instance_valid(node):
		return
	var rest := rest_position(node)
	node.position = rest
	var tw := _fresh_tween(node, META_TWEEN_POS)
	var steps: int = 8
	for i in range(steps):
		var dir := 1.0 if i % 2 == 0 else -1.0
		var falloff: float = 1.0 - float(i) / float(steps)
		var t: float = duration / float(steps)
		tw.tween_property(node, "position:x", rest.x + dir * strength * falloff, t)
	tw.tween_property(node, "position", rest, 0.05)


## One big overshoot punch on a Label (score popups, combo counters).
## Centers the pivot once so the label scales from its middle.
static func punch_label(label: Label, amount: float = 1.4) -> void:
	if label == null or not is_instance_valid(label):
		return
	if not label.has_meta(META_BASE_SCALE):
		label.pivot_offset = label.size * 0.5
		label.set_meta(META_BASE_SCALE, Vector2.ONE)
	label.scale = Vector2.ONE * amount
	var tw := _fresh_tween(label, META_TWEEN_SCALE)
	tw.tween_property(label, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fade a full-screen ColorRect flash out. Caller owns (pools) the rect.
static func flash(rect: ColorRect, color: Color, duration: float = 0.25) -> void:
	if rect == null or not is_instance_valid(rect):
		return
	rect.color = color
	var tw := _fresh_tween(rect, META_TWEEN_COLOR)
	tw.tween_property(rect, "color:a", 0.0, duration)
