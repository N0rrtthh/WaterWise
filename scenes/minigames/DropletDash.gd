extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## DROPLET DASH - Guide a water droplet through obstacles to the reservoir
## ═══════════════════════════════════════════════════════════════════
## The player swipes/drags to move a water droplet across lanes while
## avoiding trash and pollution. Collect clean-water tokens for bonus.

var droplet: DropletSprite
var lanes: Array = []
var lane_count: int = 3
var current_lane: int = 1
var obstacle_speed: float = 200.0
var obstacle_timer: float = 0.0
var obstacle_interval: float = 0.9
var distance_traveled: float = 0.0
var target_distance: float = 500.0
var obstacles: Array = []
var collectibles: Array = []
var screen_size: Vector2
var lane_width: float
var _swipe_start: Vector2 = Vector2.ZERO
var _is_swiping: bool = false
var _swipe_consumed: bool = false
## Which contact owns the current swipe. Mouse events have no index of their own,
## so they use the sentinel.
const NO_TOUCH_INDEX: int = -1
var _swipe_index: int = NO_TOUCH_INDEX

const OBSTACLE_EMOJIS = ["🗑️", "🛢️", "🏭", "🧱", "⚡"]
const CLEAN_EMOJIS = ["💧", "✨", "🌊"]

## How much of `obstacle_speed` counts as forward progress each second.
##
## _process accrues `distance_traveled += obstacle_speed * delta * DISTANCE_RATE`,
## i.e. the droplet is treated as travelling upstream at half the speed the river
## scrolls past it. target_distance is derived from the same constant below, so
## the two can never drift apart again.
const DISTANCE_RATE: float = 0.5

## Fraction of the clock a clean run should need to reach the reservoir.
##
## 0.9 leaves ~10% headroom: a player who never stalls finishes just before the
## buzzer, and mistake time penalties (MiniGameBase._apply_sp_time_penalty) can
## genuinely cost the round.
const TARGET_BUDGET_FRACTION: float = 0.9

## Distance the round should require, given the speed and clock it ends up with.
##
## This used to be a hardcoded 300 / 500 / 700 in the match block below, which had
## no relationship to the rate _process actually accrues at. Measured against the
## shipped tables:
##
##   Easy    300 px at 160×0.5 =  80 px/s →  3.75 s of a 20 s round
##   Medium  500 px at 220×0.5 = 110 px/s →  4.55 s of a 15 s round
##   Hard    700 px at 300×0.5 = 150 px/s →  4.67 s of a 12 s round
##
## So every difficulty ended at the same ~4.5 s mark, the timer was decorative,
## and adaptive difficulty could not change round length at all. A 300 s soak
## confirmed it at runtime: four Droplet Dash rounds, all Score:100, with the
## Spawn Pacer window logging 4.582 s and 4.681 s round times.
##
## Deriving the target instead makes the difficulty tables mean what they say
## (18.0 s / 13.5 s / 9.7 s of dodging) and feeds the adaptive window reaction
## times that actually differ by difficulty.
func _derive_target_distance() -> float:
	return obstacle_speed * DISTANCE_RATE * game_duration * TARGET_BUDGET_FRACTION

func _apply_difficulty_settings() -> void:
	# super() activates the chaos effects the algorithm selected and seeds
	# game_duration from difficulty_settings; the per-difficulty tuning below
	# then overrides the duration with this game's own pacing.
	super._apply_difficulty_settings()

	var settings = AdaptiveDifficulty.get_difficulty_settings() if AdaptiveDifficulty else {}
	var progressive_level = settings.get("progressive_level", 0)

	match current_difficulty:
		"Easy":
			obstacle_speed = 160.0
			obstacle_interval = 1.2
			game_duration = 20.0
		"Medium":
			obstacle_speed = 220.0
			obstacle_interval = 0.85
			game_duration = 15.0
		"Hard":
			obstacle_speed = 300.0
			obstacle_interval = 0.6
			game_duration = 12.0

	if progressive_level > 0:
		obstacle_speed += progressive_level * 20.0
		obstacle_interval = max(0.35, obstacle_interval - progressive_level * 0.06)
		game_duration = settings.get("time_limit", game_duration)

	# Derived last, from whatever speed and clock this round ended up with.
	target_distance = _derive_target_distance()

