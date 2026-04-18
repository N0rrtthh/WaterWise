extends Node
## Global button animator — auto-applies hover/press scale animations
## to every Button in the scene tree. Register as an autoload.

const HOVER_SCALE := 1.10
const HOVER_OVERSHOOT := 1.18
const PRESS_SCALE := 1.22
const PRESS_REBOUND := 0.94

var _button_tweens: Dictionary = {}  # Button -> Tween
var _button_base_scales: Dictionary = {}  # Button -> Vector2
var _connected_buttons: Dictionary = {}  # Button -> true


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# Process existing nodes
	call_deferred("_scan_existing_buttons")


func _scan_existing_buttons() -> void:
	_scan_tree(get_tree().root)


func _scan_tree(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node as BaseButton)
	for child in node.get_children():
		_scan_tree(child)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		# Defer to let the button finish initialization
		(node as BaseButton).ready.connect(
			_hook_button.bind(node as BaseButton), CONNECT_ONE_SHOT
		)


func _hook_button(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	if _connected_buttons.has(button):
		return
	_connected_buttons[button] = true
	_button_base_scales[button] = button.scale
	button.pivot_offset = button.size * 0.5

	button.resized.connect(_on_resized.bind(button))
	button.mouse_entered.connect(_on_hover.bind(button, true))
	button.mouse_exited.connect(_on_hover.bind(button, false))
	button.pressed.connect(_on_pressed.bind(button))
	button.tree_exiting.connect(_on_button_removed.bind(button))


func _on_button_removed(button: BaseButton) -> void:
	_connected_buttons.erase(button)
	_button_base_scales.erase(button)
	if _button_tweens.has(button):
		var tw = _button_tweens[button]
		if tw and tw.is_valid():
			tw.kill()
		_button_tweens.erase(button)


func _on_resized(button: BaseButton) -> void:
	if is_instance_valid(button):
		button.pivot_offset = button.size * 0.5


func _on_hover(button: BaseButton, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	var base = _button_base_scales.get(button, Vector2.ONE)
	var tw = _begin_tween(button)

	if hovered:
		tw.tween_property(
			button, "scale", base * HOVER_OVERSHOOT, 0.10
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(
			button, "scale", base * HOVER_SCALE, 0.09
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(
			button, "scale", base * 0.96, 0.06
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(
			button, "scale", base, 0.11
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	var base = _button_base_scales.get(button, Vector2.ONE)
	var is_hovered = button.get_global_rect().has_point(
		button.get_viewport().get_mouse_position()
	)
	var settle = base * (HOVER_SCALE if is_hovered else 1.0)
	var tw = _begin_tween(button)

	tw.tween_property(
		button, "scale", base * PRESS_SCALE, 0.07
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(
		button, "scale", base * PRESS_REBOUND, 0.06
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(
		button, "scale", settle, 0.10
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _begin_tween(button: BaseButton) -> Tween:
	if _button_tweens.has(button):
		var old = _button_tweens[button]
		if old and old.is_valid():
			old.kill()
	var tw = create_tween()
	_button_tweens[button] = tw
	return tw
