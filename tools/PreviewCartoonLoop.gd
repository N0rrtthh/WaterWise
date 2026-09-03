extends Node

## Manual visual check for the full DWTD-style loop, without needing to play
## a whole minigame round.
##
## Run:
##   godot --path . res://tools/PreviewCartoonLoop.tscn
##
## Plays: cause → (simulated round) → win → lose, for one scenario.
## Change SCENARIO to preview a different minigame's clips.

const SCENARIO: String = "CatchTheRain"

func _ready() -> void:
	await get_tree().process_frame
	for kind in [
		CartoonStage.Kind.CAUSE,
		CartoonStage.Kind.EFFECT_WIN,
		CartoonStage.Kind.EFFECT_LOSE,
	]:
		print("▶ %s / %s" % [SCENARIO, _kind_name(kind)])
		var stage := CartoonStage.new()
		stage.configure(kind, SCENARIO, {})
		add_child(stage)
		await stage.play_cutscene()
		stage.queue_free()
		await get_tree().process_frame
	print("✅ preview complete")
	get_tree().quit(0)

func _kind_name(kind: int) -> String:
	match kind:
		CartoonStage.Kind.EFFECT_WIN:
			return "win"
		CartoonStage.Kind.EFFECT_LOSE:
			return "lose"
		_:
			return "cause"
