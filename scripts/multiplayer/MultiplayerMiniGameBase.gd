class_name MultiplayerMiniGameBase
extends Node2D

## 
## MULTIPLAYER MINIGAME BASE CLASS
## 
## Base template for all multiplayer cooperative mini-games
## Handles G-Counter scoring, shared lives, pause sync, and resource transfer
## 

signal game_started()
signal game_completed(success: bool)
signal countdown_tick(count: int)

# 
# GAME CONFIGURATION
# 

## game_name is the round's IDENTIFIER, not its caption: _log() keys the thesis session log
## by it (SessionLogger.log_entry below), and FIX 68 is the record of what it costs to use a
## localized string as an identity — a second high-score row per language. title_key names
## the DISPLAY title instead, and display_title() falls back to the identifier so a game
## that has not been given a key still shows a caption rather than an empty bar.
@export var title_key: String = ""
@export var game_name: String = "CoopMiniGame"
@export var game_duration: float = 30.0
@export var requires_countdown: bool = true  # Show 3-2-1-GO before starting
@export var connection_type: String = "resource_transfer"
# Options: resource_transfer, task_marking, combined_efficiency.
@export var win_quota: int = 0 # If > 0, reaching this score triggers win

const FONT_TITLE: Font = preload("res://fonts/Cubao_Free_Wide.otf")
const FONT_BODY: Font = preload("res://fonts/NTBrickSans.otf")

# 
# STATE VARIABLES
# 

var game_active: bool = false
var game_started_time: int = 0
## Milliseconds this round has spent frozen, and when the current freeze began (0
## when running). Subtracted by elapsed_play_seconds(); see there for why.
var _paused_ms_total: int = 0
var _pause_began_ms: int = 0
## Whether get_tree().paused was already true when a reconnect hold began. A player can
## pause and THEN have their partner drop, and in that case the end of the hold must give
## them their pause menu back, not silently resume a game they had stopped.
var _pause_before_hold: bool = false
var ui_timer: Timer
## Drives _update_timer_bar(). Separate from ui_timer because the two run at
## different rates: the label at 1 Hz (whole seconds, no decimal flicker), the bar
## at 20 Hz so it slides.
var _bar_timer: Timer = null
var my_player_num: int = 1
var my_role: String = ""
var partner_role: String = ""
var local_score: int = 0
var is_waiting_for_partner: bool = false

# Cached reference to the progress bar for smooth 60fps update.
var _timer_progress_bar: ProgressBar = null

# Performance tracking for CoopAdaptation
var mistakes_made: int = 0
var correct_actions: int = 0
var total_actions: int = 0

# Mistake time penalty — seconds removed from remaining time per wrong action.
# Scaled by difficulty so Easy is forgiving and Hard is punishing.
# 0 = disabled (safe default before _ready() sets the real value).
var mistake_time_penalty: float = 0.0
var _time_penalty_total: float = 0.0

# UI References
var hud_layer: CanvasLayer
var background_layer: CanvasLayer = null

## Screen-space offset for a game's own side panel (the water counters the five
## household games build). Authored once here so the five copies agree.

const HUD_PANEL_OFFSET: Vector2 = Vector2(20.0, 100.0)
var countdown_label: Label
var waiting_overlay: Control
var pause_menu: Control
var instruction_overlay: Control
var timer_label: Label
var _instruction_dismissed: bool = false  # Guard against re-entry in _on_instruction_dismissed

# 
# INITIALIZATION
# 

func _ready() -> void:
	await get_tree().process_frame
	
	if not NetworkManager or not NetworkManager.is_multiplayer_connected():
		push_error(" MultiplayerMiniGameBase: Not connected to multiplayer")
		# Return to lobby instead of leaving a blank screen
		if GameManager:
			GameManager.return_to_multiplayer_lobby()
		return
	
	# Get player info
	my_player_num = NetworkManager.get_local_player_num()
	my_role = NetworkManager.get_player_role(my_player_num)
	
	# Load CoopAdaptation difficulty and sync to GameManager.difficulty_multiplier
	# so child games that read difficulty_multiplier get the correct adaptive value
	var coop = get_node_or_null("/root/CoopAdaptation")
	if coop and coop.has_method("get_difficulty_params") and GameManager:
		var params: Dictionary = coop.get_difficulty_params(my_player_num)
		GameManager.difficulty_multiplier = params.get("speed_multiplier", 1.0)
		_log("🎯 CoopAdaptation difficulty loaded: %s (mult=%.2f)" % [
			coop.get_player_difficulty(my_player_num),
			GameManager.difficulty_multiplier
		])
		mistake_time_penalty = _penalty_for_difficulty(coop.get_player_difficulty(my_player_num))
	else:
		mistake_time_penalty = _penalty_for_difficulty("Medium")
	_log("⏱️ Mistake penalty: %.0fs per wrong action (difficulty-scaled)" % mistake_time_penalty)
	
	_log(" Multiplayer game starting - Player %d (%s)" % [my_player_num, my_role])
	
	# Initialize game-specific setup FIRST (sets game_name and game_duration)
	_on_multiplayer_ready()
	
	# Register with AutoPlayManager so the MP bot can drive this game
	if AutoPlayManager and AutoPlayManager.is_mp_auto_play_enabled():
		AutoPlayManager.register_multiplayer_game(self, my_role)
	
	# Create background
	_create_background()
	
	# Setup UI AFTER game settings are configured
	_setup_multiplayer_ui()
	
	# Connect NetworkManager signals
	if NetworkManager:
		NetworkManager.team_score_updated.connect(_on_team_score_updated)
		NetworkManager.team_lives_updated.connect(_on_team_lives_updated)
		NetworkManager.round_starting.connect(_on_countdown_tick)
		NetworkManager.resource_sent.connect(_on_resource_received)
		NetworkManager.task_marked.connect(_on_task_marked)
		NetworkManager.player_disconnected.connect(_on_player_left_session)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)
		# Connected BEFORE the two above matter: NetworkManager decides whether a drop
		# is fatal or recoverable, and while it is still deciding these two handlers
		# must not tear the round down. See _on_reconnect_hold_started().
		NetworkManager.reconnect_hold_started.connect(_on_reconnect_hold_started)
		NetworkManager.reconnect_hold_ended.connect(_on_reconnect_hold_ended)
	
	# Show instructions (override get_instructions() in child class)
	var instructions_text = get_instructions()
	if instructions_text != "":
		show_instructions(instructions_text)
	else:
		# No instructions, start immediately
		if requires_countdown:
			if NetworkManager.is_server():
				NetworkManager.start_countdown()
			_show_countdown_overlay()
		else:
			start_game()

## The rectangle of WORLD space the player can actually see, camera included.
##
## Every multiplayer scene is a Node2D root with a Camera2D parked at (576, 324) —
## the centre of the 1152x648 viewport these scenes were authored against — while the
## project ships 1920x1080 with stretch/aspect="expand". The camera therefore centres
## the authored art and the visible world rect becomes x[-384, 1536], y[-216, 864] on
## desktop, and taller still on a phone. get_viewport_rect() reports (0, 0, 1920, 1080):
## the right SIZE, at the wrong ORIGIN. Treating that Rect2 as world coordinates - which
## six games did - shifts every edge-relative decision by (-384, -216):
##   MP_CatchTheRain      spawned rain across world x[50, 1870], so ~18% of drops fell
##                        outside the right edge uncatchable (and cost a shared life),
##                        while the leftmost 434px of playfield never saw a drop;
##   MP_CollectDishWater  clamped a dragged bucket to x<=1870, 334px off-screen right;
##   MP_FilterWater       spawned clickable dirt down to y=980 (headless: 1820) when the
##                        visible bottom is 864 (1284) - unclickable dirt the round
##                        cannot be cleared without.
## Returning an empty Rect2 rather than a guess when the viewport has no size yet is
## deliberate: callers must skip a layout pass, not lay out against (0, 0).
func playfield_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var size := viewport.get_visible_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		return Rect2()
	var cam := viewport.get_camera_2d()
	if cam == null:
		return Rect2(Vector2.ZERO, size)
	return Rect2(cam.global_position - size * 0.5, size)

