extends Control

@onready var total_score_label = $CenterContainer/VBoxContainer/TotalScoreLabel
@onready var high_score_label = $CenterContainer/VBoxContainer/HighScoreLabel
@onready var new_record_label = $CenterContainer/VBoxContainer/NewRecordLabel
@onready var continue_btn = $CenterContainer/VBoxContainer/ContinueButton

var _confetti: Array[Node] = []
var _droplet: Node2D = null
var _bg_particles: Array[Node] = []

func _ready():
	var total_score = GameManager.session_score if GameManager else 0
	var high_score = GameManager.high_score if GameManager else 0
	var is_new_record = total_score >= high_score and total_score > 0
	var rounds = GameManager.round_scores if GameManager else []

	# Build fun animated background
	_build_animated_background(is_new_record)
	# Spawn floating background particles
	_spawn_bg_particles()

	# Display scores with count-up animation
	total_score_label.text = "%s: 0" % [
		Localization.get_text("total_score") if Localization else "TOTAL SCORE"
	]
	high_score_label.text = "%s: %d" % [
		Localization.get_text("high_score") if Localization else "HIGH SCORE",
		high_score
	]

	# Staggered entrance animation
	_animate_staggered_entrance(total_score, is_new_record)

	_add_rank_and_character(total_score, rounds)
	_add_round_breakdown(rounds)

	if is_new_record:
		new_record_label.visible = true
		new_record_label.text = (
			Localization.get_text("new_high_score")
			if Localization
			else "\u{1f389} NEW HIGH SCORE! \u{1f389}"
		)
		# Rainbow pulse animation for new record
		var tween = create_tween().set_loops()
		tween.tween_property(new_record_label, "scale", Vector2(1.25, 1.25), 0.4)
		tween.tween_property(new_record_label, "scale", Vector2(0.95, 0.95), 0.3)
		tween.tween_property(new_record_label, "scale", Vector2(1.0, 1.0), 0.2)
		# Color cycle
		var color_tw = create_tween().set_loops()
		color_tw.tween_property(new_record_label, "modulate", Color(1, 1, 0.3), 0.4)
		color_tw.tween_property(new_record_label, "modulate", Color(1, 0.6, 0.9), 0.4)
		color_tw.tween_property(new_record_label, "modulate", Color(0.5, 1, 0.8), 0.4)
		color_tw.tween_property(new_record_label, "modulate", Color(1, 1, 1), 0.3)
		# Spawn confetti burst
		_spawn_confetti(24)
	else:
		new_record_label.visible = false
		_spawn_confetti(10)

	continue_btn.pressed.connect(_on_continue_pressed)

	# Spawn animated mascot droplet
	_spawn_score_mascot(total_score, rounds)

	if AudioManager:
		AudioManager.play_music("results", 0.5)
		await get_tree().create_timer(0.3).timeout
		AudioManager.play_fanfare()
		if is_new_record:
			await get_tree().create_timer(0.5).timeout
			AudioManager.play_bonus()

func _build_animated_background(is_new_record: bool) -> void:
	# Replace the static dark background with a gradient feel
	var bg = get_node_or_null("ColorRect")
	if bg:
		if is_new_record:
			bg.color = Color(0.04, 0.1, 0.22, 1)
		else:
			bg.color = Color(0.03, 0.08, 0.18, 1)

	# Add animated gradient overlay
	var grad_overlay = ColorRect.new()
	grad_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad_overlay.color = Color(0.1, 0.3, 0.6, 0.12)
	grad_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad_overlay)
	move_child(grad_overlay, 1)  # Right after bg

	# Pulse the gradient
	var gt = create_tween().set_loops()
	gt.tween_property(grad_overlay, "color:a", 0.2, 2.0).set_trans(Tween.TRANS_SINE)
	gt.tween_property(grad_overlay, "color:a", 0.06, 2.0).set_trans(Tween.TRANS_SINE)

func _spawn_bg_particles() -> void:
	var vp = get_viewport_rect().size
	for i in 20:
		var p = ColorRect.new()
		var sz = randf_range(2, 6)
		p.size = Vector2(sz, sz)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.rotation = randf_range(0, TAU)
		p.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		p.color = Color(
			randf_range(0.4, 1.0),
			randf_range(0.7, 1.0),
			1.0,
			randf_range(0.15, 0.4)
		)
		add_child(p)
		move_child(p, 2)
		_bg_particles.append(p)

		# Floating drift animation
		var drift_x = randf_range(-30, 30)
		var drift_y = randf_range(-60, -20)
		var dur = randf_range(3.0, 6.0)
		var pt = create_tween().set_loops()
		pt.tween_property(p, "position", p.position + Vector2(drift_x, drift_y), dur).set_trans(Tween.TRANS_SINE)
		pt.tween_property(p, "position", p.position, dur).set_trans(Tween.TRANS_SINE)
		# Twinkle
		var at = create_tween().set_loops()
		at.tween_interval(randf_range(0.0, 2.0))
		at.tween_property(p, "modulate:a", 0.3, randf_range(0.8, 1.5))
		at.tween_property(p, "modulate:a", 1.0, randf_range(0.8, 1.5))

