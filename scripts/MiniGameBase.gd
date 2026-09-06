class_name MiniGameBase
extends Node2D

## ═══════════════════════════════════════════════════════════════════
## MINI-GAME BASE CLASS
## Template for all water conservation mini-games
## Handles difficulty scaling, performance tracking, and chaos effects
## ═══════════════════════════════════════════════════════════════════

signal game_started()
signal game_completed(accuracy: float, time: int, mistakes: int)
signal game_failed()

## Game Settings
@export var game_name: String = "MiniGame"
@export var game_duration: float = 30.0  # Default duration in seconds

## Game Mode: "quota" = must complete target before time, "survival" = survive until timer ends
@export var game_mode: String = "quota"

## UI Visibility Options
@export var show_timer: bool = true
@export var show_quota: bool = true
@export var timer_starts_paused: bool = false  # For games that start timer after setup

## Performance Tracking
var game_start_time: int = 0

## Milliseconds this round has spent frozen, and when the current freeze began (0 when
## running). Subtracted by elapsed_play_seconds(); see there for what they are for.
var _paused_ms_total: int = 0
var _pause_began_ms: int = 0
var mistakes_made: int = 0
var correct_actions: int = 0
var total_actions: int = 0

## Per-action response latencies, in milliseconds, for the round in progress.
##
## The thesis defines the Consistency Penalty over "individual reaction times".
## The value that used to be fed to it was the ROUND DURATION - see end_game(),
## which sends int(elapsed_play_seconds() * 1000). Round duration is dominated by
## which minigame was drawn, not by the player: measured over the 594 real
## single-player rounds in user://session_logs, 71% of its variance is between
## games rather than within them, and the per-game medians span 1.4 s
## (Turn Off Tap) to 25 s (Filter Builder). Feeding that to CP made sigma a
## measure of the shuffle. These samples are the per-action latency instead,
## which is what "reaction time" denotes and is comparable across games.
var action_latencies_ms: PackedInt32Array = PackedInt32Array()
var _last_action_ms: int = 0
var game_active: bool = false
var timer_running: bool = false  # True when timer has actually started

## True once end_game() has run for the current round.
##
## end_game() is the single most consequential function in a round: it deducts a
## life, banks droplets and score, and feeds one performance sample into the
## adaptive-difficulty rolling window. It must therefore run exactly once, and
## `game_active` alone cannot guarantee that — it is cleared at the top of
## end_game(), but a coroutine parked on an `await` from BEFORE that point resumes
## afterwards and re-checks nothing.
##
## Reproduced in ThirstyPlant: a wrong tap parks on `await create_timer(1.0)` and
## then calls end_game(false) unconditionally. If the round timer expires inside
## that second, _on_timeout() ends the round first and the parked coroutine ends it
## again — two lives lost for one round and a DUPLICATE sample in the Φ window.
## _water_plant() is worse: it can bank a win over a round that already timed out.
##
## 47 call sites across 27 minigames end their own rounds, so the invariant belongs
## here rather than as a re-check bolted onto each of them. First call wins, which
## is the correct resolution: whatever genuinely ended the round happened first.
var _round_ended: bool = false
## Has this scene already begun leaving? See _on_exit_pressed(): the QUIT button is
## not disabled when pressed and its tally screen takes seconds, so a repeat tap has
## to be refused outright rather than merely skip the recording.
var _quitting: bool = false
var lives: int = 3
## Short outcome line of the most recently finished round (e.g. "Water leak
## fixed — no more noise."), used by the quit tally instead of a generic
## "SESSION ENDED" title. Set every time a round score page is shown.
var _last_round_outcome_text: String = ""
var current_score: int = 0
var combo_streak: int = 0
var max_combo: int = 0
var game_instruction_text: String = "TAP TO START!"

## Difficulty Settings (from AdaptiveDifficulty)
var difficulty_settings: Dictionary = {}
var current_difficulty: String = "Medium"

## Chaos Effects
var chaos_effects_active: Array = []

## Audio Timer
var _last_tick_second: int = -1

## Timer-UI change detection — the label shows tenths and the fill has 3 colour
## bands, so we only touch the UI when one of these actually changes. Keeps
## String allocation and theme lookups out of the per-frame path.
var _last_timer_tenths: int = -1
var _last_timer_band: int = -1
## Whole-second cache for the countdown number. Separate from _last_timer_tenths
## because the bar and the number now refresh at different rates (10 Hz vs 1 Hz).
var _last_timer_second: int = -1

## Internal timer reference (so we can stop it in end_game)
var _game_timer: Timer

## Mistake time penalty — seconds deducted per wrong action.
## Set after difficulty is loaded; scales Easy → Medium → Hard.
var mistake_time_penalty: float = 3.0
var _time_penalty_total: float = 0.0

## ── FAIL MODE: what actually ends a round that is going badly ───────────────
##
## "clock"    the timer decides. Mistakes shorten it (_apply_sp_time_penalty).
##            The original behaviour, and still the default.
## "attempts" a budget of wrong answers decides. The clock keeps running as an
##            anti-hang ceiling but no longer fails the round.
##
## Why this exists: the tier tables give the HARDER tiers LESS time (Easy 20 /
## Medium 15 / Hard 10 in AdaptiveDifficulty.DIFFICULTY_SETTINGS), and
## get_difficulty_settings() divides that again by the progressive ramp, down to
## a 3 s floor. For a reflex game that is exactly the point. For a think-first
## game — trace this path accurately, remember where the pair was — it made the
## round unwinnable rather than hard: the player knew the answer and lost to the
## clock while producing it. Those games call use_attempt_budget() so their
## Medium/Hard rounds end on wrong tries instead of on seconds.
##
## Set only through use_attempt_budget(); read freely.
var fail_mode: String = "clock"
## Wrong actions allowed this round, and how many remain. 0/0 in clock mode.
var attempts_max: int = 0
var attempts_left: int = 0
## The tier's authored round length, before the attempts ceiling overwrote
## game_duration. Kept because the win payout's speed bonus is calibrated
## against the authored length, not against an anti-hang ceiling.
var _nominal_duration: float = 0.0


## Chaos effect timer references (stopped on game end to prevent leaks)
var _chaos_timers: Array[Timer] = []

## Screen-shake bookkeeping.
##
## _shake_base_origin remembers the viewport canvas_transform origin from before a
## cameraless shake started, so it can be put back exactly. The root viewport
## SURVIVES scene changes, so a displacement left behind here would carry into the
## next minigame as a permanently off-centre view — hence the restore in both
## end_game() and _exit_tree().
var _shake_base_origin: Vector2 = Vector2.ZERO
var _shake_active: bool = false

## Control reverse flag — child classes check this to invert input
var controls_reversed: bool = false

## UI References
var timer_label: Label
var attempts_label: Label
var score_label: Label
var combo_label: Label
var mistakes_label: Label
var hud_layer: CanvasLayer
var timer_bar: ProgressBar
var pause_menu: Control
## Ref to the HUD pause toggle so it can be hidden once the round ends.
var pause_button_ref: Button
var pause_button: Button
var instruction_overlay: Control
var animated_cutscene_player: SimpleCutscenePlayer  # Simple animated cutscene system
var _instruction_overlay_tweens: Array[Tween] = []

## ── Minimalist HUD palette ────────────────────────────────────────────────
## One flat ink colour at two weights, plus two accents. Defined here rather
## than inline so every screen that wants to match the in-game HUD reads the
## same four constants instead of re-picking approximate values.
## The legacy HUD strip. MicrogameShell draws its own DWTD bar over this one and
## repoints score_label/combo_label at its own nodes, so it needs a handle to the
## row it is replacing: buried-but-visible text still rasterises under the shell
## layer and still costs a draw.
var hud_top_row: HBoxContainer

const HUD_BAR_HEIGHT: float = 6.0
const HUD_INK: Color = Color(0.13, 0.15, 0.18)
const HUD_INK_SOFT: Color = Color(0.13, 0.15, 0.18, 0.85)
const HUD_GREEN: Color = Color(0.29, 0.78, 0.44)
const HUD_AMBER: Color = Color(0.98, 0.75, 0.18)
const HUD_RED: Color = Color(0.93, 0.29, 0.26)
## Combo/streak accent. Dark enough to survive the pale halo every HUD label gets.
##
## Was Color(0.95, 0.5, 0.16) - a bright orange, which is fine against art but not
## against HUD_TEXT_HALO. VisualSweepHard measured the "x%d" combo badge at 2.35:1 in
## CloudCatcher, 2.43:1 in SpotTheSpeck and 2.42:1 in WringItOut, all against an
## effective background luminance of 0.876 (the halo, not the backdrop), where WCAG AA
## asks 4.5:1 at this 22px size. Every other HUD label passes because it is near-black
## ink on that same halo; the combo badge was the only warm one. This burnt orange has
## relative luminance 0.135, i.e. 5.0:1 on the measured halo and 5.7:1 on pure white,
## and still reads as "streak" next to HUD_AMBER and HUD_RED rather than as ink.
const HUD_COMBO: Color = Color(0.68, 0.28, 0.04)

## Halo drawn around HUD text. Pale and mostly opaque so dark ink stays legible
## over dark art without turning the HUD into a set of boxes. Every HUD control
## gets one, the pause glyph included: at 0.55 alpha the soft ink measured
## 2.55:1 - 4.49:1 against the pale minigame backdrops, under the 4.5:1 floor,
## and the un-haloed pause button was the worst of them.
const HUD_TEXT_HALO: Color = Color(1.0, 1.0, 1.0, 0.85)
const HUD_TEXT_HALO_SIZE: int = 4

## Theme visuals (kid-friendly palette per minigame)
var _theme_layer: CanvasLayer
var _theme_primary_rect: ColorRect
var _theme_secondary_rect: ColorRect
var _theme_wash_rect: ColorRect
var _active_game_theme: Dictionary = {}

## "Dumb Ways to Die"-style cutscenes: a full cause clip before the round and
## a win/lose consequence clip after it, acted out by CartoonActor.
## Set false on a subclass to keep the old emoji outros for that game.
var use_cartoon_cutscenes: bool = true

## Below this average FPS the cutscenes play compressed rather than at full
## length (see _get_cartoon_speed).
const LOW_END_FPS_THRESHOLD: float = 27.0

## Ceiling on how long the round-advance chain will wait for an outro clip to
## report itself finished. Authored beat clips run about 2-3 seconds even at the
## slowest speed_scale, so this only fires when a clip is genuinely broken or was
## freed mid-play — and it fires instead of parking the round permanently.
const BEAT_OUTRO_TIMEOUT_SEC: float = 8.0

func _loc(key: String, fallback: String) -> String:
	# Optional lookup: many result/flavour lines only exist for some minigames,
	# so a miss is normal and must not warn. has_text() answers without going
	# through get_text()'s push_warning path.
	if Localization and Localization.has_text(key):
		return Localization.get_text(key)
	return fallback

func _ready() -> void:
	# Difficulty is resolved BEFORE the frame wait, and this ordering is load-bearing.
	#
	# Subclasses call super._ready() partway through their own _ready() and then keep
	# building their board. Because this function is a coroutine, super._ready()
	# returns to them at the first `await` — so anything the base does after that
	# await happens a whole frame LATER than the rest of the subclass's _ready().
	#
	# _apply_difficulty_settings() used to sit after the await, which meant every
	# subclass that read a difficulty-tuned value while building its board got the
	# member initializer instead of the difficulty value. Measured cases:
	#   • VegetableBath built 5 veggies for a quota of 3 (verified: washed=5/3,
	#     total_actions=5, score inflated 35→65, two rejected end_game(true) calls,
	#     and the inflated score fed AdaptiveDifficulty as S=0.882).
	#   • PlugTheLeak laid out `num_pipes` pipes from the default, not the difficulty.
	#   • MudPieMaker drew the gauge's target band from default target_min/target_max,
	#     so the visible target was not the band being graded.
	#   • FilterBuilder built its solution guides from the default
	#     show_solution_guide, ignoring the visual_guidance output of the algorithm.
	#   • 14 more games printed a stale "0 / N" quota on their score label.
	#
	# The frame wait still guards _setup_ui() — that is what needs a settled
	# viewport — and the chaos effects are queued rather than spawned so they land
	# after the board exists. See _apply_difficulty_settings().
	if GameManager:
		lives = GameManager.session_lives

	_load_difficulty_settings()
	_apply_difficulty_settings()

	await get_tree().process_frame

	_setup_ui()
	_activate_pending_chaos_effects()
	_apply_minigame_theme_visuals()
	call_deferred("_refresh_minigame_theme_visuals")
	_setup_animated_cutscene_player()  # Initialize animated cutscene system
	_create_instruction_overlay()
	
	# Register with AutoPlayManager so it can drive SP gameplay
	if AutoPlayManager and AutoPlayManager.is_auto_play_enabled():
		# Identity, not the display title. game_name reaches HANDLERS and
		# _determine_strategy, and FixLeakV2 builds its title from Localization, so
		# under Filipino the bot registered "Ayusin ang Tagas", matched nothing, and
		# drove the game with the random-button fallback instead of its own ai.
		# See GameManager.complete_minigame() for the same distinction.
		AutoPlayManager.register_game(self, _get_minigame_key())

	# First play of a game with an authored tutorial gets the tutorial popup in
	# place of the one-line instruction overlay — not in addition to it, so there
	# is still exactly one thing to dismiss. _wait_for_input() polls global input
	# state rather than events, so the same tap that presses the popup's START
	# button also ends the wait and nothing can strand the player behind it.
	var first_play_tutorial: Control = _show_first_play_tutorial()
	# Show instruction overlay, wait for tap to start
	instruction_overlay.visible = first_play_tutorial == null
	# Scoped to the round: normally superseded by the gameplay track a moment later, so
	# the scoped stop is a no-op - it matters when the scene is destroyed while the
	# player is still sitting at the tap-to-start prompt.
	_play_scoped_music("instruction", 0.25, self)
	await _wait_for_input()
	# _wait_for_input() has two exits: the player tapped, or this node left the tree
	# while the prompt was still up - quit to menu, the app being backgrounded, a
	# harness tearing the scene down. Only the first of those means "start the round".
	# Resuming blind started a round on a DETACHED node: _start_timer() adds a Timer
	# whose parent is outside the tree and calls start() on it, which is the "Unable to
	# start the timer because it is not inside the scene tree" error - 69 of them in one
	# VerifyFairness run, about one per game instantiated - and it left game_active true
	# with game_started emitted on a node that was about to be freed.
	if not is_inside_tree():
		return
	if first_play_tutorial != null and is_instance_valid(first_play_tutorial):
		first_play_tutorial.queue_free()
	_hide_instruction_overlay()
	
	# Start game
	start_game()


func _refresh_minigame_theme_visuals() -> void:
	_apply_minigame_theme_visuals()


func _apply_minigame_theme_visuals() -> void:
	var theme = _resolve_minigame_theme()
	_active_game_theme = theme
	_ensure_theme_layer()
	_apply_theme_layer_colors(theme)
	_tint_existing_background_nodes(theme)

	var theme_id = "default"
	if ThemeManager and ThemeManager.has_method("get_minigame_theme_id_for_name"):
		theme_id = ThemeManager.get_minigame_theme_id_for_name(_build_theme_lookup_text())

	print("🎨 Minigame theme applied: %s (%s)" % [game_name, theme_id])


func _resolve_minigame_theme() -> Dictionary:
	if ThemeManager and ThemeManager.has_method("get_minigame_theme_for_name"):
		return ThemeManager.get_minigame_theme_for_name(_build_theme_lookup_text())

	return {
		"bg_primary": Color(0.73, 0.90, 0.99, 1.0),
		"bg_secondary": Color(0.56, 0.79, 0.95, 1.0),
		"bg_wash": Color(0.86, 0.95, 1.0, 0.32),
		"scene_blend": 0.24,
	}


func _build_theme_lookup_text() -> String:
	var parts: Array[String] = []
	if not game_name.strip_edges().is_empty():
		parts.append(game_name)

	if not scene_file_path.is_empty():
		parts.append(scene_file_path.get_file().get_basename())

	if GameManager:
		var pending_name = str(GameManager.pending_next_minigame_name)
		if not pending_name.is_empty():
			parts.append(pending_name)

	if parts.is_empty():
		return "MiniGame"
	return " ".join(parts)


func _ensure_theme_layer() -> void:
	if _theme_layer and is_instance_valid(_theme_layer):
		return

	_theme_layer = CanvasLayer.new()
	_theme_layer.name = "_ThemeLayer"
	_theme_layer.layer = -120
	add_child(_theme_layer)

	_theme_primary_rect = ColorRect.new()
	_theme_primary_rect.name = "PrimaryBackdrop"
	_theme_primary_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_theme_primary_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_theme_layer.add_child(_theme_primary_rect)

	_theme_secondary_rect = ColorRect.new()
	_theme_secondary_rect.name = "SecondaryGlow"
	_theme_secondary_rect.anchor_left = 0.0
	_theme_secondary_rect.anchor_top = 0.42
	_theme_secondary_rect.anchor_right = 1.0
	_theme_secondary_rect.anchor_bottom = 1.0
	_theme_secondary_rect.offset_left = 0.0
	_theme_secondary_rect.offset_top = 0.0
	_theme_secondary_rect.offset_right = 0.0
	_theme_secondary_rect.offset_bottom = 0.0
	_theme_secondary_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_theme_layer.add_child(_theme_secondary_rect)

	_theme_wash_rect = ColorRect.new()
	_theme_wash_rect.name = "TopWash"
	_theme_wash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_theme_wash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_theme_layer.add_child(_theme_wash_rect)


func _apply_theme_layer_colors(theme: Dictionary) -> void:
	if not _theme_primary_rect:
		return

	var primary = theme.get("bg_primary", Color(0.73, 0.90, 0.99, 1.0))
	var secondary = theme.get("bg_secondary", Color(0.56, 0.79, 0.95, 1.0))
	var wash = theme.get("bg_wash", Color(0.86, 0.95, 1.0, 0.32))

	_theme_primary_rect.color = primary

	var secondary_tint = secondary
	secondary_tint.a = 0.33
	_theme_secondary_rect.color = secondary_tint

	_theme_wash_rect.color = wash
	RenderingServer.set_default_clear_color(primary)


func _tint_existing_background_nodes(theme: Dictionary) -> void:
	var blend_strength = clamp(float(theme.get("scene_blend", 0.24)), 0.0, 0.45)
	_tint_background_nodes_recursive(self, theme, blend_strength)


func _tint_background_nodes_recursive(node: Node, theme: Dictionary, blend_strength: float) -> void:
	for child in node.get_children():
		if child == _theme_layer or child == hud_layer:
			continue

		if child is ColorRect:
			_tint_background_rect(child as ColorRect, theme, blend_strength)

		_tint_background_nodes_recursive(child, theme, blend_strength)


func _tint_background_rect(rect: ColorRect, theme: Dictionary, blend_strength: float) -> void:
	if not rect or not _is_theme_background_rect(rect):
		return

	var base_color: Color
	if rect.has_meta("_theme_base_color"):
		base_color = rect.get_meta("_theme_base_color")
	else:
		base_color = rect.color
		rect.set_meta("_theme_base_color", base_color)

	var target = _pick_theme_target_for_rect(rect, theme)
	var themed_color = base_color.lerp(target, blend_strength)
	themed_color.a = base_color.a
	rect.color = themed_color


func _is_theme_background_rect(rect: ColorRect) -> bool:
	if not rect:
		return false

	var lower_name = rect.name.to_lower()
	if (
		lower_name.contains("background")
		or lower_name == "bg"
		or lower_name.contains("ground")
		or lower_name.contains("sky")
		or lower_name.contains("wall")
		or lower_name.contains("counter")
	):
		return true

	if rect.z_index <= -1:
		return true

	var vp = get_viewport_rect().size
	if vp != Vector2.ZERO:
		if rect.size.x >= vp.x * 0.75 and rect.size.y >= vp.y * 0.5:
			return true

	return false


