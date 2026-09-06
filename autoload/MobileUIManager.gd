extends Node

## ═══════════════════════════════════════════════════════════════════
## MOBILE UI MANAGER - RESPONSIVE UI SYSTEM
## ═══════════════════════════════════════════════════════════════════
## Central manager for mobile-specific UI adaptations
## Handles platform detection, UI scaling, and layout management
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEPENDENCIES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const UIScalerUtil = preload("res://scripts/mobile/UIScaler.gd")
const LayoutManagerUtil = preload("res://scripts/mobile/LayoutManager.gd")

# Godot's own DisplayServer.ScreenOrientation values, referenced symbolically
# instead of copied. The copies read 0 and 6, and 6 is SCREEN_SENSOR - free
# rotation into BOTH portraits - not SCREEN_SENSOR_LANDSCAPE, which is 4. So
# flipping allow_reverse_landscape, whose name promises the other LANDSCAPE,
# would have handed the device full rotation and broken every landscape-only
# assumption below (is_portrait is pinned false, and the whole mobile layout is
# authored against a 16:9-or-wider canvas). Checked against the engine by
# tools/ProbeOrientation.tscn so a future enum change cannot pass unnoticed.
const SCREEN_LANDSCAPE_VALUE: int = DisplayServer.SCREEN_LANDSCAPE
const SCREEN_SENSOR_LANDSCAPE_VALUE: int = DisplayServer.SCREEN_SENSOR_LANDSCAPE

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal mobile_mode_changed(is_mobile: bool)
signal orientation_changed(is_portrait: bool)
signal safe_area_changed(margins: Dictionary)
signal keyboard_visibility_changed(keyboard_height: int)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION EXPORTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Scaling factors
@export var mobile_ui_scale: float = 1.5
@export var mobile_font_scale: float = 1.4
@export var mobile_game_object_scale: float = 1.4
@export var mobile_collectible_scale: float = 1.3

## Minimum sizes
@export var mobile_button_min_size: Vector2 = Vector2(100, 60)
@export var mobile_touch_target_min_size: Vector2 = Vector2(80, 80)

## Spacing
@export var mobile_button_spacing_vertical: float = 20.0
@export var mobile_button_spacing_horizontal: float = 15.0
@export var mobile_safe_area_margin: float = 20.0
@export var mobile_edge_dead_zone: float = 15.0

## Orientation
@export var enforce_landscape_only: bool = true
## Whether the device may auto-rotate between the two LANDSCAPE orientations.
##
## Was false, which made _enforce_landscape_orientation() push SCREEN_LANDSCAPE
## and silently override project.godot's handheld/orientation="sensor_landscape"
## on every _ready() and every resize. A player holding the phone the other way
## round got an upside-down game that would not rotate, and the setting the
## Android export writes into the manifest disagreed with the setting the running
## game applied. Both values are landscape, so this does not weaken
## enforce_landscape_only - is_portrait stays pinned false either way.
@export var allow_reverse_landscape: bool = true

## Performance
@export var mobile_particle_reduction: float = 0.4
@export var mobile_max_tweens: int = 10

var _last_scene: Node = null
@export var mobile_target_fps: int = 30

## Gameplay adjustments — UNADOPTED BY DESIGN. Read this before wiring them in.
##
## These four knobs and apply_game_object_scaling() feed the getters below. Nothing
## in the shipped game calls those getters: the one minigame that did (CatchTheRainV2)
## was measured and reverted. See tools/VerifyMobilePath.tscn and the comments in
## CatchTheRainV2._apply_difficulty_settings / _build_drum for the numbers.
##
## Why they stay unused rather than being wired into MiniGameBase/MicrogameShell:
##
##   * The speed and spawn knobs move the wrong quantity. reaction_time in
##     MiniGameBase is the round's ELAPSED time and AdaptiveDifficulty normalises it
##     by the TIER's time_limit, which these do not touch — so slowing a game down
##     LOWERS the thesis speed term 1 - T_r/T_max for the mobile player.
##   * Any of them applied to some games and not others makes a player's
##     (Accuracy, ReactionTime) samples incomparable across games on one device, and
##     those samples are the study's data, not a game feature.
##   * apply_game_object_scaling scales a Node2D's drawing only. Every minigame's hit
##     test is arithmetic against authored constants, so scaling the node desynchronises
##     the visuals from the logic rather than enlarging a touch target.
##   * project.godot stretches "canvas_items" from a 1920x1080 base, so gameplay
##     objects are already proportionally identical on every panel. Scaling on mobile
##     compensates a second time for something the stretch mode has already done.
##
## The mobile provisions that ARE wired, and are the right places to extend, are the
## UI ones: safe-area insets, touch-target minimum sizes and haptics, applied to every
## scene automatically by _on_tree_changed → adapt_scene_for_mobile.
@export var mobile_game_speed_reduction: float = 0.15
@export var mobile_timing_window_increase: float = 0.2
@export var mobile_spawn_rate_reduction: float = 0.1
@export var mobile_drag_smoothing_increase: float = 1.5

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE VARIABLES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var is_mobile: bool = false
var is_portrait: bool = false
var safe_area_margins: Dictionary = {}
var debug_mobile_mode: bool = false
var debug_logging_enabled: bool = false
var debug_visualization_enabled: bool = false
var viewport_width: int = 0
var viewport_height: int = 0
# Orientation change detection is handled synchronously by
# _on_viewport_size_changed(), which the root Viewport's size_changed signal
# drives. It used to ALSO be polled from _process() behind a 0.5 s debounce
# (_pending_orientation_change / _orientation_change_timer / _new_orientation);
# tools/VerifyViewportPolling.tscn measured that path as unreachable — the signal
# handler has already overwritten viewport_width/height before any frame boundary,
# so the poll's comparison was false forever and the debounce never armed across
# 307 frames spanning two real orientation flips. The dead poll is gone.

# Keyboard avoidance
var keyboard_height: int = 0  ## Current on-screen keyboard height (pixels, 0 when hidden)
var _natural_viewport_height: int = 0  ## Full viewport height with no keyboard
## How often the keyboard's height is read back from Android while a text field has focus.
## The slide-in animation runs ~250 ms, so 10 Hz lands the inset inside that animation,
## and the poll is skipped outright the rest of the time — see _poll_virtual_keyboard().
const KEYBOARD_POLL_INTERVAL: float = 0.1
var _keyboard_poll_timer: float = 0.0
## True once DisplayServer has reported a real keyboard height. From then on the
## viewport-shrink heuristic in _on_viewport_size_changed() stops writing keyboard_height,
## so the two sources can never disagree about it.
var _keyboard_height_from_displayserver: bool = false
## Where the scene's own bottom offset is remembered before a keyboard inset is added to
## it. Cached in node meta rather than assumed to be 0: LayoutManagerUtil.apply_safe_area_margins
## writes that same property ABSOLUTELY (see adapt_scene_for_mobile), so an inset that
## assumed 0 would silently erase the safe-area reserve on the way back out.
const KEYBOARD_INSET_BASE_META := "ww_keyboard_inset_base"

# Frame rate monitoring
var _fps_samples: Array[float] = []
var _fps_sample_interval: float = 1.0  # Sample FPS every second
var _fps_sample_timer: float = 0.0
var _low_fps_warning_shown: bool = false

# Background state
var _is_in_background: bool = false

## Whether THIS autoload is the one that paused the tree.
##
## _on_app_focus_gained() used to clear get_tree().paused unconditionally, which
## cancelled every pause the game takes on purpose: GameManager.pause_game(),
## NetworkManager._execute_pause(), MiniGameBase pause menu, the pause handlers in
## all five MP minigames, and MultiplayerGameOver. On Android that is an everyday
## gesture - open the pause menu, pull the notification shade down, dismiss it - and
## the round resumed underneath a pause menu still on screen. The pause is only ours
## to lift if it was ours to take. Covered by tools/ProbeBackgroundPause.tscn.
var _paused_by_background: bool = false

# Debug visualization
var _debug_overlay: CanvasLayer = null
var _last_adapted_scene_id: int = -1

## The Android/Material minimum touch target, in density-independent pixels.
## Android's accessibility guidance states 48dp; WCAG 2.5.5 asks for the
## equivalent 44 CSS px, so 48dp satisfies both.
const MIN_TOUCH_TARGET_DP: float = 48.0

## The floor the "Large Touch Targets" accessibility toggle asks for, in the same
## density-independent pixels.
##
## WHY THIS CONSTANT EXISTS AT ALL: the toggle used to do nothing on a phone.
## _resolve_button_min_size() raised the target to a fixed Vector2(120, 80) canvas
## units when the toggle was on, and THEN raised it again to the 48dp floor. On the
## two devices this was reported from, the 48dp floor is already larger than both of
## those numbers - 121 units on the Moto E5 Plus (402.5 dpi) and 119 on the Poco X3
## (394.6) - so the toggle resolved to 121x121 on and 121x121 off. Identical. It was
## only ever visible on the 9.7in tablet profile, where the floor is 75 units. A
## fixed canvas-unit pair cannot express "bigger than the minimum" on a screen whose
## minimum is measured in dp, so the toggle asks for a bigger DP FLOOR instead and
## the same production conversion turns it into units.
##
## 64dp rather than something larger: Material's own guidance names 48dp as the
## minimum and recommends going up for motor-impairment users, and 64dp is the step
## that still lets Settings' accessibility rows fit the card they live in - the
## clipping and overlap cost of this number is measured at all seven device profiles
## by tools/AuditMobileUI.tscn -- --large-targets, and the growth it produces is
## measured by tools/VerifyLargeTouchTargets.tscn. That audit is also what found the
## one screen size where 64dp does not fit, which is why the constant below caps it.
const LARGE_TOUCH_TARGET_DP: float = 64.0

