extends "res://scripts/multiplayer/MultiplayerMiniGameBase.gd"

## Bundle 5: Wash Car with Dish Water
## P2 washes car sections using P1's dish water

## HOW LONG ONE FILTHY PANEL MAY SIT WHILE THE PLAYER HOLDS WATER
##
## Was 40.0 in a 30-second round, so the rule could not fire: the whistle always came first and
## the round ended in an unconditional win no matter how the car looked. 12.0 makes it reachable
## with 18 seconds left to recover, and _process() only advances the clock while
## available_water > 0, so it charges wasted opportunity rather than P1's delivery pace.
##
## It cannot fire on a player who is playing. Exactly one panel is dirty at a time
## (_make_section_dirty), a wash clears it and _redirty_after(2.0) posts the next one, so any
## tap inside 12 seconds of a panel appearing resets the clock — and the 3 starter units mean
## the first panel is always answerable.
const MAX_DIRTY_TIME: float = 12.0
## How long the car waits before another section gets dirty — after a wash, and after a
## section has been left dirty too long. Both paths go through _redirty_after().
const RE_DIRTY_SECONDS: float = 2.0

## Car body proportions, as fractions of the playfield, plus the floor every panel must clear.
## PANEL_SPREAD_FRAC * 1080 = 194, so hood/roof/trunk sit 194 apart and a 160-tall panel leaves
## a 34-unit gap; DOOR_SPREAD_FRAC * 1920 = 336 leaves 36 units between a door and the roof.
## MIN_PANEL is the 48dp floor on the densest profile (WVGA 4.5in -> 147 canvas units), rounded
## up, so the panels stay tappable even if the playfield comes back small.
const PANEL_SPREAD_FRAC: float = 0.18
const DOOR_SPREAD_FRAC: float = 0.175
const PANEL_W_FRAC: float = 0.156
const PANEL_H_FRAC: float = 0.148
const PANEL_GAP: float = 30.0
const MIN_PANEL: Vector2 = Vector2(150.0, 150.0)
const PANEL_TEX: Vector2 = Vector2(140.0, 80.0)   # art resolution; scaled to the real panel

var available_water: int = 0
var sections_washed: int = 0
var car_sections: Array = []
var dirty_timer: float = 0.0
var water_indicator_label: Label

func get_instructions() -> String:
	return Localization.get_text("mp_wash_car_instructions") % [int(MAX_DIRTY_TIME)]

func get_controls_text() -> String:
	return Localization.get_text("mp_wash_car_controls")

func _on_multiplayer_ready() -> void:
	game_name = "Wash Car"
	title_key = "mp_title_wash_car"
	
	_create_water_indicator()
	_create_car()
	
	_log("🚗 Wash car sections! Dirty for %d sec = lose 1 life" % int(MAX_DIRTY_TIME))

func _on_game_start() -> void:
	_make_section_dirty()
	# Give P2 starter water so they can wash immediately
	available_water = 3
	_update_water_display()
	_log("💧 Starting with %d dish water" % available_water)
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
	title.text = Localization.get_text("mp_res_dish_water")
	vbox.add_child(title)
	
	var label = Label.new()
	label.name = "WaterLabel"
	label.text = "💧 x 0"
	label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(label)
	water_indicator_label = label

## Assembles the car FROM THE PLAYFIELD CENTRE, not from authored pixels.
##
## The five sections used to sit at fixed points in a 1152x648 design box - hood (576, 250),
## roof (576, 350), trunk (576, 450), doors at x 400 and 752 - with 140x80 hit shapes. On the
## shipping 1920x1080 canvas that parks the whole car left of centre and above it, and 80 units
## on the short side is 26dp: barely half the 48dp Android/WCAG floor that
## tools/VerifyTouchTargets.tscn measures. It could not simply be grown either, because hood,
## roof and trunk were only 100 units apart, so a 150-tall section would have overlapped its
## neighbours and stolen their taps. Both are fixed by spacing the body off the playfield
## centre: the car scales with the screen and every panel clears the floor.
func _create_car() -> void:
	var field := playfield_rect()
	if field.size.x <= 1.0:
		# No viewport yet. The authored design box, camera-centred as playfield_rect() returns it.
		field = Rect2(Vector2(576.0, 324.0) - Vector2(960.0, 540.0), Vector2(1920.0, 1080.0))
	var centre := field.get_center()
	var dx: float = field.size.x * DOOR_SPREAD_FRAC
	var dy: float = field.size.y * PANEL_SPREAD_FRAC
	var panel := Vector2(
		maxf(field.size.x * PANEL_W_FRAC, MIN_PANEL.x),
		minf(maxf(field.size.y * PANEL_H_FRAC, MIN_PANEL.y), dy - PANEL_GAP))
	# "name" stays English on purpose: it is the identifier the session log records for
	# each washed panel, which the thesis reads. "key" is what the on-screen chip renders,
	# so the Filipino build labels the panels in Filipino without changing the log format.
	var sections_data = [
		{"name": "Hood", "key": "mp_car_hood", "pos": centre + Vector2(0.0, -dy)},
		{"name": "Roof", "key": "mp_car_roof", "pos": centre},
		{"name": "Door L", "key": "mp_car_door_l", "pos": centre + Vector2(-dx, 0.0)},
		{"name": "Door R", "key": "mp_car_door_r", "pos": centre + Vector2(dx, 0.0)},
		{"name": "Trunk", "key": "mp_car_trunk", "pos": centre + Vector2(0.0, dy)}
	]

	for data in sections_data:
		var section = Area2D.new()
		section.position = data["pos"]
		section.set_meta("dirty", false)
		section.set_meta("name", data["name"])
		add_child(section)

		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = panel
		collision.shape = shape
		section.add_child(collision)

		var visual = Sprite2D.new()
		visual.name = "Visual"
		# create_car_texture() is a per-pixel GDScript fill, so the panel art is generated
		# once at a small fixed size and scaled to the real panel - a 300x160 panel would
		# otherwise cost 48k set_pixel calls each, five times, at round start.
		visual.texture = MiniGameAssets.create_car_texture(
			int(PANEL_TEX.x), int(PANEL_TEX.y), Color(0.8, 0.2, 0.2))
		visual.scale = panel / PANEL_TEX
		section.add_child(visual)

		var label = Label.new()
		label.name = "Label"
		label.text = Localization.get_text(str(data["key"]))
		label.position = Vector2(-panel.x * 0.5 + 12.0, -panel.y * 0.5 + 8.0)
		label.add_theme_font_size_override("font_size", 20)
		MiniGameAssets.outline_text(label)
		section.add_child(label)

		section.input_event.connect(_on_section_clicked.bind(section))
		car_sections.append(section)