func _pick_theme_target_for_rect(rect: ColorRect, theme: Dictionary) -> Color:
	var lower_name = rect.name.to_lower()
	if (
		lower_name.contains("ground")
		or lower_name.contains("counter")
		or lower_name.contains("wall")
	):
		return theme.get("bg_secondary", theme.get("bg_primary", rect.color))

	if (
		lower_name.contains("sky")
		or lower_name.contains("background")
		or lower_name == "bg"
	):
		return theme.get("bg_primary", rect.color)

	return theme.get("bg_secondary", theme.get("bg_primary", rect.color))

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DIFFICULTY MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _load_difficulty_settings() -> void:
	# Check if we're in multiplayer mode
	var is_multiplayer = (
		GameManager
		and GameManager.current_game_mode == GameManager.GameMode.MULTIPLAYER_COOP
	)
	
	if is_multiplayer and CoopAdaptation:
		# Multiplayer: Use CoopAdaptation for per-player difficulty
		var my_player_num = GameManager.local_player_num if GameManager else 1
		current_difficulty = CoopAdaptation.get_player_difficulty(my_player_num)
		difficulty_settings = CoopAdaptation.get_difficulty_params(my_player_num)
		chaos_effects_active = difficulty_settings.get("chaos_effects", [])
		
		print("🎮 [MP] %s | P%d: %s" % [game_name, my_player_num, current_difficulty])
	elif AdaptiveDifficulty:
		# ────────────────────────────────────────────────────────────────────────
		# Single-player: Use AdaptiveDifficulty (Φ = WMA - CP algorithm)
		# ────────────────────────────────────────────────────────────────────────
		# ELI5: When a minigame starts, it asks AdaptiveDifficulty:
		#       "What difficulty should I use for this player?"
		#
		# AdaptiveDifficulty looks at the current_difficulty (Easy/Medium/Hard)
		# which was calculated by the Rolling Window Algorithm, and returns
		# the appropriate settings:
		#
		# Easy:   speed_multiplier = 0.7,  time_limit = 20s, chaos_effects = []
		# Medium: speed_multiplier = 1.0,  time_limit = 15s, chaos_effects = [shake]
		# Hard:   speed_multiplier = 1.5,  time_limit = 10s, chaos_effects = [shake, mud, fly]
		#
		# The minigame then uses these settings to adjust gameplay!
		# ────────────────────────────────────────────────────────────────────────
		difficulty_settings = AdaptiveDifficulty.get_difficulty_settings()
		current_difficulty = AdaptiveDifficulty.get_current_difficulty()
		chaos_effects_active = difficulty_settings.get("chaos_effects", [])
		
		print("🎮 %s | Difficulty: %s" % [game_name, current_difficulty])
	else:
		# Fallback defaults when no difficulty system is available
		difficulty_settings = {
			"speed_multiplier": 1.0,
			"time_limit": 15,
			"chaos_effects": [],
			"task_complexity": 1,
			"item_count": 3,
			"distractors": 0,
			"progressive_level": 0,
			"progression_bonus": 0
		}
		current_difficulty = "Medium"
		print("🎮 %s | Difficulty: %s (fallback)" % [game_name, current_difficulty])
	# Always set penalty after current_difficulty is resolved.
	#
	# NOTE: this is a provisional value only. _penalty_for_difficulty() scales
	# with game_duration, and at this point game_duration is still the class
	# default — subclasses set the real one in _apply_difficulty_settings(),
	# which runs *after* this. _start_timer() recomputes it once the duration is
	# final; see the comment there.
	mistake_time_penalty = _penalty_for_difficulty(current_difficulty)

func _apply_difficulty_settings() -> void:
	# Override this in child classes to apply specific settings
	# Example: adjust spawn rates, timer speeds, etc.

	# Apply speed multiplier to game duration
	if difficulty_settings.has("time_limit"):
		game_duration = difficulty_settings["time_limit"]

	# Chaos effects are QUEUED here, not activated.
	#
	# This function runs before the subclass has built its board (see the ordering
	# note in _ready()), and the chaos effects add children, read
	# get_viewport().canvas_transform and spawn timers — a splatter created now
	# would sit behind every node the subclass adds afterwards. _ready() drains the
	# queue once the board and the HUD exist.
	#
	# Subclasses call super() from their own override, so the queue is refilled on
	# every re-apply; clearing it first keeps a second call from doubling the
	# effects.
	_pending_chaos_effects.clear()
	for effect in chaos_effects_active:
		_pending_chaos_effects.append(effect)


## Chaos effects selected by the algorithm but not yet instantiated.
var _pending_chaos_effects: Array = []


## Instantiate the queued chaos effects. Called from _ready() after the board and
## HUD exist, and safe to call again — the queue is emptied as it is drained.
func _activate_pending_chaos_effects() -> void:
	if _pending_chaos_effects.is_empty():
		return
	var effects: Array = _pending_chaos_effects.duplicate()
	_pending_chaos_effects.clear()
	for effect in effects:
		_activate_chaos_effect(effect)

## Round-length multiplier applied when a tier switches to the attempt budget,
## and the floor under it. The clock stops being the opponent, but it must still
## exist: a phone left on the minigame screen would otherwise hold an unfinished
## round forever, with the gameplay music and the pause state still live.
const ATTEMPT_CEILING_SCALE: float = 4.0
const ATTEMPT_CEILING_MIN_SEC: float = 45.0
## Seconds of ceiling left at which the hidden clock reappears, so running out of
## it is never a surprise.
const ATTEMPT_CEILING_WARN_SEC: float = 10.0


## Make this tier end on wrong tries instead of on the clock.
##
## Call at the END of a subclass's _apply_difficulty_settings(), after the tier
## table has set game_duration — this reads that value to size the ceiling.
##
## Pass 0 for a tier that should stay clock-based. Easy normally does: it is
## where a player learns that mistakes cost something, and a forgiving 20 s clock
## with a 12% mistake penalty is not the tier anyone loses unfairly.
##
## Refused in survival mode, where surviving the clock IS the win — replacing the
## clock there would delete the win condition, not soften a loss.
func use_attempt_budget(easy: int, medium: int, hard: int) -> void:
	if game_mode == "survival":
		push_warning(
			"%s: use_attempt_budget() ignored — survival rounds are won BY the clock"
			% game_name
		)
		return
	var budget: int = 0
	match current_difficulty:
		"Easy":   budget = easy
		"Medium": budget = medium
		"Hard":   budget = hard
		_:        budget = medium
	if budget <= 0:
		fail_mode = "clock"
		attempts_max = 0
		attempts_left = 0
		return
	fail_mode = "attempts"
	attempts_max = budget
	attempts_left = budget
	_nominal_duration = game_duration
	game_duration = maxf(ATTEMPT_CEILING_MIN_SEC, game_duration * ATTEMPT_CEILING_SCALE)
	# _setup_ui() has not run yet (see the ordering note in _ready()), so the bar and
	# the labels do not exist to hide from here. show_timer IS the lever: _setup_ui()
	# and start_timer_now() both honour it.
	show_timer = false
	print("🎯 %s | %s: %d tries, no clock pressure (ceiling %.0fs)" % [
		game_name, current_difficulty, budget, game_duration
	])


## The tier's authored round length in seconds — game_duration in clock mode, the
## pre-ceiling value in attempts mode.
func nominal_round_seconds() -> float:
	if fail_mode == "attempts" and _nominal_duration > 0.0:
		return _nominal_duration
	return game_duration


## Spend one try. Returns true when that was the last one.
func _consume_attempt() -> bool:
	attempts_left = maxi(0, attempts_left - 1)
	_refresh_attempts_hud()
	return attempts_left <= 0


## Paint the tries readout. No-op before _setup_ui() has built it.
func _refresh_attempts_hud() -> void:
	if attempts_label == null or not is_instance_valid(attempts_label):
		return
	if fail_mode != "attempts":
		attempts_label.visible = false
		return
	attempts_label.visible = true
	attempts_label.text = _loc("hud_tries_short", "TRIES %d") % attempts_left
	attempts_label.add_theme_color_override(
		"font_color", HUD_RED if attempts_left <= 1 else HUD_INK
	)


## Point the HUD at whichever thing is actually deciding this round.
##
## Called at the end of the HUD build. In attempts mode the big seconds number is
## meaningless — it counts down an anti-hang ceiling — so it is hidden and the
## tries readout takes its slot. _process() reveals it again inside the warn
## window.
func _apply_fail_mode_hud() -> void:
	var attempts := fail_mode == "attempts"
	if timer_label:
		timer_label.visible = not attempts
	if timer_bar:
		timer_bar.visible = show_timer and not attempts
	_refresh_attempts_hud()


func _penalty_for_difficulty(diff: String) -> float:
	## Seconds deducted per mistake, as a FRACTION of the round length.
	##
	## This used to return flat seconds: Easy 3, Medium 6, Hard 10. That is
	## unplayable, because round length shrinks as difficulty rises while the
	## penalty grows. Measured against the shipped tables:
	##
	##   Hard   penalty 10 s  vs  8 s rounds (TurnOffTap, TimingTap, ToiletTankFix,
	##                            QuickShower, ThirstyPlant, WringItOut, CatchTheRain)
	##   → one single mistake drove effective_time_left below zero on the same
	##     frame, so the round was lost before the player could react. A human
	##     cannot clear a quota with a zero-mistake requirement at that speed.
	##
	## Scaling by duration keeps the *intent* (harder = costlier mistakes) while
	## guaranteeing a round always survives several errors:
	##   Easy   12% of the clock  → ~8 mistakes before timeout
	##   Medium 18%               → ~5 mistakes
	##   Hard   25%               → 4 mistakes
	##
	## Clamped to [1.0, 6.0] s so very long rounds don't hand out 7 s penalties
	## and very short ones still cost something noticeable.
	var fraction: float = 0.18
	match diff:
		"Easy":   fraction = 0.12
		"Medium": fraction = 0.18
		"Hard":   fraction = 0.25
		_:        fraction = 0.18
	return clampf(game_duration * fraction, 1.0, 6.0)

func _apply_sp_time_penalty() -> void:
	## Deduct mistake_time_penalty from the SP timer and show a visual flash.
	if not game_active or not timer_running:
		return

	# ── Survival mode must NOT be clock-penalised ──────────────────────────
	# In survival mode _on_timeout() calls end_game(true): running the clock
	# down IS the win condition. Subtracting time for a mistake therefore
	# *rewarded* the mistake — a Hard 10 s round could be won by taking one
	# hit. Survival games express failure through their own rules (e.g.
	# WaterPlant drowning the plant), so a mistake here only costs accuracy
	# and combo, never seconds.
	if game_mode == "survival":
		return

	# ── Attempt-based rounds must NOT be clock-penalised ───────────────────
	# The mistake already cost a try in record_action(). Charging seconds as well
	# would double-bill it, and the clock in this mode is only an anti-hang
	# ceiling — draining it is not the feedback the player should be reading.
	if fail_mode == "attempts":
		return

	_time_penalty_total += mistake_time_penalty
	print("💔 [%s] Mistake! -%ds (total: %.0fs)" % [game_name, int(mistake_time_penalty), _time_penalty_total])
	if timer_bar:
		var tw := create_tween()
		tw.tween_property(timer_bar, "modulate", Color(2.0, 0.3, 0.3), 0.12)
		tw.tween_property(timer_bar, "modulate", Color.WHITE, 0.18)
	if timer_label:
		# Don't write the penalty into timer_label: _process() owns that text and
		# rewrites it whenever the whole second changes. The penalty moves the
		# clock by at least a second, so the "-3s" was overwritten on the very
		# next frame and read as a one-frame flicker. Instead force the cache to
		# repaint so the reduced number appears at once — the bar flash above is
		# what communicates "you lost time".
		_last_timer_second = -1
		_last_timer_tenths = -1

func get_difficulty_multiplier(setting_name: String, default_value: float = 1.0) -> float:
	return difficulty_settings.get(setting_name, default_value)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME FLOW
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func start_game() -> void:
	game_active = true
	_round_ended = false
	_quitting = false
	# Baseline for the first action latency of the round.
	_last_action_ms = 0
	action_latencies_ms.clear()
	# Refill the try budget, so a shell that replays a round in place (rather than
	# reloading the scene and re-running _apply_difficulty_settings) starts fresh.
	if attempts_max > 0:
		attempts_left = attempts_max
		_refresh_attempts_hud()
	game_started.emit()
	
	# Play game start sound and gameplay music
	if AudioManager:
		AudioManager.play_game_start()
	# Scoped to the round. end_game() still stops this track itself with its own 0.5s
	# fade (:664) and that is deliberate presentation, so the scoped stop is a no-op on
	# the normal path - it only fires when the scene dies without end_game() ever
	# running, which used to leave current_music='gameplay' playing over the hub.
	_play_scoped_music("gameplay", 0.5, self)
	
	# Start game timer (unless paused for setup phase)
	if not timer_starts_paused:
		game_start_time = Time.get_ticks_msec()
		_paused_ms_total = 0
		_pause_began_ms = 0
		timer_running = true
		reset_timer_label_cache()
		_start_timer()
	
	# Override this in child classes for specific game logic
	_on_game_start()

## Call this from child class when ready to start the timer
func start_timer_now() -> void:
	game_start_time = Time.get_ticks_msec()
	_paused_ms_total = 0
	_pause_began_ms = 0
	timer_running = true
	reset_timer_label_cache()
	_start_timer()
	
	# Show timer if it was hidden during setup
	if timer_bar:
		timer_bar.visible = show_timer

func end_game(success: bool = true) -> void:
	# Exactly once per round — see _round_ended. Warned rather than silently
	# dropped so a genuine double-end still shows up in soak logs instead of
	# being hidden by the guard that makes it harmless.
	if _round_ended:
		push_warning(
			"%s: end_game(%s) ignored — round already ended" % [game_name, success]
		)
		return
	_round_ended = true

	game_active = false
	timer_running = false
	_hide_instruction_overlay()
	get_tree().paused = false
	# The round is over: kill the pause affordance so it can't appear over
	# the scoring/tally screens.
	if pause_button_ref and is_instance_valid(pause_button_ref):
		pause_button_ref.visible = false
	var shell_btn: Button = get("shell_pause_button")
	if shell_btn and is_instance_valid(shell_btn):
		shell_btn.visible = false

	# Unregister from AutoPlay so nav logic takes over for the outro
	if AutoPlayManager and AutoPlayManager.is_auto_play_enabled():
		AutoPlayManager.unregister_game()

	# Stop the game timer so it can't double-trigger
	if _game_timer and is_instance_valid(_game_timer):
		_game_timer.stop()
	
	# Stop all chaos effect timers to prevent memory leaks
	for t in _chaos_timers:
		if is_instance_valid(t):
			t.stop()
			t.queue_free()
	_chaos_timers.clear()
	_clear_screen_shake()
	controls_reversed = false
	
	# Stop gameplay music
	if AudioManager:
		AudioManager.stop_music(0.5)
	
	# Deduct life if game failed
	if not success:
		_deduct_life()
	
	# Paused seconds excluded: an interruption used to inflate the reaction time fed
	# to the algorithm, making an interrupted player look slower than they were.
	var reaction_time = int(elapsed_play_seconds() * 1000.0)
	# Two different quantities, deliberately kept apart:
	#   reaction_time  - how long the ROUND took. Drives the speed bonus below and
	#                    the session clock, both of which are about the round.
	#   algo_reaction  - the player's RESPONSE latency, which is what the thesis's
	#                    Consistency Penalty is defined over. See
	#                    representative_reaction_time_ms().
	var algo_reaction = representative_reaction_time_ms()
	var accuracy = _report_accuracy(success)
	
	# Always send performance data to algorithm (success or fail)
	if GameManager:
		var droplets_earned = 0
		# Game Lab rounds pay nothing: droplets are spendable currency, so a
		# sandbox win would be a real reward for a round that never happened.
		if success and not GameManager.sandbox_mode:
			# Tuned-down economy (playtest rework): a win pays at most 7
			# droplets instead of the old 20, so shop prices (100-500) keep
			# meaning something for dozens of rounds. Losses pay nothing.
			droplets_earned = 3 # Base reward
			if accuracy > 0.9: droplets_earned += 2 # Perfect bonus
			# nominal_round_seconds(), not game_duration: an attempts-mode round
			# replaces game_duration with a 4x anti-hang ceiling, which would have
			# handed out the speed bonus unconditionally. The bonus is calibrated
			# against the tier's authored length, so that is what it compares to.
			if reaction_time < nominal_round_seconds() * 1000.0:
				droplets_earned += 2 # Speed bonus

			if SaveManager and SaveManager.has_method("add_droplets"):
				SaveManager.add_droplets(droplets_earned)
				if SaveManager.has_method("save_all_data"):
					SaveManager.save_all_data()
				if SaveManager.has_method("get_droplets"):
					GameManager.water_droplets = int(SaveManager.get_droplets())
			else:
				GameManager.water_droplets += droplets_earned

			if GameManager.has_method("add_session_droplets"):
				GameManager.add_session_droplets(droplets_earned)
		
		# Win-only session points (playtest rework): a lost round contributes
		# nothing to session_score, the SP leaderboard, or per-game high
		# scores. The in-round tally still shows current_score for context;
		# it simply never banks.
		var banked_score: int = current_score if success else 0
		if success and banked_score <= 0:
			# GUARANTEED WIN PAYOUT: some games end without feeding points
			# through record_action (timer wins, cutscene-triggered wins),
			# which used to bank 0 even on a win. Fall back to the same
			# accuracy-based formula GameManager uses so a win always pays.
			banked_score = maxi(10, int(accuracy * 100.0) - mistakes_made * 10)

		# Always complete minigame (records performance for algorithm)
		GameManager.complete_minigame(
			game_name,
			accuracy,
			algo_reaction,
			mistakes_made,
			banked_score,
			max_combo,
			success,
			# Identity, not the display title: see GameManager.complete_minigame.
			_get_minigame_key()
		)

	# Outcome presentation. With cartoon cutscenes on, the CartoonStage clip in
	# _show_tally_screen IS the outcome beat, so the older micro-cutscene is
	# skipped to avoid showing two consecutive win/lose screens.
	if not use_cartoon_cutscenes:
		if success:
			await _show_success_micro_cutscene()
		else:
			await _show_failure_micro_cutscene()

	game_completed.emit(accuracy, reaction_time, mistakes_made)

	# Show tally screen with score
	await _show_tally_screen(success, accuracy, reaction_time)
	await _show_round_score_page(success, accuracy, reaction_time)

	# Continue to next game — but only if this minigame is still the live scene.
	#
	# The two awaits above span several seconds of presentation, and the player can
	# quit to the menu inside that window. Advancing unconditionally here would
	# then pull them straight back out of the menu into the next round, because
	# GameManager is an autoload and start_next_minigame() works perfectly well
	# from a node that has already been detached.
	if not is_inside_tree():
		return

	if GameManager:
		GameManager.start_next_minigame()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

func _calculate_accuracy() -> float:
	if total_actions == 0:
		return 0.0
	return float(correct_actions) / float(total_actions)

## Fraction of the round's objective the player actually completed (0.0–1.0).
##
## Override in a minigame that has a countable quota so a partially-completed
## loss earns partial credit. The default is the paper's binary A ("1 for
## success, 0 for failure").
func _get_objective_progress(success: bool) -> float:
	return 1.0 if success else 0.0

## The accuracy value reported to AdaptiveDifficulty as the paper's A term.
##
## _calculate_accuracy() alone answers "of the actions you took, how many were
## correct" — which is the right signal for combo/streak feedback but the wrong
## one for the algorithm. A player who caught 2 of the 8 droplets a round
## required, all of them cleanly, scored A = 1.00 on a LOSS: a soak log showed
## `Score:0 | Acc:100%` producing S = 0.698 for a failed round, so failing
## pushed difficulty UP. Conversely a round won on the timer without any
## record_action() call reported A = 0.00 on a WIN.
##
## Weighting action-correctness by objective completion fixes both directions
## and is correct under either reading of the paper (which states A is binary
## success, yet whose worked example feeds the window fractional accuracies).
## Wins are unchanged: the default progress on success is 1.0.
func _report_accuracy(success: bool) -> float:
	var objective: float = clampf(_get_objective_progress(success), 0.0, 1.0)
	if total_actions <= 0:
		# Nothing discrete to grade (timer-resolved or cutscene-triggered
		# rounds): objective completion IS the accuracy signal.
		return objective
	return clampf(_calculate_accuracy() * objective, 0.0, 1.0)