func _animate_staggered_entrance(total_score: int, is_new_record: bool) -> void:
	# Main container starts invisible, slides in from below
	var vbox = $CenterContainer/VBoxContainer
	vbox.modulate.a = 0.0
	vbox.position.y += 60

	var enter = create_tween()
	enter.set_parallel(true)
	enter.tween_property(vbox, "modulate:a", 1.0, 0.5)
	enter.tween_property(vbox, "position:y", vbox.position.y - 60, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Score label starts at 0 then counts up
	var score_label_text = Localization.get_text("total_score") if Localization else "TOTAL SCORE"
	var count_tw = create_tween()
	count_tw.tween_interval(0.6)
	count_tw.tween_method(func(val: float):
		total_score_label.text = "%s: %d" % [score_label_text, int(val)]
	, 0.0, float(total_score), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Pop the score label big then settle
	var pop = create_tween()
	pop.tween_interval(1.8)
	pop.tween_property(total_score_label, "scale", Vector2(1.3, 1.3), 0.12)
	pop.tween_property(total_score_label, "scale", Vector2(0.95, 0.95), 0.08)
	pop.tween_property(total_score_label, "scale", Vector2(1.0, 1.0), 0.06)

	# High score label slides in with delay
	high_score_label.modulate.a = 0.0
	var hs_tw = create_tween()
	hs_tw.tween_interval(1.0)
	hs_tw.tween_property(high_score_label, "modulate:a", 1.0, 0.4)

func _spawn_confetti(count: int) -> void:
	var vp = get_viewport_rect().size
	var colors = [
		Color(1, 0.85, 0.2, 0.9),  # Gold
		Color(0.3, 1, 0.5, 0.8),   # Green
		Color(0.5, 0.8, 1, 0.8),   # Blue
		Color(1, 0.5, 0.8, 0.8),   # Pink
		Color(1, 0.6, 0.2, 0.8),   # Orange
		Color(0.7, 0.4, 1, 0.8),   # Purple
	]
	for i in count:
		var c = ColorRect.new()
		var w = randf_range(4, 10)
		var h = randf_range(8, 16)
		c.size = Vector2(w, h)
		c.position = Vector2(randf_range(vp.x * 0.1, vp.x * 0.9), -randf_range(10, 80))
		c.color = colors[i % colors.size()]
		c.rotation = randf_range(0, TAU)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		_confetti.append(c)

		var delay = randf_range(0.0, 1.5)
		var fall_dur = randf_range(2.5, 5.0)
		var end_x = c.position.x + randf_range(-80, 80)
		var end_y = vp.y + 50

		var ct = create_tween()
		ct.tween_interval(delay)
		ct.set_parallel(true)
		ct.tween_property(c, "position", Vector2(end_x, end_y), fall_dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		ct.tween_property(c, "rotation", c.rotation + randf_range(-4, 4), fall_dur)
		ct.tween_property(c, "modulate:a", 0.0, fall_dur * 0.3).set_delay(fall_dur * 0.7)

		# Wobble side-to-side like real confetti
		var wobble = create_tween().set_loops(int(fall_dur / 0.6))
		wobble.tween_interval(delay)
		wobble.tween_property(c, "position:x", c.position.x + randf_range(-25, 25), 0.3).set_trans(Tween.TRANS_SINE)
		wobble.tween_property(c, "position:x", c.position.x + randf_range(-25, 25), 0.3).set_trans(Tween.TRANS_SINE)

func _spawn_score_mascot(total_score: int, rounds: Array) -> void:
	var vp = get_viewport_rect().size
	_droplet = Node2D.new()
	_droplet.position = Vector2(vp.x * 0.82, vp.y * 0.55)
	_droplet.scale = Vector2.ZERO
	_droplet.modulate.a = 0.0
	add_child(_droplet)

	var rank = _compute_rank(total_score)
	var is_happy = rank in ["S", "A", "B"]

	# Body
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(0, -45), Vector2(22, -30), Vector2(32, -5),
		Vector2(28, 18), Vector2(15, 32), Vector2(0, 36),
		Vector2(-15, 32), Vector2(-28, 18), Vector2(-32, -5),
		Vector2(-22, -30),
	])
	body.color = Color(0.35, 0.75, 1.0) if is_happy else Color(0.45, 0.5, 0.8)
	_droplet.add_child(body)

	# Eyes
	for xoff in [-11, 11]:
		var eye = Polygon2D.new()
		var ep = PackedVector2Array()
		for i in range(12):
			var a = i * TAU / 12
			ep.append(Vector2(cos(a) * 7, sin(a) * 7) + Vector2(xoff, -5))
		eye.polygon = ep
		eye.color = Color.WHITE
		_droplet.add_child(eye)
		var pupil = Polygon2D.new()
		var pp = PackedVector2Array()
		for i in range(8):
			var a = i * TAU / 8
			pp.append(Vector2(cos(a) * 3.5, sin(a) * 3.5) + Vector2(xoff, -4))
		pupil.polygon = pp
		pupil.color = Color.BLACK
		_droplet.add_child(pupil)

	# Mouth (happy grin or meh face)
	var mouth = Line2D.new()
	mouth.width = 2.5
	mouth.default_color = Color(0.1, 0.1, 0.1)
	if is_happy:
		for i in range(7):
			var mt = float(i) / 6.0
			var mx = lerp(-14.0, 14.0, mt)
			var my = 8.0 + sin(mt * PI) * 10.0
			mouth.add_point(Vector2(mx, my))
	else:
		for i in range(7):
			var mt = float(i) / 6.0
			var mx = lerp(-12.0, 12.0, mt)
			var my = 14.0 - sin(mt * PI) * 4.0
			mouth.add_point(Vector2(mx, my))
	_droplet.add_child(mouth)

	# Arms
	for side in [-1, 1]:
		var arm = Line2D.new()
		arm.name = "Arm_L" if side < 0 else "Arm_R"
		arm.width = 4.5
		arm.default_color = Color(0.3, 0.68, 0.95)
		arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
		arm.end_cap_mode = Line2D.LINE_CAP_ROUND
		if is_happy:
			arm.add_point(Vector2(side * 28, 0))
			arm.add_point(Vector2(side * 42, -16))
			arm.add_point(Vector2(side * 45, -28))
		else:
			arm.add_point(Vector2(side * 28, 2))
			arm.add_point(Vector2(side * 40, 14))
			arm.add_point(Vector2(side * 38, 26))
		_droplet.add_child(arm)

	# Legs
	for side in [-1, 1]:
		var leg = Line2D.new()
		leg.width = 4.0
		leg.default_color = Color(0.28, 0.62, 0.9)
		leg.add_point(Vector2(side * 10, 34))
		leg.add_point(Vector2(side * 12, 46))
		leg.add_point(Vector2(side * 15, 50))
		leg.begin_cap_mode = Line2D.LINE_CAP_ROUND
		leg.end_cap_mode = Line2D.LINE_CAP_ROUND
		_droplet.add_child(leg)

	# Blush
	if is_happy:
		for sx in [-20, 20]:
			var blush = Polygon2D.new()
			var bp = PackedVector2Array()
			for i in range(8):
				var a = i * TAU / 8
				bp.append(Vector2(cos(a) * 5, sin(a) * 3.5) + Vector2(sx, 5))
			blush.polygon = bp
			blush.color = Color(1, 0.5, 0.5, 0.25)
			_droplet.add_child(blush)

	# Rank badge above head
	var badge = Label.new()
	badge.text = rank
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 38)
	badge.add_theme_color_override("font_color", _rank_color(rank))
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 8)
	badge.position = Vector2(-18, -82)
	_droplet.add_child(badge)

	# Animate mascot entrance
	var enter = create_tween()
	enter.tween_interval(0.8)
	enter.tween_property(_droplet, "modulate:a", 1.0, 0.1)
	enter.tween_property(_droplet, "scale", Vector2(1.3, 0.6), 0.1)
	enter.tween_property(_droplet, "scale", Vector2(0.8, 1.3), 0.1)
	enter.tween_property(_droplet, "scale", Vector2(1.1, 0.9), 0.08)
	enter.tween_property(_droplet, "scale", Vector2(1.0, 1.0), 0.06)

	# Looping idle animation
	if is_happy:
		var idle = create_tween().set_loops()
		idle.tween_interval(0.4)
		idle.tween_property(_droplet, "position:y", _droplet.position.y - 8, 0.5).set_trans(Tween.TRANS_SINE)
		idle.tween_property(_droplet, "scale", Vector2(1.05, 0.95), 0.2)
		idle.tween_property(_droplet, "position:y", _droplet.position.y, 0.5).set_trans(Tween.TRANS_SINE)
		idle.tween_property(_droplet, "scale", Vector2(0.95, 1.05), 0.2)
		idle.tween_property(_droplet, "scale", Vector2(1.0, 1.0), 0.15)

		var arm_l = _droplet.get_node_or_null("Arm_L")
		var arm_r = _droplet.get_node_or_null("Arm_R")
		if arm_l:
			var wave = create_tween().set_loops()
			wave.tween_property(arm_l, "rotation_degrees", -20.0, 0.4)
			wave.tween_property(arm_l, "rotation_degrees", 10.0, 0.4)
			wave.tween_property(arm_l, "rotation_degrees", 0.0, 0.3)
		if arm_r:
			var wave2 = create_tween().set_loops()
			wave2.tween_interval(0.2)
			wave2.tween_property(arm_r, "rotation_degrees", 20.0, 0.4)
			wave2.tween_property(arm_r, "rotation_degrees", -10.0, 0.4)
			wave2.tween_property(arm_r, "rotation_degrees", 0.0, 0.3)
	else:
		# Sad sway
		var idle = create_tween().set_loops()
		idle.tween_property(_droplet, "rotation", 0.06, 1.0).set_trans(Tween.TRANS_SINE)
		idle.tween_property(_droplet, "rotation", -0.06, 1.0).set_trans(Tween.TRANS_SINE)

