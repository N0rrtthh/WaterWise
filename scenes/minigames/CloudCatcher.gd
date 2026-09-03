extends MiniGameBase

## ═══════════════════════════════════════════════════════════════════
## CLOUD CATCHER - Tap clouds to release rain for thirsty plants
## ═══════════════════════════════════════════════════════════════════
## Kids tap moving clouds floating across the screen. Each tap releases
## rain drops that fall and water the plants below. Water enough plants
## before time runs out!

var clouds: Array = []
var plants: Array = []
var cloud_speed: float = 80.0
var cloud_spawn_timer: float = 0.0
var cloud_spawn_interval: float = 1.5
var plants_watered: int = 0
var target_plants: int = 8

## Plants the row always has, and the closest two of them may sit. The row grows with the
## quota (see the spawn block) and MIN_PLANT_SPACING is what stops it growing into mush:
## the plant glyph is a 48 px font, so 120 canvas units leaves a clear gap between icons
## and keeps each one its own tap-sized target.
const BASE_PLANT_COUNT: int = 6
const MIN_PLANT_SPACING: float = 120.0

## Thirst bar geometry. Width reads as attached to the 48 px plant glyph; height is the
## 6-device-px floor on the low-end profile (6 / 0.445 device px per canvas unit).
const THIRST_BAR_W: float = 64.0
const THIRST_BAR_H: float = 14.0

## Clouds are what the player taps, and they used to spawn from y=80 - straight under the
## title (y~37) and the "0 / N watered" readout (y 120 plus a 26 px line box). A tap target
## sitting behind HUD text is the same defect FIX 84 fixed in TurnOffTap by moving the taps.
const CLOUD_TOP_CLEARANCE: float = 175.0

## FIX 91 - cloud SUPPLY. The quota is really a count of clouds the player must convert: a tap
## consumes its cloud and drops five droplets in a 60-unit band, while the plants sit 213 units
## apart on Hard, so one tap waters exactly ONE plant.
##
## Two things were wrong, and they pulled in opposite directions.
##
## STOCK  the opening batch was a hardcoded 3 while target_plants is 4/6/8 - the same unscaled
##        constant FIX 88 found in the plant row, reached from the other side.
## FLOW   every later cloud entered from a screen EDGE, so it needed seconds of travel before it
##        was over anything. The far side of Hard's plant row is 1707 units from the left edge,
##        which is 14.9 s at 120 units/s against a 10 s round: the stream existed but its latency
##        exceeded the round, so late clouds could never be converted at all.
##
## Measured with tools/VerifyCloudCatcherClearable.tscn (an optimal bot: exact cloud positions,
## frame-perfect taps, no cooldown, and drop-commitment accounting so no cloud is wasted on a
## plant already covered) - before:
##     Easy    one convertible cloud every 2.50s, quota costs 10.0s of a 20s round -> 8/8 won
##     Medium  every 2.58s, quota costs 15.5s of a 15s round                       -> 3/8 won
##     Hard    every 1.45s, quota costs 11.6s of a 10s round                       -> 0/8 won
## Hard was unwinnable by anyone and Medium a coin flip, on supply rather than on skill.
##
## Raising the stock alone fixed that and broke the pacing instead: one opening cloud per plant
## put the whole quota in the sky at once, an optimal bot cleared Hard in 2.5s of its 10s, and
## the timer became decorative. So the stock stays modest and the FLOW is what carries the round -
## clouds now also condense mid-field, which is what removes the latency.
const OPENING_CLOUD_CAP: int = 5

## Share of ongoing spawns that condense over the field instead of drifting in from an edge.
## Edge entries are kept for the look - a cloud sailing in is the readable, expected thing - but
## they cannot be the only source, or the far half of the plant row is unreachable inside a short
## round. A mid-field cloud fades and scales in over CLOUD_CONDENSE_SEC so it reads as forming
## rather than popping into existence.
const MIDFIELD_SPAWN_SHARE: float = 0.5
const CLOUD_CONDENSE_SEC: float = 0.4
var screen_size: Vector2

