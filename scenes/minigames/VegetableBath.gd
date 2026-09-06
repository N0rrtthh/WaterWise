extends "res://scripts/MiniGameBase.gd"

## How close a tap counts as grabbing a veggie. 74 units is half of the 48dp touch floor on
## the densest profile this game ships to (WVGA 4.5in, 217.7dpi -> 147 canvas units), so the
## grab is a 148-unit target end to end. The old 50 gave a 100-unit target - 33dp - which
## tools/VerifyTouchTargets.tscn measured as under the Android and WCAG minimum.
const GRAB_RADIUS: float = 74.0

var veggies_to_wash: int = 5
var veggies_washed: int = 0

var source_basket: Node2D
var wash_bowl: Node2D
var clean_basket: Node2D

var veggies: Array = []
var selected_veggie: Node2D = null
var drag_offset: Vector2 = Vector2.ZERO

## Set the moment the quota is met, so the round can only be ended once.
##
## The quota branch in _check_placement() awaits a 0.5s celebratory beat before
## end_game(true), and nothing stopped a further delivery from re-entering it
## during that gap. Every Vegetable Bath completion in the 300s soak logged
## `end_game(true) ignored — round already ended`.
var _quota_reached: bool = false

## Failure reactions for a dirty veggie dropped in the clean basket. Two or three
## words so they read in the 0.4s they are on screen, and each one names the waste
## it stands for: rinsing again means running the tap twice. The English text is kept
## beside the key as the fallback, so a table miss degrades to readable copy instead
## of printing "veg_quip_still_muddy" over the basket.
const DIRTY_QUIPS: Array[Dictionary] = [
	{"key": "veg_quip_still_muddy", "en": "STILL MUDDY! 🥕"},
	{"key": "veg_quip_rinse_first", "en": "RINSE IT FIRST! 💧"},
	{"key": "veg_quip_thats_soil", "en": "THAT'S SOIL! 🌱"}
]

func _apply_difficulty_settings() -> void:
	# super() activates the chaos effects the algorithm picked for this round and
	# seeds game_duration from difficulty_settings; the table below then overrides
	# the duration with this game's own pacing.
	super._apply_difficulty_settings()

	match current_difficulty:
		"Easy":
			veggies_to_wash = 3
			game_duration = 20.0
		"Medium":
			veggies_to_wash = 4
			game_duration = 20.0
		"Hard":
			veggies_to_wash = 5
			game_duration = 18.0

	# The pool has to match the quota it is graded against — see _sync_veggie_pool.
	_sync_veggie_pool()

## Rebuild the veggie pool whenever the quota changes under it.
##
## MiniGameBase._ready() opens with `await get_tree().process_frame`, so
## `super._ready()` on line 36 returns immediately and the rest of THIS _ready()
## — including _create_veggies() — runs a whole frame before the base resumes and
## calls _apply_difficulty_settings(). _create_veggies() therefore ran against the
## `veggies_to_wash = 5` member initializer, not the difficulty value.
##
## On Easy that produced 5 veggies for a quota of 3: two deliveries past the quota,
## each filing another record_action(true) and re-entering the end_game branch.
## Verified with tools/VerifyRoundBudgets.tscn before the fix —
## `washed=5/3 total_actions=5 score=65`, two rejected end_game calls, and the
## inflated score went on to feed AdaptiveDifficulty as S=0.882 / Φ=1.000.
##
## Called from _apply_difficulty_settings(), which runs while the instruction
## overlay still covers the board, so the correction is never visible.
func _sync_veggie_pool() -> void:
	if source_basket == null:
		# Difficulty resolved before the board exists (also the harness's path);
		# _ready() creates the pool at the right size on its own.
		return
	if veggies.size() == veggies_to_wash:
		return
	for veggie in veggies:
		if is_instance_valid(veggie):
			veggie.queue_free()
	veggies.clear()
	_create_veggies()
	_refresh_score_label()

func _refresh_score_label() -> void:
	var lbl := get_node_or_null("ScoreLabel") as Label
	if lbl:
		lbl.text = _loc("hud_veggies_clean", "🥬 Clean: %d / %d") % [veggies_washed, veggies_to_wash]

