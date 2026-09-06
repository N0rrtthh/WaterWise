extends Node

## Does the on-screen keyboard still cover the field the player is typing into?
##
## THE DEFECT
##   Reported as "the on-screen keyboard fully covers the Enter Host IP Address input,
##   and there is no way to scroll it into view". MobileUIManager already had the whole
##   avoidance mechanism - keyboard_height, _apply_keyboard_inset(), a
##   keyboard_visibility_changed signal - and it was never reached. Detection lived only
##   inside _on_viewport_size_changed(), which infers "keyboard" from a height-only
##   viewport shrink. This game runs fullscreen/immersive, and Android does not resize a
##   fullscreen window for the soft keyboard: it draws the keyboard over it. So
##   size_changed never fired, keyboard_height stayed 0 for the life of the process, and
##   the inset was dead code. DisplayServer.virtual_keyboard_get_height() asks the Android
##   side directly and is right whether or not the window resized.
##
## WHAT IS MEASURED HERE
##   1. that a keyboard-sized inset actually lifts the IP field clear of the keyboard, at
##      both device shapes - the input AND the CONNECT button under it, since typing an
##      address you cannot then submit is the same bug.
##   2. that nothing is pushed off the TOP in the process. Shrinking the container is only
##      a fix while the content still fits above the keyboard.
##   3. that the layout returns exactly to where it was when the keyboard closes.
##   4. that the inset ADDS to the scene's existing bottom offset instead of replacing it.
##      The safe-area pass writes that same property absolutely - adapt_scene_for_mobile
##      carries a comment about a previous two-writers-one-property bug that cost 185 units
##      of Settings' reserved bar - so this is the trap next door, checked rather than
##      hoped about.
##   5. the screen-px -> viewport-unit conversion, at a shape where they are NOT 1:1. Both
##      test phones are 1080 tall, so an unconverted height measures perfect on both and is
##      50% short on a 720p handset. This is the one part of the fix the two named devices
##      could never have caught.
##   6. that the poll is inert with no text field focused, so gameplay frames do not pay
##      for it.
##   7. that one height change emits exactly one signal, and a repeat of the same height
##      emits none.
##
## NOT MEASURED HERE (needs the physical device)
##   That DisplayServer.virtual_keyboard_get_height() returns non-zero on the Moto E5 Plus
##   when the keyboard is up. Headless has no keyboard to raise, so this harness drives
##   MobileUIManager.apply_keyboard_height() - the same entry point the poll calls - and
##   checks everything downstream of it. The on-device row is the log line
##   "Keyboard shown, height: N px" appearing at all.
##
## Usage:
##   godot --headless --path . res://tools/VerifyKeyboardInset.tscn

const LOBBY: String = "res://scenes/ui/MultiplayerLobby.tscn"

## The two reported devices. Moto E5 Plus first: it is the one that fails everything else.
const SHAPES: Array = [Vector2i(2160, 1080), Vector2i(2400, 1080)]

## A landscape Android keyboard covers roughly 40-50% of the screen. 45% is used as the
## realistic case rather than a token 100 px that any layout survives.
const KB_FRACTION: float = 0.45

var _pass: int = 0
var _fail: int = 0
var _signal_log: Array[int] = []

var _mui_node: Node = null
var _lobby: Node = null
var _root_ctrl: Control = null
var _ip_input: LineEdit = null
var _ip_label: Label = null
var _connect_btn: Button = null


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		print("  PASS  %s" % label)
	else:
		_fail += 1
		print("  FAIL  %s" % label)
	if detail != "":
		print("          %s" % detail)


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


## Become a device of the given shape. Four frames: the window write, the stretch
## recompute, the resize listeners, and whatever they deferred.
func _resize(size: Vector2i) -> void:
	get_window().size = size
	await _frames(4)
	# The resize runs MobileUIManager._detect_platform(), which re-derives set_process().
	# This harness is the only writer of keyboard_height, so the manager's own 10 Hz poll -
	# which would read a headless DisplayServer's 0 and quietly undo every staged height -
	# is switched back off. Inert on desktop anyway (is_mobile is false above 800 units
	# wide); explicit so the run does not depend on that staying true.
	var mui := _mui()
	if mui:
		mui.set_process(false)


