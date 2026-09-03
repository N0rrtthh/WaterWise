extends Node

## Orientation-contract probe.
##
## project.godot declares display/window/handheld/orientation="sensor_landscape",
## but MobileUIManager also calls DisplayServer.screen_set_orientation() at
## _ready() and again on every viewport resize, with two hardcoded int constants.
## Hardcoded engine enum values are exactly the kind of thing that silently rots
## across engine versions, and on desktop/headless the call is gated out - so the
## values can never be wrong in a way a desktop run would notice.
##
## This prints the real enum, so the constants are checked against the engine
## rather than against memory.
##
## Usage: godot --path . res://tools/ProbeOrientation.tscn


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("")
	print("=== DisplayServer.ScreenOrientation, as the engine defines it ===")
	var names := [
		"SCREEN_LANDSCAPE", "SCREEN_PORTRAIT",
		"SCREEN_REVERSE_LANDSCAPE", "SCREEN_REVERSE_PORTRAIT",
		"SCREEN_SENSOR_LANDSCAPE", "SCREEN_SENSOR_PORTRAIT", "SCREEN_SENSOR",
	]
	var engine := {}
	for n in names:
		if n in DisplayServer:
			engine[n] = DisplayServer[n]
			print("  %-26s = %d" % [n, DisplayServer[n]])
		else:
			print("  %-26s = <absent>" % n)

	print("")
	print("=== project.godot vs MobileUIManager ===")
	var declared: String = str(ProjectSettings.get_setting(
		"display/window/handheld/orientation", "<unset>"))
	print("  project.godot handheld/orientation      : \"%s\"" % declared)
	print("  DisplayServer.has_method(screen_set_orientation): %s"
		% DisplayServer.has_method("screen_set_orientation"))

	var mui := get_node_or_null("/root/MobileUIManager")
	if mui == null:
		print("  FAIL: MobileUIManager autoload missing")
		get_tree().quit(1)
		return

	var land: int = mui.SCREEN_LANDSCAPE_VALUE
	var sensor_land: int = mui.SCREEN_SENSOR_LANDSCAPE_VALUE
	print("  MobileUIManager.SCREEN_LANDSCAPE_VALUE        : %d" % land)
	print("  MobileUIManager.SCREEN_SENSOR_LANDSCAPE_VALUE : %d" % sensor_land)
	print("  enforce_landscape_only=%s  allow_reverse_landscape=%s"
		% [mui.enforce_landscape_only, mui.allow_reverse_landscape])

	var fails := 0
	if engine.has("SCREEN_LANDSCAPE") and land != int(engine["SCREEN_LANDSCAPE"]):
		print("  FAIL: SCREEN_LANDSCAPE_VALUE is %d, engine says %d"
			% [land, int(engine["SCREEN_LANDSCAPE"])])
		fails += 1
	if engine.has("SCREEN_SENSOR_LANDSCAPE") and sensor_land != int(engine["SCREEN_SENSOR_LANDSCAPE"]):
		# What the wrong number actually MEANS, so the consequence is stated and
		# not just the mismatch.
		var meant := "<out of range>"
		for n in names:
			if engine.has(n) and int(engine[n]) == sensor_land:
				meant = n
		print("  FAIL: SCREEN_SENSOR_LANDSCAPE_VALUE is %d, engine says %d"
			% [sensor_land, int(engine["SCREEN_SENSOR_LANDSCAPE"])])
		print("        %d is actually %s" % [sensor_land, meant])
		fails += 1

	# The declared project setting and the value the code would push must agree,
	# otherwise the runtime call silently contradicts project.godot.
	var declared_to_enum := {
		"landscape": "SCREEN_LANDSCAPE",
		"portrait": "SCREEN_PORTRAIT",
		"reverse_landscape": "SCREEN_REVERSE_LANDSCAPE",
		"reverse_portrait": "SCREEN_REVERSE_PORTRAIT",
		"sensor_landscape": "SCREEN_SENSOR_LANDSCAPE",
		"sensor_portrait": "SCREEN_SENSOR_PORTRAIT",
		"sensor": "SCREEN_SENSOR",
	}
	if declared_to_enum.has(declared) and engine.has(declared_to_enum[declared]):
		var want: int = int(engine[declared_to_enum[declared]])
		var pushed: int = sensor_land if mui.allow_reverse_landscape else land
		print("")
		print("  project.godot asks for %s (=%d); code would push %d"
			% [declared_to_enum[declared], want, pushed])
		if pushed != want:
			print("  MISMATCH: the runtime call overrides the project setting.")
			fails += 1

	print("")
	print("  RESULT: %d failed" % fails)
	get_tree().quit(0)