func _ready():
	# Localized: the title stayed English above the Filipino objective FIX 58
	# authored. _loc() keeps the English literal as the fallback for the case
	# where the table is not up yet (tools/SceneLoadCheck instantiates that way).
	game_name = _loc("vegetable_bath", "Vegetable Bath")
	var fallback := "DRAG: Dirty Basket ➡ Wash Bowl ➡ Clean Basket!\n"
	fallback += "Dirty in clean = TIME PENALTY! 🥕"
	game_instruction_text = _loc("vegetable_bath_instructions", fallback)
	game_duration = 25.0
	game_mode = "quota"
	
	super._ready()
	
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.95, 0.9, 0.85)
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	bg.z_index = -10
	add_child(bg)
	
	# Counter
	var counter = ColorRect.new()
	counter.color = Color(0.55, 0.35, 0.2)
	counter.position = Vector2(0, screen_size.y * 0.78)
	counter.size = Vector2(screen_size.x, screen_size.y * 0.22)
	counter.z_index = -5
	add_child(counter)
	
	# Score
	var score_lbl = Label.new()
	score_lbl.name = "ScoreLabel"
	score_lbl.text = _loc("hud_veggies_clean", "🥬 Clean: %d / %d") % [0, veggies_to_wash]
	score_lbl.add_theme_font_size_override("font_size", 32)
	score_lbl.add_theme_color_override("font_color", Color.WHITE)
	MiniGameAssets.outline_text(score_lbl)
	score_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	score_lbl.add_theme_constant_override("outline_size", 4)
	score_lbl.position = Vector2(screen_size.x / 2 - 100, 120)
	add_child(score_lbl)
	
	_create_source_basket(screen_size)
	_create_wash_bowl(screen_size)
	_create_clean_basket(screen_size)
	_create_veggies()

func _create_source_basket(screen_size: Vector2):
	source_basket = Node2D.new()
	source_basket.position = Vector2(screen_size.x * 0.15, screen_size.y * 0.55)
	add_child(source_basket)
	
	var basket = Polygon2D.new()
	basket.polygon = PackedVector2Array([
		Vector2(-80, -40), Vector2(80, -40),
		Vector2(70, 60), Vector2(-70, 60)
	])
	basket.color = Color(0.6, 0.4, 0.2)
	source_basket.add_child(basket)
	
	var lbl = Label.new()
	lbl.text = _loc("hud_veggie_dirty", "🥬 DIRTY")
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.3))
	MiniGameAssets.outline_text(lbl)
	lbl.position = Vector2(-45, 65)
	source_basket.add_child(lbl)

func _create_wash_bowl(screen_size: Vector2):
	wash_bowl = Node2D.new()
	wash_bowl.position = Vector2(screen_size.x * 0.5, screen_size.y * 0.55)
	add_child(wash_bowl)
	
	var bowl = Polygon2D.new()
	bowl.polygon = PackedVector2Array([
		Vector2(-90, -30), Vector2(90, -30),
		Vector2(75, 60), Vector2(-75, 60)
	])
	bowl.color = Color(0.7, 0.7, 0.75)
	wash_bowl.add_child(bowl)
	
	var water = Polygon2D.new()
	water.polygon = PackedVector2Array([
		Vector2(-80, -20), Vector2(80, -20),
		Vector2(65, 55), Vector2(-65, 55)
	])
	water.color = Color(0.3, 0.6, 0.9, 0.7)
	wash_bowl.add_child(water)
	
	var lbl = Label.new()
	lbl.text = _loc("hud_veggie_wash", "💧 WASH")
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.2, 0.5, 0.8))
	MiniGameAssets.outline_text(lbl)
	lbl.position = Vector2(-45, 65)
	wash_bowl.add_child(lbl)