## The round's representative reaction time, in milliseconds, for the thesis's
## Consistency Penalty.
##
## CP is defined over "individual reaction times". When the round graded discrete
## actions, the median per-action latency is that quantity, and it is comparable
## across minigames of very different lengths. Median rather than mean because a
## single mid-round hesitation (a player looking away) must not masquerade as a
## slow player.
##
## Rounds with nothing discrete to grade - timer-resolved and cutscene-resolved
## games - have no per-action latency to report, so they fall back to the round
## duration, which is exactly what every round used to send. The fallback is
## reported, not silent: report_reaction_time_source() names which was used, and
## SessionLogger records it per round.
func representative_reaction_time_ms() -> int:
	var n: int = action_latencies_ms.size()
	if n == 0:
		return int(elapsed_play_seconds() * 1000.0)
	var sorted_ms: Array[int] = []
	for v in action_latencies_ms:
		sorted_ms.append(int(v))
	sorted_ms.sort()
	if n % 2 == 1:
		return sorted_ms[n / 2]
	return int(round((sorted_ms[n / 2 - 1] + sorted_ms[n / 2]) / 2.0))


## "per_action" when the value above came from measured action latencies,
## "round_duration" when the round had no graded actions to measure.
func report_reaction_time_source() -> String:
	return "per_action" if action_latencies_ms.size() > 0 else "round_duration"


func record_action(is_correct: bool) -> void:
	total_actions += 1

	# Time since the previous graded action (or since the round started, for the
	# first). Paused seconds are already excluded because elapsed_play_seconds()
	# discounts them; using it here keeps a pause from being recorded as one very
	# slow response.
	var now_ms: int = int(elapsed_play_seconds() * 1000.0)
	var gap_ms: int = now_ms - _last_action_ms
	_last_action_ms = now_ms
	if gap_ms > 0:
		action_latencies_ms.append(gap_ms)

	
	if is_correct:
		combo_streak += 1
		max_combo = max(max_combo, combo_streak)
		correct_actions += 1
		var combo_bonus = int(floor(float(combo_streak) / 3.0)) * 5
		current_score += 10 + combo_bonus
		if score_label:
			score_label.text = str(current_score)
		if combo_label:
			combo_label.text = "x%d" % combo_streak
			combo_label.visible = combo_streak >= 2
		# Audio: correct action + combo milestone
		if AudioManager:
			AudioManager.play_collect()
			if combo_streak > 0 and combo_streak % 3 == 0:
				AudioManager.play_combo()
		_on_correct_action()
	else:
		combo_streak = 0
		mistakes_made += 1
		if combo_label:
			combo_label.text = "x0"
			combo_label.visible = false
		# Audio: mistake
		if AudioManager:
			AudioManager.play_damage()
		
		# Deduct time penalty scaled by difficulty. This call already owns the
		# timer_bar "modulate" flash — see _apply_sp_time_penalty().
		#
		# A second Tween used to be created here animating the SAME
		# timer_bar:modulate property. When two Tweens fight over one property
		# the later one forcibly wins, so the flashes clobbered each other and
		# could leave the bar tinted red. It also wrote timer_bar.position:x,
		# which a Control inside a container does not own — the container
		# overwrites it on the next layout pass, so the "shake" read as jitter.
		# Both are gone; the flash now lives in exactly one place.
		# Clock rounds pay in seconds, attempt rounds pay in tries. Exactly one of
		# these does anything: _apply_sp_time_penalty() returns early in attempts
		# mode, and _consume_attempt() is only reached in it.
		var out_of_attempts := false
		if fail_mode == "attempts":
			out_of_attempts = _consume_attempt()
		else:
			_apply_sp_time_penalty()

		# Subclass feedback first: it flashes and resets the board, and several games
		# end the round from here themselves. Ending above this line would cut the
		# feedback for the very mistake that lost the round.
		_on_mistake()

		# The budget is spent. _on_mistake() may already have ended the round (or
		# quit the scene), hence the game_active re-check rather than trusting the
		# state we saw before calling it.
		if out_of_attempts and game_active:
			print("🎯 [%s] Out of tries (%d used)" % [game_name, attempts_max])
			game_failed.emit()
			end_game(false)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TIMER MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _start_timer() -> void:
	# Recompute the mistake penalty now that game_duration is final.
	# _load_difficulty_settings() runs before the subclass's
	# _apply_difficulty_settings(), so the value computed there was based on the
	# default duration. This is the last point before the clock starts.
	mistake_time_penalty = _penalty_for_difficulty(current_difficulty)

	# The bar's range is set from game_duration, which subclasses only finalise
	# in _apply_difficulty_settings() — after _setup_ui() built the bar. Without
	# this, a 10 s round kept a max_value of 25 and the bar started 60% drained.
	if timer_bar:
		timer_bar.max_value = game_duration
		timer_bar.value = game_duration

	if _game_timer:
		_game_timer.stop()
		_game_timer.queue_free()
	_game_timer = Timer.new()
	_game_timer.wait_time = game_duration
	_game_timer.one_shot = true
	_game_timer.timeout.connect(_on_timer_timeout)
	add_child(_game_timer)
	_game_timer.start()

func _on_timer_timeout() -> void:
	if game_active:
		# Survival mode: timer runs out = SUCCESS (you survived!)
		# Quota mode: timer runs out = FAIL (didn't meet target)
		if game_mode == "survival":
			end_game(true)
		elif fail_mode == "attempts":
			# Not a clock loss: this is use_attempt_budget()'s anti-hang ceiling,
			# which only a round nobody is playing can reach. Logged distinctly so
			# a soak can tell it apart from a real timeout.
			print("🎯 [%s] Anti-hang ceiling reached, %d tries still unspent" % [
				game_name, attempts_left
			])
			end_game(false)
		else:
			end_game(false)
## Seconds this round has actually been PLAYED, with time spent paused removed.
##
## The single source of truth for round time. Four places used to compute
## "(Time.get_ticks_msec() - game_start_time) / 1000.0" independently:
## _process() at the timeout check, get_remaining_time(), and the reaction_time fed
## to the algorithm from both end_game() and _on_exit_pressed(). Time.get_ticks_msec()
## is WALL CLOCK, so every one of them counted time the game was frozen.
##
## What that cost, measured by tools/VerifyPauseClock.tscn before this existed:
##   - a 2s pause took 2.02s off the round;
##   - the HUD read 12.93s while _game_timer - the Timer node that actually ends the
##     round, and which DOES stop when the tree pauses - held 14.94s, a 2.01s
##     disagreement between the number shown and the number enforced;
##   - a 6s interruption on a 4s round ended the round as a FAILURE on the first
##     frame after resume and spent a life, 3 -> 2, before the player could touch
##     anything.
##
## The third one is the serious one, because on Android the pause is not a menu the
## player chose: MobileUIManager._on_app_focus_lost() sets get_tree().paused = true
## when the app is backgrounded (autoload/MobileUIManager.gd:1339). An incoming call
## or a pulled-down notification failed the round.
##
## Paused time is accounted rather than the clock being switched to accumulated
## delta, so games that hold the timer through a setup phase keep the reaction_time
## semantics they already had - the only thing that changes is that frozen seconds
## no longer count.
func elapsed_play_seconds() -> float:
	var paused_ms: int = _paused_ms_total
	if _pause_began_ms > 0:
		# Called while still paused: include the pause in progress, otherwise the
		# value jumps the moment the tree resumes.
		paused_ms += Time.get_ticks_msec() - _pause_began_ms
	return float(Time.get_ticks_msec() - game_start_time - paused_ms) / 1000.0


## Paused-time bookkeeping.
##
## NOTIFICATION_PAUSED / NOTIFICATION_UNPAUSED are delivered when this node's own
## processing stops and restarts, which is precisely the interval elapsed_play_seconds()
## has to discount - it covers the pause menu, the network pause and the Android
## background pause identically, without any of them having to know about this.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		if _pause_began_ms == 0:
			_pause_began_ms = Time.get_ticks_msec()
	elif what == NOTIFICATION_UNPAUSED:
		if _pause_began_ms > 0:
			_paused_ms_total += Time.get_ticks_msec() - _pause_began_ms
			_pause_began_ms = 0




# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MUSIC OWNERSHIP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Start a music track and pair its stop with `scope`'s lifetime.
##
## Every music start in this file is a promise to stop it, and the destination screens
## do not cover for it. AudioManager.music_player is a child of the AudioManager
## AUTOLOAD (autoload/AudioManager.gd:116-119), so freeing a scene does not silence
## anything - a track is only ended by an explicit stop_music() or superseded by a
## later play_music(). Of the screens a round can exit to, only MainMenu ("menu", :53)
## and FinalScore ("results", :88) start a track of their own; InitialScreen - the hub
## GameManager.return_to_main_menu() actually loads - starts none, and neither do
## MultiplayerLobby, MultiplayerMenu, Settings, UnlockablesScreen or RoadmapScreen. A
## track nobody stopped just keeps playing over them.
##
## Writing the stop on a later line of the same coroutine does NOT discharge that
## promise, because the coroutine can be abandoned. create_tween() binds its tween to
## this node; freeing the node kills the tween; a killed tween never emits `finished`,
## so `await fade_out.finished` never resumes and everything below it is dead code for
## that exit. tools/VerifyStrayAudio.tscn measured exactly that, in one run: with the
## quit tally's stop on its coroutine's last line, tearing the scene down while the
## tally was up left `current_music='scoring' playing=true` over InitialScreen, while
## the score page - whose stop was already bound to its page - came out silent.
##
## tree_exiting fires on every way out instead: the queue_free() at the natural end of
## the presentation, a quit, the roster advancing, the session ending. So the stop
## happens once per start without any of those paths having to know about it.
##
## `scope` is whichever node the track actually belongs to - the presentation page for
## a page's track, `self` for a track that belongs to the round as a whole (there is no
## per-call node to hang it on in the micro-cutscenes, which return early on the
## animated_cutscene_player path).
##
## The current_music guard is what makes overlapping scopes safe. Tracks supersede each
## other by design here - "instruction" gives way to "gameplay", "gameplay" to
## "scoring" - so by the time a scope exits, another track may legitimately own the
## player, including one started by the screen that is replacing this one. Stopping
## only while our own track is still the current one keeps a scope from silencing
## somebody else's music, and makes the order in which nested scopes exit irrelevant.
func _play_scoped_music(track: String, fade_in: float, scope: Node) -> void:
	if AudioManager == null or not is_instance_valid(AudioManager):
		return
	AudioManager.play_music(track, fade_in)
	if scope == null or not is_instance_valid(scope):
		return
	scope.tree_exiting.connect(func() -> void:
		if is_instance_valid(AudioManager) and AudioManager.current_music == track:
			AudioManager.stop_music(0.15))


func get_remaining_time() -> float:
	## Seconds left on the clock, mistake penalties included.
	##
	## This used to ignore _time_penalty_total, so it disagreed with both the
	## HUD number and the _process() timeout check — a game asking "how long do I
	## have?" got a more optimistic answer than the one that ends the round.
	var elapsed = elapsed_play_seconds()
	return max(0.0, game_duration - elapsed - _time_penalty_total)

## Clear the cached HUD values so the next frame repaints unconditionally.
##
## The timer UI only writes when the tenth / second / colour band changes. After
## a replay the cache still holds the previous round's values, so the first frame
## would skip the write and briefly show the old time. Called from start_game()
## and start_timer_now().
func reset_timer_label_cache() -> void:
	_last_timer_tenths = -1
	_last_timer_band = -1
	_last_timer_second = -1
	_last_tick_second = -1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CHAOS EFFECTS SYSTEM
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _activate_chaos_effect(effect_name: String) -> void:
	match effect_name:
		"screen_shake_mild":
			_start_screen_shake(0.5)
		"screen_shake_heavy":
			_start_screen_shake(1.0)
		"mud_splatters":
			_spawn_mud_splatters()
		"buzzing_fly":
			_spawn_buzzing_fly()
		"control_reverse":
			_activate_control_reverse()
		"visual_obstruction":
			_create_visual_obstruction()


func _is_screen_shake_allowed() -> bool:
	if AccessibilityManager and AccessibilityManager.has_method("is_screen_shake_enabled"):
		return AccessibilityManager.is_screen_shake_enabled()
	if SaveManager and SaveManager.has_method("is_screen_shake_enabled"):
		return SaveManager.is_screen_shake_enabled()
	return true

func _start_screen_shake(intensity: float) -> void:
	if not _is_screen_shake_allowed():
		return

	# Screen shake is the visible half of the thesis's chaos_effects output
	# ({NONE, MILD, STRONG} from the difficulty decision tree). It used to be gated
	# entirely behind `get_viewport().get_camera_2d()`, and no single-player minigame
	# scene owns a Camera2D — measured: 0 of the 25 scenes in scenes/minigames, the
	# last one (FixLeak) having had an inert camera that also broke MicrogameShell's
	# world==screen assumption. So on Hard the algorithm faithfully emitted
	# screen_shake_heavy and every single-player game silently displayed nothing at
	# all, with no warning to say so.
	#
	# The camera branch below is kept rather than deleted because it is the correct
	# driver wherever a camera does exist: an active Camera2D rewrites the viewport's
	# canvas_transform every frame, so displacing that transform directly would be
	# overwritten instantly. (All 12 multiplayer scenes do own one, though they run on
	# MultiplayerMiniGameBase, which extends Node2D and never reaches this code.)
	# Cameraless, offsetting canvas_transform.origin is the equivalent — it moves all
	# Node2D content and deliberately leaves the CanvasLayer HUD still, which keeps the
	# timer and score readable while the world shakes.
	var camera := get_viewport().get_camera_2d()
	if not _shake_active:
		_shake_active = true
		_shake_base_origin = get_viewport().canvas_transform.origin

	var shake_timer := Timer.new()
	shake_timer.wait_time = 0.05
	shake_timer.timeout.connect(func() -> void:
		if not game_active:
			_clear_screen_shake()
			return
		var amplitude := intensity * 5.0
		var jitter := Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude)
		)
		if camera and is_instance_valid(camera):
			camera.offset = jitter
		else:
			var vp := get_viewport()
			if vp:
				var xform := vp.canvas_transform
				xform.origin = _shake_base_origin + jitter
				vp.canvas_transform = xform
	)
	add_child(shake_timer)
	shake_timer.start()
	_chaos_timers.append(shake_timer)

func _clear_screen_shake() -> void:
	## Put the view back where the shake found it.
	##
	## The old code only reset camera.offset from inside the shake timer's own
	## callback, on the first tick after game_active went false — but end_game()
	## stops and frees those timers in the same breath as clearing game_active, so
	## that tick usually never arrived and a shaking round could end (and hand over
	## to the tally screen) still displaced.
	if not _shake_active:
		return
	_shake_active = false

	var vp := get_viewport()
	if vp == null:
		return
	var camera := vp.get_camera_2d()
	if camera and is_instance_valid(camera):
		camera.offset = Vector2.ZERO
	else:
		var xform := vp.canvas_transform
		xform.origin = _shake_base_origin
		vp.canvas_transform = xform

func _spawn_mud_splatters() -> void:
	# Create random mud splatter sprites
	var splatter_timer = Timer.new()
	splatter_timer.wait_time = 2.0
	splatter_timer.timeout.connect(_create_mud_splatter)
	add_child(splatter_timer)
	splatter_timer.start()
	_chaos_timers.append(splatter_timer)

func _create_mud_splatter() -> void:
	var splatter = ColorRect.new()
	splatter.color = Color(0.3, 0.2, 0.1, 0.7)
	# A ColorRect is a Control, and a Control's default mouse_filter is STOP, so an
	# 80px splatter dropped on top of the board swallowed every tap underneath it
	# for the six seconds it lived. Chaos is meant to distract, not to disable the
	# game - _create_visual_obstruction() below already got this right.
	splatter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splatter.size = Vector2(randf_range(30, 80), randf_range(30, 80))
	splatter.position = Vector2(
		randf_range(0, get_viewport_rect().size.x),
		randf_range(0, get_viewport_rect().size.y)
	)
	add_child(splatter)
	
	# Hold, then fade - on one node-bound tween rather than an awaited SceneTreeTimer.
	#
	# This used to `await get_tree().create_timer(5.0).timeout` before building the fade.
	# A SceneTreeTimer that has not run out is never resumed once the round is torn down,
	# so every splatter spawned in the last five seconds of a round stranded this
	# function state for the life of the process, and the timer went with it. A tween
	# created on this node is killed when the node is freed, and tween_interval expresses
	# the same five second hold with no coroutine at all.
	var tween = create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(splatter, "modulate:a", 0.0, 1.0)
	tween.tween_callback(splatter.queue_free)

func _spawn_buzzing_fly() -> void:
	# Create an annoying fly emoji that moves around
	var fly = Label.new()
	fly.text = "🐛"
	fly.add_theme_font_size_override("font_size", 40)
	# Same as the splatters: a Label is a Control, and this one is deliberately drawn
	# over everything (z_index 10) and moved onto a new part of the board every half
	# second. Left on STOP it was a roving dead zone.
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.z_index = 10
	fly.position = Vector2(
		randf_range(50, get_viewport_rect().size.x - 50),
		randf_range(50, get_viewport_rect().size.y - 50)
	)
	add_child(fly)
	
	var move_timer = Timer.new()
	move_timer.wait_time = 0.5
	move_timer.timeout.connect(func():
		if game_active:
			var target = Vector2(
				randf_range(50, get_viewport_rect().size.x - 50),
				randf_range(50, get_viewport_rect().size.y - 50)
			)
			var tween = create_tween()
			tween.tween_property(fly, "position", target, 0.5)
	)
	add_child(move_timer)
	move_timer.start()
	_chaos_timers.append(move_timer)

func _activate_control_reverse() -> void:
	# Set flag — child classes should check controls_reversed to invert input
	controls_reversed = true

func _create_visual_obstruction() -> void:
	# Create semi-transparent overlays
	var obstruction = ColorRect.new()
	obstruction.color = Color(0, 0, 0, 0.3)
	obstruction.size = get_viewport_rect().size
	obstruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(obstruction)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UI MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## The HUD's game-name label, kept so a language change can re-resolve it.
var _hud_name_label: Label = null

## Re-resolve the displayed title when the language changes mid-round.
##
## Every game assigns `game_name` once, in its own _ready() and mostly through
## Localization, so the title is correct for the language that was active when the
## round loaded and then frozen for the life of the scene.
##
## REACHABILITY, STATED PLAINLY: no surface inside a round can switch the language.
## The only toggle is the button in Settings.gd, and reaching Settings is a full scene
## change that rebuilds the game from scratch — so this is defence in depth, not a
## live player-visible bug. It is driven directly, by calling Localization from a
## harness while a round is on screen (tools/VerifyTitleRetitle.tscn).
##
## Rewriting `game_name` is safe: it is the display title, not identity. AutoPlayManager
## registers on _get_minigame_key() and GameManager.complete_minigame() keys on the same
## thing precisely because this string is language-dependent. The table is consulted
## first, so a game whose title is a plain literal with no row keeps its literal.
func _retitle_for_language(_new_language: String = "") -> void:
	if Localization == null or not is_instance_valid(_hud_name_label):
		return
	var key: String = _get_minigame_key().to_snake_case()
	if not Localization.has_text(key):
		return
	game_name = Localization.get_text(key)
	_hud_name_label.text = game_name.to_upper()
	# "TRIES 3" is a localized string too — repaint it, or it keeps the old
	# language until the next mistake happens to rewrite it.
	_refresh_attempts_hud()


