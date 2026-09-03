extends Node

## Whether UnlockablesScreen's grid cards really miss the 48dp touch minimum.
##
## AuditMobileUI once reported them at 38.5dp on a 21:9 phone and 38.8dp on a 4:3
## tablet while the other five profiles passed. Three things could produce that:
##   (a) the mobile minimum never reaching buttons built after the scene was adapted,
##   (b) a container squashing a minimum that WAS applied, or
##   (c) an ANCESTOR TRANSFORM shrinking a button whose own size is correct.
## They need different fixes, so this prints the numbers that separate them: the
## resolved minimum at adapt time, each card button's custom_minimum_size, the size it
## settled at, and the ancestor scale multiplying it.
##
## It was (c), and not a product defect at all. UnlockablesScreen reveals MainPanel
## from scale 0.85 and each card from 0.94; 0.85 * 0.94 = 0.799, which is exactly the
## ratio between the failing sizes and the compliant ones. The audit had measured a
## FROZEN reveal, because MobileUIManager pauses the whole SceneTree when the window
## loses focus and a paused tree freezes every Tween. tools/ProbePauseArtifact.tscn
## demonstrates that end to end; AuditMobileUI now clears the pause, and the sweep
## reports 0 below 48dp.
##
## The first version of this probe measured bare ctrl.size and so reported ~48dp where
## the audit reported 38.5dp - it was contradicting the audit by leaving out the very
## factor that explained it. It multiplies by the ancestor scale now, which is what a
## finger actually meets.
##
## Usage (WINDOWED): godot --path . res://tools/ProbeUnlockGrid.tscn

const MIN_TOUCH_DP: float = 48.0

const PROFILES: Array = [
	{"name": "WVGA 4.5in", "w": 854, "h": 480, "diag": 4.5},
	{"name": "HD 5.0in", "w": 1280, "h": 720, "diag": 5.0},
	{"name": "FHD 6.0in", "w": 1920, "h": 1080, "diag": 6.0,
		"cut": {"left": 88.0, "right": 0.0, "top": 0.0, "bottom": 48.0}},
	{"name": "21:9 6.7in", "w": 2560, "h": 1080, "diag": 6.7,
		"cut": {"left": 110.0, "right": 0.0, "top": 0.0, "bottom": 44.0}},
	{"name": "4:3 tab 9.7in", "w": 2048, "h": 1536, "diag": 9.7},
]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Frames with the tree kept running: MobileUIManager pauses the whole SceneTree when
## this window loses focus, and a paused tree freezes the reveal tweens whose scale
## this probe is measuring. Without this the probe would reproduce the very artefact
## its header explains.
func _frames(n: int) -> void:
	for _i in range(n):
		if _tree().paused:
			_tree().paused = false
		await _tree().process_frame


func _dpi(d: Dictionary) -> float:
	var w := float(d["w"])
	var h := float(d["h"])
	return sqrt(w * w + h * h) / float(d["diag"])


