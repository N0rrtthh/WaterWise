extends Control

## Demo scene for AnimatedCutscenePlayer
## Allows testing of intro, win, and fail cutscenes

@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var button_container: VBoxContainer = $VBoxContainer

var cutscene_player: AnimatedCutscenePlayer


func _ready() -> void:
	# Create cutscene player
	cutscene_player = AnimatedCutscenePlayer.new()
	add_child(cutscene_player)
	move_child(cutscene_player, 0)  # Move to back so buttons are visible
	
	# Connect signal
	cutscene_player.cutscene_finished.connect(_on_cutscene_finished)
	
	# Hide cutscene player initially
	cutscene_player.visible = false


func _on_play_intro_button_pressed() -> void:
	_play_cutscene(CutsceneTypes.CutsceneType.INTRO)


func _on_play_win_button_pressed() -> void:
	_play_cutscene(CutsceneTypes.CutsceneType.WIN)


func _on_play_fail_button_pressed() -> void:
	_play_cutscene(CutsceneTypes.CutsceneType.FAIL)


func _play_cutscene(cutscene_type: CutsceneTypes.CutsceneType) -> void:
	# Disable buttons during playback
	_set_buttons_enabled(false)
	
	# Update status
	var type_name = _get_cutscene_type_name(cutscene_type)
	status_label.text = "Playing " + type_name + " cutscene..."
	
	# Show cutscene player
	cutscene_player.visible = true
	
	# Play cutscene
	await cutscene_player.play_cutscene("DemoMinigame", cutscene_type)


func _on_cutscene_finished() -> void:
	# Hide cutscene player
	cutscene_player.visible = false
	
	# Update status
	status_label.text = "Cutscene complete! Ready for next."
	
	# Re-enable buttons
	_set_buttons_enabled(true)


func _set_buttons_enabled(enabled: bool) -> void:
	for child in button_container.get_children():
		if child is Button:
			child.disabled = not enabled


func _get_cutscene_type_name(cutscene_type: CutsceneTypes.CutsceneType) -> String:
	match cutscene_type:
		CutsceneTypes.CutsceneType.INTRO:
			return "Intro"
		CutsceneTypes.CutsceneType.WIN:
			return "Win"
		CutsceneTypes.CutsceneType.FAIL:
			return "Fail"
		_:
			return "Unknown"