func _apply_difficulty_settings() -> void:
	# Queues this tier's chaos_effects; without it the algorithm asks for them
	# and this game silently drops them. The per-tier game_duration below is
	# deliberate and overrides the base's time_limit write. See MiniGameBase.
	super._apply_difficulty_settings()
	var settings = AdaptiveDifficulty.get_difficulty_settings() if AdaptiveDifficulty else {}
	var progressive_level = settings.get("progressive_level", 0)

	match current_difficulty:
		"Easy":
			cloud_speed = 60.0
			cloud_spawn_interval = 1.8
			target_plants = 4
			game_duration = 20.0
		"Medium":
			cloud_speed = 80.0
			cloud_spawn_interval = 1.4
			target_plants = 6
			game_duration = 15.0
		"Hard":
			cloud_speed = 120.0
			# 1.0 left Hard exactly on the line: with the mid-field flow in place an optimal bot
			# converted one cloud every 1.02 s and needed 8 of them with the last landing ~1.9 s
			# before time (drops fall 562-765 units at 300-500 units/s), i.e. 8.2 s of tapping in an
			# 8.1 s window - it won 6 of 8 rounds, a coin-flip margin for a PERFECT player. Hard
			# should be gated by aim and speed, not by whether a cloud exists to aim at.
			cloud_spawn_interval = 0.85
			target_plants = 8
			# 10.0 was a coin flip, and this is the measurement that says so
			# (tools/VerifyCloudCatcherClearable, whose bots are frame-perfect or better
			# than human): at 10.0 the quota cost 9.1s of tapping for the optimal bot and
			# 9.5s for the one that SHIPS - margins of 1.10x and 1.05x - and they won only
			# 6 of 8 and 2 of 4 Hard rounds. Medium is the control, and its margin is the
			# band being aimed at rather than a guarantee: 11.6-12.9s of tapping in a 15s
			# clock measured across runs (1.16-1.29x), winning 6 of 8 and 3 of 4. At 12.0
			# Hard measures 9.7s and 8.1s against the 12s clock (1.24x and 1.48x) and wins
			# 7 of 8 and 4 of 4, while the optimal bot still needs 10.4s of the 12 to do it
			# - the round is not handed over, it just has room for one mis-aimed tap. Cloud
			# density, plant spacing and the 8-plant quota are untouched: Hard still demands
			# a plant every 1.5s against Medium's 2.5s.
			game_duration = 12.0

	if progressive_level > 0:
		target_plants += progressive_level
		cloud_speed += progressive_level * 15.0
		cloud_spawn_interval = max(0.5, cloud_spawn_interval - progressive_level * 0.1)
		game_duration = settings.get("time_limit", game_duration)

