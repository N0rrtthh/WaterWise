extends Node

## Is the QUIT/EXIT button on the title screen reachable, or is it off the bottom edge?
##
## THE DEFECT
##   Reported as "QUIT button clipped off the bottom of the title screen". The screen is
##   scenes/ui/MainMenu.tscn (project.godot run/main_scene), whose UI node is a
##   CenterContainer holding one VBoxContainer, and on mobile MainMenu calls
##   MobileUIManager.apply_mobile_scaling() on that VBox - which set Control.scale to
##   mobile_ui_scale (1.5).
##
##   Control.scale is invisible to layout. CenterContainer positioned the VBox from its
##   UNSCALED minimum size and the VBox then drew 1.5x larger, growing from pivot_offset,
##   which defaults to the top-left corner. So the box was centred and the CONTENT was
##   not: it started where a 618-unit box would be centred and ran 927 units down from
##   there, putting EXIT's bottom edge at 1158 on a 1080-unit screen. The same arithmetic
##   left the whole menu 154 units low and 214 units right of centre.
##
##   Why no headless sweep caught it: the box height is driven by the 48dp touch floor,
##   which is dpi-dependent (MobileUIManager._dp_to_canvas_units). A headless
##   DisplayServer reports no dpi, the code falls back to mdpi 160, and at that density
##   the same layout has 24 units to spare. The defect exists only at real phone
##   densities - which is exactly where the report came from.
##
## WHAT IS MEASURED HERE
##   1. that the defect is still reproducible: at the reported devices' densities the
##      old top-left-pivot arithmetic really does put EXIT below the bottom edge. Without
##      this row every check below could pass on a layout that never had the problem.
##   2. that every button and every label on the title screen is fully inside the
##      viewport, at both reported device shapes and across a density band, measured
##      through the accumulated canvas transform so the ancestor's scale counts.
##   3. that the drawn content is actually centred, which is the other half of the same
##      defect and the thing the screenshot shows.
##   4. that the factor is only ever clamped DOWN, never below the authored 1.0, so this
##      can turn a clipped screen into a fitting one but never shrink a working one.
##   5. that re-running the scaling pass - which every viewport resize does - neither
##      compounds the scale nor drifts the pivot.
##   6. that desktop is untouched: no scale, no pivot rewrite, single player unchanged.
##   7. that a pivot the scene authored itself is left alone.
##
## NOT MEASURED HERE (needs the physical device)
##   The dpi the Moto E5 Plus actually reports. This harness injects densities through
##   MobileUIManager.debug_dpi_override - the same value the production conversion reads -
##   and sweeps a band around the plausible figure rather than betting on one number.
##
## Usage:
##   godot --headless --path . res://tools/VerifyMenuFit.tscn

const MENU: String = "res://scenes/ui/MainMenu.tscn"

## The two reported devices at the densities their panels imply, plus the mdpi fallback
## that made the defect invisible, plus a denser case where even a centred 1.5x cannot
## fit and the clamp has to do the work.
const CASES: Array = [
	{"n": "mdpi fallback (what headless sees)", "w": 2160, "h": 1080, "dpi": 160.0, "reported": false},
	{"n": "Moto E5 Plus 2160x1080, 268 dpi", "w": 2160, "h": 1080, "dpi": 268.0, "reported": true},
	{"n": "Moto E5 Plus 2160x1080, 402 dpi", "w": 2160, "h": 1080, "dpi": 402.0, "reported": true},
	{"n": "Poco X3 2400x1080, 395 dpi", "w": 2400, "h": 1080, "dpi": 395.0, "reported": true},
	{"n": "xxxhdpi stress 2160x1080, 560 dpi", "w": 2160, "h": 1080, "dpi": 560.0, "reported": false},
]

var _pass: int = 0
var _fail: int = 0
var _mui: Node = null
var _reproduced: int = 0


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


## Where a Control is actually drawn on the glass, ancestor scale included. Control's own
## get_global_rect() returns size UNSCALED, which is the blind spot that let this ship:
## the position moves with the parent's scale but the size does not, so a control inside a
## 1.5x ancestor measures as fitting when 43% of it is off the screen.
func _glass(c: Control) -> Rect2:
	var x := c.get_global_transform_with_canvas()
	return Rect2(x.origin, c.size * x.get_scale())


