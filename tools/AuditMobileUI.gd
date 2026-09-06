extends Node

## Mobile UI/UX audit: touch-target size, clipping and overlap, measured at real
## device resolutions instead of asserted.
##
## WHY dp AND NOT PIXELS
##   The project stretches a 1920x1080 canvas with stretch/mode="canvas_items"
##   and stretch/aspect="expand", so a control size is in CANVAS units, not in
##   device pixels. MobileUIManager enforces its minimum in those same canvas
##   units (mobile_button_min_size, applied through custom_minimum_size), which
##   makes the enforced number internally consistent but says nothing about how
##   big the target actually is under a finger. A 60-unit-tall button is 60 px on
##   a 1080p screen and 40 px on a 720p one.
##
##   The standard that does describe a finger is the Android 48dp minimum touch
##   target (Material; WCAG 2.5.5 asks for the equivalent 44 CSS px). dp is
##   physical pixels divided by density, and density is dpi/160. So this audit
##   measures the canvas size the layout actually produced, converts it to device
##   pixels through the real stretch ratio, and converts that to dp through the
##   real dpi of a named device. Every step is a measurement or an arithmetic
##   identity; nothing is a guess.
##
## WHAT IT CHECKS, PER SCENE PER DEVICE
##   1. every enabled, visible, hit-testable BaseButton reaches 48dp on both axes
##   2. no interactive control lands partly or wholly outside the visible canvas
##   3. no two interactive controls overlap (the accidental-touch case)
##
## Usage (WINDOWED - resizing and layout need a real window):
##   godot --path . res://tools/AuditMobileUI.tscn

## The Android minimum touch target. Material Design and the Android
## accessibility guidelines both state 48dp; WCAG 2.5.5 Level AAA asks for
## 44 CSS px, which is the same physical size.
const MIN_TOUCH_DP: float = 48.0

## Real device geometries, landscape because project.godot forces
## handheld/orientation="sensor_landscape". The first three are the target class
## the paper names (legacy, sub-2GB Android); FHD and FHD+ show the mainstream
## range; the last two are the aspect extremes a 1920x1080 base has to survive.
##
## "cut" injects a landscape hardware cutout in DEVICE PIXELS through
## MobileUIManager.debug_safe_area_px_override, so the clipping and overlap checks
## run against a layout that has real safe-area insets folded in. Without it every
## inset is 0 on a desktop DisplayServer and the whole safe-area path - including
## the mirroring that allow_reverse_landscape turns on - would be measured only in
## its no-op state. Legacy phones genuinely have no cutout, so theirs stay empty.
##
## The two extreme aspects are the canvas sizes VerifyAspectSupply already
## confirmed the engine produces under stretch/aspect="expand": 21:9 widens the
## canvas to 2560x1080, and 4:3 heightens it to 1920x1440. That harness checks what
## the extra room does to gameplay SUPPLY; these two rows check what it does to UI
## LAYOUT, which is the other half.
const DEVICES: Array = [
	{"name": "WVGA 4.5in", "w": 854, "h": 480, "diag": 4.5},
	{"name": "qHD 4.5in", "w": 960, "h": 540, "diag": 4.5},
	{"name": "HD 5.0in", "w": 1280, "h": 720, "diag": 5.0},
	{"name": "FHD 6.0in", "w": 1920, "h": 1080, "diag": 6.0,
		"cut": {"left": 88.0, "right": 0.0, "top": 0.0, "bottom": 48.0}},
	{"name": "FHD+ 6.5in", "w": 2340, "h": 1080, "diag": 6.5,
		"cut": {"left": 96.0, "right": 0.0, "top": 0.0, "bottom": 44.0}},
	{"name": "21:9 6.7in", "w": 2560, "h": 1080, "diag": 6.7,
		"cut": {"left": 110.0, "right": 0.0, "top": 0.0, "bottom": 44.0}},
	{"name": "4:3 tab 9.7in", "w": 2048, "h": 1536, "diag": 9.7},
	# The two devices the session logs came from, at the densities their panels imply.
	# The generic profiles above bracket them on shape but not on density, and density is
	# what drives the 48dp touch floor and therefore every container minimum size.
	{"name": "Moto E5 Plus", "w": 2160, "h": 1080, "diag": 6.0,
		"cut": {"left": 0.0, "right": 0.0, "top": 0.0, "bottom": 48.0}},
	{"name": "Poco X3", "w": 2400, "h": 1080, "diag": 6.67,
		"cut": {"left": 0.0, "right": 0.0, "top": 0.0, "bottom": 44.0}},
]

