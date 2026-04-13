extends Control
class_name SimpleCutscenePlayer

## DWTD-style micro cutscene player - quick animated win/fail reactions
## Generates all graphics procedurally with particles and screen effects

signal cutscene_finished

var _character: Node2D
var _is_playing: bool = false
var _particles: Array[Node] = []
var _game_key: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func play_cutscene(minigame_key: String, cutscene_type) -> void:
	if _is_playing:
		return

	_is_playing = true
	_game_key = minigame_key
	var is_win = (cutscene_type == 0)

	# Play immediate SFX
	if AudioManager:
		if is_win:
			AudioManager.play_success()
		else:
			AudioManager.play_failure()

	await _show_animated_droplet(is_win)
	_is_playing = false
	cutscene_finished.emit()

func _show_animated_droplet(is_win: bool) -> void:
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	# Background with gradient feel
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.14, 0.06, 0.85) if is_win else Color(0.12, 0.03, 0.02, 0.88)
	container.add_child(bg)

	# Flash on entry
	var flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(flash)

	var ft = create_tween()
	ft.tween_property(flash, "color:a", 0.4 if is_win else 0.3, 0.1)
	ft.tween_property(flash, "color:a", 0.0, 0.25)

	# Center
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(center)

	# Build character
	_character = _create_droplet_character(is_win)
	center.add_child(_character)

	# Spawn burst particles
	_spawn_burst_particles(container, is_win)

	# Animate
	await _animate_droplet(is_win)

	# Fade out
	var tween = create_tween()
	tween.tween_property(container, "modulate:a", 0.0, 0.35)
	await tween.finished

	container.queue_free()
	_particles.clear()