func _rank_color(rank: String) -> Color:
	match rank:
		"S": return Color(1, 0.85, 0.1)
		"A": return Color(0.3, 1, 0.5)
		"B": return Color(0.5, 0.85, 1)
		"C": return Color(0.9, 0.7, 0.4)
		_: return Color(0.7, 0.5, 0.5)

func _add_rank_and_character(total_score: int, rounds: Array) -> void:
	var vbox = $CenterContainer/VBoxContainer

	var rank = _compute_rank(total_score)
	var rank_label = Label.new()
	rank_label.text = "Rank: %s" % rank
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 42)
	rank_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.9))
	rank_label.add_theme_color_override("font_outline_color", Color.BLACK)
	rank_label.add_theme_constant_override("outline_size", 6)
	vbox.add_child(rank_label)

	var mascot = Label.new()
	mascot.text = _pick_mascot(rounds)
	mascot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mascot.add_theme_font_size_override("font_size", 96)
	vbox.add_child(mascot)

	var line = Label.new()
	line.text = _summary_line(total_score, rounds)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 28)
	line.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	vbox.add_child(line)

	var tw = create_tween().set_loops()
	tw.tween_property(mascot, "scale", Vector2(1.08, 1.08), 0.45)
	tw.tween_property(mascot, "scale", Vector2(1.0, 1.0), 0.45)