## Ceiling on what that request may cost, as a fraction of the 1080-unit canvas height every
## screen in this project is authored against.
##
## 64dp is a PHYSICAL size, and on a low-density screen it buys a lot of canvas: 196 units of a
## 1080-unit-tall canvas on the WVGA 4.5in and qHD 4.5in profiles, against 161 on the Moto E5
## Plus and 158 on the Poco X3. At 196, tools/AuditMobileUI.tscn -- --large-targets measured
## four accidental-touch pairs on the title screen and nowhere else: UI/TopRight's icon strip
## grows downward from the top edge while UI/ButtonContainer's PLAY/MULTIPLAYER column grows
## upward from the bottom, and on those two profiles the two meet. Every profile that resolved
## to 177 units or less was clean, so the ceiling is set just under the largest size measured
## clean: 0.16 * 1080 = 173 units. It therefore bites only on 4.5in-class screens and leaves
## both reported devices at the full 64dp.
##
## Against the BASE height from ProjectSettings rather than the live canvas: stretch
## canvas_items/expand keeps the authored 1080 and expands the width, so the canvas measured
## 1080 tall at every one of the audit's nine profiles - and a headless harness, where the
## canvas comes up square at 1920x1920, would read a 308-unit ceiling and silently stop
## capping the very thing it is there to measure.
##
## The 48dp minimum is applied AFTER this cap and cannot be undercut by it - see
## _resolve_button_min_size(). If a screen is ever dense enough that 48dp alone exceeds the
## ceiling, the standard wins and the layout has to cope.
const LARGE_TOUCH_TARGET_MAX_CANVAS_FRACTION: float = 0.16

## Marker meta a scene sets on the Control it manages itself, so
## adapt_scene_for_mobile() leaves that node's offsets alone. Settings uses it: it
## needs the safe-area inset AND a reserve for its fixed action bar in the same
## two properties, and only the scene knows how tall that bar is.
const SAFE_AREA_SELF_MANAGED_META := "safe_area_self_managed"

## Marker meta a scene sets on a BaseButton that is one row of a list rather than a
## standalone control, so _apply_button_min_size() leaves its authored size alone.
##
## The 48dp floor is applied to BOTH axes, which is right for a button a finger aims
## at directly and wrong for a two-column list row: on a 420dpi phone the floor is
## 126 canvas units, so every CheckBox in Settings became a 126x126 square and six
## accessibility rows overflowed the card they live in. Use this only where the ROW
## is the touch target and the scene sizes that row itself; a control carrying it is
## exempt from the audit's 48dp expectation, so it must not be the only thing a
## player can press.
const COMPACT_ROW_META := "mobile_compact_row"

## The custom_minimum_size a button's own scene or script asked for, before this manager
## raised it to the touch floor. Stored so _apply_button_min_size() can recompute from the
## authored pair rather than from the value it last wrote, which is what makes the
## "Large Touch Targets" toggle work in BOTH directions: max(current, smaller_floor) is
## current, so growing from the live value meant turning the toggle back off left every
## button big until its scene was rebuilt.
const AUTHORED_MIN_SIZE_META := "ww_authored_min_size"

## What this manager last wrote to that button. If the live minimum no longer matches it,
## something else - a script that sizes its own button after adding it to the tree, and
## there are 80 such sites - has spoken since, and its number becomes the new authored
## baseline instead of being overwritten by a floor on the next pass.
const APPLIED_MIN_SIZE_META := "ww_applied_min_size"

## Marks a node whose pivot_offset this manager centred itself, so a later refit may
## recompute it. A node that authored its own pivot never gets the marker and is never
## rewritten.
const MOBILE_PIVOT_META := "ww_mobile_center_pivot"

## Marks a node already hooked to its own resized signal for a scale refit, so the
## connection is made once however many times apply_mobile_scaling is called.
const MOBILE_FIT_HOOK_META := "ww_mobile_fit_hooked"

## Test-only dpi injection, mirroring debug_mobile_mode above. tools/AuditMobileUI.gd
## sets this to a real device's dpi so the touch-target maths can be verified at
## several device profiles on one desktop screen. 0.0 means "ask the DisplayServer".
var debug_dpi_override: float = 0.0

## Test-only cutout injection, in DEVICE PIXELS, same shape as
## SafeAreaInfo.to_dictionary(). Desktop and headless DisplayServers report no
## cutout at all, so without a seam the entire safe-area path is unreachable off
## a real phone and could only be reasoned about, not measured. Empty means
## "ask the DisplayServer".
var debug_safe_area_px_override: Dictionary = {}

## Cache for _resolve_button_min_size(). Recomputed on resize and when the
## large-touch-target setting changes, because the dp-derived floor depends on the
## window size, and because the node_added hook asks for this value once per node
## added to the tree.
var _button_min_cache: Vector2 = Vector2.ZERO
var _button_min_cache_valid: bool = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	_detect_platform()
	_enforce_landscape_orientation()
	_detect_orientation()
	if _should_force_landscape():
		is_portrait = false
	_calculate_safe_area()
	_load_config_if_exists()
	_apply_mobile_performance_profile()
	
	# Capture baseline height before any keyboard appears
	var vp := get_viewport()
	var vp_size := vp.get_visible_rect().size
	viewport_width = int(vp_size.x)
	viewport_height = int(vp_size.y)
	_natural_viewport_height = viewport_height

	# Connect to viewport size changes
	vp.size_changed.connect(_on_viewport_size_changed)
	
	# Connect to app focus changes for background CPU reduction
	get_tree().root.focus_entered.connect(_on_app_focus_gained)
	get_tree().root.focus_exited.connect(_on_app_focus_lost)

	# Adapt newly loaded scenes automatically for mobile safe-area and touch targets.
	if get_tree().has_signal("current_scene_changed"):
		if not get_tree().is_connected("current_scene_changed", _on_current_scene_changed):
			get_tree().connect("current_scene_changed", _on_current_scene_changed)
	else:
		get_tree().tree_changed.connect(_on_tree_changed)
	# Catch buttons built at runtime, which a single scene-change pass misses.
	get_tree().node_added.connect(_on_node_added)
	
	# Create debug overlay if enabled
	if debug_visualization_enabled:
		_create_debug_overlay()

	call_deferred("_adapt_current_scene")
	
	print("📱 MobileUIManager initialized")
	print("   - Platform: %s" % ("Mobile" if is_mobile else "Desktop"))
	print("   - Viewport: %dx%d" % [viewport_width, viewport_height])
	print("   - Orientation: %s" % ("Portrait" if is_portrait else "Landscape"))
	print("   - Debug Mode: %s" % debug_mobile_mode)

## Frame-rate sampling and the soft-keyboard height poll.
##
## The viewport-size poll that used to live here was unreachable: the size_changed
## handler mirrors viewport_width/height synchronously inside the resize, so by the
## time a frame boundary arrived the poll's comparison was always false and its
## 0.5 s orientation debounce never armed (measured over 307 frames and two real
## flips in tools/VerifyViewportPolling.tscn). Removing it leaves _monitor_frame_rate
## as the only body it had. Both it and _poll_virtual_keyboard() are mobile-only, so
## _refresh_process_state() switches this callback off entirely on desktop and while the
## app is backgrounded rather than paying a per-frame script call to reach an early return.
func _process(delta: float) -> void:
	if is_mobile and not _is_in_background:
		_monitor_frame_rate(delta)
		_poll_virtual_keyboard(delta)


## Enable _process only while it has work: FPS sampling and the keyboard-height poll,
## both mobile-only and both pointless while the app is in the background. Called from
## every place that can change either input (platform detection, the debug-mobile
## override, focus).
func _refresh_process_state() -> void:
	set_process(is_mobile and not _is_in_background)

func _detect_platform() -> void:
	# Detect if running on mobile platform or small viewport
	# Check OS platform
	var os_name = OS.get_name()
	var is_mobile_os = os_name in ["Android", "iOS"]
	
	# Check viewport size
	var viewport = get_viewport()
	if viewport:
		var viewport_size = viewport.get_visible_rect().size
		viewport_width = int(viewport_size.x)
		viewport_height = int(viewport_size.y)
		var is_small_viewport = viewport_width < 800
		
		# Mobile if either mobile OS or small viewport
		is_mobile = is_mobile_os or is_small_viewport
	else:
		is_mobile = is_mobile_os
	
	# Apply debug flag override
	if debug_mobile_mode:
		is_mobile = true

	# _process now exists only for the mobile FPS sampler, so whether it runs at
	# all follows is_mobile.
	_refresh_process_state()

func _detect_orientation() -> void:
	# Detect if viewport is in portrait or landscape orientation
	is_portrait = viewport_height > viewport_width
	if _should_force_landscape():
		is_portrait = false


func _should_force_landscape() -> bool:
	if not enforce_landscape_only:
		return false
	if not is_mobile:
		return false
	return OS.get_name() in ["Android", "iOS"]


