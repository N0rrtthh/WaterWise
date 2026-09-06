extends Node

## ═══════════════════════════════════════════════════════════════════
## FIRST-PLAY TUTORIAL HARNESS
## ═══════════════════════════════════════════════════════════════════
## autoload/TutorialManager.gd is 440 lines carrying multi-step bilingual tutorials
## plus a gameplay tip for 8 of the 24 singleplayer games, and a contextual-hint
## table on top of that. Its entire API — should_show_tutorial(),
## create_tutorial_popup(), mark_tutorial_shown(), get_contextual_hint() — had NO
## caller anywhere in the project: the only reference to the file was its own
## autoload line in project.godot. It does not self-wire either (its _ready() only
## reloads persisted state; nothing listens to node_added or scene changes). So every
## first-time player got game_instruction_text, one line, and none of the authored
## teaching content was reachable. For an educational thesis game that is a gap
## between what the build does and what the project claims to teach.
##
## MiniGameBase._show_first_play_tutorial() is now that caller, wired as a REPLACEMENT
## for the one-line instruction overlay on first play rather than as an extra gate, so
## the player still has exactly one thing to dismiss.
##
## What is measured here, each with a control beside it:
##   * the popup appears on first play of a game that HAS authored content, carrying
##     that content's real title;
##   * the one-line overlay is suppressed while it is up, so the two do not stack;
##   * the round still starts and the popup is gone afterwards — the failure mode of
##     a full-screen modal is a soft lock, so this is the check that matters most;
##   * a SECOND visit to the same game shows the plain overlay instead;
##   * a game with no authored entry (16 of the 24) is completely unaffected;
##   * the language actually switches the content, which is the point of authoring
##     both halves.
##
## Player state is snapshotted and restored: mark_tutorial_shown() writes through to
## SaveManager, so a harness that did not restore would consume the real player's
## first-play tutorials.
##
## Usage:
##   godot --headless --path . res://tools/VerifyFirstPlayTutorial.tscn

## Has authored tutorial content.
const TUTORIAL_GAME: String = "res://scenes/minigames/CatchTheRain.tscn"
## Has none — 16 of the 24 games are in this position and must be untouched.
const PLAIN_GAME: String = "res://scenes/minigames/ThirstyPlant.tscn"
## _wait_for_input() returns after 0.8s when autoplay drives the round.
const AUTOPLAY_GATE: float = 0.8
## The shapes the popup is measured at. 2400x1080 is the reported test phone
## (M2007J20CG); the portrait entry catches a sensor rotation mid-round.
const GEOM_SHAPES: Array = [Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1080, 2400)]
## Container centring is integer-exact in practice; this only absorbs an odd-pixel split.
const CENTRE_TOL_PX: float = 1.5

var results: Array = []
var _detached: bool = false

var _orig_shown: Array = []
var _orig_autoplay: bool = false
var _orig_lang: int = 0


func _ready() -> void:
	if not _detached:
		# This harness drives change_scene_to_file(), which memdeletes the outgoing
		# current_scene — for a tool-scene launch that is this node. The timeline runs
		# on a twin parented to /root instead.
		var twin: Node = (get_script() as GDScript).new()
		twin.set("_detached", true)
		twin.name = "FirstPlayTutorialProbe"
		get_tree().root.add_child.call_deferred(twin)
		return
	await _run()


func _check(label: String, ok: bool, detail: String = "") -> void:
	results.append({"ok": ok, "label": label})
	var mark := "✓" if ok else "✗"
	if detail == "":
		print("  %s %s" % [mark, label])
	else:
		print("  %s %s  — %s" % [mark, label, detail])


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _current() -> Node:
	var t := _tree()
	return t.current_scene if t else null


## The popup TutorialManager builds is named "TutorialOverlay" and is parented to the
## minigame's hud_layer, so it is found by name rather than by guessing at a path.
func _find_popup() -> Node:
	var cs := _current()
	if cs == null:
		return null
	return cs.find_child("TutorialOverlay", true, false)


## The authored title is rendered into the first Label of the popup, prefixed with an
## emoji by TutorialManager. Reading it back proves the popup carries THIS game's
## content and not an empty shell.
func _popup_title() -> String:
	var popup := _find_popup()
	if popup == null:
		return ""
	for label in _all_labels(popup):
		return label.text
	return ""


## The panel is a grandchild now (overlay/TutorialCentre/PanelContainer), so it is found
## by type rather than by path: the point of these checks is that SOMETHING centres it,
## not that a particular node does.
func _find_panel(node: Node) -> PanelContainer:
	if node is PanelContainer:
		return node
	for child in node.get_children():
		var hit: PanelContainer = _find_panel(child)
		if hit != null:
			return hit
	return null


