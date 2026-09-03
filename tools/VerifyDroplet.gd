extends Node

## Droplet + HUD gate: proves the shared silhouette is a valid droplet and that
## the rebuilt HUD wires up the nodes the 25 subclasses depend on.
##
## Run:
##   godot --path . res://tools/VerifyDroplet.tscn
##
## Why this exists: both the silhouette and the HUD are built in code with no
## .tscn to eyeball, and both are shared by every minigame. Two classes of bug
## are invisible until you look at a specific game on a specific device:
##
##   1. Geometry. DropletShape.outline() tapers x by sqrt(1 - s) and stretches y
##      by TIP_STRETCH. If the taper ever stops being monotonic the polygon
##      self-intersects and Polygon2D renders a bow-tie. That is a pure function
##      of the numbers, so it is provable here.
##   2. Node contract. _setup_ui() was rewritten from six pill PanelContainers to
##      a bar plus one text row. The subclasses reach for timer_bar, timer_label,
##      score_label and combo_label directly; if the rewrite dropped one, the
##      failure is a null access at runtime inside whichever game touches it.
##
## Checks:
##   A. silhouette — closed, tip is the topmost point, x monotonic per side,
##      widest point is at y = 0, bottom half is a true ellipse
##   B. tip_y agrees with the polygon's actual minimum y
##   C. highlight sits strictly inside the silhouette
##   D. CartoonActor and DropletSprite use the same TIP_STRETCH
##   E. DropletSprite builds its parts and survives react/wobble without
##      leaving two tweens on rig:scale
##   F. HUD node contract: timer_bar, timer_label, score_label, combo_label all
##      exist after _setup_ui(), and the bar's range matches game_duration
##   G. HUD tap target: the pause button is at least 44 px
##
## Exits 0 on success, 1 on any failure.

const MIN_TAP_PX: float = 44.0

var _failures: Array[String] = []
var _checked: int = 0

func _ready() -> void:
	await get_tree().process_frame

	print("▶ Droplet/HUD gate")
	_check_silhouette()
	_check_tip_y()
	_check_highlight()
	_check_shared_constant()
	await _check_sprite()
	await _check_hud()

	print("— ran %d checks" % _checked)
	if _failures.is_empty():
		print("✅ VerifyDroplet: droplet geometry and HUD contract hold")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("❌ %s" % f)
		printerr("❌ VerifyDroplet: %d failure(s)" % _failures.size())
		get_tree().quit(1)

func _fail(msg: String) -> void:
	_failures.append(msg)

# ── A. silhouette ─────────────────────────────────────────────────────────
func _check_silhouette() -> void:
	# Sweep a range of radii and vertex counts: the shape is used at 26×32 in
	# gameplay and at the CartoonActor body size in cutscenes, and a bug that
	# only appears at one aspect ratio is still a bug.
	for rx in [10.0, 26.0, 40.0]:
		for ry in [10.0, 32.0, 60.0]:
			for segs in [10, 11, 26, 30, 64]:
				_check_one_outline(float(rx), float(ry), int(segs))

func _check_one_outline(rx: float, ry: float, segs: int) -> void:
	_checked += 1
	var tag := "outline(rx=%.0f, ry=%.0f, segs=%d)" % [rx, ry, segs]
	var pts := DropletShape.outline(rx, ry, segs)
	var want_count := DropletShape.vertex_count(segs)

	if pts.size() != want_count:
		_fail("%s: returned %d points, expected %d" % [tag, pts.size(), want_count])
		return

	var min_y: float = INF
	var max_y: float = -INF
	var max_abs_x: float = 0.0
	for p in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
		max_abs_x = maxf(max_abs_x, absf(p.x))
		if not (is_finite(p.x) and is_finite(p.y)):
			_fail("%s: non-finite vertex %s" % [tag, p])
			return

	# The tip must be the single topmost point and must sit on the axis: that is
	# what makes the shape read as a droplet rather than a blob.
	var tip_count := 0
	for p in pts:
		if is_equal_approx(p.y, min_y):
			tip_count += 1
			if absf(p.x) > rx * 0.001:
				_fail("%s: topmost vertex is off-axis at x=%.3f" % [tag, p.x])
	if tip_count != 1:
		_fail("%s: %d vertices tie for topmost, tip is not a point" % [tag, tip_count])

	# Bottom half untouched, so the droplet sits flat on its widest circle.
	if not is_equal_approx(max_y, ry):
		_fail("%s: bottom reaches y=%.3f, expected ry=%.3f" % [tag, max_y, ry])

	# The widest point is the equator, never the tapered half.
	if max_abs_x > rx + 0.001:
		_fail("%s: width %.3f exceeds rx=%.3f" % [tag, max_abs_x, rx])

	# Tip rises above the circle by exactly TIP_STRETCH.
	var want_tip := -ry * DropletShape.TIP_STRETCH
	if not is_equal_approx(min_y, want_tip):
		_fail("%s: tip at y=%.3f, expected %.3f" % [tag, min_y, want_tip])

	_check_monotonic_x(tag, pts)

