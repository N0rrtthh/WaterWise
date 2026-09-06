extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## TOILET TANK FIX - Hold to stop flow, tap to adjust float
## ═══════════════════════════════════════════════════════════════════

var water_level: float = 0.0
var target_level: float = 70.0
var tolerance: float = 10.0
var fill_rate: float = 30.0
var is_holding: bool = false
var tanks_fixed: int = 0
var target_tanks: int = 4

## True from the moment a tank is graded until the replacement tank is set up.
##
## _check_level() awaits a respawn delay, and it is called from _process without
## `await`, so _process keeps running during that gap. Without this gate a player
## who pressed again inside the window carried the graded tank's water_level
## upward and was then scored against a target_level that had not been re-rolled
## yet — a stale target on a pre-filled tank. Holding through the gap now simply
## does nothing until the new tank appears.
var _awaiting_next_tank: bool = false

## Highest target_level _setup_tank() will roll, and the mean of its range.
const MAX_TARGET_LEVEL: float = 80.0
const MIN_TARGET_LEVEL: float = 50.0
const AVG_TARGET_LEVEL: float = (MIN_TARGET_LEVEL + MAX_TARGET_LEVEL) * 0.5

## Narrowest release window a human is expected to hit, in seconds.
##
## The player has to let go while water_level is within `tolerance` of
## target_level, so the window they are aiming at is (2 × tolerance) ÷ fill_rate
## seconds wide — tolerance is a distance, not a duration, and it only becomes a
## duration once divided by the fill rate. The shipped Hard row asked for 5%
## tolerance at 45%/s, a 0.22 s window: narrower than a typical visual-motor
## reaction, so Hard could only be cleared by luck. Easy (1.50 s) and Medium
## (0.67 s) were always fine.
##
## 0.45 s is the floor `_minimum_tolerance()` enforces below.
const MIN_RELEASE_WINDOW: float = 0.45

## Seconds a flawless run may spend, as a fraction of the clock.
##
## The rest is the margin a player needs to absorb a missed tank: the retry costs
## the failure respawn, a full refill, and MiniGameBase's difficulty-scaled time
## penalty on top.
const QUOTA_BUDGET_FRACTION: float = 0.75

## Human release latency charged against every tank.
const RELEASE_SLOP_SECONDS: float = 0.2

## Ignore releases this shallow instead of grading them as a failed tank.
##
## _process grades on the release edge, so a stray tap used to fill one frame's
## worth of water (45%/s ÷ 60 fps ≈ 0.75%) and then be scored against a target of
## 50-80% — a guaranteed record_action(false) plus a time penalty for brushing the
## screen. Well below the lowest target this can never mask a real miss.
const MIN_GRADED_LEVEL: float = 5.0

## Failure reactions, kept to two or three words so they read in the 0.4 s they
## are on screen. Each one still points at the waste it stands for.
## Reactions to a mis-graded tank, keyed like VegetableBath.DIRTY_QUIPS so the Filipino
## build gets Filipino jokes instead of English ones. Two or three words: they sit above
## the tank for well under a second. The English text stays beside the key as the
## fallback, so a table miss shows readable copy rather than "ttf_quip_gusher".
const OVERFLOW_QUIPS: Array[Dictionary] = [
	{"key": "ttf_quip_overflow", "en": "OVERFLOW! 🌊"},
	{"key": "ttf_quip_gusher", "en": "GUSHER! 💦"},
	{"key": "ttf_quip_flood_mode", "en": "FLOOD MODE! 🚽"}
]
const UNDERFILL_QUIPS: Array[Dictionary] = [
	{"key": "ttf_quip_too_shy", "en": "TOO SHY! 💧"},
	{"key": "ttf_quip_half_flush", "en": "HALF A FLUSH! 🚽"},
	{"key": "ttf_quip_more_more", "en": "MORE, MORE! ⬆️"}
]