## Where a screen-space (window) event position lands in world space.
##
## The canvas transform carries both the camera offset and the content scale that
## stretch/mode="canvas_items" applies, so this is the only correct conversion for an
## InputEvent position. Steering code must use it instead of get_global_mouse_position():
## on a touch build the emulated mouse reads (0, 0) until the first tap, and following
## that poll blindly parks a bucket against a clamp for the opening seconds of the round.
func world_from_screen(screen_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return screen_pos
	return viewport.get_canvas_transform().affine_inverse() * screen_pos

## Horizontal clamp for anything the player drags: keeps a body of half-width `half_w` fully
## inside the visible rect. The four catch-and-drag games all clamped to world x[50, 1870]
## instead - "50 to viewport width minus 50", viewport size mistaken for world extent - which let
## a bucket be dragged 334px past the right edge on desktop and made the leftmost 434px of the
## playfield unreachable. Returns the input unchanged while the viewport has no size yet.
func clamp_x_into_playfield(x: float, half_w: float) -> float:
	var view := playfield_rect()
	if view.size.x <= 1.0:
		return x
	return clampf(x, view.position.x + half_w, view.end.x - half_w)

## A spawn position for a falling object: random across the visible width, `above` pixels above
## the visible top so it enters frame instead of blinking into existence mid-screen. The three
## collect games used hardcoded authoring bands (150..1002, 200..952, 100..1000) that no longer
## match the visible width once the camera centres a 1152x648 scene in a 1920-wide viewport.
func spawn_above_playfield(margin_x: float, above: float = 50.0) -> Vector2:
	var view := playfield_rect()
	if view.size.x <= 1.0:
		return Vector2(0.0, -above)
	return Vector2(
		randf_range(view.position.x + margin_x, view.end.x - margin_x),
		view.position.y - above)

## The y at which a falling object has provably left the player's view, so a "missed" is reported
## when the player sees the drop go, not hundreds of pixels later. Three games hardcoded y > 700
## against a visible bottom of 864 on desktop and 1284 headless; on a portrait phone the same
## line sits near the middle of the screen, where drops appeared to vanish in mid-air.
func playfield_exit_y(beyond: float = 50.0) -> float:
	var view := playfield_rect()
	if view.size.y <= 1.0:
		return INF
	return view.end.y + beyond

## Spreads draggable catchers evenly across the visible width and seats them a fixed distance
## above the visible bottom, returning true once they have been placed.
##
## The first pass assigns x; later passes (a resize, an orientation flip) re-seat only y and clamp
## x, because teleporting a catcher the player has just lined up under a falling drop back to its
## slot would cost them the catch - the same rule tools/VerifyMPBucketLayout.gd pins for the
## single-bucket games. Authored positions like Vector2(288 + i * 288, 450) put every catcher in
## the upper-left of a 1920x1080 viewport with a lot of empty screen below them.
func seat_catchers(catchers: Array, half_w: float, margin_bottom: float, already_placed: bool) -> bool:
	var view := playfield_rect()
	if view.size.x <= 1.0 or catchers.is_empty():
		return already_placed
	var min_x: float = view.position.x + half_w
	var max_x: float = view.end.x - half_w
	var y: float = view.end.y - margin_bottom
	var step: float = (max_x - min_x) / float(catchers.size() + 1)
	for i in catchers.size():
		var catcher := catchers[i] as Node2D
		if catcher == null or not is_instance_valid(catcher):
			continue
		if already_placed:
			catcher.position = Vector2(clampf(catcher.position.x, min_x, max_x), y)
		else:
			catcher.position = Vector2(min_x + step * float(i + 1), y)
	return true

## Builds the shared gradient background every multiplayer round renders on.
##
## The gradient lives in its OWN CanvasLayer, not as a direct child of this Node2D.
## A Control takes its anchor rectangle from its parent CanvasItem's
## get_anchorable_rect(), and Node2D inherits the CanvasItem default of
## Rect2(0, 0, 0, 0) - so the previous `add_child(bg)` plus PRESET_FULL_RECT
## resolved to a 0x0 TextureRect and all 12 multiplayer scenes (which contain
## nothing but a root and a Camera2D) drew on the engine's default grey clear
## colour instead of the intended blue gradient. Measured as
## `background rect: pos=(0.0, 0.0) size=(0.0, 0.0)` by
## tools/VerifyMPPlayfieldBounds.tscn before this fix.
##
## Under a CanvasLayer the anchor parent is the viewport itself, so the rect fills
## the window, follows every resize without a size_changed hook, and - unlike a
## camera-relative rect - cannot be left behind if a scene ever moves its camera.
func _create_background() -> void:
	background_layer = CanvasLayer.new()
	background_layer.name = "BackgroundLayer"
	background_layer.layer = -100
	add_child(background_layer)
	
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	
	# Gradient background
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.1, 0.3, 0.5))  # Dark blue
	gradient.set_color(1, Color(0.3, 0.5, 0.7))  # Light blue
	
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(0, 1)
	
	bg.texture = gradient_texture
	background_layer.add_child(bg)

## The CanvasLayer every HUD element lives in, created on first use.
##
## Ordering forces this: the base calls _on_multiplayer_ready() — where five games build
## their own water-counter panel — BEFORE _setup_multiplayer_ui(), so whichever runs first
## has to be the one that creates the layer. Creating it twice would strand the top bar and
## the counters on separate layers and lose the earlier layer's children.
func _ensure_hud_layer() -> void:
	if hud_layer == null:
		hud_layer = CanvasLayer.new()
		hud_layer.layer = 100  # Above game elements
		add_child(hud_layer)

## Attach a game's own HUD panel in SCREEN space.
##
## Every multiplayer scene is a Node2D world with a Camera2D at (576, 324), so a Control
## add_child()ed to the root is drawn in WORLD space: a panel authored at (20, 100) lands at
## screen (404, 316) on a 1920x1080 window, (404, 736) on the 1920x1920 the headless driver
## reports, and further right still on a 21:9 phone — the water counter drifted with the
## aspect ratio instead of sitting under the top bar. hud_layer is a CanvasLayer, so its
## children are laid out against the viewport and the offset means what it says.
func attach_hud_panel(panel: Control, offset: Vector2 = HUD_PANEL_OFFSET) -> void:
	_ensure_hud_layer()
	panel.position = offset
	hud_layer.add_child(panel)
	# Deferred, not immediate: every caller attaches the panel first and fills it after, so
	# the labels this pass reaches do not exist yet on this line, and the top bar it clears
	# may not be built yet either - the two are created in whichever order the subclass
	# happens to use. By the end of the frame both are up.
	_finish_hud_panel.call_deferred(panel, offset)


## Outlines the captions in an attached panel, and keeps the panel clear of the top bar.
func _finish_hud_panel(panel: Control, offset: Vector2) -> void:
	if not is_instance_valid(panel):
		return
	for c in _panel_controls(panel):
		# The five resource captions measured 3.23:1 white-on-panel with no rim of their own.
		if (c is Label or c is Button) and int(c.get_theme_constant("outline_size")) == 0:
			MiniGameAssets.outline_text(c)
	if offset != HUD_PANEL_OFFSET:
		return
	# The default offset put the panel's first caption underneath the top bar, whose stylebox is
	# 60% black - so "Tubig-ulan:" was white text seen through a dark scrim and rasterised at 0.40
	# grey, 3.53:1 against the panel behind it. The bar is added to the same CanvasLayer and,
	# depending on the subclass, after this panel, so it wins the draw. Push the panel clear of it.
	var bar: Node = hud_layer.get_node_or_null("TopBar")
	if not (bar is Control):
		return
	var bar_ctrl: Control = bar
	# size.y needs a completed layout sort, which is not guaranteed this early; the 120 floor is
	# the bar's own content height (a 28px title over 10/15 margins) so the clearance is right
	# even on the frame where the container has not sized itself yet. +10 is the stylebox
	# expand_margin_bottom, which draws below size.y, and +4 is a breathing gap.
	var bottom: float = bar_ctrl.position.y + maxf(bar_ctrl.size.y, 120.0) + 14.0
	if panel.position.y < bottom:
		panel.position.y = bottom


func _panel_controls(root: Node) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is Control:
			out.append(child)
		out.append_array(_panel_controls(child))
	return out

