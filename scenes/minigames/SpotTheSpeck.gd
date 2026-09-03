extends MiniGameBase

var glasses: Array = []
var current_glass: Node2D = null
var glasses_checked: int = 0
var correct_choices: int = 0
var target_correct: int = 6
var dirty_chance: float = 0.5
var num_specks_min: int = 5
var num_specks_max: int = 12

## The two swipe-direction hints, held so the judgement badge can step out of their way.
## See _flash_result().
var _up_hint: Label = null
var _down_hint: Label = null

var swipe_start: Vector2 = Vector2.ZERO
var is_swiping: bool = false

## VISUAL SCALE - why the glass is not drawn at its authored size any more.
##
## The glass is the only thing in this scene the player has to LOOK at, and it was the
## only thing authored in fixed units. The table band, both hint labels and the score
## readout are all screen-relative (screen_size.y * 0.7, * 0.25, * 0.75), but the glass
## polygons are +/-60 x -105..100 at scale 1.0. On the 1920x1080 canvas the project
## ships that is 110x205 units - 5.7% of the width, a small island in a mostly empty
## frame - with 3-8 unit specks inside it. The background scaled with the screen and the
## subject of the game did not. Measured from tools/probe_frames/SpotTheSpeck/f0180.png.
##
## AUTHORED_GLASS_H is the rim-to-base extent of the polygons in _spawn_glass().
## GLASS_VIEWPORT_SHARE keeps the scaled glass clear of the "CLEAN" hint above
## (screen_size.y * 0.25 plus its ~30 unit line box) and the table edge below
## (screen_size.y * 0.7) at every aspect the project supports; the cap stops a very tall
## window from making it absurd.
const AUTHORED_GLASS_H: float = 205.0
const GLASS_VIEWPORT_SHARE: float = 0.38
const GLASS_SCALE_MAX: float = 3.0

## The smallest speck that still reads on the smallest screen the paper targets.
##
## A speck is a child of the glass, so its on-screen width is
## (radius * 2) * _glass_scale * (device px per canvas unit). The lowest-end profile in
## tools/AuditMobileUI.gd DEVICES is 854x480, where a 1920-unit-wide canvas yields
## 0.445 device px per unit. A brown blob on blue water needs roughly 6 device px across
## before a player can tell it is dirt rather than a compression artefact:
##     radius >= 6 / (2 * 0.445 * _glass_scale)
## which is 3.5 units at the ~1.9 scale this scene now uses. The old floor was 3.0 at
## scale 1.0 - 2.7 device px, under three pixels of brown - and Hard asks for as few as
## 2 specks at the minimum size, so Hard was a coin flip rather than a perception test.
const SPECK_RADIUS_MIN: float = 4.0
const SPECK_RADIUS_MAX: float = 9.0

## Resolved per spawn from the live viewport, and used BOTH for the entrance tween's
## target and for anything measured against the glass (the result label above it, the
## exit slide). A stale 1.0 here would let the entrance tween scale the glass back down.
var _glass_scale: float = 1.0

func _apply_difficulty_settings() -> void:
	# Queues this tier's chaos_effects; without it the algorithm asks for them
	# and this game silently drops them. The per-tier game_duration below is
	# deliberate and overrides the base's time_limit write. See MiniGameBase.
	super._apply_difficulty_settings()
	match current_difficulty:
		"Easy":
			target_correct = 4
			dirty_chance = 0.6  # More dirty = easier to spot
			num_specks_min = 8
			num_specks_max = 15  # Very visible specks
			game_duration = 18.0
		"Medium":
			target_correct = 5
			dirty_chance = 0.5
			num_specks_min = 5
			num_specks_max = 12
			game_duration = 15.0
		"Hard":
			target_correct = 6
			dirty_chance = 0.4  # Less dirty = harder to spot
			num_specks_min = 2
			num_specks_max = 6  # Subtle specks
			game_duration = 12.0

	# Medium and Hard end on wrong judgements, not on the clock.
	#
	# Judging a glass is perception, and Hard deliberately makes the evidence
	# faint — 2 to 6 specks at SPECK_RADIUS_MIN, which the constant above measures
	# as ~6 device px on the lowest profile the paper targets. Twelve seconds for
	# six of those judgements is two seconds each, which measures how quickly a
	# player is willing to guess rather than how well they can see.
	#
	# Wrong glasses do not count toward target_correct, so the budget is a real
	# accuracy requirement: 5 correct before 5 wrong on Medium, 6 before 4 on Hard.
	use_attempt_budget(0, 5, 4)