func _setup_ui() -> void:
	# Create HUD Layer
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	# ══════════════════════════════════════════════════════════════════
	# MINIMALIST HUD — one bar, two numbers, nothing else
	# ══════════════════════════════════════════════════════════════════
	# Dumb Ways to Die's HUD is almost invisible: a bare timer bar pinned to the
	# screen edge and flat type. This used to be six rounded "pill" PanelContainers
	# with drop shadows, 2 px borders and four emoji glyphs used as icons
	# (⏱ ⭐ · 🔥). That chrome cost ~30 extra Control nodes, ate the top 90 px of a
	# phone screen, and the emoji rendered in whatever the platform font decided —
	# so the same HUD looked different on every device. Flat type in a fixed
	# palette is both cheaper and consistent.
	#
	# Layout, top to bottom, full-bleed with no outer margin:
	#   [==========timer bar==========]   6 px, flush to the very top edge
	#   GAME NAME              12  x3     one thin row of flat text
	#
	# Node contract kept intact for the 25 subclasses: timer_bar, timer_label,
	# score_label and combo_label are all still assigned here.

	# ── Timer bar: full width, pinned to the top edge ──────────────────
	# Outside any container so nothing can push it inward — a container would
	# also overwrite any position we tween on it.
	timer_bar = ProgressBar.new()
	timer_bar.show_percentage = false
	timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	timer_bar.custom_minimum_size = Vector2(0, HUD_BAR_HEIGHT)
	# No explicit `size` assignment: PRESET_TOP_WIDE uses non-equal opposite
	# horizontal anchors, so the layout server overrides any size set during
	# _ready() and Godot pushes a warning for every minigame that boots. The
	# anchors already stretch the bar full-width; custom_minimum_size supplies
	# the height.
	timer_bar.max_value = game_duration
	timer_bar.value = game_duration

	# Square corners, no border: the bar reads as part of the screen edge.
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.0, 0.0, 0.0, 0.16)
	timer_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = HUD_GREEN
	timer_bar.add_theme_stylebox_override("fill", bar_fill)

	timer_bar.visible = show_timer
	hud_layer.add_child(timer_bar)

	# ── Info row: name (left) · seconds + score + combo (right) ────────
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_top", int(HUD_BAR_HEIGHT) + 8)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	hud_layer.add_child(margin)

	var top_row := HBoxContainer.new()
	hud_top_row = top_row
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 14)
	margin.add_child(top_row)

	# -- Game name: quiet, lowercase-weight, never competes with gameplay --
	# Every HUD label gets a light outline. The ink colours are dark by design
	# (they read as pencil on the light minigame backdrops), but several
	# minigames use dark or high-contrast art, and without an outline the
	# left-side name and the score simply disappeared into the background.
	var hud_name_label = Label.new()
	hud_name_label.text = game_name.to_upper()
	_hud_name_label = hud_name_label
	if Localization and not Localization.language_changed.is_connected(_retitle_for_language):
		Localization.language_changed.connect(_retitle_for_language)
	hud_name_label.add_theme_font_size_override("font_size", 18)
	hud_name_label.add_theme_color_override("font_color", HUD_INK_SOFT)
	_apply_hud_label_contrast(hud_name_label)
	top_row.add_child(hud_name_label)

	var spacer = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	# -- Seconds: the only large number on screen --
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 30)
	timer_label.add_theme_color_override("font_color", HUD_INK)
	timer_label.text = "%.0f" % game_duration
	_apply_hud_label_contrast(timer_label)
	top_row.add_child(timer_label)

	# -- Tries: takes the seconds slot in attempts mode (see _apply_fail_mode_hud) --
	# Built unconditionally so a subclass can switch fail modes without the label
	# having to be created lazily from inside the hot path.
	attempts_label = Label.new()
	attempts_label.add_theme_font_size_override("font_size", 26)
	attempts_label.add_theme_color_override("font_color", HUD_INK)
	attempts_label.visible = false
	_apply_hud_label_contrast(attempts_label)
	top_row.add_child(attempts_label)

	# -- Score --
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 22)
	score_label.add_theme_color_override("font_color", HUD_INK_SOFT)
	score_label.text = "0"
	score_label.visible = show_quota
	_apply_hud_label_contrast(score_label)
	top_row.add_child(score_label)

	# -- Combo: hidden until it means something (streak >= 2) --
	combo_label = Label.new()
	combo_label.add_theme_font_size_override("font_size", 22)
	combo_label.add_theme_color_override("font_color", HUD_COMBO)
	combo_label.text = "x0"
	combo_label.visible = false
	_apply_hud_label_contrast(combo_label)
	top_row.add_child(combo_label)

	# -- Pause: flat glyph, no panel behind it --
	var pause_btn = Button.new()
	pause_button_ref = pause_btn
	pause_btn.text = "II"
	pause_btn.flat = true
	pause_btn.custom_minimum_size = Vector2(44, 44)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.add_theme_color_override("font_color", HUD_INK_SOFT)
	pause_btn.add_theme_color_override("font_pressed_color", HUD_INK)
	pause_btn.add_theme_color_override("font_hover_color", HUD_INK)
	_apply_hud_label_contrast(pause_btn)
	pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_btn.pressed.connect(_on_pause_pressed)
	pause_button = pause_btn  # ref used by MicrogameShell to bury this glyph
	top_row.add_child(pause_btn)

	# ── Progressive level: a bare "LVL 3", no pill ─────────────────────
	if AdaptiveDifficulty:
		var settings = AdaptiveDifficulty.get_difficulty_settings()
		var progressive_level = settings.get("progressive_level", 0)
		if progressive_level > 0:
			var prog_label = Label.new()
			prog_label.add_theme_font_size_override("font_size", 16)
			prog_label.add_theme_color_override("font_color", HUD_COMBO)
			prog_label.text = _loc("hud_level_short", "LVL %d") % progressive_level
			prog_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			prog_label.position = Vector2(
				get_viewport_rect().size.x - 90.0, HUD_BAR_HEIGHT + 46.0
			)
			prog_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_apply_hud_label_contrast(prog_label)
			hud_layer.add_child(prog_label)

	# Point the HUD at whatever is actually deciding this round. Last, because it
	# reads timer_bar / timer_label / attempts_label, all built above.
	_apply_fail_mode_hud()

	# Create Pause Menu (Hidden)
	_create_pause_menu()

## Adds a light halo behind HUD text so it survives dark backdrops.
##
## The HUD ink is intentionally near-black for a "pencil on paper" look, which
## works on the pale minigames but made the top-left game name and the score
## unreadable on the darker ones. A pale outline is cheaper than a panel and
## keeps the flat look, while guaranteeing contrast either way.
func _apply_hud_label_contrast(label: Control) -> void:
	label.add_theme_color_override("font_outline_color", HUD_TEXT_HALO)
	label.add_theme_constant_override("outline_size", HUD_TEXT_HALO_SIZE)

func _setup_animated_cutscene_player() -> void:
	# Initialize the SimpleCutscenePlayer for win/fail cutscenes
	animated_cutscene_player = SimpleCutscenePlayer.new()
	animated_cutscene_player.visible = false
	animated_cutscene_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	animated_cutscene_player.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(animated_cutscene_player)

func _create_instruction_overlay():
	if instruction_overlay and is_instance_valid(instruction_overlay):
		instruction_overlay.queue_free()
	_stop_instruction_overlay_tweens()

	instruction_overlay = Control.new()
	instruction_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	instruction_overlay.visible = false
	instruction_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	instruction_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_layer.add_child(instruction_overlay)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction_overlay.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	instruction_overlay.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.custom_minimum_size.x = min(
		get_viewport_rect().size.x * 0.85, 900.0
	)
	center.add_child(vbox)

	# Game name with gentle pulse animation
	var name_label = Label.new()
	name_label.text = game_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 48)
	name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 10)
	vbox.add_child(name_label)

	# Gentle pulse (no scale bounce — avoids overflow)
	var bounce = create_tween().set_loops()
	_instruction_overlay_tweens.append(bounce)
	bounce.tween_property(
		name_label, "modulate",
		Color(1.2, 1.1, 0.6), 0.6
	).set_trans(Tween.TRANS_SINE)
	bounce.tween_property(
		name_label, "modulate",
		Color.WHITE, 0.6
	).set_trans(Tween.TRANS_SINE)

	# Atmospheric intro narrative (game-specific flavor text)
	var _intro_text: String = _narrative(_get_minigame_key(), "intro")
	if not _intro_text.is_empty():
		var intro_label := Label.new()
		intro_label.text = _intro_text
		intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intro_label.add_theme_font_size_override("font_size", 22)
		intro_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0, 0.88))
		intro_label.add_theme_color_override("font_outline_color", Color.BLACK)
		intro_label.add_theme_constant_override("outline_size", 4)
		vbox.add_child(intro_label)

	# Instruction
	var instruction_label = Label.new()
	instruction_label.text = game_instruction_text
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_font_size_override("font_size", 32)
	instruction_label.add_theme_color_override("font_color", Color.WHITE)
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	instruction_label.add_theme_constant_override("outline_size", 6)
	vbox.add_child(instruction_label)
	
	# Tap to start (blinking)
	var tap_label = Label.new()
	tap_label.text = _loc("tap_to_start", "TAP ANYWHERE TO START")
	tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_label.add_theme_font_size_override("font_size", 26)
	tap_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	tap_label.add_theme_color_override("font_outline_color", Color.BLACK)
	tap_label.add_theme_constant_override("outline_size", 4)
	tap_label.name = "TapLabel"
	vbox.add_child(tap_label)
	
	# Blinking animation
	var tween = create_tween().set_loops()
	_instruction_overlay_tweens.append(tween)
	tween.tween_property(tap_label, "modulate:a", 0.3, 0.5)
	tween.tween_property(tap_label, "modulate:a", 1.0, 0.5)

func _wait_for_input() -> void:
	# AutoPlay bypass — skip the "tap to start" wait automatically
	#
	# Frame-polled rather than `await get_tree().create_timer(0.8).timeout`, for the same
	# reason the manual loop below is `while is_inside_tree()`. A SceneTreeTimer that has not
	# run out yet is never resumed once the scene is torn down or the process quits, so every
	# round that ended inside that 0.8 s window stranded this coroutine's
	# GDScriptFunctionState for the life of the process. Measured with --verbose: VerifyFairness
	# leaked 72 of them, VerifyNarrativeCopy 49, VerifyCartoonLoop 6 - one per game the harness
	# instantiated, and `Orphan StringName: _wait_for_input` matched each count exactly.
	# process_frame emits every idle frame, paused or not, so the wait is still 0.8 s and it
	# now ends the moment the node leaves the tree.
	if AutoPlayManager and AutoPlayManager.is_auto_play_enabled():
		var bypass_deadline := Time.get_ticks_msec() + 800
		while is_inside_tree() and Time.get_ticks_msec() < bypass_deadline:
			await get_tree().process_frame
		return

	var mouse_was_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var touch_was_down := false
	if InputMap.has_action("touch"):
		touch_was_down = Input.is_action_pressed("touch")

	# Loop while this node is still live, not `while true`.
	#
	# The only way out used to be the player pressing something. If the scene was
	# torn down while this waited on the "tap to start" prompt — quit to menu, the
	# app being backgrounded, shutdown — the loop had no terminating condition and
	# the coroutine spun on forever, stranding its GDScriptFunctionState (an
	# ObjectDB leak at exit). get_tree() also returns null on a detached node, so
	# the await itself would fault once the node left the tree.
	while is_inside_tree():
		await get_tree().process_frame
		if not is_inside_tree():
			return
		var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		var mouse_just_pressed := mouse_down and not mouse_was_down
		mouse_was_down = mouse_down

		var touch_pressed := false
		if InputMap.has_action("touch"):
			var touch_down := Input.is_action_pressed("touch")
			touch_pressed = touch_down and not touch_was_down
			touch_was_down = touch_down

		if (
			Input.is_action_just_pressed("ui_accept")
			or mouse_just_pressed
			or touch_pressed
		):
			break

## Bring up the authored first-play tutorial for this game, or return null when
## there is nothing to show.
##
## autoload/TutorialManager.gd carries multi-step bilingual tutorials plus a tip
## for 8 of the 24 singleplayer games, and had NO caller anywhere in the project:
## should_show_tutorial(), create_tutorial_popup() and mark_tutorial_shown() were
## all unreachable, so first-time players only ever saw game_instruction_text — a
## single line. This is the caller. Games with no authored entry fall through to
## that line exactly as before.
##
## The key is the scene basename ("CatchTheRain"), which is what TutorialManager
## keys its dictionary on.
##
## mark_tutorial_shown() is called HERE rather than from the popup's START button
## so that a player who leaves mid-tutorial is not shown it again on every future
## visit; the button's own call is idempotent.
func _show_first_play_tutorial() -> Control:
	if TutorialManager == null or hud_layer == null:
		return null
	if scene_file_path.is_empty():
		return null
	var key: String = scene_file_path.get_file().get_basename()
	if not TutorialManager.should_show_tutorial(key):
		return null
	var popup: Control = TutorialManager.create_tutorial_popup(key, hud_layer) as Control
	if popup == null:
		return null
	# The popup has to swallow taps aimed at the game underneath it, and keep
	# animating if the round is brought up paused.
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	TutorialManager.mark_tutorial_shown(key)
	return popup


func _hide_instruction_overlay() -> void:
	_stop_instruction_overlay_tweens()
	if instruction_overlay and is_instance_valid(instruction_overlay):
		instruction_overlay.visible = false

func _stop_instruction_overlay_tweens() -> void:
	for t in _instruction_overlay_tweens:
		if t and t.is_valid():
			t.kill()
	_instruction_overlay_tweens.clear()

func _exit_tree() -> void:
	# Safety: never leave the tree paused when the minigame scene goes away —
	# a stuck pause here froze the whole game past the scoring screen.
	get_tree().paused = false
	_hide_instruction_overlay()
	# The root viewport outlives this scene, so an unrestored cameraless shake
	# offset would follow the player into the next minigame. Quitting to menu
	# mid-round skips end_game() entirely, which is how that used to happen.
	_clear_screen_shake()

func _play_intro_animation() -> void:
	var scene = _resolve_cutscene_scene("intro")
	if scene:
		var intro = scene.instantiate()
		hud_layer.add_child(intro)
		if intro.has_method("configure"):
			# Third argument is the anim profile MiniGameIntroCutscene divides its whole
			# 4 s timeline by. It used to be omitted, which pinned this intro at full
			# length even with reduced motion on.
			intro.configure(
				game_name,
				_loc("get_ready", "Get ready..."),
				{"speed": _motion_speed()}
			)
		if intro.has_method("play_cutscene"):
			await intro.play_cutscene()
		else:
			await get_tree().create_timer(1.1).timeout
		intro.queue_free()
		return

	# Fallback if cutscene scene is missing
	await get_tree().create_timer(0.45).timeout

func _create_pause_menu():
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(pause_menu)

	# ── Frosted glass backdrop ───────────────────────────────────────
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.08, 0.14, 0.82)
	pause_menu.add_child(bg)

	# Subtle vignette border glow
	var vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.0, 0.0, 0.0, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_menu.add_child(vignette)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)

	# ── Main card panel ──────────────────────────────────────────────
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.14, 0.22, 0.92)
	card_style.corner_radius_top_left = 32
	card_style.corner_radius_top_right = 32
	card_style.corner_radius_bottom_left = 32
	card_style.corner_radius_bottom_right = 32
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_color = Color(0.3, 0.65, 0.9, 0.4)
	card_style.shadow_color = Color(0, 0, 0, 0.35)
	card_style.shadow_size = 12
	card_style.content_margin_left = 60
	card_style.content_margin_right = 60
	card_style.content_margin_top = 44
	card_style.content_margin_bottom = 44
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# ── Water drop icon ──────────────────────────────────────────────
	var drop_icon = Label.new()
	drop_icon.text = "💧"
	drop_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop_icon.add_theme_font_size_override("font_size", 56)
	vbox.add_child(drop_icon)

	# Gentle pulse on the drop icon
	var pulse = create_tween().set_loops()
	pulse.tween_property(drop_icon, "modulate", Color(0.8, 0.9, 1.2), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(drop_icon, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)

	# ── Title ────────────────────────────────────────────────────────
	var label = Label.new()
	label.text = _loc("mp_paused", "PAUSED")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.35, 0.6))
	label.add_theme_constant_override("outline_size", 4)
	vbox.add_child(label)

	# ── Current score display ────────────────────────────────────────
	var score_info = Label.new()
	score_info.name = "PauseScoreLabel"
	score_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_info.add_theme_font_size_override("font_size", 20)
	score_info.add_theme_color_override("font_color", Color(0.6, 0.75, 0.88))
	var _session_score = GameManager.session_score if GameManager else 0
	score_info.text = _loc("shell_current_score", "Current Score: %d") % _session_score
	vbox.add_child(score_info)

	# ── Spacer ───────────────────────────────────────────────────────
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	vbox.add_child(spacer)

	# ── RESUME Button ────────────────────────────────────────────────
	var resume_btn = Button.new()
	resume_btn.text = _loc("shell_resume", "▶  RESUME")
	resume_btn.custom_minimum_size = Vector2(260, 64)
	var resume_style = StyleBoxFlat.new()
	resume_style.bg_color = Color(0.2, 0.6, 0.4, 0.92)
	resume_style.corner_radius_top_left = 32
	resume_style.corner_radius_top_right = 32
	resume_style.corner_radius_bottom_left = 32
	resume_style.corner_radius_bottom_right = 32
	resume_style.border_width_top = 2
	resume_style.border_width_bottom = 2
	resume_style.border_width_left = 2
	resume_style.border_width_right = 2
	resume_style.border_color = Color(0.35, 0.85, 0.55, 0.5)
	resume_btn.add_theme_stylebox_override("normal", resume_style)
	var resume_hover = resume_style.duplicate()
	resume_hover.bg_color = Color(0.25, 0.7, 0.48, 0.95)
	resume_btn.add_theme_stylebox_override("hover", resume_hover)
	var resume_press = resume_style.duplicate()
	resume_press.bg_color = Color(0.15, 0.5, 0.35, 0.95)
	resume_btn.add_theme_stylebox_override("pressed", resume_press)
	resume_btn.add_theme_font_size_override("font_size", 24)
	resume_btn.add_theme_color_override("font_color", Color.WHITE)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)

	# ── QUIT Button ──────────────────────────────────────────────────
	var exit_btn = Button.new()
	exit_btn.text = _loc("shell_quit_game", "✖  QUIT GAME")
	exit_btn.custom_minimum_size = Vector2(260, 64)
	var exit_style = StyleBoxFlat.new()
	exit_style.bg_color = Color(0.55, 0.2, 0.2, 0.85)
	exit_style.corner_radius_top_left = 32
	exit_style.corner_radius_top_right = 32
	exit_style.corner_radius_bottom_left = 32
	exit_style.corner_radius_bottom_right = 32
	exit_style.border_width_top = 2
	exit_style.border_width_bottom = 2
	exit_style.border_width_left = 2
	exit_style.border_width_right = 2
	exit_style.border_color = Color(0.9, 0.4, 0.4, 0.4)
	exit_btn.add_theme_stylebox_override("normal", exit_style)
	var exit_hover = exit_style.duplicate()
	exit_hover.bg_color = Color(0.65, 0.25, 0.25, 0.92)
	exit_btn.add_theme_stylebox_override("hover", exit_hover)
	var exit_press = exit_style.duplicate()
	exit_press.bg_color = Color(0.45, 0.15, 0.15, 0.92)
	exit_btn.add_theme_stylebox_override("pressed", exit_press)
	exit_btn.add_theme_font_size_override("font_size", 22)
	exit_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.85))
	exit_btn.pressed.connect(_on_exit_pressed)
	vbox.add_child(exit_btn)

func _on_pause_pressed():
	# No pausing once the round is over (scoring/tally/outro) — the pause
	# overlay belongs to the minigame scene and would freeze the game with
	# no way to resume once the scene changes.
	if not game_active:
		return
	get_tree().paused = true
	pause_menu.visible = true
	# Update current score display
	var score_lbl = pause_menu.find_child("PauseScoreLabel", true, false)
	if score_lbl:
		var _session_score = GameManager.session_score if GameManager else 0
		score_lbl.text = _loc("shell_current_score", "Current Score: %d") % _session_score
	if AudioManager:
		AudioManager.play_pause()

