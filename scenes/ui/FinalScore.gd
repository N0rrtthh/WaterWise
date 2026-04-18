extends Control

# =====================================================================
# FINAL SCORE — DWTD-style end-of-session results
# Optimized: <=12 tweens, <=25 nodes, no _process loop.
# Algorithms preserved: scores come from GameManager which
# feeds AdaptiveDifficulty (Phi=WMA-CP) and G-Counter CRDT.
# =====================================================================

@onready var total_score_label = $CenterContainer/VBoxContainer/TotalScoreLabel
@onready var high_score_label = $CenterContainer/VBoxContainer/HighScoreLabel
@onready var new_record_label = $CenterContainer/VBoxContainer/NewRecordLabel
@onready var continue_btn = $CenterContainer/VBoxContainer/ContinueButton

var _droplet: Node2D = null


func _loc(key: String, fallback: String) -> String:
	if Localization:
		var translated = Localization.get_text(key)
		if translated != key:
			return translated
	return fallback


func _fmt_loc(key: String, fallback: String, values: Array) -> String:
	var pattern = _loc(key, fallback)
	if values.is_empty():
		return pattern
	if values.size() == 1:
		return pattern % values[0]
	return pattern % values


func _should_show_particles() -> bool:
	if AccessibilityManager and AccessibilityManager.has_method("should_show_particles"):
		return AccessibilityManager.should_show_particles()
	if SaveManager and SaveManager.has_method("is_particles_enabled"):
		return SaveManager.is_particles_enabled()
	return true


func _ready() -> void:
	var total = GameManager.session_score if GameManager else 0
	var high = GameManager.high_score if GameManager else 0
	var is_record = total >= high and total > 0
	var rounds = GameManager.round_scores if GameManager else []

	_build_bg(is_record)
	_init_labels(total, high)
	_build_mascot(total, rounds)
	_build_round_breakdown(rounds)
	_animate_entrance(total, is_record)
	continue_btn.text = _loc("continue", "CONTINUE")

	new_record_label.visible = is_record
	if is_record:
		new_record_label.text = _loc("new_high_score", "NEW HIGH SCORE!")
		_animate_record_label()
		_spawn_confetti(12)
	else:
		_spawn_confetti(6)

	continue_btn.pressed.connect(_on_continue)
	continue_btn.pivot_offset = continue_btn.size * 0.5

	if AudioManager:
		AudioManager.play_music("results", 0.5)
		await get_tree().create_timer(0.3).timeout
		AudioManager.play_fanfare()
		if is_record:
			await get_tree().create_timer(0.5).timeout
			AudioManager.play_bonus()


# ── Background ──────────────────────────────────────────────────────

func _build_bg(is_record: bool) -> void:
	var bg = get_node_or_null("ColorRect")
	if bg:
		bg.color = Color(0.04, 0.1, 0.22) if is_record else Color(0.03, 0.08, 0.18)


# ── Labels ──────────────────────────────────────────────────────────

func _init_labels(_total: int, high: int) -> void:
	var score_key = _loc("total_score", "TOTAL SCORE")
	total_score_label.text = "%s: 0" % score_key
	var hs_key = _loc("high_score", "HIGH SCORE")
	high_score_label.text = "%s: %d" % [hs_key, high]


# ── Entrance animation ─────────────────────────────────────────────