func _create_droplet_character(is_win: bool) -> Node2D:
	var character = Node2D.new()

	# ─ Body (DWTD-style round blobby bean person) ─
	var body = Polygon2D.new()
	var body_pts = PackedVector2Array()
	for i in range(20):
		var a = i * TAU / 20
		var rx = 32.0 + sin(a * 2) * 5
		var ry = 40.0 + cos(a * 3) * 4
		body_pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	body.polygon = body_pts
	body.color = Color(0.3, 0.72, 1.0) if is_win else Color(0.45, 0.5, 0.8)
	character.add_child(body)

	# ─ Highlight ─
	var shine = Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-12, -24), Vector2(-4, -28), Vector2(4, -24), Vector2(-4, -16),
	])
	shine.color = Color(1, 1, 1, 0.55)
	character.add_child(shine)

	# ─ Eyes ─
	if is_win:
		character.add_child(_create_eye(Vector2(-13, -8), true))
		character.add_child(_create_eye(Vector2(13, -8), true))
	else:
		# X-EYES for failure (classic cartoon KO)
		for xoff in [-13, 13]:
			var eye_bg = Polygon2D.new()
			var ebpts = PackedVector2Array()
			for i in range(16):
				var a = i * TAU / 16
				ebpts.append(Vector2(cos(a) * 11, sin(a) * 11) + Vector2(xoff, -8))
			eye_bg.polygon = ebpts
			eye_bg.color = Color(0.95, 0.95, 0.95)
			character.add_child(eye_bg)
			for rot_val in [0.785, -0.785]:
				var x_line = Line2D.new()
				x_line.width = 3.5
				x_line.default_color = Color(0.2, 0.2, 0.2)
				# Center points around origin so rotation works correctly
				x_line.add_point(Vector2(-6, -6))
				x_line.add_point(Vector2(6, 6))
				x_line.position = Vector2(xoff, -10)
				x_line.rotation = rot_val
				character.add_child(x_line)

	# ─ Mouth ─
	character.add_child(_create_mouth(is_win))

	# ─ Tongue ─
	if is_win:
		var tongue = Polygon2D.new()
		tongue.polygon = PackedVector2Array([
			Vector2(-5, 20), Vector2(5, 20), Vector2(6, 28),
			Vector2(3, 32), Vector2(-3, 32), Vector2(-6, 28),
		])
		tongue.color = Color(1.0, 0.45, 0.5)
		character.add_child(tongue)
	else:
		# Tongue hanging out sideways — dazed
		var tongue = Polygon2D.new()
		tongue.polygon = PackedVector2Array([
			Vector2(8, 18), Vector2(16, 19), Vector2(18, 26),
			Vector2(14, 32), Vector2(10, 30), Vector2(7, 24),
		])
		tongue.color = Color(1.0, 0.5, 0.55, 0.8)
		character.add_child(tongue)

	# ─ Cheek blush (win only) ─
	if is_win:
		for xoff in [-30, 30]:
			var blush = Polygon2D.new()
			var pts = PackedVector2Array()
			for i in range(8):
				var a = i * TAU / 8
				pts.append(Vector2(cos(a) * 7, sin(a) * 5) + Vector2(xoff, 8))
			blush.polygon = pts
			blush.color = Color(1, 0.5, 0.5, 0.3)
			character.add_child(blush)

	# ─ Arms ─
	var left_arm = Line2D.new()
	left_arm.name = "LeftArm"
	left_arm.width = 5.0
	left_arm.default_color = Color(0.25, 0.65, 0.95) if is_win else Color(0.38, 0.45, 0.72)
	left_arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
	left_arm.end_cap_mode = Line2D.LINE_CAP_ROUND
	if is_win:
		left_arm.add_point(Vector2(-30, 2))
		left_arm.add_point(Vector2(-46, -14))
		left_arm.add_point(Vector2(-52, -30))
	else:
		left_arm.add_point(Vector2(-30, 2))
		left_arm.add_point(Vector2(-44, 18))
		left_arm.add_point(Vector2(-40, 32))
	character.add_child(left_arm)

	var right_arm = Line2D.new()
	right_arm.name = "RightArm"
	right_arm.width = 5.0
	right_arm.default_color = Color(0.25, 0.65, 0.95) if is_win else Color(0.38, 0.45, 0.72)
	right_arm.begin_cap_mode = Line2D.LINE_CAP_ROUND
	right_arm.end_cap_mode = Line2D.LINE_CAP_ROUND
	if is_win:
		right_arm.add_point(Vector2(30, 2))
		right_arm.add_point(Vector2(46, -14))
		right_arm.add_point(Vector2(52, -30))
	else:
		right_arm.add_point(Vector2(30, 2))
		right_arm.add_point(Vector2(44, 18))
		right_arm.add_point(Vector2(40, 32))
	character.add_child(right_arm)

	# ─ Legs ─
	for side in [-1, 1]:
		var leg = Line2D.new()
		leg.name = "Leg_L" if side < 0 else "Leg_R"
		leg.width = 5.0
		leg.default_color = Color(0.22, 0.58, 0.88) if is_win else Color(0.35, 0.42, 0.68)
		leg.add_point(Vector2(side * 12, 38))
		leg.add_point(Vector2(side * 14, 52))
		leg.add_point(Vector2(side * 18, 56))
		leg.begin_cap_mode = Line2D.LINE_CAP_ROUND
		leg.end_cap_mode = Line2D.LINE_CAP_ROUND
		character.add_child(leg)

	# ─ Failure extras: sweat + dizzy stars ─
	if not is_win:
		for idx in range(2):
			var sweat = Polygon2D.new()
			var sx = [-28, 32][idx]
			var sy = [-24, -20][idx]
			sweat.polygon = PackedVector2Array([
				Vector2(0, -5), Vector2(3, 0), Vector2(2, 4),
				Vector2(0, 6), Vector2(-2, 4), Vector2(-3, 0),
			])
			sweat.color = Color(0.6, 0.85, 1.0, 0.7)
			sweat.position = Vector2(sx, sy)
			character.add_child(sweat)

		# Dizzy stars circling above head
		var stars_container = Node2D.new()
		stars_container.name = "DizzyStars"
		stars_container.position = Vector2(0, -75)
		character.add_child(stars_container)
		for i in range(3):
			var star = Label.new()
			star.text = ["⭐", "💫", "✦"][i]
			star.add_theme_font_size_override("font_size", 18)
			star.position = Vector2(cos(i * TAU / 3.0) * 26, sin(i * TAU / 3.0) * 12)
			stars_container.add_child(star)

	return character

func _create_eye(pos: Vector2, is_win: bool) -> Node2D:
	var eye = Node2D.new()
	eye.position = pos

	var white = Polygon2D.new()
	var eye_points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16
		eye_points.append(Vector2(cos(angle), sin(angle)) * 10)
	white.polygon = eye_points
	white.color = Color.WHITE
	eye.add_child(white)

	var pupil = Polygon2D.new()
	var pupil_points = PackedVector2Array()
	for i in range(12):
		var angle = i * TAU / 12
		pupil_points.append(Vector2(cos(angle), sin(angle)) * 5)
	pupil.polygon = pupil_points
	pupil.color = Color.BLACK
	pupil.position = Vector2(0, 2) if not is_win else Vector2(0, -1)
	eye.add_child(pupil)

	# Sparkle in eye for win
	if is_win:
		var sparkle = Polygon2D.new()
		var sp = PackedVector2Array()
		for i in range(6):
			var a = i * TAU / 6
			sp.append(Vector2(cos(a), sin(a)) * 1.5)
		sparkle.polygon = sp
		sparkle.color = Color.WHITE
		sparkle.position = Vector2(-2, -3)
		eye.add_child(sparkle)

	return eye