func _on_resume_pressed():
	get_tree().paused = false
	pause_menu.visible = false
	if AudioManager:
		AudioManager.play_resume()

func _on_exit_pressed():
	# Exactly once, and never a second recording of a round end_game() already
	# recorded. This function is the OTHER caller of
	# GameManager.complete_minigame() besides end_game(), and it used to neither
	# check nor set _round_ended, so the exactly-once guard covered one of the two
	# paths. Measured consequences, from tools/VerifyRoundEndOnce.tscn before this
	# was added: three taps on QUIT recorded the round three times, and one
	# abandoned round put 3 samples into AdaptiveDifficulty.performance_window -
	# 60% of a window_size of 5, so most of the evidence behind the next difficulty
	# decision came from a single quit. It also double-counted
	# minigames_played_this_session and wrote a duplicate SessionLogger row.
	#
	# Two separate flags because they answer two different questions:
	#   _quitting     - has this scene already begun leaving? A repeat tap must do
	#                   nothing at all, not merely skip the recording, because the
	#                   Button stays enabled and the tally screen takes seconds.
	#   _round_ended  - has this round already been reported to the algorithm?
	#                   Shared with end_game() so the guard holds in BOTH
	#                   directions: quit-then-end, and end-then-quit.
	# The player still leaves either way; it is only the recording that is skipped.
	if _quitting:
		return
	_quitting = true
	var record_round: bool = not _round_ended
	_round_ended = true

	get_tree().paused = false
	pause_menu.visible = false
	game_active = false
	timer_running = false

	# Stop all timers/effects
	if _game_timer and is_instance_valid(_game_timer):
		_game_timer.stop()
	for t in _chaos_timers:
		if is_instance_valid(t):
			t.stop()
			t.queue_free()
	_chaos_timers.clear()
	controls_reversed = false

	# Save whatever score we have so far - but only if end_game() has not already
	# reported this round. record_round is false when the round was already ended
	# and the player then pressed QUIT over the tally screen.
	#
	# Deliberately NOT force-recording a zero-score round on the second path: the
	# round already went to the algorithm with its real accuracy, and adding a
	# second synthetic sample is the defect, not the fix.
	if GameManager and record_round:
		var elapsed = elapsed_play_seconds()
		# A quit is not a completed objective. This path used to report raw
		# action-correctness, so abandoning a round after three clean catches
		# sent A = 1.00 to the algorithm and read as a flawless performance.
		var accuracy = _report_accuracy(false)
		GameManager.complete_minigame(
			game_name,
			accuracy,
			# Same distinction as end_game(): the algorithm gets response latency.
			representative_reaction_time_ms(),
			mistakes_made,
			current_score,
			max_combo,
			false,
			_get_minigame_key()
		)

	# Show quit tally screen with current progress before exiting
	await _show_quit_tally_screen()

	if GameManager:
		GameManager.mark_welcome_shown()
		GameManager.return_to_main_menu()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

## DWTD-style quit tally — shows your session score before leaving
func _show_quit_tally_screen() -> void:

	var session_total: int = GameManager.session_score if GameManager else 0
	var rounds_played: int = GameManager.round_scores.size() if GameManager else 0
	var _lives: int = GameManager.session_lives if GameManager else lives

	# ── Full-screen page ──────────────────────────────────────────────
	var page = Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.process_mode = Node.PROCESS_MODE_ALWAYS
	page.modulate.a = 0.0
	hud_layer.add_child(page)

	# Scoring track, started after the page exists so it can be scoped to the page it
	# belongs to rather than to this coroutine.
	#
	# It used to start at the top of the function and be stopped on the coroutine's
	# LAST line, three awaits and ~3.5s later. Two of those awaits are
	# `await tween.finished` on tweens made with create_tween(), which binds them to
	# this node - so a teardown inside the tally window killed the tweens, the awaits
	# never resumed, and the stop never ran. tools/VerifyStrayAudio.tscn measured it:
	# tearing the scene down while the tally was up left current_music='scoring'
	# playing=true over InitialScreen, in a run where the score page's already-paired
	# stop came out silent.
	_play_scoped_music("scoring", 0.22, page)

	# Dark background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.1, 0.16, 0.96)
	page.add_child(bg)

	# Top accent
	var accent_bar = ColorRect.new()
	accent_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	accent_bar.custom_minimum_size.y = 6
	accent_bar.color = Color(0.9, 0.5, 0.3)
	page.add_child(accent_bar)

	# Layout
	var outer = MarginContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 48)
	outer.add_theme_constant_override("margin_right", 48)
	outer.add_theme_constant_override("margin_top", 36)
	outer.add_theme_constant_override("margin_bottom", 36)
	page.add_child(outer)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	outer.add_child(vbox)

	# ── Outcome title (was a bare "GAME OVER") ────────────────────────
	var title = Label.new()
	# The player just finished a round and chose to leave — the title should
	# say WHAT happened, not the generic "SESSION ENDED". Reuse the round's
	# flavor outcome line (e.g. "Water leak fixed — no more noise").
	if _last_round_outcome_text != "":
		title.text = _last_round_outcome_text
	else:
		title.text = _loc("shell_session_ended", "SESSION ENDED")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.9, 0.65, 0.4))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.5))
	title.add_theme_constant_override("outline_size", 3)
	vbox.add_child(title)

	# ── Water drops row (lives) ───────────────────────────────────────
	var drops_row = HBoxContainer.new()
	drops_row.alignment = BoxContainer.ALIGNMENT_CENTER
	drops_row.add_theme_constant_override("separation", 32)
	vbox.add_child(drops_row)

	for i in range(3):
		var drop = Label.new()
		drop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		drop.add_theme_font_size_override("font_size", 64)
		drop.text = "💧"
		if i >= _lives:
			drop.modulate = Color(0.4, 0.4, 0.4, 0.5)
		drops_row.add_child(drop)

	# ── Score display ─────────────────────────────────────────────────
	var score_display = Label.new()
	score_display.text = str(session_total)
	score_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_display.add_theme_font_size_override("font_size", 72)
	score_display.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(score_display)

	var score_cap = Label.new()
	score_cap.text = _loc("total_score", "TOTAL SCORE")
	score_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_cap.add_theme_font_size_override("font_size", 16)
	score_cap.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	vbox.add_child(score_cap)

	# ── Stat pills ────────────────────────────────────────────────────
	var pills = HBoxContainer.new()
	pills.alignment = BoxContainer.ALIGNMENT_CENTER
	pills.add_theme_constant_override("separation", 16)
	vbox.add_child(pills)

	var pill_data: Array = [
		["🎮 %d" % rounds_played, "Rounds"],
		["💧 %d" % (GameManager.water_droplets if GameManager else 0), "Droplets"],
	]

	for pd in pill_data:
		var pill = PanelContainer.new()
		var pstyle = StyleBoxFlat.new()
		pstyle.bg_color = Color(0.12, 0.18, 0.28, 0.9)
		pstyle.corner_radius_top_left = 16
		pstyle.corner_radius_top_right = 16
		pstyle.corner_radius_bottom_left = 16
		pstyle.corner_radius_bottom_right = 16
		pstyle.content_margin_left = 20
		pstyle.content_margin_right = 20
		pstyle.content_margin_top = 10
		pstyle.content_margin_bottom = 10
		pill.add_theme_stylebox_override("panel", pstyle)

		var pvbox = VBoxContainer.new()
		pvbox.add_theme_constant_override("separation", 2)
		pill.add_child(pvbox)

		var val_lbl = Label.new()
		val_lbl.text = pd[0]
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 22)
		val_lbl.add_theme_color_override("font_color", Color.WHITE)
		pvbox.add_child(val_lbl)

		var cap_lbl = Label.new()
		cap_lbl.text = pd[1]
		cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap_lbl.add_theme_font_size_override("font_size", 13)
		cap_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		pvbox.add_child(cap_lbl)

		pills.add_child(pill)

	# ── Animate ───────────────────────────────────────────────────────
	var fade_in = create_tween()
	fade_in.tween_property(page, "modulate:a", 1.0, 0.35)
	await fade_in.finished

	# Hold for viewing
	await get_tree().create_timer(2.8).timeout

	# Fade out
	var fade_out = create_tween()
	fade_out.tween_property(page, "modulate:a", 0.0, 0.35)
	await fade_out.finished
	page.queue_free()
	# The stop that used to be here is now bound to page.tree_exiting at the top of
	# this function - queue_free() above still triggers it, and so does every exit
	# that never gets this far. See _play_scoped_music().


func _process(_delta):
	if not game_active: return
	
	# Skip timer logic if timer hasn't started yet (for games with setup phases)
	if not timer_running: return
	
	# ── Hot path: arithmetic only, no allocation, no UI writes ──────────────
	var elapsed = elapsed_play_seconds()
	var time_left = max(0.0, game_duration - elapsed)
	
	# Note: mistake penalty is tracked in _time_penalty_total and subtracted here.
	var effective_time_left = max(0.0, time_left - _time_penalty_total)

	# Attempts mode hides the clock, because the clock is only an anti-hang
	# ceiling. Reveal it for the last few seconds so hitting it is never a
	# surprise; the tries readout keeps its place beside it.
	if fail_mode == "attempts" and effective_time_left <= ATTEMPT_CEILING_WARN_SEC:
		if timer_label and not timer_label.visible:
			timer_label.visible = true
		if timer_bar and not timer_bar.visible:
			timer_bar.visible = true
	
	# ── UI is decoupled from the hot path ───────────────────────────────────
	# The bar moves at 10 Hz (smooth enough to read as continuous), the number
	# only at 1 Hz because it now shows whole seconds. Writing
	# `timer_label.text` every frame allocated a new String 60×/s and re-laid-out
	# the Label; `add_theme_color_override` also re-resolved the theme every
	# frame. Both fire only on real change.
	if timer_bar:
		var tenths := int(effective_time_left * 10.0)
		if tenths != _last_timer_tenths:
			_last_timer_tenths = tenths
			timer_bar.value = effective_time_left

			# Colour band: 0 = green, 1 = amber, 2 = red. Recolour on transition
			# only, so the StyleBox and theme override are touched ~2× per round.
			var time_ratio = effective_time_left / game_duration
			var band := 0
			if time_ratio < 0.3:
				band = 2
			elif time_ratio < 0.6:
				band = 1

			if band != _last_timer_band:
				_last_timer_band = band
				var fill_style = timer_bar.get_theme_stylebox("fill") as StyleBoxFlat
				var band_color: Color = HUD_GREEN
				match band:
					2: band_color = HUD_RED
					1: band_color = HUD_AMBER
					_: band_color = HUD_GREEN
				if fill_style:
					fill_style.bg_color = band_color
				# The number stays ink-coloured until it's actually urgent, so
				# the HUD reads as one calm object for most of the round.
				if timer_label:
					timer_label.add_theme_color_override(
						"font_color", HUD_RED if band == 2 else HUD_INK
					)

	# Whole-second countdown, no unit suffix — the bar already says "time".
	var sec := int(ceil(effective_time_left))
	if timer_label and sec != _last_timer_second:
		_last_timer_second = sec
		timer_label.text = str(sec)

	# Tick urgency sound once per whole second in the final 5 s. Kept outside the
	# UI block so it fires even when this game has no timer_bar.
	if sec != _last_tick_second and sec <= 5 and sec > 0 and AudioManager:
		_last_tick_second = sec
		AudioManager.play_timer_tick()
	
	if effective_time_left <= 0:
		_on_timeout()

func _on_timeout():
	if not game_active: return
	
	# Survival mode: timer running out = SUCCESS (you survived!)
	if game_mode == "survival":
		end_game(true)
	else:
		# In attempts mode this is the anti-hang ceiling, not a fair loss — see
		# _on_timer_timeout(). Both paths exist because the Timer node and this
		# per-frame check are independent; whichever fires first ends the round and
		# end_game()'s _round_ended guard absorbs the other.
		if fail_mode == "attempts":
			print("🎯 [%s] Anti-hang ceiling reached, %d tries still unspent" % [
				game_name, attempts_left
			])
		# Quota mode: timer running out = FAIL (didn't meet target)
		game_failed.emit()
		end_game(false)

func _deduct_life():
	# Game Lab: losing a sandbox round costs nothing. The point of the Lab is to
	# find out whether a mechanic is fair; charging a life to ask makes the
	# player pay for the experiment.
	if GameManager and GameManager.sandbox_mode:
		print("🧪 [%s] Sandbox round lost — no life deducted" % game_name)
		return

	lives -= 1
	
	# Save lives to GameManager
	if GameManager:
		GameManager.session_lives = lives
	
	# Audio: life lost
	if AudioManager:
		AudioManager.play_life_lost()
	
	# Note: Game over is handled by GameManager.start_next_minigame() which
	# checks session_lives <= 0 and shows the final score screen properly.

# _show_results() and _show_failure() used to live here: two unreachable functions
# that dropped a bare "SUCCESS!" / "OOPS!" Label on hud_layer and then called
# GameManager.start_next_minigame() themselves. Nothing in the project called
# either one — the live outcome path is end_game() → _show_tally_screen() →
# _show_round_score_page(), which plays the cartoon outro and the funny failure
# reactions from _get_result_reaction(). They were removed rather than polished
# because calling one would have advanced the round a SECOND time on top of
# end_game()'s own advance, racing two scene loads.

func _show_tally_screen(success: bool, _accuracy: float, _reaction_time: int):
	# Preferred path: full "Dumb Ways to Die"-style outro — a real animated
	# scene with a jointed character acting out the consequence, instead of
	# a single emoji scaling in a Label.
	if await _play_cartoon_outro(success):
		return

	var reaction = _get_result_reaction(success)
	var score_this_round = 0
	if GameManager and GameManager.round_scores.size() > 0:
		score_this_round = GameManager.round_scores[-1]["score"]

	var scene = _resolve_narrative_outro_scene(success)
	if not scene:
		print("⚠️ No narrative scene found, trying text-based outro...")
		scene = _resolve_outro_cutscene_scene(success)
	
	if scene:
		print("▶️ LOADING OUTRO: %s" % scene.resource_path)
		var outro = scene.instantiate()
		hud_layer.add_child(outro)
		var use_narrative = scene.resource_path.contains("CharacterOutcomeNarrative")
		if outro.has_method("configure"):
			if use_narrative:
				print("🎭 Configuring NARRATIVE cutscene")
				outro.configure(
					success,
					_get_minigame_key(),
					_with_motion_speed(_get_outro_anim_profile(success))
				)
			else:
				print("📝 Configuring TEXT-BASED outro")
				outro.configure(
					success,
					reaction["line"],
					score_this_round,
					max_combo,
					lives,
					_with_motion_speed(_get_outro_anim_profile(success))
				)
		if outro.has_method("play_cutscene"):
			print("▶️ Playing cutscene...")
			await outro.play_cutscene()
		else:
			print("⏱️ Generic wait instead of cutscene playback")
			await get_tree().create_timer(1.25).timeout
		if is_instance_valid(outro):
			outro.queue_free()
		return

	# Fallback if cutscene scene is missing
	print("❌ No outro cutscene found at all")
	await get_tree().create_timer(0.55).timeout

## Plays the animated consequence scene for this minigame.
## Returns true if it ran, false if the caller should fall back to the older
## emoji/text outros.
func _play_cartoon_outro(success: bool) -> bool:
	if not use_cartoon_cutscenes:
		return false

	# Tier 1: authored 4-beat scenes (MicrogameOutroBase subclasses) living at
	# res://scenes/ui/cutscenes/beats/<Key><Win|Lose>Outro.tscn. They expose
	# play_win()/play_lose() so any minigame's clip is driven identically.
	if await _play_beat_outro(success):
		return true

	# Tier 2: declarative CartoonStage scenario (existing behaviour).
	var kind: int = (
		CartoonStage.Kind.EFFECT_WIN if success
		else CartoonStage.Kind.EFFECT_LOSE
	)
	var stage := CartoonStage.new()
	stage.configure(kind, _get_minigame_key(), _get_cartoon_speed())
	hud_layer.add_child(stage)
	await stage.play_cutscene()
	if is_instance_valid(stage):
		stage.queue_free()
	if not is_inside_tree():
		return true
	# One frame so the queued free completes before the score page builds on top.
	await get_tree().process_frame
	return true

## Plays an authored MicrogameOutroBase clip if one exists for this minigame.
## Returns true if it ran, false so the caller falls back to CartoonStage.
func _play_beat_outro(success: bool) -> bool:
	var suffix := "Win" if success else "Lose"
	var beat_path := "res://scenes/ui/cutscenes/beats/%s%sOutro.tscn" % [
		_get_minigame_key(), suffix
	]
	if not ResourceLoader.exists(beat_path):
		return false

	var clip = (load(beat_path) as PackedScene).instantiate()
	clip.speed_scale = _get_cartoon_speed()["speed"]
	hud_layer.add_child(clip)
	if success and clip.has_method("play_win"):
		clip.play_win()
	elif clip.has_method("play_lose"):
		clip.play_lose()
	await _await_signal_or_timeout(clip.outro_finished, BEAT_OUTRO_TIMEOUT_SEC)
	if is_instance_valid(clip):
		clip.queue_free()
	if not is_inside_tree():
		return true
	await get_tree().process_frame
	return true

## Low-end devices get faster clips rather than no clips: the scenario is the
## teaching moment, so we compress it instead of skipping it.
## The cutscene speed DIVISOR shared by CartoonStage, the authored beat clips and
## the intro/outro cutscene scenes: every one of them expresses its runtime as a
## duration divided by this number, so a bigger value means a shorter cutscene.
##
## Two independent reasons to compress, and they multiply because both can hold at
## once:
##   * the device is already missing frames (1.6), so a cutscene it renders badly
##     costs the player less time, and
##   * the player asked for reduced motion, which is what
##     AccessibilityManager.get_animation_speed() reports (3.0 when on).
##
## Until this call, get_animation_speed() had no reader anywhere in the project:
## "reduced motion" suppressed particles and screen shake and still played every
## cutscene at full length.
func _get_cartoon_speed() -> Dictionary:
	var speed: float = 1.0
	if PerformanceProfiler and PerformanceProfiler.session_elapsed_sec > 5.0:
		if PerformanceProfiler.fps_avg < LOW_END_FPS_THRESHOLD:
			speed = 1.6
	return {"speed": speed * _motion_speed()}

## AccessibilityManager.get_animation_speed(), guarded, never zero. Falls back to
## 1.0 (unchanged pacing) rather than to a guess, so a missing accessibility layer
## leaves cutscene timing exactly as authored instead of stalling or racing it.
func _motion_speed() -> float:
	if AccessibilityManager and AccessibilityManager.has_method("get_animation_speed"):
		var reported := float(AccessibilityManager.get_animation_speed())
		if reported > 0.0:
			return reported
	return 1.0

## Fold the reduced-motion factor into an authored anim profile without disturbing
## the per-game pacing it carries. Copied rather than mutated: the profile helpers
## return fresh literals today, and a future cached one must not accumulate the
## multiplier on every round.
func _with_motion_speed(profile: Dictionary) -> Dictionary:
	var out: Dictionary = profile.duplicate()
	out["speed"] = float(out.get("speed", 1.0)) * _motion_speed()
	return out

func _resolve_narrative_outro_scene(_success: bool) -> PackedScene:
	# Try to use generic narrative scene (shows character outcome animation)
	var fallback_narrative_path = "res://scenes/ui/cutscenes/CharacterOutcomeNarrative.tscn"
	if ResourceLoader.exists(fallback_narrative_path):
		return load(fallback_narrative_path) as PackedScene

	return null

func _resolve_outro_cutscene_scene(success: bool) -> PackedScene:
	var key = _get_minigame_key()
	var suffix = "Win" if success else "Lose"

	var specific_status_path = "res://scenes/ui/cutscenes/outro/%s%sOutro.tscn" % [
		key,
		suffix
	]
	var generic_status_path = "res://scenes/ui/cutscenes/MiniGame%sOutroCutscene.tscn" % suffix
	var legacy_specific_path = "res://scenes/ui/cutscenes/outro/%sOutro.tscn" % key
	var legacy_generic_path = "res://scenes/ui/cutscenes/MiniGameOutroCutscene.tscn"

	if ResourceLoader.exists(specific_status_path):
		return load(specific_status_path) as PackedScene
	if ResourceLoader.exists(generic_status_path):
		return load(generic_status_path) as PackedScene
	if ResourceLoader.exists(legacy_specific_path):
		return load(legacy_specific_path) as PackedScene
	if ResourceLoader.exists(legacy_generic_path):
		return load(legacy_generic_path) as PackedScene
	return null