func _create_clean_basket(screen_size: Vector2):
	clean_basket = Node2D.new()
	clean_basket.position = Vector2(screen_size.x * 0.85, screen_size.y * 0.55)
	add_child(clean_basket)
	
	var basket = Polygon2D.new()
	basket.polygon = PackedVector2Array([
		Vector2(-80, -40), Vector2(80, -40),
		Vector2(70, 60), Vector2(-70, 60)
	])
	basket.color = Color(0.4, 0.7, 0.4)
	clean_basket.add_child(basket)
	
	var lbl = Label.new()
	lbl.text = _loc("hud_veggie_clean", "✔ CLEAN")
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
	MiniGameAssets.outline_text(lbl)
	lbl.position = Vector2(-45, 65)
	clean_basket.add_child(lbl)

func _create_veggies():
	var types = [
		{"color": Color(1.0, 0.4, 0.2), "emoji": "🥕"},
		{"color": Color(0.2, 0.7, 0.2), "emoji": "🥬"},
		{"color": Color(0.8, 0.2, 0.2), "emoji": "🍅"},
		{"color": Color(0.5, 0.3, 0.6), "emoji": "🍆"},
		{"color": Color(0.9, 0.8, 0.2), "emoji": "🌽"}
	]
	
	for i in range(veggies_to_wash):
		var type = types[i % types.size()]
		var veggie = Node2D.new()
		veggie.position = source_basket.position + Vector2(randf_range(-50, 50), randf_range(-25, 25))
		veggie.set_meta("washed", false)
		veggie.set_meta("done", false)
		add_child(veggie)
		
		var visual = Polygon2D.new()
		var points = PackedVector2Array()
		for j in range(10):
			var angle = j * TAU / 10
			points.append(Vector2(cos(angle) * 28, sin(angle) * 28))
		visual.polygon = points
		visual.color = type.color
		visual.name = "Visual"
		veggie.add_child(visual)
		
		var emoji = Label.new()
		emoji.text = type.emoji
		emoji.add_theme_font_size_override("font_size", 32)
		emoji.position = Vector2(-16, -20)
		veggie.add_child(emoji)
		
		var dirt = Node2D.new()
		dirt.name = "Dirt"
		for d in range(4):
			var spot = Polygon2D.new()
			var sp = PackedVector2Array()
			for k in range(5):
				var a = k * TAU / 5
				sp.append(Vector2(cos(a) * 6, sin(a) * 6))
			spot.polygon = sp
			spot.color = Color(0.4, 0.3, 0.15, 0.7)
			spot.position = Vector2(randf_range(-18, 18), randf_range(-18, 18))
			dirt.add_child(spot)
		veggie.add_child(dirt)
		
		veggies.append(veggie)

func _input(event):
	if not game_active: return
	
	var pos = Vector2.ZERO
	var pressed = false
	var released = false
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	
	if pressed:
		# Nearest, not first in the list: the veggies spawn as a jittered pile inside the
		# source basket (+/-50 x, +/-25 y), so two or three sit under one 74-unit grab and
		# first-match handed the player whichever happened to spawn earliest rather than the
		# one under the finger.
		var grabbed: Node2D = null
		var grabbed_d: float = INF
		for veggie in veggies:
			if not is_instance_valid(veggie): continue
			if veggie.get_meta("done"): continue
			var d: float = pos.distance_squared_to(veggie.position)
			if d < GRAB_RADIUS * GRAB_RADIUS and d < grabbed_d:
				grabbed_d = d
				grabbed = veggie as Node2D
		if grabbed != null:
			selected_veggie = grabbed
			drag_offset = grabbed.position - pos
			grabbed.scale = Vector2(1.2, 1.2)
			grabbed.z_index = 10
	
	if released and selected_veggie:
		selected_veggie.scale = Vector2(1.0, 1.0)
		selected_veggie.z_index = 0
		_check_placement(selected_veggie)
		selected_veggie = null

