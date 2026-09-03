extends Node

## Proves that a paused SceneTree, not a layout defect, produced the 38.5dp
## touch-target failures the 7-profile AuditMobileUI run reported.
##
## THE CLAIM UNDER TEST
##   MobileUIManager pauses the whole SceneTree when the app goes to background.
##   That is correct on Android. In a windowed harness the same notification fires
##   when the window merely loses focus, and a paused tree freezes every Tween - so
##   UnlockablesScreen is measured with MainPanel still at its reveal start scale of
##   0.85 and each card still at 0.94. 0.85 * 0.94 = 0.799, and the failing sizes
##   were exactly 0.8 of the compliant ones (154x125 measured as 123x100).
##
##   That is arithmetic that FITS the observation. It is not yet a demonstration.
##   This probe forces the pause, measures, clears it, measures again, and requires
##   the numbers to move the predicted way. If they do not, the pause is not the
##   cause and the dp failure is a real defect that still needs fixing.
##
## Usage (WINDOWED - Control layout needs a real window):
##   godot --path . res://tools/ProbePauseArtifact.tscn

const SCENE: String = "res://scenes/ui/UnlockablesScreen.tscn"
const MIN_TOUCH_DP: float = 48.0

## The 21:9 profile the failure was reported on, with its cutout.
const DEV_W: int = 2560
const DEV_H: int = 1080
const DEV_DIAG: float = 6.7
const CUT: Dictionary = {"left": 110.0, "right": 0.0, "top": 0.0, "bottom": 44.0}

var _failed: int = 0


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Frames that advance whether or not the tree is paused. SceneTree.process_frame
## is emitted every frame regardless of pause state, which is what lets this probe
## wait out a reveal animation that is deliberately frozen.
func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _dpi() -> float:
	var w := float(DEV_W)
	var h := float(DEV_H)
	return sqrt(w * w + h * h) / DEV_DIAG


## The same measurement AuditMobileUI makes: reachable size, which is the control's
## own size scaled by every ancestor transform.
func _smallest_card(inst: Node) -> Dictionary:
	var out := {"dp": 99999.0, "size": Vector2.ZERO, "raw": Vector2.ZERO,
		"scale": Vector2.ONE, "name": ""}
	var canvas := _tree().root.get_visible_rect().size
	var ratio := 1.0
	if canvas.x > 0.0:
		ratio = float(DisplayServer.window_get_size().x) / canvas.x
	var density := _dpi() / 160.0
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is BaseButton:
			var b := n as BaseButton
			if b.is_visible_in_tree() and not b.disabled \
					and b.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				var sc := b.get_global_transform().get_scale()
				var sz: Vector2 = b.size * sc
				var dp: float = minf(sz.x * ratio / density, sz.y * ratio / density)
				if dp < float(out["dp"]):
					out["dp"] = dp
					out["size"] = sz
					out["raw"] = b.size
					out["scale"] = sc
					out["name"] = str(inst.get_path_to(b))
		for c in n.get_children():
			stack.append(c)
	return out


## Which grid card the pinned button came from. Recorded so the two runs can be shown
## to have pinned the same card and not merely the same class of node.
var _pinned_card_index: int = -1


## One grid card's inner Button, pinned so the same control can be followed across
## both runs.
##
## Needed because the "smallest target" is a different NODE in the two runs: frozen
## at 0.799 the smallest is a grid card, and at rest the cards grow past the Back
## button, which then becomes the smallest. Comparing those two would be comparing
## two different controls, which cannot say whether the LAYOUT changed.
##
## Cards are scanned in order rather than taking child 0, because not every card
## carries a button - a locked entry is rendered without its action button, and on a
## fresh save card 0 is locked. Taking child 0 returned null and made this probe
## report four failures that were entirely its own fault.
func _fixed_card_button(inst: Node) -> BaseButton:
	var grid: Node = null
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is GridContainer:
			grid = n
			break
		for c in n.get_children():
			stack.append(c)
	if grid == null:
		return null
	for i in range(grid.get_child_count()):
		var inner: Array = [grid.get_child(i)]
		while not inner.is_empty():
			var n2: Node = inner.pop_front()
			if n2 is BaseButton:
				_pinned_card_index = i
				return n2 as BaseButton
			for c2 in n2.get_children():
				inner.append(c2)
	return null
	return null