func _animate_entrance(total: int, _is_record: bool) -> void:
	var vbox = $CenterContainer/VBoxContainer
	vbox.modulate.a = 0.0
	vbox.position.y += 60

	var enter = create_tween()
	enter.set_parallel(true)
	enter.tween_property(vbox, "modulate:a", 1.0, 0.5)
	enter.tween_property(
		vbox, "position:y", vbox.position.y - 60, 0.6
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Score count-up
	var score_key = _loc("total_score", "TOTAL SCORE")
	var count = create_tween()
	count.tween_interval(0.6)
	count.tween_method(
		func(v: float):
			total_score_label.text = "%s: %d" % [score_key, int(v)],
		0.0, float(total), 1.0
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Pop score label
	total_score_label.pivot_offset = total_score_label.size * 0.5
	var pop = create_tween()
	pop.tween_interval(1.6)
	pop.tween_property(total_score_label, "scale", Vector2(1.25, 1.25), 0.1)
	pop.tween_property(total_score_label, "scale", Vector2(0.95, 0.95), 0.07)
	pop.tween_property(total_score_label, "scale", Vector2(1.0, 1.0), 0.06)

	# HS label fade
	high_score_label.modulate.a = 0.0
	var hs = create_tween()
	hs.tween_interval(0.9)
	hs.tween_property(high_score_label, "modulate:a", 1.0, 0.4)


# ── Record label ───────────────────────────────────────────────────

func _animate_record_label() -> void:
	new_record_label.pivot_offset = new_record_label.size * 0.5
	var pulse = create_tween().set_loops()
	pulse.tween_property(new_record_label, "scale", Vector2(1.15, 1.15), 0.35)
	pulse.tween_property(new_record_label, "scale", Vector2(0.95, 0.95), 0.25)
	pulse.tween_property(new_record_label, "scale", Vector2(1.0, 1.0), 0.15)

	var clr = create_tween().set_loops()
	clr.tween_property(new_record_label, "modulate", Color(1, 1, 0.3), 0.35)
	clr.tween_property(new_record_label, "modulate", Color(1, 0.6, 0.9), 0.35)
	clr.tween_property(new_record_label, "modulate", Color(0.5, 1, 0.8), 0.35)
	clr.tween_property(new_record_label, "modulate", Color(1, 1, 1), 0.25)


# ── Confetti (lightweight: ColorRect, no GPU particles) ────────────

func _spawn_confetti(count: int) -> void:
	if not _should_show_particles():
		return

	var vp = get_viewport_rect().size
	var colors := [
		Color(1, 0.85, 0.2, 0.85),
		Color(0.3, 1, 0.5, 0.8),
		Color(0.5, 0.8, 1, 0.8),
		Color(1, 0.5, 0.8, 0.8),
		Color(1, 0.6, 0.2, 0.8),
	]
	for i in count:
		var c = ColorRect.new()
		c.size = Vector2(randf_range(4, 9), randf_range(8, 14))
		c.position = Vector2(randf_range(vp.x * 0.1, vp.x * 0.9), -randf_range(10, 60))
		c.color = colors[i % colors.size()]
		c.rotation = randf_range(0, TAU)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)

		var dur = randf_range(2.5, 4.5)
		var delay = randf_range(0.0, 1.2)
		var end_y = vp.y + 40
		var end_x = c.position.x + randf_range(-60, 60)

		var tw = create_tween()
		tw.tween_interval(delay)
		tw.set_parallel(true)
		tw.tween_property(
			c, "position", Vector2(end_x, end_y), dur
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		tw.tween_property(c, "rotation", c.rotation + randf_range(-4, 4), dur)
		tw.tween_property(
			c, "modulate:a", 0.0, dur * 0.3
		).set_delay(delay + dur * 0.7)

		# Auto-free when done
		var cleanup = create_tween()
		cleanup.tween_interval(delay + dur + 0.5)
		cleanup.tween_callback(c.queue_free)


# ── Mascot droplet ─────────────────────────────────────────────────

func _build_mascot(total: int, _rounds: Array) -> void:
	var vp = get_viewport_rect().size
	_droplet = Node2D.new()
	_droplet.position = Vector2(vp.x * 0.82, vp.y * 0.5)
	_droplet.scale = Vector2.ZERO
	_droplet.modulate.a = 0.0
	add_child(_droplet)

	var rank = _compute_rank(total)
	var happy = rank in ["S", "A", "B"]

	# Body
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -45), Vector2(22, -30), Vector2(32, -5),
		Vector2(28, 18), Vector2(15, 32), Vector2(0, 36),
		Vector2(-15, 32), Vector2(-28, 18), Vector2(-32, -5),
		Vector2(-22, -30),
	])
	body.color = Color(0.35, 0.75, 1.0) if happy else Color(0.45, 0.5, 0.8)
	_droplet.add_child(body)

	# Eyes
	for xoff in [-11, 11]:
		var ew = Polygon2D.new()
		ew.polygon = _oval(7, 7, 8)
		ew.position = Vector2(xoff, -5)
		ew.color = Color.WHITE
		_droplet.add_child(ew)
		var pp = Polygon2D.new()
		pp.polygon = _oval(3.5, 3.5, 6)
		pp.position = Vector2(xoff, -4)
		pp.color = Color.BLACK
		_droplet.add_child(pp)

	# Mouth
	var mouth = Line2D.new()
	mouth.width = 2.5
	mouth.default_color = Color(0.1, 0.1, 0.1)
	if happy:
		mouth.points = PackedVector2Array([
			Vector2(-12, 8), Vector2(-6, 16),
			Vector2(6, 16), Vector2(12, 8),
		])
	else:
		mouth.points = PackedVector2Array([
			Vector2(-10, 14), Vector2(-4, 10),
			Vector2(4, 10), Vector2(10, 14),
		])
	_droplet.add_child(mouth)

	# Arms
	for side in [-1, 1]:
		var arm = Line2D.new()
		arm.width = 4
		arm.default_color = Color(0.3, 0.68, 0.95)
		arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arm.end_cap_mode = Line2D.LINE_CAP_ROUND
		if happy:
			arm.points = PackedVector2Array([
				Vector2(side * 28, 0), Vector2(side * 42, -16),
				Vector2(side * 45, -28),
			])
		else:
			arm.points = PackedVector2Array([
				Vector2(side * 28, 2), Vector2(side * 38, 14),
				Vector2(side * 36, 24),
			])
		_droplet.add_child(arm)

	# Rank badge
	var badge = Label.new()
	badge.text = rank
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 38)
	badge.add_theme_color_override("font_color", _rank_color(rank))
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 8)
	badge.position = Vector2(-18, -82)
	_droplet.add_child(badge)

	# Entrance — bouncy squash-stretch
	var en = create_tween()
	en.tween_interval(0.7)
	en.tween_property(_droplet, "modulate:a", 1.0, 0.08)
	en.tween_property(_droplet, "scale", Vector2(1.3, 0.6), 0.08)
	en.tween_property(_droplet, "scale", Vector2(0.85, 1.25), 0.08)
	en.tween_property(_droplet, "scale", Vector2(1.05, 0.95), 0.06)
	en.tween_property(_droplet, "scale", Vector2(1.0, 1.0), 0.05)

	# Idle bounce / sway (1 tween)
	if happy:
		var idle = create_tween().set_loops()
		idle.tween_interval(0.3)
		var base_y = _droplet.position.y
		idle.tween_property(_droplet, "position:y", base_y - 8, 0.45).set_trans(Tween.TRANS_SINE)
		idle.tween_property(_droplet, "scale", Vector2(1.05, 0.95), 0.15)
		idle.tween_property(_droplet, "position:y", base_y, 0.45).set_trans(Tween.TRANS_SINE)
		idle.tween_property(_droplet, "scale", Vector2(1.0, 1.0), 0.15)
	else:
		var sway = create_tween().set_loops()
		sway.tween_property(_droplet, "rotation", 0.06, 0.9).set_trans(Tween.TRANS_SINE)
		sway.tween_property(_droplet, "rotation", -0.06, 0.9).set_trans(Tween.TRANS_SINE)


