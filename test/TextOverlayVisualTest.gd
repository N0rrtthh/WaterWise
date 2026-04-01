extends Control

## Visual test for text overlay animation system
##
## This test demonstrates all three animation types:
## - fade_in: Text fades in and out
## - slide_in: Text slides in from left and out to right
## - bounce_in: Text bounces in with scale animation
##
## Press SPACE to cycle through animation types
## Press R to restart current animation

@onready var _container: Control = $Container
@onready var _info_label: Label = $InfoLabel

var _current_animation_index: int = 0
var _animation_types = [
	{"type": CutsceneTypes.TextAnimationType.FADE_IN, "name": "Fade In"},
	{"type": CutsceneTypes.TextAnimationType.SLIDE_IN, "name": "Slide In"},
	{"type": CutsceneTypes.TextAnimationType.BOUNCE_IN, "name": "Bounce In"}
]

var _current_positions = [
	{"pos": CutsceneTypes.TextPosition.TOP, "name": "Top"},
	{"pos": CutsceneTypes.TextPosition.CENTER, "name": "Center"},
	{"pos": CutsceneTypes.TextPosition.BOTTOM, "name": "Bottom"}
]

var _current_position_index: int = 0


func _ready() -> void:
	_update_info_label()
	_play_current_animation()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # SPACE
		_current_animation_index = (_current_animation_index + 1) % _animation_types.size()
		_update_info_label()
		_play_current_animation()
	
	elif event.is_action_pressed("ui_cancel"):  # ESC
		get_tree().quit()
	
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_play_current_animation()
	
	elif event is InputEventKey and event.pressed and event.keycode == KEY_P:
		_current_position_index = (_current_position_index + 1) % _current_positions.size()
		_update_info_label()
		_play_current_animation()


func _update_info_label() -> void:
	var anim_name = _animation_types[_current_animation_index]["name"]
	var pos_name = _current_positions[_current_position_index]["name"]
	_info_label.text = "Animation: %s | Position: %s\nPress SPACE to change animation | Press P to change position | Press R to restart | Press ESC to quit" % [anim_name, pos_name]


func _play_current_animation() -> void:
	# Clear existing overlays
	for child in _container.get_children():
		child.queue_free()
	
	# Create overlay data
	var overlay_data = CutsceneDataModels.TextOverlay.new("Water Conservation!", 0.0)
	overlay_data.animation_type = _animation_types[_current_animation_index]["type"]
	overlay_data.position = _current_positions[_current_position_index]["pos"]
	overlay_data.duration = 2.0
	overlay_data.font_size = 48
	overlay_data.color = Color.CYAN
	
	# Create and play overlay
	var overlay_node = AnimatedTextOverlay.new()
	_container.add_child(overlay_node)
	overlay_node.play_animation(overlay_data, _container.size)
	
	# Restart after animation finishes
	overlay_node.animation_finished.connect(_on_animation_finished)


func _on_animation_finished() -> void:
	# Wait a moment before restarting
	await get_tree().create_timer(0.5).timeout
	_play_current_animation()