## The orientation value to push at runtime, derived from project.godot rather
## than decided a second time here.
##
## display/window/handheld/orientation is what the Android export writes into the
## manifest, so a runtime call that disagrees with it ships a build whose declared
## and applied orientations differ - which is exactly the bug this replaces.
## allow_reverse_landscape can only NARROW a sensor variant down to one fixed
## landscape; it can never widen the project's choice. Returns -1 when the project
## is not asking for a landscape at all, so the caller pushes nothing instead of
## overriding a deliberate portrait or free-rotation setting.
func _landscape_orientation_value() -> int:
	var declared := str(ProjectSettings.get_setting(
		"display/window/handheld/orientation", "sensor_landscape"))
	var base: int
	match declared:
		"landscape":
			base = SCREEN_LANDSCAPE_VALUE
		"reverse_landscape":
			base = DisplayServer.SCREEN_REVERSE_LANDSCAPE
		"sensor_landscape":
			base = SCREEN_SENSOR_LANDSCAPE_VALUE
		_:
			return -1
	if not allow_reverse_landscape and base == SCREEN_SENSOR_LANDSCAPE_VALUE:
		return SCREEN_LANDSCAPE_VALUE
	return base


func _enforce_landscape_orientation() -> void:
	if not _should_force_landscape():
		return
	if not DisplayServer.has_method("screen_set_orientation"):
		return

	var want := _landscape_orientation_value()
	if want < 0:
		# project.godot is not asking for a landscape. Pushing one anyway would
		# override a deliberate setting with a stale assumption baked into this file.
		return
	DisplayServer.screen_set_orientation(want)

func _calculate_safe_area() -> void:
	# Calculate safe area margins for devices with notches
	#
	# 	Uses SafeAreaInfo to calculate margins from DisplayServer and applies
	# 	a 20-pixel minimum margin from safe area boundaries as per requirements.
	# 	Emits safe_area_changed signal with the calculated margins.
	# Use SafeAreaInfo to calculate safe area margins
	var safe_area_info = SafeAreaInfo.new()
	safe_area_info.from_display_safe_area()
	
	# Get base margins from SafeAreaInfo
	var base_margins = safe_area_info.to_dictionary()
	if not debug_safe_area_px_override.is_empty():
		base_margins = debug_safe_area_px_override.duplicate()

	# DEVICE PIXELS -> CANVAS UNITS.
	#
	# DisplayServer.get_display_safe_area() and screen_get_size() are both in
	# device pixels, but every consumer of safe_area_margins spends the number as
	# CANVAS units: LayoutManager.apply_safe_area_margins writes it into Control
	# offsets, Settings folds it into its own offsets, and _build_safe_area_overlay
	# sizes ColorRects with it. Those two units coincide only when the stretch
	# ratio is 1, i.e. on a 1080p phone against this project's 1920x1080 base.
	# On a 720p phone the ratio is 0.667, so a 60px cutout inset was applied as 60
	# units where 90 were needed and 20 device pixels of UI stayed under the
	# cutout; on a 1440p phone the same bug over-reserved by a third and wasted
	# screen. Converting once here keeps every consumer correct without each of
	# them having to know about the stretch.
	var px_per_unit := _stretch_ratio()
	for side in ["top", "bottom", "left", "right"]:
		base_margins[side] = float(base_margins.get(side, 0.0)) / px_per_unit
	
	# ROTATION INVARIANCE.
	#
	# allow_reverse_landscape lets the OS flip the device 180 degrees, and a 180
	# degree landscape flip does not change the viewport SIZE - so the resize path
	# that re-reads this never runs, and "left"/"right" stop being stable labels for a
	# cutout that has physically moved to the other edge. Nothing else would correct
	# it either: safe_area_changed has no listeners anywhere in the project, and every
	# consumer pulls get_safe_area_margins() while laying out, which happens on
	# _ready() and on size_changed only. Reserving the larger of each opposing pair on
	# BOTH edges is invariant under the flip by construction - no polling, no new
	# signal, no per-screen wiring - and it keeps centred content centred, which is
	# the same symmetry the authored-margin rule below exists to protect. On the
	# paper's target class, legacy sub-2GB phones with no cutout, every inset is 0 and
	# this is a no-op.
	if allow_reverse_landscape:
		var inset_h := maxf(float(base_margins["left"]), float(base_margins["right"]))
		var inset_v := maxf(float(base_margins["top"]), float(base_margins["bottom"]))
		base_margins["left"] = inset_h
		base_margins["right"] = inset_h
		base_margins["top"] = inset_v
		base_margins["bottom"] = inset_v
	
	# mobile_safe_area_margin is an authored design constant, already expressed in
	# canvas units, so it is added AFTER the conversion above rather than scaled.
	# Apply 20-pixel extra margin ONLY on sides that have an actual hardware
	# cutout (notch/camera cutout). Sides with 0 base margin have no cutout and
	# must NOT receive the extra padding — that would make safe_area_margins
	# asymmetric on phones whose Android nav bar sits on one side in landscape,
	# which shifts the CenterContainer off-center.
	safe_area_margins = {
		"top":    base_margins["top"]    + (mobile_safe_area_margin if base_margins["top"]    > 0 else 0.0),
		"bottom": base_margins["bottom"] + (mobile_safe_area_margin if base_margins["bottom"] > 0 else 0.0),
		"left":   base_margins["left"]   + (mobile_safe_area_margin if base_margins["left"]   > 0 else 0.0),
		"right":  base_margins["right"]  + (mobile_safe_area_margin if base_margins["right"]  > 0 else 0.0),
	}
	
	# Emit signal with updated margins
	safe_area_changed.emit(safe_area_margins)

func _load_config_if_exists() -> void:
	# Load configuration from file if it exists
	var config_path = "user://mobile_ui_config.cfg"
	if FileAccess.file_exists(config_path):
		load_config_file(config_path)


func _adapt_current_scene() -> void:
	if not is_mobile:
		return

	var scene_root = get_tree().current_scene
	if scene_root:
		adapt_scene_for_mobile(scene_root)
		# Re-apply keyboard inset if keyboard is still visible
		if keyboard_height > 0:
			_apply_keyboard_inset(keyboard_height)


func _on_current_scene_changed(_scene_root: Node) -> void:
	if not is_mobile:
		return
	_adapt_current_scene_deferred.call_deferred()


func _on_tree_changed() -> void:
	if not is_inside_tree():
		return
	var tree = get_tree()
	if not tree:
		return
	var current = tree.current_scene
	if current != _last_scene:
		_last_scene = current
		if is_mobile and current != null:
			_adapt_current_scene_deferred.call_deferred()


## Out-of-band fix, no behaviour change while the scene is alive: both scene-change hooks used
## to defer adapt_scene_for_mobile(scene_root) with the Node as the argument. A scene freed
## between the signal and the deferred flush - two scene changes in one frame - made the call
## itself fail with "Error calling deferred method: '...adapt_scene_for_mobile': Cannot convert
## argument 1 from Object to Object", because a stored argument cannot be converted once its
## object is gone. A guard inside adapt_scene_for_mobile() could not help; the failure happens
## while the argument is being bound, before the body runs. Resolving the scene at flush time
## instead does, and it is the same node in every case where the old code worked - if it did
## change again in between, the newer scene is the one that needs adapting anyway.
func _adapt_current_scene_deferred() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if is_instance_valid(scene):
		adapt_scene_for_mobile(scene)


func adapt_scene_for_mobile(scene_root: Node) -> void:
	if not is_mobile or not scene_root:
		return
	# is_mobile and the accessibility toggle are both inputs to the resolved
	# minimum, and Settings re-runs the adaptation right after flipping the
	# toggle, so recomputing here covers both without a second hook.
	_button_min_cache_valid = false

	var safe_target := _find_safe_area_target(scene_root)
	# A scene that computes its own safe-area offsets must not have them
	# overwritten here. LayoutManager.apply_safe_area_margins writes offset_top and
	# offset_bottom ABSOLUTELY, so on Settings it replaced the bar reserve
	# (-(bottom_margin + row_height + gap), measured -253) with the bare inset
	# (-68) and let the scroll viewport run 27 units under the fixed Back button -
	# leaving touchable checkbox slivers beneath it. Settings already folds
	# safe_area_margins into its own arithmetic, so the fix is to stop two systems
	# writing one property rather than to interleave them.
	if safe_target and safe_target.has_meta(SAFE_AREA_SELF_MANAGED_META):
		safe_target = null
	if safe_target and not safe_area_margins.is_empty():
		LayoutManagerUtil.apply_safe_area_margins(safe_target, safe_area_margins)

	_apply_mobile_layout_hints(scene_root, _resolve_button_min_size())
	_apply_mobile_scene_optimizations(scene_root)

	if TouchInputManager and TouchInputManager.has_method("enable_haptics_for_scene"):
		TouchInputManager.enable_haptics_for_scene(scene_root)

	_last_adapted_scene_id = scene_root.get_instance_id()
	_log_debug("Adapted scene for mobile: %s" % scene_root.name)