const SCENES: Array = [
	"res://scenes/ui/InitialScreen.tscn",
	"res://scenes/ui/MainMenu.tscn",
	"res://scenes/ui/MultiplayerMenu.tscn",
	"res://scenes/ui/MultiplayerLobby.tscn",
	"res://scenes/ui/Settings.tscn",
	"res://scenes/ui/FinalScore.tscn",
	"res://scenes/ui/UnlockablesScreen.tscn",
]

## Screens that show more than one panel in the same scene. Auditing a scene only in the
## state it opens in measured MultiplayerLobby's mode-select buttons at nine device shapes
## and never looked at the waiting room or the join form - and the waiting room is where the
## reported clipping was: its column is seven rows tall, five of them raised to the
## density-dependent 48dp floor, so it overflowed on both reported phones while the three
## mode-select buttons fitted everywhere. Each entry names a method on the scene root that
## puts it into that state; "" is the state the scene opens in. Depth for the waiting room
## specifically - both roles, a density band, reachability of every row - lives in
## tools/VerifyWaitingRoomFit.tscn; this table is what makes the general sweep see the panel
## at all.
const PANEL_STATES: Dictionary = {
	"MultiplayerLobby": [
		{"call": "", "label": "mode select"},
		{"call": "_show_join_panel", "label": "join form"},
		{"call": "_show_waiting_panel", "label": "waiting room"},
	],
}


## The states to audit for one scene: its own list, or the single default state.
func _states_for(path: String) -> Array:
	var key := path.get_file().get_basename()
	if PANEL_STATES.has(key):
		return PANEL_STATES[key]
	return [{"call": "", "label": ""}]

var _rows: Array = []
var _worst_dp: float = 99999.0
var _worst_where: String = ""


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## How many frames this run had to clear a pause. Reported, not hidden: a nonzero
## count means the harness window lost focus mid-sweep, and any measurement is only
## trustworthy because the pause was cleared before the frame advanced.
var _unpaused_frames: int = 0


## Frames, with the tree kept running.
##
## MobileUIManager pauses the entire SceneTree when the app goes to background
## (autoload/MobileUIManager.gd, _on_app_background -> get_tree().paused = true).
## That is right on Android and wrong for a windowed harness: this window loses
## focus while a long sweep runs, every Tween bound to the scene under test freezes,
## and sizes are then read at the START of the reveal animation instead of at rest.
## The error is not small. UnlockablesScreen begins its reveal with MainPanel at
## scale 0.85 and each card at 0.94, so a fully compliant 154x125 card button
## measured 123x100 - 0.799 of its real size - and the audit reported 38.5dp
## failures on the last two profiles of the sweep that do not exist on a device.
## Clearing the pause keeps every measurement on the resting layout.
func _frames(n: int) -> void:
	for _i in range(n):
		if _tree().paused:
			_tree().paused = false
			_unpaused_frames += 1
		await _tree().process_frame


## Density-independent pixels for a device: dp = device_px / (dpi / 160).
func _dp(device_px: float, dpi: float) -> float:
	return device_px / (dpi / 160.0)


func _dpi(d: Dictionary) -> float:
	var w := float(d["w"])
	var h := float(d["h"])
	return sqrt(w * w + h * h) / float(d["diag"])


## Every BaseButton under root that a finger could actually hit: on screen,
## enabled, and not set to ignore input. A disabled or MOUSE_FILTER_IGNORE
## control is not a touch target, and counting it would inflate the failure list
## with things no player can press.
func _touch_targets(root: Node, out: Array) -> void:
	if root is BaseButton:
		var b := root as BaseButton
		var hittable: bool = b.mouse_filter != Control.MOUSE_FILTER_IGNORE
		if b.is_visible_in_tree() and not b.disabled and hittable:
			out.append(b)
	for c in root.get_children():
		_touch_targets(c, out)