## Where the panel really lands on screen: its own rect pushed through the full canvas
## transform, so a CanvasLayer offset or a scaled hud_layer is included rather than
## assumed away. Control.get_rect() alone would have reported the pre-fix bug as fine on
## any parent that happened to be offset.
func _panel_screen_rect(panel: Control) -> Rect2:
	return panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, panel.size)


func _find_button(node: Node) -> Button:
	if node is Button:
		return node
	for child in node.get_children():
		var hit: Button = _find_button(child)
		if hit != null:
			return hit
	return null


func _all_labels(node: Node) -> Array:
	var out: Array = []
	if node is Label:
		out.append(node)
	for child in node.get_children():
		out.append_array(_all_labels(child))
	return out


func _instruction_visible() -> bool:
	var cs := _current()
	if cs == null:
		return false
	var overlay = cs.get("instruction_overlay")
	return overlay != null and is_instance_valid(overlay) and bool(overlay.visible)


func _load(path: String) -> void:
	_tree().change_scene_to_file(path)
	await _tree().process_frame
	await _tree().process_frame
	await _tree().process_frame


func _wait(seconds: float) -> void:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < seconds:
		await _tree().process_frame


func _run() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  FIRST-PLAY TUTORIAL HARNESS")
	print("═══════════════════════════════════════════════════════════")
	_orig_shown = TutorialManager.shown_tutorials.duplicate()
	_orig_autoplay = bool(AutoPlayManager.auto_play_enabled)
	_orig_lang = int(Localization.current_language)
	# Set directly: set_auto_play_enabled() writes the flag through to the player's
	# settings file.
	AutoPlayManager.auto_play_enabled = true
	TutorialManager.shown_tutorials.clear()

	await _first_play()
	await _second_play()
	await _plain_game()
	await _language()
	await _geometry()
	await _animation()
	await _button_reachable()

	# Restore every piece of player state this harness touched, including the
	# persisted copy that mark_tutorial_shown() wrote.
	Localization.current_language = _orig_lang
	TutorialManager.shown_tutorials = []
	for g in _orig_shown:
		TutorialManager.shown_tutorials.append(str(g))
	TutorialManager._save_shown_tutorials()
	AutoPlayManager.auto_play_enabled = _orig_autoplay
	print("")
	print("  restored: shown_tutorials=%s autoplay=%s language=%d"
		% [str(TutorialManager.shown_tutorials), str(_orig_autoplay), _orig_lang])

	var failed := 0
	for r in results:
		if not r["ok"]:
			failed += 1
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [results.size() - failed, failed])
	if failed > 0:
		for r in results:
			if not r["ok"]:
				print("    ✗ %s" % r["label"])
	print("═══════════════════════════════════════════════════════════")
	print("")
	_tree().quit(1 if failed > 0 else 0)


# ── first play of a game with authored content ───────────────────────

func _first_play() -> void:
	Localization.current_language = Localization.Language.ENGLISH
	var key := TUTORIAL_GAME.get_file().get_basename()
	_check("control: TutorialManager has authored content for %s" % key,
		not TutorialManager.get_tutorial(key).is_empty(),
		"tutorial keys present = %s" % str(TutorialManager.tutorials.has(key)))
	_check("control: it has not been marked shown yet",
		TutorialManager.should_show_tutorial(key),
		"should_show_tutorial = %s" % str(TutorialManager.should_show_tutorial(key)))

	await _load(TUTORIAL_GAME)
	var popup := _find_popup()
	_check("first play of %s brings up the authored tutorial" % key,
		popup != null,
		"TutorialOverlay under the minigame = %s" % ("found" if popup else "ABSENT"))
	var title := _popup_title()
	_check("the popup carries this game's authored English title",
		title.contains("Catch The Rain"),
		"first label = \"%s\"" % title)
	_check("the one-line instruction overlay is suppressed while it is up (one gate,"
			+ " not two)",
		not _instruction_visible(),
		"instruction_overlay.visible = %s" % str(_instruction_visible()))
	_check("the popup swallows taps meant for the game underneath",
		popup != null and int(popup.get("mouse_filter")) == Control.MOUSE_FILTER_STOP,
		"mouse_filter = %s" % (str(popup.get("mouse_filter")) if popup else "<none>"))

	# The soft-lock check. A full-screen modal that outlives the wait would leave the
	# player looking at a game they cannot reach.
	await _wait(AUTOPLAY_GATE + 1.2)
	var cs := _current()
	_check("the round still starts with the tutorial in the flow (no soft lock)",
		cs != null and bool(cs.get("game_active")),
		"game_active = %s" % (str(cs.get("game_active")) if cs else "<no scene>"))
	_check("the popup is gone once the round starts",
		_find_popup() == null,
		"TutorialOverlay = %s" % ("STILL PRESENT" if _find_popup() else "freed"))
	_check("showing it marked it shown, so it cannot reappear every visit",
		not TutorialManager.should_show_tutorial(key),
		"should_show_tutorial = %s" % str(TutorialManager.should_show_tutorial(key)))