func _buttons(root: Node, out: Array) -> void:
	if root is BaseButton:
		var b := root as BaseButton
		if b.is_visible_in_tree() and not b.disabled and b.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			out.append(b)
	for c in root.get_children():
		_buttons(c, out)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  REFUSING: needs a real window.")
		_tree().quit(2)
		return
	var mui := get_node_or_null("/root/MobileUIManager")
	if mui == null:
		print("  FAIL: MobileUIManager missing")
		_tree().quit(1)
		return
	mui.debug_mobile_mode = true
	mui._detect_platform()

	print("")
	print("=== UnlockablesScreen grid cards: minimum applied vs size settled ===")
	for d in PROFILES:
		DisplayServer.window_set_size(Vector2i(int(d["w"]), int(d["h"])))
		await _frames(8)
		mui._detect_platform()
		mui.debug_dpi_override = _dpi(d)
		mui.debug_safe_area_px_override = d.get("cut", {})
		mui.invalidate_button_min_size_cache()
		mui._calculate_safe_area()

		var canvas := _tree().root.get_visible_rect().size
		var ratio: float = float(DisplayServer.window_get_size().x) / canvas.x
		var resolved: Vector2 = mui._resolve_button_min_size()
		var need: float = MIN_TOUCH_DP * (_dpi(d) / 160.0) / ratio
		print("")
		print("  -- %s: canvas %.0fx%.0f, ratio %.3f, %.0f dpi --"
			% [d["name"], canvas.x, canvas.y, ratio, _dpi(d)])
		print("     48dp needs %.1f units; _resolve_button_min_size() = %s" % [need, str(resolved)])

		var inst: Node = (load("res://scenes/ui/UnlockablesScreen.tscn") as PackedScene).instantiate()
		_tree().root.add_child(inst)
		mui.adapt_scene_for_mobile(inst)
		await _frames(45)

		var panel := inst.get_node_or_null("MainPanel") as Control
		var sc: ScrollContainer = null
		var gc: GridContainer = null
		for n in inst.find_children("*", "ScrollContainer", true, false):
			sc = n as ScrollContainer
			break
		for n in inst.find_children("*", "GridContainer", true, false):
			gc = n as GridContainer
			break
		print("     MainPanel %s custom_min %s | ScrollContainer %s | grid columns %d"
			% [str(panel.size) if panel else "<none>",
				str(panel.custom_minimum_size) if panel else "-",
				str(sc.size) if sc else "<none>",
				gc.columns if gc else -1])
		print("     safe-area insets: %s" % str(mui.get_safe_area_margins()))
		var btns: Array = []
		_buttons(inst, btns)
		# Grid cards only: everything under the GridContainer. The panel chrome
		# (Back, tab buttons) is adapted correctly and would just add noise.
		var shown := 0
		var worst_dp: float = 99999.0
		var worst_scale: float = 1.0
		for b in btns:
			var ctrl := b as Control
			var p := ctrl.get_parent()
			var in_grid := false
			while p != null:
				if p is GridContainer:
					in_grid = true
					break
				p = p.get_parent()
			if not in_grid:
				continue
			shown += 1
			# Track the worst reachable card on this profile so the verdict states a
			# measurement rather than restating the hypothesis it was written under.
			var wanc := ctrl.get_global_transform().get_scale()
			var wreach: Vector2 = ctrl.size * wanc
			var wdp: float = minf(wreach.x, wreach.y) * ratio / (_dpi(d) / 160.0)
			if wdp < worst_dp:
				worst_dp = wdp
				worst_scale = wanc.x
			if shown > 3:
				continue
			# Reachable size, not authored size: an ancestor transform is part of what a
			# finger meets, and leaving it out is what made this probe contradict
			# AuditMobileUI. Same measurement the audit makes.
			var anc := ctrl.get_global_transform().get_scale()
			var reach: Vector2 = ctrl.size * anc
			var dp_x: float = reach.x * ratio / (_dpi(d) / 160.0)
			var dp_y: float = reach.y * ratio / (_dpi(d) / 160.0)
			print("     card btn '%s'  own %.0fx%.0f  x ancestor scale %.3f  = reachable %.0fx%.0f  custom_min %s  -> %.1f x %.1f dp"
				% [ctrl.name, ctrl.size.x, ctrl.size.y, anc.x, reach.x, reach.y,
					str(ctrl.custom_minimum_size), dp_x, dp_y])
		print("     grid buttons found: %d (first 3 shown)" % shown)
		# Three outcomes, distinguished rather than assumed. custom_minimum_size below
		# the resolved minimum means adaptation never reached the card; an ancestor
		# scale below 1.0 means a reveal tween was still running (or frozen) when the
		# measurement was taken; anything else that falls short is a container squash.
		var verdict := "OK - every grid card reaches 48dp at rest"
		if shown > 0 and _any_below(btns, resolved):
			verdict = "minimum NEVER applied - cards built after adaptation"
		elif worst_scale < 0.999:
			verdict = "MEASURED MID-ANIMATION - ancestor scale %.3f, not a layout defect" % worst_scale
		elif worst_dp < MIN_TOUCH_DP:
			verdict = "container squash - %.1fdp at rest with the minimum applied" % worst_dp
		print("     worst reachable card: %.1fdp (ancestor scale %.3f)" % [worst_dp, worst_scale])
		print("     verdict: %s" % verdict)
		inst.queue_free()
		await _frames(4)

	print("")
	_tree().quit(0)


## True when a grid card button's custom_minimum_size is still under the resolved
## minimum on BOTH axes, which is the signature of never having been adapted.
func _any_below(btns: Array, resolved: Vector2) -> bool:
	for b in btns:
		var ctrl := b as Control
		var p := ctrl.get_parent()
		while p != null:
			if p is GridContainer:
				if ctrl.custom_minimum_size.x < resolved.x and ctrl.custom_minimum_size.y < resolved.y:
					return true
				break
			p = p.get_parent()
	return false
