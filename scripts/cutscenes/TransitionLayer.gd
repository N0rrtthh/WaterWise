class_name TransitionLayer
extends CanvasLayer

## SNAP-transition (beat 4 of the cutscene rhythm) for the Microgame beat tier.
##
## Contract from the beat spec: the cut NEVER resolves with a plain fade. The
## stage hands off via a fast directional wipe (WHIP_PAN), a radial zoom cover
## (ZOOM_SNAP), or a two-step white-then-black cut (FLASH_CUT). Every variant
## ends with the screen fully covered, so whatever is swapped in behind it
## (score page, next scene) never shows a partial frame.
##
## Total snap duration: 0.2–0.3 s. The layer self-contains its cover rect, so a
## per-game beat scene never has to author transition nodes.

enum Snap { WHIP_PAN, ZOOM_SNAP, FLASH_CUT }

## The "ink" slab colour — matches the CartoonStage palette's dark tone.
const COVER_COLOR := Color(0.07, 0.09, 0.12)

var _cover: ColorRect

func _ensure_cover(color: Color) -> ColorRect:
	if _cover and is_instance_valid(_cover):
		_cover.queue_free()
	_cover = ColorRect.new()
	_cover.name = "Cover"
	_cover.color = color
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)
	return _cover

## Plays the outgoing snap. Returns when the screen is fully covered.
func snap_out(kind: int = Snap.WHIP_PAN, duration: float = 0.25) -> void:
	layer = 100
	match kind:
		Snap.WHIP_PAN:
			_whip_pan(duration)
		Snap.ZOOM_SNAP:
			_zoom_snap(duration)
		_:
			_flash_cut(duration)

## Plays the incoming snap (cover peels away). Call after the new content is
## behind the layer. The cover frees itself when fully clear.
func snap_in(kind: int = Snap.ZOOM_SNAP, duration: float = 0.22) -> void:
	layer = 100
	var cover := _cover
	if not cover or not is_instance_valid(cover):
		cover = _ensure_cover(COVER_COLOR)
		cover.size = get_viewport().get_visible_rect().size
	match kind:
		Snap.WHIP_PAN:
			var vp := get_viewport().get_visible_rect().size
			var t := create_tween()
			t.tween_property(cover, "position:x", vp.x, duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_callback(cover.queue_free)
		Snap.ZOOM_SNAP:
			cover.pivot_offset = cover.size * 0.5
			var t := create_tween()
			t.tween_property(cover, "scale", Vector2(0.02, 0.02), duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_callback(cover.queue_free)
		_:
			var t := create_tween()
			t.tween_property(cover, "color", Color(1, 1, 1, 0), duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_callback(cover.queue_free)

# ── Snap variants ─────────────────────────────────────────────────────────

## Directional screen wipe. Two thin "streak" slabs lead the main slab by a
## few frames so the eye reads motion, not a rectangle sliding across.
func _whip_pan(duration: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var main := _ensure_cover(COVER_COLOR)
	main.size = vp
	main.position = Vector2(-vp.x, 0)
	var streak_a := _make_slab(Color(COVER_COLOR.r, COVER_COLOR.g, COVER_COLOR.b, 0.55),
		Vector2(vp.x * 0.12, vp.y))
	var streak_b := _make_slab(Color(COVER_COLOR.r, COVER_COLOR.g, COVER_COLOR.b, 0.3),
		Vector2(vp.x * 0.06, vp.y * 0.8))
	var lead := vp.x * 0.16
	for slab: ColorRect in [streak_b, streak_a]:
		slab.position = Vector2(-slab.size.x - lead, 0)
		var st := create_tween()
		st.tween_property(slab, "position:x", vp.x + lead, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		st.tween_callback(slab.queue_free)
	var t := create_tween()
	t.tween_property(main, "position:x", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Radial cover that accelerates from a pinprick at screen centre — reads as
## the camera "snapping" into the next shot.
func _zoom_snap(duration: float) -> void:
	var cover := _ensure_cover(COVER_COLOR)
	var vp := get_viewport().get_visible_rect().size
	cover.size = vp
	cover.pivot_offset = vp * 0.5
	cover.scale = Vector2(0.04, 0.04)
	var t := create_tween()
	t.tween_property(cover, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Chirpy camera-flash cut: white bloom, then hard cut to the ink slab.
func _flash_cut(duration: float) -> void:
	var cover := _ensure_cover(Color.WHITE)
	var vp := get_viewport().get_visible_rect().size
	cover.size = vp
	var t := create_tween()
	t.tween_property(cover, "color", COVER_COLOR, duration * 0.7) \
		.set_delay(duration * 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _make_slab(color: Color, slab_size: Vector2) -> ColorRect:
	var slab := ColorRect.new()
	slab.color = color
	slab.size = slab_size
	slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slab)
	return slab