func _mui() -> Node:
	return get_node_or_null("/root/MobileUIManager")


func _vp_height() -> float:
	return get_viewport().get_visible_rect().size.y


## Where a Control actually lands on the glass, whatever it is parented to.
func _screen_rect(c: Control) -> Rect2:
	return Rect2(c.get_global_transform_with_canvas().origin, c.size)


func _on_kb_signal(height: int) -> void:
	_signal_log.append(height)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== Keyboard inset over the host-IP field ===")

	_mui_node = _mui()
	if _mui_node == null:
		print("  FAIL  MobileUIManager autoload missing")
		get_tree().quit(1)
		return
	_mui_node.set_process(false)
	_mui_node.keyboard_visibility_changed.connect(_on_kb_signal)

	_lobby = load(LOBBY).instantiate()
	get_tree().root.add_child(_lobby)
	# The inset resolves its target through get_tree().current_scene, so the slot has to be
	# handed over. change_scene_to_file() is not an option: this harness IS current_scene
	# and would be freed mid-run.
	get_tree().current_scene = _lobby
	await _frames(4)

	_root_ctrl = _lobby as Control
	_ip_input = _lobby.get_node_or_null(
		"MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/IPInput"
	) as LineEdit
	_ip_label = _lobby.get_node_or_null(
		"MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/Label"
	) as Label
	_connect_btn = _lobby.get_node_or_null(
		"MarginContainer/VBoxContainer/JoinPanel/VBoxContainer/HBoxContainer/ConnectButton"
	) as Button
	_check(
		"the join screen still has the reported field, its label and CONNECT",
		_ip_input != null and _ip_label != null and _connect_btn != null,
		"IPInput=%s Label=%s ConnectButton=%s"
			% [_ip_input != null, _ip_label != null, _connect_btn != null]
	)
	if _ip_input == null or _ip_label == null or _connect_btn == null:
		print("")
		print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
		get_tree().quit(1)
		return

	# Which branch of _apply_keyboard_inset() is under test. _find_root_control() returns
	# the scene itself when the scene root is a Control, and the two branches write
	# different properties (offset_bottom vs a margin_bottom override), so a scene edit
	# that wrapped this screen in a MarginContainer would move the fix to code this run
	# never touched.
	_check(
		"the inset target is the scene root Control (offset_bottom branch)",
		not (_root_ctrl is MarginContainer),
		"root is %s" % _root_ctrl.get_class()
	)

	for shape in SHAPES:
		await _geometry_at(shape)

	await _composition_check()
	await _signal_check()
	await _conversion_check()
	_poll_gate_check()

	_mui_node.apply_keyboard_height(0)
	await _frames(2)

	print("")
	print("  -- on-device row, not measurable headless --")
	print("     DisplayServer.virtual_keyboard_get_height() must return non-zero on the")
	print("     Moto E5 Plus while the keyboard is up; the evidence is the log line")
	print("     \"Keyboard shown, height: N px\" appearing at all. Headless has no keyboard")
	print("     to raise, so everything above drives apply_keyboard_height() - the same")
	print("     entry point the poll calls - and checks what happens downstream of it.")
	print("")
	print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## The reported bug, measured at one device shape: does a realistic keyboard cover the