func _setup_multiplayer_ui() -> void:
	# Setup HUD for multiplayer game. _ensure_hud_layer() rather than a fresh CanvasLayer:
	# _on_multiplayer_ready() runs BEFORE this function and five games attach their own
	# counter panel from there, so the layer may already exist.
	_ensure_hud_layer()
	
	# Load fonts.
	var font_title = FONT_TITLE
	var font_body = FONT_BODY
	
	# Top Bar Background
	var top_bar = PanelContainer.new()
	# Named so attach_hud_panel() can measure it and keep the games' own counters clear of it.
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.expand_margin_bottom = 10
	top_bar.add_theme_stylebox_override("panel", style)
	
	hud_layer.add_child(top_bar)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 40)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)
	
	# --- LEFT SECTION: STATUS ---
	var left_box = HBoxContainer.new()
	left_box.add_theme_constant_override("separation", 20)
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.size_flags_stretch_ratio = 1.0
	hbox.add_child(left_box)
	
	# Lives
	var lives_container = HBoxContainer.new()
	var lives_label = Label.new()
	lives_label.name = "LivesLabel"
	lives_label.text = " x%d" % NetworkManager.team_lives
	if font_title: lives_label.add_theme_font_override("font", font_title)
	lives_label.add_theme_font_size_override("font_size", 32)
	lives_label.add_theme_color_override("font_outline_color", Color.BLACK)
	lives_label.add_theme_constant_override("outline_size", 4)
	lives_label.pivot_offset = Vector2(50, 20)
	# Same reserve as ScoreLabel below, for the same reason: " x9" -> " x10" must not
	# change this Label's minimum size, or the recoil started one line later loses a
	# frame to the container re-sort it would trigger.
	lives_label.custom_minimum_size = Vector2(90, 0)
	lives_container.add_child(lives_label)
	left_box.add_child(lives_container)
	
	# Score
	var score_container = HBoxContainer.new()
	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	# The round's team score, matching what _on_team_score_updated writes here later and what
	# the quota is measured against (NetworkManager.round_score_baseline).
	score_label.text = " %d" % (NetworkManager.get_round_score()
		if NetworkManager.has_method("get_round_score") else NetworkManager.get_total_score())
	if font_title: score_label.add_theme_font_override("font", font_title)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	score_label.add_theme_constant_override("outline_size", 4)
	score_label.pivot_offset = Vector2(50, 20)
	# Reserve the width the biggest realistic score needs (5 digits at font size 32), so
	# writing a new score never changes this Label's minimum size. A minimum-size change
	# re-sorts the HBoxContainer chain above it, and Container.fit_child_in_rect resets
	# every child's `rotation` and `scale` on the way — which clipped a frame out of the
	# score pop here and, because the sort walks the whole left section, out of the
	# neighbouring LivesLabel recoil as well. The reserve also stops the label sliding
	# sideways each time the score gains a digit.
	score_label.custom_minimum_size = Vector2(150, 0)
	score_container.add_child(score_label)
	left_box.add_child(score_container)
	
	# --- CENTER SECTION: GAME INFO ---
	var center_box = VBoxContainer.new()
	center_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_box.size_flags_stretch_ratio = 1.0
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(center_box)
	
	# Game Name
	var game_label = Label.new()
	game_label.name = "GameLabel"
	game_label.text = display_title()
	if font_body: game_label.add_theme_font_override("font", font_body)
	game_label.add_theme_font_size_override("font_size", 18)
	game_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
	game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(game_label)
	
	# Timer (Progress Bar Style)
	var timer_container = VBoxContainer.new()
	timer_container.custom_minimum_size = Vector2(300, 0)
	center_box.add_child(timer_container)
	
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	if game_duration >= 999999.0:
		timer_label.text = Localization.get_text("mp_hud_endless")
	else:
		timer_label.text = "%.0f" % game_duration
	if font_title: timer_label.add_theme_font_override("font", font_title)
	timer_label.add_theme_font_size_override("font_size", 36)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	timer_label.add_theme_constant_override("outline_size", 4)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_container.add_child(timer_label)
	
	# Timer Progress Bar
	var timer_progress = ProgressBar.new()
	timer_progress.name = "TimerProgress"
	timer_progress.custom_minimum_size = Vector2(300, 20)
	timer_progress.max_value = game_duration
	timer_progress.value = game_duration
	timer_progress.show_percentage = false
	
	var progress_style = StyleBoxFlat.new()
	progress_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	progress_style.corner_radius_top_left = 10
	progress_style.corner_radius_top_right = 10
	progress_style.corner_radius_bottom_left = 10
	progress_style.corner_radius_bottom_right = 10
	timer_progress.add_theme_stylebox_override("background", progress_style)
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.8, 1.0)
	fill_style.corner_radius_top_left = 10
	fill_style.corner_radius_top_right = 10
	fill_style.corner_radius_bottom_left = 10
	fill_style.corner_radius_bottom_right = 10
	timer_progress.add_theme_stylebox_override("fill", fill_style)
	
	timer_container.add_child(timer_progress)
	_timer_progress_bar = timer_progress  # Cache for smooth _process() updates
	var right_box = HBoxContainer.new()
	right_box.add_theme_constant_override("separation", 20)
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.size_flags_stretch_ratio = 1.0
	right_box.alignment = BoxContainer.ALIGNMENT_END
	hbox.add_child(right_box)
	
	# Roles Container
	var roles_vbox = VBoxContainer.new()
	roles_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_box.add_child(roles_vbox)
	
	# Your Role
	var role_label = Label.new()
	role_label.name = "RoleLabel"
	role_label.text = Localization.get_text("mp_hud_you") % _role_display(my_role)
	if font_body: role_label.add_theme_font_override("font", font_body)
	role_label.add_theme_font_size_override("font_size", 20)
	role_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	role_label.add_theme_color_override("font_outline_color", Color.BLACK)
	role_label.add_theme_constant_override("outline_size", 2)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	roles_vbox.add_child(role_label)
	
	# Partner Role
	var partner_num = 2 if my_player_num == 1 else 1
	var partner_role_name = NetworkManager.get_player_role(partner_num)
	var partner_label = Label.new()
	partner_label.name = "PartnerLabel"
	partner_label.text = Localization.get_text("mp_hud_partner") % _role_display(partner_role_name)
	if font_body: partner_label.add_theme_font_override("font", font_body)
	partner_label.add_theme_font_size_override("font_size", 16)
	partner_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	partner_label.add_theme_color_override("font_outline_color", Color.BLACK)
	partner_label.add_theme_constant_override("outline_size", 2)
	partner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	roles_vbox.add_child(partner_label)
	
	# Pause button
	var pause_btn = Button.new()
	pause_btn.text = ""
	pause_btn.custom_minimum_size = Vector2(50, 50)
	pause_btn.add_theme_font_size_override("font_size", 24)
	pause_btn.pressed.connect(_on_pause_pressed)
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.focus_mode = Control.FOCUS_NONE
	right_box.add_child(pause_btn)
	
	# Create overlays
	_create_pause_menu()
	_create_waiting_overlay()
	_create_countdown_overlay()
	_create_instruction_overlay()
	_create_controls_panel()

func _create_pause_menu() -> void:
	# Create pause menu overlay
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(pause_menu)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	pause_menu.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var label = Label.new()
	label.text = Localization.get_text("mp_paused")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 64)
	vbox.add_child(label)
	
	var resume_btn = Button.new()
	resume_btn.text = Localization.get_text("mp_resume")
	resume_btn.custom_minimum_size = Vector2(200, 60)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = Localization.get_text("mp_quit_session")
	quit_btn.custom_minimum_size = Vector2(200, 60)
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

func _create_waiting_overlay() -> void:
	# Create 'Waiting for partner' overlay
	waiting_overlay = Control.new()
	waiting_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	waiting_overlay.visible = false
	hud_layer.add_child(waiting_overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	waiting_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	waiting_overlay.add_child(center)
	
	var label = Label.new()
	label.text = Localization.get_text("mp_waiting_partner")
	label.add_theme_font_size_override("font_size", 48)
	center.add_child(label)

func _create_countdown_overlay() -> void:
	# Create countdown overlay (3-2-1-GO!)
	var countdown_overlay = Control.new()
	countdown_overlay.name = "CountdownOverlay"
	countdown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_overlay.visible = false
	hud_layer.add_child(countdown_overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.4)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_overlay.add_child(center)
	
	countdown_label = Label.new()
	countdown_label.text = "3"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var font_title = FONT_TITLE
	if font_title: countdown_label.add_theme_font_override("font", font_title)
	
	countdown_label.add_theme_font_size_override("font_size", 160)
	countdown_label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	countdown_label.add_theme_constant_override("outline_size", 10)
	countdown_label.pivot_offset = Vector2(0, 80) # Approximate center
	center.add_child(countdown_label)

func _show_countdown_overlay() -> void:
	# Show countdown overlay
	var overlay = hud_layer.get_node_or_null("CountdownOverlay")
	if overlay:
		overlay.visible = true

func _hide_countdown_overlay() -> void:
	# Hide countdown overlay
	var overlay = hud_layer.get_node_or_null("CountdownOverlay")
	if overlay:
		overlay.visible = false

func _create_instruction_overlay() -> void:
	# Create instruction overlay shown before game starts
	instruction_overlay = Control.new()
	instruction_overlay.name = "InstructionOverlay"
	instruction_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	instruction_overlay.visible = false
	# Ensure it does not block input when hidden/fading.
	instruction_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(instruction_overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	instruction_overlay.add_child(center)
	
	var panel = PanelContainer.new()
	panel.name = "PanelContainer"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.3, 0.6, 1.0)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.expand_margin_left = 20
	style.expand_margin_right = 20
	style.expand_margin_top = 20
	style.expand_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 20)
	vbox.custom_minimum_size = Vector2(600, 0)
	panel.add_child(vbox)
	
	var font_title = FONT_TITLE
	var font_body = FONT_BODY
	
	var title = Label.new()
	title.name = "Title"
	title.text = display_title()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_title: title.add_theme_font_override("font", font_title)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title)
	
	var role = Label.new()
	role.name = "Role"
	role.text = Localization.get_text("mp_your_role") % _role_display(my_role)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_body: role.add_theme_font_override("font", font_body)
	role.add_theme_font_size_override("font_size", 32)
	role.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	vbox.add_child(role)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	var instructions = Label.new()
	instructions.name = "Instructions"
	instructions.text = Localization.get_text("mp_instructions_placeholder")
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font_body: instructions.add_theme_font_override("font", font_body)
	instructions.add_theme_font_size_override("font_size", 24)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(instructions)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	var start_label = Label.new()
	start_label.text = Localization.get_text("tap_to_start")
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_label.add_theme_font_size_override("font_size", 20)
	start_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	vbox.add_child(start_label)
	
	# Pulse animation for "Click to start"
	var tween = create_tween().set_loops()
	tween.tween_property(start_label, "modulate:a", 0.3, 0.8)
	tween.tween_property(start_label, "modulate:a", 1.0, 0.8)

	# Transparent full-screen button so mouse, touch, and AutoPlay can dismiss.
	var click_catcher = Button.new()
	click_catcher.name = "ClickCatcher"
	click_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_catcher.focus_mode = Control.FOCUS_NONE
	click_catcher.flat = true
	click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	click_catcher.text = ""
	var empty_style = StyleBoxEmpty.new()
	click_catcher.add_theme_stylebox_override("normal", empty_style)
	click_catcher.add_theme_stylebox_override("hover", empty_style)
	click_catcher.add_theme_stylebox_override("pressed", empty_style)
	click_catcher.add_theme_stylebox_override("focus", empty_style)
	click_catcher.pressed.connect(_on_instruction_dismissed)
	instruction_overlay.add_child(click_catcher)