func _ready():
	# Localized: the title stayed English above the Filipino objective FIX 58
	# authored. _loc() keeps the English literal as the fallback for the case
	# where the table is not up yet (tools/SceneLoadCheck instantiates that way).
	game_name = _loc("cloud_catcher", "Cloud Catcher")
	var fallback := "TAP clouds to release rain!\nWater the thirsty plants below! ☁️"
	game_instruction_text = (
		Localization.get_text("cloud_catcher_instructions")
		if Localization else fallback
	)
	game_duration = 25.0
	game_mode = "quota"

	super._ready()

	screen_size = get_viewport_rect().size

	# Sky background
	var bg = ColorRect.new()
	bg.color = Color(0.53, 0.81, 0.92)
	bg.position = Vector2.ZERO
	bg.size = get_viewport_rect().size
	bg.z_index = -10
	add_child(bg)

	# Ground
	var ground = ColorRect.new()
	ground.color = Color(0.36, 0.25, 0.14)
	ground.size = Vector2(screen_size.x, 120)
	ground.position = Vector2(0, screen_size.y - 120)
	ground.z_index = -5
	add_child(ground)

	# Grass strip
	var grass = ColorRect.new()
	grass.color = Color(0.3, 0.7, 0.2)
	grass.size = Vector2(screen_size.x, 30)
	grass.position = Vector2(0, screen_size.y - 120)
	grass.z_index = -4
	add_child(grass)

	# Spawn plants along the bottom.
	#
	# The count follows the QUOTA, and the quota is then clamped to the count. It used to be a
	# hardcoded 6 while target_plants was 4 / 6 / 8 - and each plant scores at most once
	# (_water_plant() increments only when "watered" flips false to true, and the collision in
	# _process() skips plants already watered). So plants_watered could never pass 6, and the
	# win check at the bottom of _process() could never fire on Hard: a perfect round ran the
	# clock out and reported a loss. progressive_level made it worse by adding to target_plants,
	# so Medium reached the same dead end at level 1.
	#
	# Growing the row is the reading that keeps the authored curve meaning what it says - Hard
	# is meant to be eight plants, not six plants and an impossible eighth. MIN_PLANT_SPACING
	# bounds how far that can go before the row stops being readable; past it the quota is
	# clamped down instead, so "quota <= plants that exist" holds either way.
	var plant_count: int = maxi(BASE_PLANT_COUNT, target_plants)
	var max_plants: int = maxi(BASE_PLANT_COUNT, int(screen_size.x / MIN_PLANT_SPACING) - 1)
	plant_count = mini(plant_count, max_plants)
	target_plants = mini(target_plants, plant_count)
	for i in range(plant_count):
		var plant_x = (screen_size.x / (plant_count + 1)) * (i + 1)
		var plant_pos = Vector2(plant_x, screen_size.y - 140)
		var plant = _create_plant(plant_pos)
		add_child(plant)
		plants.append(plant)

	# Score display
	var score_display = Label.new()
	score_display.name = "PlantScore"
	score_display.text = _loc("hud_plants_watered", "🌱 %d / %d watered") % [0, target_plants]
	score_display.add_theme_font_size_override("font_size", 26)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	score_display.add_theme_color_override("font_outline_color", Color.BLACK)
	score_display.add_theme_constant_override("outline_size", 4)
	score_display.position = Vector2(20, 120)
	add_child(score_display)

func _create_plant(pos: Vector2) -> Node2D:
	var plant = Node2D.new()
	plant.position = pos
	plant.set_meta("watered", false)
	plant.set_meta("water_amount", 0.0)
	plant.set_meta("target_water", 1.0)

	var icon = Label.new()
	icon.name = "Icon"
	icon.text = "🌱"
	icon.add_theme_font_size_override("font_size", 48)
	icon.position = Vector2(-20, -30)
	plant.add_child(icon)

	# Thirst indicator. This is the only thing that tells the player a plant is HALF watered,
	# and half is the only intermediate state there is: target_water is 1.0 and each drop that
	# lands gives 0.5, so the bar reads 0, half, or full-then-bloomed. At the authored 40x6 it
	# was 17.8 x 2.7 device px on the 854x480 profile in tools/AuditMobileUI.gd DEVICES - the
	# game's most decision-relevant signal, under three pixels tall. THIRST_BAR_H is the height
	# that clears 6 device px there (6 / 0.445), the same floor tools/VerifySpeckDifficulty.gd
	# argues for the specks.
	var thirst_bg = ColorRect.new()
	thirst_bg.name = "ThirstBg"
	thirst_bg.color = Color(0.3, 0.3, 0.3, 0.6)
	thirst_bg.size = Vector2(THIRST_BAR_W, THIRST_BAR_H)
	thirst_bg.position = Vector2(-THIRST_BAR_W * 0.5, -46.0 - THIRST_BAR_H)
	plant.add_child(thirst_bg)

	var thirst_bar = ColorRect.new()
	thirst_bar.name = "ThirstBar"
	thirst_bar.color = Color(0.3, 0.6, 1.0)
	thirst_bar.size = Vector2(0, THIRST_BAR_H)
	thirst_bar.position = thirst_bg.position
	plant.add_child(thirst_bar)

	return plant