## The rect a finger can actually reach: the control's global rect intersected with
## every clip_contents ancestor.
##
## Godot's hit test does exactly this - Viewport's control search skips a whole
## subtree when the point falls outside a clipping ancestor - so an overlap
## computed on raw rects can be an artefact of a list scrolled under something
## else rather than a place a player can mis-tap. Without this, UnlockablesScreen
## reported three overlapping pairs on every device: grid cards whose rects run
## past the bottom of their ScrollContainer and under the panel's Back button,
## where they are clipped away and untouchable.
## Where a Control is actually drawn, ancestor scale included.
##
## Control.get_global_rect() pairs a TRANSFORMED position with an UNTRANSFORMED size, so a
## control inside a scaled ancestor measures smaller than it draws - and this audit's
## clipping check used it. MainMenu reported "clipped 0" on every device profile while the
## title screen's EXIT button hung 78 units off the bottom of a 1080-unit screen at real
## phone densities, because the VBox above it carries MobileUIManager's 1.5x mobile scale.
## The touch-target size check a few lines below always multiplied by the transform scale;
## the clipping and overlap checks did not. Measured in tools/VerifyMenuFit.tscn.
func _canvas_rect(c: Control) -> Rect2:
	var x := c.get_global_transform_with_canvas()
	return Rect2(x.origin, c.size * x.get_scale())


func _effective_rect(ctrl: Control) -> Rect2:
	var r := _canvas_rect(ctrl)
	var p := ctrl.get_parent()
	while p != null:
		if p is Control and (p as Control).clip_contents:
			r = r.intersection(_canvas_rect(p as Control))
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				return Rect2()
		p = p.get_parent()
	return r