# ── second visit to the same game ────────────────────────────────────

func _second_play() -> void:
	await _load(TUTORIAL_GAME)
	_check("a second visit shows no tutorial popup",
		_find_popup() == null,
		"TutorialOverlay = %s" % ("PRESENT" if _find_popup() else "absent"))
	_check("a second visit falls back to the one-line instruction overlay",
		_instruction_visible(),
		"instruction_overlay.visible = %s" % str(_instruction_visible()))
	await _wait(AUTOPLAY_GATE + 1.2)
	var cs := _current()
	_check("the second visit starts normally",
		cs != null and bool(cs.get("game_active")),
		"game_active = %s" % (str(cs.get("game_active")) if cs else "<no scene>"))


# ── a game with no authored entry ────────────────────────────────────

func _plain_game() -> void:
	var key := PLAIN_GAME.get_file().get_basename()
	_check("control: %s has no authored tutorial (16 of the 24 do not)" % key,
		TutorialManager.get_tutorial(key).is_empty(),
		"entry present = %s" % str(TutorialManager.tutorials.has(key)))
	await _load(PLAIN_GAME)
	_check("a game with no authored tutorial shows no popup",
		_find_popup() == null,
		"TutorialOverlay = %s" % ("PRESENT" if _find_popup() else "absent"))
	_check("it still shows its one-line instruction overlay, unchanged",
		_instruction_visible(),
		"instruction_overlay.visible = %s" % str(_instruction_visible()))
	await _wait(AUTOPLAY_GATE + 1.2)
	var cs := _current()
	_check("it starts normally",
		cs != null and bool(cs.get("game_active")),
		"game_active = %s" % (str(cs.get("game_active")) if cs else "<no scene>"))


# ── the other authored language ──────────────────────────────────────

func _language() -> void:
	var key := TUTORIAL_GAME.get_file().get_basename()
	TutorialManager.shown_tutorials.erase(key)
	Localization.current_language = Localization.Language.FILIPINO
	_check("control: Filipino is selected",
		not Localization.is_english(),
		"is_english = %s" % str(Localization.is_english()))
	await _load(TUTORIAL_GAME)
	var title := _popup_title()
	_check("the popup switches to the authored Filipino title",
		title.contains("Saluhin ang Ulan"),
		"first label = \"%s\"" % title)


# ── where the popup lands on screen ──────────────────────────────────

## The reported defect: "the tutorial screen is on the far right corner of the screen".
## create_tutorial_popup() presets the panel to PRESET_CENTER before the panel is in the
## tree, so the offsets it derives from the (empty) current rect stay 0, and anchors of
## 0.5 with zero offsets pin the panel TOP-LEFT to the viewport centre. Measured before
## the fix, at the three shapes below: the panel sat at (960,540), (1200,540) and
## (960,2133), each off centre by exactly half its own size, (300,235).
##
## Nothing in this harness looked at geometry before, which is how a popup that was
## half off screen on every device passed all 21 checks. Autoplay is turned off for the
## duration so the popup is not dismissed while it is being measured.
func _geometry() -> void:
	var key := TUTORIAL_GAME.get_file().get_basename()
	var win: Window = _tree().root
	var orig_size: Vector2i = win.size
	var was_autoplay: bool = bool(AutoPlayManager.auto_play_enabled)
	AutoPlayManager.auto_play_enabled = false
	Localization.current_language = Localization.Language.ENGLISH

	for shape in GEOM_SHAPES:
		win.size = shape
		await _wait(0.2)
		TutorialManager.shown_tutorials.erase(key)
		await _load(TUTORIAL_GAME)
		# Past the 0.3s entrance tween: it animates panel.scale, and a rect sampled
		# mid-flight is smaller than the settled one for reasons that are not a layout bug.
		await _wait(0.7)
		await _assert_geometry("%dx%d" % [shape.x, shape.y])

	# The other authored language is longer in almost every string; a panel that only fits
	# in English is not fixed.
	Localization.current_language = Localization.Language.FILIPINO
	win.size = Vector2i(2400, 1080)
	await _wait(0.2)
	TutorialManager.shown_tutorials.erase(key)
	await _load(TUTORIAL_GAME)
	await _wait(0.7)
	await _assert_geometry("2400x1080 Filipino")

	Localization.current_language = Localization.Language.ENGLISH
	win.size = orig_size
	AutoPlayManager.auto_play_enabled = was_autoplay
	# With autoplay off nothing dismissed the last popup, and it is full-screen and
	# MOUSE_FILTER_STOP. Left up, it eats the tap _button_reachable() aims at its own
	# popup - measured: the leftover START button sits within ~20px of the same place,
	# because both are centred by the same container, so the tap dismissed the wrong
	# overlay and the check failed while its sibling "marked shown" check passed.
	var leftover := _find_popup()
	if leftover != null:
		leftover.queue_free()
	await _wait(0.2)


