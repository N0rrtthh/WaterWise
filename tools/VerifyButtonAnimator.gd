extends Node

## ═══════════════════════════════════════════════════════════════════
## BUTTONANIMATOR HARNESS — the autoload that animates EVERY button
## ═══════════════════════════════════════════════════════════════════
## autoload/ButtonAnimator.gd hooks every BaseButton in the tree from
## get_tree().node_added, so anything wrong in it is wrong on every screen in the
## game at once. Three defects are measured here, each with a control beside it.
##
## 1. AUTHORED BASE SCALE IS LOST ACROSS A REMOVE / RE-ADD.
##    _hook_button() stores button.scale in _button_base_scales and every animation
##    is expressed as base * factor. _on_button_removed() (wired to tree_exiting)
##    erases that entry, and re-hooking is attempted through
##    `btn.ready.connect(..., CONNECT_ONE_SHOT)` — but Node.ready fires ONCE per
##    node lifetime, so a re-added button never re-hooks. Its mouse_entered /
##    pressed connections from the first hook are still live (nothing disconnects
##    them), so the next hover runs with `base` falling back to Vector2.ONE and a
##    button authored at any other scale SNAPS to the wrong size. Menus that hide
##    and re-show a panel by remove_child/add_child hit this.
##
## 2. PRESS SETTLES AT HOVER SCALE ON TOUCH.
##    _on_pressed() decides where to settle by asking whether the MOUSE POSITION is
##    inside the button. On a touch device with emulate_mouse_from_touch (Godot's
##    default, and on in this project) a tap leaves the emulated cursor sitting
##    inside the button that was tapped, so is_hovered reads true, the button
##    settles at base * HOVER_SCALE, and no mouse_exited ever arrives to bring it
##    back down. The button stays permanently 10% enlarged. This project is an
##    Android thesis build: touch IS the input path.
##    Measured headlessly by putting the button's rect over the headless cursor
##    position, which is the same condition a tap creates.
##
## 3. NO REDUCED-MOTION SUPPORT.
##    Every duration here is a literal. AccessibilityManager.get_animation_speed()
##    is not consulted, so the hover/press animations run full length with reduced
##    motion on. Buttons must get SHORTER feedback, not none — an unanimated button
##    still has to acknowledge the tap.
##
## Usage:
##   godot --headless --path . res://tools/VerifyButtonAnimator.tscn

## A deliberately non-unit authored scale: with the base-scale bug the button
## animates around 1.0 instead, which is far outside any easing overshoot.
const AUTHORED_SCALE: Vector2 = Vector2(1.25, 1.25)
## HOVER_SCALE / PRESS_* from ButtonAnimator, restated so a change there shows up
## here as a failure rather than being silently tracked.
const HOVER_SCALE: float = 1.10
## Longest chain: press is 0.07 + 0.06 + 0.10 = 0.23s. 1.2s is ample.
const SETTLE_WAIT: float = 1.2
## Hover chain at full speed: 0.10 + 0.09 = 0.19s.
const HOVER_LEN: float = 0.19
const EXPECTED_FACTOR: float = 3.0

var results: Array = []
var original_reduced: bool = false


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


## A button placed over the headless cursor position, so the mouse-position probe
## inside _on_pressed() reads "inside" — exactly what a tap leaves behind on
## Android with emulate_mouse_from_touch on.
func _make_button_under_cursor() -> Button:
	var b := Button.new()
	b.text = "OK"
	b.size = Vector2(400, 200)
	b.position = get_viewport().get_mouse_position() - Vector2(200, 100)
	b.scale = AUTHORED_SCALE
	return b


## A button far from the cursor, so the same probe reads "outside".
func _make_button_away_from_cursor() -> Button:
	var b := Button.new()
	b.text = "OK"
	b.size = Vector2(120, 60)
	b.position = get_viewport().get_mouse_position() + Vector2(900, 700)
	b.scale = AUTHORED_SCALE
	return b


func _settle(button: Button) -> void:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < SETTLE_WAIT:
		await get_tree().process_frame


