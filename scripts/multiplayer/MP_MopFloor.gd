extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## Bundle 4: Mop Floor with Laundry Water
## P2 mops floors using P1's laundry water

## HOW MUCH MESS ENDS A LIFE, AND HOW FAST MESS ARRIVES
##
## Both were set so the rule could never fire. An 8s cadence dirties at most 4 of the 20 tiles
## inside a 30s round (one at the start, then t=8/16/24) and the allowance was 12, so the failure
## the overlay advertises was unreachable by arithmetic and the round could only end in
## MultiplayerMiniGameBase's unconditional survival win. Both had been inflated ("was 10 — more
## breathing room") to soften a penalty that fired during dry spells, which _make_tile_dirty() now
## refuses to charge for; with that unfairness fixed at its source these can describe a real
## floor again. At 5s the round offers 7 dirtyings, so an allowance of 4 is crossable by t=15 —
## and 7 mops at 10 points lifts this role's ceiling to 70 against its partner's 125, from 40.
const MAX_DIRTY_TILES: int = 4

## Floor grid shape and the fractions of the playfield it leaves free. The HUD band at the top
## carries the water counter, timer and score; the bottom strip keeps the last row off the edge
## on a device with a gesture bar.
const TILE_COLS: int = 5
const TILE_ROWS: int = 4
const TILE_GAP: float = 14.0             # grout: the visible seam between two tiles
const HUD_BAND_FRAC: float = 0.20
const BOTTOM_MARGIN_FRAC: float = 0.06
const SIDE_MARGIN_FRAC: float = 0.04

## How often one more tile gets dirty. The timer carried a bare 8.0 while the overlay still
## promised "every 5 seconds" from an earlier tune, so the number is named once here now.
const DIRTY_INTERVAL: float = 5.0   # matches the "every 5 seconds" the overlay has promised all along

var available_water: int = 0
var tiles_mopped: int = 0
var floor_tiles: Array = []
var dirty_timer: Timer
var water_indicator_label: Label

func get_instructions() -> String:
	return Localization.get_text("mp_mop_floor_instructions") % [int(DIRTY_INTERVAL), MAX_DIRTY_TILES]

func get_controls_text() -> String:
	return Localization.get_text("mp_mop_floor_controls")

func _on_multiplayer_ready() -> void:
	game_name = "Mop Floor"
	title_key = "mp_title_mop_floor"
	
	_create_water_indicator()
	_create_floor()
	
	dirty_timer = Timer.new()
	dirty_timer.wait_time = DIRTY_INTERVAL
	dirty_timer.timeout.connect(_make_tile_dirty)
	add_child(dirty_timer)
	
	_log("🧹 Mop dirty tiles! %d dirty tiles = lose 1 life" % MAX_DIRTY_TILES)

func _on_game_start() -> void:
	dirty_timer.start()
	# Give P2 starter water so they can mop immediately before P1’s
	# first full container arrives (which takes ~2-4 catches at 1.2s each).
	available_water = 5
	_update_water_display()
	_log("💧 Starting with %d laundry water" % available_water)
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
	title.text = Localization.get_text("mp_res_laundry_water")
	vbox.add_child(title)
	
	var label = Label.new()
	label.name = "WaterLabel"
	label.text = "💧 x 0"
	label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(label)
	water_indicator_label = label