func _ready():
	# Localized: the title stayed English above the Filipino objective FIX 58
	# authored. _loc() keeps the English literal as the fallback for the case
	# where the table is not up yet (tools/SceneLoadCheck instantiates that way).
	game_name = _loc("spot_the_speck", "Spot The Speck")
	# Was hardcoded English; speck_instruction now carries this same detail in both
	# languages instead of the terser pair of lines it had.
	game_instruction_text = _loc(
		"speck_instruction",
		"Check the water glasses!\n⬆️ SWIPE UP = Clean (drink!) | ⬇️ SWIPE DOWN = Dirty (reject!)"
	)
	game_duration = 20.0
	game_mode = "quota"  # Must check target number of glasses!
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.9, 0.95, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	add_child(bg)
	
	# Table
	var table = ColorRect.new()
	table.color = Color(0.55, 0.35, 0.2)
	table.position = Vector2(0, screen_size.y * 0.7)
	table.size = Vector2(screen_size.x, screen_size.y * 0.3)
	table.z_index = -5
	add_child(table)
	
	# Score label
	var local_score_label = Label.new()
	local_score_label.name = "ScoreLabel"
	local_score_label.text = _loc("hud_correct_count", "✓ Correct: %d / %d") % [0, target_correct]
	local_score_label.add_theme_font_size_override("font_size", 28)
	local_score_label.add_theme_color_override("font_color", Color.WHITE)
	local_score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	local_score_label.add_theme_constant_override("outline_size", 4)
	local_score_label.position = Vector2(screen_size.x / 2 - 100, 120)
	add_child(local_score_label)
	
	# Hint arrows
	var up_hint = Label.new()
	up_hint.text = _loc("hud_swipe_clean", "⬆️ CLEAN")
	up_hint.add_theme_font_size_override("font_size", 24)
	up_hint.add_theme_color_override("font_color", Color.GREEN)
	MiniGameAssets.outline_text(up_hint)
	up_hint.position = Vector2(screen_size.x / 2 - 50, screen_size.y * 0.25)
	add_child(up_hint)
	_up_hint = up_hint
	
	var down_hint = Label.new()
	down_hint.text = _loc("hud_swipe_dirty", "⬇️ DIRTY")
	down_hint.add_theme_font_size_override("font_size", 24)
	down_hint.add_theme_color_override("font_color", Color.RED)
	MiniGameAssets.outline_text(down_hint)
	down_hint.position = Vector2(screen_size.x / 2 - 50, screen_size.y * 0.75)
	add_child(down_hint)
	_down_hint = down_hint
	
	# Spawn first glass
	_spawn_glass()