func _ready():
	# Localized: the title stayed English above the Filipino objective FIX 58
	# authored. _loc() keeps the English literal as the fallback for the case
	# where the table is not up yet (tools/SceneLoadCheck instantiates that way).
	game_name = _loc("droplet_dash", "Droplet Dash")
	var fallback := "SWIPE to dodge obstacles!\n"
	fallback += "Guide Droppy to the reservoir! 💧"
	game_instruction_text = (
		Localization.get_text("droplet_dash_instructions")
		if Localization else fallback
	)
	game_duration = 20.0
	game_mode = "survival"

	super._ready()

	screen_size = get_viewport_rect().size
	lane_width = screen_size.x / lane_count

	# Background - River path
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.4, 0.6)
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	bg.z_index = -10
	add_child(bg)

	# Lane dividers
	for i in range(1, lane_count):
		var divider = ColorRect.new()
		divider.color = Color(1, 1, 1, 0.15)
		divider.size = Vector2(3, screen_size.y)
		divider.position = Vector2(i * lane_width - 1.5, 0)
		divider.z_index = -5
		add_child(divider)

	# River flow lines (visual flair)
	for i in range(12):
		var flow = Label.new()
		flow.name = "Flow_%d" % i
		flow.text = "~"
		flow.add_theme_font_size_override("font_size", 24)
		flow.modulate = Color(1, 1, 1, 0.2)
		flow.position = Vector2(randf_range(10, screen_size.x - 30), randf_range(0, screen_size.y))
		flow.z_index = -8
		flow.set_meta("base_y", flow.position.y)
		add_child(flow)

	# Create droplet player.
	#
	# DropletSprite builds its own body, face and idle wobble in _ready(), so no
	# child icon is needed. The old version was a bare Node2D holding a Label with
	# the water-drop emoji at font_size 52: rendered by whatever emoji font the
	# platform shipped, unable to animate a reaction, and visibly not the same
	# character as the droplet in the cutscenes.
	droplet = DropletSprite.new()
	droplet.name = "Droplet"
	droplet.position = Vector2(lane_width * (current_lane + 0.5), screen_size.y * 0.75)
	add_child(droplet)

	# Distance progress bar
	var prog_bg = ColorRect.new()
	prog_bg.name = "ProgBg"
	prog_bg.color = Color(0.2, 0.2, 0.2, 0.7)
	prog_bg.size = Vector2(screen_size.x - 40, 12)
	prog_bg.position = Vector2(20, 125)
	add_child(prog_bg)

	var prog_fill = ColorRect.new()
	prog_fill.name = "ProgFill"
	prog_fill.color = Color(0.3, 0.8, 1.0)
	prog_fill.size = Vector2(0, 12)
	prog_fill.position = Vector2(20, 125)
	add_child(prog_fill)

	var prog_label = Label.new()
	prog_label.name = "ProgLabel"
	prog_label.text = "🏁 0%"
	prog_label.add_theme_font_size_override("font_size", 20)
	prog_label.add_theme_color_override("font_color", Color.WHITE)
	prog_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prog_label.add_theme_constant_override("outline_size", 3)
	prog_label.position = Vector2(20, 140)
	add_child(prog_label)

func _on_game_start() -> void:
	pass

## Swipe threshold in pixels before a lane change fires.
const SWIPE_THRESHOLD: float = 40.0

func _input(event: InputEvent) -> void:
	if not game_active:
		return

	# Touch/mouse swipe detection.
	#
	# The lane change fires from the DRAG, not the release. Waiting for release
	# meant a player who held the finger down after flicking sat in the old lane
	# until they let go — with obstacles arriving every 0.6-1.2 s that reads as
	# unresponsive controls. _swipe_consumed makes one press worth one lane step,
	# so a long drag cannot chain-shift across every lane.
	# ONE finger owns the gesture. Both touch branches below used to ignore
	# InputEventScreenTouch.index, and a phone is held in two hands: a resting
	# thumb is a second contact. tools/ProbeMultitouch.tscn reproduced both
	# failures - a second finger landing re-seeded _swipe_start, so the owning
	# finger's next 10px wobble measured across BOTH contacts and threw the
	# droplet a lane sideways; and that second finger lifting cancelled the
	# gesture still in progress under the first.
	#
	# emulate_mouse_from_touch defaults to true, so the first touch also arrives
	# as a synthetic InputEventMouseButton. Mouse events carry no index, so they
	# use NO_TOUCH_INDEX: on Android the real touch claims the gesture first and
	# the synthetic pair is then ignored, while on desktop the mouse claims it.
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var idx: int = (event as InputEventScreenTouch).index if event is InputEventScreenTouch else NO_TOUCH_INDEX
		if event.pressed:
			if _is_swiping:
				return
			_swipe_index = idx
			_swipe_start = event.position
			_is_swiping = true
			_swipe_consumed = false
		elif idx == _swipe_index:
			_is_swiping = false
			_swipe_consumed = false
			_swipe_index = NO_TOUCH_INDEX
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if not _is_swiping or _swipe_consumed:
			return
		var drag_idx: int = (event as InputEventScreenDrag).index if event is InputEventScreenDrag else NO_TOUCH_INDEX
		if drag_idx != _swipe_index:
			return
		var diff: Vector2 = event.position - _swipe_start
		if absf(diff.x) > SWIPE_THRESHOLD:
			_swipe_consumed = true
			_move_lane(1 if diff.x > 0.0 else -1)