func _create_cloud(start_x: float) -> Node2D:
	var cloud = Node2D.new()
	cloud.position = Vector2(start_x, randf_range(CLOUD_TOP_CLEARANCE, screen_size.y * 0.35))
	cloud.set_meta("tapped", false)
	cloud.set_meta("speed", cloud_speed + randf_range(-20, 20))

	# WHAT A CLOUD LOOKS LIKE AND WHAT IT IS TO TAP ARE TWO NODES NOW
	#
	# One Button used to be both, so every animation that scaled the cloud scaled the tap target with
	# it. A mid-field cloud condenses 0.6 -> 1.0 and a tapped one shrinks to 0.3, which held the
	# 48dp-grown Button as low as 0.6x the floor while it was still the thing the player was aiming
	# at - and because clouds keep condensing all round, one target was always somewhere on that
	# ramp. The glyph is now a Label that the animations own, and the Button is an invisible box that
	# nothing scales: the target is floor size from the frame it spawns to the frame it is freed.
	var art := Label.new()
	art.text = "☁️"
	art.add_theme_font_size_override("font_size", 56)
	art.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud.add_child(art)
	# Centred on the cloud origin and scaling about its own middle, re-derived on resize: the glyph's
	# box is decided by the font, and MobileUIManager may restyle it after this frame.
	var centre_art := func() -> void:
		if is_instance_valid(art):
			art.pivot_offset = art.size * 0.5
			art.position = -art.size * 0.5
	art.resized.connect(centre_art)
	centre_art.call()
	cloud.set_meta("art", art)

	var btn = Button.new()
	btn.flat = true
	btn.custom_minimum_size = Vector2(90, 70)
	btn.pressed.connect(_on_cloud_tapped.bind(cloud))
	cloud.add_child(btn)
	# Centred after growth, not at the authored offset: the 48dp floor enlarges this button.
	centre_hit_control(btn)
	cloud.set_meta("btn", btn)

	return cloud

func _on_cloud_tapped(cloud: Node2D) -> void:
	if not game_active or cloud.get_meta("tapped", false):
		return

	cloud.set_meta("tapped", true)
	# This cloud is spent, and until now the guard above was the only thing that said so. The button
	# stays in the tree for the 0.3s fade, so leaving it enabled left a full-size target that eats
	# presses and counts as a target to anything measuring them. Disabling it makes the tree agree
	# with the guard.
	var btn: Button = cloud.get_meta("btn")
	btn.disabled = true
	# A mid-field cloud may still be condensing, and that tween owns the art scale and modulate:a -
	# the two properties the shrink-away below animates. Two live tweens on one property is the
	# defect where the loser's value is silently overwritten every frame, so retire it first.
	var condense = cloud.get_meta("condense") if cloud.has_meta("condense") else null
	if condense is Tween and (condense as Tween).is_valid():
		(condense as Tween).kill()
	record_action(true)

	# Spawn rain drops falling down
	_spawn_rain(cloud.position)

	# Shrink the ART away, so the cloud root keeps the transform the rain was spawned from
	var tw = create_tween()
	tw.tween_property(cloud.get_meta("art"), "scale", Vector2(0.3, 0.3), 0.3)
	tw.parallel().tween_property(cloud, "modulate:a", 0.0, 0.3)
	tw.tween_callback(cloud.queue_free)

func _spawn_rain(from_pos: Vector2) -> void:
	for i in range(5):
		var drop = Label.new()
		drop.text = "💧"
		drop.add_theme_font_size_override("font_size", 22)
		drop.position = Vector2(from_pos.x + randf_range(-30, 30), from_pos.y)
		drop.set_meta("fall_speed", randf_range(300, 500))
		drop.set_meta("is_rain", true)
		add_child(drop)