func _get_outro_anim_profile(success: bool) -> Dictionary:
	var key = _get_minigame_key()

	if (
		"Rain" in key
		or "Leak" in key
		or "Tap" in key
		or "Pipe" in key
	):
		return {
			"speed": 1.15 if success else 1.0,
			"distance": 1.2,
			"pop": 1.1 if success else 0.95
		}

	if (
		"Plant" in key
		or "Scrub" in key
		or "Filter" in key
		or "Vegetable" in key
	):
		return {
			"speed": 0.95 if success else 0.9,
			"distance": 0.9,
			"pop": 1.25 if success else 1.0
		}

	return {
		"speed": 1.05 if success else 0.95,
		"distance": 1.0,
		"pop": 1.05 if success else 0.95
	}

func _show_round_score_page(success: bool, accuracy: float, _reaction_time: int) -> void:
	# ═══════════════════════════════════════════════════════════════════════
	# DWTD-STYLE SCORING PAGE  — Water Drop Characters + Evaporation
	# ═══════════════════════════════════════════════════════════════════════
	var max_lives := 3
	var current_lives := lives  # already decremented by _deduct_life() if failed
	var accent: Color = Color(0.35, 0.85, 0.55) if success else Color(1.0, 0.45, 0.3)

	var round_score := 0
	if GameManager and GameManager.round_scores.size() > 0:
		round_score = int(GameManager.round_scores[-1].get("score", 0))
	var session_total := GameManager.session_score if GameManager else 0
	var flavor_line := _get_result_line_for_key(success, _get_minigame_key())

	# ── Full-screen page ──────────────────────────────────────────────────
	var page = Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.process_mode = Node.PROCESS_MODE_ALWAYS
	page.modulate.a = 0.0
	hud_layer.add_child(page)

	# Scoring track, owned by the page rather than by this coroutine.
	#
	# The stop used to sit on the coroutine's last line, ~5.5 seconds and 40-odd
	# await points later. Any exit before that line — the player quitting, the
	# round being advanced, the app being backgrounded, the scene torn down — left
	# the scoring track playing over whatever screen came next. Hanging the stop on
	# tree_exiting instead pairs it with the page's actual lifetime, so every path
	# out stops the music exactly once.
	#
	# The binding now goes through _play_scoped_music() rather than being written out
	# here, because this was the only one of the file's six music starts that had it:
	# tools/VerifyStrayAudio.tscn measured this page coming out silent while the quit
	# tally, which kept its stop on the coroutine's last line, left
	# current_music='scoring' playing=true over InitialScreen in the same run.
	_play_scoped_music("scoring", 0.22, page)

	# Warm cream/beige background (DWTD style)
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.96, 0.93, 0.86, 0.97)
	page.add_child(bg)

	# Subtle top accent bar
	var accent_bar = ColorRect.new()
	accent_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	accent_bar.custom_minimum_size.y = 6
	accent_bar.color = accent
	page.add_child(accent_bar)

	# ── Main layout ───────────────────────────────────────────────────────
	var outer_margin = MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 48)
	outer_margin.add_theme_constant_override("margin_right", 48)
	outer_margin.add_theme_constant_override("margin_top", 36)
	outer_margin.add_theme_constant_override("margin_bottom", 36)
	page.add_child(outer_margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	outer_margin.add_child(vbox)

	# ── Title ─────────────────────────────────────────────────────────────
	var title = Label.new()
	title.text = _loc("mp_round_complete", "ROUND COMPLETE") if success else _loc("round_failed", "ROUND FAILED")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.22, 0.22, 0.22))
	title.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.3))
	title.add_theme_constant_override("outline_size", 2)
	vbox.add_child(title)

	# ── Water Drop Characters (DWTD Lives Row) ───────────────────────────
	var drops_row = HBoxContainer.new()
	drops_row.alignment = BoxContainer.ALIGNMENT_CENTER
	drops_row.add_theme_constant_override("separation", 32)
	vbox.add_child(drops_row)

	var drop_labels: Array[Label] = []
	for i in range(max_lives):
		var drop = Label.new()
		drop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		drop.add_theme_font_size_override("font_size", 72)
		if i < current_lives:
			drop.text = "💧"
		else:
			drop.text = "💧"
			drop.modulate = Color(0.5, 0.5, 0.5, 0.7)
		drop.modulate.a = 0.0  # start invisible for staggered entrance
		drops_row.add_child(drop)
		drop_labels.append(drop)

	# ── Flavor text ───────────────────────────────────────────────────────
	var flavor = Label.new()
	flavor.text = flavor_line
	_last_round_outcome_text = ("Win: " if success else "Loss: ") + flavor_line
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.add_theme_font_size_override("font_size", 22)
	flavor.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.modulate.a = 0.0
	vbox.add_child(flavor)

	# ── Big Score Number ──────────────────────────────────────────────────
	var score_display = Label.new()
	score_display.text = "0"
	score_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_display.add_theme_font_size_override("font_size", 80)
	score_display.add_theme_color_override("font_color", Color(0.18, 0.18, 0.18))
	score_display.modulate.a = 0.0
	vbox.add_child(score_display)

	var score_caption = Label.new()
	score_caption.text = _loc("total_score", "TOTAL SCORE")
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_caption.add_theme_font_size_override("font_size", 16)
	score_caption.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
	score_caption.modulate.a = 0.0
	vbox.add_child(score_caption)

	# ── Stat Pills (accuracy / combo / time) ─────────────────────────────
	var pills_row = HBoxContainer.new()
	pills_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pills_row.add_theme_constant_override("separation", 16)
	vbox.add_child(pills_row)

	var accuracy_pct := int(round(accuracy * 100.0))
	var pill_data := [
		["🎯 %d%%" % accuracy_pct, "Accuracy"],
		["🔥 x%d" % max_combo, "Best Combo"],
		["💧 %d" % (GameManager.water_droplets if GameManager else 0), "Droplets"],
	]
	var pill_nodes: Array[Control] = []

	for pd in pill_data:
		var pill = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.92, 0.89, 0.82)
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
		style.corner_radius_bottom_left = 16
		style.corner_radius_bottom_right = 16
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		pill.add_theme_stylebox_override("panel", style)
		pill.modulate.a = 0.0

		var pill_vbox = VBoxContainer.new()
		pill_vbox.add_theme_constant_override("separation", 2)
		pill.add_child(pill_vbox)

		var val_lbl = Label.new()
		val_lbl.text = pd[0]
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 22)
		val_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		pill_vbox.add_child(val_lbl)

		var cap_lbl = Label.new()
		cap_lbl.text = pd[1]
		cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap_lbl.add_theme_font_size_override("font_size", 13)
		cap_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.48))
		pill_vbox.add_child(cap_lbl)

		pills_row.add_child(pill)
		pill_nodes.append(pill)

	# ── Session total bar ─────────────────────────────────────────────────
	var session_bar = PanelContainer.new()
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = accent.lerp(Color.WHITE, 0.7)
	sb_style.corner_radius_top_left = 12
	sb_style.corner_radius_top_right = 12
	sb_style.corner_radius_bottom_left = 12
	sb_style.corner_radius_bottom_right = 12
	sb_style.content_margin_left = 24
	sb_style.content_margin_right = 24
	sb_style.content_margin_top = 8
	sb_style.content_margin_bottom = 8
	session_bar.add_theme_stylebox_override("panel", sb_style)
	session_bar.modulate.a = 0.0
	vbox.add_child(session_bar)

	var session_hbox = HBoxContainer.new()
	session_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	session_hbox.add_theme_constant_override("separation", 12)
	session_bar.add_child(session_hbox)

	var sess_label = Label.new()
	sess_label.text = _loc("shell_this_round", "This Round")
	sess_label.add_theme_font_size_override("font_size", 18)
	sess_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	session_hbox.add_child(sess_label)

	var sess_val = Label.new()
	sess_val.text = _loc("shell_round_points", "+%d pts") % round_score
	sess_val.add_theme_font_size_override("font_size", 22)
	sess_val.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	session_hbox.add_child(sess_val)

	# ══════════════════════════════════════════════════════════════════════
	#  ANIMATION SEQUENCE
	# ══════════════════════════════════════════════════════════════════════
	#
	# Every tween above and below is created on `page`, not on `self`. Two reasons:
	# the page is PROCESS_MODE_ALWAYS, so binding to it keeps the tweens in step
	# with the process-always timers this sequence waits on instead of stalling on
	# a pause the timers ignore; and a tween bound to the page dies with the page,
	# which is exactly the abort condition _score_page_alive() tests for.
	#
	# The waits are durations rather than `await tween.finished`. A killed tween
	# never emits `finished`, so awaiting it strands the coroutine permanently —
	# that is the leaked GDScriptFunctionState this sequence used to produce on
	# shutdown, and mid-play it would have parked the round on the score page with
	# start_next_minigame() never reached.

	# 1. Fade in entire page
	var fade_in = page.create_tween()
	fade_in.tween_property(page, "modulate:a", 1.0, 0.3)
	if not await _score_page_alive(0.3, page):
		return

	# 2. Stagger water drops entrance (bounce in one-by-one)
	for i in range(drop_labels.size()):
		var dl: Label = drop_labels[i]
		var is_alive := (i < current_lives)
		var tw = page.create_tween()
		tw.set_parallel(true)
		tw.tween_property(dl, "modulate:a", 1.0 if is_alive else 0.7, 0.2)
		tw.tween_property(dl, "scale", Vector2(1.0, 1.0), 0.25).from(Vector2(0.2, 0.2))
		if AudioManager and is_alive:
			AudioManager.play_collect()
		if not await _score_page_alive(0.18, page):
			return

	# 3. Evaporate dead drops (float upward + fade out)
	for i in range(drop_labels.size()):
		if i >= current_lives:
			var dl: Label = drop_labels[i]
			var evap = page.create_tween()
			evap.set_parallel(true)
			evap.tween_property(dl, "position:y", dl.position.y - 40, 0.6)
			evap.tween_property(dl, "modulate:a", 0.15, 0.6)
			evap.tween_property(dl, "scale", Vector2(0.6, 1.3), 0.6)
			if AudioManager:
				AudioManager.play_damage()

	# 4. Show flavor text
	if not await _score_page_alive(0.2, page):
		return
	var flav_tw = page.create_tween()
	flav_tw.tween_property(flavor, "modulate:a", 1.0, 0.25)

	# 5. Score count-up (from previous session total → new session total)
	if not await _score_page_alive(0.15, page):
		return
	score_display.modulate.a = 1.0
	score_caption.modulate.a = 1.0
	var prev_total := session_total - round_score
	var count_steps := mini(round_score, 30)
	if count_steps > 0:
		score_display.text = str(prev_total)
		for step in range(count_steps + 1):
			var val = int(lerp(float(prev_total), float(session_total), float(step) / float(count_steps)))
			score_display.text = str(val)
			if AudioManager and step % 3 == 0:
				AudioManager.play_score_tick()
			if not await _score_page_alive(0.03, page):
				return
	else:
		score_display.text = str(prev_total)
	score_display.text = str(session_total)

	# Pop the final number
	var pop_tw = page.create_tween()
	pop_tw.tween_property(score_display, "scale", Vector2(1.15, 1.15), 0.1)
	pop_tw.tween_property(score_display, "scale", Vector2(1.0, 1.0), 0.1)
	if AudioManager:
		AudioManager.play_bonus()

	# 6. Cascade stat pills
	if not await _score_page_alive(0.2, page):
		return
	for pill in pill_nodes:
		var ptw = page.create_tween()
		ptw.set_parallel(true)
		ptw.tween_property(pill, "modulate:a", 1.0, 0.2)
		ptw.tween_property(pill, "scale", Vector2(1.0, 1.0), 0.2).from(Vector2(0.85, 0.85))
		if not await _score_page_alive(0.12, page):
			return

	# 7. Session total bar
	if not await _score_page_alive(0.15, page):
		return
	var stw = page.create_tween()
	stw.tween_property(session_bar, "modulate:a", 1.0, 0.25)

	# 8. Idle bounce on alive drops while user views the page
	for i in range(mini(current_lives, drop_labels.size())):
		var dl: Label = drop_labels[i]
		var bounce = page.create_tween().set_loops(4)
		bounce.tween_property(dl, "position:y", dl.position.y - 6, 0.25).set_delay(i * 0.12)
		bounce.tween_property(dl, "position:y", dl.position.y, 0.25)

	# Hold for viewing
	if not await _score_page_alive(2.5, page):
		return

	# 9. Fade out
	var out_tw = page.create_tween()
	out_tw.tween_property(page, "modulate:a", 0.0, 0.35)
	await _score_page_alive(0.35, page)
	if is_instance_valid(page):
		page.queue_free()
	# Music stop is handled by the page's tree_exiting handler, so it fires on this
	# path and on every early return above.

## Await `sig`, giving up after `timeout_sec`. Returns true if the signal arrived.
##
## Cutscene clips announce their own completion, and the round-advance chain hangs
## off that announcement. If a clip is freed mid-play — scene change, quit to menu,
## app teardown — the signal never arrives, and a bare `await` parks the round for
## good with no path back to the menu. Racing the signal against the frame clock
## means the sequence always continues.
##
## The timeout is a safety net sized well past any authored clip, not a pacing
## knob: if it ever fires, a clip failed to signal and that is worth seeing in the
## log rather than silently swallowing.
func _await_signal_or_timeout(sig: Signal, timeout_sec: float) -> bool:
	if not is_inside_tree():
		return false
	var state := {"fired": false}
	sig.connect(func() -> void: state["fired"] = true, CONNECT_ONE_SHOT)
	var deadline: int = Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not state["fired"]:
		if not is_inside_tree():
			return false
		if Time.get_ticks_msec() >= deadline:
			push_warning(
				"MiniGameBase: cutscene signal did not arrive within %.1fs; continuing."
				% timeout_sec)
			return false
		await get_tree().process_frame
	return true

## Await `seconds` of PLAY, not of wall clock.
##
## SceneTree.create_timer()'s second parameter is process_always and it DEFAULTS TO
## TRUE, so the bare `await get_tree().create_timer(0.4).timeout` that every minigame
## used for its respawn and resolve delays kept counting while get_tree().paused was
## true. The rest of the round does not: _on_pause_pressed() (:1684) pauses the tree,
## which freezes _process, the round Timer node and every tween. So a pause stopped
## the game but not its delays -- the next target spawned behind the pause overlay,
## and on a quota-completing tap end_game() itself ran with the pause menu still up,
## banking a score, a life and one adaptive-difficulty sample the player never saw.
##
## On Android this is routine rather than rare: MobileUIManager._on_app_focus_lost()
## pauses the tree when the app is backgrounded, so a pulled-down notification lands
## inside these sub-second windows constantly.
##
## Returns the Signal, so both call shapes at the 26 sites keep reading naturally:
##     await round_delay(0.4)
##     round_delay(0.6).connect(_check_match)
## Post-round waits deliberately do NOT use this -- once the score page is up the
## pause button is gone and the wait ends in a scene change; see _score_page_alive().
func round_delay(seconds: float) -> Signal:
	return get_tree().create_timer(seconds, false).timeout


## Await `seconds`, then report whether the score page is still safe to touch.
##
## Every await in _show_round_score_page is a point where the player can quit, the
## round can be advanced, or the app can be backgrounded — any of which frees this
## node and its page while the coroutine is parked. Resuming blind then writes to
## freed Labels, and at app exit the coroutine never resumes at all, stranding its
## GDScriptFunctionState (visible as an ObjectDB leak on shutdown).
##
## Returning a bool lets each step bail out at its own await instead of the
## sequence being wrapped in validity checks after the fact.
func _score_page_alive(seconds: float, page: Control) -> bool:
	if not is_inside_tree():
		return false
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
	return (
		is_inside_tree()
		and is_instance_valid(page)
		and not page.is_queued_for_deletion()
	)

func _resolve_cutscene_scene(kind: String) -> PackedScene:
	var key = _get_minigame_key()
	var specific_path = ""
	var generic_path = ""

	if kind == "intro":
		specific_path = "res://scenes/ui/cutscenes/intro/%sIntro.tscn" % key
		generic_path = "res://scenes/ui/cutscenes/MiniGameIntroCutscene.tscn"
	else:
		specific_path = "res://scenes/ui/cutscenes/outro/%sOutro.tscn" % key
		generic_path = "res://scenes/ui/cutscenes/MiniGameOutroCutscene.tscn"

	if ResourceLoader.exists(specific_path):
		return load(specific_path) as PackedScene
	if ResourceLoader.exists(generic_path):
		return load(generic_path) as PackedScene
	return null

func _get_result_reaction(success: bool) -> Dictionary:
	var key = _get_minigame_key()
	var line = _get_result_line_for_key(success, key)

	if success:
		return {
			"character": "😎",
			"line": line,
			"color": Color(0.45, 1.0, 0.55)
		}
	return {
		"character": "😵",
		"line": line,
		"color": Color(1.0, 0.5, 0.3)
	}