func _assert_geometry(tag: String) -> void:
	var popup := _find_popup()
	if popup == null:
		_check("[%s] control: the tutorial popup is up to be measured" % tag, false,
			"TutorialOverlay ABSENT — the checks below cannot run")
		return
	var panel: PanelContainer = _find_panel(popup)
	if panel == null:
		_check("[%s] control: the popup has a panel to measure" % tag, false,
			"no PanelContainer under TutorialOverlay")
		return
	var vis: Rect2 = (popup as Control).get_viewport().get_visible_rect()
	var rect: Rect2 = _panel_screen_rect(panel)
	var off: Vector2 = rect.get_center() - vis.get_center()
	_check("[%s] the tutorial panel is centred on the viewport, not hung off its centre"
			% tag,
		absf(off.x) <= CENTRE_TOL_PX and absf(off.y) <= CENTRE_TOL_PX,
		"panel centre=%s viewport centre=%s off by %s" % [
			str(rect.get_center()), str(vis.get_center()), str(off)])
	_check("[%s] the whole panel is inside the visible screen" % tag,
		vis.encloses(rect),
		"panel=%s visible=%s" % [str(rect), str(vis)])
	var mins: Vector2 = panel.get_combined_minimum_size()
	_check("[%s] the panel is not squeezed below the size its content needs" % tag,
		panel.size.x >= mins.x - 0.5 and panel.size.y >= mins.y - 0.5,
		"size=%s combined_min=%s" % [str(panel.size), str(mins)])


# ── the entrance animation ───────────────────────────────────────────

## Guards the OTHER half of the centring fix. The panel now lives in a CenterContainer,
## and a Container sort pass resets a child's scale to (1,1) as well as writing its rect.
## The first sort is queued when the panel is added and runs before the entrance tweener
## takes its first step, so a tweener that reads its start value off the property found
## (1,1) there and animated 1 -> 1: the popup faded in but never scaled. Measured that
## way once (scale read 1.000 on 14 consecutive samples at all three shapes while alpha
## climbed normally), which is why tween_property(...).from(Vector2(0.8, 0.8)) is pinned.
##
## The popup is built directly here, on a CanvasLayer this harness owns, rather than
## through a scene load: a 0.3s animation cannot be sampled reliably while a round is
## also starting, and create_tutorial_popup() is the product function either way. Nothing
## presses the start button, so no first-play state is consumed.
##
## The clock is slowed to 0.1x because 0.3s of animation against headless frame times is
## a handful of samples; at 0.1x it is dozens, so "it animated" is measured rather than
## inferred from one lucky read.
func _animation() -> void:
	var orig_scale: float = Engine.time_scale
	Engine.time_scale = 0.1
	var layer := CanvasLayer.new()
	layer.name = "TutorialAnimProbe"
	add_child(layer)
	var popup: Control = TutorialManager.create_tutorial_popup("CatchTheRain", layer)
	if popup == null:
		_check("control: a popup was built to measure the entrance animation", false,
			"create_tutorial_popup returned null")
		Engine.time_scale = orig_scale
		layer.queue_free()
		return
	var panel: PanelContainer = _find_panel(popup)
	_check("control: the built popup starts scaled down and transparent",
		panel != null and panel.scale.x < 0.99 and popup.modulate.a < 0.01,
		"scale=%s alpha=%.3f" % [
			str(panel.scale) if panel != null else "<no panel>", popup.modulate.a])

	var min_scale: float = 9.0
	var max_scale: float = -9.0
	var mid_alpha: bool = false
	var samples: int = 0
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4200:
		await _tree().process_frame
		if not is_instance_valid(popup) or panel == null:
			break
		samples += 1
		min_scale = minf(min_scale, panel.scale.x)
		max_scale = maxf(max_scale, panel.scale.x)
		if popup.modulate.a > 0.01 and popup.modulate.a < 0.99:
			mid_alpha = true
	_check("the panel really scales in — the container sort has not eaten the tween",
		samples > 0 and min_scale < 0.999 and min_scale > 0.5,
		"min scale=%.4f max=%.4f over %d samples (1.0 throughout = tween overwritten)"
			% [min_scale, max_scale, samples])
	_check("it settles at full size, leaving no residue from the animation",
		panel != null and absf(panel.scale.x - 1.0) < 0.001
			and absf(panel.scale.y - 1.0) < 0.001,
		"final scale=%s" % (str(panel.scale) if panel != null else "<no panel>"))
	_check("the fade runs alongside it and completes",
		mid_alpha and is_instance_valid(popup) and popup.modulate.a > 0.99,
		"saw mid-fade=%s final alpha=%.3f" % [str(mid_alpha),
			popup.modulate.a if is_instance_valid(popup) else -1.0])
	_check("the scale pivot is the panel middle, so it grows from the centre outwards",
		panel != null and panel.size.x > 0.0
			and absf(panel.pivot_offset.x - panel.size.x * 0.5) <= 0.5
			and absf(panel.pivot_offset.y - panel.size.y * 0.5) <= 0.5,
		"pivot=%s size=%s" % [
			str(panel.pivot_offset) if panel != null else "-",
			str(panel.size) if panel != null else "-"])

	Engine.time_scale = orig_scale
	layer.queue_free()
	await _wait(0.2)