## Start a music track and stop it again when `scope` leaves the tree.
##
## Same helper, same contract as MiniGameBase._play_scoped_music: the `current_music`
## check means a track already replaced by whatever came next is left alone, so only
## the owner of the still-playing track stops it. Nothing under scripts/multiplayer/
## played music at all before this — all seventeen multiplayer rounds ran on SFX
## alone while every single-player round has a track.
func _play_scoped_music(track: String, fade_in: float, scope: Node) -> void:
	if AudioManager == null or not is_instance_valid(AudioManager):
		return
	AudioManager.play_music(track, fade_in)
	if scope == null or not is_instance_valid(scope):
		return
	scope.tree_exiting.connect(func() -> void:
		if is_instance_valid(AudioManager) and AudioManager.current_music == track:
			AudioManager.stop_music(0.15))


func show_instructions(instructions_text: String) -> void:
	# Show instruction overlay with custom text
	_play_scoped_music("instruction", 0.6, self)
	if instruction_overlay:
		var instructions_label = instruction_overlay.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/Instructions"
		)
		if instructions_label:
			instructions_label.text = instructions_text
		
		var title_label = instruction_overlay.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/Title"
		)
		if title_label:
			title_label.text = display_title()
		
		var role_label = instruction_overlay.get_node_or_null(
			"CenterContainer/PanelContainer/VBoxContainer/Role"
		)
		if role_label:
			role_label.text = Localization.get_text("mp_your_role") % _role_display(my_role)
		
		instruction_overlay.visible = true
		instruction_overlay.mouse_filter = Control.MOUSE_FILTER_STOP # Block input until clicked
		var click_catcher = instruction_overlay.get_node_or_null("ClickCatcher")
		if click_catcher and click_catcher is Button:
			click_catcher.disabled = false

func _on_instruction_clicked(event: InputEvent) -> void:
	# Handle click on instruction overlay
	var is_mouse_click = (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	)
	var is_touch = event is InputEventScreenTouch and event.pressed
	if is_mouse_click or is_touch:
		_on_instruction_dismissed()

func _on_instruction_dismissed() -> void:
	# Guard: only run once per game instance (AutoPlay fires this every frame otherwise)
	if _instruction_dismissed:
		return
	if not instruction_overlay or not instruction_overlay.visible:
		return
	_instruction_dismissed = true

	var click_catcher = instruction_overlay.get_node_or_null("ClickCatcher")
	if click_catcher and click_catcher is Button:
		click_catcher.disabled = true

	# Fade out instructions
	var tween = create_tween()
	tween.set_loops(1)
	tween.tween_property(instruction_overlay, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): 
		instruction_overlay.visible = false
		instruction_overlay.modulate.a = 1.0
	)

	# Show waiting overlay and notify readiness
	_show_waiting_for_start()
	if NetworkManager.has_method("set_local_player_ready"):
		NetworkManager.set_local_player_ready()
	else:
		# Fallback for older NetworkManager versions
		if NetworkManager.is_server():
			NetworkManager.start_countdown()
		_show_countdown_overlay()

	# HOST FALLBACK: if partner never signals ready within 6 seconds, force-start countdown.
	# This covers the case where the client's ready RPC is lost or arrives late.
	if NetworkManager.is_server():
		await get_tree().create_timer(6.0).timeout
		if not game_active:
			_log("⚠️ Partner ready timeout — force-starting countdown")
			NetworkManager.start_countdown()

func _show_waiting_for_start() -> void:
	# Show waiting message while waiting for partner to click ready
	if not hud_layer: return
	_hide_waiting_for_start_overlay()
	
	var overlay = Control.new()
	overlay.name = "WaitingStartOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	overlay.add_child(bg)
	
	var label = Label.new()
	label.text = Localization.get_text("mp_waiting_partner")
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 32)
	overlay.add_child(label)

func _hide_waiting_for_start_overlay() -> void:
	if not hud_layer:
		return
	for child in hud_layer.get_children():
		if child.name == "WaitingStartOverlay":
			child.visible = false
			child.queue_free()

func _on_countdown_tick(count: int) -> void:
	# Countdown tick received
	# Remove waiting overlay if exists
	_hide_waiting_for_start_overlay()
	
	_show_countdown_overlay() # Ensure countdown is visible
	
	countdown_tick.emit(count)
	
	if countdown_label:
		if count > 0:
			countdown_label.text = str(count)
			# Animate the number
			var tween = create_tween()
			tween.set_loops(1)
			tween.tween_property(countdown_label, "scale", Vector2(1.5, 1.5), 0.2).from(Vector2.ZERO)
			tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.2)
		else:
			countdown_label.text = Localization.get_text("mp_countdown_go")
			# Animate GO! then start game
			var tween = create_tween()
			tween.set_loops(1)
			tween.tween_property(countdown_label, "scale", Vector2(1.5, 1.5), 0.2).from(Vector2.ZERO)
			tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.2)
			await get_tree().create_timer(1.0).timeout
			_on_countdown_complete()

# 
# GAME FLOW
# 

func start_game() -> void:
	# Start the game (called after countdown or immediately)

	# Second line of defence behind NetworkManager's one-countdown-per-round guard.
	# Measured symptom when a second countdown chain got through: a second
	# `ui_timer = Timer.new(); add_child(ui_timer)` was left as a live child with
	# the first never freed, so TWO Timers wrote the same timer label every second;
	# game_started was emitted twice; and _on_game_start()'s per-game spawn setup
	# ran a second time on top of the entities the first pass had already created.
	# Guarded here as well because start_game() is also reachable directly from
	# subclasses and from the no-countdown path.
	if game_active:
		_log("⚠️ start_game() called while the round was already active — ignoring")
		return

	_hide_waiting_for_start_overlay()
	_hide_countdown_overlay()
	if instruction_overlay:
		instruction_overlay.visible = false
	if waiting_overlay:
		waiting_overlay.visible = false
	game_active = true
	# Provisional stamp, re-taken at the bottom of this function once the round is
	# actually built. It is set here as well so that nothing reached during the build
	# can read a previous round's stamp (or 0 on the first round, which reads as an
	# elapsed time of hours and would end the round on the spot).
	game_started_time = Time.get_ticks_msec()
	# Cleared with the start time they are relative to. start_game() is guarded
	# against a second entry above, but a scene reused across rounds would carry a
	# previous round's frozen seconds forward and shorten this one.
	_paused_ms_total = 0
	_pause_began_ms = 0
	game_started.emit()
	# Round music, replacing the instruction track. Placed in the base rather than in
	# the twelve subclasses: none of them override start_game().
	_play_scoped_music("gameplay", 0.5, self)
	
	# Start UI timer — fires every second for a clean, human-readable countdown.
	# Do NOT use a shorter interval here: _process() must NOT also update the
	# timer label or the two writes will fight each other and produce decimal
	# flicker at 60fps.
	ui_timer = Timer.new()
	ui_timer.wait_time = 1.0
	ui_timer.timeout.connect(_update_timer_display)
	add_child(ui_timer)
	ui_timer.start()
	# Fire immediately so the label shows the full duration right away.
	_update_timer_display()

	# The smooth progress bar, at 20 Hz off a Timer this base owns rather than off
	# _process() - see _update_timer_bar() for why _process() could not be trusted
	# here. PAUSABLE by inheritance, so it stops with the round.
	if _bar_timer and is_instance_valid(_bar_timer):
		_bar_timer.queue_free()
	_bar_timer = Timer.new()
	_bar_timer.wait_time = 0.05
	_bar_timer.timeout.connect(_update_timer_bar)
	add_child(_bar_timer)
	_bar_timer.start()
	_update_timer_bar()
	
	_log(" Game started! Duration: %.0fs | Inputs enabled" % game_duration)
	_log(" Player %d (%s) - Ready to play!" % [my_player_num, my_role])
	_on_game_start()
	# The round clock starts when the round STARTS, not when this function was
	# entered. Between the two sit the gameplay music stream, two Timers and the
	# subclass's whole spawn fan-out in _on_game_start(): measured at 0.12s on a warm
	# desktop process and 0.45s on the same machine under load, all of it charged to
	# the player's countdown before a single object was on screen - and a legacy
	# Android device is the case this matters for, not the desktop. Single player has
	# never had this bug: MiniGameBase stamps game_start_time after its own fan-out.
	# Safe as a second write because game_started_time has exactly one reader,
	# elapsed_play_seconds(), and re-stamping only ever moves the clock later, so no
	# elapsed value can go backwards mid-round.
	game_started_time = Time.get_ticks_msec()