## field, and does the inset lift the field AND the button under it clear of the keyboard
## without pushing the label off the top?
func _geometry_at(shape: Vector2i) -> void:
	await _resize(shape)
	_mui_node.apply_keyboard_height(0)
	_lobby.call("_show_join_panel")
	await _frames(4)

	var vp := get_viewport().get_visible_rect().size
	var vp_h: float = vp.y
	var kb: int = int(round(vp_h * KB_FRACTION))
	var kb_top: float = vp_h - float(kb)
	print("")
	print("  -- %dx%d window; viewport %.0fx%.0f units; keyboard %d units, top edge y=%.0f --"
		% [shape.x, shape.y, vp.x, vp_h, kb, kb_top])

	var before_input := _screen_rect(_ip_input)
	var before_connect := _screen_rect(_connect_btn)
	var before_offset: float = _root_ctrl.offset_bottom

	# Validity, not regression. If the field already sat above a 45% keyboard with no inset
	# at all, every check below would pass without the fix doing anything. This row is what
	# says the harness is looking at the situation that was reported.
	_check(
		"without the inset the field really is under the keyboard (guards a vacuous pass)",
		before_input.end.y > kb_top,
		"IPInput bottom y=%.0f vs keyboard top y=%.0f" % [before_input.end.y, kb_top]
	)
	_check(
		"without the inset CONNECT is under the keyboard too",
		before_connect.end.y > kb_top,
		"CONNECT bottom y=%.0f vs keyboard top y=%.0f" % [before_connect.end.y, kb_top]
	)

	_mui_node.apply_keyboard_height(kb)
	await _frames(4)

	var after_input := _screen_rect(_ip_input)
	var after_connect := _screen_rect(_connect_btn)
	var after_label := _screen_rect(_ip_label)

	_check(
		"the IP field clears the keyboard",
		after_input.end.y <= kb_top,
		"IPInput y=%.0f..%.0f vs keyboard top y=%.0f (%.0f units of clearance)"
			% [after_input.position.y, after_input.end.y, kb_top, kb_top - after_input.end.y]
	)
	# Typing an address you then cannot submit is the same bug, so the button counts.
	_check(
		"the CONNECT button clears the keyboard as well",
		after_connect.end.y <= kb_top,
		"CONNECT y=%.0f..%.0f vs keyboard top y=%.0f (%.0f units of clearance)"
			% [after_connect.position.y, after_connect.end.y, kb_top,
				kb_top - after_connect.end.y]
	)
	_check(
		"the field actually moved rather than being left where it was",
		after_input.end.y < before_input.end.y - 1.0,
		"IPInput bottom %.0f -> %.0f (moved %.0f units up)"
			% [before_input.end.y, after_input.end.y, before_input.end.y - after_input.end.y]
	)
	# Shrinking the container is only a fix while the content still fits above the keyboard.
	# There is no ScrollContainer on this screen, so anything pushed off the top is gone.
	_check(
		"nothing was pushed off the top of the screen",
		after_label.position.y >= 0.0,
		"\"Enter Host IP Address\" label top y=%.0f" % after_label.position.y
	)
	_check(
		"the field is still fully on screen horizontally and vertically",
		after_input.position.y >= 0.0 and after_input.position.x >= 0.0
			and after_input.end.x <= vp.x,
		"IPInput rect %.0f,%.0f %.0fx%.0f in a %.0fx%.0f viewport"
			% [after_input.position.x, after_input.position.y, after_input.size.x,
				after_input.size.y, vp.x, vp_h]
	)

	_mui_node.apply_keyboard_height(0)
	await _frames(4)
	var restored := _screen_rect(_ip_input)
	_check(
		"closing the keyboard puts the layout back exactly where it was",
		absf(restored.position.y - before_input.position.y) <= 0.5
			and absf(restored.end.y - before_input.end.y) <= 0.5,
		"IPInput y=%.1f..%.1f before, %.1f..%.1f after"
			% [before_input.position.y, before_input.end.y, restored.position.y, restored.end.y]
	)
	_check(
		"closing the keyboard hands the root's own bottom offset back untouched",
		is_equal_approx(_root_ctrl.offset_bottom, before_offset),
		"offset_bottom %.1f before, %.1f after" % [before_offset, _root_ctrl.offset_bottom]
	)


