extends Node
## Chaos effects must distract, not disable.
##
## Two of the five Hard chaos effects spawn Controls over the board: mud splatters
## (ColorRect) and the buzzing fly (Label, z_index 10, moved every half second). A
## Control's default mouse_filter is STOP, so both used to swallow every tap that
## landed on them - a roving dead zone on the hardest tier, in exactly the games the
## algorithm had decided needed MORE pressure, not fewer working taps.
## _create_visual_obstruction() had always set MOUSE_FILTER_IGNORE; the other two now
## do too.
##
## Part A drives the REAL effect functions on a REAL minigame instance and diffs the
## child list, so what is measured is whatever those functions actually add - not a
## copy of them written here.
## Part B is the negative control: it clicks a Button through the viewport's GUI
## pipeline, once with a STOP rect on top and once with IGNORE, so "the taps get
## through" is a measurement rather than an assumption about a property name.
##
## Run: Godot_v4.7.2 --headless --path . tools/VerifyChaosInput.tscn

const EFFECTS := ["mud_splatters", "buzzing_fly", "visual_obstruction",
	"screen_shake_heavy", "control_reverse"]

var _pass: int = 0
var _fail: int = 0


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s%s" % [label, "" if detail == "" else "   " + detail])
	else:
		_fail += 1
		print("  FAIL  %s%s" % [label, "" if detail == "" else "   " + detail])


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _child_set(node: Node) -> Array:
	var ids: Array = []
	for c in node.get_children():
		ids.append(c.get_instance_id())
	return ids


## A. Every Control the real chaos functions add must be transparent to input.
func _check_a_real_effects() -> void:
	print("-- A. the nodes the real effects spawn")
	var path := "res://scenes/minigames/TurnOffTap.tscn"
	if not ResourceLoader.exists(path):
		_check("TurnOffTap.tscn exists", false)
		return
	var ad := get_node_or_null("/root/AdaptiveDifficulty")
	if ad:
		# Easy so _ready() queues nothing: the effects below are driven one at a
		# time, and a child that appeared on its own would be attributed to them.
		ad.current_difficulty = "Easy"
	var inst := (load(path) as PackedScene).instantiate()
	get_tree().root.add_child(inst)
	await _frames(8)
	_check("the game parked with no chaos of its own",
		(inst.get("_pending_chaos_effects") as Array).is_empty(),
		"%d queued at Easy" % (inst.get("_pending_chaos_effects") as Array).size())

	for effect in EFFECTS:
		var before: Array = _child_set(inst)
		inst.call("_activate_chaos_effect", effect)
		# Splatters arrive on a 2s repeating Timer, so give it more than one period.
		await _frames(4)
		if effect == "mud_splatters":
			await get_tree().create_timer(2.4).timeout
		var blockers: Array[String] = []
		var added: int = 0
		for c in inst.get_children():
			if c.get_instance_id() in before:
				continue
			added += 1
			if c is Control and (c as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
				blockers.append("%s(%s)" % [c.get_class(), str(c.name)])
		_check("%s adds nothing that eats taps" % effect, blockers.is_empty(),
			"%d node(s) added%s" % [added,
				"" if blockers.is_empty() else ", blocking: " + ", ".join(blockers)])

	# The flag-only effect is inert unless a game reads it, which is worth stating
	# rather than leaving as a silent pass above.
	_check("control_reverse set its flag", inst.get("controls_reversed") == true,
		"controls_reversed=%s (honoured by MicrogameShell's drag mapping)" % str(
			inst.get("controls_reversed")))
	inst.queue_free()
	await _frames(4)


## B. The negative control: does mouse_filter actually decide whether a tap lands?
## Without this, part A is only asserting that a property has a value.
func _check_b_hit_test() -> void:
	print("-- B. the hit test, with a blocker that really blocks")
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(holder)
	# Wait for the first layout pass before reading holder.size, and do NOT assign
	# that size by hand. On a FULL_RECT preset the anchors already span the parent,
	# and set_size() on a Control that is not in the tree yet keeps its offsets: once
	# added, size becomes parent_size + offset, i.e. exactly double. The button then
	# gets centred at (1920,1920) in a 1920x1920 viewport - off the canvas, where it
	# receives nothing and this whole control run silently measures zero taps.
	await _frames(1)

	var hits: Array[int] = [0]
	var button := Button.new()
	button.text = "TARGET"
	button.size = Vector2(400, 200)
	button.position = holder.size * 0.5 - button.size * 0.5
	button.pressed.connect(func() -> void: hits[0] += 1)
	holder.add_child(button)

	var cover := ColorRect.new()
	cover.color = Color(0.3, 0.2, 0.1, 0.7)
	cover.size = button.size
	cover.position = button.position
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(cover)  # added after the button, so it is on top
	cover.visible = false
	await _frames(2)

	var centre: Vector2 = button.position + button.size * 0.5
	var bare: int = await _tap(centre, hits)
	_check("a bare Button takes the tap", bare == 1, "%d press(es)" % bare)

	cover.visible = true
	await _frames(2)
	var stopped: int = await _tap(centre, hits)
	_check("a STOP Control over it swallows the tap", stopped == 0,
		"%d press(es) got through" % stopped)

	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await _frames(2)
	var ignored: int = await _tap(centre, hits)
	_check("the same Control on IGNORE lets the tap through", ignored == 1,
		"%d press(es)" % ignored)

	holder.queue_free()
	await _frames(2)


## One click through the viewport's own GUI pipeline. Returns the presses it caused.
##
## push_input(ev, true) - the `true` matters. Headless runs a 64x64 window holding a
## 1920-wide viewport, so a position in window space is scaled by ~1/30 on its way in:
## a click aimed at the middle of the screen lands thousands of pixels off the canvas
## and hits nothing. Passing the position as viewport-local skips that transform.
## Input.parse_input_event() has no local-coords option and therefore cannot drive GUI
## controls here at all - it is still the right call for games that POLL input state.
func _tap(at: Vector2, hits: Array[int]) -> int:
	hits[0] = 0
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	get_tree().root.push_input(mm, true)
	await _frames(1)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_tree().root.push_input(ev, true)
		await _frames(1)
	await _frames(2)
	return hits[0]


func _ready() -> void:
	print("=== CHAOS INPUT GATE ===")
	await _frames(2)
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.enter_sandbox("Easy")
	await _check_a_real_effects()
	print("")
	await _check_b_hit_test()
	if gm:
		gm.exit_sandbox()
	print("")
	print("  RESULT: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