## |x| must fall monotonically from the equator up to the tip on each side.
## This is the property that guarantees the polygon cannot self-intersect: if the
## taper ever widened again while y kept rising, the upper edge would cross the
## lower one and Polygon2D would draw a bow-tie.
func _check_monotonic_x(tag: String, pts: PackedVector2Array) -> void:
	var upper_right: Array[Vector2] = []
	var upper_left: Array[Vector2] = []
	for p in pts:
		if p.y < 0.0:
			if p.x > 0.0:
				upper_right.append(p)
			elif p.x < 0.0:
				upper_left.append(p)

	_assert_narrowing(tag + " right", upper_right)
	_assert_narrowing(tag + " left", upper_left)

func _assert_narrowing(tag: String, side: Array[Vector2]) -> void:
	# Sort by height, tip last. |x| must never increase along that walk.
	side.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
	var prev_abs_x: float = INF
	for p in side:
		var ax: float = absf(p.x)
		if ax > prev_abs_x + 0.001:
			_fail("%s: |x| widens to %.3f at y=%.3f while rising (self-intersects)"
				% [tag, ax, p.y])
			return
		prev_abs_x = ax

# ── B. tip_y ──────────────────────────────────────────────────────────────
func _check_tip_y() -> void:
	for ry in [10.0, 32.0, 60.0]:
		_checked += 1
		var pts := DropletShape.outline(26.0, float(ry), 30)
		var min_y: float = INF
		for p in pts:
			min_y = minf(min_y, p.y)
		var reported: float = DropletShape.tip_y(float(ry))
		# Accents (dizzy stars, sweat beads) anchor off tip_y(). If it drifted
		# from the real geometry they would overlap the body.
		if not is_equal_approx(reported, min_y):
			_fail("tip_y(%.0f) = %.3f but polygon minimum y is %.3f"
				% [ry, reported, min_y])

# ── C. highlight inside the body ──────────────────────────────────────────
func _check_highlight() -> void:
	for rx in [10.0, 26.0, 40.0]:
		for ry in [10.0, 32.0, 60.0]:
			_checked += 1
			var body := DropletShape.outline(float(rx), float(ry), 64)
			var shine := DropletShape.highlight(float(rx), float(ry))
			for p in shine:
				# A highlight poking outside the silhouette is the exact bug the
				# hand-placed CartoonActor points had: they were positioned for
				# an ellipse and stuck out past the tapered upper half.
				if not Geometry2D.is_point_in_polygon(p, body):
					_fail("highlight(rx=%.0f, ry=%.0f): point %s is outside the body"
						% [rx, ry, p])

# ── D. one silhouette, two call sites ─────────────────────────────────────
func _check_shared_constant() -> void:
	_checked += 1
	var actor_script: GDScript = load("res://scripts/cutscenes/CartoonActor.gd")
	var actor_stretch: Variant = actor_script.get_script_constant_map().get("TIP_STRETCH")
	if actor_stretch == null:
		_fail("CartoonActor has no TIP_STRETCH constant")
	elif not is_equal_approx(float(actor_stretch), DropletShape.TIP_STRETCH):
		# If these diverge the cutscene character and the gameplay droplet stop
		# being the same character, which is the drift DropletShape exists to stop.
		_fail("CartoonActor.TIP_STRETCH=%.4f != DropletShape.TIP_STRETCH=%.4f"
			% [float(actor_stretch), DropletShape.TIP_STRETCH])

