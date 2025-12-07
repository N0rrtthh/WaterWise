@tool
@icon("./pause_button.svg")
class_name PauseButton
extends Button

## PauseButton
##
## Pauses the tree when pressed.[br]
## When [member Button.toggle_mode] is set, the button's
## [member Button.pressed] state will match the trees [member SceneTree.paused] state
## and the button [i]toggle[/i] the pause state of the tree instead.[br]
## NOTE: It is [b]highly[/b] suggested to modify the [member Node.process_mode] of this
## in order for it to process with the tree's expected [member SceneTree.paused] state.
## NOTE: When using [member Button.toggle_mode], its highly suggested to provide the NovaTools
## plugin as well, as NovaTools provides the [TreeWatcher] autoload, which allows for the
## the (visible) toggle state to consistently reflect the state of the scene tree.

var _hooked := false
func _hook_tree(_ign = null) -> void:
	var tw:Node = get_node_or_null("/root/TreeWatcher")
	if tw == null:
		tw = get_node_or_null("/root/treewatcher")
	var tree := get_tree()
	if tw == null:
		_hooked = false
		if tree != null:
			if not tree.node_renamed.is_connected(_hook_tree):
				tree.node_renamed.connect(_hook_tree)
			if not tree.node_added.is_connected(_hook_tree):
				tree.node_added.connect(_hook_tree)
	else:
		if not tw.tree_exited.is_connected(_hook_tree):
			tw.tree_exited.connect(_hook_tree)
		if tree != null:
			if tree.node_renamed.is_connected(_hook_tree):
				tree.node_renamed.disconnect(_hook_tree)
			if tree.node_added.is_connected(_hook_tree):
				tree.node_added.disconnect(_hook_tree)

		if not tw.tree_paused.is_connected(_on_paused):
			tw.tree_paused.connect(_on_paused)
		if not tw.tree_resumed.is_connected(_on_unpaused):
			tw.tree_resumed.connect(_on_unpaused)
		_hooked = true

	update_configuration_warnings()

	if toggle_mode and tree != null:
		if tree.paused:
			_on_paused()
		else:
			_on_unpaused()

func _get_configuration_warnings() -> PackedStringArray:
	var ret := PackedStringArray()
	if not _hooked and toggle_mode:
		ret.append("The TreeWatcher autoload could not be found. " +
					"This button's toggled state may not behave as expected."
					)
	if process_mode != PROCESS_MODE_ALWAYS:
		ret.append("process_mode is not set to PROCESS_MODE_ALWAYS. " +
					"This button's toggled state may not behave as expected."
					)
	return ret

func _enter_tree() -> void:
	_hook_tree()
	disabled = false

func _property_can_revert(property: StringName) -> bool:
	match(property):
		"text", "process_mode", "icon":
			return true
	return false

func _property_get_revert(property: StringName) -> Variant:
	match(property):
		"text":
			return "Pause"
		"process_mode":
			return PROCESS_MODE_ALWAYS
		"icon":
			return preload("./pause_button.svg")
	return null

func _pressed() -> void:
	if toggle_mode or Engine.is_editor_hint():
		return

	var tree := get_tree()
	if tree != null:
		tree.paused = true

func _toggled(toggled_on: bool) -> void:
	if not toggle_mode or Engine.is_editor_hint():
		return

	var tree := get_tree()
	if tree != null:
		tree.paused = toggled_on

func _on_paused() -> void:
	if toggle_mode:
		set_pressed_no_signal(true)

func _on_unpaused() -> void:
	if toggle_mode:
		set_pressed_no_signal(false)

func _exit_tree() -> void:
	_hook_tree()
	disabled = true
