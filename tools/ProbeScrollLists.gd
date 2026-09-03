extends Node

## Touch-scroll audit for the three hand-rolled scroll handlers.
##
## WHY THIS EXISTS
##   UnlockablesScreen, CharacterCustomization and RoadmapScreen each implement
##   touch scrolling in their own _input() with the absolute-anchor pattern:
##       on press   -> remember drag_start and scroll_start
##       on drag    -> scroll = scroll_start + (drag_start - current)
##   Two things about that are worth measuring rather than assuming.
##
##   1. ScrollContainer ALREADY scrolls itself on touch drag. Godot gates that path
##      behind DisplayServer.is_touchscreen_available(), and project.godot sets
##      input_devices/pointing/emulate_touch_from_mouse=true, which makes that
##      predicate true. If both systems run, one finger scrolls the list twice as
##      far as it moved.
##   2. None of the three looks at event.index, so a second contact re-anchors or
##      cancels the first one's scroll.
##
## HOW THE EVENTS ARE DELIVERED
##   Through get_viewport().push_input(event, TRUE) - the real dispatch chain, so
##   Node._input() and the control's _gui_input() both run and defect 1 is
##   observable at all. Calling the handler directly would hide it completely.
##   The second argument matters: with in_local_coords=false (the default)
##   push_input treats the position as a WINDOW coordinate and converts it by the
##   inverse viewport transform. The first run of this probe was headless, where
##   the window is 64x64 against a 1920-unit canvas, so every position was
##   multiplied by 30 and landed off-screen - the two rect-guarded handlers never
##   engaged and the probe blamed the game.
##
## Usage (WINDOWED - realistic layout and stretch ratio):
##   godot --path . res://tools/ProbeScrollLists.tscn

var _fails: int = 0

const CASES: Array = [
	{
		"scene": "res://scenes/ui/UnlockablesScreen.tscn",
		"member": "_scroll_container",
		"axis": "scroll_vertical",
		"flag": "_scroll_dragging",
	},
	{
		"scene": "res://scenes/ui/RoadmapScreen.tscn",
		"member": "scroll_container",
		"axis": "scroll_vertical",
		"flag": "is_dragging",
	},
	{
		"scene": "res://scenes/ui/CharacterCustomization.tscn",
		"member": "_accessory_scroll",
		"axis": "scroll_horizontal",
		"flag": "_acc_dragging",
	},
]


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _touch(idx: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	return e


func _drag(idx: int, pos: Vector2, rel: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	return e


func _check(label: String, got: Variant, want: Variant) -> void:
	var ok: bool = str(got) == str(want)
	if not ok:
		_fails += 1
	print("      %s %-54s got=%s expected=%s" % ["PASS" if ok else "FAIL", label, str(got), str(want)])


## in_local_coords = true: the position is already in viewport units.
func _push(e: InputEvent) -> void:
	get_viewport().push_input(e, true)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== TOUCH-SCROLL AUDIT: double-scroll and contact ownership ===")
	if DisplayServer.get_name() == "headless":
		print("  REFUSING: needs a real window - see the delivery note above.")
		get_tree().quit(2)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(8)
	var mui := get_node_or_null("/root/MobileUIManager")
	if mui != null:
		mui.debug_mobile_mode = true
		if mui.has_method("_detect_platform"):
			mui._detect_platform()
	print("  emulate_touch_from_mouse   : %s" % ProjectSettings.get_setting(
		"input_devices/pointing/emulate_touch_from_mouse", false))
	print("  is_touchscreen_available() : %s  <- gates ScrollContainer's own drag path"
		% DisplayServer.is_touchscreen_available())
	print("  canvas %s, window %s" % [str(get_viewport().get_visible_rect().size),
		str(DisplayServer.window_get_size())])
	print("")

	for c in CASES:
		var path: String = c["scene"]
		if not ResourceLoader.exists(path):
			print("  SKIP %s (missing)" % path)
			continue
		print("  -- %s --" % path.get_file().get_basename())
		var inst: Node = (load(path) as PackedScene).instantiate()
		get_tree().root.add_child(inst)
		if mui != null:
			mui.adapt_scene_for_mobile(inst)
		await _frames(45)

		var sc: ScrollContainer = inst.get(c["member"]) as ScrollContainer
		if sc == null:
			print("      FAIL %s is null - list never built" % c["member"])
			_fails += 1
			inst.queue_free()
			await _frames(4)
			continue

		var axis: String = c["axis"]
		var vertical: bool = axis == "scroll_vertical"
		var rect := sc.get_global_rect()
		var span: float = 0.0
		if sc.get_child_count() > 0:
			var content := sc.get_child(0) as Control
			if content != null:
				span = (content.size.y - rect.size.y) if vertical else (content.size.x - rect.size.x)
		print("      list rect %s, scrollable span %.0f px" % [str(rect), span])
		if span <= 20.0:
			print("      SKIP nothing to scroll at this size")
			inst.queue_free()
			await _frames(4)
			continue

		var mid := rect.position + rect.size * 0.5
		# Travel stays INSIDE the span, or the measurement is just the clamp at the
		# end of the list.
		var travel: float = minf(60.0, span * 0.4)
		var axis_v := Vector2(0.0, 1.0) if vertical else Vector2(1.0, 0.0)

		# ── 1. one finger, N px of travel: how far does the list actually move? ──
		sc.set(axis, 0)
		await _frames(2)
		_push(_touch(0, mid, true))
		await _frames(1)
		var engaged: bool = bool(inst.get(c["flag"]))
		var step := 10
		for i in range(step):
			var d := travel / float(step)
			_push(_drag(0, mid - axis_v * d * float(i + 1), -axis_v * d))
			await _frames(1)
		var moved := float(sc.get(axis))
		_push(_touch(0, mid - axis_v * travel, false))
		await _frames(2)
		var ratio := moved / travel
		print("      handler engaged %s; finger moved %.0f px -> %s moved %.0f px (ratio %.2f)"
			% [str(engaged), travel, axis, moved, ratio])
		_check("finger travel and list travel match (no double-scroll)",
			"%.2f" % ratio, "1.00")

		# ── 2. a second contact must not hijack or cancel the first ──
		sc.set(axis, 0)
		await _frames(2)
		_push(_touch(0, mid, true))
		await _frames(1)
		var half := mid - axis_v * (travel * 0.5)
		_push(_drag(0, half, -axis_v * (travel * 0.5)))
		await _frames(1)
		var after_first := float(sc.get(axis))
		# A thumb resting near a corner of the list, moving the few px a resting
		# thumb really moves.
		var thumb: Vector2 = rect.position + Vector2(rect.size.x * 0.1, rect.size.y * 0.9)
		_push(_touch(1, thumb, true))
		await _frames(1)
		# Along the LIST axis. The first run moved the thumb vertically against
		# CharacterCustomization's HORIZONTAL list, so its pass was vacuous.
		_push(_drag(1, thumb + axis_v * 3.0, axis_v * 3.0))
		await _frames(1)
		var after_thumb := float(sc.get(axis))
		print("      after finger 0: %s=%.0f; after the thumb: %.0f"
			% [axis, after_first, after_thumb])
		_check("a resting thumb does not jump the list",
			"%.0f" % absf(after_thumb - after_first), "0")
		_push(_touch(1, thumb, false))
		await _frames(1)
		_check("the thumb lifting leaves finger 0 still dragging",
			bool(inst.get(c["flag"])), true)
		_push(_touch(0, half, false))
		await _frames(2)

		inst.queue_free()
		await _frames(4)

	print("  -- %d failing case(s) --" % _fails)
	print("")
	get_tree().quit(0)