func _make_section_dirty() -> void:
	var clean_sections = car_sections.filter(func(s): return not s.get_meta("dirty", false))
	if clean_sections.is_empty():
		return
	
	var section = clean_sections[randi() % clean_sections.size()]
	section.set_meta("dirty", true)
	section.set_meta("dirty_elapsed", 0.0)
	section.get_node("Visual").modulate = Color(0.5, 0.4, 0.3)  # Muddy

func _process(delta: float) -> void:
	if not game_active:
		return
	
	# HOW LONG A PANEL HAS BEEN FILTHY *WITH SOAP IN REACH*
	#
	# This read Time.get_ticks_msec() against a stamp taken when the panel got dirty, so the
	# neglect clock ran on wall time — including every second this player spent with an empty
	# bucket waiting on P1's dish water. _try_wash() refuses without water, so those seconds are
	# P1's pace, not a mistake, and they were being charged to one of three shared lives. An
	# accumulator that only advances while there is water to wash with cannot do that, and it
	# also means the allowance below finally measures what it claims to: time the player had and
	# wasted, rather than time that merely passed.
	for section in car_sections:
		if section.get_meta("dirty", false):
			if available_water > 0:
				section.set_meta("dirty_elapsed",
					float(section.get_meta("dirty_elapsed", 0.0)) + delta)
			var elapsed: float = float(section.get_meta("dirty_elapsed", 0.0))
			
			if elapsed > MAX_DIRTY_TIME:
				_log("💩 Section filthy for %.0fs with water in hand - lose 1 life!" % elapsed)
				section.set_meta("dirty", false)
				section.set_meta("dirty_elapsed", 0.0)
				section.get_node("Visual").modulate = Color(0.8, 0.2, 0.2)
				report_miss_to_host(section)
				# Put a section back in play. _make_section_dirty() had exactly two callers —
				# _on_game_start() once, and the tail of a SUCCESSFUL wash — so a player who ran
				# out of partner water and ate this penalty was left with a spotless car for the
				# rest of the round: nothing dirty to tap, no way to score, and the quota out of
				# reach (measured 0 of 5 sections dirty and local_score 0 → 0 afterwards).
				_redirty_after(RE_DIRTY_SECONDS)

func _on_section_clicked(_viewport: Node, event: InputEvent, _shape_idx: int, section: Area2D) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_wash(section)

func _try_wash(section: Area2D) -> void:
	if not game_active:
		return
	
	if not section.get_meta("dirty", false):
		return
	
	if available_water <= 0:
		_log("⚠️ No water! Wait for partner")
		return
	
	available_water -= 1
	_update_water_display()
	
	section.set_meta("dirty", false)
	section.get_node("Visual").modulate = Color(1.0, 1.0, 1.0)  # Clean
	
	sections_washed += 1
	add_score(15, true, section)
	_log("✨ Washed %s! Total: %d" % [section.get_meta("name"), sections_washed])
	
	# Line up the next section to scrub.
	_redirty_after(RE_DIRTY_SECONDS)

## Dirties one more section a beat later, so there is always something to scrub.
## Re-checks the round before it acts: this used to be a bare `await create_timer(2.0)`
## followed by _make_section_dirty(), so a wash landing near the final whistle dirtied a
## board whose round had already ended (measured 1 section dirtied after game over).
func _redirty_after(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if not is_inside_tree() or not game_active:
		return
	_make_section_dirty()

func _on_resource_received(_from_player: int, resource_type: String, amount: int, _quality: float) -> void:
	if resource_type == "dishwater":
		available_water += amount
		_update_water_display()
		_log("📥 Received %d dish water (Total: %d)" % [amount, available_water])

func _update_water_display() -> void:
	if water_indicator_label:
		water_indicator_label.text = "💧 x %d" % available_water

func _on_game_over() -> void:
	super._on_game_over()