## Seconds between a graded tank and the next one appearing.##
## Scaled by difficulty because it is charged (target_tanks - 1) times against a
## clock that shrinks as the quota grows: a flat 0.8 s spent 2.4 s of Hard's 8 s
## round doing nothing.
func _respawn_delay() -> float:
	match current_difficulty:
		"Easy":
			return 0.8
		"Medium":
			return 0.6
		"Hard":
			return 0.35
	return 0.6

## Tolerance needed to keep the release window at MIN_RELEASE_WINDOW.
func _minimum_tolerance() -> float:
	return fill_rate * MIN_RELEASE_WINDOW * 0.5

## Seconds a flawless run needs: fill + release slop per tank, plus the respawns
## between them. Used to size the clock so the quota is reachable at all.
func _flawless_run_seconds() -> float:
	var per_tank: float = AVG_TARGET_LEVEL / maxf(fill_rate, 1.0) + RELEASE_SLOP_SECONDS
	return float(target_tanks) * per_tank + float(maxi(target_tanks - 1, 0)) * _respawn_delay()

func _apply_difficulty_settings() -> void:
	# super() activates the chaos effects the algorithm picked for this round.
	super._apply_difficulty_settings()

	# Get progressive difficulty settings
	var settings = AdaptiveDifficulty.get_difficulty_settings() if AdaptiveDifficulty else {}
	var progressive_level = settings.get("progressive_level", 0)

	match current_difficulty:
		"Easy":
			target_tanks = 2  # Achievable in 18s
			tolerance = 15.0
			fill_rate = 20.0
			game_duration = 18.0
		"Medium":
			target_tanks = 3  # Achievable in 12s
			tolerance = 10.0
			fill_rate = 30.0
			game_duration = 12.0
		"Hard":
			target_tanks = 4
			tolerance = 5.0
			fill_rate = 45.0
			game_duration = 8.0

	# Apply PROGRESSIVE DIFFICULTY (NO CEILING!)
	if progressive_level > 0:
		target_tanks += mini(progressive_level, 2)  # +1 tank per level, max +2
		fill_rate += progressive_level * 5.0  # Slightly faster filling
		tolerance = max(4.0, tolerance - progressive_level * 0.5)  # Tighter target, floor at 4%
		game_duration += progressive_level * 2.0  # Give more time for extra tanks
		if settings.has("time_limit"):
			game_duration = max(game_duration, settings.get("time_limit", game_duration))
		print("🔥 Progressive Lvl %d: %d tanks, %.1f fill rate"
			% [progressive_level, target_tanks, fill_rate])

	# Keep the release window and the clock physically achievable for whatever
	# fill_rate and quota the rows above (and progressive scaling) settled on.
	# Both are floors, so Easy and Medium come through unchanged: only Hard was
	# out of budget (0.22 s window, and 8.2 s of work in an 8.0 s round).
	tolerance = maxf(tolerance, _minimum_tolerance())
	game_duration = maxf(game_duration, _flawless_run_seconds() / QUOTA_BUDGET_FRACTION)

	# Medium and Hard end on bad releases, not on the clock.
	#
	# This is a precision-hold task, and hurrying is actively counterproductive:
	# the level has to be watched to be released on. Hard asks for 4 tanks at 5%
	# tolerance inside a round that _flawless_run_seconds() has to floor upward
	# just to make physically possible — the clock was already the binding
	# constraint rather than the hand. Ending on releases measures the hand.
	use_attempt_budget(0, target_tanks + 1, target_tanks)