## Seconds this round has actually been PLAYED, with time spent paused removed.
##
## The single source of truth for round time, and the multiplayer arm of the same
## fix MiniGameBase.elapsed_play_seconds() carries. Four places used to compute
## "(Time.get_ticks_msec() - game_started_time) / 1000.0" independently:
## _update_timer_display() (:758), the reaction_time_ms reported to
## NetworkManager.report_player_completion() (:830), the penalty-path time-up check
## (:873) and the progress bar (:1091). Time.get_ticks_msec() is WALL CLOCK, so all
## four counted time the round was frozen - while ui_timer, the Timer child whose
## tick drives _update_timer_display, is add_child()ed and therefore PAUSABLE and
## does stop. Two clocks, one of them still running while the game was not.
##
## What that cost, measured by tools/VerifyMPPauseClock.tscn across two real peers
## before this existed:
##   - a 2.5s synchronised pause took 2.5s off the round on BOTH peers;
##   - a 6s interruption on a 4s round ended the round the moment it resumed
##     (game_active false on host and client alike), with 1.5s of the players' time
##     never played.
##
## The multiplayer case is worse than the single-player one in two ways. The pause
## is broadcast - NetworkManager.request_pause() rpc's _execute_pause to every peer
## (:1489-1497) - so one player's interruption spent BOTH players' clock; and
## _update_timer_display() is what ends the round, so the loss was not cosmetic.
## On Android the pause is not even a choice: MobileUIManager._on_app_focus_lost()
## sets get_tree().paused = true when the app is backgrounded, so one player taking
## a call failed the round for the pair.
##
## Paused time is accounted rather than the clock being switched to accumulated
## delta, so the reaction_time semantics reported to CoopAdaptation are unchanged
## except that frozen seconds no longer inflate them.
func elapsed_play_seconds() -> float:
	var paused_ms: int = _paused_ms_total
	if _pause_began_ms > 0:
		# Called while still paused: include the pause in progress, otherwise the
		# value jumps the moment the tree resumes.
		paused_ms += Time.get_ticks_msec() - _pause_began_ms
	return float(Time.get_ticks_msec() - game_started_time - paused_ms) / 1000.0

## Paused-time bookkeeping.
##
## NOTIFICATION_PAUSED / NOTIFICATION_UNPAUSED are delivered when this node's own
## processing stops and restarts, which is exactly the interval
## elapsed_play_seconds() has to discount. It covers all three ways an MP round
## gets frozen - the pause menu's NetworkManager.request_pause(), a partner's
## pause arriving over the wire, and the Android background pause - without any of
## them having to know about this.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		if _pause_began_ms == 0:
			_pause_began_ms = Time.get_ticks_msec()
	elif what == NOTIFICATION_UNPAUSED:
		if _pause_began_ms > 0:
			_paused_ms_total += Time.get_ticks_msec() - _pause_began_ms
			_pause_began_ms = 0

func _update_timer_display() -> void:
	# Single source of truth for the timer label — called every 1 second by
	# ui_timer. _process() must NOT write to timer_label or the two paths
	# fight and produce decimal flicker / super-fast animation.
	if not game_active:
		ui_timer.stop()
		return

	_hide_waiting_for_start_overlay()
	_hide_countdown_overlay()
	if instruction_overlay:
		instruction_overlay.visible = false
	if waiting_overlay:
		waiting_overlay.visible = false

	var elapsed := elapsed_play_seconds()
	var remaining: float = max(0.0, game_duration - elapsed - _time_penalty_total)

	if timer_label:
		# Ensure the pivot is centred for the scale-pop animation.
		if timer_label.pivot_offset == Vector2.ZERO:
			timer_label.pivot_offset = timer_label.size / 2.0

		if game_duration >= 999999.0:
			# Endless mode — show elapsed MM:SS
			var minutes := int(elapsed / 60)
			var seconds := int(elapsed) % 60
			timer_label.text = "%02d:%02d" % [minutes, seconds]
			timer_label.add_theme_color_override("font_color", Color.WHITE)
			timer_label.scale = Vector2.ONE
		else:
			# Countdown — whole seconds only, no decimals.
			var secs_left := int(ceil(remaining))
			timer_label.text = str(secs_left)

			if remaining <= 5.0:
				timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
				# Pop animation on each tick in the danger zone.
				var tw := create_tween()
				tw.tween_property(timer_label, "scale", Vector2(1.35, 1.35), 0.08)
				tw.tween_property(timer_label, "scale", Vector2.ONE, 0.15)
			elif remaining <= 10.0:
				timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
				timer_label.scale = Vector2.ONE
			else:
				timer_label.add_theme_color_override("font_color", Color.WHITE)
				timer_label.scale = Vector2.ONE

	if remaining <= 0.0 and game_duration < 999999.0:
		_on_time_up()

func _on_time_up() -> void:
	# Called when time runs out
	_log(" Time up!")
	# Default behavior: If quota exists and not met, fail. Else success.
	# Measured against the TEAM total, not this peer's share — see team_score().
	if win_quota > 0:
		var total := team_score()
		if total >= win_quota:
			end_game(true)
		else:
			_log(" Quota not met (%d/%d team)" % [total, win_quota])
			end_game(false)
	else:
		end_game(true) # Survival success

func _on_countdown_complete() -> void:
	# Called when countdown reaches GO
	_hide_countdown_overlay()
	start_game()

func end_game(success: bool) -> void:
	# End the game and report results
	if not game_active:
		return
	
	game_active = false
	
	_log(" Game ended - %s" % ("Success" if success else "Failed"))
	_play_scoped_music("scoring", 0.3, self)
	
	# Show results/waiting overlay
	_show_results_screen(success)
	
	game_completed.emit(success)
	
	# Report completion to NetworkManager with performance data for CoopAdaptation
	if NetworkManager:
		var reaction_time_ms: int = int(elapsed_play_seconds() * 1000.0)
		var accuracy: float
		if total_actions > 0:
			# Prefer action-tracked accuracy
			accuracy = clamp(float(correct_actions) / float(total_actions), 0.0, 1.0)
		elif win_quota > 0:
			# Derive from score vs quota
			accuracy = clamp(float(local_score) / float(win_quota), 0.0, 1.0)
		else:
			accuracy = 1.0 if success else 0.0
		NetworkManager.report_player_completion(success, local_score, accuracy, reaction_time_ms)

func _penalty_for_difficulty(diff: String) -> float:
	## Returns seconds removed from the clock per mistake for each difficulty tier.
	##   Easy   →  3s  (generous — player needs ~10 mistakes to lose 30s)
	##   Medium →  6s  (moderate — 5 mistakes costs half a minute)
	##   Hard   → 10s  (punishing — 3 mistakes can end the game)
	match diff:
		"Easy":   return 3.0
		"Medium": return 6.0
		"Hard":   return 10.0
	return 5.0  # safe fallback

func _apply_time_penalty() -> void:
	## Remove mistake_time_penalty seconds from the remaining game time and
	## show a brief "-Xs" flash on the timer label so the player knows why
	## the clock jumped.
	if not game_active or game_duration >= 999999.0:
		return
	_time_penalty_total += mistake_time_penalty
	_log("💔 Mistake! -%ds  (total deducted: %.0fs)" % [int(mistake_time_penalty), _time_penalty_total])
	# Visual feedback: show penalty amount in red for 0.6s then restore.
	if timer_label:
		timer_label.text = "-%ds" % int(mistake_time_penalty)
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_callback(func():
			if is_instance_valid(timer_label):
				timer_label.add_theme_color_override("font_color", Color.WHITE)
			_update_timer_display()
		)
	# Check immediately if the penalty ended the game.
	var elapsed := elapsed_play_seconds()
	if game_duration - elapsed - _time_penalty_total <= 0.0:
		_on_time_up()

func _track_action(correct: bool) -> void:
	## Count one player action for CoopAdaptation accuracy, WITHOUT the clock penalty.
	##
	## end_game() reports accuracy to CoopAdaptation, preferring correct_actions /
	## total_actions. Nothing ever incremented those in multiplayer: record_mp_action()
	## was written for child games to call and had zero call sites across all 12 MP
	## games, so total_actions was always 0 and accuracy always fell through to
	## local_score / win_quota.
	##
	## That fallback broke the thesis's Dynamic Co-Adaptation Algorithm in a way no
	## error surfaced: with a shared team quota, two players splitting the work evenly
	## both report ~0.5 accuracy no matter how differently they actually played, so
	## |Φ1 - Φ2| stayed near zero, never crossed SKILL_GAP_THRESHOLD (0.15), and the
	## asymmetric branch with its load balancing could effectively never run.
	##
	## Hits and misses are counted here in the base instead of in each of the 12
	## games, because every one of them already routes scoring through add_score() and
	## misses through report_miss_to_host(). Each peer counts only its OWN events, so
	## the two proficiency indices stay genuinely independent.
	total_actions += 1
	if correct:
		correct_actions += 1
	else:
		mistakes_made += 1

func record_mp_action(correct: bool) -> void:
	## Record a player action for CoopAdaptation accuracy tracking.
	## Call this from child games when the player makes a correct or incorrect move.
	_track_action(correct)
	if not correct:
		_apply_time_penalty()