func _find_safe_area_target(scene_root: Node) -> Control:
	var scene_path := ""
	if scene_root:
		scene_path = scene_root.scene_file_path
	var is_cutscene := scene_path.contains("/cutscenes/")

	if scene_root is Control:
		var ui_child = scene_root.get_node_or_null("UI")
		if ui_child and ui_child is Control:
			return ui_child as Control
		var margin_child = scene_root.get_node_or_null("MarginContainer")
		if margin_child and margin_child is Control:
			return margin_child as Control
		var center_child = scene_root.get_node_or_null("CenterContainer")
		if center_child and center_child is Control:
			return center_child as Control
		if is_cutscene:
			return null
		return scene_root as Control

	var direct_ui = scene_root.get_node_or_null("UI")
	if direct_ui and direct_ui is Control:
		return direct_ui as Control

	var direct_margin = scene_root.get_node_or_null("MarginContainer")
	if direct_margin and direct_margin is Control:
		return direct_margin as Control
	var direct_center = scene_root.get_node_or_null("CenterContainer")
	if direct_center and direct_center is Control:
		return direct_center as Control
	if is_cutscene:
		return null

	for child in scene_root.get_children():
		if child is Control:
			return child as Control

	return null


## The dp -> canvas-unit conversion, and the reason this function is not just a
## constant.
##
## project.godot uses stretch/mode="canvas_items" with a 1920x1080 base, so every
## Control size is in CANVAS units, not device pixels. mobile_button_min_size was
## therefore internally consistent but said nothing about finger size: 60 canvas
## units is 60 physical px on a 1080p phone and 40 px on a 720p one. Measured with
## tools/AuditMobileUI.tscn, the 60-unit floor landed between 13.1dp and 17.4dp
## across five device profiles - every touch target in the game was under a third
## of the 48dp Android minimum.
##
## canvas_units = dp * (dpi / 160) / stretch_ratio
##
## where stretch_ratio is physical px per canvas unit, read back from the
## DisplayServer rather than assumed, because stretch/aspect="expand" lets Godot
## pick the governing axis.
## Device pixels per canvas unit.
##
## Read back rather than assumed: project.godot uses stretch/aspect="expand", so
## Godot chooses which axis absorbs the extra room and window.x/1920 is only the
## right ratio when the window aspect happens to match the base aspect.
func _stretch_ratio() -> float:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return 1.0
	var canvas := tree.root.get_visible_rect().size
	if canvas.x <= 0.0:
		return 1.0
	var r := float(DisplayServer.window_get_size().x) / canvas.x
	return r if r > 0.0 else 1.0


func _dp_to_canvas_units(dp: float) -> float:
	var dpi := debug_dpi_override
	if dpi <= 0.0:
		dpi = float(DisplayServer.screen_get_dpi(DisplayServer.window_get_current_screen()))
	# A DisplayServer that cannot report dpi returns 0 (and some Android drivers
	# report absurd values). Fall back to the mdpi baseline of 160, which makes
	# 1dp == 1px and degrades to the old behaviour instead of producing a
	# nonsensical floor.
	if dpi <= 40.0 or dpi > 1200.0:
		dpi = 160.0
	var ratio := _stretch_ratio()
	# Rounded UP, not to the nearest unit. A fractional minimum of 146.86 units
	# produces a button that measures 47.997dp - short of the standard by a
	# rounding error, which is still short. Ceiling guarantees the target meets or
	# exceeds 48dp, and costs at most one canvas unit of extra height.
	return ceilf(dp * (dpi / 160.0) / ratio)


func _resolve_button_min_size() -> Vector2:
	if _button_min_cache_valid:
		return _button_min_cache
	var wants_large: bool = _wants_large_touch_targets()
	var target_size = mobile_button_min_size
	if wants_large:
		target_size = Vector2(max(target_size.x, 120.0), max(target_size.y, 80.0))
	# Raise the authored minimum to the touch floor when the screen needs it. This
	# only ever grows the target, so a scene that already authored something bigger
	# keeps its own size.
	#
	# WHICH floor is the whole of the "Large Touch Targets" toggle: the fixed 120x80
	# above is smaller than the 48dp floor on every phone profile this project
	# measures, so before LARGE_TOUCH_TARGET_DP existed the toggle changed nothing a
	# finger could feel. See that constant for the numbers.
	if is_mobile:
		var floor_units := _dp_to_canvas_units(MIN_TOUCH_TARGET_DP)
		if wants_large:
			# max(), so the capped large request can never come out UNDER the 48dp standard
			# on a screen dense enough for the cap to fall below it.
			floor_units = maxf(floor_units, _large_target_floor_units())
		target_size = Vector2(maxf(target_size.x, floor_units), maxf(target_size.y, floor_units))
	_button_min_cache = target_size
	_button_min_cache_valid = true
	return target_size


