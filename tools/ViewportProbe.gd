extends Node

## Diagnostic probe: reports what the window/viewport actually measure at runtime.
##
## Exists because the soak logs report "Viewport: 1920x1920" and
## "Scale factor: 1.00x1.78" while project.godot declares a 1920x1080 design
## resolution. This prints every input to that calculation so the mismatch can
## be attributed to a real scaling bug or to the headless display driver.
## Run as a scene (tools/ViewportProbe.tscn), not with --script.

func _ready() -> void:
	# Let the window manager settle before measuring.
	await get_tree().process_frame
	await get_tree().process_frame

	var vp := get_viewport()
	print("=== VIEWPORT PROBE ===")
	print("headless_driver: ", DisplayServer.get_name())
	print("screen_count: ", DisplayServer.get_screen_count())
	print("screen_size(0): ", DisplayServer.screen_get_size(0))
	print("window_size: ", DisplayServer.window_get_size())
	print("project width x height: %s x %s" % [
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"),
	])
	print("stretch_mode: ", ProjectSettings.get_setting("display/window/stretch/mode"))
	print("stretch_aspect: ", ProjectSettings.get_setting("display/window/stretch/aspect"))
	print("viewport.size: ", vp.size)
	print("viewport.get_visible_rect().size: ", vp.get_visible_rect().size)
	print("content_scale_size: ", get_window().content_scale_size)
	print("content_scale_mode: ", get_window().content_scale_mode)
	print("content_scale_aspect: ", get_window().content_scale_aspect)
	print("content_scale_factor: ", get_window().content_scale_factor)

	var scaler := get_node_or_null("/root/ScreenScaler")
	if scaler:
		print("ScreenScaler.screen_size: ", scaler.screen_size)
		print("ScreenScaler.screen_scale: ", scaler.screen_scale)
	var mobile := get_node_or_null("/root/MobileUIManager")
	if mobile:
		print("MobileUIManager viewport: %sx%s" % [
			mobile.viewport_width, mobile.viewport_height
		])
	print("=== END PROBE ===")
	get_tree().quit(0)