# ── the one tap that dismisses it ────────────────────────────────────

## The centring fix inserted a CenterContainer between the overlay and the panel, and a
## Container defaults to MOUSE_FILTER_STOP across its whole rect. That node now sits in
## the hit-test stack above the game and below the START button, so "the button still
## works" is a claim about changed code, not a given: if the container swallowed the tap
## the popup would be a soft lock with no way out on a touch device.
##
## Driven with Viewport.push_input(), because Input.parse_input_event() does not reach
## Controls in a headless run.
func _button_reachable() -> void:
	var key := "CatchTheRain"
	# A game with no authored tutorial, so the scene underneath contributes no overlay of
	# its own to compete for the tap.
	await _load(PLAIN_GAME)
	var stray := _find_popup()
	if stray != null:
		stray.queue_free()
		await _wait(0.2)
	TutorialManager.shown_tutorials.erase(key)
	var layer := CanvasLayer.new()
	layer.name = "TutorialClickProbe"
	# Above anything the round draws, so the tap cannot be intercepted.
	layer.layer = 100
	add_child(layer)
	var popup: Control = TutorialManager.create_tutorial_popup(key, layer)
	if popup == null:
		_check("control: a popup was built to tap", false, "create_tutorial_popup null")
		layer.queue_free()
		return
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	await _wait(0.6)
	var btn: Button = _find_button(popup)
	if btn == null:
		_check("control: the popup has a START button", false, "no Button under it")
		layer.queue_free()
		return
	var vis: Rect2 = (popup as Control).get_viewport().get_visible_rect()
	var brect: Rect2 = btn.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, btn.size)
	_check("control: the START button is on screen to be tapped",
		vis.encloses(brect) and brect.size.x > 1.0,
		"button=%s text=\"%s\" visible=%s" % [str(brect), btn.text, str(vis)])
	_check("control: the tutorial is unshown before the tap",
		TutorialManager.should_show_tutorial(key),
		"should_show_tutorial=%s" % str(TutorialManager.should_show_tutorial(key)))

	var at: Vector2 = brect.get_center()
	var vp: Viewport = (popup as Control).get_viewport()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	vp.push_input(down, true)
	await _tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	up.global_position = at
	vp.push_input(up, true)
	await _wait(0.3)

	var gone: bool = not is_instance_valid(popup) or popup.is_queued_for_deletion()
	_check("tapping START at the centred position dismisses the tutorial",
		gone,
		"tapped %s — popup %s" % [str(at), "freed" if gone else "STILL UP"])
	_check("the tap also marked it shown, so it does not return next round",
		not TutorialManager.should_show_tutorial(key),
		"should_show_tutorial=%s" % str(TutorialManager.should_show_tutorial(key)))
	layer.queue_free()
	await _wait(0.2)