func _add_round_breakdown(rounds: Array) -> void:
	if rounds.is_empty():
		return

	var vbox = $CenterContainer/VBoxContainer

	var title = Label.new()
	title.text = "Run Breakdown"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vbox.add_child(title)

	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	for i in range(rounds.size()):
		var row = rounds[i]
		var label = Label.new()
		var combo = int(row.get("combo", 0))
		label.text = "%d. %s | %d pts | combo x%d" % [
			i + 1,
			str(row.get("game", "Unknown")),
			int(row.get("score", 0)),
			combo
		]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		list.add_child(label)

	vbox.add_child(list)

func _compute_rank(total_score: int) -> String:
	if total_score >= 900:
		return "S"
	if total_score >= 700:
		return "A"
	if total_score >= 500:
		return "B"
	if total_score >= 300:
		return "C"
	return "D"

func _pick_mascot(rounds: Array) -> String:
	var success_count = 0
	for row in rounds:
		if int(row.get("score", 0)) > 0:
			success_count += 1
	if rounds.size() > 0 and float(success_count) / float(rounds.size()) >= 0.7:
		return "😎"
	if success_count > 0:
		return "🙂"
	return "😵"

func _summary_line(total_score: int, rounds: Array) -> String:
	if rounds.is_empty():
		return "No rounds played this run."
	var avg = float(total_score) / float(rounds.size())
	if avg >= 120.0:
		return "Legend pace. Water saved like a pro!"
	if avg >= 80.0:
		return "Solid run. Nice consistency!"
	if avg >= 40.0:
		return "Good effort. Keep building combos!"
	return "Rough run. You can bounce back next session!"

func _on_continue_pressed():
	if AudioManager:
		AudioManager.play_click()
	if GameManager:
		GameManager.transition_to_scene("res://scenes/ui/InitialScreen.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")