func _ready():
	# Localized: the title stayed English above the Filipino objective FIX 58
	# authored. _loc() keeps the English literal as the fallback for the case
	# where the table is not up yet (tools/SceneLoadCheck instantiates that way).
	game_name = _loc("toilet_tank_fix", "Toilet Tank Fix")
	var fallback := "HOLD to fill tank!\nRelease when water reaches the LINE! 🚽"
	game_instruction_text = _loc("toilet_tank_instructions", fallback)
	game_duration = 25.0
	game_mode = "quota"
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background - Bathroom
	var bg = ColorRect.new()
	bg.color = Color(0.9, 0.9, 0.95)
	bg.position = Vector2.ZERO
	bg.size = screen_size
	bg.z_index = -10
	add_child(bg)
	
	# Toilet tank
	var tank = Node2D.new()
	tank.name = "Tank"
	tank.position = Vector2(screen_size.x / 2, screen_size.y * 0.5)
	add_child(tank)
	
	# Tank body
	var tank_body = Polygon2D.new()
	tank_body.polygon = PackedVector2Array([
		Vector2(-100, -120), Vector2(100, -120),
		Vector2(100, 120), Vector2(-100, 120)
	])
	tank_body.color = Color(0.95, 0.95, 0.95)
	tank.add_child(tank_body)
	
	# Tank outline
	var outline = Line2D.new()
	outline.points = PackedVector2Array([
		Vector2(-100, -120), Vector2(100, -120),
		Vector2(100, 120), Vector2(-100, 120), Vector2(-100, -120)
	])
	outline.width = 4
	outline.default_color = Color(0.7, 0.7, 0.7)
	tank.add_child(outline)
	
	# Water fill
	var water = Polygon2D.new()
	water.name = "Water"
	water.polygon = PackedVector2Array([
		Vector2(-95, 115), Vector2(95, 115),
		Vector2(95, 115), Vector2(-95, 115)
	])
	water.color = Color(0.3, 0.6, 0.9, 0.7)
	tank.add_child(water)
	
	# Target line
	var target_line = Line2D.new()
	target_line.name = "TargetLine"
	target_line.points = PackedVector2Array([Vector2(-100, 0), Vector2(100, 0)])
	target_line.width = 4
	target_line.default_color = Color(0.2, 0.8, 0.2)
	tank.add_child(target_line)
	
	# Target zone indicator
	var zone_label = Label.new()
	zone_label.text = _loc("hud_target_arrow", "⬅ TARGET")
	zone_label.add_theme_font_size_override("font_size", 18)
	zone_label.add_theme_color_override("font_color", Color(0.2, 0.7, 0.2))
	MiniGameAssets.outline_text(zone_label)
	zone_label.position = Vector2(105, -15)
	tank.add_child(zone_label)
	
	# Float mechanism
	var float_ball = Label.new()
	float_ball.name = "Float"
	float_ball.text = "⚪"
	float_ball.add_theme_font_size_override("font_size", 40)
	float_ball.position = Vector2(50, 100)
	tank.add_child(float_ball)
	
	# Instructions
	var hold_label = Label.new()
	hold_label.name = "HoldLabel"
	hold_label.text = _loc("hud_hold_to_fill", "👆 HOLD TO FILL")
	hold_label.add_theme_font_size_override("font_size", 28)
	hold_label.add_theme_color_override("font_color", Color.WHITE)
	hold_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hold_label.add_theme_constant_override("outline_size", 4)
	hold_label.position = Vector2(screen_size.x / 2 - 100, screen_size.y * 0.85)
	add_child(hold_label)
	
	# Score display
	var score_display = Label.new()
	score_display.name = "ScoreDisplay"
	score_display.text = "🚽 0 / %d" % target_tanks
	score_display.add_theme_font_size_override("font_size", 28)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(screen_size.x / 2 - 60, 120)
	add_child(score_display)
	
	_setup_tank()