func show_waiting_overlay() -> void:
	# Show waiting for partner overlay
	is_waiting_for_partner = true
	# waiting_overlay is now handled by _show_results_screen(true)
	_log(" Waiting for partner...")

func hide_waiting_overlay() -> void:
	# Hide waiting overlay
	is_waiting_for_partner = false
	var results = hud_layer.get_node_or_null("ResultsOverlay")
	if results:
		results.visible = false

# 
# SCORING (G-Counter)
# 

func team_score() -> int:
	## The team total the win quota is measured against: the G-Counter query
	## (Σ of every peer's counter), which is the same number _on_team_score_updated
	## puts on the HUD.
	##
	## win_quota is a TEAM target — MP_CatchRainAquarium sets 50 for "10 drops × 5
	## points" out of one shared aquarium that both players fill. Both the early-win
	## check in add_score() and the time-up verdict in _on_time_up() used to compare
	## it against local_score, this peer's own points alone. A round split evenly
	## 25/25 therefore hit the quota on the scoreboard the players were watching and
	## was still recorded as a LOSS by both peers at time-up, feeding a false failure
	## into CoopAdaptation. Reading the shared total also makes the two peers agree:
	## with local_score they could reach opposite verdicts from the same round.
	##
	## It is the ROUND's team total, not the session's. The G-Counter is monotone by
	## construction, so the session total walks into round 2 already past an 80-point quota;
	## NetworkManager.get_round_score() subtracts the baseline the host set when the round
	## loaded. get_total_score() is still the right call for the final-score screen.
	if NetworkManager and NetworkManager.has_method("get_round_score"):
		return NetworkManager.get_round_score()
	if NetworkManager and NetworkManager.has_method("get_total_score"):
		return NetworkManager.get_total_score()
	return local_score

func add_score(points: int, counts_as_action: bool = true) -> void:
	# Add points to local score and sync via G-Counter
	local_score += points

	# A scoring event is this peer's correct action — see _track_action().
	# counts_as_action is false for a bonus stacked on top of an award that was
	# already counted (MP_FilterWater pays 5 per item and 20 again when the unit
	# completes); counting both would inflate that one game's accuracy.
	if counts_as_action:
		_track_action(true)

	if NetworkManager:
		NetworkManager.increment_local(points)

	_log(" +%d points (Local: %d)" % [points, local_score])

	# Check quota against the TEAM total — see team_score().
	if win_quota > 0 and team_score() >= win_quota:
		_log(" Quota met! (%d/%d team)" % [team_score(), win_quota])
		end_game(true)

func report_miss_to_host() -> void:
	# Report a miss event - deducts one team life via the host
	_log("💔 Miss reported - losing team life")
	# Counted for accuracy but deliberately WITHOUT _apply_time_penalty(): a miss
	# already costs the team a shared life here, so also taking seconds off the
	# clock would be a balance change rather than a fix. The MP clock penalty stays
	# reachable only through record_mp_action().
	_track_action(false)
	if GameManager:
		GameManager.rpc("report_damage")

# 
# PAUSE HANDLING
# 

func _on_pause_pressed() -> void:
	# Local player pressed pause
	if NetworkManager:
		NetworkManager.request_pause()
	
	if pause_menu:
		pause_menu.visible = true

func _on_resume_pressed() -> void:
	# Local player pressed resume
	if NetworkManager:
		NetworkManager.request_resume()
	
	if pause_menu:
		pause_menu.visible = false

func _on_quit_pressed() -> void:
	# Quit button pressed - terminate session for both players
	if pause_menu:
		pause_menu.visible = false
	
	_log(" Player quitting session")
	
	# Use GameManager to fully close the ENet peer and reset all state,
	# which triggers server_disconnected on the partner side so they
	# are returned to mode-selection instead of being stuck on the
	# waiting panel with a stale connection.
	if GameManager:
		GameManager.return_to_multiplayer_lobby()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _on_remote_pause() -> void:
	# Partner paused the game
	if pause_menu:
		pause_menu.visible = true

func _on_remote_resume() -> void:
	# Partner resumed the game
	if pause_menu:
		pause_menu.visible = false

## Freeze the round behind a "reconnecting" notice instead of ending it.
##
## The overlay is deliberately STATIC - no tween, no spinner, no animated dots. The tree
## is paused for the duration of the hold, so a tween created here would not advance
## (SceneTreeTween inherits its node's process mode) and would sit on a single frame
## looking broken; PROCESS_MODE_ALWAYS on the overlay just to animate three dots would
## also make it the one thing still moving on a frozen screen, which reads as "the game
## kept playing without me". The dropped seconds are excluded from the round clock by the
## NOTIFICATION_PAUSED accounting above, so nobody loses time to the wait.
func _on_reconnect_hold_started(seconds: float) -> void:
	if not game_active:
		return
	_log(" Connection lost - holding round for %.0f s" % seconds)
	if hud_layer and hud_layer.get_node_or_null("ReconnectOverlay") == null:
		var overlay := Control.new()
		overlay.name = "ReconnectOverlay"
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		hud_layer.add_child(overlay)
		var bg := ColorRect.new()
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.color = Color(0, 0, 0, 0.75)
		overlay.add_child(bg)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.add_child(center)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 16)
		center.add_child(vbox)
		var title := Label.new()
		title.text = Localization.get_text("mp_reconnecting")
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 44)
		title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		vbox.add_child(title)
		var message := Label.new()
		message.text = Localization.get_text("mp_reconnecting_hint")
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.add_theme_font_size_override("font_size", 22)
		vbox.add_child(message)
	var tree := get_tree()
	if tree:
		_pause_before_hold = tree.paused
		tree.paused = true

## Either the peer is back (rejoined == true) and the round resumes exactly where it
## stopped, or the window expired and NetworkManager is already routing this scene out.
func _on_reconnect_hold_ended(rejoined: bool) -> void:
	var tree := get_tree()
	if hud_layer:
		var overlay: Node = hud_layer.get_node_or_null("ReconnectOverlay")
		if overlay:
			hud_layer.remove_child(overlay)
			overlay.queue_free()
	if not rejoined:
		# Leave the tree paused on the way out, and let the resolution clear it.
		# Unpausing here would only buy a dead round one more frame of updates - it has
		# lost a player and NetworkManager._resolve_lost_peer() is about to replace it -
		# and this handler cannot know what replaces it, so it does not get a say.
		#
		# `paused` is a SceneTree property and does NOT come off with the old scene, so
		# both of _resolve_lost_peer()'s branches have to clear it themselves: the client
		# one through return_to_multiplayer_lobby(), the host one inline before its raw
		# change_scene_to_file(). An earlier version of this comment claimed the scene
		# change cleared it, and tools/VerifyInRoundReconnect.tscn caught the host landing
		# in a frozen lobby because of it.
		return
	if tree:
		tree.paused = _pause_before_hold
	_pause_before_hold = false
	_log(" Partner reconnected - round resumed")

func _on_player_left_session(_peer_id: int) -> void:
	# A recoverable drop is NOT a terminated session. NetworkManager emits
	# player_disconnected on every drop, including the ones it is about to hold the round
	# open for, so without this the "player disconnected / session terminated" overlay
	# would go up and its 2 s timer would route to the lobby underneath the hold.
	if NetworkManager and NetworkManager.is_reconnect_hold_active():
		return
	
	# Logged AFTER the gate, not before it. It used to sit at the top of the function, so
	# a drop that was in fact being held open printed "terminating for all players"
	# immediately above "Holding the round open for 6s" - two lines that contradict each
	# other, in a log being read to find out which one actually happened.
	_log(" Player left session - terminating for all players")
	game_active = false
	
	# Show disconnect message
	var disconnect_overlay = Control.new()
	disconnect_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(disconnect_overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.8)
	disconnect_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	disconnect_overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = Localization.get_text("mp_player_disconnected")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	vbox.add_child(title)
	
	var message = Label.new()
	message.text = Localization.get_text("mp_session_terminated")
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 24)
	vbox.add_child(message)
	
	# Wait 2 seconds then return to lobby
	var tree = get_tree()
	if tree:
		await tree.create_timer(2.0).timeout
		
		# Use GameManager to fully close peer + reset state so the
		# lobby shows mode-selection, not a stuck waiting panel.
		if GameManager:
			GameManager.return_to_multiplayer_lobby()
		elif is_inside_tree():
			tree.change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _on_server_disconnected() -> void:
	# Handle when server disconnects (Host quits)
	# Same reason as _on_player_left_session(): while the hold is open the outcome is not
	# decided yet. If it expires, _resolve_lost_peer() runs the branch below itself.
	if NetworkManager and NetworkManager.is_reconnect_hold_active():
		return
	_log(" Server disconnected - terminating session")
	
	# Don't call _on_player_left_session to avoid duplicate UI.
	# Use GameManager to fully close peer + reset state so the
	# lobby shows mode-selection, not a stuck waiting panel.
	if GameManager:
		GameManager.return_to_multiplayer_lobby()
	elif is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

# 
# MAIN LOOP
# 