## The rect the OLD code drew: identical layout positions, but the mobile-scaled ancestor
## growing down and right from its top-left corner instead of out from its middle.
##
## Godot maps a local point through position + pivot + scale * (p - pivot), so a pivoted
## box is drawn pivot * (1 - scale) away from where an unpivoted one would be. The only
## difference between the two versions of this screen is that pivot, so adding
## pivot * (scale - 1) back onto the measured rect reconstructs the reported geometry
## rather than asserting against a number typed in from a previous run.
func _topleft_pivot_rect(c: Control) -> Rect2:
	var g := _glass(c)
	var root := _scaled_root_of(c)
	if root == null:
		return g
	return Rect2(g.position + root.pivot_offset * (root.scale - Vector2.ONE), g.size)


## The ancestor MobileUIManager scaled, which is the node whose pivot moved everything.
func _scaled_root_of(c: Control) -> Control:
	var n: Node = c
	while n != null:
		if n is Control and (n as Control).has_meta("_mobile_scaled_root"):
			return n as Control
		n = n.get_parent()
	return null


func _box_of(c: Control) -> Vector2:
	var m := c.get_combined_minimum_size()
	return Vector2(maxf(c.size.x, m.x), maxf(c.size.y, m.y))


func _visible_ctrls(root: Node, out: Array, want_buttons: bool) -> void:
	if root is Control:
		var c := root as Control
		var is_btn := c is BaseButton
		if c.is_visible_in_tree() and is_btn == want_buttons:
			if not is_btn or not (c as BaseButton).disabled:
				if is_btn or (c is Label and (c as Label).text != ""):
					out.append(c)
	for ch in root.get_children():
		_visible_ctrls(ch, out, want_buttons)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== Title-screen fit: is EXIT on the screen? ===")

	_mui = get_node_or_null("/root/MobileUIManager")
	if _mui == null:
		print("  FAIL  MobileUIManager autoload missing")
		get_tree().quit(1)
		return

	await _desktop_check()

	_mui.enable_debug_mobile_mode(true)
	for c in CASES:
		await _case(c)

	_check(
		"the reported defect is reproducible at the reported densities (guards a vacuous pass)",
		_reproduced >= 2,
		"%d of the reported device cases put EXIT below the bottom edge under the old top-left-pivot arithmetic" % _reproduced
	)

	await _clamp_check()
	_authored_pivot_check()

	print("")
	print("  -- on-device row, not measurable headless --")
	print("     The dpi the Moto E5 Plus reports to DisplayServer.screen_get_dpi(). This run")
	print("     injects densities through debug_dpi_override - the same value the production")
	print("     conversion reads - and sweeps a band rather than betting on one number.")
	print("")
	print("=== RESULT: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## Single player runs this same screen. With mobile off nothing here may touch it.
func _desktop_check() -> void:
	_mui.enable_debug_mobile_mode(false)
	get_window().size = Vector2i(1920, 1080)
	await _frames(4)
	var menu: Node = load(MENU).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	await _frames(30)
	var vbox := menu.get_node_or_null("UI/VBoxContainer") as Control
	if vbox == null:
		_check("desktop: the title screen still has UI/VBoxContainer", false)
		menu.queue_free()
		return
	_check(
		"desktop leaves the title screen's scale and pivot exactly as authored",
		vbox.scale.is_equal_approx(Vector2.ONE) and vbox.pivot_offset.is_zero_approx()
			and not vbox.has_meta("_mobile_scaled_root"),
		"scale %s pivot %s scaled_root_meta %s"
			% [str(vbox.scale), str(vbox.pivot_offset), vbox.has_meta("_mobile_scaled_root")]
	)
	var q := menu.get_node_or_null("UI/VBoxContainer/QuitButton") as Control
	if q:
		var g := _glass(q)
		_check(
			"desktop: EXIT is on screen (the single-player path this shares)",
			g.end.y <= 1080.0 and g.position.y >= 0.0,
			"EXIT y=%.1f..%.1f in a 1080-unit viewport" % [g.position.y, g.end.y]
		)
	menu.queue_free()
	await _frames(4)


## One device shape at one density: does everything the player can see and press land
## inside the screen, and is the content actually centred?
func _case(c: Dictionary) -> void:
	get_window().size = Vector2i(int(c["w"]), int(c["h"]))
	await _frames(4)
	# The density goes in through the same override the audit uses, and the cached button
	# floor is dropped so the new density is actually read rather than served from cache.
	_mui.debug_dpi_override = float(c["dpi"])
	_mui.invalidate_button_min_size_cache()
	_mui.enable_debug_mobile_mode(true)
	await _frames(2)

	var menu: Node = load(MENU).instantiate()
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	# adapt_scene_for_mobile is what raises the button minimums to the 48dp floor, and in
	# the running game it fires from _on_tree_changed when tree.current_scene changes.
	# Under a harness current_scene is assigned by hand, so it is called explicitly - the
	# alternative is measuring the raw .tscn and calling it the mobile layout.
	_mui.adapt_scene_for_mobile(menu)
	await _frames(45)

	var vp := get_viewport().get_visible_rect().size
	var view := Rect2(Vector2.ZERO, vp)
	var vbox := menu.get_node_or_null("UI/VBoxContainer") as Control
	var quit_btn := menu.get_node_or_null("UI/VBoxContainer/QuitButton") as Control
	print("")
	print("  -- %s: viewport %.0fx%.0f, 48dp floor %s, VBox box %s, scale %.3f --"
		% [c["n"], vp.x, vp.y, str(_mui._resolve_button_min_size()),
			str(_box_of(vbox)) if vbox else "?", vbox.scale.y if vbox else 0.0])

	if vbox == null or quit_btn == null:
		_check("%s: the title screen still has UI/VBoxContainer/QuitButton" % c["n"], false)
		menu.queue_free()
		return

	# The guard. Report it for every case and count only the reported devices: at the mdpi
	# fallback the old arithmetic did fit, which is precisely why nobody saw this.
	var old := _topleft_pivot_rect(quit_btn)
	var overflowed: bool = old.end.y > vp.y
	if bool(c["reported"]) and overflowed:
		_reproduced += 1
	print("     old top-left-pivot EXIT bottom %.1f vs screen %.0f -> %s"
		% [old.end.y, vp.y, "OFF THE BOTTOM by %.1f" % (old.end.y - vp.y) if overflowed else "fitted"])

	var g := _glass(quit_btn)
	_check(
		"%s: EXIT is fully on screen" % c["n"],
		view.encloses(g),
		"EXIT %.1f,%.1f %.0fx%.0f in %.0fx%.0f (%.1f units of bottom clearance)"
			% [g.position.x, g.position.y, g.size.x, g.size.y, vp.x, vp.y, vp.y - g.end.y]
	)

	var buttons: Array = []
	_visible_ctrls(menu, buttons, true)
	var off_btn: Array = []
	for b in buttons:
		if not view.encloses(_glass(b)):
			off_btn.append("%s%s" % [str(menu.get_path_to(b)), str(_glass(b))])
	_check(
		"%s: every pressable button on the title screen is on screen" % c["n"],
		off_btn.is_empty(),
		"%d buttons checked; off screen: %s" % [buttons.size(), str(off_btn).substr(0, 240)]
	)

	var labels: Array = []
	_visible_ctrls(menu, labels, false)
	var off_lbl: Array = []
	for l in labels:
		if not view.encloses(_glass(l)):
			off_lbl.append("%s%s" % [str(menu.get_path_to(l)), str(_glass(l))])
	_check(
		"%s: no text on the title screen is cut off by an edge" % c["n"],
		off_lbl.is_empty(),
		"%d labels checked; off screen: %s" % [labels.size(), str(off_lbl).substr(0, 240)]
	)

	# The other half of the same defect: a container that centred the box has to end up
	# with the DRAWN content centred too, or the menu sits low and to the right.
	var gb := _glass(vbox)
	var ui := menu.get_node_or_null("UI") as Control
	var box_centre: Vector2 = ui.get_global_transform_with_canvas() * (ui.size * 0.5)
	_check(
		"%s: the drawn menu is centred in the space the container gave it" % c["n"],
		absf(gb.get_center().x - box_centre.x) <= 1.0
			and absf(gb.get_center().y - box_centre.y) <= 1.0,
		"content centre %.1f,%.1f vs container centre %.1f,%.1f"
			% [gb.get_center().x, gb.get_center().y, box_centre.x, box_centre.y]
	)
	_check(
		"%s: the factor is clamped down but never below the authored 1.0" % c["n"],
		vbox.scale.y >= 1.0 and vbox.scale.y <= float(_mui.mobile_ui_scale) + 0.001,
		"scale %.3f against mobile_ui_scale %.3f" % [vbox.scale.y, float(_mui.mobile_ui_scale)]
	)

	# Every viewport resize re-runs MainMenu._apply_mobile_ui_scaling(), so the second and
	# tenth pass have to land on the same numbers as the first.
	var scale_before: Vector2 = vbox.scale
	var pivot_before: Vector2 = vbox.pivot_offset
	menu.call("_apply_mobile_ui_scaling")
	menu.call("_apply_mobile_ui_scaling")
	await _frames(6)
	_check(
		"%s: re-running the scaling pass does not compound the scale or drift the pivot" % c["n"],
		vbox.scale.is_equal_approx(scale_before) and vbox.pivot_offset.is_equal_approx(pivot_before),
		"scale %s -> %s, pivot %s -> %s"
			% [str(scale_before), str(vbox.scale), str(pivot_before), str(vbox.pivot_offset)]
	)

	menu.queue_free()
	await _frames(4)


## The clamp itself, on a box built to need it. A screen whose content is already taller
## than the room it has must not be magnified further, and must not be shrunk below what
## the scene authored either - a box that does not fit at 1.0 is the scene's own bug and
## squashing it here would hide that.
func _clamp_check() -> void:
	get_window().size = Vector2i(2160, 1080)
	await _frames(4)
	_mui.enable_debug_mobile_mode(true)
	await _frames(2)
	var vp := get_viewport().get_visible_rect().size

	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(host)
	await _frames(2)

	# 80% of the screen height: fits at 1.0, cannot fit at 1.5, so the clamp must land
	# between the two and exactly fill.
	var tall := Control.new()
	tall.custom_minimum_size = Vector2(400.0, vp.y * 0.8)
	host.add_child(tall)
	await _frames(2)
	_mui.apply_mobile_scaling(tall)
	await _frames(2)
	var want: float = vp.y / (vp.y * 0.8)
	_check(
		"a box too tall for 1.5x is clamped to exactly the factor that fits",
		absf(tall.scale.y - want) <= 0.01,
		"scale %.3f, expected %.3f (%.0f units of room for a %.0f-unit box)"
			% [tall.scale.y, want, vp.y, vp.y * 0.8]
	)
	_check(
		"the clamped box now fits the room it was given",
		_box_of(tall).y * tall.scale.y <= vp.y + 0.5,
		"drawn height %.1f vs %.0f units of room" % [_box_of(tall).y * tall.scale.y, vp.y]
	)

	# Taller than the screen at 1.0 already. The floor has to hold.
	var over := Control.new()
	over.custom_minimum_size = Vector2(400.0, vp.y * 1.4)
	host.add_child(over)
	await _frames(2)
	_mui.apply_mobile_scaling(over)
	await _frames(2)
	_check(
		"a box that does not fit even at 1.0 is left at 1.0 rather than squashed",
		is_equal_approx(over.scale.y, 1.0),
		"scale %.3f for a %.0f-unit box in %.0f units of room"
			% [over.scale.y, vp.y * 1.4, vp.y]
	)

	# Room to spare: the full mobile magnification has to survive.
	var small := Control.new()
	small.custom_minimum_size = Vector2(100.0, 100.0)
	host.add_child(small)
	await _frames(2)
	_mui.apply_mobile_scaling(small)
	await _frames(2)
	_check(
		"a box with room to spare keeps the full mobile magnification",
		is_equal_approx(small.scale.y, float(_mui.mobile_ui_scale)),
		"scale %.3f against mobile_ui_scale %.3f" % [small.scale.y, float(_mui.mobile_ui_scale)]
	)
	_check(
		"the centred pivot is the middle of the box, not the corner",
		small.pivot_offset.is_equal_approx(Vector2(50.0, 50.0)),
		"pivot %s for a 100x100 box" % str(small.pivot_offset)
	)

	host.queue_free()
	await _frames(4)


## A pivot the scene set for itself - an entrance popup, a rotation - is an opinion, and
## overwriting it would move that animation's origin. Only a pivot left at the default is
## claimed.
func _authored_pivot_check() -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(host)
	var authored := Control.new()
	authored.custom_minimum_size = Vector2(200.0, 200.0)
	authored.pivot_offset = Vector2(7.0, 9.0)
	host.add_child(authored)
	_mui.apply_mobile_scaling(authored)
	_check(
		"a pivot the scene authored itself is left alone",
		authored.pivot_offset.is_equal_approx(Vector2(7.0, 9.0)),
		"pivot %s (authored 7,9)" % str(authored.pivot_offset)
	)
	_check(
		"an authored pivot still gets the mobile scale",
		is_equal_approx(authored.scale.y, float(_mui.mobile_ui_scale)),
		"scale %.3f" % authored.scale.y
	)
	host.queue_free()