func _process(delta):
	super._process(delta)
	if not game_active:
		return

	# Spawn clouds
	cloud_spawn_timer -= delta
	if cloud_spawn_timer <= 0:
		cloud_spawn_timer = cloud_spawn_interval + randf_range(-0.3, 0.3)
		var cloud: Node2D
		if randf() < MIDFIELD_SPAWN_SHARE:
			# Condense over the field. An edge entry has to cross up to 1787 units before it is over
			# the far plant - 14.9 s at Hard's 120 units/s against a 10 s round - so edge spawns alone
			# leave half the plant row unreachable no matter how often they fire.
			cloud = _create_cloud(randf_range(screen_size.x * 0.15, screen_size.x * 0.85))
			if randf() < 0.5:
				cloud.set_meta("speed", -cloud.get_meta("speed"))
			cloud.modulate.a = 0.0
			# The ART scales in, not the cloud: the tap target under it is full size for the whole
			# 0.4s condense. See _create_cloud() for why the two are separate nodes.
			var art: Control = cloud.get_meta("art")
			art.scale = Vector2(0.6, 0.6)
			add_child(cloud)
			var condense := create_tween()
			cloud.set_meta("condense", condense)
			condense.tween_property(cloud, "modulate:a", 1.0, CLOUD_CONDENSE_SEC)
			condense.parallel().tween_property(art, "scale", Vector2.ONE, CLOUD_CONDENSE_SEC) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			var side := randi() % 2
			cloud = _create_cloud(-80.0 if side == 0 else screen_size.x + 80.0)
			if side == 1:
				cloud.set_meta("speed", -cloud.get_meta("speed"))
			add_child(cloud)
		clouds.append(cloud)

	# Move clouds
	var to_remove: Array = []
	for cloud in clouds:
		if not is_instance_valid(cloud):
			to_remove.append(cloud)
			continue
		cloud.position.x += cloud.get_meta("speed") * delta
		if cloud.position.x < -120 or cloud.position.x > screen_size.x + 120:
			cloud.queue_free()
			to_remove.append(cloud)
	for c in to_remove:
		clouds.erase(c)

	# Move rain drops and check plant collisions
	for child in get_children():
		if child is Label and child.has_meta("is_rain"):
			child.position.y += child.get_meta("fall_speed") * delta
			# Check plant watering
			for plant in plants:
				if is_instance_valid(plant) and not plant.get_meta("watered", false):
					if child.position.distance_to(plant.position) < 50:
						_water_plant(plant, 0.5)
						child.queue_free()
						break
			# Remove if off-screen
			if child.position.y > screen_size.y:
				child.queue_free()

	# Update score display
	var display = get_node_or_null("PlantScore")
	if display:
		display.text = _loc("hud_plants_watered", "🌱 %d / %d watered") % [plants_watered, target_plants]

	# Check win
	if plants_watered >= target_plants:
		end_game(true)

func _water_plant(plant: Node2D, amount: float) -> void:
	var current = plant.get_meta("water_amount", 0.0) + amount
	plant.set_meta("water_amount", current)

	var bar = plant.get_node_or_null("ThirstBar")
	if bar:
		var ratio = min(current / plant.get_meta("target_water", 1.0), 1.0)
		bar.size.x = ratio * THIRST_BAR_W

	if current >= plant.get_meta("target_water", 1.0) and not plant.get_meta("watered"):
		plant.set_meta("watered", true)
		plants_watered += 1
		var icon = plant.get_node_or_null("Icon")
		if icon:
			icon.text = "🌻"
			var tw = create_tween()
			tw.tween_property(plant, "scale", Vector2(1.3, 1.3), 0.15)
			tw.tween_property(plant, "scale", Vector2(1.0, 1.0), 0.15)

func _on_game_start() -> void:
	# A modest opening stock: enough that the first seconds have something to convert, not enough
	# to hold the whole quota at once. The ongoing stream below is what has to carry the round.
	var initial: int = clampi(target_plants / 2 + 1, 3, OPENING_CLOUD_CAP)
	# Spread across the field in even slots rather than randf_range over the whole width: several
	# random x values inside 1720 units overlap often, and two clouds on the same spot is one tap
	# target, not two. The half-slot offset puts each cloud between plants instead of on one, so it
	# has to DRIFT into place - about 0.9 s at Hard's 120 units/s - which is the tap-it-as-it-passes
	# beat the game is built on rather than a row of free gimmes at t=0.
	var slot: float = screen_size.x / float(initial + 1)
	for i in range(initial):
		var x: float = slot * (float(i) + 0.5) + randf_range(-slot * 0.15, slot * 0.15)
		var cloud = _create_cloud(clampf(x, 60.0, screen_size.x - 60.0))
		add_child(cloud)
		clouds.append(cloud)