## The smooth timer bar. Driven by _bar_timer, NOT by _process().
##
## This used to be the body of the base's own _process(), and 13 of the 17
## multiplayer minigames declare their own _process() without calling
## super._process(): MP_CatchRainAquarium, MP_CatchTheRain, MP_CollectDishWater,
## MP_CollectLaundryWater, MP_CollectShowerWater, MP_FillAquarium, MP_FilterWater,
## MP_WashCar and all five MiniGame_* co-op games. A GDScript override REPLACES the
## parent method, so in every one of those the bar was never written again after
## _setup_multiplayer_ui() initialised it to game_duration: it sat visibly full for
## the whole round while the label beside it counted down. Only MP_FlushToilets,
## MP_MopFloor, MP_WashVegetables and MP_WaterPlants - the four that do not override
## _process - ever animated it. Found by tools/VerifyMPPauseClock.tscn, which read
## the bar as a production observable and got a constant 30.00 out of a 20s round.
##
## Adding super._process() to thirteen files would fix today's thirteen and leave
## the trap armed for the fourteenth game. A Timer the BASE owns cannot be shadowed
## by a subclass, and it inherits PAUSABLE from this node, so it correctly freezes
## with the round instead of sliding on through a pause.
func _update_timer_bar() -> void:
	if not game_active:
		# Self-stopping, the same way _update_timer_display() stops ui_timer: the
		# round can end from several places and none of them should have to know
		# about this timer.
		if _bar_timer:
			_bar_timer.stop()
		return
	if _timer_progress_bar == null or game_duration >= 999999.0:
		return
	var elapsed := elapsed_play_seconds()
	var remaining: float = max(0.0, game_duration - elapsed - _time_penalty_total)
	_timer_progress_bar.value = remaining
	# Keep bar colour in sync with danger thresholds
	var fill_style = _timer_progress_bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		if remaining <= 5.0:
			fill_style.bg_color = Color(1.0, 0.3, 0.3)
		elif remaining <= 10.0:
			fill_style.bg_color = Color(1.0, 0.9, 0.3)
		else:
			fill_style.bg_color = Color(0.3, 0.8, 1.0)

# 
# NETWORK CALLBACKS
# 

func _on_team_score_updated(total_score: int) -> void:
	# Team score updated via G-Counter
	var score_label = hud_layer.find_child("ScoreLabel", true, false)
	if score_label:
		score_label.text = " %d" % total_score
		
		# Pop animation
		var tween = create_tween()
		tween.set_loops(1)
		tween.tween_property(score_label, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.1)

func _on_team_lives_updated(remaining_lives: int) -> void:
	# Team lives updated
	var lives_label = hud_layer.find_child("LivesLabel", true, false)
	if lives_label:
		lives_label.text = " x%d" % remaining_lives

		# Flash red and recoil when a life is lost.
		#
		# This used to shake with five position:x tweens. LivesLabel sits inside an
		# HBoxContainer inside another HBoxContainer, and a Control in a container
		# does not own its position — the container rewrites it on the next layout
		# pass, so the shake read as jitter. Worse, every keyframe captured
		# lives_label.position.x at tween-BUILD time, so a re-layout part way through
		# left the tween driving toward a stale coordinate. (Same defect already
		# fixed for timer_bar in MiniGameBase.record_action.)
		#
		# rotation and scale are owned by the Control itself and survive layout, and
		# pivot_offset is already set so both pivot on the glyph rather than the
		# corner. Squash in, overshoot out: the recoil reads as "that hurt" and
		# stays legible on a small phone screen.
		var tween = create_tween()
		tween.set_loops(1)
		tween.tween_property(lives_label, "modulate", Color(2, 0.5, 0.5), 0.08)
		tween.parallel().tween_property(lives_label, "scale", Vector2(1.35, 0.75), 0.08)
		tween.parallel().tween_property(lives_label, "rotation_degrees", -9.0, 0.08)
		tween.tween_property(lives_label, "rotation_degrees", 7.0, 0.07)
		tween.tween_property(lives_label, "scale", Vector2(1.0, 1.0), 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(lives_label, "rotation_degrees", 0.0, 0.12)
		tween.parallel().tween_property(lives_label, "modulate", Color.WHITE, 0.12)
	
	# Check for game over
	if remaining_lives <= 0:
		_on_game_over()

func _on_resource_received(
	from_player: int,
	resource_type: String,
	amount: int,
	quality: float
) -> void:
	# Resource received from partner
	# Override in child class to handle resource
	_log(
		" Received %s x%d (quality: %.1f) from P%d" % [
			resource_type,
			amount,
			quality,
			from_player
		]
	)

func _on_task_marked(from_player: int, task_id: int, pos: Vector2) -> void:
	# Task marked by partner
	# Override in child class to handle task marking
	_log(" Task #%d marked by P%d at %s" % [task_id, from_player, pos])

# 
# HELPER FUNCTIONS
# 

func send_resource_to_partner(resource_type: String, amount: int, quality: float = 1.0) -> void:
	# Send resource to partner player
	if NetworkManager:
		NetworkManager.send_resource(resource_type, amount, quality)

func mark_task_for_partner(task_id: int, task_position: Vector2) -> void:
	# Mark a task for partner to complete
	if NetworkManager:
		NetworkManager.mark_task(task_id, task_position)

func _create_controls_panel() -> void:
	# Create persistent controls panel at bottom right
	var panel = PanelContainer.new()
	panel.name = "ControlsPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -280
	panel.offset_top = -180
	panel.offset_right = -20
	panel.offset_bottom = -20
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	
	hud_layer.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	vbox.add_child(margin)
	
	var controls_vbox = VBoxContainer.new()
	controls_vbox.add_theme_constant_override("separation", 5)
	margin.add_child(controls_vbox)
	
	var title = Label.new()
	title.text = Localization.get_text("mp_controls_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	controls_vbox.add_child(title)
	
	var separator = HSeparator.new()
	controls_vbox.add_child(separator)
	
	# Add controls based on game
	var controls_text = get_controls_text()
	var controls_label = Label.new()
	controls_label.text = controls_text
	controls_label.add_theme_font_size_override("font_size", 14)
	controls_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_label.custom_minimum_size = Vector2(220, 0)
	controls_vbox.add_child(controls_label)

func get_controls_text() -> String:
	# Override this to provide game-specific controls
	return "  Arrow Keys\n Click to interact\n Pause button"

func _log(message: String) -> void:
	# Internal logging
	var full := "[%s P%d] %s" % [game_name, my_player_num, message]
	print(full)
	if SessionLogger:
		SessionLogger.log_entry(game_name if game_name != "" else "MPGame", message)

# 
# OVERRIDE THESE IN CHILD CLASSES
# 

func get_instructions() -> String:
	# Override: Return instruction text for this game
	return ""

## The caption the player reads, in the player's language.
func display_title() -> String:
	if title_key != "" and Localization and Localization.has_text(title_key):
		return Localization.get_text(title_key)
	return game_name


## The role name the player reads. NetworkManager.player_roles holds IDS — the shipping
## start path leaves them at {1: "Collector", 2: "User"} and RainwaterHarvesting branches on
## player_role == "Collector", so the id is logic and must not be translated in place. Only
## the caption is. An id with no key of its own (the LevelSets pairs, which reach
## player_roles solely through MultiplayerCoordinator) passes through unchanged.
func _role_display(role_id: String) -> String:
	if role_id.strip_edges() == "":
		return role_id
	var key: String = "mp_role_%s" % role_id.to_snake_case()
	if Localization and Localization.has_text(key):
		return Localization.get_text(key)
	return role_id

## The game's own key, derived the way MiniGameBase._get_minigame_key() derives the
## singleplayer one: from the script filename, not from game_name. game_name is the
## session-log identity (FIX 68) and title_key is the caption; neither is a table key.
## MP_WashCar.gd -> "wash_car".
func _mp_game_key() -> String:
	var scr: Script = get_script() as Script
	if scr != null and scr.resource_path != "":
		var base: String = scr.resource_path.get_file().trim_suffix(".gd").trim_prefix("MP_")
		if base != "":
			return base.to_snake_case()
	return ""


## The short funny reaction for this game's outcome. The co-op screens used to end a round
## with a bare verdict while the singleplayer path has had per-game reactions all along
## (MiniGameBase._get_result_line_for_key); this is the co-op twin of that resolver. A game
## with no line of its own falls back to the shared one rather than to an empty label.
func _react_line(success: bool) -> String:
	var key: String = "mp_react_%s_%s" % ["win" if success else "fail", _mp_game_key()]
	if Localization and Localization.has_text(key):
		return Localization.get_text(key)
	# A game with no line of its own borrows the singleplayer default, which is already in
	# the table in both languages, rather than rendering an empty label.
	return Localization.get_text("result_line_success_default" if success else "result_line_fail_default")

func _on_multiplayer_ready() -> void:
	# Override: Called when multiplayer setup is complete
	pass

func _on_game_start() -> void:
	# Override: Called when game actually starts
	pass

func _on_game_over() -> void:
	# Override: Called when team runs out of lives
	_log(" GAME OVER")
	_show_results_screen(false)



func _show_game_over_screen() -> void:
	# Show game over screen when lives are depleted
	var overlay = Control.new()
	overlay.name = "GameOverOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.9)
	overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = Localization.get_text("game_over")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(title)
	
	var sub = Label.new()
	sub.text = Localization.get_text("mp_team_out_of_lives")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 32)
	vbox.add_child(sub)

	# The verdict above is correct here — the session really is over. What was missing is the
	# reaction: the brief asks for a funny readable failure, not just the word.
	var react = Label.new()
	react.text = Localization.get_text("mp_react_session_over")
	react.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	react.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	react.custom_minimum_size = Vector2(560, 0)
	react.add_theme_font_size_override("font_size", 28)
	react.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	vbox.add_child(react)
	
	var score_label = Label.new()
	# Two keys the table has carried since the co-op UI was first written. Their only
	# consumer was MultiplayerGameOver.gd, which nothing loads but MultiplayerCoordinator.
	score_label.text = "%s\n%s" % [
		Localization.get_text("multiplayer_final_score") % NetworkManager.get_total_score(),
		Localization.get_text("multiplayer_rounds_survived") % NetworkManager.rounds_survived
	]
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(score_label)
	
	var btn = Button.new()
	btn.text = Localization.get_text("mp_return_to_lobby")
	btn.custom_minimum_size = Vector2(200, 60)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func(): 
		if NetworkManager and NetworkManager.has_method("return_to_lobby"):
			NetworkManager.return_to_lobby()
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")
	)
	
	var btn_container = CenterContainer.new()
	btn_container.add_child(btn)
	vbox.add_child(btn_container)