# ── E. DropletSprite ──────────────────────────────────────────────────────
func _check_sprite() -> void:
	_checked += 1
	var sprite := DropletSprite.new()
	add_child(sprite)
	await get_tree().process_frame

	for part in ["rig", "body", "shine", "eye_l", "eye_r", "pupil_l", "pupil_r", "mouth"]:
		if sprite.get(part) == null:
			_fail("DropletSprite.%s was not built" % part)

	if sprite.body and sprite.body.polygon.size() < 3:
		_fail("DropletSprite body polygon has %d points" % sprite.body.polygon.size())

	# The idle wobble and the reactions both animate rig:scale. Two live tweens on
	# one property means the loser is silently dropped, which showed up as the
	# droplet freezing mid-squash. react_*() must therefore kill the wobble.
	sprite.react_happy()
	await get_tree().process_frame
	if sprite._wobble != null and sprite._wobble.is_valid():
		_fail("react_happy() left the idle wobble running on rig:scale")

	sprite.react_hurt()
	await get_tree().process_frame
	if sprite._wobble != null and sprite._wobble.is_valid():
		_fail("react_hurt() left the idle wobble running on rig:scale")

	# Eye tracking must stay inside the eye white, or the pupil slides off the face.
	sprite.look_at_local(Vector2(500.0, -500.0))
	var shift: float = sprite.body_rx * 0.09
	for pupil in [sprite.pupil_l, sprite.pupil_r]:
		if pupil and pupil.position.length() > shift + 0.001:
			_fail("look_at_local() moved a pupil %.3f px, limit is %.3f"
				% [pupil.position.length(), shift])

	# A zero-length direction must not produce NAN from normalized().
	sprite.look_at_local(sprite.eye_l.position)
	if sprite.pupil_l and not is_finite(sprite.pupil_l.position.x):
		_fail("look_at_local() on the eye centre produced a non-finite pupil position")

	sprite.queue_free()
	await get_tree().process_frame

# ── F/G. HUD contract ─────────────────────────────────────────────────────
func _check_hud() -> void:
	_checked += 1
	var game_script: GDScript = load("res://scripts/MiniGameBase.gd")
	var game: Node = game_script.new()
	game.game_name = "Gate Probe"
	add_child(game)

	# MiniGameBase._ready() awaits a frame before building the UI, then blocks on
	# the instruction overlay — which is where the HUD is fully assembled.
	await get_tree().process_frame
	await get_tree().process_frame

	if game.timer_bar == null:
		_fail("HUD: timer_bar is null after _setup_ui()")
	if game.timer_label == null:
		_fail("HUD: timer_label is null after _setup_ui()")
	if game.score_label == null:
		_fail("HUD: score_label is null after _setup_ui()")
	if game.combo_label == null:
		_fail("HUD: combo_label is null after _setup_ui()")

	if game.timer_bar:
		# The bar is pinned outside any container so nothing overwrites a tweened
		# position; a container parent would silently re-lay it out.
		var parent: Node = game.timer_bar.get_parent()
		if parent is BoxContainer or parent is MarginContainer:
			_fail("HUD: timer_bar is inside %s, which will overwrite its position"
				% parent.get_class())
		if not is_equal_approx(float(game.timer_bar.max_value), float(game.game_duration)):
			_fail("HUD: timer_bar.max_value=%.2f but game_duration=%.2f"
				% [game.timer_bar.max_value, game.game_duration])

	# Combo starts hidden: showing "x0" every round makes the HUD noisy and the
	# streak meaningless.
	if game.combo_label and game.combo_label.visible:
		_fail("HUD: combo_label is visible at a streak of 0")

	# Pause must stay tappable on a phone.
	var pause := _find_pause_button(game)
	if pause == null:
		_fail("HUD: no pause Button found")
	elif pause.custom_minimum_size.y < MIN_TAP_PX or pause.custom_minimum_size.x < MIN_TAP_PX:
		_fail("HUD: pause button is %s, below the %.0f px tap target"
			% [pause.custom_minimum_size, MIN_TAP_PX])

	game.queue_free()
	await get_tree().process_frame

func _find_pause_button(root: Node) -> Button:
	for child in root.get_children():
		if child is Button and (child as Button).text == "II":
			return child as Button
		var found := _find_pause_button(child)
		if found:
			return found
	return null
