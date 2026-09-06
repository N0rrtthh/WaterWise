extends Node

## Navigation while SceneTree.paused is true: can the player still get out?
##
## THE DEFECT THIS WAS OPENED FOR
##   Reported from an Android test run as "back buttons should work with pause".
##   Two independent causes, both measured before anything was changed:
##
##   1. A paused tree delivers NO gui input to a Button left on the default
##      PROCESS_MODE_INHERIT. Not a swallowed release - zero presses. Measured with
##      the same synthetic click twice: paused=false -> 1 press, paused=true -> 0.
##      Only three Controls in the whole project set PROCESS_MODE_ALWAYS
##      (ExportDataButton, MultiplayerGameOver, RoundTransition), so every menu Back
##      button was dead for as long as a pause outlived the round that took it.
##
##   2. GameManager.transition_to_scene() DEADLOCKED on a paused tree. It sets its
##      full-screen ColorRect to MOUSE_FILTER_STOP, then awaits a fade tween bound to
##      a pausable autoload. Measured: 2.5s after the call, still_transitioning=true,
##      current_scene unchanged, overlay mouse_filter=0 at alpha=0.00 - a completely
##      invisible, full-screen input eater that is never released. Every tap on the
##      screen went nowhere, and _is_transitioning stayed true so no later navigation
##      could start either. That is the same symptom for every button, not just Back.
##
## WHAT IS ASSERTED
##   1. the transition overlay layer runs while paused, and a transition started on a
##      paused tree completes, changes the scene and releases the input eater
##   2. a pause taken DURING a fade still completes the fade and releases the overlay
##   3. a raw change_scene_to_file() while paused lands on an unpaused screen
##   4. every Back control on every screen under scenes/ui/ is pause-immune, and the
##      ones whose layout puts them on screen are clicked while paused to prove it
##   5. gameplay buttons are still pausable - the fix did not leak into the playfield
##
## Usage:
##   godot --headless --path . res://tools/VerifyPausedNavigation.tscn

const UI_DIR: String = "res://scenes/ui"
const ROUND: String = "res://scenes/minigames/CatchTheRain.tscn"
var _pass: int = 0
var _fail: int = 0
var _skipped: PackedStringArray = []
var _hits: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