## A ScrollContainer ancestor changes the meaning of "outside the viewport": the
## control is reachable by scrolling, so it is not a clipping defect. The first
## run of this probe counted 9 clipped controls in Settings and every one of them
## was a scrolled list row.
func _in_scroll(ctrl: Node) -> bool:
	var p := ctrl.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _audit_scene(path: String, d: Dictionary, mui: Node, state: Dictionary) -> Dictionary:
	var label: String = str(state.get("label", ""))
	var res := {
		"scene": path.get_file().get_basename() + ("" if label == "" else " " + label),
		"device": d["name"],
		"targets": 0, "too_small": 0, "clipped": 0, "overlaps": 0,
		"min_dp": 99999.0, "min_name": "", "smallest_canvas": Vector2.ZERO,
		"scrolled_off": 0, "clip_names": [], "overlap_names": [], "small_names": [],
		"exempt": 0,
	}

	var inst: Node = (load(path) as PackedScene).instantiate()
	_tree().root.add_child(inst)
	# Reproduce the production adaptation path. In the real game MobileUIManager
	# adapts a scene from _on_tree_changed, which fires only when
	# tree.current_scene changes - and under this harness current_scene stays the
	# harness itself, so nothing would be adapted and the audit would measure the
	# RAW .tscn layout while reporting it as the mobile one. The first run of this
	# probe did exactly that: it found a 190x40 button, which is below
	# MobileUIManager's own 100x60 enforced minimum and therefore proof the
	# adaptation had not run.
	if mui != null:
		mui.adapt_scene_for_mobile(inst)
	# Put the scene into the panel state under audit before the settle below, so the 45
	# frames measure the resting layout OF THAT PANEL rather than of the one it opened in.
	var state_call: String = str(state.get("call", ""))
	if state_call != "" and inst.has_method(state_call):
		inst.call(state_call)
	# 45 frames, not 10. UnlockablesScreen builds its grid after two awaits and
	# then runs _animate_grid_reveal(), and the first version of this probe
	# measured mid-tween - visible in sizes like 154.0052 x 147.089. Touch targets
	# have to be judged on the resting layout, because that is the state a finger
	# meets.
	await _frames(45)
	var canvas := _tree().root.get_visible_rect().size
	var phys := Vector2(DisplayServer.window_get_size())
	# The real stretch ratio, read back rather than assumed: with aspect="expand"
	# Godot picks the axis itself, and hardcoding window/1920 would be wrong on
	# any aspect other than 16:9.
	var ratio := 1.0
	if canvas.x > 0.0:
		ratio = phys.x / canvas.x
	res["canvas"] = canvas
	res["ratio"] = ratio
	var dpi := _dpi(d)
	res["dpi"] = dpi

	var targets: Array = []
	_touch_targets(inst, targets)
	res["targets"] = targets.size()

	var view := Rect2(Vector2.ZERO, canvas)
	var rects: Array = []
	for b in targets:
		var ctrl := b as Control
		var sz: Vector2 = ctrl.size * ctrl.get_global_transform_with_canvas().get_scale()
		var dp_x := _dp(sz.x * ratio, dpi)
		var dp_y := _dp(sz.y * ratio, dpi)
		var smaller: float = minf(dp_x, dp_y)
		# Rows the scene deliberately sized itself (MobileUIManager.COMPACT_ROW_META)
		# are counted, named and reported, but kept out of the 48dp tally and out of
		# min_dp - otherwise the whole summary reads as a regression whose cause is a
		# design decision rather than a defect. Settings' accessibility and dev lists
		# carry the marker: at the 48dp floor each two-column toggle measured 126x126
		# and the list ran several screens long, so the rows were shrunk on purpose.
		# They still take part in the clipping and overlap checks below.
		if b.has_meta("mobile_compact_row"):
			res["exempt"] = int(res["exempt"]) + 1
		else:
			if smaller < float(res["min_dp"]):
				res["min_dp"] = smaller
				res["min_name"] = str(inst.get_path_to(ctrl))
				res["smallest_canvas"] = sz
			if smaller < MIN_TOUCH_DP:
				res["too_small"] = int(res["too_small"]) + 1

		var gr := _effective_rect(ctrl)
		if gr.size.x <= 0.0 or gr.size.y <= 0.0:
			# Entirely clipped away by an ancestor: reachable by scrolling, not a
			# defect, and it must not enter the overlap set either.
			res["scrolled_off"] = int(res["scrolled_off"]) + 1
			continue
		if not view.encloses(gr):
			if _in_scroll(ctrl):
				res["scrolled_off"] = int(res["scrolled_off"]) + 1
			else:
				res["clipped"] = int(res["clipped"]) + 1
				res["clip_names"].append("%s%s" % [str(inst.get_path_to(ctrl)), str(gr)])
		rects.append({"r": gr, "n": str(inst.get_path_to(ctrl))})
	# Overlap between two things a finger can press is the accidental-touch case.
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			var a: Rect2 = rects[i]["r"]
			var bb: Rect2 = rects[j]["r"]
			if a.get_area() > 0.0 and bb.get_area() > 0.0 and a.intersects(bb, false):
				res["overlaps"] = int(res["overlaps"]) + 1
				res["overlap_names"].append("%s%s vs %s%s" % [rects[i]["n"], str(a), rects[j]["n"], str(bb)])

	if float(res["min_dp"]) < _worst_dp:
		_worst_dp = float(res["min_dp"])
		_worst_where = "%s / %s / %s" % [res["scene"], d["name"], res["min_name"]]

	inst.queue_free()
	await _frames(4)
	return res


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== MOBILE UI AUDIT: TOUCH TARGETS, CLIPPING, OVERLAP ===")
	if DisplayServer.get_name() == "headless":
		print("  REFUSING: window resizing and Control layout need a real window.")
		_tree().quit(2)
		return

	# OPT-IN SECOND STATE: the same 81 combinations with the "Large Touch Targets"
	# accessibility toggle on. That toggle raises the floor from 48dp to
	# MobileUIManager.LARGE_TOUCH_TARGET_DP, which grows every standalone button by
	# about a third, so the question it has to answer is not whether targets are big
	# enough - they are, by construction - but whether anything CLIPS or OVERLAPS once
	# they are. Written into the in-memory settings dictionary rather than through
	# SaveManager.set_setting(), which would persist it to waterwise_settings.json and
	# leave the player's own preference flipped by a test run.
	var large_targets: bool = "--large-targets" in OS.get_cmdline_user_args()
	if large_targets:
		var save_mgr := get_node_or_null("/root/SaveManager")
		if save_mgr and save_mgr.get("settings") != null:
			save_mgr.settings["large_touch_targets"] = true
		var acc_mgr := get_node_or_null("/root/AccessibilityManager")
		if acc_mgr:
			acc_mgr.large_touch_targets = true
	print("  large touch targets    : %s" % ("ON" if large_targets \
		else "off  (pass -- --large-targets to audit the other state)"))

	# Force the mobile code path on desktop. Without this, is_mobile stays false,
	# _resolve_button_min_size() returns the desktop 44x44 and
	# adapt_scene_for_mobile() returns immediately - so the audit would measure
	# the DESKTOP layout and report it as the mobile one.
	var mui := get_node_or_null("/root/MobileUIManager")
	if mui == null:
		print("  FAIL: MobileUIManager autoload missing")
		_tree().quit(1)
		return
	mui.debug_mobile_mode = true
	if mui.has_method("_detect_platform"):
		mui._detect_platform()
	print("  MobileUIManager.is_mobile forced -> %s" % mui.is_mobile)
	print("  enforced button minimum : %s canvas units (mobile_button_min_size)"
		% mui.mobile_button_min_size)
	print("  declared touch minimum  : %s canvas units (mobile_touch_target_min_size)"
		% mui.mobile_touch_target_min_size)
	print("  standard applied here   : %.0fdp on both axes" % MIN_TOUCH_DP)
	print("")

	for d in DEVICES:
		DisplayServer.window_set_size(Vector2i(int(d["w"]), int(d["h"])))
		await _frames(8)
		if mui.has_method("_detect_platform"):
			mui._detect_platform()
		# Inject this device profile's dpi so the PRODUCTION conversion in
		# MobileUIManager._dp_to_canvas_units is what gets exercised, rather than
		# this harness computing its own parallel answer.
		mui.debug_dpi_override = _dpi(d)
		# Inject this profile's hardware cutout, in device pixels, so the layout under
		# test carries real safe-area insets. adapt_scene_for_mobile() folds
		# safe_area_margins into the scene's safe-area target via
		# LayoutManager.apply_safe_area_margins, so an empty override does not merely
		# skip a check - it measures a different layout from the one a cutout phone
		# shows. Devices with no "cut" key keep the DisplayServer's answer, which on
		# desktop is no cutout, matching a legacy phone.
		mui.debug_safe_area_px_override = d.get("cut", {})
		mui.invalidate_button_min_size_cache()
		if mui.has_method("_calculate_safe_area"):
			mui._calculate_safe_area()
		var actual := DisplayServer.window_get_size()
		var canvas := _tree().root.get_visible_rect().size
		print("  %-12s requested %dx%d, window %dx%d, canvas %.0fx%.0f, %.0f dpi, density %.2f"
			% [d["name"], d["w"], d["h"], actual.x, actual.y,
				canvas.x, canvas.y, _dpi(d), _dpi(d) / 160.0])
		# What a 48dp target costs in canvas units on THIS device. This is the
		# number MobileUIManager's minimum would have to reach, and it is derived
		# rather than guessed: canvas_units = 48dp * (dpi/160) / stretch_ratio.
		var rr := 1.0
		if canvas.x > 0.0:
			rr = float(actual.x) / canvas.x
		var need := MIN_TOUCH_DP * (_dpi(d) / 160.0) / rr
		print("               stretch ratio %.3f -> a 48dp target needs %.0f canvas units" % [rr, need])
		print("               safe-area insets applied (canvas u): %s" % str(mui.get_safe_area_margins()))
		for path in SCENES:
			if not ResourceLoader.exists(path):
				continue
			for state in _states_for(path):
				var r: Dictionary = await _audit_scene(path, d, mui, state)
				_rows.append(r)
				var flag := "ok  "
				if int(r["too_small"]) > 0 or int(r["clipped"]) > 0:
					flag = "FAIL"
				print("      %s %-29s targets %2d  below-48dp %2d  exempt %2d  clipped %2d  scrolled-off %2d  overlap %2d  smallest %.0fx%.0f units = %.1fdp (%s)"
					% [flag, r["scene"], r["targets"], r["too_small"], r["exempt"],
						r["clipped"], r["scrolled_off"], r["overlaps"],
						r["smallest_canvas"].x, r["smallest_canvas"].y,
						r["min_dp"], r["min_name"]])
				if int(r["clipped"]) > 0:
					print("           clipped: %s (canvas %s)" % [str(r["clip_names"]).substr(0, 220), str(canvas)])
				if int(r["overlaps"]) > 0:
					print("           overlap: %s" % str(r["overlap_names"]).substr(0, 300))

	var tot_small := 0
	var tot_clip := 0
	var tot_over := 0
	var tot_targets := 0
	var tot_exempt := 0
	for r in _rows:
		tot_small += int(r["too_small"])
		tot_clip += int(r["clipped"])
		tot_over += int(r["overlaps"])
		tot_targets += int(r["targets"])
		tot_exempt += int(r["exempt"])
	print("  -- SUMMARY --")
	print("  %d target measurements across %d screen-state/device combinations"
		% [tot_targets, _rows.size()])
	print("  below the 48dp minimum : %d" % tot_small)
	print("  exempt compact rows    : %d (scene-sized list rows, not judged against 48dp)"
		% tot_exempt)
	print("  clipped by the viewport: %d" % tot_clip)
	print("  overlapping pairs      : %d" % tot_over)
	print("  worst target anywhere  : %.1fdp at %s" % [_worst_dp, _worst_where])
	print("  frames that had to clear a background pause: %d" % _unpaused_frames)
	print("")
	_tree().quit(0)