func _get_result_line_for_key(success: bool, key: String) -> String:
	# The narrative line wins over the short result lines below -- it is per-game and
	# funnier. It goes through _narrative() so the Filipino build gets Filipino here.
	var _narr: String = _narrative(key, "win" if success else "fail")
	if not _narr.is_empty():
		return _narr
	if success:
		match key:
			"RiceWashRescue":
				return _loc(
					"result_line_success_rice_wash_rescue",
					"Rice water saved. Smart kitchen move!"
				)
			"VegetableBath":
				return _loc(
					"result_line_success_vegetable_bath",
					"Veggies cleaned with one smart rinse!"
				)
			"GreywaterSorter":
				return _loc(
					"result_line_success_greywater_sorter",
					"Greywater routed to the right use!"
				)
			"WringItOut":
				return _loc(
					"result_line_success_wring_it_out",
					"Nice squeeze. Every drop counted!"
				)
			"ThirstyPlant":
				return _loc(
					"result_line_success_thirsty_plant",
					"Plant hydrated with just enough water!"
				)
			"MudPieMaker":
				return _loc(
					"result_line_success_mud_pie_maker",
					"Mud mix perfect. Zero waste vibes!"
				)
			"CatchTheRain":
				return _loc(
					"result_line_success_catch_the_rain",
					"Rain caught clean. Tanks up!"
				)
			"CoverTheDrum":
				return _loc(
					"result_line_success_cover_the_drum",
					"Drum covered in time. Great reflex!"
				)
			"SpotTheSpeck":
				return _loc(
					"result_line_success_spot_the_speck",
					"All impurities spotted. Crystal clear!"
				)
			"FixLeak":
				return _loc(
					"result_line_success_fix_leak",
					"Leak fixed fast. Flow restored!"
				)
			"RainwaterHarvesting":
				return _loc(
					"result_line_success_rainwater_harvesting",
					"Harvest complete. Rain put to work!"
				)
			"WaterPlant":
				return _loc(
					"result_line_success_water_plant",
					"Perfect pour. Happy roots!"
				)
			"PlugTheLeak":
				return _loc(
					"result_line_success_plug_the_leak",
					"Pipe plugged. Waste stopped cold!"
				)
			"SwipeTheSoap":
				return _loc(
					"result_line_success_swipe_the_soap",
					"Soap swipe efficiency unlocked!"
				)
			"QuickShower":
				return _loc(
					"result_line_success_quick_shower",
					"Quick shower run. Big water saved!"
				)
			"FilterBuilder":
				return _loc(
					"result_line_success_filter_builder",
					"Filter stack built like a pro!"
				)
			"ToiletTankFix":
				return _loc(
					"result_line_success_toilet_tank_fix",
					"Tank tuned right. No excess flush!"
				)
			"TracePipePath":
				return _loc(
					"result_line_success_trace_pipe_path",
					"Path traced clean. Nice routing!"
				)
			"ScrubToSave":
				return _loc(
					"result_line_success_scrub_to_save",
					"Scrub done water-wise. Spotless!"
				)
			"BucketBrigade":
				return _loc(
					"result_line_success_bucket_brigade",
					"Relay complete. Team flow secured!"
				)
			"TimingTap":
				return _loc(
					"result_line_success_timing_tap",
					"Tap timing nailed. Zero extra drip!"
				)
			"TurnOffTap":
				return _loc(
					"result_line_success_turn_off_tap",
					"Tap shut off right on cue!"
				)
			"CloudCatcher":
				return _loc(
					"result_line_success_cloud_catcher",
					"Rain landed on roots. Free water, zero waste!"
				)
			_:
				return _loc(
					"result_line_success_default",
					"Clean save! Keep it flowing!"
				)

	match key:
		"RiceWashRescue":
			return _loc("result_line_fail_rice_wash_rescue", "Rice water spilled. Retry!")
		"VegetableBath":
			return _loc(
				"result_line_fail_vegetable_bath",
				"Too much rinse. One-pass next!"
			)
		"GreywaterSorter":
			return _loc("result_line_fail_greywater_sorter", "Wrong route. Sort cleaner!")
		"WringItOut":
			return _loc("result_line_fail_wring_it_out", "Still dripping. Wring harder!")
		"ThirstyPlant":
			return _loc(
				"result_line_fail_thirsty_plant",
				"Watering off-balance. Re-aim!"
			)
		"MudPieMaker":
			return _loc("result_line_fail_mud_pie_maker", "Mix missed. Steady hands!")
		"CatchTheRain":
			return _loc("result_line_fail_catch_the_rain", "Rain got away. Track drops!")
		"CoverTheDrum":
			return _loc(
				"result_line_fail_cover_the_drum",
				"Drum stayed open. Cover faster!"
			)
		"SpotTheSpeck":
			return _loc("result_line_fail_spot_the_speck", "Speck missed. Scan sharper!")
		"FixLeak":
			return _loc("result_line_fail_fix_leak", "Leak still live. Seal now!")
		"RainwaterHarvesting":
			return _loc(
				"result_line_fail_rainwater_harvesting",
				"Harvest missed. Reposition!"
			)
		"WaterPlant":
			return _loc(
				"result_line_fail_water_plant",
				"Watering off. Find the sweet spot!"
			)
		"PlugTheLeak":
			return _loc("result_line_fail_plug_the_leak", "Plug missed. Line it up!")
		"SwipeTheSoap":
			return _loc("result_line_fail_swipe_the_soap", "Swipe too slow. Clean cut!")
		"QuickShower":
			return _loc("result_line_fail_quick_shower", "Shower too long. Speed run!")
		"FilterBuilder":
			return _loc(
				"result_line_fail_filter_builder",
				"Wrong layer stack. Rebuild!"
			)
		"ToiletTankFix":
			return _loc("result_line_fail_toilet_tank_fix", "Tank unstable. Retune it!")
		"TracePipePath":
			return _loc("result_line_fail_trace_pipe_path", "Route drifted. Follow flow!")
		"ScrubToSave":
			return _loc(
				"result_line_fail_scrub_to_save",
				"Scrub wasted water. Stay tight!"
			)
		"BucketBrigade":
			return _loc("result_line_fail_bucket_brigade", "Relay broke pace. Move!")
		"TimingTap":
			return _loc("result_line_fail_timing_tap", "Timing off. Tap on beat!")
		"TurnOffTap":
			return _loc("result_line_fail_turn_off_tap", "Tap stayed on. Cut early!")
		"CloudCatcher":
			return _loc(
				"result_line_fail_cloud_catcher",
				"Rain hit concrete. Aim over the plants!"
			)
		_:
			return _loc(
				"result_line_fail_default",
				"Oops! Try a faster rescue next round!"
			)

func _show_failure_micro_cutscene() -> void:
	# See _show_success_micro_cutscene(): same missing stop, same scope.
	_play_scoped_music("outcome_fail", 0.18, self)

	# Try to use SimpleCutscenePlayer
	if animated_cutscene_player and animated_cutscene_player.has_method("play_cutscene"):
		animated_cutscene_player.visible = true
		animated_cutscene_player.play_cutscene(_get_minigame_key(), 1)  # 1 = FAIL
		await animated_cutscene_player.cutscene_finished
		animated_cutscene_player.visible = false
		return
	
	# Fallback to legacy emoji cutscene (only if SimpleCutscenePlayer not available)
	var data = _get_failure_cutscene_data()
	var cutscene = Control.new()
	cutscene.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(cutscene)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = data.get("bg", Color(0, 0, 0, 0.75))
	cutscene.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var icon = Label.new()
	icon.text = data.get("icon", "💥")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 110)
	vbox.add_child(icon)

	var line = Label.new()
	line.text = data.get("line", "That was close!")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 40)
	line.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	line.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_theme_constant_override("outline_size", 8)
	vbox.add_child(line)

	_play_cutscene_sfx("failure", str(data.get("anim", "wobble")), _get_minigame_key())

	_animate_failure_icon(icon, str(data.get("anim", "wobble")))

	var tw = create_tween()
	tw.tween_interval(float(data.get("hold", 0.55)))
	tw.tween_property(cutscene, "modulate:a", 0.0, 0.2)
	await tw.finished
	cutscene.queue_free()

func _show_success_micro_cutscene() -> void:
	# Scoped to the round, not to this coroutine: there is no per-call node on the
	# animated_cutscene_player path below (it returns early), and this function had
	# no stop_music at all.
	_play_scoped_music("outcome_win", 0.18, self)

	# Try to use SimpleCutscenePlayer
	if animated_cutscene_player and animated_cutscene_player.has_method("play_cutscene"):
		animated_cutscene_player.visible = true
		animated_cutscene_player.play_cutscene(_get_minigame_key(), 0)  # 0 = WIN
		await animated_cutscene_player.cutscene_finished
		animated_cutscene_player.visible = false
		return
	
	# Fallback to legacy emoji cutscene (only if SimpleCutscenePlayer not available)
	var data = _get_success_cutscene_data()
	var cutscene = Control.new()
	cutscene.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene.process_mode = Node.PROCESS_MODE_ALWAYS
	hud_layer.add_child(cutscene)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = data.get("bg", Color(0.02, 0.12, 0.06, 0.72))
	cutscene.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cutscene.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var icon = Label.new()
	icon.text = data.get("icon", "✨")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 110)
	vbox.add_child(icon)

	var line = Label.new()
	line.text = data.get("line", "Great save!")
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 40)
	line.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
	line.add_theme_color_override("font_outline_color", Color.BLACK)
	line.add_theme_constant_override("outline_size", 8)
	vbox.add_child(line)

	_play_cutscene_sfx("success", str(data.get("anim", "pop")), _get_minigame_key())

	_animate_success_icon(icon, str(data.get("anim", "pop")))

	var tw = create_tween()
	tw.tween_interval(float(data.get("hold", 0.48)))
	tw.tween_property(cutscene, "modulate:a", 0.0, 0.2)
	await tw.finished
	cutscene.queue_free()

func _get_success_cutscene_data() -> Dictionary:
	var key = _get_minigame_key()
	var presets = _get_success_cutscene_presets()
	var data: Dictionary = presets.get(key, {
		"icon": "✨",
		"line": "Clean save!",
		"anim": "pop",
		"bg": Color(0.02, 0.12, 0.06, 0.72),
		"hold": 0.48
	})
	var _win_line: String = _narrative(key, "win")
	if not _win_line.is_empty():
		var _dot := _win_line.find(". ")
		data["line"] = _win_line.left(_dot) if _dot > 0 else _win_line
	return data

## One narrative field, localized, with the table's English as the fallback.
##
## _get_narratives() is a hardcoded English Dictionary, and four player-visible
## surfaces read it: the intro screen's atmospheric line, the round score page's
## flavour line, and the two micro-cutscene lines. Reading it directly meant all
## of them were English in the Filipino build -- and because
## _get_result_line_for_key() checks the narrative FIRST, the narrative also
## shadowed all 46 result_line_* keys, so localizing those alone changed nothing
## on screen. Routing every read through here fixes both at once: the key is
## derived from the table key so no second table has to be kept in step, and a
## key that is absent from Localization falls back to the authored English, which
## is what shipped before.
func _narrative(key: String, field: String) -> String:
	var n: Dictionary = _get_narratives().get(key, {})
	var en: String = str(n.get(field, ""))
	if en.is_empty():
		return ""
	return _loc("narrative_%s_%s" % [key.to_snake_case(), field], en)

func _get_narratives() -> Dictionary:
	return {
		"CatchTheRain": {
			"intro": "The clouds finally show up. You have one drum. Gravity is merciless.",
			"win": "The drum overflows with glory. A tiny rainbow forms. You take a bow.",
			"fail": "You chase a red drop \"just to see.\" The drum fills with mystery liquid. A plant nearby dies on the spot.",
		},
		"CloudCatcher": {
			"intro": "Clouds drift past carrying free water. The plants below are extremely aware of this.",
			"win": "Every plant soaked straight from the sky. The clouds float off empty and smug. Not one drop of tap water spent.",
			"fail": "You pop the clouds over bare concrete. The rain hits pavement, steams off, and is gone. The plants are still thirsty, and now they're judging you.",
		},
		"CoverTheDrum": {
			"intro": "Standing water. Mosquitoes circling. They look personally offended.",
			"win": "Every drum sealed. The mosquitoes hold a sad little funeral. The water is safe.",
			"fail": "You miss one drum. Within seconds, a mosquito the size of a fist has claimed it as a condo. The water is lost. So is your dignity.",
		},
		"DropletDash": {
			"intro": "Water droplets are escaping. They are faster than you. They know this.",
			"win": "Every drop caught. The droplets look betrayed. You did good.",
			"fail": "The last droplet waves goodbye. The whole glass is empty. You're thirsty and it's your fault.",
		},
		"FilterBuilder": {
			"intro": "The water is brown. Very brown. Suspiciously brown.",
			"win": "Sparkling clean water pours out. A child somewhere drinks it gratefully. You are basically a hero.",
			"fail": "Wrong order. The dirt comes out worse. It looks like gravy. No one is drinking that.",
		},
		"FixLeak": {
			"intro": "The pipe is leaking. Dramatically. Personally.",
			"win": "The pipe is sealed. Silence. Peace. A single drip salutes you.",
			"fail": "You plug one, three more burst open. The room is now a splash park. The water bill is catastrophic.",
		},
		# Was a verbatim copy of FixLeak's copy. Same premise, different mechanic --
		# FixLeak is tap-to-seal several leaks, this one is hold-to-plug against a
		# waste budget -- and identical text on two games in one session reads as a bug.
		"PlugTheLeak": {
			"intro": "Pipes with holes. One thumb. Hold and hope.",
			"win": "Every leak held shut until the pressure dropped. Barely a litre lost. Your thumb is a hero.",
			"fail": "You let go early and the pipe rediscovers freedom. A hundred litres later the floor is a wading pool. The pipe seems happier than you.",
		},
		"GreywaterSorter": {
			"intro": "Two buckets. One for the garden. One for the drain. The water doesn't know the difference.",
			"win": "Every bucket sorted. The garden blooms. The drain thanks you for not dumping soap on it.",
			"fail": "Soapy water hits the tomatoes. They wilt in real time. The garden dies. The tomatoes had a name.",
		},
		"BucketBrigade": {
			"intro": "A line of people. One bucket. A very thirsty plant at the end.",
			"win": "The plant gets water. Everyone high-fives. Someone shouts \"TEAMWORK!\" unironically.",
			"fail": "You tap too slow. The third person in line sits down and eats a sandwich. The bucket goes nowhere. The plant writes a strongly worded letter.",
		},
		"QuickShower": {
			"intro": "A shower that runs forever. A water meter that cries.",
			"win": "Precise stop. Clean. Efficient. The water meter gives a thumbs up.",
			"fail": "You overshoot. The shower runs another 45 minutes. The meter explodes. You're clean but the planet is not.",
		},
		"RiceWashRescue": {
			"intro": "Nanay is washing rice. The rice water is gold. It is also running down the drain.",
			"win": "Basin full of precious starchy water. The plants are about to be very happy.",
			"fail": "The pot zigs, you zag. The rice water hits the drain. A single grain of rice rolls away in disappointment.",
		},
		"ScrubToSave": {
			"intro": "One dirty dish. One mission. Use as little water as possible.",
			"win": "Spotless dish. Minimum water used. The dish sparkles. A fork nearby applauds.",
			"fail": "You scrub in panic. The gauge drains dry. The dish is still dirty AND you wasted water. The dish does not sparkle. It judges you.",
		},
		"SpotTheSpeck": {
			"intro": "A row of water glasses. Some clean. Some containing things that should not be in water.",
			"win": "Perfect record. You are basically a water-quality inspector now. Add it to your resume.",
			"fail": "You approve the glass with a visible something floating in it. Someone drinks it. You don't want to know what happens next.",
		},
		"SwipeTheSoap": {
			"intro": "Handwashing. Quick. Purposeful. The soap has opinions.",
			"win": "Clean hands. Minimal water. The soap bar is impressed.",
			"fail": "You swipe wrong. The soap flies off the screen. You rinse with the tap full open for 30 seconds. The soap lands somewhere outside.",
		},
		"ThirstyPlant": {
			"intro": "Three buckets. One is the green one. You will second-guess yourself.",
			"win": "Correct bucket. The plant gets watered. It grows noticeably. It seems grateful.",
			"fail": "Wrong bucket. You pour fertilizer directly on the plant's face. It recoils. The real green bucket watches silently.",
		},
		"TimingTap": {
			"intro": "A tap. A container. A line that means \"enough.\"",
			"win": "Perfect fill. Not a drop over. The container does a little shimmy.",
			"fail": "You hold too long. It overflows spectacularly. The floor is now a small lake. The target line is underwater.",
		},
		"ToiletTankFix": {
			"intro": "The toilet is running. Constantly. It's been running since Tuesday.",
			"win": "Tank filled correctly. The phantom flush stops. Peace returns to the household.",
			"fail": "Overfilled. The tank overflows into the bowl into the floor into your problems. The Tuesday leak was less bad.",
		},
		"TracePipePath": {
			"intro": "The pipe is broken. Water is going to the wrong neighborhood.",
			"win": "Pipe connected. Water flows true. The neighborhood cheers.",
			"fail": "You draw off-path. Water detours through the kitchen ceiling. Everyone in the house gets an unexpected shower.",
		},
		"TurnOffTap": {
			"intro": "Multiple faucets. All running. Nobody knows why.",
			"win": "All taps off. Silence. The water bill sighs with relief.",
			"fail": "You can't keep up. Every tap you close, another opens in protest. The house is now a fountain. It's actually kind of beautiful. But wrong.",
		},
		"VegetableBath": {
			"intro": "Dirty vegetables. One wash bowl. A very particular basket system.",
			"win": "All veggies clean and sorted. Dinner is saved. Someone says \"you're actually useful.\"",
			"fail": "You throw a dirty carrot directly into the clean basket. Cross-contamination achieved. Dinner is canceled. The carrot is ashamed.",
		},
		"WaterMemory": {
			"intro": "Water-saving tips are flashing on cards. They vanish. Your brain says \"I got this.\"",
			"win": "All pairs matched. The tips are now burned into your brain. You will never run a tap unnecessarily again.",
			"fail": "You flip the wrong card every time. The cards start to look identical. You match \"Don't waste water\" with \"Turtle.\" That is not a pair.",
		},
		# Was a verbatim copy of WringItOut's laundry copy -- wrong game entirely: this
		# one is "keep every plant alive without drowning it", not wringing clothes.
		"WaterPlant": {
			"intro": "A shelf of plants, all quietly dehydrating. None of them will say anything.",
			"win": "Every plant still standing. Nobody drowned, nobody wilted. The shelf looks smug.",
			"fail": "One plant crisps up while you flood the one beside it. You have somehow overwatered AND underwatered the same shelf. The survivors are taking notes.",
		},
		"WringItOut": {
			"intro": "Wet laundry. A basin below. Physics awaiting.",
			"win": "Basin full, clothes dry enough. The water goes to the garden. The clothes go on the line.",
			"fail": "You tap too slowly. The clothes drip-dry on the floor instead. The basin has three drops in it. The garden sulks.",
		},
		"MudPieMaker": {
			"intro": "Children want mud pies. You have water. The gauge has opinions.",
			"win": "Perfect consistency. The mud pie is structurally sound. A child somewhere is delighted. You feel strangely proud.",
			"fail": "Too much water. The mud pie is now mud soup. It collapses immediately. The child is not delighted. You have failed mud.",
		},
		"RainwaterHarvesting": {
			"intro": "A drought. A storm on the way. Two people, four drums, one shot.",
			"win": "All drums full and sealed. Maximum harvest achieved. The rain stops. You two shake hands like you just ended the drought. Maybe you did.",
			"fail": "P2 misses an overflow redirect. P1 seals the wrong drum mid-fill. Water cascades everywhere. The storm passes. The drums are one-third full. The drought continues. So does your shame.",
		},
		"MP_CatchRainAquarium": {
			"intro": "It's raining. The fish tank is empty. Two people, one plan, zero coordination yet.",
			"win": "Tank filled to the line. The fish arrive and immediately look smug. Both players celebrate at each other through the screen.",
			"fail": "P2 overpours while P1 is still catching. The aquarium floods. The fish were never coming — they heard about you.",
		},
		"MP_CollectDishWater": {
			"intro": "Dishes need washing. Water needs saving. These two facts must coexist.",
			"win": "Dishes clean. Greywater saved. Two environmentalists nod at each other solemnly.",
			"fail": "P1 washes too slow; P2's bucket overflows waiting. The greywater hits the floor. Both players blame each other immediately.",
		},
		"MP_CollectLaundryWater": {
			"intro": "The washing machine is done. The rinse water is pure gold (well, soapy gold).",
			"win": "Every drop redirected. The laundry smells fine. The garden is thriving. You are sustainability icons.",
			"fail": "Buffer full — water spills onto the tiles. The rinse water is wasted. The tiles need mopping now too. You've created more problems.",
		},
		"MP_CollectShowerWater": {
			"intro": "Someone showered. The warm-up water just ran down the drain for four minutes. Not today.",
			"win": "Every warm-up litre saved. Both players feel personally responsible for fixing the water crisis. They are correct.",
			"fail": "P1 passes too fast. P2 drops a bucket. The bathroom is now a puddle. Nobody wins. The shower just watches.",
		},
		"MP_FillAquarium": {
			"intro": "An empty tank. Two determined people. One correct water level line.",
			"win": "Perfect fill. The line is hit with surgical precision. A goldfish materializes from nowhere to say thank you.",
			"fail": "P2 signals too late. The tank overflows. The goldfish was watching from a distance and shakes its tiny head.",
		},
		"MP_FilterWater": {
			"intro": "The water is not drinking quality. It is barely looking-at quality.",
			"win": "Crystal-clear output. Both players look at it like they made something beautiful. They did.",
			"fail": "P2 stacks layers wrong while P1 pours too fast. Output is brownish. It is somehow more brown than the input. Science has failed you.",
		},
		"MP_FlushToilets": {
			"intro": "Low-flush challenge. The toilet does not care. It wants a full tank. You're giving it half.",
			"win": "Clean flush. Perfect pressure. The toilet is satisfied. This is the most empowering moment in water conservation.",
			"fail": "P2 flushes too early with only a quarter tank. It does not clear. The situation escalates quickly. You both pretend it didn't happen.",
		},
		"MP_MopFloor": {
			"intro": "The floor is dirty. You have a plan to use recycled water. The floor has no opinions but the outcome does.",
			"win": "Spotless floor. Zero fresh water used. You have mopped sustainably. Tell everyone you know.",
			"fail": "P1 passes an unfiltered bucket. P2 spreads the dirt evenly across the entire floor. It is now uniformly dirty — which is arguably worse. Congratulations.",
		},
		"MP_WashCar": {
			"intro": "Dirty car. Two buckets of rainwater. No hose permitted.",
			"win": "Shiny car. Zero hose used. Both players stare at it appreciatively. A neighbor walks by and is impressed.",
			"fail": "P1's timing is off. P2 is mid-scrub with a dry sponge. The dirt smears. The car now has abstract art on it. The neighbor walks past again, confused.",
		},
		"MP_WashVegetables": {
			"intro": "Market-fresh vegetables. Soil still attached. A basin of recycled water awaiting.",
			"win": "All veggies clean. Basin water saved for irrigation. Dinner and the environment both win.",
			"fail": "P2 sends a dirty vegetable to the tray. P1 sends five more before noticing. The \"clean\" tray is now the dirty tray. Nobody eats salad tonight.",
		},
		"MP_WaterPlants": {
			"intro": "Thirsty plants. Greywater supply. A pipe system held together by teamwork and optimism.",
			"win": "Every pot watered correctly. The garden is lush. A butterfly appears. Both players feel personally responsible for that butterfly.",
			"fail": "P1 releases too much at once; P2 can't redirect fast enough. Three pots overflow. One plant drowns. It was a cactus. A cactus.",
		},
	}