func _create_mouth(is_win: bool) -> Line2D:
	var mouth = Line2D.new()
	mouth.width = 3
	mouth.default_color = Color(0.15, 0.15, 0.15)

	if is_win:
		# Big happy open smile
		for i in range(7):
			var t = float(i) / 6.0
			var x = lerp(-22.0, 22.0, t)
			var y = 10.0 + sin(t * PI) * 12.0
			mouth.add_point(Vector2(x, y))
	else:
		# Wobbly frown
		for i in range(7):
			var t = float(i) / 6.0
			var x = lerp(-18.0, 18.0, t)
			var y = 22.0 - sin(t * PI) * 8.0
			mouth.add_point(Vector2(x, y))

	return mouth

func _spawn_burst_particles(container: Control, is_win: bool) -> void:
	var vp = get_viewport_rect().size
	var center = vp / 2
	var count = 14 if is_win else 8

	for i in count:
		var p = ColorRect.new()
		var sz = randf_range(4, 12)
		p.size = Vector2(sz, sz)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.modulate.a = 0.0
		p.position = center + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		p.rotation = randf_range(0, TAU)

		if is_win:
			p.color = [
				Color(1.0, 0.95, 0.3, 0.8),
				Color(0.3, 1.0, 0.5, 0.7),
				Color(0.5, 0.8, 1.0, 0.6),
				Color(1.0, 0.6, 0.9, 0.7),
			][i % 4]
		else:
			p.color = Color(0.4, 0.45, 0.7, 0.5)

		container.add_child(p)
		_particles.append(p)

		# Explode outward from center
		var angle = TAU * float(i) / float(count) + randf_range(-0.2, 0.2)
		var dist = randf_range(80, 220)
		var target = center + Vector2(cos(angle), sin(angle)) * dist
		var dur = randf_range(0.4, 0.8)

		var pt = create_tween()
		pt.set_parallel(true)
		pt.tween_property(p, "modulate:a", 0.9, 0.08)
		pt.tween_property(p, "position", target, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		pt.tween_property(p, "rotation", p.rotation + randf_range(-2, 2), dur)

		var pf = create_tween()
		pf.tween_interval(dur * 0.5)
		pf.tween_property(p, "modulate:a", 0.0, dur * 0.5)

func _animate_droplet(is_win: bool) -> void:
	if not _character:
		return

	_character.modulate.a = 0.0
	_character.scale = Vector2(0.05, 0.05)

	if is_win:
		# ══ WIN: Rocket in from below with triumphant landing ══
		_character.position.y += 120

		var enter = create_tween()
		enter.tween_property(_character, "modulate:a", 1.0, 0.06)
		# Rocket up (stretched tall)
		enter.tween_property(_character, "scale", Vector2(0.7, 1.5), 0.12)
		enter.tween_property(_character, "position:y", _character.position.y - 140, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		# Squash on "landing" — EXTREME pancake
		enter.tween_property(_character, "scale", Vector2(1.6, 0.4), 0.08)
		enter.tween_callback(func():
			if AudioManager: AudioManager.play_click()
		)
		# Spring up tall
		enter.tween_property(_character, "scale", Vector2(0.7, 1.4), 0.1)
		# Bounce settle
		enter.tween_property(_character, "scale", Vector2(1.2, 0.8), 0.08)
		enter.tween_property(_character, "scale", Vector2(0.95, 1.05), 0.06)
		enter.tween_property(_character, "scale", Vector2(1.0, 1.0), 0.05)
		await enter.finished

		# Victory spin!
		var spin = create_tween()
		spin.tween_property(_character, "rotation", TAU, 0.35).set_ease(Tween.EASE_IN_OUT)
		spin.tween_property(_character, "rotation", 0.0, 0.01)
		await spin.finished

		# Fist pump + silly dance
		var left_arm = _character.get_node_or_null("LeftArm")
		var right_arm = _character.get_node_or_null("RightArm")
		if left_arm and right_arm:
			var pump = create_tween().set_loops(5)
			pump.tween_property(left_arm, "rotation_degrees", -30.0, 0.08)
			pump.tween_property(left_arm, "rotation_degrees", 10.0, 0.08)
			pump.tween_property(left_arm, "rotation_degrees", 0.0, 0.06)
			var pump2 = create_tween().set_loops(5)
			pump2.tween_property(right_arm, "rotation_degrees", 30.0, 0.08)
			pump2.tween_property(right_arm, "rotation_degrees", -10.0, 0.08)
			pump2.tween_property(right_arm, "rotation_degrees", 0.0, 0.06)

		# Happy bounce dance
		var dance = create_tween().set_loops(4)
		dance.tween_property(_character, "scale", Vector2(1.2, 0.7), 0.07)
		dance.tween_property(_character, "position:y", _character.position.y - 25, 0.1).set_ease(Tween.EASE_OUT)
		dance.tween_property(_character, "scale", Vector2(0.8, 1.3), 0.07)
		dance.tween_property(_character, "position:y", _character.position.y, 0.1).set_ease(Tween.EASE_IN)
		dance.tween_property(_character, "scale", Vector2(1.4, 0.5), 0.06)
		dance.tween_property(_character, "scale", Vector2(1.0, 1.0), 0.06)
		await dance.finished

		# Leg kick during hold
		var leg_l = _character.get_node_or_null("Leg_L")
		var leg_r = _character.get_node_or_null("Leg_R")
		if leg_l and leg_r:
			var kick = create_tween().set_loops(4)
			kick.tween_property(leg_l, "rotation_degrees", -25.0, 0.08)
			kick.tween_property(leg_l, "rotation_degrees", 0.0, 0.08)
			var kick2 = create_tween().set_loops(4)
			kick2.tween_property(leg_r, "rotation_degrees", 25.0, 0.08)
			kick2.tween_property(leg_r, "rotation_degrees", 0.0, 0.08)

		await get_tree().create_timer(1.5).timeout
	else:
		# ══ FAIL: Fall from sky, face-plant splat ══
		_character.position.y -= 150
		_character.scale = Vector2(0.6, 1.5)  # Stretched from falling

		var fall = create_tween()
		fall.tween_property(_character, "modulate:a", 1.0, 0.05)
		# Accelerate downward
		fall.tween_property(
			_character, "position:y", _character.position.y + 150, 0.25
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		fall.tween_callback(func():
			if AudioManager: AudioManager.play_damage()
		)
		# EXTREME SPLAT — total pancake
		fall.tween_property(_character, "scale", Vector2(2.0, 0.25), 0.06)
		# Jelly recovery attempt
		fall.tween_property(_character, "scale", Vector2(0.5, 1.6), 0.15)
		fall.tween_property(_character, "scale", Vector2(1.3, 0.7), 0.1)
		fall.tween_property(_character, "scale", Vector2(0.9, 1.1), 0.08)
		fall.tween_property(_character, "scale", Vector2(1.0, 1.0), 0.07)
		await fall.finished

		# Violent dizzy shake
		var shake = create_tween()
		for k in range(8):
			var dir = 1.0 if k % 2 == 0 else -1.0
			var mag = 0.25 - k * 0.028
			shake.tween_property(_character, "rotation", dir * mag, 0.05)
		shake.tween_property(_character, "rotation", 0.0, 0.06)
		await shake.finished

		# Spin dizzy stars
		var dizzy_stars = _character.get_node_or_null("DizzyStars")
		if dizzy_stars:
			var star_spin = create_tween().set_loops(6)
			star_spin.tween_property(dizzy_stars, "rotation", dizzy_stars.rotation + TAU, 0.55).set_trans(Tween.TRANS_LINEAR)

		# Limp arms swinging
		var left_arm = _character.get_node_or_null("LeftArm")
		var right_arm = _character.get_node_or_null("RightArm")
		if left_arm:
			var limp = create_tween().set_loops(4)
			limp.tween_property(left_arm, "rotation_degrees", 18.0, 0.18)
			limp.tween_property(left_arm, "rotation_degrees", 5.0, 0.25)
		if right_arm:
			var limp2 = create_tween().set_loops(4)
			limp2.tween_property(right_arm, "rotation_degrees", -15.0, 0.18)
			limp2.tween_property(right_arm, "rotation_degrees", -3.0, 0.25)

		# Slow dejected shrink
		var sad = create_tween()
		sad.tween_property(_character, "scale", Vector2(0.82, 0.82), 0.4)
		sad.tween_property(_character, "rotation", -0.1, 0.3)

		await get_tree().create_timer(1.5).timeout