func _show_results_screen(success: bool) -> void:
	# Remove any existing results overlay to prevent duplicates
	var existing = hud_layer.get_node_or_null("ResultsOverlay")
	if existing:
		existing.queue_free()
	
	# Show Game Over or Success screen
	var overlay = Control.new()
	overlay.name = "ResultsOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = Localization.get_text("mp_level_complete") if success else Localization.get_text("mp_round_lost")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override(
		"font_color",
		Color(0.4, 1.0, 0.4) if success else Color(1.0, 0.55, 0.25)
	)
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(title)

	# A lost ROUND is not the end of the session — the team still has lives and the next
	# round is already queued. The verdict belongs on _show_game_over_screen(); this screen
	# gets the same short reaction the singleplayer path shows.
	var react = Label.new()
	react.text = _react_line(success)
	react.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	react.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	react.custom_minimum_size = Vector2(560, 0)
	react.add_theme_font_size_override("font_size", 28)
	react.add_theme_color_override(
		"font_color",
		Color(0.65, 1.0, 0.7) if success else Color(1.0, 0.72, 0.45)
	)
	vbox.add_child(react)
	
	var sub = Label.new()
	sub.text = Localization.get_text("mp_waiting_partner")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 32)
	vbox.add_child(sub)
	
	# Add your score
	var score_label = Label.new()
	score_label.text = Localization.get_text("mp_your_score") % local_score
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 36)
	score_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(score_label)
	
	is_waiting_for_partner = true
	
	# Connect to NetworkManager signal for round transition
	if (
		NetworkManager
		and not NetworkManager.both_players_completed.is_connected(_on_both_players_completed)
	):
		NetworkManager.both_players_completed.connect(_on_both_players_completed)

func _on_both_players_completed(
	p1_success: bool,
	p2_success: bool,
	p1_score: int,
	p2_score: int
) -> void:
	# Called when both players complete their games
	_log(" Round Complete - P1: %s (%d), P2: %s (%d)" % [
		"Win" if p1_success else "Fail", p1_score,
		"Win" if p2_success else "Fail", p2_score
	])
	
	# Update results screen
	_show_round_summary(p1_success, p2_success, p1_score, p2_score)

func _show_round_summary(
	p1_success: bool,
	p2_success: bool,
	p1_score: int,
	p2_score: int
) -> void:
	# Show detailed round summary
	var overlay = hud_layer.get_node_or_null("ResultsOverlay")
	if not overlay:
		return
	
	# Determine which rows are "mine" vs "partner" based on player number.
	var my_score := p1_score if my_player_num == 1 else p2_score
	var my_success := p1_success if my_player_num == 1 else p2_success
	var partner_score := p2_score if my_player_num == 1 else p1_score
	var partner_success := p2_success if my_player_num == 1 else p1_success

	# Fetch cumulative session totals from NetworkManager
	var session_scores: Dictionary = {}
	if NetworkManager and NetworkManager.has_method("get_mp_session_scores"):
		session_scores = NetworkManager.get_mp_session_scores()
	var session_my_total: int = session_scores.get("p%d_total" % my_player_num, 0)
	var session_team_total: int = session_scores.get("team_total", p1_score + p2_score)

	# Clear and rebuild with full results
	for child in overlay.get_children():
		child.queue_free()
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.9)
	overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = Localization.get_text("mp_round_complete") if (my_success and partner_success) else Localization.get_text("mp_round_rough")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4) if (my_success and partner_success) else Color(1.0, 0.72, 0.25))
	vbox.add_child(title)

	# The reaction for MY outcome, on the screen the player actually reads after a round.
	# _react_line() keys off this game's own script, so each of the 12 gets its own line.
	var react = Label.new()
	react.text = _react_line(my_success)
	react.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	react.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	react.custom_minimum_size = Vector2(520, 0)
	react.add_theme_font_size_override("font_size", 26)
	react.add_theme_color_override(
		"font_color",
		Color(0.65, 1.0, 0.7) if my_success else Color(1.0, 0.72, 0.45)
	)
	vbox.add_child(react)

	# ── YOUR score (highlighted) ──────────────────────────────────────
	var my_panel = PanelContainer.new()
	var my_style = StyleBoxFlat.new()
	my_style.bg_color = Color(0.1, 0.3, 0.1, 0.8)
	my_style.border_color = Color(0.4, 1.0, 0.4)
	my_style.border_width_left = 3
	my_style.border_width_right = 3
	my_style.border_width_top = 3
	my_style.border_width_bottom = 3
	my_style.corner_radius_top_left = 8
	my_style.corner_radius_top_right = 8
	my_style.corner_radius_bottom_left = 8
	my_style.corner_radius_bottom_right = 8
	my_panel.add_theme_stylebox_override("panel", my_style)
	vbox.add_child(my_panel)

	var my_vbox = VBoxContainer.new()
	my_vbox.add_theme_constant_override("separation", 4)
	my_panel.add_child(my_vbox)

	var my_header = Label.new()
	my_header.text = Localization.get_text("mp_your_result_header") % my_player_num
	my_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	my_header.add_theme_font_size_override("font_size", 18)
	my_header.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	my_vbox.add_child(my_header)

	var my_result = Label.new()
	my_result.text = Localization.get_text("mp_result_row_mine") % [
		Localization.get_text("mp_win_token") if my_success else Localization.get_text("mp_fail_token"),
		my_score,
		session_my_total
	]
	my_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	my_result.add_theme_font_size_override("font_size", 28)
	my_result.add_theme_color_override(
		"font_color",
		Color(0.4, 1.0, 0.4) if my_success else Color(1.0, 0.4, 0.4)
	)
	my_vbox.add_child(my_result)

	# ── PARTNER score ─────────────────────────────────────────────────
	var partner_num := 2 if my_player_num == 1 else 1
	var partner_label = Label.new()
	partner_label.text = Localization.get_text("mp_result_row_partner") % [
		partner_num,
		Localization.get_text("mp_win_token") if partner_success else Localization.get_text("mp_fail_token"),
		partner_score
	]
	partner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	partner_label.add_theme_font_size_override("font_size", 28)
	partner_label.add_theme_color_override(
		"font_color",
		Color(0.4, 1.0, 0.4) if partner_success else Color(1.0, 0.4, 0.4)
	)
	vbox.add_child(partner_label)

	# ── Team totals ───────────────────────────────────────────────────
	var sep = HSeparator.new()
	vbox.add_child(sep)

	var total_label = Label.new()
	total_label.text = Localization.get_text("mp_result_totals") % [
		p1_score + p2_score,
		session_team_total,
		NetworkManager.team_lives,
		NetworkManager.rounds_survived
	]
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	total_label.add_theme_font_size_override("font_size", 24)
	total_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(total_label)
	
	# Life deduction notice
	if not p1_success or not p2_success:
		var life_notice = Label.new()
		life_notice.text = Localization.get_text("mp_life_lost")
		life_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		life_notice.add_theme_font_size_override("font_size", 36)
		life_notice.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		vbox.add_child(life_notice)
	
	# Next round notice
	var next_label = Label.new()
	next_label.text = Localization.get_text("mp_loading_next_round")
	next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_label.add_theme_font_size_override("font_size", 22)
	next_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	vbox.add_child(next_label)

## Android Back inside a co-op round: toggle pause, never leave.
##
## Same contract as MiniGameBase.on_back_requested(), and the reason is stronger here:
## leaving drops a partner mid-round, ends the session for BOTH players and opens a
## reconnection window. A stray gesture must not be able to do that. The pause menu
## already carries the deliberate way out.
func on_back_requested() -> bool:
	if pause_menu and is_instance_valid(pause_menu) and pause_menu.visible:
		_on_resume_pressed()
		return true
	if game_active:
		_on_pause_pressed()
		return true
	return true