func _hooked(button: Button) -> bool:
	# The autoload connects a BOUND callable, so the bind has to be reproduced for
	# is_connected() to match it.
	return button.pressed.is_connected(
		Callable(ButtonAnimator, "_on_pressed").bind(button))


# ── 1. authored base scale across a remove / re-add ──────────────────

func _test_base_scale_reuse() -> void:
	var b := _make_button_away_from_cursor()
	add_child(b)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("control: a freshly added button gets hooked at all",
		_hooked(b), "hooked = %s" % str(_hooked(b)))

	# The control half: hover BEFORE any re-add must respect the authored scale.
	b.mouse_entered.emit()
	await _settle(b)
	var first_hover := b.scale
	_check("control: on a first hover the button grows from its authored scale",
		first_hover.x >= AUTHORED_SCALE.x,
		"scale %.3f, authored %.3f (expected authored * %.2f = %.3f)"
			% [first_hover.x, AUTHORED_SCALE.x, HOVER_SCALE,
				AUTHORED_SCALE.x * HOVER_SCALE])
	b.mouse_exited.emit()
	await _settle(b)

	# The screen-hides-a-panel pattern: remove, then put it back.
	remove_child(b)
	await get_tree().process_frame
	add_child(b)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("a re-added button is still hooked (Node.ready cannot fire twice)",
		_hooked(b), "hooked = %s" % str(_hooked(b)))

	b.mouse_entered.emit()
	await _settle(b)
	var second_hover := b.scale
	_check("a re-added button hovers from its authored scale, not from 1.0",
		second_hover.x >= AUTHORED_SCALE.x,
		("scale %.3f after re-add vs %.3f on the first hover — below the authored"
			+ " %.3f means base fell back to Vector2.ONE and the button snapped")
			% [second_hover.x, first_hover.x, AUTHORED_SCALE.x])
	b.mouse_exited.emit()
	await _settle(b)
	_check("hover-out returns a re-added button to its authored scale",
		absf(b.scale.x - AUTHORED_SCALE.x) < 0.01,
		"scale %.3f, authored %.3f" % [b.scale.x, AUTHORED_SCALE.x])
	b.queue_free()


# ── 2. press settle on touch ─────────────────────────────────────────

func _test_touch_press_settles() -> void:
	# The control: a button the cursor is genuinely NOT over. Its press must end at
	# the authored scale, and it does so today for the right reason, so this stays
	# green either way and proves the measurement is reading the real settle point.
	var away := _make_button_away_from_cursor()
	add_child(away)
	await get_tree().process_frame
	await get_tree().process_frame
	away.pressed.emit()
	await _settle(away)
	_check("control: a press with no hover settles back to the authored scale",
		absf(away.scale.x - AUTHORED_SCALE.x) < 0.01,
		"scale %.3f, authored %.3f" % [away.scale.x, AUTHORED_SCALE.x])
	away.queue_free()

	# The touch case: the button sits under the cursor position, which is what a tap
	# leaves behind, but no mouse_entered was ever delivered — there is no hover on a
	# touchscreen. It must still settle back down.
	var tapped := _make_button_under_cursor()
	add_child(tapped)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("control: the tapped button really is under the cursor position",
		tapped.get_global_rect().has_point(get_viewport().get_mouse_position()),
		"rect %s contains %s" % [str(tapped.get_global_rect()),
			str(get_viewport().get_mouse_position())])
	tapped.pressed.emit()
	await _settle(tapped)
	var settled := tapped.scale.x
	_check("a tap with no hover does not leave the button stuck enlarged",
		absf(settled - AUTHORED_SCALE.x) < 0.01,
		("settled at %.3f, authored %.3f (hover settle would be %.3f and never comes"
			+ " back down on touch — no mouse_exited is ever delivered)")
			% [settled, AUTHORED_SCALE.x, AUTHORED_SCALE.x * HOVER_SCALE])

	# And the genuine-hover path must still settle enlarged, or the fix would have
	# simply deleted the hover feedback instead of correcting its trigger.
	tapped.mouse_entered.emit()
	await _settle(tapped)
	tapped.pressed.emit()
	await _settle(tapped)
	_check("a press WHILE hovered still settles at hover scale (feedback intact)",
		absf(tapped.scale.x - AUTHORED_SCALE.x * HOVER_SCALE) < 0.01,
		"settled at %.3f, expected %.3f"
			% [tapped.scale.x, AUTHORED_SCALE.x * HOVER_SCALE])
	tapped.queue_free()


