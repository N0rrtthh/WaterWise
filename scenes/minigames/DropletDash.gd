extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## DROPLET DASH - Guide a water droplet through obstacles to the reservoir
## ═══════════════════════════════════════════════════════════════════
## The player swipes/drags to move a water droplet across lanes while
## avoiding trash and pollution. Collect clean-water tokens for bonus.

var droplet: Node2D
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

const OBSTACLE_EMOJIS = ["🗑️", "🛢️", "🏭", "🧱", "⚡"]
const CLEAN_EMOJIS = ["💧", "✨", "🌊"]

func _apply_difficulty_settings() -> void:
	var settings = AdaptiveDifficulty.get_difficulty_settings() if AdaptiveDifficulty else {}
	var progressive_level = settings.get("progressive_level", 0)

	match current_difficulty:
		"Easy":
			obstacle_speed = 160.0
			obstacle_interval = 1.2
			target_distance = 300.0
			game_duration = 20.0
		"Medium":
			obstacle_speed = 220.0
			obstacle_interval = 0.85
			target_distance = 500.0
			game_duration = 15.0
		"Hard":
			obstacle_speed = 300.0
			obstacle_interval = 0.6
			target_distance = 700.0
			game_duration = 12.0

	if progressive_level > 0:
		obstacle_speed += progressive_level * 20.0
		obstacle_interval = max(0.35, obstacle_interval - progressive_level * 0.06)
		target_distance += progressive_level * 80.0
		game_duration = settings.get("time_limit", game_duration)

func _ready():
	game_name = "Droplet Dash"
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
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
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

	# Create droplet player
	droplet = Node2D.new()
	droplet.name = "Droplet"
	droplet.position = Vector2(lane_width * (current_lane + 0.5), screen_size.y * 0.75)
	add_child(droplet)

	var droplet_icon = Label.new()
	droplet_icon.name = "Icon"
	droplet_icon.text = "💧"
	droplet_icon.add_theme_font_size_override("font_size", 52)
	droplet_icon.position = Vector2(-22, -26)
	droplet.add_child(droplet_icon)

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

func _input(event: InputEvent) -> void:
	if not game_active:
		return

	# Touch/mouse swipe detection
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_swipe_start = event.position
			_is_swiping = true
		elif _is_swiping:
			_is_swiping = false
			var diff = event.position - _swipe_start
			if abs(diff.x) > 40:
				if diff.x > 0:
					_move_lane(1)
				else:
					_move_lane(-1)

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

	# Win condition - survival mode, distance reached
	if distance_traveled >= target_distance:
		end_game(true)

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
	var tw = create_tween()
	tw.tween_property(droplet, "modulate", Color(1.5, 0.3, 0.3), 0.1)
	tw.tween_property(droplet, "modulate", Color.WHITE, 0.2)
	# Shake
	var orig_pos = droplet.position
	tw.parallel().tween_property(droplet, "position:x", orig_pos.x + 10, 0.05)
	tw.tween_property(droplet, "position:x", orig_pos.x - 10, 0.05)
	tw.tween_property(droplet, "position:x", orig_pos.x, 0.05)