func _check_placement(veggie: Node2D):
	# Guarded here rather than in _input() because _input() is not the only caller:
	# AutoPlayManager._play_vegetable_bath() repositions a veggie and calls this
	# directly, bypassing the `done` test that guards the human drag path. A veggie
	# already in the clean basket must never be counted twice no matter who asks.
	if veggie.get_meta("done", false):
		return

	var pos = veggie.position

	# In wash bowl
	if pos.distance_to(wash_bowl.position) < 100:
		if not veggie.get_meta("washed"):
			veggie.set_meta("washed", true)
			veggie.get_node("Dirt").visible = false
			var sparkle = Label.new()
			sparkle.text = "✨"
			sparkle.add_theme_font_size_override("font_size", 40)
			sparkle.position = veggie.position + Vector2(-15, -40)
			sparkle.pivot_offset = Vector2(20, 20)
			sparkle.scale = Vector2(0.3, 0.3)
			add_child(sparkle)
			# Bursts to oversize and settles as it fades, so the frame the dirt
			# disappears has an impact instead of a plain crossfade. Animated on the
			# sparkle rather than the veggie: _input() owns `veggie.scale` for the
			# drag lift, and two tweens on one property fight.
			var tw = create_tween()
			tw.tween_property(sparkle, "scale", Vector2(1.35, 1.35), 0.1) \
				.set_ease(Tween.EASE_OUT)
			tw.tween_property(sparkle, "scale", Vector2.ONE, 0.08)
			tw.parallel().tween_property(sparkle, "position:y", sparkle.position.y - 26, 0.42)
			tw.tween_property(sparkle, "modulate:a", 0.0, 0.34)
			tw.tween_callback(sparkle.queue_free)
		veggie.position = wash_bowl.position + Vector2(randf_range(-40, 40), randf_range(-15, 25))
		return

	# In clean basket
	if pos.distance_to(clean_basket.position) < 100:
		if veggie.get_meta("washed"):
			veggie.set_meta("done", true)
			veggies_washed += 1
			record_action(true)
			_refresh_score_label()
			veggie.position = clean_basket.position + Vector2(randf_range(-40, 40), randf_range(-20, 30))
			# _quota_reached, not `veggies_washed >= veggies_to_wash`: the branch
			# awaits before end_game(), and a delivery landing inside that window
			# used to re-enter it and call end_game(true) a second time.
			if not _quota_reached and veggies_washed >= veggies_to_wash:
				_quota_reached = true
				await round_delay(0.5)
				end_game(true)
		else:
			# The time cost is MiniGameBase's: record_action(false) runs
			# _apply_sp_time_penalty(), which charges a difficulty-scaled fraction
			# of the round (_penalty_for_difficulty(), 12/18/25%).
			record_action(false)
			var warn = Label.new()
			var quip: Dictionary = DIRTY_QUIPS[randi() % DIRTY_QUIPS.size()]
			warn.text = _loc(str(quip["key"]), str(quip["en"]))
			warn.add_theme_font_size_override("font_size", 34)
			warn.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
			MiniGameAssets.outline_text(warn)
			warn.add_theme_color_override("font_outline_color", Color.BLACK)
			warn.add_theme_constant_override("outline_size", 4)
			warn.position = veggie.position + Vector2(-70, -70)
			warn.pivot_offset = Vector2(70, 20)
			warn.scale = Vector2(0.6, 1.4)
			add_child(warn)
			var tw = create_tween()
			tw.tween_property(warn, "scale", Vector2(1.15, 0.9), 0.09).set_ease(Tween.EASE_OUT)
			tw.tween_property(warn, "scale", Vector2.ONE, 0.07)
			tw.tween_property(warn, "modulate:a", 0.0, 0.5)
			tw.tween_callback(warn.queue_free)
			# Rejected, not returned: the veggie is flung back to the dirty basket
			# with a full spin so the refusal is legible from the movement alone.
			# One turn lands rotation back where it started.
			var bounce_tw = create_tween()
			veggie.rotation = 0.0
			bounce_tw.set_parallel(true)
			bounce_tw.tween_property(veggie, "position", source_basket.position, 0.34) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
			bounce_tw.tween_property(veggie, "rotation", TAU, 0.34)
		return
	
	# Return to source
	var home := source_basket.position + Vector2(randf_range(-40, 40), randf_range(-20, 20))
	var return_tw = create_tween()
	return_tw.tween_property(veggie, "position", home, 0.2)

func _process(delta):
	super._process(delta)
	if not game_active: return
	
	if selected_veggie and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var viewport = get_viewport()
		if viewport:
			selected_veggie.position = viewport.get_mouse_position() + drag_offset