## Lays the floor out FROM THE PLAYFIELD, not from authored pixels.
##
## The grid used to be pinned at (300 + col * 140, 200 + row * 120) with 120x100 tiles, which
## put the whole 5x4 floor inside x 300..860, y 200..560 - a 560x360 box in the top-left of a
## 1920x1080 playfield, with the rest of the "floor" empty background. Two defects in one:
## a tile was 100 units on its short side (33dp, under the 48dp Android/WCAG floor measured
## by tools/VerifyTouchTargets.tscn) and it could not grow, because the 140x120 pitch left no
## room. Deriving the pitch from the visible rect fixes both - the floor fills the floor, and
## every tile clears the touch floor with room to spare.
func _create_floor() -> void:
	var field := playfield_rect()
	if field.size.x <= 1.0:
		# No viewport yet (headless first frame). The authored 1920x1080 design box, camera-
		# centred the same way playfield_rect() would return it.
		field = Rect2(Vector2(576.0, 324.0) - Vector2(960.0, 540.0), Vector2(1920.0, 1080.0))
	# The HUD band (water counter, timer, score) owns the top of the screen, and the mop
	# feedback labels sit just under it, so the floor starts below both.
	var top: float = field.size.y * HUD_BAND_FRAC
	var area := Rect2(
		field.position + Vector2(field.size.x * SIDE_MARGIN_FRAC, top),
		Vector2(field.size.x * (1.0 - SIDE_MARGIN_FRAC * 2.0),
			field.size.y - top - field.size.y * BOTTOM_MARGIN_FRAC))
	var step := Vector2(area.size.x / float(TILE_COLS), area.size.y / float(TILE_ROWS))
	var tile_size := Vector2(maxf(step.x - TILE_GAP, 8.0), maxf(step.y - TILE_GAP, 8.0))
	for row in range(TILE_ROWS):
		for col in range(TILE_COLS):
			var tile = Area2D.new()
			tile.position = area.position + Vector2(step.x * (col + 0.5), step.y * (row + 0.5))
			tile.set_meta("dirty", false)
			add_child(tile)

			var collision = CollisionShape2D.new()
			var shape = RectangleShape2D.new()
			shape.size = tile_size
			collision.shape = shape
			tile.add_child(collision)

			var visual = ColorRect.new()
			visual.name = "Visual"
			visual.size = tile_size
			visual.position = -tile_size * 0.5
			visual.color = Color(0.9, 0.9, 0.9)
			visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(visual)

			tile.input_event.connect(_on_tile_clicked.bind(tile))
			floor_tiles.append(tile)

func _make_tile_dirty() -> void:
	var clean_tiles = floor_tiles.filter(func(t): return not t.get_meta("dirty", false))
	if clean_tiles.is_empty():
		return
	
	var tile = clean_tiles[randi() % clean_tiles.size()]
	tile.set_meta("dirty", true)
	tile.get_node("Visual").color = Color(0.5, 0.4, 0.3)
	
	var dirty_count = floor_tiles.filter(func(t): return t.get_meta("dirty", false)).size()
	if dirty_count >= MAX_DIRTY_TILES:
		# A LIFE ONLY GOES WHERE WATER COULD HAVE GONE
		#
		# Mopping spends a unit of laundry water only P1 can send. While this player holds none,
		# a filthy floor is P1's pace rather than a mistake, and one of three shared lives is far
		# too much to charge for it. The floor still gets dirtier — that is honest — and the same
		# threshold applies again the moment there is water to mop with.
		if available_water > 0:
			_log("💩 %d of %d tiles filthy - lose 1 life!" % [dirty_count, floor_tiles.size()])
			report_miss_to_host()
			_clean_all_tiles()
		else:
			_log("💩 %d of %d tiles filthy, but there is no water to mop with — not charged"
				% [dirty_count, floor_tiles.size()])

func _clean_all_tiles() -> void:
	for tile in floor_tiles:
		tile.set_meta("dirty", false)
		tile.get_node("Visual").color = Color(0.9, 0.9, 0.9)

func _on_tile_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, tile: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_mop(tile)

func _try_mop(tile: Area2D) -> void:
	if not game_active:
		return
	
	if not tile.get_meta("dirty", false):
		return
	
	if available_water <= 0:
		_log("⚠️ No water! Wait for partner")
		return
	
	available_water -= 1
	_update_water_display()
	
	tile.set_meta("dirty", false)
	tile.get_node("Visual").color = Color(0.9, 0.9, 0.9)
	
	tiles_mopped += 1
	add_score(10)
	_log("✨ Mopped tile! Total: %d" % tiles_mopped)

func _on_resource_received(_from_player: int, resource_type: String, amount: int, _quality: float) -> void:
	if resource_type == "laundry_water":
		available_water += amount
		_update_water_display()
		_log("📥 Received %d laundry water (Total: %d)" % [amount, available_water])

func _update_water_display() -> void:
	if water_indicator_label:
		water_indicator_label.text = "💧 x %d" % available_water

func _on_game_over() -> void:
	dirty_timer.stop()
	super._on_game_over()
