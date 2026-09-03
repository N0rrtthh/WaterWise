extends Node

## Safe-area / display-cutout audit.
##
## WHY A SEAM IS NEEDED
##   Desktop and headless DisplayServers report no cutout, so the whole safe-area
##   path is unreachable off a real phone. MobileUIManager.debug_safe_area_px_override
##   injects a cutout in DEVICE PIXELS - the same units and shape DisplayServer
##   would hand SafeAreaInfo - so the production conversion and the production
##   layout pass are what get exercised here, not a parallel calculation.
##
## WHAT IT CHECKS
##   1. The px -> canvas-unit conversion. safe_area_margins is spent as Control
##      offsets, which are canvas units, while DisplayServer reports device pixels.
##      The two agree only at stretch ratio 1. Expected canvas margin is
##      px / ratio, mirrored across each opposing pair (see the rotation-invariance
##      note in MobileUIManager._calculate_safe_area), plus the authored
##      mobile_safe_area_margin on any side that ends up nonzero.
##   2. No interactive control's touchable rect intrudes into the unsafe band.
##      That is the actual product requirement: a button under a camera cutout
##      cannot be pressed.
##
## The cutout profiles are real landscape geometries: a punch-hole camera on the
## left edge (the long edge becomes the left in sensor_landscape), and an Android
## gesture-navigation bar along the bottom.
##
## Usage (WINDOWED - the stretch ratio is the whole point):
##   godot --path . res://tools/ProbeSafeArea.tscn

const MARGIN_TOLERANCE: float = 0.51

const PROFILES: Array = [
	{"name": "WVGA 854x480",  "w": 854,  "h": 480,  "cut": {"left": 40.0, "bottom": 24.0, "top": 0.0, "right": 0.0}},
	{"name": "HD 1280x720",   "w": 1280, "h": 720,  "cut": {"left": 60.0, "bottom": 36.0, "top": 0.0, "right": 0.0}},
	{"name": "FHD 1920x1080", "w": 1920, "h": 1080, "cut": {"left": 88.0, "bottom": 48.0, "top": 0.0, "right": 0.0}},
	{"name": "QHD 2560x1440", "w": 2560, "h": 1440, "cut": {"left": 118.0, "bottom": 64.0, "top": 0.0, "right": 0.0}},
]

const SCENES: Array = [
	"res://scenes/ui/InitialScreen.tscn",
	"res://scenes/ui/MainMenu.tscn",
	"res://scenes/ui/Settings.tscn",
	"res://scenes/ui/MultiplayerMenu.tscn",
]

var _fails: int = 0
var _intrusions: int = 0


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _check(label: String, got: Variant, want: Variant) -> void:
	var ok: bool = str(got) == str(want)
	if not ok:
		_fails += 1
	print("      %s %-46s got=%s expected=%s" % ["PASS" if ok else "FAIL", label, str(got), str(want)])


func _close(label: String, got: float, want: float) -> void:
	var ok: bool = absf(got - want) <= MARGIN_TOLERANCE
	if not ok:
		_fails += 1
	print("      %s %-46s got=%.2f expected=%.2f" % ["PASS" if ok else "FAIL", label, got, want])


## Same clip-aware reachable rect the touch-target audit uses: Godot's hit test
## skips a subtree whose clipping ancestor excludes the point, so a raw rect that
## pokes into the cutout band is only a defect if it is actually touchable there.
func _effective_rect(ctrl: Control) -> Rect2:
	var r := ctrl.get_global_rect()
	var p := ctrl.get_parent()
	while p != null:
		if p is Control and (p as Control).clip_contents:
			r = r.intersection((p as Control).get_global_rect())
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				return Rect2()
		p = p.get_parent()
	return r


