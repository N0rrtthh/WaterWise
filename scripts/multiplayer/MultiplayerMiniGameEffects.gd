class_name MultiplayerMiniGameEffects
extends Node2D

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
	var tween = create_tween()
	tween.tween_property(lives_lbl, "modulate", Color(2.0, 0.3, 0.3), 0.1)
	tween.tween_property(lives_lbl, "modulate", Color.WHITE, 0.3)

	var original_scale = lives_lbl.scale
	tween.parallel().tween_property(lives_lbl, "scale", Vector2(1.4, 1.4), 0.1)
	var scale_tween = tween.tween_property(lives_lbl, "scale", original_scale, 0.2)
	scale_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func animate_timer_warning() -> void:
	var timer_lbl: Label = get_node_or_null("UI/TopBar/TimerLabel")
	if not timer_lbl:
		return
	var tween = create_tween()
	tween.tween_property(timer_lbl, "modulate", Color(2.0, 0.3, 0.3), 0.2)
	tween.tween_property(timer_lbl, "modulate", Color.WHITE, 0.2)

func _flash_screen(color: Color) -> void:
	var flash = ColorRect.new()
	flash.color = color
	flash.size = get_viewport_rect().size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.finished.connect(flash.queue_free)
