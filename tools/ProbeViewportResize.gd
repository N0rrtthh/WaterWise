extends Node

## Can a headless run be told to pretend it is a 2560x1080 phone?
##
## Everything in the fixed-unit sweep has to be measured at more than one aspect ratio, and the
## headless display driver hands out one size of its own choosing (1920x1920 here). This probe
## asks whether writing get_window().size re-runs the stretch computation so get_viewport_rect()
## follows — if it does, one process can sample every device shape; if it does not, each shape
## needs its own process and --resolution.

const TARGETS: Array = [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1920, 1440)]


func _ready() -> void:
	print("\n=== ProbeViewportResize ===")
	print("  driver: %s" % DisplayServer.get_name())
	await get_tree().process_frame
	print("  as launched: window=%s viewport=%s scale=%.3f" % [
		str(get_window().size), str(get_viewport().get_visible_rect().size), get_window().content_scale_factor])
	for t in TARGETS:
		get_window().size = t as Vector2i
		for _i in range(4):
			await get_tree().process_frame
		print("  asked %s -> window=%s viewport=%s scale=%.3f  visible=%s" % [
			str(t), str(get_window().size), str(get_viewport().get_visible_rect().size),
			get_window().content_scale_factor, str(get_viewport().get_visible_rect())])
	get_tree().quit(0)