# ── 3. reduced motion ────────────────────────────────────────────────

## Time a hover-in to completion, by asking the Tween itself when it stops running.
##
## Two earlier discriminators were unsound and are recorded here so they do not come
## back. Sampling the scale at a fixed instant inverts on a frame hitch. Polling for
## the scale to REACH the hover value is worse: the first leg of the chain targets
## base * HOVER_OVERSHOOT (1.18) with TRANS_BACK, so it sails straight THROUGH the
## 1.10 hover value on its way up — a "reached it" poll therefore stops the clock
## partway into leg one and reported 0.013s for a 0.19s animation.
## The Tween runs the whole chain, so its own is_running() is the honest end point.
func _time_hover(reduced: bool) -> float:
	AccessibilityManager.reduced_motion = reduced
	var b := _make_button_away_from_cursor()
	add_child(b)
	await get_tree().process_frame
	await get_tree().process_frame
	var target: float = AUTHORED_SCALE.x * HOVER_SCALE
	b.mouse_entered.emit()
	var tw: Tween = ButtonAnimator._button_tweens.get(b, null) as Tween
	if tw == null:
		b.queue_free()
		print("  [reduced_motion=%s] NO TWEEN was created for the hover" % str(reduced))
		return -1.0
	var start := Time.get_ticks_msec()
	var elapsed := 0.0
	while elapsed < SETTLE_WAIT:
		await get_tree().process_frame
		elapsed = (Time.get_ticks_msec() - start) / 1000.0
		if not tw.is_running():
			break
	var reached: bool = absf(b.scale.x - target) < 0.01
	b.queue_free()
	print("  [reduced_motion=%s] hover chain ran %.3fs, settled at %.3f (want %.3f)%s"
		% [str(reduced), elapsed, b.scale.x, target,
			"" if reached else "  (WRONG SETTLE POINT)"])
	return elapsed if reached else -1.0


func _test_reduced_motion() -> void:
	var full: float = await _time_hover(false)
	var reduced: float = await _time_hover(true)
	AccessibilityManager.reduced_motion = false

	# Bounded on BOTH sides: an upper bound alone is satisfied by an animation that
	# collapsed to nothing, which is what the discarded discriminator reported.
	_check("control: at full speed the hover takes its authored ~%.2fs" % HOVER_LEN,
		full > HOVER_LEN - 0.06 and full < HOVER_LEN + 0.12,
		"took %.3fs (authored %.2fs)" % [full, HOVER_LEN])
	var target: float = HOVER_LEN / EXPECTED_FACTOR
	_check("with reduced motion the hover completes in about %.2fs" % target,
		reduced > 0.0 and reduced <= target + 0.06,
		"took %.3fs (limit %.3fs)" % [reduced, target + 0.06])
	_check("the button still reaches its hover scale under reduced motion"
			+ " (shortened, not removed)",
		reduced > 0.0, "completion %.3fs (-1 means it never got there)" % reduced)
	_check("the hover is at least 2x faster under reduced motion",
		reduced > 0.0 and full / reduced >= 2.0,
		"%.3fs vs %.3fs = %.2fx"
			% [full, reduced, (full / reduced) if reduced > 0.0 else 0.0])


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  BUTTONANIMATOR HARNESS")
	print("═══════════════════════════════════════════════════════════")
	original_reduced = bool(AccessibilityManager.reduced_motion)
	await get_tree().process_frame
	await _test_base_scale_reuse()
	await _test_touch_press_settles()
	await _test_reduced_motion()
	# Written directly, never through set_reduced_motion(), which would persist a
	# change to the player's real settings file.
	AccessibilityManager.reduced_motion = original_reduced
	print("")
	print("  reduced_motion restored to %s" % str(original_reduced))
	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [results.size() - failed, failed])
	print("═══════════════════════════════════════════════════════════")
	print("")
	get_tree().quit(1 if failed > 0 else 0)