func _spawn_glass():
	# Both hints belong to the glass that is arriving, not to the verdict that just
	# cleared - see _flash_result().
	_set_swipe_hints_visible(true)
	var screen_size = get_viewport_rect().size
	# Resolve the glass size against the live viewport, the way every other element in this
	# scene already does. Recomputed per spawn so a mid-round resize or rotation affects the
	# next glass instead of keeping a stale _ready()-time number.
	_glass_scale = clampf(
		(screen_size.y * GLASS_VIEWPORT_SHARE) / AUTHORED_GLASS_H, 1.0, GLASS_SCALE_MAX)
	# Was a hardcoded randf() > 0.5, so dirty_chance was write-only too: Easy (0.6 dirty,
	# "more dirty = easier to spot") and Hard (0.4) both ran at the Medium 0.5.
	var has_specks = randf() < dirty_chance
	
	current_glass = Node2D.new()
	current_glass.position = Vector2(screen_size.x / 2, screen_size.y * 0.5)
	current_glass.set_meta("dirty", has_specks)
	add_child(current_glass)
	
	# Glass body (transparent)
	var glass_body = Polygon2D.new()
	glass_body.polygon = PackedVector2Array([
		Vector2(-60, -100), Vector2(60, -100),
		Vector2(50, 100), Vector2(-50, 100)
	])
	glass_body.color = Color(0.8, 0.9, 1.0, 0.3)
	current_glass.add_child(glass_body)
	
	# Glass rim
	var rim = Polygon2D.new()
	rim.polygon = PackedVector2Array([
		Vector2(-62, -105), Vector2(62, -105),
		Vector2(62, -95), Vector2(-62, -95)
	])
	rim.color = Color(0.7, 0.8, 0.9, 0.5)
	current_glass.add_child(rim)
	
	# Water inside
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-55, -80), Vector2(55, -80),
		Vector2(45, 95), Vector2(-45, 95)
	])
	
	if has_specks:
		water.color = Color(0.4, 0.55, 0.7, 0.8)  # Slightly murky
	else:
		water.color = Color(0.4, 0.7, 0.95, 0.8)  # Clear blue
	current_glass.add_child(water)
	
	# Add specks if dirty
	if has_specks:
		# Was a hardcoded randi_range(5, 12) - the Medium values - so num_specks_min and
		# num_specks_max were written by _apply_difficulty_settings() and read by nothing.
		# Easy asks for 8-15 specks and Hard for 2-6; both played as Medium.
		var num_specks = randi_range(num_specks_min, num_specks_max)
		for i in range(num_specks):
			var speck = Polygon2D.new()
			var speck_points = PackedVector2Array()
			var speck_size = randf_range(SPECK_RADIUS_MIN, SPECK_RADIUS_MAX)
			for j in range(5):
				var angle = j * TAU / 5
				speck_points.append(Vector2(cos(angle) * speck_size, sin(angle) * speck_size))
			speck.polygon = speck_points
			speck.color = Color(0.3, 0.2, 0.1, 0.7)  # Brown specks
			speck.position = Vector2(randf_range(-40, 40), randf_range(-60, 80))
			current_glass.add_child(speck)
	
	# Glass highlights
	var highlight = Polygon2D.new()
	highlight.polygon = PackedVector2Array([
		Vector2(-50, -90), Vector2(-40, -90),
		Vector2(-35, 50), Vector2(-45, 50)
	])
	highlight.color = Color(1, 1, 1, 0.3)
	current_glass.add_child(highlight)
	
	# Entrance animation
	current_glass.modulate.a = 0
	# Entrance grows from half the FINAL size, not from half of 1.0 - the tween target below
	# is what actually sets the glass scale, so a literal 1.0 there would shrink it back.
	current_glass.scale = Vector2(_glass_scale, _glass_scale) * 0.5
	var tween = create_tween()
	tween.tween_property(current_glass, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(current_glass, "scale", Vector2(_glass_scale, _glass_scale), 0.3)
	
	glasses.append(current_glass)

func _input(event: InputEvent) -> void:
	if not game_active or not current_glass: return
	if event is InputEventScreenTouch:
		if event.pressed:
			is_swiping = true
			swipe_start = event.position
		else:
			if is_swiping:
				is_swiping = false
				var direction = event.position - swipe_start
				if direction.length() > 60 and abs(direction.y) > abs(direction.x):
					if direction.y < 0:
						_judge_glass(false)  # Swipe UP = Clean
					else:
						_judge_glass(true)   # Swipe DOWN = Dirty

func _process(delta):
	super._process(delta)
	if not game_active or not current_glass: return
	
	_handle_input()

func _handle_input():
	# Mouse input (PC only — touch is handled in _input() above)
	var viewport = get_viewport()
	if viewport == null: return
	var mouse_pos = viewport.get_mouse_position()
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_swiping:
			is_swiping = true
			swipe_start = mouse_pos
	else:
		if is_swiping:
			is_swiping = false
			var swipe_end = mouse_pos
			var direction = swipe_end - swipe_start
			
			if direction.length() > 60 and abs(direction.y) > abs(direction.x):
				if direction.y < 0:  # Swipe UP = Accept (clean)
					_judge_glass(false)  # Player thinks it's clean
				else:  # Swipe DOWN = Reject (dirty)
					_judge_glass(true)  # Player thinks it's dirty

func _judge_glass(player_says_dirty: bool):
	if not current_glass: return
	
	var is_actually_dirty = current_glass.get_meta("dirty")
	var correct = (player_says_dirty == is_actually_dirty)
	
	glasses_checked += 1
	
	var screen_size = get_viewport_rect().size
	var tween = create_tween()
	
	if correct:
		correct_choices += 1
		record_action(true)
		get_node("ScoreLabel").text = _loc("hud_correct_count", "✓ Correct: %d / %d") % [correct_choices, target_correct]
		
		# Success animation
		_flash_result(_loc("hud_correct", "✓ CORRECT!"), Color.GREEN, -80.0)
		
		# Slide glass away
		# Off-screen has to clear the SCALED glass, not the authored one: a fixed -200 left
		# a 400-unit-tall glass still poking into the frame when it was freed.
		var glass_h: float = AUTHORED_GLASS_H * _glass_scale
		var target_y = -glass_h if not player_says_dirty else screen_size.y + glass_h
		tween.tween_property(current_glass, "position:y", target_y, 0.3)
		tween.tween_callback(current_glass.queue_free)
		
		if correct_choices >= target_correct:
			current_glass = null
			await round_delay(0.4)
			# The sibling respawn path below guards its own resume; this one banked a WIN
			# over a round that may already have timed out inside the 0.4s.
			if not game_active:
				return
			end_game(true)
			return
	else:
		record_action(false)
		
		# Wrong animation
		_flash_result(_loc("hud_wrong", "✗ WRONG!"), Color.RED, -60.0)
		
		# Shake and remove
		current_glass.modulate = Color(1, 0.5, 0.5)
		tween.tween_property(current_glass, "position:x", current_glass.position.x + 20, 0.05)
		tween.tween_property(current_glass, "position:x", current_glass.position.x - 20, 0.05)
		tween.tween_property(current_glass, "position:x", current_glass.position.x, 0.05)
		tween.tween_property(current_glass, "modulate:a", 0.0, 0.2)
		tween.tween_callback(current_glass.queue_free)
	
	current_glass = null
	glasses.clear()
	
	# Spawn next glass
	await round_delay(0.4)
	if game_active:
		_spawn_glass()


## Pop the judgement badge above the glass, with the swipe hints out of its way.
##
## The badge lands at _above_glass(), which at the scale this scene now draws the glass
## puts it in the same band as the UP hint (screen_size.y * 0.25): VisualSweepHard
## measured "✓ TAMA!" covering 56% of "⬆️ MALINIS", which makes both unreadable at the
## one moment the player is looking for the verdict. The two are mutually exclusive
## anyway - the hints teach the swipe that has just been performed - so they step aside
## for the badge and come back with the next glass.
##
## The restore hangs off _spawn_glass(), NOT off this tween finishing: the tween is
## killed with the node on a scene change or a round end, and a killed tween never emits
## finished, so a restore parked there would leave the hints hidden on the way out.
func _flash_result(text: String, color: Color, dx: float) -> void:
	_set_swipe_hints_visible(false)
	
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", 36)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", Color.BLACK)
	result.add_theme_constant_override("outline_size", 4)
	result.position = current_glass.position + _above_glass(dx)
	add_child(result)
	
	var result_tween := create_tween()
	result_tween.tween_property(result, "modulate:a", 0.0, 0.5)
	result_tween.tween_callback(result.queue_free)

func _set_swipe_hints_visible(shown: bool) -> void:
	if is_instance_valid(_up_hint):
		_up_hint.visible = shown
	if is_instance_valid(_down_hint):
		_down_hint.visible = shown

## Where a floating result label goes so it clears the glass. The glass height depends on
## _glass_scale now, so the old fixed -150 offset landed INSIDE a scaled-up glass.
func _above_glass(dx: float) -> Vector2:
	return Vector2(dx, -(AUTHORED_GLASS_H * 0.5 * _glass_scale + 50.0))
