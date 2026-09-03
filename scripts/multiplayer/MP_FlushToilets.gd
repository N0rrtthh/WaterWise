extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## Bundle 2: Flush Toilet with Shower Water
## P2 uses P1's shower water to flush toilet

## HOW MUCH MESS ENDS A LIFE, AND HOW FAST MESS ARRIVES
##
## Both numbers were set so the rule could never fire. A 12s cadence puts at most 3 toilets on a
## 6-toilet board inside a 30s round (one dirty at the start, two more at t=12 and t=24), and the
## allowance was 5 — so the failure the overlay advertises was unreachable by arithmetic, and the
## round could only ever end in MultiplayerMiniGameBase's unconditional survival win. Both were
## inflated ("was 3 — more forgiving while P2 waits for water") to compensate for charging lives
## during dry spells, which _mark_toilet_dirty() now refuses to do; with the unfairness fixed at
## its source the numbers can go back to describing a real bathroom. At 6s the board offers 6
## dirtyings per round, so an allowance of 3 is crossable by t=12 — and 6 flushes at 10 points
## brings this role's ceiling to 60 against its partner's 150 instead of 30.
const MAX_UNFLUSHED: int = 3
## How often another toilet gets dirty. Named because the timer was retuned 8s → 12s while
## the overlay kept saying 8, and the log line beside it said something else again.
const DIRTY_INTERVAL: float = 6.0

## HOW THE SIX TOILETS ARE ARRANGED
##
## They used to be pinned at (350 + col*250, 200 + row*250): a 500x250 cluster in the middle of
## the 1152x648 box these scenes were authored against. On the shipping 1920x1080 canvas that
## leaves ~700 units of bare tile either side, keeps every toilet at 160x170 while the screen has
## room for half again as much, and the dead margins grow with the aspect ratio under
## stretch/aspect="expand". Spreading the grid over playfield_rect() — the way MP_MopFloor lays
## out its floor — makes the bathroom fill the bathroom and the tap targets grow with it.
const HUD_BAND_FRAC: float = 0.20
const SIDE_MARGIN_FRAC: float = 0.10
const BOTTOM_MARGIN_FRAC: float = 0.10
const TOILET_COLS: int = 3
const TOILET_ROWS: int = 2
## Breathing room between two toilets, so neighbouring hit shapes cannot swallow each other's taps.
const TOILET_GAP: float = 40.0
## The authored size, kept as a floor: 170 units on the short side is 57dp, already clear of the
## 48dp Android/WCAG floor tools/VerifyTouchTargets.tscn measures.
const MIN_TOILET: Vector2 = Vector2(160.0, 170.0)
## The art is generated at this resolution and scaled onto whatever hit size the field allows.
const TOILET_TEX: Vector2 = Vector2(120.0, 140.0)

var available_water: int = 0
var toilets_flushed: int = 0
var unflushed_count: int = 0
var toilets: Array = []
var spawn_timer: Timer
var water_indicator_label: Label

func get_instructions() -> String:
	return Localization.get_text("mp_flush_toilets_instructions") % [int(DIRTY_INTERVAL), MAX_UNFLUSHED]

func get_controls_text() -> String:
	return Localization.get_text("mp_flush_toilets_controls")

func _on_multiplayer_ready() -> void:
	game_name = "Flush Toilets"
	title_key = "mp_title_flush_toilets"
	
	_create_water_indicator()
	_create_toilets()
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = DIRTY_INTERVAL
	spawn_timer.timeout.connect(_mark_toilet_dirty)
	add_child(spawn_timer)
	
	_log("🚽 Flush toilets with shower water! %d unflushed = lose 1 life" % MAX_UNFLUSHED)

func _on_game_start() -> void:
	spawn_timer.start()
	# Give P2 a small starter supply so they can flush right away
	# before P1’s first full bucket arrives.
	available_water = 3
	_update_water_display()
	_log("💧 Starting with %d shower water" % available_water)
	if AutoPlayManager and AutoPlayManager.is_mp_auto_play_enabled():
		AutoPlayManager.register_multiplayer_game(self, my_role)