func _get_success_cutscene_presets() -> Dictionary:
	return {
		"RiceWashRescue": {
			"icon": "🍚",
			"line": "Rice water rescued!",
			"anim": "pop",
			"bg": Color(0.09, 0.12, 0.05, 0.72)
		},
		"VegetableBath": {
			"icon": "🥬",
			"line": "Veggies cleaned with less water!",
			"anim": "bounce",
			"bg": Color(0.04, 0.12, 0.05, 0.72)
		},
		"GreywaterSorter": {
			"icon": "🛢",
			"line": "Greywater sorted perfectly!",
			"anim": "spin",
			"bg": Color(0.05, 0.1, 0.1, 0.72)
		},
		"WringItOut": {
			"icon": "🧽",
			"line": "Every drop squeezed back!",
			"anim": "pop",
			"bg": Color(0.03, 0.11, 0.09, 0.72)
		},
		"ThirstyPlant": {
			"icon": "🌱",
			"line": "Plant watered just right!",
			"anim": "bounce",
			"bg": Color(0.02, 0.12, 0.05, 0.72)
		},
		"MudPieMaker": {
			"icon": "🥧",
			"line": "Mud mix nailed!",
			"anim": "spin",
			"bg": Color(0.1, 0.08, 0.04, 0.72)
		},
		"CatchTheRain": {
			"icon": "🌧",
			"line": "Rain captured cleanly!",
			"anim": "drop",
			"bg": Color(0.02, 0.1, 0.13, 0.74)
		},
		"CoverTheDrum": {
			"icon": "🛢",
			"line": "Drum protected in time!",
			"anim": "pop",
			"bg": Color(0.03, 0.1, 0.12, 0.74)
		},
		"SpotTheSpeck": {
			"icon": "🔍",
			"line": "All specks detected!",
			"anim": "spin",
			"bg": Color(0.03, 0.11, 0.11, 0.72)
		},
		"FixLeak": {
			"icon": "🔧",
			"line": "Leak sealed!",
			"anim": "pop",
			"bg": Color(0.02, 0.1, 0.12, 0.74)
		},
		"RainwaterHarvesting": {
			"icon": "☔",
			"line": "Rainwater harvest complete!",
			"anim": "drop",
			"bg": Color(0.02, 0.1, 0.13, 0.74)
		},
		"WaterPlant": {
			"icon": "🌿",
			"line": "Healthy watering rhythm!",
			"anim": "bounce",
			"bg": Color(0.02, 0.12, 0.05, 0.72)
		},
		"PlugTheLeak": {
			"icon": "🔩",
			"line": "Pipe patched under pressure!",
			"anim": "pop",
			"bg": Color(0.02, 0.1, 0.12, 0.74)
		},
		"SwipeTheSoap": {
			"icon": "🧼",
			"line": "Soap swipe efficiency!",
			"anim": "spin",
			"bg": Color(0.03, 0.11, 0.12, 0.72)
		},
		"QuickShower": {
			"icon": "🚿",
			"line": "Quick shower master!",
			"anim": "bounce",
			"bg": Color(0.03, 0.1, 0.13, 0.74)
		},
		"FilterBuilder": {
			"icon": "🧪",
			"line": "Perfect filter stack!",
			"anim": "spin",
			"bg": Color(0.03, 0.11, 0.1, 0.72)
		},
		"ToiletTankFix": {
			"icon": "🚽",
			"line": "Tank tuned and sealed!",
			"anim": "pop",
			"bg": Color(0.04, 0.1, 0.12, 0.72)
		},
		"TracePipePath": {
			"icon": "🧭",
			"line": "Pipe path traced cleanly!",
			"anim": "spin",
			"bg": Color(0.03, 0.09, 0.12, 0.72)
		},
		"ScrubToSave": {
			"icon": "💦",
			"line": "Spotless and water-wise!",
			"anim": "bounce",
			"bg": Color(0.03, 0.11, 0.12, 0.72)
		},
		"BucketBrigade": {
			"icon": "💧",
			"line": "Relay run delivered!",
			"anim": "drop",
			"bg": Color(0.03, 0.1, 0.12, 0.72)
		},
		"TimingTap": {
			"icon": "🎯",
			"line": "Tap timing on point!",
			"anim": "pop",
			"bg": Color(0.04, 0.09, 0.12, 0.72)
		},
		"TurnOffTap": {
			"icon": "🚰",
			"line": "Tap turned off right on cue!",
			"anim": "bounce",
			"bg": Color(0.02, 0.1, 0.13, 0.72)
		}
	}

func _animate_success_icon(icon: Label, anim: String) -> void:
	var tw = create_tween()
	match anim:
		"spin":
			tw.tween_property(icon, "rotation", TAU, 0.32).from(0.0)
		"bounce":
			tw.tween_property(icon, "position:y", icon.position.y - 20, 0.10)
			tw.tween_property(icon, "position:y", icon.position.y + 8, 0.10)
			tw.tween_property(icon, "position:y", icon.position.y, 0.09)
		"drop":
			tw.tween_property(icon, "position:y", icon.position.y + 18, 0.10)
			tw.tween_property(icon, "position:y", icon.position.y, 0.10)
		_:
			tw.tween_property(icon, "scale", Vector2(1.15, 1.15), 0.11)
			tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.11)

func _play_cutscene_sfx(kind: String, anim: String, key: String) -> void:
	if not AudioManager:
		return

	if kind == "success":
		AudioManager.play_success()
		match anim:
			"spin":
				AudioManager.play_bonus()
			"drop":
				AudioManager.play_water_drop()
			"bounce":
				AudioManager.play_collect()
			_:
				AudioManager.play_click()

		# Water-themed wins get an extra splash accent.
		if (
			"Rain" in key
			or "Leak" in key
			or "Water" in key
			or "Tap" in key
		):
			AudioManager.play_water_splash()
		return

	# Failure branch
	AudioManager.play_failure()
	match anim:
		"shake":
			AudioManager.play_damage()
		"drop":
			AudioManager.play_water_drop()
		"spin":
			AudioManager.play_warning()
		_:
			AudioManager.play_click()

	if (
		"Rain" in key
		or "Leak" in key
		or "Water" in key
		or "Tap" in key
	):
		AudioManager.play_water_drop()

func _get_failure_cutscene_data() -> Dictionary:
	var key = _get_minigame_key()
	var presets = _get_failure_cutscene_presets()
	var data: Dictionary = presets.get(key, {
		"icon": "💥",
		"line": "Mission failed. Retry incoming!",
		"anim": "wobble",
		"bg": Color(0, 0, 0, 0.75),
		"hold": 0.55
	})
	var _fail_line: String = _narrative(key, "fail")
	if not _fail_line.is_empty():
		var _dot := _fail_line.find(". ")
		data["line"] = _fail_line.left(_dot) if _dot > 0 else _fail_line
	return data

func _get_minigame_key() -> String:
	if get_script() and get_script().resource_path != "":
		var file_name = get_script().resource_path.get_file()
		var base_name = file_name.trim_suffix(".gd")
		# The v2 rehaul scripts are named <Game>V2.gd while every lookup table
		# (narratives, failure presets, cartoon stages, beat outro clip paths)
		# keys on the bare game name — strip the suffix here, once, for all
		# call sites (verified empirically via tools probe: without this,
		# "CatchTheRain.tscn" resolved to key "CatchTheRainV2" and missed).
		if base_name.ends_with("V2"):
			base_name = base_name.trim_suffix("V2")
		if base_name != "":
			return base_name
	# Fallback. Not reachable from the shipped game - every round is a .tscn instance, so
	# its script always has a resource_path - but what it returns matters if it ever is,
	# because this key is what high scores, completed_minigames and the narrative /
	# cartoon-stage tables are stored under. It used to be game_name.replace(" ", ""), the
	# DISPLAY TITLE: FixLeakV2 builds game_name from Localization, so under Filipino this
	# line would have written "AyusinAngTagas" into the save file as a game id and split one
	# game's history across two keys. tools/VerifyGameIdentity [5]-[7] assert that no save
	# row is ever keyed by a title, and a fallback that quietly breaks that rule is worse
	# than one that refuses. The scene path is the same id under every language.
	if scene_file_path != "":
		return scene_file_path.get_file().trim_suffix(".tscn").trim_suffix("V2")
	push_error("MiniGameBase: no script path and no scene path for '%s' - falling back to the node name" % name)
	return name

func _get_failure_cutscene_presets() -> Dictionary:
	return {
		"RiceWashRescue": {
			"icon": "🍚",
			"line": "Rice water spilled away!",
			"anim": "drop",
			"bg": Color(0.08, 0.05, 0.02, 0.8)
		},
		"VegetableBath": {
			"icon": "🥬",
			"line": "Veggies wasted the wash water!",
			"anim": "spin",
			"bg": Color(0.03, 0.08, 0.03, 0.8)
		},
		"GreywaterSorter": {
			"icon": "🛢",
			"line": "Greywater got contaminated!",
			"anim": "shake",
			"bg": Color(0.06, 0.06, 0.08, 0.8)
		},
		"WringItOut": {
			"icon": "🧽",
			"line": "Still dripping! Wring tighter!",
			"anim": "wobble",
			"bg": Color(0.04, 0.07, 0.09, 0.8)
		},
		"ThirstyPlant": {
			"icon": "🌱",
			"line": "Plant stayed thirsty this round!",
			"anim": "drop",
			"bg": Color(0.03, 0.09, 0.04, 0.8)
		},
		"MudPieMaker": {
			"icon": "🥧",
			"line": "Too much water in the mud mix!",
			"anim": "spin",
			"bg": Color(0.09, 0.06, 0.03, 0.8)
		},
		"CatchTheRain": {
			"icon": "🌧",
			"line": "Rain escaped the bucket!",
			"anim": "drop",
			"bg": Color(0.02, 0.05, 0.1, 0.82)
		},
		"CoverTheDrum": {
			"icon": "🛢",
			"line": "Drum left open in the rain!",
			"anim": "shake",
			"bg": Color(0.03, 0.06, 0.1, 0.82)
		},
		"SpotTheSpeck": {
			"icon": "🔍",
			"line": "Missed particles in the water!",
			"anim": "wobble",
			"bg": Color(0.03, 0.07, 0.09, 0.8)
		},
		"FixLeak": {
			"icon": "💧",
			"line": "Leak burst! Water escaped!",
			"anim": "drop",
			"bg": Color(0.02, 0.05, 0.09, 0.82)
		},
		"RainwaterHarvesting": {
			"icon": "🌧",
			"line": "Harvest missed the downpour!",
			"anim": "drop",
			"bg": Color(0.02, 0.05, 0.1, 0.82)
		},
		"WaterPlant": {
			"icon": "🌿",
			"line": "Plant got the wrong amount!",
			"anim": "wobble",
			"bg": Color(0.03, 0.08, 0.04, 0.8)
		},
		"PlugTheLeak": {
			"icon": "🔧",
			"line": "Pipe pressure won this time!",
			"anim": "shake",
			"bg": Color(0.03, 0.05, 0.09, 0.82)
		},
		"SwipeTheSoap": {
			"icon": "🧼",
			"line": "Soap slipped and water ran!",
			"anim": "spin",
			"bg": Color(0.04, 0.08, 0.1, 0.8)
		},
		"QuickShower": {
			"icon": "🚿",
			"line": "Shower time exceeded target!",
			"anim": "shake",
			"bg": Color(0.03, 0.06, 0.1, 0.82)
		},
		"FilterBuilder": {
			"icon": "🧪",
			"line": "Wrong filter stack!",
			"anim": "spin",
			"bg": Color(0.04, 0.07, 0.09, 0.8)
		},
		"ToiletTankFix": {
			"icon": "🚽",
			"line": "Tank setup leaked again!",
			"anim": "wobble",
			"bg": Color(0.04, 0.06, 0.09, 0.8)
		},
		"TracePipePath": {
			"icon": "🧭",
			"line": "Pipe route got crossed!",
			"anim": "spin",
			"bg": Color(0.04, 0.05, 0.08, 0.8)
		},
		"ScrubToSave": {
			"icon": "🧼",
			"line": "Scrub wasted too much water!",
			"anim": "shake",
			"bg": Color(0.05, 0.07, 0.09, 0.8)
		},
		"BucketBrigade": {
			"icon": "💧",
			"line": "Bucket relay broke down!",
			"anim": "drop",
			"bg": Color(0.04, 0.06, 0.09, 0.82)
		},
		"TimingTap": {
			"icon": "⏱",
			"line": "Tap timing missed the beat!",
			"anim": "wobble",
			"bg": Color(0.04, 0.05, 0.08, 0.8)
		},
		"TurnOffTap": {
			"icon": "🚰",
			"line": "Tap stayed on too long!",
			"anim": "shake",
			"bg": Color(0.03, 0.06, 0.1, 0.82)
		},
		# The last three games in the roster had no preset at all, so their failure beat
		# fell through to the generic 💥 + "wobble" while every other game got an icon and
		# a motion that matched what had just gone wrong. The LINE was never the problem
		# (_get_failure_cutscene_data overwrites it with the narrative fail line), the
		# mismatched icon and animation were -- exactly the "wrong action for the moment"
		# case the animation audit is looking for. Found by tools/VerifyNarrativeCopy.
		"CloudCatcher": {
			"icon": "☁",
			"line": "Rain fell on bare concrete!",
			"anim": "drop",
			"bg": Color(0.05, 0.07, 0.1, 0.82)
		},
		"WaterMemory": {
			"icon": "🃏",
			"line": "The pairs slipped your mind!",
			"anim": "shake",
			"bg": Color(0.05, 0.06, 0.09, 0.82)
		},
		"DropletDash": {
			"icon": "🏃",
			"line": "The droplets got away!",
			"anim": "spin",
			"bg": Color(0.04, 0.06, 0.09, 0.82)
		}
	}

func _animate_failure_icon(icon: Label, anim: String) -> void:
	var tw = create_tween()
	match anim:
		"spin":
			tw.tween_property(icon, "rotation", TAU, 0.35).from(0.0)
		"shake":
			tw.tween_property(icon, "position:x", icon.position.x + 22, 0.06)
			tw.tween_property(icon, "position:x", icon.position.x - 22, 0.06)
			tw.tween_property(icon, "position:x", icon.position.x + 14, 0.06)
			tw.tween_property(icon, "position:x", icon.position.x, 0.06)
		"drop":
			tw.tween_property(icon, "position:y", icon.position.y + 24, 0.14)
			tw.tween_property(icon, "position:y", icon.position.y, 0.14)
		_:
			tw.tween_property(icon, "rotation", 0.12, 0.08).from(-0.12)
			tw.tween_property(icon, "rotation", -0.08, 0.08)
			tw.tween_property(icon, "rotation", 0.04, 0.08)
			tw.tween_property(icon, "rotation", 0.0, 0.08)

## REMOVED: _show_game_over() lived here and nothing called it, in this class or any
## of the 24 subclasses -- the only live callers of that name are NetworkManager's own
## RPC and MultiplayerCoordinator's local function, both unrelated. It built an 80 px
## red "GAME OVER!" Label at viewport_centre - 250 px, held it on a pause-blind
## create_timer, then jumped straight to InitialScreen, skipping the results screen,
## the score tally and the educational outro. Three separate things the rest of the
## file had already moved past: the bare verdict (every live failure now reads a
## narrative reaction line), the hardcoded centring (layout goes through anchors),
## and the pause-blind delay (FIX 42/46). Deleted rather than banner-marked because a
## fossil that spells the word this project is removing invites reuse.

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# OVERRIDE THESE IN CHILD CLASSES
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_game_start() -> void:
	# Override: Initialize game-specific logic
	pass

func _on_correct_action() -> void:
	# Override: Handle correct action feedback
	_play_success_effect()

func _on_mistake() -> void:
	# Override: Handle mistake feedback
	_play_mistake_effect()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# JUICE/POLISH EFFECTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _play_success_effect() -> void:
	# Screen flash
	_flash_screen(Color(0.3, 1.0, 0.3, 0.3))
	# Would play sound here

func _play_mistake_effect() -> void:
	# Screen flash
	_flash_screen(Color(1.0, 0.3, 0.3, 0.3))
	# Would play sound here
	
	# Screen shake
	if AdaptiveDifficulty:
		var shake_intensity = AdaptiveDifficulty.get_screen_shake_intensity()
		if shake_intensity > 0:
			_shake_camera(shake_intensity)

func _flash_screen(color: Color) -> void:
	var flash = ColorRect.new()
	flash.color = color
	flash.size = get_viewport_rect().size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	
	var tween = create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	tween.finished.connect(flash.queue_free)

func _shake_camera(intensity: float) -> void:
	if not _is_screen_shake_allowed():
		return

	var camera = get_viewport().get_camera_2d()
	if camera:
		var original_offset = camera.offset
		
		var tween = create_tween()
		for i in range(5):
			tween.tween_property(camera, "offset", original_offset + Vector2(
				randf_range(-intensity * 10, intensity * 10),
				randf_range(-intensity * 10, intensity * 10)
			), 0.05)
		tween.tween_property(camera, "offset", original_offset, 0.05)

## Android Back inside a round: toggle the pause overlay, never leave.
##
## Called by GameManager.handle_back_request(). Returning true claims the gesture, so
## the fallback that sends every other screen to the hub does not run here - a round
## carries score, a life and one sample of algorithm data, and a stray Back gesture
## must not discard them.
##
## Back over the tally/outro is consumed and ignored on purpose. game_active is false
## there, so _on_pause_pressed() would refuse anyway, and the alternative - falling
## through to the hub - would abandon the round score page mid-presentation. The
## presentation finishes on its own and advances, so nothing is stuck.
func on_back_requested() -> bool:
	if pause_menu and is_instance_valid(pause_menu) and pause_menu.visible:
		_on_resume_pressed()
		return true
	if game_active:
		_on_pause_pressed()
		return true
	return true


## Keeps a bare Control tap target centred on its Node2D anchor even after the mobile
## floor grows it.
##
## A fixture that authors a 100x100 Button at position (-50, -50) is centred on its art -
## until MobileUIManager._on_node_added() raises custom_minimum_size to the 48dp floor
## (147 canvas units on WVGA), at which point the Control grows right and down from that
## same top-left and the hit area slides off the art by half the difference: 24 units on
## a phone, in the direction the finger is least likely to be. Measured on
## CloudCatcher's cloud button and TurnOffTap's TapButton by tools/VerifyTouchTargets.
##
## Re-centring on the resized signal covers the initial layout pass, the growth pass, and
## any later change - the large_touch_targets accessibility toggle re-runs the floor and
## resizes every button again.
func centre_hit_control(c: Control) -> void:
	if c == null or c.has_meta("hit_centred"):
		return
	c.set_meta("hit_centred", true)
	c.position = -c.size * 0.5
	var recentre := func() -> void:
		if is_instance_valid(c):
			c.position = -c.size * 0.5
	c.resized.connect(recentre)