## The trap next door. LayoutManagerUtil.apply_safe_area_margins() writes offset_bottom
## ABSOLUTELY, and adapt_scene_for_mobile carries a comment about the last time two systems
## wrote one property: Settings lost 185 units of its reserved bottom bar and left touchable
## checkbox slivers under a fixed Back button. So the inset has to compose with whatever
## bottom offset the scene already owns and hand it back untouched, rather than restore a
## hardcoded 0.
func _composition_check() -> void:
	var base: float = -120.0  # a plausible safe-area reserve, written the way the real pass writes it
	var kb: int = 300
	_mui_node.apply_keyboard_height(0)
	await _frames(2)
	var original: float = _root_ctrl.offset_bottom
	_root_ctrl.offset_bottom = base
	await _frames(2)

	_mui_node.apply_keyboard_height(kb)
	await _frames(2)
	_check(
		"the inset ADDS to the scene's existing bottom offset instead of replacing it",
		is_equal_approx(_root_ctrl.offset_bottom, base - float(kb)),
		"offset_bottom %.1f; expected %.1f (base %.1f minus keyboard %d)"
			% [_root_ctrl.offset_bottom, base - float(kb), base, kb]
	)
	# A 10 Hz poll re-reports the same height over and over. If the base were re-captured
	# each time, the inset would compound and walk the layout off the top of the screen.
	_mui_node.apply_keyboard_height(kb)
	_mui_node.apply_keyboard_height(kb)
	await _frames(2)
	_check(
		"re-reporting the same height does not compound the inset",
		is_equal_approx(_root_ctrl.offset_bottom, base - float(kb)),
		"offset_bottom %.1f after three applies of %d; expected %.1f"
			% [_root_ctrl.offset_bottom, kb, base - float(kb)]
	)

	_mui_node.apply_keyboard_height(0)
	await _frames(2)
	_check(
		"closing the keyboard gives the safe-area reserve back, not a bare 0",
		is_equal_approx(_root_ctrl.offset_bottom, base),
		"offset_bottom %.1f; expected %.1f" % [_root_ctrl.offset_bottom, base]
	)
	# Released on the way out so a safe-area recalculation between two keyboards (a rotation
	# with the keyboard open) is picked up instead of being overwritten by a stale number.
	_check(
		"the cached base is released when the keyboard closes",
		not _root_ctrl.has_meta(_mui_node.KEYBOARD_INSET_BASE_META),
		"meta %s present: %s"
			% [_mui_node.KEYBOARD_INSET_BASE_META,
				_root_ctrl.has_meta(_mui_node.KEYBOARD_INSET_BASE_META)]
	)
	_root_ctrl.offset_bottom = original
	await _frames(2)


## keyboard_visibility_changed is what any screen would listen to in order to re-layout or
## scroll itself. One height change must produce exactly one emission, and a repeat of the
## same height none - at 10 Hz an unguarded emit would spam every listener ten times a
## second for as long as the keyboard is up.
func _signal_check() -> void:
	_mui_node.apply_keyboard_height(0)
	await _frames(2)
	_signal_log.clear()

	_mui_node.apply_keyboard_height(400)
	await _frames(2)
	_check(
		"one height change emits exactly one signal, carrying that height",
		_signal_log.size() == 1 and _signal_log[0] == 400,
		"emissions: %s" % str(_signal_log)
	)

	_mui_node.apply_keyboard_height(400)
	_mui_node.apply_keyboard_height(400)
	await _frames(2)
	_check(
		"a repeat of the same height emits nothing",
		_signal_log.size() == 1,
		"emissions after two further applies of 400: %s" % str(_signal_log)
	)

	_mui_node.apply_keyboard_height(0)
	await _frames(2)
	_check(
		"closing emits exactly one 0",
		_signal_log.size() == 2 and _signal_log[1] == 0,
		"emissions: %s" % str(_signal_log)
	)


