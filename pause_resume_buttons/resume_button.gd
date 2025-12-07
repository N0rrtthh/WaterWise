@tool
@icon("./resume_button.svg")
class_name ResumeButton
extends PauseButton

## ResumeButton
##
## Resumes (unpauses) the tree.[br]
## When [member Button.toggle_mode] is set, the button's
## [member Button.pressed] state will [b]inversely[/b] match the trees
## [member SceneTree.paused] state and the button [i]toggle[/i]
## the pause state of the tree instead.[br]
## NOTE: For more important notes on this, see the documentation for [PauseButton],
## This button's parent class.

func _property_get_revert(property: StringName) -> Variant:
	match(property):
		"text":
			return "Resume"
		"icon":
			return preload("./resume_button.svg")
	return super(property)

func _pressed() -> void:
	if toggle_mode or Engine.is_editor_hint():
		return

	var tree := get_tree()
	if tree != null:
		tree.paused = false

func _toggled(toggled_on: bool) -> void:
	if not toggle_mode or Engine.is_editor_hint():
		return

	var tree := get_tree()
	if tree != null:
		tree.paused = not toggled_on

func _on_paused() -> void:
	if toggle_mode:
		set_pressed_no_signal(false)

func _on_unpaused() -> void:
	if toggle_mode:
		set_pressed_no_signal(true)