func _targets(root: Node, out: Array) -> void:
	if root is BaseButton:
		var b := root as BaseButton
		if b.is_visible_in_tree() and not b.disabled and b.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			out.append(b)
	for c in root.get_children():
		_targets(c, out)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== SAFE-AREA / DISPLAY-CUTOUT AUDIT ===")
	if DisplayServer.get_name() == "headless":
		print("  REFUSING: the stretch ratio needs a real window.")
		get_tree().quit(2)
		return
	var mui := get_node_or_null("/root/MobileUIManager")
	if mui == null:
		print("  FAIL: MobileUIManager missing")
		get_tree().quit(1)
		return
	mui.debug_mobile_mode = true
	if mui.has_method("_detect_platform"):
		mui._detect_platform()
	print("  authored extra margin on cut sides: %s canvas units (mobile_safe_area_margin)"
		% mui.mobile_safe_area_margin)
	print("")

	for prof in PROFILES:
		DisplayServer.window_set_size(Vector2i(int(prof["w"]), int(prof["h"])))
		await _frames(8)
		if mui.has_method("_detect_platform"):
			mui._detect_platform()
		mui.invalidate_button_min_size_cache()
		var canvas := get_viewport().get_visible_rect().size
		var win := DisplayServer.window_get_size()
		var ratio := float(win.x) / canvas.x if canvas.x > 0.0 else 1.0

		var cut: Dictionary = prof["cut"]
		mui.debug_safe_area_px_override = cut
		mui._calculate_safe_area()
		var got: Dictionary = mui.get_safe_area_margins()

		print("  -- %s: canvas %.0fx%.0f, ratio %.3f --" % [prof["name"], canvas.x, canvas.y, ratio])
		print("      injected cutout (device px): left %.0f bottom %.0f"
			% [cut["left"], cut["bottom"]])
		print("      resolved margins (canvas u): %s" % str(got))
		# Mirroring: with allow_reverse_landscape the OS may flip the device 180 degrees
		# without changing the viewport size, so MobileUIManager reserves the larger of
		# each opposing pair on BOTH edges. The expected value is therefore the PAIR
		# maximum, not this side's own injected cutout.
		var opposite := {"left": "right", "right": "left", "top": "bottom", "bottom": "top"}
		for side in ["left", "bottom", "top", "right"]:
			var px := float(cut[side])
			if mui.allow_reverse_landscape:
				px = maxf(px, float(cut[opposite[side]]))
			var want: float = px / ratio
			if px > 0.0:
				want += float(mui.mobile_safe_area_margin)
			_close("%s margin converted to canvas units" % side, float(got[side]), want)
		# The unsafe bands, in canvas units, straight from the injected pixels.
		var unsafe: Array = []
		if float(cut["left"]) > 0.0:
			unsafe.append({"n": "left cutout", "r": Rect2(0.0, 0.0, float(cut["left"]) / ratio, canvas.y)})
		if float(cut["bottom"]) > 0.0:
			unsafe.append({"n": "bottom nav bar",
				"r": Rect2(0.0, canvas.y - float(cut["bottom"]) / ratio, canvas.x, float(cut["bottom"]) / ratio)})

		for path in SCENES:
			if not ResourceLoader.exists(path):
				continue
			var inst: Node = (load(path) as PackedScene).instantiate()
			get_tree().root.add_child(inst)
			mui.adapt_scene_for_mobile(inst)
			await _frames(45)
			var targets: Array = []
			_targets(inst, targets)
			var hits: Array = []
			for b in targets:
				var r := _effective_rect(b as Control)
				if r.size.x <= 0.0 or r.size.y <= 0.0:
					continue
				for u in unsafe:
					if r.intersects(u["r"], false):
						hits.append("%s in %s" % [str(inst.get_path_to(b)), u["n"]])
			_intrusions += hits.size()
			var flag := "ok  " if hits.is_empty() else "FAIL"
			print("      %s %-20s %2d targets, %d in an unsafe band%s"
				% [flag, path.get_file().get_basename(), targets.size(), hits.size(),
					("" if hits.is_empty() else ": " + str(hits).substr(0, 170))])
			inst.queue_free()
			await _frames(4)

	mui.debug_safe_area_px_override = {}
	mui._calculate_safe_area()
	print("  -- SUMMARY --")
	print("  conversion failures      : %d" % _fails)
	print("  controls in unsafe bands : %d" % _intrusions)
	print("")
	get_tree().quit(0)