## The one part of this fix that neither reported device could ever have caught.
## DisplayServer.virtual_keyboard_get_height() returns SCREEN pixels; the inset is spent in
## VIEWPORT units. With stretch canvas_items/expand on a 1920x1080 base the two coincide
## only when the device is exactly 1080 tall - which both the Moto E5 Plus (2160x1080) and
## the Poco X3 (2400x1080) are. On a 1440x720 handset an unconverted height is half the size
## it needs to be and the keyboard still covers the field.
func _conversion_check() -> void:
	await _resize(SHAPES[0])
	var vp_h_1080: float = _vp_height()
	var win_h_1080: float = float(get_window().size.y)
	_check(
		"at a 1080-tall device screen px and viewport units are 1:1 (why this was invisible)",
		int(_mui_node.screen_px_to_viewport_units(300)) == 300,
		"300 px -> %d units; window %.0f tall, viewport %.0f units tall"
			% [int(_mui_node.screen_px_to_viewport_units(300)), win_h_1080, vp_h_1080]
	)

	# 1440x720 against a 1920x1080 base with aspect=expand: the height is the limiting
	# dimension, so the visible rect comes out 2160x1080 and one screen pixel is 1.5 units.
	await _resize(Vector2i(1440, 720))
	var win_h: float = float(get_window().size.y)
	var vp_h: float = _vp_height()
	var expected: int = int(round(300.0 * vp_h / win_h))
	var got: int = int(_mui_node.screen_px_to_viewport_units(300))
	_check(
		"the shape used for this check is genuinely not 1:1",
		not is_equal_approx(win_h, vp_h),
		"window %.0f px tall vs viewport %.0f units tall (ratio %.2f)"
			% [win_h, vp_h, vp_h / maxf(win_h, 1.0)]
	)
	_check(
		"a screen-pixel keyboard height is converted into viewport units",
		got == expected and got != 300,
		"300 px -> %d units; expected %d (viewport %.0f / window %.0f)"
			% [got, expected, vp_h, win_h]
	)
	_check(
		"a hidden keyboard converts to zero, not to a scaled zero-ish number",
		int(_mui_node.screen_px_to_viewport_units(0)) == 0,
		"0 px -> %d units" % int(_mui_node.screen_px_to_viewport_units(0))
	)
	await _resize(SHAPES[0])


## The poll is per-frame code on the critical path of a phone that already misses its frame
## budget, so it has to cost nothing when nobody is typing. It is gated on
## Viewport.gui_get_focus_owner() being a text field: with nothing focused and no keyboard up
## the function returns before it reaches DisplayServer, and its own accumulator is forced
## back to 0. Measured with a delta SMALLER than KEYBOARD_POLL_INTERVAL so the two cases are
## distinguishable at all - with a larger delta both paths leave the accumulator at 0.
func _poll_gate_check() -> void:
	_mui_node.apply_keyboard_height(0)
	_ip_input.release_focus()
	var owner_now: Control = get_viewport().gui_get_focus_owner()
	_check(
		"the gated case really has nothing focused",
		owner_now == null,
		"focus owner: %s" % ("<none>" if owner_now == null else str(owner_now.name))
	)
	_mui_node._keyboard_poll_timer = 0.0
	_mui_node._poll_virtual_keyboard(0.02)
	_check(
		"with no text field focused the poll does no work at all",
		is_zero_approx(float(_mui_node._keyboard_poll_timer)),
		"accumulator %.3f s after a 0.02 s frame (interval %.2f s)"
			% [float(_mui_node._keyboard_poll_timer),
				float(_mui_node.KEYBOARD_POLL_INTERVAL)]
	)

	_ip_input.grab_focus()
	var focused: Control = get_viewport().gui_get_focus_owner()
	_check(
		"the IP field can hold focus, so the gate has something to open for",
		focused == _ip_input,
		"focus owner: %s" % ("<none>" if focused == null else str(focused.name))
	)
	_mui_node._keyboard_poll_timer = 0.0
	_mui_node._poll_virtual_keyboard(0.02)
	_check(
		"with the IP field focused the poll starts accumulating toward its next read",
		float(_mui_node._keyboard_poll_timer) > 0.0,
		"accumulator %.3f s after a 0.02 s frame" % float(_mui_node._keyboard_poll_timer)
	)
	_ip_input.release_focus()
	_mui_node._keyboard_poll_timer = 0.0
