extends Node

## Temporary probe: reproduces the MiniGameIntroBridge node layout and reports
## the resolved rects of CartoonStage's Control children.

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var stage := CartoonStage.new()
	stage.configure(CartoonStage.Kind.CAUSE, "CatchTheRain", {"speed": 1.0})
	root.add_child(stage)
	stage.play_cutscene()

	await get_tree().process_frame
	await get_tree().process_frame

	print("viewport      = ", get_viewport().get_visible_rect().size)
	print("root.size     = ", root.size)
	print("stage.size    = ", stage.size)
	print("backdrop.size = ", stage.backdrop.size)
	print("panel.pos     = ", stage.caption_panel.position,
		"  panel.size = ", stage.caption_panel.size)
	print("label.size    = ", stage.caption_label.size)
	print("content_scale = ", stage._content_scale)
	print("ground_y      = ", stage._ground_y())
	print("actor.pos     = ", stage.actor.position, "  scale = ", stage.actor.scale)
	for child in stage._props.get_children():
		print("prop ", child.name, " pos = ", (child as Node2D).position,
			"  scale = ", (child as Node2D).scale)
	get_tree().quit(0)