func _create_water_indicator() -> void:
	var panel = PanelContainer.new()
	# Screen space, not world space: the Camera2D would otherwise drag this counter
	# across the screen with the aspect ratio. See attach_hud_panel() in the base.
	attach_hud_panel(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = Localization.get_text("mp_res_shower_water")
	vbox.add_child(title)
	
	var label = Label.new()
	label.name = "WaterLabel"
	label.text = "💧 x 0"
	label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(label)
	water_indicator_label = label

func _create_toilets() -> void:
	var field := playfield_rect()
	if field.size.x <= 1.0:
		# No viewport yet (headless first frame). The authored 1920x1080 design box,
		# camera-centred the same way playfield_rect() would return it.
		field = Rect2(Vector2(576.0, 324.0) - Vector2(960.0, 540.0), Vector2(1920.0, 1080.0))
	# The HUD band (water counter, timer, score) owns the top of the screen.
	var top: float = field.size.y * HUD_BAND_FRAC
	var area := Rect2(
		field.position + Vector2(field.size.x * SIDE_MARGIN_FRAC, top),
		Vector2(field.size.x * (1.0 - SIDE_MARGIN_FRAC * 2.0),
			field.size.y - top - field.size.y * BOTTOM_MARGIN_FRAC))
	var step := Vector2(area.size.x / float(TOILET_COLS), area.size.y / float(TOILET_ROWS))
	var hit := Vector2(
		maxf(step.x - TOILET_GAP, MIN_TOILET.x),
		maxf(step.y - TOILET_GAP, MIN_TOILET.y))
	for i in range(TOILET_COLS * TOILET_ROWS):
		var toilet = Area2D.new()
		var row: int = i / TOILET_COLS
		var col: int = i % TOILET_COLS
		toilet.position = area.position + Vector2(
			(float(col) + 0.5) * step.x, (float(row) + 0.5) * step.y)
		toilet.set_meta("needs_flush", false)
		add_child(toilet)
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = hit
		collision.shape = shape
		toilet.add_child(collision)
		
		var visual = Sprite2D.new()
		visual.name = "Visual"
		# create_toilet_texture() writes every pixel from GDScript, so the art is generated
		# once at TOILET_TEX and scaled onto the hit shape: x6 toilets at full field size
		# would be ~200k more set_pixel calls at round start for no visible gain.
		visual.texture = MiniGameAssets.create_toilet_texture(int(TOILET_TEX.x), int(TOILET_TEX.y))
		visual.scale = hit / TOILET_TEX
		toilet.add_child(visual)
		
		var label = Label.new()
		label.name = "Label"
		label.text = Localization.get_text("mp_toilet_clean")
		# Just above the bowl, in the same proportion the authored (-40, -90) had at 160x170.
		label.position = Vector2(-hit.x * 0.25, -hit.y * 0.53)
		label.add_theme_font_size_override("font_size", 20)
		MiniGameAssets.outline_text(label)
		toilet.add_child(label)
		
		toilet.input_event.connect(_on_toilet_clicked.bind(toilet))
		toilets.append(toilet)

func _mark_toilet_dirty() -> void:
	var clean_toilets = toilets.filter(func(t): return not t.get_meta("needs_flush", false))
	if not clean_toilets.is_empty():
		var toilet = clean_toilets[randi() % clean_toilets.size()]
		toilet.set_meta("needs_flush", true)
		toilet.get_node("Visual").modulate = Color(0.8, 0.7, 0.4)
		toilet.get_node("Label").text = Localization.get_text("mp_toilet_dirty")
	
	# Count the board instead of keeping a parallel tally beside it. unflushed_count used to
	# be incremented once per dirtying and zeroed the moment it reached MAX_UNFLUSHED, while
	# every toilet it had counted stayed dirty — so the number shown to the player stopped
	# describing the bathroom (measured: it said 1 with 6 of 6 dirty). Worse, with 6 toilets
	# and an allowance of 5, that reset made a second penalty need 5 more dirtyings the board
	# had no room for: once every toilet was filthy the early return above fired forever and
	# total failure cost the team nothing at all (measured 0 lives over 3 dirty ticks).
	unflushed_count = _dirty_toilet_count()
	
	if unflushed_count >= MAX_UNFLUSHED:
		# A LIFE ONLY GOES WHERE WATER COULD HAVE GONE
		#
		# Flushing spends a unit of shower water only P1 can send. While this player holds none,
		# every toilet on the board is P1's pace rather than a mistake, and one of three shared
		# lives is far too much to charge for it. So the rule waits: the bathroom keeps getting
		# worse (the honest state of it), and the moment there is water to flush with, the same
		# threshold applies as before.
		if available_water > 0:
			_log("💩 %d toilets need flushing — lose 1 life!" % unflushed_count)
			report_miss_to_host()
			# And the board resets. MAX_UNFLUSHED is 3 of 6 toilets and P1's water arrives two
			# units at a time, so a board already over the line could not always be brought back
			# under it before the next dirtying — which would charge a second and third life for
			# the same mess, from a position the player could not escape. Same shape as
			# MP_MopFloor's _clean_all_tiles() on its own penalty.
			_reset_all_toilets()
		else:
			_log("💩 %d toilets need flushing, but there is no water to flush with — not charged"
				% unflushed_count)
	else:
		_log("💩 Toilet dirty! (%d/%d)" % [unflushed_count, MAX_UNFLUSHED])

## Puts every toilet back to clean. Called when the mess costs the team a life, so the same
## overflowing board cannot be charged for twice.
func _reset_all_toilets() -> void:
	for toilet in toilets:
		if not is_instance_valid(toilet):
			continue
		toilet.set_meta("needs_flush", false)
		toilet.get_node("Visual").modulate = Color(1.0, 1.0, 1.0)
		toilet.get_node("Label").text = Localization.get_text("mp_toilet_clean")
	unflushed_count = _dirty_toilet_count()

## The toilets actually waiting on a flush right now. The single source of truth for the
## fail state, so the count cannot drift from the board it describes.
func _dirty_toilet_count() -> int:
	return toilets.filter(func(t): return t.get_meta("needs_flush", false)).size()

func _on_toilet_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, toilet: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_flush(toilet)

func _try_flush(toilet: Area2D) -> void:
	if not game_active:
		return
	
	if not toilet.get_meta("needs_flush", false):
		return
	
	if available_water <= 0:
		_log("⚠️ No water! Wait for partner")
		return
	
	available_water -= 1
	_update_water_display()
	
	toilet.set_meta("needs_flush", false)
	toilet.get_node("Visual").modulate = Color(1.0, 1.0, 1.0)
	toilet.get_node("Label").text = Localization.get_text("mp_toilet_clean")
	
	toilets_flushed += 1
	unflushed_count = _dirty_toilet_count()
	add_score(10)
	_log("✨ Flushed toilet! Total: %d" % toilets_flushed)

func _on_resource_received(_from_player: int, resource_type: String, amount: int, _quality: float) -> void:
	if resource_type == "shower_water":
		available_water += amount
		_update_water_display()
		_log("📥 Received %d shower water (Total: %d)" % [amount, available_water])

func _update_water_display() -> void:
	if water_indicator_label:
		water_indicator_label.text = "💧 x %d" % available_water

func _on_game_over() -> void:
	spawn_timer.stop()
	super._on_game_over()