## What the "Large Touch Targets" floor costs in canvas units on THIS screen, with the request
## capped so it cannot outgrow the layout it is spent on. See
## LARGE_TOUCH_TARGET_MAX_CANVAS_FRACTION for the measurement that set the ceiling and for why
## it is taken against the authored base height rather than the live canvas.
func _large_target_floor_units() -> float:
	var large_units := _dp_to_canvas_units(LARGE_TOUCH_TARGET_DP)
	var base_height: float = float(
		ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	if base_height <= 0.0:
		return large_units
	return minf(large_units, ceilf(base_height * LARGE_TOUCH_TARGET_MAX_CANVAS_FRACTION))


## Called wherever an input to the size changes: a resize alters the stretch ratio,
## and the accessibility toggle alters the authored floor.
func invalidate_button_min_size_cache() -> void:
	_button_min_cache_valid = false

func _apply_mobile_performance_profile() -> void:
	# Apply baseline performance limits for mobile hardware.
	if is_mobile:
		Engine.max_fps = max(20, mobile_target_fps)
		PerformanceManager.set_max_tweens(get_max_tweens())
	else:
		Engine.max_fps = 0


func _apply_mobile_scene_optimizations(scene_root: Node) -> void:
	if not scene_root or not is_mobile:
		return
	if scene_root.has_meta("_mobile_optimized"):
		return
	_optimize_particles_recursive(scene_root)
	scene_root.set_meta("_mobile_optimized", true)


func _optimize_particles_recursive(node: Node) -> void:
	if node is GPUParticles2D:
		PerformanceManager.optimize_particle_system_for_mobile(node)
	for child in node.get_children():
		_optimize_particles_recursive(child)


## Runtime-built buttons, which are the majority in this project: 80
## BaseButton.new() sites across 25 scripts. Several of them run after an `await`
## inside _ready(), so the single adapt_scene_for_mobile() pass at scene-change
## time cannot see them - MainMenu is the proof, since it builds its Auto-Play
## toggle after `await get_tree().process_frame` and that toggle measured 190x40
## on a mobile profile, below this manager's own enforced minimum.
##
## node_added fires once per node and the handler is a single type check, so it
## costs far less than constructing the node it follows, and it makes the touch
## minimum unmissable instead of dependent on frame ordering.
func _on_node_added(node: Node) -> void:
	if not is_mobile:
		return
	if node is BaseButton:
		_apply_button_min_size(node as BaseButton, _resolve_button_min_size())


## Only ever grows a button beyond the size ITS OWN scene or script asked for, and that
## authored size is remembered rather than inferred from the live value - so the pass is
## idempotent, and the accessibility toggle above it is reversible.
func _apply_button_min_size(button: BaseButton, button_minimum_size: Vector2) -> void:
	# Whose number is currently in custom_minimum_size? If it is not the one this manager
	# last wrote, the button's owner has spoken since - a script that sizes its button
	# after adding it to the tree - and that becomes the baseline to grow from.
	if not button.has_meta(APPLIED_MIN_SIZE_META) \
			or button.custom_minimum_size != Vector2(button.get_meta(APPLIED_MIN_SIZE_META)):
		button.set_meta(AUTHORED_MIN_SIZE_META, button.custom_minimum_size)
	var authored: Vector2 = Vector2(button.get_meta(AUTHORED_MIN_SIZE_META, Vector2.ZERO))

	var target: Vector2 = Vector2(
		maxf(authored.x, button_minimum_size.x),
		maxf(authored.y, button_minimum_size.y)
	)
	# A compact row keeps the WIDTH its scene authored, always: the row already spans the
	# list it sits in, and squaring it off against a both-axes floor is what put six
	# 126x126 accessibility checkboxes through the bottom of Settings' card. With large
	# touch targets off it keeps its authored height as well; with them on, that explicit
	# accessibility request outranks the layout that wanted the row short - Settings' own
	# "Large Touch Targets" checkbox is one of these rows - but it is spent on the one
	# axis a finger actually misses.
	if button.has_meta(COMPACT_ROW_META):
		if not _wants_large_touch_targets():
			target = authored
		else:
			target = Vector2(authored.x, maxf(authored.y, button_minimum_size.y))

	button.custom_minimum_size = target
	button.set_meta(APPLIED_MIN_SIZE_META, target)


func _wants_large_touch_targets() -> bool:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("get_setting"):
		return bool(save_mgr.get_setting("large_touch_targets", false))
	return false


func _apply_mobile_layout_hints(node: Node, button_minimum_size: Vector2) -> void:
	if node is BaseButton:
		_apply_button_min_size(node as BaseButton, button_minimum_size)
	if node is BoxContainer:
		var box = node as BoxContainer
		var desired_sep = (
			mobile_button_spacing_vertical if box.vertical else mobile_button_spacing_horizontal
		)
		if box.get_theme_constant("separation") < int(desired_sep):
			box.add_theme_constant_override("separation", int(desired_sep))
	elif node is GridContainer:
		var grid = node as GridContainer
		if grid.get_theme_constant("h_separation") < int(mobile_button_spacing_horizontal):
			grid.add_theme_constant_override("h_separation", int(mobile_button_spacing_horizontal))
		if grid.get_theme_constant("v_separation") < int(mobile_button_spacing_vertical):
			grid.add_theme_constant_override("v_separation", int(mobile_button_spacing_vertical))

	for child in node.get_children():
		_apply_mobile_layout_hints(child, button_minimum_size)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - PLATFORM DETECTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func is_mobile_platform() -> bool:
	# Returns true if running on mobile platform or small viewport
	return is_mobile

func is_portrait_orientation() -> bool:
	# Returns true if viewport is in portrait orientation
	return is_portrait

func is_landscape_orientation() -> bool:
	# Returns true if viewport is in landscape orientation
	return not is_portrait

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - SCALING FACTORS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_ui_scale() -> float:
	# Returns UI scale factor for mobile (1.5x) or desktop (1.0x)
	return mobile_ui_scale if is_mobile else 1.0

func get_font_scale() -> float:
	# Returns font scale factor for mobile (1.4x) or desktop (1.0x)
	return mobile_font_scale if is_mobile else 1.0

func get_game_object_scale() -> float:
	# Returns game object scale factor for mobile (1.4x) or desktop (1.0x)
	return mobile_game_object_scale if is_mobile else 1.0

func get_collectible_scale() -> float:
	# Returns collectible scale factor for mobile (1.3x) or desktop (1.0x)
	return mobile_collectible_scale if is_mobile else 1.0

func get_button_min_size() -> Vector2:
	# Returns minimum button size for mobile (100x60) or desktop (44x44)
	return mobile_button_min_size if is_mobile else Vector2(44, 44)

func get_touch_target_min_size() -> Vector2:
	# Returns minimum touch target size for mobile (80x80) or desktop (44x44)
	return mobile_touch_target_min_size if is_mobile else Vector2(44, 44)

func get_button_spacing_vertical() -> float:
	# Returns vertical button spacing for mobile (20px) or desktop (10px)
	return mobile_button_spacing_vertical if is_mobile else 10.0

func get_button_spacing_horizontal() -> float:
	# Returns horizontal button spacing for mobile (15px) or desktop (10px)
	return mobile_button_spacing_horizontal if is_mobile else 10.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - SAFE AREA
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_safe_area_margins() -> Dictionary:
	# Returns safe area margins for devices with notches
	return safe_area_margins

func get_safe_area_margin() -> float:
	# Returns minimum margin from safe area boundaries (20px)
	return mobile_safe_area_margin

func get_edge_dead_zone() -> float:
	# Returns edge dead zone size for preventing accidental touches (15px)
	return mobile_edge_dead_zone

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - PERFORMANCE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_particle_reduction() -> float:
	# Returns particle reduction factor for mobile (0.4 = 40% reduction)
	return mobile_particle_reduction if is_mobile else 0.0

func get_max_tweens() -> int:
	# Returns maximum simultaneous tweens for mobile (10)
	return mobile_max_tweens if is_mobile else 999

func get_target_fps() -> int:
	# Returns target FPS for mobile (30)
	return mobile_target_fps if is_mobile else 60

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - GAMEPLAY ADJUSTMENTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func get_game_speed_multiplier() -> float:
	# Returns game speed multiplier for mobile (0.85 = 15% slower)
	return 1.0 - mobile_game_speed_reduction if is_mobile else 1.0

func get_timing_window_multiplier() -> float:
	# Returns timing window multiplier for mobile (1.2 = 20% larger)
	return 1.0 + mobile_timing_window_increase if is_mobile else 1.0

func get_spawn_rate_multiplier() -> float:
	# Returns spawn rate multiplier for mobile (0.9 = 10% slower)
	return 1.0 - mobile_spawn_rate_reduction if is_mobile else 1.0

func get_drag_smoothing_multiplier() -> float:
	# Returns drag smoothing multiplier for mobile (1.5x)
	return mobile_drag_smoothing_increase if is_mobile else 1.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - UI SCALING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func apply_mobile_scaling(node: Control) -> void:
	# Apply mobile-specific scaling to a Control node
	if not is_mobile:
		return
	
	if not node:
		push_warning("MobileUIManager.apply_mobile_scaling: node is null")
		return

	# Avoid compounding scale when a parent is already scaled for mobile.
	if _has_mobile_scaled_ancestor(node):
		return
	
	_log_debug("Scaling Control node: %s (original size: %s)" % [node.name, node.size])

	var base_scale = _get_or_store_base_scale(node)
	var base_minimum_size = _get_or_store_base_minimum_size(node)
	
	# Apply UI scale factor
	_apply_fitted_mobile_scale(node, base_scale)
	node.set_meta("_mobile_scaled_root", true)
	
	# Apply button-specific handling
	if node is Button:
		var button_node = node as Button
		# Ensure minimum button size (100x60 pixels)
		UIScalerUtil.ensure_minimum_size(button_node, _resolve_button_min_size())
		
		# Add expanded hit detection area (10 pixels beyond visual boundaries) once.
		var expanded_size = Vector2(
			max(base_minimum_size.x, _resolve_button_min_size().x),
			max(base_minimum_size.y, _resolve_button_min_size().y)
		) + Vector2(20, 20)
		button_node.custom_minimum_size = Vector2(
			max(button_node.custom_minimum_size.x, expanded_size.x),
			max(button_node.custom_minimum_size.y, expanded_size.y)
		)
		
		# Apply font scaling to button label
		# Buttons in Godot have their text rendered internally, but we can scale the font
		var button_base_font = _get_or_store_base_font_size(button_node, 18)
		button_node.add_theme_font_size_override(
			"font_size",
			max(16, int(round(button_base_font * mobile_font_scale)))
		)
	
	# Apply font scaling to labels
	if node is Label:
		var label_node = node as Label
		var label_base_font = _get_or_store_base_font_size(label_node, 16)
		label_node.add_theme_font_size_override(
			"font_size",
			max(14, int(round(label_base_font * mobile_font_scale)))
		)
	
	# Ensure all touch targets meet minimum size
	UIScalerUtil.ensure_minimum_size(node, mobile_touch_target_min_size)
	
	_log_debug("Scaled Control node: %s (final size: %s)" % [node.name, node.size])


func _has_mobile_scaled_ancestor(node: Control) -> bool:
	var current = node.get_parent()
	while current and current is Control:
		if current.has_meta("_mobile_scaled_root"):
			return true
		current = current.get_parent()
	return false


func _get_or_store_base_scale(node: Control) -> Vector2:
	if node.has_meta("_mobile_base_scale"):
		var stored_scale = node.get_meta("_mobile_base_scale")
		if stored_scale is Vector2:
			return stored_scale

	node.set_meta("_mobile_base_scale", node.scale)
	return node.scale


func _get_or_store_base_minimum_size(node: Control) -> Vector2:
	if node.has_meta("_mobile_base_min_size"):
		var stored_min_size = node.get_meta("_mobile_base_min_size")
		if stored_min_size is Vector2:
			return stored_min_size

	node.set_meta("_mobile_base_min_size", node.custom_minimum_size)
	return node.custom_minimum_size


## Write the mobile scale factor in a way the layout can survive.
##
## Control.scale is invisible to layout. A container positions this node from its
## UNSCALED minimum size and the node then draws mobile_ui_scale times larger, growing
## from pivot_offset - which defaults to the TOP-LEFT corner. On the title screen that
## put the EXIT button 78 units below the bottom of a 1080-unit screen: CenterContainer
## centred an 857x618 box and the box then drew 927 units tall downward from y=231.
## Measured with tools/VerifyMenuFit.tscn at 402 dpi (the density of 2160x1080 on the
## Moto E5 Plus's 6.0in panel) and 74 units over at the Poco X3's 395 dpi. It was
## invisible in every headless sweep because DisplayServer reports no dpi there, the
## mdpi 160 fallback keeps the 48dp touch floor small, and at that floor the same
## layout has 24 units to spare - so the defect only exists at real phone densities.
##
## Two corrections, each of which can only ever improve the fit:
##   1. scale about the node's own centre, so a container that centred the unscaled box
##      still centres what gets drawn instead of letting the extra size fall downward.
##      The whole title menu sat 154 units low for the same reason it was clipped.
##   2. clamp the factor so the scaled box still fits the space the parent gave it, for
##      the densities where even a centred 1.5x does not fit. Never below 1.0: the
##      unscaled layout is the scene's own business, not something to squash here.
func _apply_fitted_mobile_scale(node: Control, base_scale: Vector2) -> void:
	_center_mobile_pivot(node)
	node.scale = base_scale * _fit_scale_for(node, mobile_ui_scale)
	# The 48dp touch floor that grows the box is applied by adapt_scene_for_mobile,
	# which runs AFTER a scene's own _ready() has already called in here - the box the
	# first call measured is not the box the player gets. Re-derive on resized rather
	# than hoping the ordering never changes; nothing in here writes size, so this
	# cannot feed back on itself.
	if not node.has_meta(MOBILE_FIT_HOOK_META):
		node.set_meta(MOBILE_FIT_HOOK_META, true)
		node.resized.connect(_refit_mobile_scale.bind(node))


func _refit_mobile_scale(node: Control) -> void:
	if node == null or not is_instance_valid(node) or not is_mobile:
		return
	# Only refit what this manager scaled in the first place. Without the guard the
	# base-scale accessor below would capture the ALREADY SCALED value as the base and
	# the factor would compound on every re-sort.
	if not node.has_meta("_mobile_base_scale"):
		return
	_center_mobile_pivot(node)
	node.scale = _get_or_store_base_scale(node) * _fit_scale_for(node, mobile_ui_scale)


## Scale from the middle rather than the top-left corner. A non-zero pivot_offset is an
## opinion the scene expressed and is left alone; anything this manager centres itself
## is marked so a later refit may recompute it against a grown box.
func _center_mobile_pivot(node: Control) -> void:
	if not node.has_meta(MOBILE_PIVOT_META):
		if not node.pivot_offset.is_zero_approx():
			return
		node.set_meta(MOBILE_PIVOT_META, true)
	node.pivot_offset = _layout_box_of(node) * 0.5


## The box layout will give this node: its settled size where there is one, and its own
## combined minimum otherwise, because this runs from _ready() before any sort has
## happened. For a container placed by its minimum size the two are the same number.
func _layout_box_of(node: Control) -> Vector2:
	var mins := node.get_combined_minimum_size()
	return Vector2(maxf(node.size.x, mins.x), maxf(node.size.y, mins.y))


## The largest factor up to `wanted` at which this node's own box still fits the space
## its parent gave it. Returns `wanted` untouched whenever there is room, so a screen
## with space to spare keeps the full mobile magnification.
func _fit_scale_for(node: Control, wanted: float) -> float:
	if wanted <= 1.0:
		return wanted
	var box := _layout_box_of(node)
	var area := node.get_parent_area_size()
	if box.x <= 0.0 or box.y <= 0.0 or area.x <= 0.0 or area.y <= 0.0:
		return wanted
	var fit: float = minf(area.x / box.x, area.y / box.y)
	if fit >= wanted:
		return wanted
	return maxf(1.0, fit)


func _get_or_store_base_font_size(node: Control, fallback_size: int) -> int:
	if node.has_meta("_mobile_base_font_size"):
		return int(node.get_meta("_mobile_base_font_size"))

	var font_size = node.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = fallback_size

	node.set_meta("_mobile_base_font_size", font_size)
	return font_size

func apply_game_object_scaling(node: Node2D) -> void:
	# Apply mobile-specific scaling to game objects (Node2D)
	#
	# 	Scales interactive objects by 1.4x and collectibles by 1.3x.
	# 	Ensures draggable objects have minimum 120x120 pixel area.
	# 	Preserves collision shapes during scaling.
	#
	# 	@param node: The Node2D game object to scale
	if not is_mobile:
		return
	
	if not node:
		push_warning("MobileUIManager.apply_game_object_scaling: node is null")
		return
	
	_log_debug("Scaling game object: %s (original scale: %s)" % [node.name, node.scale])
	
	# Determine scale factor based on object type
	var scale_factor: float = mobile_game_object_scale  # Default: 1.4x for interactive objects
	
	# Check if this is a collectible (by name or group)
	var is_collectible = (
		"collectible" in node.name.to_lower() or
		"drop" in node.name.to_lower() or
		"coin" in node.name.to_lower() or
		"item" in node.name.to_lower() or
		node.is_in_group("collectibles")
	)
	
	if is_collectible:
		scale_factor = mobile_collectible_scale  # 1.3x for collectibles
	
	# Store original scale to preserve any existing scaling
	var original_scale = node.scale
	
	# Apply mobile scaling while preserving aspect ratio
	node.scale = original_scale * scale_factor
	
	# Check if this is a draggable object and ensure minimum size
	var is_draggable = (
		"drag" in node.name.to_lower() or
		node.is_in_group("draggable") or
		node.get("input_pickable") == true
	)
	
	if is_draggable:
		# Calculate effective size after scaling
		# For Node2D, we need to check if there's a visual representation
		var effective_size = Vector2.ZERO
		
		# Try to get size from Sprite2D
		var sprite = node.get_node_or_null("Sprite2D")
		if not sprite and node is Sprite2D:
			sprite = node
		
		if sprite and sprite is Sprite2D:
			var texture = sprite.texture
			if texture:
				effective_size = texture.get_size() * node.scale
		
		# Try to get size from CollisionShape2D
		if effective_size == Vector2.ZERO:
			var collision = node.get_node_or_null("CollisionShape2D")
			if not collision and node is CollisionShape2D:
				collision = node
			
			if collision and collision is CollisionShape2D:
				var shape = collision.shape
				if shape:
					if shape is RectangleShape2D:
						effective_size = shape.size * node.scale
					elif shape is CircleShape2D:
						var diameter = shape.radius * 2.0
						effective_size = Vector2(diameter, diameter) * node.scale
					elif shape is CapsuleShape2D:
						effective_size = Vector2(shape.radius * 2.0, shape.height) * node.scale
		
		# Ensure minimum draggable area of 120x120 pixels
		var min_draggable_size = Vector2(120, 120)
		if effective_size != Vector2.ZERO:
			if effective_size.x < min_draggable_size.x or effective_size.y < min_draggable_size.y:
				# Calculate additional scaling needed
				var additional_scale_x = (
					min_draggable_size.x / effective_size.x if effective_size.x > 0 else 1.0
				)
				var additional_scale_y = (
					min_draggable_size.y / effective_size.y if effective_size.y > 0 else 1.0
				)
				var additional_scale = max(additional_scale_x, additional_scale_y)
				
				# Apply additional scaling to meet minimum size
				node.scale *= additional_scale
	
	# Collision shapes are automatically scaled with the parent node in Godot
	# No additional work needed to preserve collision detection accuracy
	
	var object_type = "collectible" if is_collectible else (
		"draggable" if is_draggable else "interactive"
	)
	_log_debug(
		"Scaled game object: %s (final scale: %s, type: %s)"
		% [node.name, node.scale, object_type]
	)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - DEMO BUTTONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func should_show_demo_buttons() -> bool:
	# Returns true if demo buttons should be visible
	# Hide on mobile unless in debug mode
	if is_mobile and not OS.is_debug_build():
		return false
	
	# Show on desktop in debug mode
	if OS.is_debug_build():
		return true
	
	# Hide in production builds
	return false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - DEBUG MODE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func enable_debug_mobile_mode(enabled: bool) -> void:
	# Enable/disable debug mobile mode for testing on desktop
	debug_mobile_mode = enabled
	_detect_platform()
	mobile_mode_changed.emit(is_mobile)
	
	print("📱 Debug mobile mode: %s" % ("enabled" if enabled else "disabled"))
	print("   - is_mobile: %s" % is_mobile)

func is_debug_mode() -> bool:
	# Returns true if debug mobile mode is enabled
	return debug_mobile_mode

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PUBLIC INTERFACE - CONFIGURATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Read the tuning knobs out of a hand-editable ConfigFile.
##
## Every value goes through a checked accessor rather than straight into the
## @export member. The members are statically typed, so `mobile_ui_scale =
## config.get_value(...)` with a String in the file did not store a wrong number —
## it raised "Trying to assign value of type 'String' to a variable of type
## 'float'" and ABORTED THIS FUNCTION, leaving every knob below it at its default
## and skipping the `return true`, which the caller discards anyway. Measured in
## tools/VerifyMobileConfig.tscn: one bad "scaling/ui_scale" dropped font_scale,
## touch_target_min_size, max_tweens and drag_smoothing_increase from the same
## file. A rejected key now falls back alone and says so.
##
## Numbers are accepted across int/float either way (a decimal in an int knob
## truncates, which ConfigFile and GDScript already did: 41.7 -> 41), because the
## point is to survive a hand-edit, not to be pedantic about how it was typed.
func load_config_file(path: String) -> bool:
	var config := ConfigFile.new()
	var err := config.load(path)

	if err != OK:
		push_warning("Failed to load mobile UI config from %s: %s" % [path, error_string(err)])
		return false

	# Scaling factors
	mobile_ui_scale = _cfg_float(config, "scaling", "ui_scale", mobile_ui_scale)
	mobile_font_scale = _cfg_float(config, "scaling", "font_scale", mobile_font_scale)
	mobile_game_object_scale = _cfg_float(
		config, "scaling", "game_object_scale", mobile_game_object_scale
	)
	mobile_collectible_scale = _cfg_float(
		config, "scaling", "collectible_scale", mobile_collectible_scale
	)

	# Minimum sizes
	mobile_button_min_size = _cfg_vector2(
		config, "sizes", "button_min_size", mobile_button_min_size
	)
	mobile_touch_target_min_size = _cfg_vector2(
		config, "sizes", "touch_target_min_size", mobile_touch_target_min_size
	)

	# Spacing
	mobile_button_spacing_vertical = _cfg_float(
		config, "spacing", "button_vertical", mobile_button_spacing_vertical
	)
	mobile_button_spacing_horizontal = _cfg_float(
		config, "spacing", "button_horizontal", mobile_button_spacing_horizontal
	)
	mobile_safe_area_margin = _cfg_float(
		config, "spacing", "safe_area_margin", mobile_safe_area_margin
	)
	mobile_edge_dead_zone = _cfg_float(
		config, "spacing", "edge_dead_zone", mobile_edge_dead_zone
	)

	# Performance settings
	mobile_particle_reduction = _cfg_float(
		config, "performance", "particle_reduction", mobile_particle_reduction
	)
	mobile_max_tweens = _cfg_int(config, "performance", "max_tweens", mobile_max_tweens)
	mobile_target_fps = _cfg_int(config, "performance", "target_fps", mobile_target_fps)

	# Gameplay adjustments
	mobile_game_speed_reduction = _cfg_float(
		config, "gameplay", "speed_reduction", mobile_game_speed_reduction
	)
	mobile_timing_window_increase = _cfg_float(
		config, "gameplay", "timing_window_increase", mobile_timing_window_increase
	)
	mobile_spawn_rate_reduction = _cfg_float(
		config, "gameplay", "spawn_rate_reduction", mobile_spawn_rate_reduction
	)
	mobile_drag_smoothing_increase = _cfg_float(
		config, "gameplay", "drag_smoothing_increase", mobile_drag_smoothing_increase
	)

	print("📱 Loaded mobile UI config from %s" % path)
	return true


func _reject_cfg(section: String, key: String, value: Variant, expected: String) -> void:
	push_warning("📱 mobile UI config \"%s/%s\" is %s, expected %s — keeping %s"
		% [section, key, type_string(typeof(value)), expected, "the default"])


func _cfg_float(config: ConfigFile, section: String, key: String, fallback: float) -> float:
	var value: Variant = config.get_value(section, key, fallback)
	if value is float or value is int:
		return float(value)
	_reject_cfg(section, key, value, "a number")
	return fallback


func _cfg_int(config: ConfigFile, section: String, key: String, fallback: int) -> int:
	var value: Variant = config.get_value(section, key, fallback)
	if value is int:
		return value
	if value is float:
		return int(value)
	_reject_cfg(section, key, value, "a number")
	return fallback


func _cfg_vector2(config: ConfigFile, section: String, key: String,
		fallback: Vector2) -> Vector2:
	var value: Variant = config.get_value(section, key, fallback)
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	_reject_cfg(section, key, value, "a Vector2")
	return fallback

func save_config_file(path: String) -> bool:
	# Save current configuration to file
	var config = ConfigFile.new()
	
	# Save scaling factors
	config.set_value("scaling", "ui_scale", mobile_ui_scale)
	config.set_value("scaling", "font_scale", mobile_font_scale)
	config.set_value("scaling", "game_object_scale", mobile_game_object_scale)
	config.set_value("scaling", "collectible_scale", mobile_collectible_scale)
	
	# Save minimum sizes
	config.set_value("sizes", "button_min_size", mobile_button_min_size)
	config.set_value("sizes", "touch_target_min_size", mobile_touch_target_min_size)
	
	# Save spacing
	config.set_value("spacing", "button_vertical", mobile_button_spacing_vertical)
	config.set_value("spacing", "button_horizontal", mobile_button_spacing_horizontal)
	config.set_value("spacing", "safe_area_margin", mobile_safe_area_margin)
	config.set_value("spacing", "edge_dead_zone", mobile_edge_dead_zone)
	
	# Save performance settings
	config.set_value("performance", "particle_reduction", mobile_particle_reduction)
	config.set_value("performance", "max_tweens", mobile_max_tweens)
	config.set_value("performance", "target_fps", mobile_target_fps)
	
	# Save gameplay adjustments
	config.set_value("gameplay", "speed_reduction", mobile_game_speed_reduction)
	config.set_value("gameplay", "timing_window_increase", mobile_timing_window_increase)
	config.set_value("gameplay", "spawn_rate_reduction", mobile_spawn_rate_reduction)
	config.set_value("gameplay", "drag_smoothing_increase", mobile_drag_smoothing_increase)
	
	var err = config.save(path)
	if err != OK:
		push_error("Failed to save mobile UI config to %s: %s" % [path, error_string(err)])
		return false
	
	print("📱 Saved mobile UI config to %s" % path)
	return true

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# EVENT HANDLERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_viewport_size_changed() -> void:
	# The stretch ratio just changed, so the dp-derived touch floor has too.
	_button_min_cache_valid = false
	var old_is_mobile := is_mobile
	var old_is_portrait := is_portrait

	var vp_size := get_viewport().get_visible_rect().size
	var new_width := int(vp_size.x)
	var new_height := int(vp_size.y)

	# ── Keyboard detection: FALLBACK path only ───────────────────
	# A host that resizes its window for the soft keyboard shrinks it vertically with the
	# width unchanged, so a height-only shrink means "keyboard". That is the whole of what
	# detection used to be, and it never fired in the shipped build: this game runs
	# fullscreen/immersive, where Android draws the keyboard OVER the window instead of
	# resizing it. keyboard_height therefore stayed 0 forever and _apply_keyboard_inset()
	# was never called — the reported "keyboard completely covers the Enter Host IP
	# Address field with no way to scroll". _poll_virtual_keyboard() asks Android directly
	# and is the authority; this branch is kept for a windowed/resizing host and steps
	# aside the moment the poll has produced a height.
	var width_unchanged := (new_width == viewport_width or viewport_width == 0)
	var height_shrank := new_height < viewport_height and viewport_height > 0

	if _keyboard_height_from_displayserver:
		# DisplayServer owns keyboard_height now; just keep the baseline current.
		if new_height >= _natural_viewport_height:
			_natural_viewport_height = new_height
	elif width_unchanged and height_shrank and new_height < _natural_viewport_height:
		# Keyboard appeared: compute how tall it is
		apply_keyboard_height(_natural_viewport_height - new_height)
	elif new_height >= _natural_viewport_height and keyboard_height > 0:
		# Keyboard dismissed: restore
		apply_keyboard_height(0)
		_natural_viewport_height = new_height  # Refresh baseline (e.g. after rotation)
	else:
		# Genuine orientation / resize — update natural baseline
		if new_height >= _natural_viewport_height:
			_natural_viewport_height = new_height

	viewport_width = new_width
	viewport_height = new_height

	_detect_platform()
	_enforce_landscape_orientation()
	_detect_orientation()
	if _should_force_landscape():
		is_portrait = false
	_calculate_safe_area()
	_apply_mobile_performance_profile()

	if old_is_mobile != is_mobile:
		mobile_mode_changed.emit(is_mobile)

	if old_is_portrait != is_portrait:
		orientation_changed.emit(is_portrait)
		_log_debug("Orientation changed to: %s" % ("Portrait" if is_portrait else "Landscape"))

	if _debug_overlay:
		_destroy_debug_overlay()
		_create_debug_overlay()

	call_deferred("_adapt_current_scene")

	print(
		"📱 Viewport size changed: %dx%d (%s)"
		% [
			viewport_width,
			viewport_height,
			"Portrait" if is_portrait else "Landscape",
		]
	)

## Read the keyboard's height from Android rather than inferring it from a window resize.
##
## THE DEFECT: keyboard detection lived only in _on_viewport_size_changed(), which reads a
## height-only viewport shrink as "keyboard shown". A fullscreen/immersive Android window
## is not resized when the soft keyboard slides up — the keyboard is drawn over it — so
## size_changed never fired for a keyboard, keyboard_height stayed 0, and the inset that
## exists to lift the focused field was never applied. That is exactly the reported
## "keyboard covers the Enter Host IP Address input and there is no scroll".
##
## DisplayServer.virtual_keyboard_get_height() asks the Android side for the real height
## and is correct whether or not the window resized, which is why it is the authority.
##
## Costs nothing when it cannot matter: with no text field focused and no inset applied
## the first comparison returns, so ordinary gameplay frames never reach the poll or the
## DisplayServer call. (Assumption: only LineEdit and TextEdit raise the soft keyboard —
## true of every text entry in this project.)
func _poll_virtual_keyboard(delta: float) -> void:
	var vp := get_viewport()
	if not vp:
		return
	var focused := vp.gui_get_focus_owner()
	var text_focused: bool = focused is LineEdit or focused is TextEdit
	if not text_focused and keyboard_height <= 0:
		_keyboard_poll_timer = 0.0
		return
	_keyboard_poll_timer += delta
	if _keyboard_poll_timer < KEYBOARD_POLL_INTERVAL:
		return
	_keyboard_poll_timer = 0.0
	var reported_px: int = DisplayServer.virtual_keyboard_get_height()
	if reported_px > 0:
		_keyboard_height_from_displayserver = true
	apply_keyboard_height(screen_px_to_viewport_units(reported_px))


## DisplayServer reports the keyboard in real screen pixels, while every layout property
## the inset writes is in viewport units. Under stretch/mode="canvas_items" with a
## 1920x1080 base those are 1:1 only on a device whose height is exactly 1080 — which both
## test phones are (2160x1080 and 2400x1080), so an unconverted value would have measured
## correct here and been half again too small on a 1440x720 handset.
func screen_px_to_viewport_units(px: int) -> int:
	if px <= 0:
		return 0
	var win := get_window()
	var vp := get_viewport()
	if not win or not vp or win.size.y <= 0:
		return px
	var vp_h: float = vp.get_visible_rect().size.y
	return int(round(float(px) * vp_h / float(win.size.y)))


## "The keyboard is now N viewport units tall": record it, inset the scene, tell listeners.
##
## The single place that decides what a keyboard height means. Both the DisplayServer poll
## and the window-resize fallback route through here, so there is one write to
## keyboard_height instead of two; harnesses drive it directly to check the layout response
## without an Android keyboard to raise.
func apply_keyboard_height(height: int) -> void:
	var clamped: int = maxi(height, 0)
	if clamped == keyboard_height:
		return
	keyboard_height = clamped
	_apply_keyboard_inset(keyboard_height)
	keyboard_visibility_changed.emit(keyboard_height)
	if keyboard_height > 0:
		print("⌨️ Keyboard shown, height: %d px" % keyboard_height)
	else:
		print("⌨️ Keyboard hidden")


## Apply a bottom inset to the current scene's root Control so the
## content is pushed above the keyboard.  A height of 0 removes it.
##
## The inset is ADDED to whatever bottom offset the scene already had rather than replacing
## it. adapt_scene_for_mobile() warns about two systems writing one property; the safe-area
## pass writes offset_bottom absolutely, so an inset that assumed a base of 0 would drop
## the safe-area reserve the moment the keyboard closed. The base is captured once, into
## node meta, so a second apply cannot stack on its own output either.
func _apply_keyboard_inset(height: int) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	# Find the outermost Control or CanvasLayer>Control in the scene
	var root_ctrl: Control = _find_root_control(scene)
	if not root_ctrl:
		return
	if root_ctrl is MarginContainer:
		var base_margin: float = _keyboard_inset_base(
			root_ctrl, float(root_ctrl.get_theme_constant("margin_bottom"))
		)
		root_ctrl.add_theme_constant_override("margin_bottom", int(base_margin) + height)
	else:
		# For full-rect anchored controls, shrink the bottom anchor offset
		var base_offset: float = _keyboard_inset_base(root_ctrl, root_ctrl.offset_bottom)
		root_ctrl.offset_bottom = base_offset - float(height)
	if height <= 0 and root_ctrl.has_meta(KEYBOARD_INSET_BASE_META):
		# Base released on the way out so the next keyboard re-reads it. A safe-area
		# recalculation between two keyboard appearances (rotation) then lands correctly
		# instead of restoring an offset that is one layout out of date.
		root_ctrl.remove_meta(KEYBOARD_INSET_BASE_META)


## The bottom offset the scene owns with no keyboard up. Captured on the first inset and
## reused until the keyboard closes, so repeated applies are idempotent.
func _keyboard_inset_base(ctrl: Control, current: float) -> float:
	if not ctrl.has_meta(KEYBOARD_INSET_BASE_META):
		ctrl.set_meta(KEYBOARD_INSET_BASE_META, current)
	return float(ctrl.get_meta(KEYBOARD_INSET_BASE_META))

## Walk down the scene to find the first Control child of the root Node.
func _find_root_control(scene: Node) -> Control:
	if scene is Control:
		return scene as Control
	for child in scene.get_children():
		if child is Control:
			return child as Control
	return null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# FRAME RATE MONITORING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _monitor_frame_rate(delta: float) -> void:
	# Monitor FPS and log warnings when performance drops below target
	#
	# 	Tracks FPS using Engine.get_frames_per_second() and logs warnings
	# 	when FPS drops below 30 on mobile. Samples FPS every second.
	_fps_sample_timer += delta
	
	if _fps_sample_timer >= _fps_sample_interval:
		var current_fps = Engine.get_frames_per_second()
		_fps_samples.append(current_fps)
		
		# Keep only last 5 samples
		if _fps_samples.size() > 5:
			_fps_samples.remove_at(0)
		
		# Calculate average FPS
		var avg_fps = 0.0
		for fps in _fps_samples:
			avg_fps += fps
		avg_fps /= _fps_samples.size()
		
		# Log warning if FPS drops below target
		if avg_fps < mobile_target_fps and not _low_fps_warning_shown:
			push_warning("📱 Low FPS detected: %.1f (target: %d)" % [avg_fps, mobile_target_fps])
			_low_fps_warning_shown = true
		elif avg_fps >= mobile_target_fps:
			_low_fps_warning_shown = false
		
		_fps_sample_timer = 0.0

func get_current_fps() -> float:
	# Get the current frames per second
	#
	# 	@return: Current FPS from Engine
	return Engine.get_frames_per_second()

func get_average_fps() -> float:
	# Get the average FPS from recent samples
	#
	# 	@return: Average FPS over last 5 seconds, or 0 if no samples
	if _fps_samples.is_empty():
		return 0.0
	
	var sum = 0.0
	for fps in _fps_samples:
		sum += fps
	return sum / _fps_samples.size()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BACKGROUND CPU REDUCTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_app_focus_lost() -> void:
	# Handle app going to background
	#
	# 	Pauses all animations, reduces process priority, and disables
	# 	unnecessary updates to conserve battery and CPU.
	if not is_mobile:
		return
	
	_is_in_background = true
	_refresh_process_state()
	
	# Take the pause only if the game is not already paused on purpose, and record
	# that we took it so the resume stays symmetric. See _paused_by_background.
	if not get_tree().paused:
		get_tree().paused = true
		_paused_by_background = true
	
	# Disable screen keep-on when in background
	DisplayServer.screen_set_keep_on(false)
	
	print("📱 App went to background - pausing updates")

func _on_app_focus_gained() -> void:
	# Handle app returning to foreground
	#
	# 	Resumes all animations and normal processing.
	if not is_mobile:
		return
	
	_is_in_background = false
	_refresh_process_state()
	
	# Lift only our own pause. A pause menu, a network pause or a game-over screen
	# that was already up when the app went to background stays up.
	if _paused_by_background:
		_paused_by_background = false
		get_tree().paused = false
	
	# Re-enable screen keep-on when returning to foreground
	DisplayServer.screen_set_keep_on(true)
	
	print("📱 App returned to foreground - resuming updates")

func is_in_background() -> bool:
	# Check if app is currently in background
	#
	# 	@return: True if app is in background
	return _is_in_background

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEBUG VISUALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func enable_debug_visualization(enabled: bool) -> void:
	# Enable or disable debug visualization overlay
	#
	# 	Shows safe area boundaries as colored rectangles when enabled.
	#
	# 	@param enabled: True to show debug overlay
	debug_visualization_enabled = enabled
	
	if enabled and not _debug_overlay:
		_create_debug_overlay()
	elif not enabled and _debug_overlay:
		_destroy_debug_overlay()

func _create_debug_overlay() -> void:
	# Create debug overlay showing safe area boundaries
	if _debug_overlay:
		return
	
	_debug_overlay = CanvasLayer.new()
	_debug_overlay.name = "_MobileDebugOverlay"
	_debug_overlay.layer = 100  # On top of everything
	add_child(_debug_overlay)
	
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Top margin (red)
	var top_rect = ColorRect.new()
	top_rect.color = Color(1, 0, 0, 0.3)
	top_rect.position = Vector2(0, 0)
	top_rect.size = Vector2(viewport_size.x, safe_area_margins.get("top", 0))
	_debug_overlay.add_child(top_rect)
	
	# Bottom margin (green)
	var bottom_rect = ColorRect.new()
	bottom_rect.color = Color(0, 1, 0, 0.3)
	var bottom_margin = safe_area_margins.get("bottom", 0)
	bottom_rect.position = Vector2(0, viewport_size.y - bottom_margin)
	bottom_rect.size = Vector2(viewport_size.x, bottom_margin)
	_debug_overlay.add_child(bottom_rect)
	
	# Left margin (blue)
	var left_rect = ColorRect.new()
	left_rect.color = Color(0, 0, 1, 0.3)
	left_rect.position = Vector2(0, 0)
	left_rect.size = Vector2(safe_area_margins.get("left", 0), viewport_size.y)
	_debug_overlay.add_child(left_rect)
	
	# Right margin (yellow)
	var right_rect = ColorRect.new()
	right_rect.color = Color(1, 1, 0, 0.3)
	var right_margin = safe_area_margins.get("right", 0)
	right_rect.position = Vector2(viewport_size.x - right_margin, 0)
	right_rect.size = Vector2(right_margin, viewport_size.y)
	_debug_overlay.add_child(right_rect)
	
	# Info label
	var info_label = Label.new()
	info_label.text = "Safe Area Debug (Red=Top, Green=Bottom, Blue=Left, Yellow=Right)"
	info_label.position = Vector2(10, 10)
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.add_theme_color_override("font_color", Color.WHITE)
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	info_label.add_theme_constant_override("outline_size", 2)
	_debug_overlay.add_child(info_label)
	
	print("📱 Debug visualization enabled")

func _destroy_debug_overlay() -> void:
	# Remove debug overlay
	if _debug_overlay:
		_debug_overlay.queue_free()
		_debug_overlay = null
		print("📱 Debug visualization disabled")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEBUG LOGGING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func enable_debug_logging(enabled: bool) -> void:
	# Enable or disable debug logging for scaling operations
	#
	# 	Logs all scaling operations, layout reorganization, and performance metrics.
	#
	# 	@param enabled: True to enable debug logging
	debug_logging_enabled = enabled
	print("📱 Debug logging: %s" % ("enabled" if enabled else "disabled"))

func _log_debug(message: String) -> void:
	# Log debug message if debug logging is enabled
	if debug_logging_enabled:
		print("📱 [DEBUG] " + message)
