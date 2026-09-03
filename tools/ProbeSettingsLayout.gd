extends Node

## Why the Settings checkbox slivers stay touchable under the Back button.
##
## The design intent in Settings.gd is already correct: _reparent_action_buttons()
## moves Back/Exit out of the scroll area into a bottom-anchored bar, and
## _update_action_button_bar_layout() shrinks CenterContainer by
## (bottom_margin + row_height + gap) so the card ends above that bar. Yet the
## audit still finds the scroll viewport reaching past the bar's top edge, so one
## of the numbers in that chain is wrong. This prints the whole chain so the
## culprit is identified rather than guessed at.
##
## Usage (WINDOWED): godot --path . res://tools/ProbeSettingsLayout.tscn

const DEVICES: Array = [
	{"name": "HD 5.0in", "w": 1280, "h": 720, "diag": 5.0},
	{"name": "FHD 6.0in", "w": 1920, "h": 1080, "diag": 6.0},
]


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _frames(n: int) -> void:
	for _i in range(n):
		await _tree().process_frame


func _rect(inst: Node, path: String) -> String:
	var c := inst.get_node_or_null(path) as Control
	if c == null:
		return "%-18s MISSING" % path.get_file()
	var r := c.get_global_rect()
	return "%-18s y %7.1f .. %7.1f  h %6.1f  min %6.1f  clip %s" % [
		path.get_file(), r.position.y, r.end.y, r.size.y,
		c.get_combined_minimum_size().y, str(c.clip_contents),
	]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== SETTINGS LAYOUT CHAIN ===")
	var mui := get_node_or_null("/root/MobileUIManager")
	mui.debug_mobile_mode = true
	mui._detect_platform()

	for d in DEVICES:
		DisplayServer.window_set_size(Vector2i(int(d["w"]), int(d["h"])))
		await _frames(8)
		mui._detect_platform()
		var w := float(d["w"])
		var h := float(d["h"])
		mui.debug_dpi_override = sqrt(w * w + h * h) / float(d["diag"])
		mui.invalidate_button_min_size_cache()
		mui._calculate_safe_area()
		var inst: Node = (load("res://scenes/ui/Settings.tscn") as PackedScene).instantiate()
		_tree().root.add_child(inst)
		mui.adapt_scene_for_mobile(inst)
		await _frames(45)
		var canvas := _tree().root.get_visible_rect().size
		print("  %s  canvas %.0fx%.0f  touch floor %s" % [
			d["name"], canvas.x, canvas.y, str(mui._resolve_button_min_size()),
		])
		for p in [
			"CenterContainer",
			"CenterContainer/OuterVBox",
			"CenterContainer/OuterVBox/PanelCard",
			"CenterContainer/OuterVBox/PanelCard/MarginContainer",
			"CenterContainer/OuterVBox/PanelCard/MarginContainer/ScrollContainer",
			"ActionButtonsSafeArea",
			"ActionButtonsSafeArea/ButtonColumn/ButtonRow",
			"ActionButtonsSafeArea/ButtonColumn/ButtonRow/BackButton",
		]:
			print("      %s" % _rect(inst, p))
		var cc := inst.get_node_or_null("CenterContainer") as Control
		var br := inst.get_node_or_null("ActionButtonsSafeArea/ButtonColumn/ButtonRow") as Control
		if cc != null and br != null:
			print("      reserve check: CenterContainer.offset_bottom %.1f, ButtonRow min %.1f, gap %.1f" % [
				cc.offset_bottom, br.get_combined_minimum_size().y, inst._get_action_bar_gap(),
			])
		inst.queue_free()
		await _frames(4)
	print("")
	_tree().quit(0)