func _setup_tank():
	water_level = 0.0
	target_level = randf_range(MIN_TARGET_LEVEL, MAX_TARGET_LEVEL)
	
	# Update target line position
	var tank = get_node("Tank")
	var target_line = tank.get_node("TargetLine")
	var y_pos = 115 - (target_level / 100.0 * 230)
	target_line.points = PackedVector2Array([Vector2(-100, y_pos), Vector2(100, y_pos)])

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	var was_holding = is_holding
	is_holding = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	var tank = get_node("Tank")
	var water = tank.get_node("Water")
	var float_ball = tank.get_node("Float")
	
	if is_holding and not _awaiting_next_tank:
		# Fill tank
		water_level = min(100.0, water_level + fill_rate * delta)
		get_node("HoldLabel").text = _loc("hud_filling", "💧 FILLING...")
		get_node("HoldLabel").modulate = Color(0.5, 0.8, 1.0)
	elif _awaiting_next_tank:
		get_node("HoldLabel").text = _loc("hud_next_tank", "🔧 NEXT TANK...")
		get_node("HoldLabel").modulate = Color(0.8, 0.8, 0.8)
	else:
		get_node("HoldLabel").text = _loc("hud_hold_to_fill", "👆 HOLD TO FILL")
		get_node("HoldLabel").modulate = Color.WHITE
	
	# Update water visual
	var water_height = (water_level / 100.0) * 230
	var y_top = 115 - water_height
	water.polygon = PackedVector2Array([
		Vector2(-95, 115), Vector2(95, 115),
		Vector2(95, y_top), Vector2(-95, y_top)
	])
	
	# Update float position
	float_ball.position.y = y_top - 20
	
	# Check if released after holding.
	#
	# MIN_GRADED_LEVEL rather than > 0: a tap that lasted one frame is a mis-touch,
	# not an attempt at the target line, and grading it cost the player an action
	# and a time penalty.
	if was_holding and not is_holding and not _awaiting_next_tank:
		if water_level >= MIN_GRADED_LEVEL:
			_check_level()
		elif water_level > 0.0:
			water_level = 0.0

func _check_level():
	var diff = abs(water_level - target_level)
	
	if diff <= tolerance:
		# Success!
		tanks_fixed += 1
		record_action(true)
		get_node("ScoreDisplay").text = "🚽 %d / %d" % [tanks_fixed, target_tanks]
		
		# Success animation
		var flash = ColorRect.new()
		flash.color = Color(0, 1, 0, 0.3)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var tw = create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.3)
		tw.tween_callback(flash.queue_free)
		
		if tanks_fixed >= target_tanks:
			end_game(true)
		else:
			_awaiting_next_tank = true
			await round_delay(_respawn_delay())
			_awaiting_next_tank = false
			if game_active:
				_setup_tank()
	else:
		# Failed - overflow or underfill
		record_action(false)
		
		var flash = ColorRect.new()
		flash.color = Color(1, 0, 0, 0.3)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flash)
		var tw = create_tween()
		tw.tween_property(flash, "modulate:a", 0.0, 0.3)
		tw.tween_callback(flash.queue_free)
		
		# Show feedback.
		#
		# Short, funny and readable at arm's length on a phone, and it names the
		# water lesson: overfilling a tank wastes every flush after it, underfilling
		# means a second flush. The label pops in oversized and settles rather than
		# just fading, so the reaction is legible even at 0.5 s.
		var feedback = Label.new()
		var quips: Array[Dictionary] = (
			OVERFLOW_QUIPS if water_level > target_level else UNDERFILL_QUIPS)
		var quip: Dictionary = quips[randi() % quips.size()]
		feedback.text = _loc(str(quip["key"]), str(quip["en"]))
		feedback.add_theme_font_size_override("font_size", 36)
		feedback.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		feedback.add_theme_color_override("font_outline_color", Color.BLACK)
		feedback.add_theme_constant_override("outline_size", 4)
		feedback.position = get_node("Tank").position + Vector2(-80, -150)
		feedback.pivot_offset = Vector2(80, 20)
		feedback.scale = Vector2(0.6, 1.4)
		add_child(feedback)

		var tw2 = create_tween()
		tw2.tween_property(feedback, "scale", Vector2(1.15, 0.9), 0.09).set_ease(Tween.EASE_OUT)
		tw2.tween_property(feedback, "scale", Vector2.ONE, 0.07)
		tw2.tween_property(feedback, "modulate:a", 0.0, 0.34)
		tw2.tween_callback(feedback.queue_free)

		_awaiting_next_tank = true
		await round_delay(_respawn_delay())
		_awaiting_next_tank = false
		if game_active:
			_setup_tank()
