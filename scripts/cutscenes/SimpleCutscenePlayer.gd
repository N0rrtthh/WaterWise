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
			AudioManager.play_music("outcome_win", 0.15)
		else:
			AudioManager.play_failure()
			AudioManager.play_music("outcome_fail", 0.15)

	await _show_animated_droplet(is_win)
	_is_playing = false
	cutscene_finished.emit()

func _show_animated_droplet(is_win: bool) -> void:
	var scene_data = _get_scene_data(_game_key, is_win)
	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	# Per-game background color
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var default_bg = Color(0.02, 0.14, 0.06, 0.85) if is_win else Color(0.12, 0.03, 0.02, 0.88)
	bg.color = scene_data.get("bg", default_bg)
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

	# Scene-specific props (render behind character for depth)
	var vp = get_viewport_rect().size
	_spawn_scene_props(container, scene_data, vp)

	# Center area for character
	var center = Control.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(center)

	# Build character and position at viewport center
	_character = _create_droplet_character(is_win)
	_character.position = Vector2(vp.x * 0.5, vp.y * 0.5)
	center.add_child(_character)

	# Scene flavor text (lower portion of screen, fades in after 0.45s)
	var scene_text: String = scene_data.get("text", "")
	if not scene_text.is_empty():
		var text_lbl = Label.new()
		text_lbl.text = scene_text
		text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_lbl.add_theme_font_size_override("font_size", 26)
		text_lbl.add_theme_color_override(
			"font_color",
			Color(1.0, 1.0, 0.82) if is_win else Color(1.0, 0.78, 0.65)
		)
		text_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
		text_lbl.add_theme_constant_override("outline_size", 5)
		text_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		text_lbl.anchor_top = 0.76
		text_lbl.anchor_bottom = 1.0
		text_lbl.offset_left = 24
		text_lbl.offset_right = -24
		text_lbl.modulate.a = 0.0
		text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(text_lbl)
		var ttw = create_tween()
		ttw.tween_interval(0.45)
		ttw.tween_property(text_lbl, "modulate:a", 1.0, 0.3)

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
		pt.tween_property(
			p, "position", target, dur
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		pt.tween_property(p, "rotation", p.rotation + randf_range(-2, 2), dur)

		var pf = create_tween()
		pf.tween_interval(dur * 0.5)
		pf.tween_property(p, "modulate:a", 0.0, dur * 0.5)

func _animate_droplet(is_win: bool) -> void:
	if not _character:
		return

	var rest_pos = _character.position
	_character.modulate.a = 0.0
	_character.scale = Vector2(0.05, 0.05)

	if is_win:
		# ══ WIN: Rocket in from below with triumphant landing ══
		_character.position.y = rest_pos.y + 120

		var enter = create_tween()
		enter.tween_property(_character, "modulate:a", 1.0, 0.06)
		# Rocket up (stretched tall)
		enter.tween_property(_character, "scale", Vector2(0.7, 1.5), 0.12)
		enter.tween_property(
			_character, "position:y",
			rest_pos.y - 20, 0.22
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
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
		# Land at rest position
		enter.tween_property(_character, "position:y", rest_pos.y, 0.1)
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
		dance.tween_property(
			_character, "position:y",
			rest_pos.y - 25, 0.1
		).set_ease(Tween.EASE_OUT)
		dance.tween_property(_character, "scale", Vector2(0.8, 1.3), 0.07)
		dance.tween_property(_character, "position:y", rest_pos.y, 0.1).set_ease(Tween.EASE_IN)
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
		_character.position.y = rest_pos.y - 150
		_character.scale = Vector2(0.6, 1.5)  # Stretched from falling

		var fall = create_tween()
		fall.tween_property(_character, "modulate:a", 1.0, 0.05)
		# Accelerate downward
		fall.tween_property(
			_character, "position:y", rest_pos.y, 0.25
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
			star_spin.tween_property(
				dizzy_stars, "rotation",
				dizzy_stars.rotation + TAU, 0.55
			).set_trans(Tween.TRANS_LINEAR)

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

## ─────────────────────────────────────────────────────────────────
## SCENE PROPS — per-game animated emoji stage dressing
## ─────────────────────────────────────────────────────────────────

func _spawn_scene_props(container: Control, scene_data: Dictionary, vp: Vector2) -> void:
	var props: Array = scene_data.get("props", [])
	for p_data in props:
		var emoji: String = p_data.get("e", "")
		if emoji.is_empty():
			continue
		var font_sz: int = p_data.get("size", 64)
		var lbl = Label.new()
		lbl.text = emoji
		lbl.add_theme_font_size_override("font_size", font_sz)
		lbl.modulate.a = 0.0
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# nx/ny are normalized [0..1] viewport fractions
		var nx: float = p_data.get("x", 0.5)
		var ny: float = p_data.get("y", 0.5)
		var base_x := vp.x * nx - font_sz * 0.5
		var base_y := vp.y * ny - font_sz * 0.5
		lbl.position = Vector2(base_x, base_y)
		container.add_child(lbl)

		var delay: float = p_data.get("delay", 0.0)
		var anim_type: String = p_data.get("anim", "pop")

		# Fade in
		var show_tw = create_tween()
		show_tw.tween_interval(delay)
		show_tw.tween_property(lbl, "modulate:a", 1.0, 0.18)

		# Anim type
		match anim_type:
			"bounce":
				var tw = create_tween().set_loops(6)
				tw.tween_interval(delay + 0.22)
				tw.tween_property(lbl, "position:y", base_y - 18, 0.2).set_ease(Tween.EASE_OUT)
				tw.tween_property(lbl, "position:y", base_y, 0.2).set_ease(Tween.EASE_IN)
			"float":
				var tw = create_tween()
				tw.tween_interval(delay + 0.12)
				tw.tween_property(lbl, "position:y", base_y - 88, 1.5).set_ease(Tween.EASE_OUT)
				var ftw = create_tween()
				ftw.tween_interval(delay + 0.75)
				ftw.tween_property(lbl, "modulate:a", 0.0, 0.85)
			"fall":
				lbl.position.y = base_y - 110
				var tw = create_tween()
				tw.tween_interval(delay)
				tw.tween_property(lbl, "position:y", base_y, 0.38).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
			"shake":
				var tw = create_tween().set_loops(7)
				tw.tween_interval(delay + 0.18)
				tw.tween_property(lbl, "rotation", 0.18, 0.08)
				tw.tween_property(lbl, "rotation", -0.18, 0.08)
				tw.tween_property(lbl, "rotation", 0.0, 0.06)
			"spin":
				var tw = create_tween()
				tw.tween_interval(delay)
				tw.tween_property(lbl, "rotation", TAU * 2.0, 1.5).set_trans(Tween.TRANS_LINEAR)
			"pop":
				lbl.scale = Vector2(0.05, 0.05)
				var tw = create_tween()
				tw.tween_interval(delay)
				tw.tween_property(lbl, "scale", Vector2(1.35, 1.35), 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1)
			"fly_away":
				var dir_x = 1.0 if base_x > vp.x * 0.5 else -1.0
				var tw = create_tween()
				tw.tween_interval(delay + 0.38)
				tw.set_parallel(true)
				tw.tween_property(lbl, "position:x", base_x + dir_x * 280, 0.52).set_ease(Tween.EASE_IN)
				tw.tween_property(lbl, "position:y", base_y - 55, 0.38).set_ease(Tween.EASE_OUT)
				tw.tween_property(lbl, "modulate:a", 0.0, 0.42)
			"fill_up":
				lbl.pivot_offset = Vector2(font_sz * 0.5, font_sz)
				lbl.scale = Vector2(1.0, 0.12)
				var tw = create_tween()
				tw.tween_interval(delay + 0.18)
				tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.55).set_ease(Tween.EASE_OUT)
			"drip":
				var tw = create_tween().set_loops(4)
				tw.tween_interval(delay + 0.18)
				tw.tween_property(lbl, "position:y", base_y + 22, 0.32).set_ease(Tween.EASE_IN)
				tw.tween_property(lbl, "modulate:a", 0.35, 0.14)
				tw.tween_property(lbl, "position:y", base_y, 0.06)
				tw.tween_property(lbl, "modulate:a", 1.0, 0.1)

## ─────────────────────────────────────────────────────────────────
## PER-GAME SCENE DATA  (bg color + emoji props + flavor text)
## Covers all 20 SP + 12 MP minigames; win and fail variants.
## ─────────────────────────────────────────────────────────────────

func _get_scene_data(key: String, is_win: bool) -> Dictionary:
	var outcome := "win" if is_win else "fail"
	var default_bg = Color(0.02, 0.14, 0.06, 0.85) if is_win else Color(0.12, 0.03, 0.02, 0.88)
	var scenes: Dictionary = {
		"CatchTheRain": {
			"win": {
				"bg": Color(0.08, 0.18, 0.38, 0.88),
				"props": [
					{"e": "☁️", "x": 0.5, "y": 0.12, "size": 80, "anim": "bounce", "delay": 0.0},
					{"e": "🌧️", "x": 0.3, "y": 0.22, "size": 52, "anim": "fall", "delay": 0.15},
					{"e": "🌧️", "x": 0.7, "y": 0.22, "size": 52, "anim": "fall", "delay": 0.28},
					{"e": "🛢️", "x": 0.5, "y": 0.8, "size": 76, "anim": "fill_up", "delay": 0.32},
					{"e": "🌈", "x": 0.74, "y": 0.1, "size": 56, "anim": "pop", "delay": 0.85},
				],
				"text": "The drum overflows with glory!",
			},
			"fail": {
				"bg": Color(0.12, 0.12, 0.2, 0.88),
				"props": [
					{"e": "☁️", "x": 0.5, "y": 0.12, "size": 72, "anim": "shake", "delay": 0.0},
					{"e": "🌧️", "x": 0.22, "y": 0.24, "size": 48, "anim": "fall", "delay": 0.12},
					{"e": "🌧️", "x": 0.78, "y": 0.26, "size": 48, "anim": "fall", "delay": 0.24},
					{"e": "🪣", "x": 0.5, "y": 0.8, "size": 68, "anim": "pop", "delay": 0.1},
					{"e": "💀", "x": 0.8, "y": 0.76, "size": 44, "anim": "pop", "delay": 0.72},
				],
				"text": "Mystery liquid fills the drum. A plant dies.",
			},
		},
		"CoverTheDrum": {
			"win": {
				"bg": Color(0.05, 0.22, 0.15, 0.88),
				"props": [
					{"e": "🛢️", "x": 0.5, "y": 0.78, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "🦟", "x": 0.22, "y": 0.32, "size": 52, "anim": "fly_away", "delay": 0.32},
					{"e": "🦟", "x": 0.75, "y": 0.36, "size": 48, "anim": "fly_away", "delay": 0.48},
					{"e": "✅", "x": 0.78, "y": 0.72, "size": 52, "anim": "pop", "delay": 0.62},
				],
				"text": "Mosquitoes hold a sad little funeral.",
			},
			"fail": {
				"bg": Color(0.18, 0.06, 0.18, 0.88),
				"props": [
					{"e": "🛢️", "x": 0.5, "y": 0.78, "size": 80, "anim": "shake", "delay": 0.0},
					{"e": "🦟", "x": 0.38, "y": 0.28, "size": 64, "anim": "bounce", "delay": 0.22},
					{"e": "🦟", "x": 0.65, "y": 0.22, "size": 52, "anim": "spin", "delay": 0.42},
					{"e": "🏠", "x": 0.16, "y": 0.72, "size": 52, "anim": "pop", "delay": 0.62},
				],
				"text": "A mosquito the size of a fist claims the drum as a condo.",
			},
		},
		"DropletDash": {
			"win": {
				"bg": Color(0.05, 0.25, 0.42, 0.88),
				"props": [
					{"e": "💧", "x": 0.22, "y": 0.3, "size": 60, "anim": "bounce", "delay": 0.0},
					{"e": "💧", "x": 0.75, "y": 0.25, "size": 52, "anim": "bounce", "delay": 0.15},
					{"e": "🫙", "x": 0.5, "y": 0.78, "size": 76, "anim": "fill_up", "delay": 0.38},
					{"e": "✨", "x": 0.78, "y": 0.68, "size": 48, "anim": "float", "delay": 0.6},
				],
				"text": "Every drop caught. The droplets look betrayed.",
			},
			"fail": {
				"bg": Color(0.18, 0.18, 0.25, 0.88),
				"props": [
					{"e": "💧", "x": 0.22, "y": 0.28, "size": 60, "anim": "fly_away", "delay": 0.1},
					{"e": "💧", "x": 0.72, "y": 0.22, "size": 52, "anim": "fly_away", "delay": 0.25},
					{"e": "🫙", "x": 0.5, "y": 0.78, "size": 76, "anim": "shake", "delay": 0.18},
					{"e": "😢", "x": 0.16, "y": 0.7, "size": 52, "anim": "pop", "delay": 0.52},
				],
				"text": "The last droplet waves goodbye. Glass is empty.",
			},
		},
		"FilterBuilder": {
			"win": {
				"bg": Color(0.05, 0.22, 0.28, 0.88),
				"props": [
					{"e": "🧪", "x": 0.5, "y": 0.78, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "✨", "x": 0.25, "y": 0.3, "size": 56, "anim": "float", "delay": 0.38},
					{"e": "💧", "x": 0.75, "y": 0.32, "size": 52, "anim": "float", "delay": 0.52},
					{"e": "🌟", "x": 0.5, "y": 0.18, "size": 60, "anim": "spin", "delay": 0.6},
				],
				"text": "Sparkling clean water. A child drinks gratefully.",
			},
			"fail": {
				"bg": Color(0.22, 0.16, 0.06, 0.88),
				"props": [
					{"e": "🧪", "x": 0.5, "y": 0.75, "size": 76, "anim": "shake", "delay": 0.0},
					{"e": "🤢", "x": 0.78, "y": 0.48, "size": 52, "anim": "pop", "delay": 0.5},
				],
				"text": "Wrong order. It looks like gravy. No one drinks that.",
			},
		},
		"FixLeak": {
			"win": {
				"bg": Color(0.05, 0.22, 0.35, 0.88),
				"props": [
					{"e": "🔧", "x": 0.5, "y": 0.3, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "🚰", "x": 0.5, "y": 0.78, "size": 72, "anim": "pop", "delay": 0.2},
					{"e": "💧", "x": 0.62, "y": 0.7, "size": 36, "anim": "float", "delay": 0.72},
					{"e": "🫡", "x": 0.75, "y": 0.48, "size": 56, "anim": "pop", "delay": 0.82},
				],
				"text": "Silence. Peace. A single drip salutes you.",
			},
			"fail": {
				"bg": Color(0.06, 0.12, 0.28, 0.92),
				"props": [
					{"e": "💦", "x": 0.3, "y": 0.22, "size": 64, "anim": "fall", "delay": 0.0},
					{"e": "💦", "x": 0.6, "y": 0.18, "size": 64, "anim": "fall", "delay": 0.15},
					{"e": "💦", "x": 0.15, "y": 0.32, "size": 52, "anim": "fall", "delay": 0.3},
					{"e": "🌊", "x": 0.5, "y": 0.85, "size": 80, "anim": "pop", "delay": 0.42},
				],
				"text": "Three more burst open. The room is now a splash park!",
			},
		},
		"PlugTheLeak": {
			"win": {
				"bg": Color(0.05, 0.22, 0.35, 0.88),
				"props": [
					{"e": "🔧", "x": 0.5, "y": 0.3, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "🚰", "x": 0.5, "y": 0.78, "size": 72, "anim": "pop", "delay": 0.2},
					{"e": "💧", "x": 0.62, "y": 0.7, "size": 36, "anim": "float", "delay": 0.72},
					{"e": "🫡", "x": 0.75, "y": 0.48, "size": 56, "anim": "pop", "delay": 0.82},
				],
				"text": "Silence. Peace. A single drip salutes you.",
			},
			"fail": {
				"bg": Color(0.06, 0.12, 0.28, 0.92),
				"props": [
					{"e": "💦", "x": 0.3, "y": 0.22, "size": 64, "anim": "fall", "delay": 0.0},
					{"e": "💦", "x": 0.6, "y": 0.18, "size": 64, "anim": "fall", "delay": 0.15},
					{"e": "💦", "x": 0.15, "y": 0.32, "size": 52, "anim": "fall", "delay": 0.3},
					{"e": "🌊", "x": 0.5, "y": 0.85, "size": 80, "anim": "pop", "delay": 0.42},
				],
				"text": "Three more burst open. The room is now a splash park!",
			},
		},
		"GreywaterSorter": {
			"win": {
				"bg": Color(0.08, 0.25, 0.08, 0.88),
				"props": [
					{"e": "🪣", "x": 0.3, "y": 0.68, "size": 72, "anim": "pop", "delay": 0.0},
					{"e": "🌸", "x": 0.72, "y": 0.62, "size": 60, "anim": "pop", "delay": 0.3},
					{"e": "🌿", "x": 0.5, "y": 0.78, "size": 60, "anim": "bounce", "delay": 0.5},
				],
				"text": "Every bucket sorted. The garden blooms!",
			},
			"fail": {
				"bg": Color(0.18, 0.15, 0.05, 0.88),
				"props": [
					{"e": "🍅", "x": 0.5, "y": 0.72, "size": 76, "anim": "shake", "delay": 0.0},
					{"e": "🧼", "x": 0.3, "y": 0.3, "size": 60, "anim": "fall", "delay": 0.22},
					{"e": "😭", "x": 0.75, "y": 0.55, "size": 52, "anim": "pop", "delay": 0.62},
				],
				"text": "Soapy water hits the tomatoes. The tomatoes had a name.",
			},
		},
		"BucketBrigade": {
			"win": {
				"bg": Color(0.2, 0.22, 0.05, 0.88),
				"props": [
					{"e": "🪣", "x": 0.22, "y": 0.42, "size": 72, "anim": "bounce", "delay": 0.0},
					{"e": "🪣", "x": 0.5, "y": 0.38, "size": 72, "anim": "bounce", "delay": 0.15},
					{"e": "🌿", "x": 0.78, "y": 0.72, "size": 68, "anim": "pop", "delay": 0.4},
					{"e": "🎉", "x": 0.5, "y": 0.18, "size": 60, "anim": "float", "delay": 0.6},
				],
				"text": "TEAMWORK! — someone shouts it unironically.",
			},
			"fail": {
				"bg": Color(0.2, 0.15, 0.05, 0.88),
				"props": [
					{"e": "🪣", "x": 0.5, "y": 0.45, "size": 72, "anim": "shake", "delay": 0.0},
					{"e": "🥪", "x": 0.75, "y": 0.42, "size": 60, "anim": "pop", "delay": 0.42},
					{"e": "🌱", "x": 0.22, "y": 0.72, "size": 56, "anim": "shake", "delay": 0.62},
				],
				"text": "Third person eats a sandwich. The plant writes a letter.",
			},
		},
		"QuickShower": {
			"win": {
				"bg": Color(0.05, 0.22, 0.35, 0.88),
				"props": [
					{"e": "🚿", "x": 0.5, "y": 0.72, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "👍", "x": 0.75, "y": 0.48, "size": 60, "anim": "pop", "delay": 0.52},
					{"e": "✨", "x": 0.25, "y": 0.3, "size": 52, "anim": "float", "delay": 0.62},
				],
				"text": "Clean. Efficient. The water meter gives a thumbs up.",
			},
			"fail": {
				"bg": Color(0.05, 0.1, 0.32, 0.92),
				"props": [
					{"e": "🚿", "x": 0.5, "y": 0.62, "size": 80, "anim": "shake", "delay": 0.0},
					{"e": "💸", "x": 0.75, "y": 0.32, "size": 60, "anim": "fly_away", "delay": 0.3},
					{"e": "💥", "x": 0.28, "y": 0.38, "size": 64, "anim": "pop", "delay": 0.52},
				],
				"text": "The meter explodes. You're clean but the planet is not.",
			},
		},
		"RiceWashRescue": {
			"win": {
				"bg": Color(0.06, 0.15, 0.12, 0.9),
				"props": [
					{"e": "🍚", "x": 0.5, "y": 0.28, "size": 76, "anim": "bounce", "delay": 0.0},
					{"e": "💧", "x": 0.35, "y": 0.5, "size": 52, "anim": "float", "delay": 0.2},
					{"e": "💧", "x": 0.65, "y": 0.45, "size": 48, "anim": "float", "delay": 0.35},
					{"e": "🌱", "x": 0.78, "y": 0.68, "size": 56, "anim": "pop", "delay": 0.72},
				],
				"text": "Precious starchy water saved. The plants are very happy.",
			},
			"fail": {
				"bg": Color(0.18, 0.14, 0.06, 0.88),
				"props": [
					{"e": "🍚", "x": 0.5, "y": 0.28, "size": 72, "anim": "shake", "delay": 0.0},
					{"e": "🌊", "x": 0.5, "y": 0.82, "size": 72, "anim": "pop", "delay": 0.22},
					{"e": "😔", "x": 0.75, "y": 0.52, "size": 52, "anim": "pop", "delay": 0.62},
				],
				"text": "A single grain of rice rolls away in disappointment.",
			},
		},
		"ScrubToSave": {
			"win": {
				"bg": Color(0.05, 0.2, 0.32, 0.88),
				"props": [
					{"e": "🍽️", "x": 0.5, "y": 0.72, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "✨", "x": 0.62, "y": 0.6, "size": 44, "anim": "float", "delay": 0.3},
					{"e": "🍴", "x": 0.75, "y": 0.68, "size": 52, "anim": "bounce", "delay": 0.52},
				],
				"text": "Spotless! A fork nearby applauds.",
			},
			"fail": {
				"bg": Color(0.18, 0.16, 0.12, 0.88),
				"props": [
					{"e": "🍽️", "x": 0.5, "y": 0.72, "size": 80, "anim": "shake", "delay": 0.0},
					{"e": "👀", "x": 0.72, "y": 0.48, "size": 56, "anim": "pop", "delay": 0.52},
				],
				"text": "The dish does not sparkle. It judges you.",
			},
		},
		"SpotTheSpeck": {
			"win": {
				"bg": Color(0.05, 0.25, 0.4, 0.88),
				"props": [
					{"e": "🔍", "x": 0.5, "y": 0.3, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "🥛", "x": 0.3, "y": 0.72, "size": 64, "anim": "pop", "delay": 0.22},
					{"e": "🥛", "x": 0.7, "y": 0.72, "size": 64, "anim": "pop", "delay": 0.32},
					{"e": "✅", "x": 0.72, "y": 0.28, "size": 52, "anim": "pop", "delay": 0.62},
				],
				"text": "All impurities spotted. Add it to your resume.",
			},
			"fail": {
				"bg": Color(0.2, 0.18, 0.1, 0.88),
				"props": [
					{"e": "🔍", "x": 0.5, "y": 0.28, "size": 72, "anim": "shake", "delay": 0.0},
					{"e": "🥛", "x": 0.5, "y": 0.72, "size": 76, "anim": "bounce", "delay": 0.22},
					{"e": "😨", "x": 0.22, "y": 0.48, "size": 56, "anim": "pop", "delay": 0.52},
				],
				"text": "You don't want to know what happens next.",
			},
		},
		"SwipeTheSoap": {
			"win": {
				"bg": Color(0.08, 0.22, 0.32, 0.88),
				"props": [
					{"e": "🧼", "x": 0.5, "y": 0.72, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "👐", "x": 0.5, "y": 0.35, "size": 72, "anim": "pop", "delay": 0.3},
					{"e": "✨", "x": 0.75, "y": 0.5, "size": 48, "anim": "float", "delay": 0.52},
				],
				"text": "Clean hands! The soap bar is impressed.",
			},
			"fail": {
				"bg": Color(0.18, 0.12, 0.06, 0.88),
				"props": [
					{"e": "🧼", "x": 0.5, "y": 0.62, "size": 76, "anim": "fly_away", "delay": 0.1},
					{"e": "🚰", "x": 0.5, "y": 0.78, "size": 68, "anim": "shake", "delay": 0.22},
					{"e": "💧", "x": 0.3, "y": 0.5, "size": 48, "anim": "drip", "delay": 0.4},
					{"e": "💧", "x": 0.7, "y": 0.5, "size": 48, "anim": "drip", "delay": 0.52},
				],
				"text": "The soap lands somewhere outside.",
			},
		},
		"ThirstyPlant": {
			"win": {
				"bg": Color(0.06, 0.22, 0.1, 0.88),
				"props": [
					{"e": "🪣", "x": 0.3, "y": 0.42, "size": 68, "anim": "pop", "delay": 0.0},
					{"e": "🌿", "x": 0.7, "y": 0.72, "size": 80, "anim": "bounce", "delay": 0.3},
					{"e": "💧", "x": 0.5, "y": 0.25, "size": 52, "anim": "fall", "delay": 0.1},
				],
				"text": "Correct bucket! It grows noticeably. It seems grateful.",
			},
			"fail": {
				"bg": Color(0.2, 0.15, 0.06, 0.88),
				"props": [
					{"e": "🌱", "x": 0.72, "y": 0.72, "size": 72, "anim": "shake", "delay": 0.0},
					{"e": "🪣", "x": 0.3, "y": 0.52, "size": 64, "anim": "pop", "delay": 0.3},
					{"e": "😐", "x": 0.72, "y": 0.35, "size": 52, "anim": "pop", "delay": 0.72},
				],
				"text": "Wrong bucket. The real green one watches silently.",
			},
		},
		"TimingTap": {
			"win": {
				"bg": Color(0.05, 0.2, 0.38, 0.88),
				"props": [
					{"e": "🚰", "x": 0.5, "y": 0.28, "size": 76, "anim": "pop", "delay": 0.0},
					{"e": "🫙", "x": 0.5, "y": 0.78, "size": 76, "anim": "fill_up", "delay": 0.3},
					{"e": "🎯", "x": 0.78, "y": 0.32, "size": 56, "anim": "pop", "delay": 0.52},
				],
				"text": "Perfect fill! The container does a little shimmy.",
			},
			"fail": {
				"bg": Color(0.04, 0.1, 0.28, 0.92),
				"props": [
					{"e": "🚰", "x": 0.5, "y": 0.22, "size": 76, "anim": "shake", "delay": 0.0},
					{"e": "🌊", "x": 0.5, "y": 0.85, "size": 80, "anim": "pop", "delay": 0.3},
					{"e": "😱", "x": 0.22, "y": 0.55, "size": 56, "anim": "pop", "delay": 0.52},
				],
				"text": "It overflows. The floor is now a small lake.",
			},
		},
		"ToiletTankFix": {
			"win": {
				"bg": Color(0.08, 0.2, 0.3, 0.88),
				"props": [
					{"e": "🚽", "x": 0.5, "y": 0.75, "size": 84, "anim": "pop", "delay": 0.0},
					{"e": "🕊️", "x": 0.5, "y": 0.18, "size": 60, "anim": "float", "delay": 0.52},
					{"e": "😌", "x": 0.78, "y": 0.52, "size": 52, "anim": "pop", "delay": 0.72},
				],
				"text": "Peace returns to the household.",
			},
			"fail": {
				"bg": Color(0.05, 0.1, 0.28, 0.92),
				"props": [
					{"e": "🚽", "x": 0.5, "y": 0.72, "size": 84, "anim": "shake", "delay": 0.0},
					{"e": "🌊", "x": 0.5, "y": 0.85, "size": 72, "anim": "pop", "delay": 0.3},
					{"e": "😰", "x": 0.25, "y": 0.42, "size": 56, "anim": "pop", "delay": 0.52},
				],
				"text": "The toilet overflows. The Tuesday leak was less bad.",
			},
		},
		"TracePipePath": {
			"win": {
				"bg": Color(0.06, 0.2, 0.32, 0.88),
				"props": [
					{"e": "🏘️", "x": 0.5, "y": 0.72, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "🎉", "x": 0.28, "y": 0.32, "size": 60, "anim": "float", "delay": 0.4},
					{"e": "🎉", "x": 0.72, "y": 0.28, "size": 56, "anim": "float", "delay": 0.55},
				],
				"text": "Pipe connected correctly. The neighborhood cheers!",
			},
			"fail": {
				"bg": Color(0.05, 0.1, 0.28, 0.92),
				"props": [
					{"e": "🏠", "x": 0.5, "y": 0.72, "size": 80, "anim": "shake", "delay": 0.0},
					{"e": "🚿", "x": 0.3, "y": 0.32, "size": 60, "anim": "fall", "delay": 0.22},
					{"e": "🚿", "x": 0.72, "y": 0.28, "size": 56, "anim": "fall", "delay": 0.36},
					{"e": "😱", "x": 0.22, "y": 0.55, "size": 52, "anim": "pop", "delay": 0.52},
				],
				"text": "Water goes through the kitchen ceiling. Everyone showers.",
			},
		},
		"TurnOffTap": {
			"win": {
				"bg": Color(0.08, 0.22, 0.32, 0.88),
				"props": [
					{"e": "🚰", "x": 0.3, "y": 0.42, "size": 68, "anim": "pop", "delay": 0.0},
					{"e": "🚰", "x": 0.7, "y": 0.38, "size": 68, "anim": "pop", "delay": 0.15},
					{"e": "🤫", "x": 0.5, "y": 0.22, "size": 64, "anim": "pop", "delay": 0.4},
					{"e": "💰", "x": 0.5, "y": 0.78, "size": 60, "anim": "bounce", "delay": 0.72},
				],
				"text": "All taps off. The water bill sighs with relief.",
			},
			"fail": {
				"bg": Color(0.04, 0.1, 0.28, 0.92),
				"props": [
					{"e": "🚰", "x": 0.22, "y": 0.32, "size": 60, "anim": "shake", "delay": 0.0},
					{"e": "🚰", "x": 0.5, "y": 0.28, "size": 64, "anim": "shake", "delay": 0.1},
					{"e": "🚰", "x": 0.78, "y": 0.32, "size": 60, "anim": "shake", "delay": 0.2},
					{"e": "🌊", "x": 0.5, "y": 0.85, "size": 80, "anim": "pop", "delay": 0.42},
				],
				"text": "The house is now a fountain. Kind of beautiful. But wrong.",
			},
		},
		"VegetableBath": {
			"win": {
				"bg": Color(0.08, 0.24, 0.1, 0.88),
				"props": [
					{"e": "🥦", "x": 0.28, "y": 0.62, "size": 68, "anim": "bounce", "delay": 0.0},
					{"e": "🥕", "x": 0.72, "y": 0.65, "size": 64, "anim": "bounce", "delay": 0.2},
					{"e": "✨", "x": 0.5, "y": 0.28, "size": 56, "anim": "float", "delay": 0.5},
					{"e": "😊", "x": 0.5, "y": 0.18, "size": 52, "anim": "pop", "delay": 0.72},
				],
				"text": "Dinner is saved. You're actually useful.",
			},
			"fail": {
				"bg": Color(0.2, 0.15, 0.06, 0.88),
				"props": [
					{"e": "🥕", "x": 0.5, "y": 0.65, "size": 76, "anim": "shake", "delay": 0.0},
					{"e": "😳", "x": 0.5, "y": 0.28, "size": 60, "anim": "pop", "delay": 0.42},
				],
				"text": "Wrong basket. The carrot is ashamed.",
			},
		},
		"WaterMemory": {
			"win": {
				"bg": Color(0.06, 0.18, 0.38, 0.88),
				"props": [
					{"e": "🃏", "x": 0.3, "y": 0.48, "size": 72, "anim": "pop", "delay": 0.0},
					{"e": "🃏", "x": 0.7, "y": 0.48, "size": 72, "anim": "pop", "delay": 0.2},
					{"e": "🧠", "x": 0.5, "y": 0.22, "size": 68, "anim": "bounce", "delay": 0.4},
					{"e": "✨", "x": 0.72, "y": 0.3, "size": 48, "anim": "float", "delay": 0.62},
				],
				"text": "All pairs matched! You will never waste water again.",
			},
			"fail": {
				"bg": Color(0.18, 0.16, 0.2, 0.88),
				"props": [
					{"e": "🃏", "x": 0.3, "y": 0.48, "size": 68, "anim": "shake", "delay": 0.0},
					{"e": "🐢", "x": 0.7, "y": 0.48, "size": 72, "anim": "pop", "delay": 0.22},
					{"e": "❓", "x": 0.5, "y": 0.22, "size": 60, "anim": "bounce", "delay": 0.52},
				],
				"text": "You match 'Don't waste water' with 'Turtle.'",
			},
		},
		"WaterPlant": {
			"win": {
				"bg": Color(0.06, 0.22, 0.1, 0.88),
				"props": [
					{"e": "👕", "x": 0.3, "y": 0.42, "size": 72, "anim": "pop", "delay": 0.0},
					{"e": "🌱", "x": 0.72, "y": 0.72, "size": 72, "anim": "bounce", "delay": 0.3},
					{"e": "💧", "x": 0.5, "y": 0.25, "size": 52, "anim": "fall", "delay": 0.22},
				],
				"text": "Basin full. The water goes to the garden!",
			},
			"fail": {
				"bg": Color(0.18, 0.14, 0.08, 0.88),
				"props": [
					{"e": "👕", "x": 0.5, "y": 0.42, "size": 72, "anim": "drip", "delay": 0.0},
					{"e": "🌱", "x": 0.72, "y": 0.72, "size": 68, "anim": "shake", "delay": 0.3},
					{"e": "😒", "x": 0.22, "y": 0.55, "size": 52, "anim": "pop", "delay": 0.62},
				],
				"text": "Three drops in the basin. The garden sulks.",
			},
		},
		"WringItOut": {
			"win": {
				"bg": Color(0.06, 0.22, 0.1, 0.88),
				"props": [
					{"e": "👕", "x": 0.3, "y": 0.42, "size": 72, "anim": "pop", "delay": 0.0},
					{"e": "🌱", "x": 0.72, "y": 0.72, "size": 72, "anim": "bounce", "delay": 0.3},
					{"e": "💧", "x": 0.5, "y": 0.25, "size": 52, "anim": "fall", "delay": 0.22},
				],
				"text": "Basin full. The water goes to the garden!",
			},
			"fail": {
				"bg": Color(0.18, 0.14, 0.08, 0.88),
				"props": [
					{"e": "👕", "x": 0.5, "y": 0.42, "size": 72, "anim": "drip", "delay": 0.0},
					{"e": "🌱", "x": 0.72, "y": 0.72, "size": 68, "anim": "shake", "delay": 0.3},
					{"e": "😒", "x": 0.22, "y": 0.55, "size": 52, "anim": "pop", "delay": 0.62},
				],
				"text": "Three drops in the basin. The garden sulks.",
			},
		},
		"MudPieMaker": {
			"win": {
				"bg": Color(0.2, 0.14, 0.05, 0.88),
				"props": [
					{"e": "🥧", "x": 0.5, "y": 0.72, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "😄", "x": 0.28, "y": 0.45, "size": 60, "anim": "bounce", "delay": 0.42},
					{"e": "✨", "x": 0.72, "y": 0.42, "size": 52, "anim": "float", "delay": 0.52},
				],
				"text": "Structurally sound mud pie! A child is delighted.",
			},
			"fail": {
				"bg": Color(0.2, 0.1, 0.02, 0.92),
				"props": [
					{"e": "🥧", "x": 0.5, "y": 0.72, "size": 76, "anim": "shake", "delay": 0.0},
					{"e": "🌊", "x": 0.5, "y": 0.82, "size": 64, "anim": "pop", "delay": 0.3},
					{"e": "😢", "x": 0.25, "y": 0.45, "size": 56, "anim": "pop", "delay": 0.62},
				],
				"text": "Too much water. You have failed mud.",
			},
		},
		"RainwaterHarvesting": {
			"win": {
				"bg": Color(0.06, 0.16, 0.32, 0.88),
				"props": [
					{"e": "🛢️", "x": 0.18, "y": 0.72, "size": 60, "anim": "fill_up", "delay": 0.0},
					{"e": "🛢️", "x": 0.38, "y": 0.72, "size": 60, "anim": "fill_up", "delay": 0.15},
					{"e": "🛢️", "x": 0.62, "y": 0.72, "size": 60, "anim": "fill_up", "delay": 0.3},
					{"e": "🛢️", "x": 0.82, "y": 0.72, "size": 60, "anim": "fill_up", "delay": 0.45},
					{"e": "🤝", "x": 0.5, "y": 0.28, "size": 64, "anim": "pop", "delay": 0.72},
				],
				"text": "All drums full! You two might have ended the drought.",
			},
			"fail": {
				"bg": Color(0.12, 0.1, 0.08, 0.92),
				"props": [
					{"e": "🛢️", "x": 0.5, "y": 0.72, "size": 72, "anim": "shake", "delay": 0.0},
					{"e": "☀️", "x": 0.5, "y": 0.15, "size": 64, "anim": "bounce", "delay": 0.42},
					{"e": "😞", "x": 0.25, "y": 0.45, "size": 52, "anim": "pop", "delay": 0.62},
				],
				"text": "The drought continues. So does your shame.",
			},
		},
		# ── Multiplayer games ──────────────────────────────────────────
		"MP_CatchRainAquarium": {
			"win": {
				"bg": Color(0.04, 0.18, 0.4, 0.88),
				"props": [
					{"e": "🌧️", "x": 0.5, "y": 0.15, "size": 68, "anim": "fall", "delay": 0.0},
					{"e": "🐠", "x": 0.35, "y": 0.65, "size": 64, "anim": "bounce", "delay": 0.42},
					{"e": "🐟", "x": 0.65, "y": 0.7, "size": 60, "anim": "bounce", "delay": 0.52},
					{"e": "🪣", "x": 0.5, "y": 0.8, "size": 72, "anim": "fill_up", "delay": 0.3},
				],
				"text": "Tank filled to the line. The fish look smug.",
			},
			"fail": {
				"bg": Color(0.05, 0.1, 0.3, 0.92),
				"props": [
					{"e": "🌧️", "x": 0.5, "y": 0.15, "size": 64, "anim": "fall", "delay": 0.0},
					{"e": "🌊", "x": 0.5, "y": 0.82, "size": 76, "anim": "pop", "delay": 0.3},
					{"e": "🐠", "x": 0.5, "y": 0.3, "size": 60, "anim": "fly_away", "delay": 0.62},
				],
				"text": "The fish were never coming — they heard about you.",
			},
		},
		"MP_CollectDishWater": {
			"win": {
				"bg": Color(0.06, 0.2, 0.3, 0.88),
				"props": [
					{"e": "🍽️", "x": 0.35, "y": 0.52, "size": 72, "anim": "pop", "delay": 0.0},
					{"e": "🪣", "x": 0.65, "y": 0.72, "size": 72, "anim": "fill_up", "delay": 0.3},
					{"e": "🌱", "x": 0.5, "y": 0.2, "size": 56, "anim": "pop", "delay": 0.62},
				],
				"text": "Dishes clean. Greywater saved. Two eco-icons.",
			},
			"fail": {
				"bg": Color(0.18, 0.15, 0.08, 0.88),
				"props": [
					{"e": "🪣", "x": 0.5, "y": 0.65, "size": 72, "anim": "shake", "delay": 0.0},
					{"e": "🌊", "x": 0.5, "y": 0.85, "size": 72, "anim": "pop", "delay": 0.3},
					{"e": "😤", "x": 0.25, "y": 0.38, "size": 52, "anim": "pop", "delay": 0.52},
					{"e": "😤", "x": 0.72, "y": 0.42, "size": 52, "anim": "pop", "delay": 0.66},
				],
				"text": "Both players blame each other immediately.",
			},
		},
		"MP_CollectLaundryWater": {
			"win": {
				"bg": Color(0.06, 0.2, 0.28, 0.88),
				"props": [
					{"e": "👕", "x": 0.3, "y": 0.38, "size": 72, "anim": "pop", "delay": 0.0},
					{"e": "🌿", "x": 0.72, "y": 0.68, "size": 72, "anim": "bounce", "delay": 0.4},
					{"e": "✨", "x": 0.5, "y": 0.2, "size": 56, "anim": "float", "delay": 0.62},
				],
				"text": "Every drop redirected. Sustainability icons!",
			},
			"fail": {
				"bg": Color(0.12, 0.12, 0.18, 0.88),
				"props": [
					{"e": "🪣", "x": 0.5, "y": 0.65, "size": 72, "anim": "shake", "delay": 0.0},
					{"e": "🌊", "x": 0.5, "y": 0.85, "size": 72, "anim": "pop", "delay": 0.3},
					{"e": "🧹", "x": 0.28, "y": 0.45, "size": 60, "anim": "pop", "delay": 0.62},
				],
				"text": "Buffer overflowed. Now the tiles need mopping too.",
			},
		},
		"MP_CollectShowerWater": {
			"win": {
				"bg": Color(0.05, 0.18, 0.35, 0.88),
				"props": [
					{"e": "🚿", "x": 0.5, "y": 0.28, "size": 76, "anim": "pop", "delay": 0.0},
					{"e": "🪣", "x": 0.3, "y": 0.72, "size": 68, "anim": "fill_up", "delay": 0.3},
					{"e": "🪣", "x": 0.7, "y": 0.72, "size": 68, "anim": "fill_up", "delay": 0.45},
					{"e": "🌍", "x": 0.5, "y": 0.18, "size": 52, "anim": "pop", "delay": 0.72},
				],
				"text": "Every warm-up litre saved. You fixed the crisis.",
			},
			"fail": {
				"bg": Color(0.05, 0.1, 0.28, 0.92),
				"props": [
					{"e": "🪣", "x": 0.5, "y": 0.62, "size": 72, "anim": "shake", "delay": 0.0},
					{"e": "🌊", "x": 0.5, "y": 0.85, "size": 76, "anim": "pop", "delay": 0.3},
					{"e": "🚿", "x": 0.5, "y": 0.22, "size": 64, "anim": "shake", "delay": 0.42},
				],
				"text": "P1 passes too fast. P2 drops a bucket. The bathroom is a puddle.",
			},
		},
		"MP_FillAquarium": {
			"win": {
				"bg": Color(0.04, 0.18, 0.4, 0.88),
				"props": [
					{"e": "🐡", "x": 0.5, "y": 0.58, "size": 76, "anim": "bounce", "delay": 0.42},
					{"e": "🪣", "x": 0.3, "y": 0.72, "size": 68, "anim": "pop", "delay": 0.0},
					{"e": "🎯", "x": 0.72, "y": 0.42, "size": 56, "anim": "pop", "delay": 0.52},
				],
				"text": "Perfect fill! A goldfish materializes to say thank you.",
			},
			"fail": {
				"bg": Color(0.05, 0.1, 0.3, 0.92),
				"props": [
					{"e": "🌊", "x": 0.5, "y": 0.82, "size": 76, "anim": "pop", "delay": 0.22},
					{"e": "🐟", "x": 0.5, "y": 0.42, "size": 68, "anim": "shake", "delay": 0.52},
				],
				"text": "P2 signals too late. The goldfish shakes its tiny head.",
			},
		},
		"MP_FilterWater": {
			"win": {
				"bg": Color(0.05, 0.22, 0.3, 0.88),
				"props": [
					{"e": "🧪", "x": 0.5, "y": 0.72, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "✨", "x": 0.3, "y": 0.38, "size": 56, "anim": "float", "delay": 0.4},
					{"e": "💧", "x": 0.72, "y": 0.35, "size": 52, "anim": "float", "delay": 0.52},
				],
				"text": "Crystal clear. You made something beautiful.",
			},
			"fail": {
				"bg": Color(0.2, 0.15, 0.06, 0.92),
				"props": [
					{"e": "🧪", "x": 0.5, "y": 0.72, "size": 76, "anim": "shake", "delay": 0.0},
					{"e": "🤮", "x": 0.72, "y": 0.45, "size": 52, "anim": "pop", "delay": 0.52},
				],
				"text": "Somehow more brown than the input. Science has failed.",
			},
		},
		"MP_FlushToilets": {
			"win": {
				"bg": Color(0.05, 0.2, 0.3, 0.88),
				"props": [
					{"e": "🚽", "x": 0.5, "y": 0.72, "size": 84, "anim": "pop", "delay": 0.0},
					{"e": "💪", "x": 0.5, "y": 0.28, "size": 64, "anim": "pop", "delay": 0.52},
				],
				"text": "Perfect pressure. The toilet is satisfied.",
			},
			"fail": {
				"bg": Color(0.2, 0.12, 0.06, 0.88),
				"props": [
					{"e": "🚽", "x": 0.5, "y": 0.72, "size": 84, "anim": "shake", "delay": 0.0},
					{"e": "😅", "x": 0.5, "y": 0.3, "size": 60, "anim": "pop", "delay": 0.52},
				],
				"text": "It does not clear. The situation escalates quickly.",
			},
		},
		"MP_MopFloor": {
			"win": {
				"bg": Color(0.06, 0.2, 0.25, 0.88),
				"props": [
					{"e": "🧹", "x": 0.5, "y": 0.52, "size": 80, "anim": "pop", "delay": 0.0},
					{"e": "✨", "x": 0.3, "y": 0.35, "size": 56, "anim": "float", "delay": 0.4},
					{"e": "✨", "x": 0.72, "y": 0.4, "size": 52, "anim": "float", "delay": 0.55},
				],
				"text": "Spotless floor. Zero fresh water used.",
			},
			"fail": {
				"bg": Color(0.18, 0.14, 0.06, 0.88),
				"props": [
					{"e": "🧹", "x": 0.5, "y": 0.52, "size": 76, "anim": "shake", "delay": 0.0},
					{"e": "😬", "x": 0.5, "y": 0.28, "size": 60, "anim": "pop", "delay": 0.52},
				],
				"text": "Uniformly dirty now. Arguably worse than before.",
			},
		},
		"MP_WashCar": {
			"win": {
				"bg": Color(0.06, 0.2, 0.32, 0.88),
				"props": [
					{"e": "🚗", "x": 0.5, "y": 0.68, "size": 84, "anim": "pop", "delay": 0.0},
					{"e": "🪣", "x": 0.28, "y": 0.55, "size": 60, "anim": "bounce", "delay": 0.3},
					{"e": "✨", "x": 0.72, "y": 0.48, "size": 52, "anim": "float", "delay": 0.52},
				],
				"text": "Shiny car, zero hose used. A neighbor is impressed.",
			},
			"fail": {
				"bg": Color(0.18, 0.12, 0.06, 0.88),
				"props": [
					{"e": "🚗", "x": 0.5, "y": 0.68, "size": 84, "anim": "shake", "delay": 0.0},
					{"e": "🎨", "x": 0.5, "y": 0.32, "size": 60, "anim": "pop", "delay": 0.42},
					{"e": "🤔", "x": 0.25, "y": 0.45, "size": 52, "anim": "pop", "delay": 0.62},
				],
				"text": "The dirt smears. The car now has abstract art on it.",
			},
		},
		"MP_WashVegetables": {
			"win": {
				"bg": Color(0.06, 0.22, 0.1, 0.88),
				"props": [
					{"e": "🥬", "x": 0.3, "y": 0.58, "size": 72, "anim": "pop", "delay": 0.0},
					{"e": "🥕", "x": 0.7, "y": 0.62, "size": 64, "anim": "pop", "delay": 0.22},
					{"e": "🌱", "x": 0.5, "y": 0.75, "size": 56, "anim": "bounce", "delay": 0.52},
				],
				"text": "All veggies clean. Dinner and the environment win.",
			},
			"fail": {
				"bg": Color(0.18, 0.14, 0.06, 0.88),
				"props": [
					{"e": "🥕", "x": 0.5, "y": 0.62, "size": 76, "anim": "shake", "delay": 0.0},
					{"e": "🚫", "x": 0.5, "y": 0.28, "size": 64, "anim": "pop", "delay": 0.42},
					{"e": "🥗", "x": 0.25, "y": 0.55, "size": 52, "anim": "fly_away", "delay": 0.62},
				],
				"text": "The 'clean' tray is now dirty. Nobody eats salad tonight.",
			},
		},
		"MP_WaterPlants": {
			"win": {
				"bg": Color(0.06, 0.22, 0.1, 0.88),
				"props": [
					{"e": "🌿", "x": 0.3, "y": 0.68, "size": 72, "anim": "bounce", "delay": 0.0},
					{"e": "🌺", "x": 0.7, "y": 0.65, "size": 68, "anim": "bounce", "delay": 0.22},
					{"e": "🦋", "x": 0.5, "y": 0.28, "size": 60, "anim": "float", "delay": 0.52},
				],
				"text": "A butterfly appears. Both players feel responsible for it.",
			},
			"fail": {
				"bg": Color(0.2, 0.12, 0.04, 0.88),
				"props": [
					{"e": "🌵", "x": 0.5, "y": 0.65, "size": 80, "anim": "shake", "delay": 0.0},
					{"e": "🌊", "x": 0.5, "y": 0.85, "size": 72, "anim": "pop", "delay": 0.3},
					{"e": "😱", "x": 0.28, "y": 0.35, "size": 56, "anim": "pop", "delay": 0.52},
				],
				"text": "One plant drowns. It was a cactus. A CACTUS.",
			},
		},
	}
	var key_data: Dictionary = scenes.get(key, {})
	return key_data.get(outcome, {
		"bg": default_bg,
		"props": [],
		"text": "",
	})
