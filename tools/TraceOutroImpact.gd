extends Node
## Per-frame trace of ONE outro clip's impact stack.
##
## VerifyOutroImpact measured BucketBrigadeLoseOutro as the single clip whose
## camera punch never moved (peak zoom deviation 0.0000) while its flash reached
## only 0.33 of the authored 0.55 and the clip ended at 1.88 s instead of ~2.03 s.
## The clip's _on_impact() calls super._on_impact() on its first line, so the
## punch tween is definitely created. This trace prints every frame so the shape
## of the failure is visible instead of inferred.

const CLIP: String = "res://scenes/ui/cutscenes/beats/BucketBrigadeLoseOutro.tscn"
const TIMEOUT: float = 6.0

func _ready() -> void:
	await get_tree().process_frame
	var clip: Node = (load(CLIP) as PackedScene).instantiate()
	var done := [false]
	clip.connect("outro_finished", func() -> void: done[0] = true)
	add_child(clip)
	await get_tree().process_frame

	# Beat schedule, as the clip itself computes it.
	for m in ["_setup_sec", "_impact_sec", "_payoff_sec", "_snap_sec"]:
		if clip.has_method(m):
			print("  %s = %s" % [m, clip.call(m)])
	var cam = clip.get("camera")
	print("  camera=%s zoom=%s  flash=%s" % [
		cam, (cam.zoom if cam is Camera2D else "n/a"), clip.get("flash_rect")])

	clip.call("play_lose")
	var t := 0.0
	var prev_flash := -1.0
	var prev_zoom := -1.0
	while t < TIMEOUT and not done[0] and is_instance_valid(clip):
		await get_tree().process_frame
		t += get_process_delta_time()
		var fr = clip.get("flash_rect")
		var f: float = fr.color.a if fr is ColorRect else -1.0
		var c = clip.get("camera")
		var z: float = c.zoom.x if c is Camera2D else -1.0
		# Only print when something actually changed, so the log stays readable.
		if absf(f - prev_flash) > 0.001 or absf(z - prev_zoom) > 0.0005:
			var tweens := 0
			if is_instance_valid(clip):
				tweens = clip.get_tree().get_processed_tweens().size() if clip.get_tree() else 0
			print("  t=%.3f flash=%.3f zoom=%.4f tweens=%d" % [t, f, z, tweens])
			prev_flash = f
			prev_zoom = z
	print("  END t=%.3f finished=%s valid=%s" % [t, done[0], is_instance_valid(clip)])
	if is_instance_valid(clip):
		clip.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