func _move_lane(direction: int) -> void:
	var new_lane = clamp(current_lane + direction, 0, lane_count - 1)
	if new_lane != current_lane:
		current_lane = new_lane
		var target_x = lane_width * (current_lane + 0.5)
		var tw = create_tween()
		tw.tween_property(droplet, "position:x", target_x, 0.12).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	super._process(delta)
	if not game_active:
		return

	# Accumulate distance
	distance_traveled += obstacle_speed * delta * 0.5

	# Spawn obstacles and collectibles
	obstacle_timer -= delta
	if obstacle_timer <= 0:
		obstacle_timer = obstacle_interval + randf_range(-0.15, 0.15)
		if randf() < 0.3:
			_spawn_collectible()
		else:
			_spawn_obstacle()

	# Move obstacles down
	var to_remove: Array = []
	for obs in obstacles:
		if not is_instance_valid(obs):
			to_remove.append(obs)
			continue
		obs.position.y += obstacle_speed * delta
		# Collision check with droplet
		if obs.position.distance_to(droplet.position) < 40:
			record_action(false)
			_flash_droplet()
			obs.queue_free()
			to_remove.append(obs)
		elif obs.position.y > screen_size.y + 50:
			obs.queue_free()
			to_remove.append(obs)
	for o in to_remove:
		obstacles.erase(o)

	# Move collectibles down
	to_remove.clear()
	for col in collectibles:
		if not is_instance_valid(col):
			to_remove.append(col)
			continue
		col.position.y += obstacle_speed * delta
		if col.position.distance_to(droplet.position) < 45:
			record_action(true)
			# Squash-pop so a good catch is felt, not just scored.
			droplet.react_happy()
			col.queue_free()
			to_remove.append(col)
		elif col.position.y > screen_size.y + 50:
			col.queue_free()
			to_remove.append(col)
	for c in to_remove:
		collectibles.erase(c)

	# Animate flow lines
	for child in get_children():
		if child.name.begins_with("Flow_"):
			child.position.y += obstacle_speed * delta * 0.5
			if child.position.y > screen_size.y + 20:
				child.position.y = -20
				child.position.x = randf_range(10, screen_size.x - 30)

	# Update progress
	var progress_ratio = min(distance_traveled / target_distance, 1.0)
	var bar_w = screen_size.x - 40
	var fill = get_node_or_null("ProgFill")
	if fill:
		fill.size.x = progress_ratio * bar_w
	var lbl = get_node_or_null("ProgLabel")
	if lbl:
		lbl.text = "🏁 %d%%" % int(progress_ratio * 100)

	# Win condition - survival mode, distance reached.
	#
	# The early return matters: without it a frame that both completed the
	# distance and landed a third hit called end_game(true) and then
	# end_game(false), and the second call was swallowed by MiniGameBase's
	# _round_ended guard with a warning. Reaching the reservoir wins.
	if distance_traveled >= target_distance:
		end_game(true)
		return

	# Fail condition - too many mistakes (3 hits)
	if mistakes_made >= 3:
		end_game(false)

func _spawn_obstacle() -> void:
	var lane = randi() % lane_count
	var obs = Node2D.new()
	obs.position = Vector2(lane_width * (lane + 0.5), -50)

	var icon = Label.new()
	icon.text = OBSTACLE_EMOJIS[randi() % OBSTACLE_EMOJIS.size()]
	icon.add_theme_font_size_override("font_size", 42)
	icon.position = Vector2(-18, -18)
	obs.add_child(icon)

	add_child(obs)
	obstacles.append(obs)

func _spawn_collectible() -> void:
	var lane = randi() % lane_count
	var col = Node2D.new()
	col.position = Vector2(lane_width * (lane + 0.5), -50)

	var icon = Label.new()
	icon.text = CLEAN_EMOJIS[randi() % CLEAN_EMOJIS.size()]
	icon.add_theme_font_size_override("font_size", 36)
	icon.position = Vector2(-15, -15)
	col.add_child(icon)

	add_child(col)
	collectibles.append(col)

func _flash_droplet() -> void:
	## Mistake feedback: a red flash on the whole node plus a recoil.
	##
	## The old version also tweened `droplet:position:x` for a shake. That is the
	## same property _move_lane() animates, and it captured the "original"
	## position at hit time — swiping during a hit snapped the droplet back to the
	## pre-swipe lane. react_hurt() animates `rig:scale`, one level below the node
	## the lane tween owns, so the two can never collide.
	droplet.react_hurt()
	var tw = create_tween()
	tw.tween_property(droplet, "modulate", Color(1.5, 0.3, 0.3), 0.08)
	tw.tween_property(droplet, "modulate", Color.WHITE, 0.18)