func _check(label: String, cond: bool, detail: String) -> void:
	if cond:
		print("  PASS  %-46s %s" % [label, detail])
	else:
		_failed += 1
		print("  FAIL  %-46s %s" % [label, detail])


func _measure(paused: bool) -> Dictionary:
	var mui := get_node_or_null("/root/MobileUIManager")
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	_tree().root.add_child(inst)
	if mui != null:
		mui.adapt_scene_for_mobile(inst)
	_tree().paused = paused
	# The same 45-frame settle AuditMobileUI uses. Under a pause this is 45 frames
	# of a frozen animation; unpaused it is long enough for the 0.3s panel tween and
	# the staggered 0.18s card tweens to finish.
	await _frames(45)
	var m := _smallest_card(inst)
	# Follow one pinned control as well, so a layout comparison across the two runs
	# compares the same node instead of whichever node happened to be smallest.
	var fixed := _fixed_card_button(inst)
	if fixed != null:
		var fsc := fixed.get_global_transform().get_scale()
		var canvas2 := _tree().root.get_visible_rect().size
		var ratio2 := 1.0
		if canvas2.x > 0.0:
			ratio2 = float(DisplayServer.window_get_size().x) / canvas2.x
		var density2 := _dpi() / 160.0
		m["fixed_raw"] = fixed.size
		m["fixed_scale"] = fsc
		m["fixed_name"] = str(inst.get_path_to(fixed))
		m["card_index"] = _pinned_card_index
		m["fixed_dp"] = minf(fixed.size.x * fsc.x * ratio2 / density2,
			fixed.size.y * fsc.y * ratio2 / density2)
	else:
		m["fixed_raw"] = Vector2.ZERO
		m["fixed_scale"] = Vector2.ZERO
		m["fixed_name"] = "<no grid card found>"
		m["card_index"] = -1
		m["fixed_dp"] = -1.0
	_tree().paused = false
	inst.queue_free()
	await _frames(4)
	return m


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== PROBE: IS THE 38.5dp FAILURE A PAUSED-TWEEN ARTEFACT? ===")
	if DisplayServer.get_name() == "headless":
		print("  REFUSING: Control layout and window sizing need a real window.")
		_tree().quit(2)
		return
	var mui := get_node_or_null("/root/MobileUIManager")
	if mui == null:
		print("  FAIL: MobileUIManager autoload missing")
		_tree().quit(1)
		return

	# Reproduce the exact profile the failure was reported on.
	mui.debug_mobile_mode = true
	DisplayServer.window_set_size(Vector2i(DEV_W, DEV_H))
	await _frames(8)
	if mui.has_method("_detect_platform"):
		mui._detect_platform()
	mui.debug_dpi_override = _dpi()
	mui.debug_safe_area_px_override = CUT
	mui.invalidate_button_min_size_cache()
	if mui.has_method("_calculate_safe_area"):
		mui._calculate_safe_area()
	var canvas := _tree().root.get_visible_rect().size
	print("  profile %dx%d, canvas %.0fx%.0f, %.0f dpi, enforced minimum %s"
		% [DEV_W, DEV_H, canvas.x, canvas.y, _dpi(),
			str(mui._resolve_button_min_size()) if mui.has_method("_resolve_button_min_size") else "n/a"])
	print("")

	var frozen: Dictionary = await _measure(true)
	print("  paused   : smallest %.1fdp (%s)" % [frozen["dp"], frozen["name"]])
	print("             pinned card %.1fdp  reachable %.1fx%.1f  own size %.1fx%.1f  ancestor scale %.4f"
		% [frozen["fixed_dp"],
			frozen["fixed_raw"].x * frozen["fixed_scale"].x,
			frozen["fixed_raw"].y * frozen["fixed_scale"].y,
			frozen["fixed_raw"].x, frozen["fixed_raw"].y, frozen["fixed_scale"].x])

	var running: Dictionary = await _measure(false)
	print("  unpaused : smallest %.1fdp (%s)" % [running["dp"], running["name"]])
	print("             pinned card %.1fdp  reachable %.1fx%.1f  own size %.1fx%.1f  ancestor scale %.4f"
		% [running["fixed_dp"],
			running["fixed_raw"].x * running["fixed_scale"].x,
			running["fixed_raw"].y * running["fixed_scale"].y,
			running["fixed_raw"].x, running["fixed_raw"].y, running["fixed_scale"].x])
	print("")

	# The predictions. Each one has to hold, or the pause hypothesis is wrong and the
	# sub-48dp reading is a real defect that needs a real fix.
	_check("a pinned card was found in both runs",
		float(frozen["fixed_dp"]) > 0.0 and float(running["fixed_dp"]) > 0.0,
		"card index %d / %d, %s" % [frozen["card_index"], running["card_index"], str(frozen["fixed_name"])])
	_check("both runs pinned the SAME card",
		int(frozen["card_index"]) >= 0 and int(frozen["card_index"]) == int(running["card_index"]),
		"index %d in both" % int(frozen["card_index"]))
	_check("paused run reproduces the sub-48dp reading",
		float(frozen["fixed_dp"]) < MIN_TOUCH_DP,
		"pinned card %.1fdp < %.0fdp" % [frozen["fixed_dp"], MIN_TOUCH_DP])
	_check("the SAME card clears the minimum unpaused",
		float(running["fixed_dp"]) >= MIN_TOUCH_DP,
		"pinned card %.1fdp >= %.0fdp" % [running["fixed_dp"], MIN_TOUCH_DP])
	# The decisive one. If the pause only froze an animation then the layout the
	# containers computed is byte-identical between the runs, and the entire
	# difference is the ancestor transform. If the own size differs, something other
	# than the animation moved and the pause is not a complete explanation.
	_check("layout is identical - only the transform differs",
		running["fixed_raw"].is_equal_approx(frozen["fixed_raw"]),
		"own size paused %s vs unpaused %s"
			% [str(frozen["fixed_raw"]), str(running["fixed_raw"])])
	# 0.85 (MainPanel reveal start, UnlockablesScreen.gd:140) * 0.94 (card reveal
	# start, _animate_grid_reveal) = 0.799.
	_check("frozen transform is the reveal-start product 0.799",
		absf(float(frozen["fixed_scale"].x) - 0.85 * 0.94) < 0.01,
		"measured %.4f, expected %.4f" % [frozen["fixed_scale"].x, 0.85 * 0.94])
	_check("unpaused transform reaches rest 1.0",
		absf(float(running["fixed_scale"].x) - 1.0) < 0.01,
		"measured %.4f" % running["fixed_scale"].x)
	# And the smallest target overall must clear the bar once nothing is frozen -
	# that is the claim AuditMobileUI actually reports.
	_check("smallest target of the whole scene clears 48dp unpaused",
		float(running["dp"]) >= MIN_TOUCH_DP,
		"%.1fdp at %s" % [running["dp"], running["name"]])

	print("")
	print("  RESULT: %d failed" % _failed)
	if _failed == 0:
		print("  => The 38.5dp finding was a MEASUREMENT ARTEFACT of a paused tree.")
		print("     The layout is compliant; the harness, not the product, was at fault.")
	else:
		print("  => Pause does NOT fully explain it. Treat it as a real defect.")
	print("")
	_tree().quit(0)