## Frames that do NOT lift the pause - the whole point of this harness.
func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _wait_ms(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await get_tree().process_frame


func _gm() -> Node:
	return get_node_or_null("/root/GameManager")


## SceneTree.current_scene is what Back dispatch reads, and it is also what
## change_scene_to_file() frees - so pointing it at the screen under test is what keeps
## this harness alive across a navigation.
func _as_current(n: Node) -> void:
	get_tree().current_scene = n


## The Back control of a screen, found by name or by label rather than by a table of
## node paths: the screens build their Back buttons in six different ways
## (back_button, _back_button, back_btn, $...BackButton, code-created, localized text).
func _find_back(root: Node) -> BaseButton:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is BaseButton:
			var b := n as BaseButton
			var nm := b.name.to_lower()
			var tx := ""
			if b is Button:
				tx = (b as Button).text.to_lower()
			if nm.contains("back") or tx.contains("back") \
					or tx.begins_with("←") or tx.begins_with("⬅") \
					or tx.begins_with("<"):
				return b
		for c in n.get_children():
			stack.append(c)
	return null


func _click(c: Control) -> void:
	var at: Vector2 = c.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	get_viewport().push_input(down, true)
	await _frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = at
	up.global_position = at
	get_viewport().push_input(up, true)
	await _frames(2)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== NAVIGATION WHILE PAUSED ===")
	var gm := _gm()
	if gm == null:
		print("  FAIL: GameManager autoload missing")
		get_tree().quit(1)
		return

	# ---- CASE 1: a transition started on a paused tree ------------------------
	var layer: Variant = gm.get("_transition_layer")
	_check("[1] the transition overlay layer runs while the tree is paused",
		layer != null and is_instance_valid(layer)
			and (layer as Node).process_mode == Node.PROCESS_MODE_ALWAYS,
		"process_mode=%s (needs ALWAYS=%d: this layer owns the input-eating rect)"
			% [str((layer as Node).process_mode) if layer != null else "<none>",
				Node.PROCESS_MODE_ALWAYS])

	var hub: Node = (load("res://scenes/ui/InitialScreen.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(hub)
	await _frames(8)
	_as_current(hub)
	get_tree().paused = true
	gm.transition_to_scene("res://scenes/ui/Settings.tscn", 0.4)
	await _wait_ms(2500)
	var rect: Variant = gm.get("_transition_rect")
	var mf: int = (rect as Control).mouse_filter if rect != null and is_instance_valid(rect) else -1
	var cs: Node = get_tree().current_scene
	_check("[1] the transition completes and the scene actually changes",
		gm.is_scene_transitioning() == false
			and cs != null and cs.scene_file_path == "res://scenes/ui/Settings.tscn",
		"still_transitioning=%s current_scene=%s"
			% [str(gm.is_scene_transitioning()), cs.scene_file_path if cs else "<none>"])
	_check("[1] the full-screen input eater is released",
		mf == Control.MOUSE_FILTER_IGNORE,
		"overlay mouse_filter=%d (IGNORE=%d STOP=%d) - STOP at alpha 0 is invisible"
			% [mf, Control.MOUSE_FILTER_IGNORE, Control.MOUSE_FILTER_STOP])
	_check("[1] a transition lifts the pause it inherited",
		get_tree().paused == false,
		"tree.paused=%s after the transition" % str(get_tree().paused))

	# ---- CASE 2: the pause arrives mid-fade ----------------------------------
	# The case transition_to_scene() cannot clear for itself: the app going to
	# background one frame after Back is pressed. Only the tween pause mode covers it.
	await _frames(20)
	gm.transition_to_scene("res://scenes/ui/InitialScreen.tscn", 0.4)
	await _frames(2)
	get_tree().paused = true
	await _wait_ms(2500)
	var cs2: Node = get_tree().current_scene
	var mf2: int = (rect as Control).mouse_filter if rect != null and is_instance_valid(rect) else -1
	_check("[2] a pause taken during the fade does not strand the transition",
		gm.is_scene_transitioning() == false
			and cs2 != null and cs2.scene_file_path == "res://scenes/ui/InitialScreen.tscn"
			and mf2 == Control.MOUSE_FILTER_IGNORE,
		"still_transitioning=%s current_scene=%s mouse_filter=%d"
			% [str(gm.is_scene_transitioning()), cs2.scene_file_path if cs2 else "<none>", mf2])
	get_tree().paused = false
	await _frames(4)

	# ---- CASE 3: a raw change_scene_to_file() while paused --------------------
	# Six Back handlers navigate this way instead of through transition_to_scene().
	get_tree().paused = true
	get_tree().change_scene_to_file("res://scenes/ui/Settings.tscn")
	await _frames(6)
	var cs3: Node = get_tree().current_scene
	_check("[3] a raw scene change lands on a screen that is not frozen",
		get_tree().paused == false
			and cs3 != null and cs3.scene_file_path == "res://scenes/ui/Settings.tscn",
		"tree.paused=%s current_scene=%s"
			% [str(get_tree().paused), cs3.scene_file_path if cs3 else "<none>"])

	# ---- CASE 4: every Back control on every screen ---------------------------
	# Enumerated from disk, not from a list in this file: a screen added later is
	# covered without anyone remembering to add it here, which is the only way a check
	# like this survives contact with a growing project.
	print("")
	print("  -- Back controls, screen by screen --")
	var dir := DirAccess.open(UI_DIR)
	var names: PackedStringArray = []
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".tscn"):
				names.append(f)
	names.sort()
	_check("[4] the screen list was actually read from disk", names.size() >= 8,
		"%d scenes found under %s" % [names.size(), UI_DIR])

	var checked: int = 0
	var clicked: int = 0
	var no_back: PackedStringArray = []
	for f in names:
		var path: String = "%s/%s" % [UI_DIR, f]
		var ps: PackedScene = load(path) as PackedScene
		if ps == null:
			_skipped.append("%s (would not load)" % f)
			continue
		var inst: Node = ps.instantiate()
		if inst == null:
			_skipped.append("%s (would not instantiate)" % f)
			continue
		get_tree().root.add_child(inst)
		await _frames(8)
		_as_current(inst)
		var b: BaseButton = _find_back(inst)
		if b == null:
			no_back.append(f)
			if is_instance_valid(inst):
				inst.queue_free()
			await _frames(3)
			continue
		checked += 1
		# A popup is hidden until the game reveals it, and a hidden Control receives no
		# mouse input at all - correct engine behaviour, not a defect. MultiplayerGameOver
		# is one: _ready() sets visible = false and show_game_over() is what puts it up
		# (and takes the pause this harness is testing under). Revealed through its own
		# API rather than by forcing `visible`, so the click lands on the state a player
		# actually sees.
		if not b.is_visible_in_tree() and inst.has_method("show_game_over"):
			inst.call("show_game_over", 0, 0, 0, 0)
			await _frames(4)
		# Structural: can_process() is the engine's own answer to "will this control be
		# fed input right now", and it accounts for an ALWAYS ancestor as well as the
		# control's own mode - which is how the in-round pause overlays already work.
		get_tree().paused = true
		var can: bool = b.can_process()
		_check("[4] %s: Back is pause-immune (%s)" % [f, b.name], can,
			"can_process()=%s process_mode=%d while tree.paused=true"
				% [str(can), b.process_mode])
		# End to end: a real click through the viewport, at the button's own rect. Read
		# after the reveal above - a popup laid out while hidden reports a stale rect.
		var r: Rect2 = b.get_global_rect()
		var vis: Rect2 = get_viewport().get_visible_rect()
		if b.is_visible_in_tree() and r.size.x > 1.0 and r.size.y > 1.0 \
				and vis.has_point(r.get_center()):
			_hits = 0
			b.pressed.connect(func() -> void: _hits += 1)
			await _click(b)
			var hits_now: int = _hits
			_check("[4] %s: a click while paused reaches the handler" % f,
				hits_now >= 1,
				"pressed fired %d time(s) at %s" % [hits_now, str(r.get_center())])
			clicked += 1
			# Reaching the handler is not the same as getting out of the screen. Waited
			# out first, because half of these screens navigate through
			# transition_to_scene()'s fade and the other half change the scene outright.
			var g2: int = 0
			while gm.is_scene_transitioning() and g2 < 400:
				g2 += 1
				await _frames(1)
			await _frames(3)
			var moved: bool = not is_instance_valid(inst) \
				or get_tree().current_scene != inst
			_check("[4] %s: and the screen is actually left behind" % f, moved,
				"current_scene=%s (still the screen under test: %s)"
					% [get_tree().current_scene.scene_file_path
						if get_tree().current_scene else "<none>",
						str(not moved)])
		else:
			_skipped.append("%s (visible_in_tree=%s, Back rect %s, viewport %s)"
				% [f, str(b.is_visible_in_tree()), str(r), str(vis.size)])
		get_tree().paused = false
		# The click may have navigated; wait any transition out so the next screen
		# does not collide with _is_transitioning.
		var guard: int = 0
		while gm.is_scene_transitioning() and guard < 400:
			guard += 1
			await _frames(1)
		if is_instance_valid(inst) and inst.is_inside_tree():
			inst.queue_free()
		await _frames(3)
	print("          %d screens had a Back control, %d of them were clicked" % [checked, clicked])
	if not no_back.is_empty():
		print("          no Back control (nothing to check): %s" % ", ".join(no_back))

	# ---- CASE 5: the playfield is still pausable ------------------------------
	# The fix must not leak into gameplay. A pause overlay over a round exists so the
	# round STOPS; if the fix had made every button in the project pause-immune, a tap
	# that landed on the playfield behind the overlay would still score.
	print("")
	print("  -- gameplay is still pausable --")
	var g: Node = (load(ROUND) as PackedScene).instantiate()
	get_tree().root.add_child(g)
	await _frames(20)
	_as_current(g)
	var gameplay: Array[BaseButton] = []
	var immune: Array[BaseButton] = []
	var stack: Array[Node] = [g]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is BaseButton:
			if (n as BaseButton).process_mode == Node.PROCESS_MODE_ALWAYS:
				immune.append(n as BaseButton)
			else:
				gameplay.append(n as BaseButton)
		for c in n.get_children():
			stack.append(c)
	_check("[5] a round's own buttons were NOT made pause-immune",
		gameplay.size() > 0,
		"%d pausable, %d intentionally always-on (pause glyph, pause menu): %s"
			% [gameplay.size(), immune.size(),
				", ".join(immune.map(func(b: BaseButton) -> String: return str(b.name)))])
	_check("[5] the round still owns an always-on way to pause",
		immune.size() > 0,
		"%d always-on control(s) inside the round" % immune.size())
	if is_instance_valid(g):
		g.queue_free()
	await _frames(4)

	# ---- RESULT ---------------------------------------------------------------
	get_tree().paused = false
	print("")
	if not _skipped.is_empty():
		print("  NOT MEASURED (%d):" % _skipped.size())
		for s in _skipped:
			print("    - %s" % s)
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	print("")
	get_tree().quit(1 if _fail > 0 else 0)
