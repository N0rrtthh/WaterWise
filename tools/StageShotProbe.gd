extends Node

## Renders one CartoonStage clip and writes PNG frames to _build/ so the clip can
## be eyeballed without launching the game. Needs a real (non-headless) renderer.

const SHOTS: Array[float] = [0.15, 0.6, 1.4, 2.6, 3.6]

func _ready() -> void:
	var scenario: String = "CatchTheRain"
	var kind: int = CartoonStage.Kind.CAUSE
	var tag: String = "cause"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenario="):
			scenario = arg.substr("--scenario=".length())
		elif arg == "--win":
			kind = CartoonStage.Kind.EFFECT_WIN
			tag = "win"
		elif arg == "--lose":
			kind = CartoonStage.Kind.EFFECT_LOSE
			tag = "lose"

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var stage := CartoonStage.new()
	stage.configure(kind, scenario, {"speed": 1.0})
	root.add_child(stage)
	stage.play_cutscene()

	DirAccess.make_dir_recursive_absolute("res://_build")
	var previous: float = 0.0
	for i in range(SHOTS.size()):
		await get_tree().create_timer(SHOTS[i] - previous).timeout
		previous = SHOTS[i]
		var img := get_viewport().get_texture().get_image()
		var path := "res://_build/stage_%s_%d.png" % [tag, i]
		img.save_png(path)
		print("wrote ", path, "  size=", img.get_size())
	get_tree().quit(0)
