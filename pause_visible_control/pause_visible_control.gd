@tool
@icon("./pause_visible_control.svg")
class_name PauseVisibleControl
extends Control

## PauseVisibleControl
##
## A [Control] that syncs it's [member Control.visible]ity with the current tree's
## [member SceneTree.paused] state.

## When set, and when the tree is unpaused and this or
## any child of this node has gui focus, their focus will be released.
@export var release_focus_on_hide := true

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

		if not Engine.is_editor_hint():
			if not tw.tree_paused.is_connected(_on_paused):
				tw.tree_paused.connect(_on_paused)
			if not tw.tree_resumed.is_connected(_on_unpaused):
				tw.tree_resumed.connect(_on_unpaused)
		_hooked = true

	update_configuration_warnings()

	if tree != null and not Engine.is_editor_hint():
		if tree.paused:
			_on_paused()
		else:
			_on_unpaused()

func _get_configuration_warnings() -> PackedStringArray:
	var ret := PackedStringArray()
	if not _hooked:
		ret.append("The TreeWatcher autoload could not be found. " +
					"This control's visibility may not behave as expected."
					)
	if process_mode != PROCESS_MODE_ALWAYS:
		ret.append("process_mode is not set to PROCESS_MODE_ALWAYS. " +
					"This control's visibility may not behave as expected."
					)
	return ret

func _enter_tree() -> void:
	_hook_tree()

func _property_can_revert(property: StringName) -> bool:
	match(property):
		"process_mode":
			return true
	return false

func _property_get_revert(property: StringName) -> Variant:
	match(property):
		"process_mode":
			return PROCESS_MODE_ALWAYS
	return null

func _on_paused() -> void:
	show()

func _on_unpaused() -> void:
	hide()

	if release_focus_on_hide:
		var fo := get_viewport().gui_get_focus_owner()
		if fo != null and (fo == self or is_ancestor_of(fo)):
			fo.release_focus()

func _exit_tree() -> void:
	_hook_tree()
