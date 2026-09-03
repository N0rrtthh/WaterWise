class_name MultiplayerMiniGameEffects
extends Node2D

## Last whole second written to the timer label. All MP minigames display the
## timer at 1 s resolution, so writing `timer_label.text` every frame allocated a
## String and re-laid-out the Label 60×/s to render identical pixels. Subclasses
## call `update_timer_label()` instead, which writes only on a real change.
var _last_timer_display_second: int = -1

## The life-lost punch currently running, so a life lost inside the previous punch
## kills it instead of fighting it. Declared here rather than in the override so
## MiniGame_Rain (which extends this class) shares the one member.
##
## Without it the two tweens both drove LivesLabel.scale and the second captured the
## live mid-punch scale as its return target, leaving the label permanently oversized
## — an HBoxContainer sizes its children but never scales them, so nothing
## downstream reset it.
var _lives_punch_tween: Tween = null

## The self-position shake currently running, and the rest position it returns to.
## MiniGame_Rain used to tween `position` to the literals (10,0), (-10,0) and
## Vector2.ZERO inline: two lives lost inside 0.15 s left two tweens driving the one
## property, and ZERO is only the right home if the scene sits at the origin.
var _shake_tween: Tween = null
var _shake_home: Vector2 = Vector2.ZERO

## Write the countdown to a Label only when the displayed whole-second value
## changes. `use_ceil` picks the rounding each game already used — ceil counts
## down 60→1, floor counts 59→0 — so display behaviour is unchanged.
## Returns true when a write happened, so callers can hook one-per-second logic.
func update_timer_label(
	label: Label, seconds_left: float, prefix: String = "", use_ceil: bool = true
) -> bool:
	if not label:
		return false
	var clamped: float = max(0.0, seconds_left)
	var whole: int = int(ceil(clamped)) if use_ceil else int(clamped)
	if whole == _last_timer_display_second:
		return false
	_last_timer_display_second = whole
	label.text = prefix + str(whole)
	return true

## Call when a round (re)starts so the next frame always repaints the label.
func reset_timer_label_cache() -> void:
	_last_timer_display_second = -1

func play_success_effect() -> void:
	_flash_screen(Color(0.3, 1.0, 0.3, 0.3))
	if AudioManager:
		AudioManager.play_collect()

func play_mistake_effect() -> void:
	_flash_screen(Color(1.0, 0.3, 0.3, 0.3))
	if AudioManager:
		AudioManager.play_damage()

func play_score_popup(amount: int, popup_pos: Vector2) -> void:
	var popup := Label.new()
	popup.text = "+%d" % amount
	popup.add_theme_font_size_override("font_size", 32)
	popup.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
	popup.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	popup.add_theme_constant_override("outline_size", 4)
	popup.position = popup_pos
	popup.z_index = 100
	add_child(popup)

	var tween = create_tween()
	tween.set_parallel(true)
	var move_tween = tween.tween_property(popup, "position:y", popup_pos.y - 80, 0.8)
	move_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var fade_tween = tween.tween_property(popup, "modulate:a", 0.0, 0.8)
	fade_tween.set_ease(Tween.EASE_IN)
	var scale_tween = tween.tween_property(popup, "scale", Vector2(1.5, 1.5), 0.3)
	scale_tween.set_ease(Tween.EASE_OUT)
	tween.finished.connect(popup.queue_free)

func animate_score_label() -> void:
	var score_lbl: Label = get_node_or_null("UI/TopBar/ScoreLabel")
	if not score_lbl:
		return
	var tween = create_tween()
	var up_tween = tween.tween_property(score_lbl, "scale", Vector2(1.15, 1.15), 0.1)
	up_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var down_tween = tween.tween_property(score_lbl, "scale", Vector2.ONE, 0.1)
	down_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

func animate_life_lost() -> void:
	var lives_lbl: Label = get_node_or_null("UI/TopBar/LivesLabel")
	if not lives_lbl:
		return
	# Same defect and same fix as the MiniGame_Rain override: kill the punch already
	# running and rebase on the rest values, rather than leaving two tweens to fight
	# over `scale` and capturing the live mid-punch value as the one to return to.
	# See _lives_punch_tween's declaration for why the label never self-corrected.
	if _lives_punch_tween and _lives_punch_tween.is_valid():
		_lives_punch_tween.kill()
	lives_lbl.scale = Vector2.ONE
	lives_lbl.modulate = Color.WHITE
	_lives_punch_tween = create_tween()
	_lives_punch_tween.tween_property(lives_lbl, "modulate", Color(2.0, 0.3, 0.3), 0.1)
	_lives_punch_tween.tween_property(lives_lbl, "modulate", Color.WHITE, 0.3)
	_lives_punch_tween.parallel().tween_property(lives_lbl, "scale", Vector2(1.4, 1.4), 0.1)
	var scale_tween: PropertyTweener = _lives_punch_tween.tween_property(lives_lbl, "scale", Vector2.ONE, 0.2)
	scale_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func animate_timer_warning() -> void:
	var timer_lbl: Label = get_node_or_null("UI/TopBar/TimerLabel")
	if not timer_lbl:
		return
	var tween = create_tween()
	tween.tween_property(timer_lbl, "modulate", Color(2.0, 0.3, 0.3), 0.2)
	tween.tween_property(timer_lbl, "modulate", Color.WHITE, 0.2)

## Nudge the whole round sideways once, obeying the screen-shake setting.
##
## Kills a shake already in flight and rebases on the stored home position rather
## than capturing a mid-shake offset as the value to return to — the same defect and
## the same fix as animate_life_lost() above. JuiceEffects.screen_shake() cannot be
## reused here: it only knows how to offset a Camera2D, and these scenes have none.
func shake_self(amount: float = 10.0, step: float = 0.05) -> void:
	if not JuiceEffects.is_screen_shake_allowed():
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		position = _shake_home
	else:
		_shake_home = position
	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "position", _shake_home + Vector2(amount, 0.0), step)
	_shake_tween.tween_property(self, "position", _shake_home - Vector2(amount, 0.0), step)
	_shake_tween.tween_property(self, "position", _shake_home, step)


## Start a music track and stop it again when `scope` leaves the tree.
##
## Same helper, same contract as MiniGameBase._play_scoped_music: the `current_music`
## check means a track that has already been replaced by whatever came next is left
## alone, so only the owner of the still-playing track stops it.
func _play_scoped_music(track: String, fade_in: float, scope: Node) -> void:
	if AudioManager == null or not is_instance_valid(AudioManager):
		return
	AudioManager.play_music(track, fade_in)
	if scope == null or not is_instance_valid(scope):
		return
	scope.tree_exiting.connect(func() -> void:
		if is_instance_valid(AudioManager) and AudioManager.current_music == track:
			AudioManager.stop_music(0.15))


## Start the round music on READY.
##
## Nothing under scripts/multiplayer/ played any music: all seventeen multiplayer
## rounds ran on SFX alone while every single-player round has a track. Hooked on the
## notification and not on a base _ready(), because all five subclasses declare their
## own _ready() and a GDScript override REPLACES the parent method — a base _ready()
## here would simply never run. A subclass that adds _notification() must call
## super._notification(what).
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_play_scoped_music("gameplay", 0.8, self)


func _flash_screen(color: Color) -> void:
	var flash = ColorRect.new()
	flash.color = color
	flash.size = get_viewport_rect().size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.finished.connect(flash.queue_free)