# ── Round breakdown ────────────────────────────────────────────────

func _build_round_breakdown(rounds: Array) -> void:
	if rounds.is_empty():
		return
	var vbox = $CenterContainer/VBoxContainer

	# Rank + summary
	var total = GameManager.session_score if GameManager else 0
	var rank = _compute_rank(total)

	var rank_lbl = Label.new()
	rank_lbl.text = _fmt_loc("finalscore_rank", "Rank: %s", [rank])
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_size_override("font_size", 40)
	rank_lbl.add_theme_color_override("font_color", _rank_color(rank))
	rank_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	rank_lbl.add_theme_constant_override("outline_size", 6)
	vbox.add_child(rank_lbl)

	var line = Label.new()
	line.text = _summary_line(total, rounds)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 24)
	line.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	vbox.add_child(line)

	# Round list (max 8 visible to avoid scroll overflow)
	var show_count = mini(rounds.size(), 8)
	for i in range(show_count):
		var row = rounds[i]
		var lbl = Label.new()
		lbl.text = _fmt_loc("finalscore_round_row", "%d. %s | %d pts | x%d", [
			i + 1,
			str(row.get("game", "?")),
			int(row.get("score", 0)),
			int(row.get("combo", 0)),
		])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1))
		vbox.add_child(lbl)


# ── Helpers ────────────────────────────────────────────────────────

func _compute_rank(score: int) -> String:
	if score >= 900:
		return "S"
	if score >= 700:
		return "A"
	if score >= 500:
		return "B"
	if score >= 300:
		return "C"
	return "D"


func _rank_color(rank: String) -> Color:
	match rank:
		"S": return Color(1, 0.85, 0.1)
		"A": return Color(0.3, 1, 0.5)
		"B": return Color(0.5, 0.85, 1)
		"C": return Color(0.9, 0.7, 0.4)
		_: return Color(0.7, 0.5, 0.5)


func _summary_line(score: int, rounds: Array) -> String:
	if rounds.is_empty():
		return _loc("finalscore_no_rounds_played", "No rounds played.")
	var avg = float(score) / float(rounds.size())
	if avg >= 120.0:
		return _loc(
			"finalscore_summary_legend",
			"Legend pace. Water saved like a pro!"
		)
	if avg >= 80.0:
		return _loc("finalscore_summary_solid", "Solid run. Nice consistency!")
	if avg >= 40.0:
		return _loc("finalscore_summary_good", "Good effort. Keep building combos!")
	return _loc("finalscore_summary_rough", "Rough run. Bounce back next session!")


func _on_continue() -> void:
	if AudioManager:
		AudioManager.play_click()
	# Droplet waves goodbye
	if _droplet:
		var tw = create_tween()
		tw.tween_property(
			_droplet, "position:y", _droplet.position.y - 200, 0.3
		).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_droplet, "scale", Vector2(1.3, 0.5), 0.15)
		tw.parallel().tween_property(_droplet, "modulate:a", 0.0, 0.25)
	if GameManager:
		if GameManager.current_game_mode == GameManager.GameMode.MULTIPLAYER_COOP:
			if NetworkManager and NetworkManager.has_method("disconnect_multiplayer"):
				NetworkManager.disconnect_multiplayer()
			if GameManager.has_method("return_to_multiplayer_lobby"):
				GameManager.return_to_multiplayer_lobby()
			else:
				GameManager.transition_to_scene("res://scenes/ui/MultiplayerLobby.tscn")
			return
		GameManager.transition_to_scene("res://scenes/ui/InitialScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")


func _oval(w: float, h: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segs):
		var a = i * TAU / segs
		pts.append(Vector2(cos(a) * w, sin(a) * h))
	return pts
