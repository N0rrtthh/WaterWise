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
## Hover state as reported by mouse_entered / mouse_exited. _on_pressed() used to ask
## whether the mouse POSITION was inside the button instead, which is wrong on touch:
## with emulate_mouse_from_touch (Godot's default, and on in this project) a tap
## leaves the emulated cursor inside the button that was tapped, so the press settled
## at HOVER_SCALE and no mouse_exited ever arrived to bring it back down — every
## tapped button stayed permanently 10% enlarged on Android.
var _button_hovered: Dictionary = {}  # Button -> bool


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
		var btn := node as BaseButton
		# A button that is ALREADY ready is being re-added (a menu that hides a panel
		# with remove_child and puts it back). Node.ready fires once per lifetime, so
		# waiting on it here would never hook such a button. _hook_button() is
		# idempotent, so calling it on a still-hooked button is a no-op.
		if btn.is_node_ready():
			_hook_button(btn)
		elif not btn.ready.is_connected(_hook_button):
			btn.ready.connect(_hook_button.bind(btn), CONNECT_ONE_SHOT)


## Is this button part of a round in progress, rather than a menu?
##
## Gameplay buttons MUST stay pausable: an in-round pause overlay is the one case
## where a frozen button is the correct behaviour, and a tap that lands on the
## playfield behind the overlay must not score. The overlays that have to keep
## working while a round is paused already set PROCESS_MODE_ALWAYS on themselves
## (MiniGameBase._create_pause_menu, the HUD pause glyph, and the five co-op pause
## menus), and their children inherit it - this function never clears that.
##
## Decided by SCRIPT INHERITANCE, walking ancestors, not by a list of scene paths: a
## path table has to be kept in step with every scene ever added and rots silently.
## Every single-player round descends from MiniGameBase (MicrogameShell included) and
## every live co-op round from MultiplayerMiniGameBase, with the older debug co-op
## scenes under scripts/multiplayer/ descending from MultiplayerMiniGameEffects.
func _is_gameplay_button(button: BaseButton) -> bool:
	var n: Node = button
	while n != null:
		if n is MiniGameBase or n is MultiplayerMiniGameBase 				or n is MultiplayerMiniGameEffects:
			return true
		n = n.get_parent()
	return false


func _hook_button(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	_prune_freed()
	if _connected_buttons.has(button):
		return
	_connected_buttons[button] = true
	_button_base_scales[button] = button.scale
	_button_hovered[button] = false
	button.pivot_offset = button.size * 0.5
	if not _is_gameplay_button(button):
		# A paused tree delivers NO gui input to a PROCESS_MODE_INHERIT Button - not a
		# swallowed release, zero presses (measured: 0 while paused, 1 unpaused, same
		# synthetic click). So every menu Back button in the project was dead for as
		# long as a pause outlived the round that took it, and the player had no way
		# out of the screen. Pause exists to freeze GAMEPLAY; a menu is not gameplay,
		# so navigation stays live and the way out is always available.
		#
		# Its ButtonAnimator tween follows this process mode (a Tween defaults to
		# TWEEN_PAUSE_BOUND), so the press animation no longer freezes mid-scale and
		# leave the button stuck 22% enlarged either.
		button.process_mode = Node.PROCESS_MODE_ALWAYS

	button.resized.connect(_on_resized.bind(button))
	button.mouse_entered.connect(_on_hover.bind(button, true))
	button.mouse_exited.connect(_on_hover.bind(button, false))
	button.pressed.connect(_on_pressed.bind(button))
	button.tree_exiting.connect(_on_button_removed.bind(button))


## Leaving the tree is NOT the end of a button's life — a hidden panel is commonly
## removed and re-added, and the signal connections made in _hook_button() survive
## that. So the identity and the AUTHORED base scale are kept: erasing them left the
## re-added button animating around Vector2.ONE, which made it visibly snap to the
## wrong size on its next hover. Only the live tween is dropped, and the button is
## returned to its base scale so it cannot come back frozen mid-animation.
func _on_button_removed(button: BaseButton) -> void:
	if _button_tweens.has(button):
		var tw = _button_tweens[button]
		if tw and tw.is_valid():
			tw.kill()
		_button_tweens.erase(button)
	if not is_instance_valid(button):
		return
	_button_hovered[button] = false
	if _button_base_scales.has(button):
		button.scale = _button_base_scales[button]


## Entries are keyed by object, and a button that is freed while out of the tree
## leaves a dead key behind. Swept on each new hook so the four dictionaries cannot
## grow across a long session.
func _prune_freed() -> void:
	for dict in [_connected_buttons, _button_base_scales, _button_hovered,
			_button_tweens]:
		for key in dict.keys():
			if not is_instance_valid(key):
				dict.erase(key)


func _on_resized(button: BaseButton) -> void:
	if is_instance_valid(button):
		button.pivot_offset = button.size * 0.5


## Duration scaler. AccessibilityManager.get_animation_speed() is a DIVISOR (3.0 with
## reduced motion on), the same way the cutscene family and JuiceEffects consume it.
## Button feedback is SHORTENED rather than suppressed: a button that answers a tap
## with nothing at all reads as an unresponsive button, which is worse than a fast one.
func _t(seconds: float) -> float:
	var speed := 1.0
	if AccessibilityManager and AccessibilityManager.has_method("get_animation_speed"):
		var reported := float(AccessibilityManager.get_animation_speed())
		if reported > 0.0:
			speed = reported
	return max(seconds / speed, 0.016)


func _on_hover(button: BaseButton, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	_button_hovered[button] = hovered
	var base = _button_base_scales.get(button, Vector2.ONE)
	var tw = _begin_tween(button)

	if hovered:
		tw.tween_property(
			button, "scale", base * HOVER_OVERSHOOT, _t(0.10)
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(
			button, "scale", base * HOVER_SCALE, _t(0.09)
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(
			button, "scale", base * 0.96, _t(0.06)
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(
			button, "scale", base, _t(0.11)
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	var base = _button_base_scales.get(button, Vector2.ONE)
	# Settle at hover scale only if a real mouse_entered put this button in a hover
	# state. See _button_hovered for why the mouse position cannot answer this.
	var is_hovered: bool = bool(_button_hovered.get(button, false))
	var settle = base * (HOVER_SCALE if is_hovered else 1.0)
	var tw = _begin_tween(button)

	tw.tween_property(
		button, "scale", base * PRESS_SCALE, _t(0.07)
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(
		button, "scale", base * PRESS_REBOUND, _t(0.06)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(
		button, "scale", settle, _t(0.10)
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _begin_tween(button: BaseButton) -> Tween:
	if _button_tweens.has(button):
		var old = _button_tweens[button]
		if old and old.is_valid():
			old.kill()
	var tw = create_tween()
	_button_tweens[button] = tw
	return tw
