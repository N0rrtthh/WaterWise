extends Node

## ═══════════════════════════════════════════════════════════════════
## AUTO-PLAY MANAGER - Automated Testing Mode
## ═══════════════════════════════════════════════════════════════════
## Automatically plays mini-games for performance testing and data collection
## without human intervention.
##
## Purpose: Collect thermal throttling, battery drain, and performance stats
## during long automated testing sessions.
##
## Features:
## - Works in both Single-Player and Multiplayer modes
## - Adapts to different mini-game mechanics (tap, drag, swipe, timing)
## - Plays optimally to generate consistent performance data
## - Toggleable via dev_mode in Settings
##
## Usage:
## 1. Enable "Dev Mode" in Settings
## 2. Enable "Auto-Play Mode" toggle
## 3. Start playing - the AI will take over gameplay
## ═══════════════════════════════════════════════════════════════════

signal state_changed(is_enabled: bool)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-PLAY STATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var auto_play_enabled: bool = false
var mp_auto_play_enabled: bool = false  # Separate toggle for multiplayer only
var current_game: Node = null
var game_name: String = ""
var auto_play_strategy: String = ""  # tap, drag, swipe, timing, memory, trace
## How long a pause with nothing to dismiss is tolerated before the driver clears
## it. Long enough that a legitimate one-frame pause is not fought over, short
## enough that a soak loses seconds rather than the rest of the run.
const PAUSE_GRACE_SECONDS: float = 3.0
## Real seconds the tree has been paused with the bot running. Accumulated from
## _process's delta, which is real time because this autoload processes always.
var _paused_seconds: float = 0.0
## One resume attempt per pause episode. _process() runs while the tree is paused and a
## co-op resume is a network round trip, so without this the bot sent one request per
## frame until the state came back - the duplicated "Game resumed" lines in
## session_2026-09-05T00-27-36.json. Cleared the moment the tree is running again.
var _resume_requested: bool = false

# Duration settings (in seconds, 0 = unlimited)
var auto_play_duration: float = 0.0  # 0 = unlimited
## True ONLY while the deadline abort (_abort_round) is walking the round's own
## quit handler. SessionLogger reads it to stamp "interrupted_by_timeout" on the
## in-progress round the configured duration expired inside, so the Trepn+JSON
## dataset can filter deadline-cut rounds from real 0% failures.
var deadline_interrupt_active: bool = false
var auto_play_start_time: int = 0
var auto_play_elapsed: float = 0.0

# MP-specific duration (mirrors SP duration concept)
var mp_auto_play_duration: float = 0.0  # 0 = unlimited
var mp_auto_play_start_time: int = 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-PLAY BEHAVIOR TIMERS & STATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var action_timer: float = 0.0
var action_interval: float = 0.3  # Default interval between actions
var drag_target: Vector2 = Vector2.ZERO
var is_dragging: bool = false
## The bot's synthetic finger: at most one is down at a time, and it is always
## lifted when the bot stops driving. See _drive_pointer().
var _pointer_down: bool = false
var _pointer_pos: Vector2 = Vector2.ZERO
## A lift asked for while the tree was paused. Input is not delivered to paused
## nodes, so the event would be swallowed and TouchInputManager would keep the
## finger in active_touches forever - the phantom touch its own code warns about.
## Retried at the top of _process(), which runs while paused.
var _pointer_release_pending: bool = false
var swipe_cooldown: float = 0.0
var tap_cooldown: float = 0.0
## Pre-allocated injection events for the bot's single synthetic finger (index 0).
##
## Reused across frames so a discrete _tap_at() does not churn .new() on the
## gameplay hot path. DOWN and UP are SEPARATE objects: Input.parse_input_event
## queues an event by reference, so mutating one object from pressed->released
## before the queue flushes would corrupt the down it just emitted. Each object
## is written once per tap and the queue is flushed before the next frame, so
## cross-frame reuse is safe.
var _tap_down_ev: InputEventScreenTouch = InputEventScreenTouch.new()
var _tap_up_ev: InputEventScreenTouch = InputEventScreenTouch.new()

## DropletDash lane scorer: how far up the lane an item still counts, in pixels.
##
## Items fall at obstacle_speed (200px/s base), the droplet sits at 0.75 * height and
## a lane step costs 0.12s of tween plus a 0.18s cooldown, so ~0.3s of travel (60px)
## is the minimum useful horizon. 600px is 3s of fall at base speed: far enough to
## commit to a collectible two lanes away, near enough that a freshly spawned item
## cannot outvote one about to land.
const DASH_LOOKAHEAD_PX: float = 600.0
## Score a rival lane must beat the current lane by before the bot commits to moving.
const DASH_SWITCH_MARGIN: float = 0.05
## Viewport-space margin the synthetic finger keeps from every screen edge.
##
## TouchInputManager rejects a touch START inside its 15px edge dead zone on mobile,
## which would leave the finger unpressed while this manager believed it was down.
const POINTER_INSET_PX: float = 24.0
## Minimum spacing between two injected discrete taps, in seconds.
##
## Guards _tap_at() against flooding the input queue when a handler runs every
## frame; _drive_pointer() (a continuous finger) is deliberately NOT throttled
## because a hold must be re-asserted each frame.
const TAP_INJECT_COOLDOWN: float = 0.08
var memory_pairs: Array = []

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HUMAN-SIMULATION REALISM LAYER (item 3 — strictly OPT-IN)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# A single realism layer consulted by the injection primitives (_tap_at,
# _start_gesture, _hold_at, _drag_to), so every game inherits it once. In
# PERFECT mode (the default) EVERY hook below is a no-op: gates return true
# without touching state and aim helpers return the input position unchanged,
# so behaviour is byte-identical to the pre-realism build. Nothing here ever
# runs for human gameplay — the primitives are only reachable from autoplay.

## A target that moves less than this between frames is treated as the SAME
## target, so the reaction clock keeps running instead of restarting every frame
## on a slowly-moving aim. A jump beyond it is a genuinely new target.
const HSIM_REACQUIRE_PX: float = 140.0
## How far off-target a deliberate miss aims, in pixels (randomised around it).
const HSIM_MISS_OFF_PX: float = 130.0
## Per-frame chance a continuous finger briefly "slips" off-target while held.
const HSIM_SLIP_CHANCE: float = 0.02
## Jitter on a CONTINUOUS finger is scaled down from the discrete magnitude: a
## hold that shook a full jitter radius every frame would read as a seizure, not
## a hand, and could walk straight out of a tight hit rect.
const HSIM_CONT_JITTER_SCALE: float = 0.6

## Loaded ONCE in _ready(); never rebuilt per action (zero per-frame cost).
var _hsim_profile: HumanSimProfile = null
## One pre-seeded generator for every roll — no per-action allocation.
var _hsim_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Time.get_ticks_msec() at which the pending reaction may fire; -1 = none.
var _hsim_reaction_ready_ms: int = -1
## The target position the pending reaction clock was started against.
var _hsim_reaction_target: Vector2 = Vector2.INF
## True once a continuous finger has cleared its ONE reaction delay and is
## driving; reset by _release_pointer() so the next engage re-delays.
var _hsim_hold_engaged: bool = false
## Diagnostic log of sampled reaction delays (ms). Populated ONLY in a non-PERFECT
## mode, so it stays empty (and free) during every Perfect-mode harness run.
## Read/cleared by tools/VerifyHumanSim.gd to prove run-to-run variance.
var hsim_reaction_samples: Array[int] = []

# Navigation state (used when no game is active — clicks through menus)
var nav_timer: float = 0.0
var nav_interval: float = 2.5  # Seconds to wait before each menu action
var memory_first_card: Node = null
var trace_path_index: int = 0

# ──────────────────────────────────────────────────────────────────
# MULTI-FRAME GESTURE SEQUENCER
# Several games read their pointer through _process pollers or a
# press->move->release event chain, so a single-frame down+up is never
# observed as a drag. _start_gesture() scripts a finger path (a list of
# VIEWPORT points) that _step_gesture() walks one waypoint per frame via
# _drag_to() (pressing on the first), then lifts on the frame after the
# last move so a poller sees the final position while the finger is down.
# A handler pumps it with:  `if _gest_active: _step_gesture(); return`.
# Reset at every round boundary (see _reset_gesture) so a scripted path
# from a finished game cannot resume driving the next one.
# ──────────────────────────────────────────────────────────────────
var _gest_pts: Array[Vector2] = []
var _gest_i: int = 0
var _gest_active: bool = false
var _gest_release_at_end: bool = true
var _gest_post_cooldown: float = 0.0
var _scrub_phase: bool = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PERFORMANCE STATS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var games_played: int = 0
var total_score: int = 0
var average_accuracy: float = 0.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _ready() -> void:
	# The bot must keep running while the tree is paused, because a pause is a
	# state it can enter by accident and cannot otherwise leave: get_tree().paused
	# stopped this _process, so the code that dismisses the overlay was frozen by
	# the overlay. Everything gameplay-related still returns early while paused —
	# see the guard in _process() — so this does not let the bot play through a
	# pause, only end one.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load saved auto-play preferences
	if SaveManager:
		auto_play_enabled = SaveManager.get_setting("auto_play_enabled", false)
		auto_play_duration = SaveManager.get_setting("auto_play_duration", 0.0)
	
	# Human-simulation realism (item 3): build the data-only profile ONCE here and
	# restore any persisted tuning. The default mode is PERFECT, so unless a real
	# windowed QA session explicitly opted in, every realism hook stays a no-op and
	# autoplay behaves exactly as it did before this layer existed.
	_hsim_profile = HumanSimProfile.new()
	_hsim_rng.randomize()
	_load_human_sim_settings()
	
	print("🤖 AutoPlayManager initialized (Auto-play: %s, Duration: %s, Sim: %s)" % [
		"ON" if auto_play_enabled else "OFF",
		_format_duration(auto_play_duration) if auto_play_duration > 0 else "Unlimited",
		_human_sim_mode_name(_hsim_profile.mode)
	])

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-PLAY CONTROL
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Turn auto-play on or off.
##
## `persist` exists for the soak harnesses in tools/, and it is not a convenience. They
## used to enable auto-play the way the Settings toggle does, which writes the flag into
## the player's real settings file - so a soak run killed rather than allowed to finish (a
## `timeout`, a Ctrl-C) never reached its restore and left auto_play_enabled=true behind in
## waterwise_settings.json. The next process to boot inherited an autoplayer:
## tools/VerifyStrayAudio spent three of its six cases watching AutoNav click Play on the
## hub, advance the story screen and finally navigate away from the round it was measuring
## ("Cannot call method 'get' on a previously freed instance"), and blamed its own fixture.
## A real play session started on that machine would have been hijacked the same way.
##
## The `persist` flag is a promise a harness has to remember to keep, and one that forgot
## (tools/VerifyGameIdentity, which then hit its own timeout and never restored anything)
## left auto_play_enabled=true on disk for the rest of a 72-harness suite: 38 later runs
## booted with the bot playing underneath them, and seven of them reported failures that
## were really the autoplayer navigating away from the thing being measured. So the promise
## is now enforced instead of trusted - see _may_persist().
func set_auto_play_enabled(enabled: bool, persist: bool = true) -> void:
	auto_play_enabled = enabled
	
	if SaveManager and persist and _may_persist():
		SaveManager.set_setting("auto_play_enabled", enabled)
	
	if enabled:
		auto_play_start_time = Time.get_ticks_msec()
		auto_play_elapsed = 0.0
		games_played = 0
		total_score = 0
		nav_timer = -2.0  # Give 2-second grace before first nav action
		
		var duration_str = (
			_format_duration(auto_play_duration) 
			if auto_play_duration > 0 
			else "Unlimited"
		)
		print(
			"🤖 Auto-play ENABLED - AI will play games automatically (Duration: %s)" 
			% duration_str
		)
		state_changed.emit(true)
	else:
		_reset_state()
		print("🤖 Auto-play DISABLED (Played for %s)" % _format_duration(auto_play_elapsed))
		state_changed.emit(false)

## Only a real windowed session may write the player's auto-play preferences. A headless
## process is never a player - it is a harness, an export or a CI job - so nothing it does
## to the autoplayer belongs in waterwise_settings.json. The in-memory flags still change,
## which is all a harness actually needs, and this is the reason a killed headless run can
## no longer hand the next process (or the next real play session) a hijacked game.
func _may_persist() -> bool:
	return DisplayServer.get_name() != "headless"

func set_auto_play_duration(minutes: float) -> void:
	auto_play_duration = minutes * 60.0  # Convert to seconds
	
	if SaveManager and _may_persist():
		SaveManager.set_setting("auto_play_duration", auto_play_duration)
	
	var duration_str = (
		_format_duration(auto_play_duration) 
		if auto_play_duration > 0 
		else "Unlimited"
	)
	print("🤖 Auto-play duration set to: %s" % duration_str)

func get_auto_play_duration_minutes() -> float:
	return auto_play_duration / 60.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HUMAN-SIMULATION CONFIG (item 3) — setters/getters + persistence
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Mirror the auto-play setter pattern above: mutate the in-memory profile, then
# persist through SaveManager's generic settings API — but ONLY from a real
# windowed session (_may_persist()), so a headless harness can never leave a
# non-PERFECT mode on disk to poison the next process.

## Setting keys (SaveManager generic settings API — no schema registration needed).
const HSIM_KEY_MODE := "human_sim_mode"
const HSIM_KEY_REACT_MIN := "human_sim_reaction_min_ms"
const HSIM_KEY_REACT_MAX := "human_sim_reaction_max_ms"
const HSIM_KEY_ACC_MIN := "human_sim_accuracy_min"
const HSIM_KEY_ACC_MAX := "human_sim_accuracy_max"
const HSIM_KEY_MISTAKE := "human_sim_mistake_rate"
const HSIM_KEY_JITTER := "human_sim_jitter_px"

## Human-readable mode name for logs / the Settings readout.
func _human_sim_mode_name(mode: int) -> String:
	match mode:
		HumanSimProfile.Mode.HUMAN_LIKE:
			return "Human-like"
		HumanSimProfile.Mode.CUSTOM:
			return "Custom"
		_:
			return "Perfect"

## Restore persisted tuning into the profile. Missing keys fall back to the
## PERFECT default / the profile's own built-in defaults, so a fresh install (or a
## settings file that predates this feature) reads as PERFECT and stays a no-op.
func _load_human_sim_settings() -> void:
	if _hsim_profile == null or SaveManager == null:
		return
	_hsim_profile.mode = int(SaveManager.get_setting(HSIM_KEY_MODE, HumanSimProfile.Mode.PERFECT))
	_hsim_profile.custom_reaction_min_ms = float(SaveManager.get_setting(
		HSIM_KEY_REACT_MIN, _hsim_profile.custom_reaction_min_ms))
	_hsim_profile.custom_reaction_max_ms = float(SaveManager.get_setting(
		HSIM_KEY_REACT_MAX, _hsim_profile.custom_reaction_max_ms))
	_hsim_profile.custom_accuracy_min = float(SaveManager.get_setting(
		HSIM_KEY_ACC_MIN, _hsim_profile.custom_accuracy_min))
	_hsim_profile.custom_accuracy_max = float(SaveManager.get_setting(
		HSIM_KEY_ACC_MAX, _hsim_profile.custom_accuracy_max))
	_hsim_profile.custom_mistake_rate = float(SaveManager.get_setting(
		HSIM_KEY_MISTAKE, _hsim_profile.custom_mistake_rate))
	_hsim_profile.custom_jitter_px = float(SaveManager.get_setting(
		HSIM_KEY_JITTER, _hsim_profile.custom_jitter_px))

func _persist_human_sim(key: String, value: Variant, persist: bool) -> void:
	if SaveManager and persist and _may_persist():
		SaveManager.set_setting(key, value)

## Switch realism mode. Selecting HUMAN_LIKE restores the built-in per-difficulty
## defaults (so it is reproducible); CUSTOM keeps whatever QA has dialled in.
## Switching to PERFECT resets the reaction clock so no half-elapsed delay leaks
## into a later non-PERFECT session.
func set_human_sim_mode(mode: int, persist: bool = true) -> void:
	if _hsim_profile == null:
		_hsim_profile = HumanSimProfile.new()
	_hsim_profile.mode = mode
	# Human-like uses the built-in per-difficulty defaults; seed the CUSTOM scalars
	# from the NORMAL tier so the Settings readout is truthful and switching to
	# Custom starts from sane values rather than stale ones.
	if mode == HumanSimProfile.Mode.HUMAN_LIKE:
		_seed_human_sim_defaults()
	_hsim_reaction_ready_ms = -1
	_hsim_reaction_target = Vector2.INF
	_hsim_hold_engaged = false
	_persist_human_sim(HSIM_KEY_MODE, mode, persist)
	print("🤖 Auto-play human-sim mode: %s" % _human_sim_mode_name(mode))

## Copy the NORMAL-tier built-in defaults into the CUSTOM override scalars (display
## + Custom starting point only — HUMAN_LIKE itself reads the per-difficulty table).
func _seed_human_sim_defaults() -> void:
	if _hsim_profile == null:
		return
	var d: int = HumanSimProfile.Difficulty.NORMAL
	var react: Variant = _hsim_profile.reaction_ms.get(d, Vector2(210.0, 380.0))
	if react is Vector2:
		_hsim_profile.custom_reaction_min_ms = (react as Vector2).x
		_hsim_profile.custom_reaction_max_ms = (react as Vector2).y
	var acc: Variant = _hsim_profile.accuracy_band.get(d, Vector2(0.80, 0.94))
	if acc is Vector2:
		_hsim_profile.custom_accuracy_min = (acc as Vector2).x
		_hsim_profile.custom_accuracy_max = (acc as Vector2).y
	_hsim_profile.custom_mistake_rate = float(_hsim_profile.mistake_rate.get(d, 0.11))
	_hsim_profile.custom_jitter_px = float(_hsim_profile.aim_jitter_px.get(d, 11.0))

func get_human_sim_mode() -> int:
	return _hsim_profile.mode if _hsim_profile != null else HumanSimProfile.Mode.PERFECT

## Set one CUSTOM tuning field by name. `param` is one of:
##   reaction_min_ms, reaction_max_ms, accuracy_min, accuracy_max,
##   mistake_rate, jitter_px.
## Values feed the CUSTOM override scalars on the profile. Returns true on success.
func set_human_sim_param(param: String, value: float, persist: bool = true) -> bool:
	if _hsim_profile == null:
		_hsim_profile = HumanSimProfile.new()
	match param:
		"reaction_min_ms":
			_hsim_profile.custom_reaction_min_ms = maxf(0.0, value)
			_persist_human_sim(HSIM_KEY_REACT_MIN, _hsim_profile.custom_reaction_min_ms, persist)
		"reaction_max_ms":
			_hsim_profile.custom_reaction_max_ms = maxf(0.0, value)
			_persist_human_sim(HSIM_KEY_REACT_MAX, _hsim_profile.custom_reaction_max_ms, persist)
		"accuracy_min":
			_hsim_profile.custom_accuracy_min = clampf(value, 0.0, 1.0)
			_persist_human_sim(HSIM_KEY_ACC_MIN, _hsim_profile.custom_accuracy_min, persist)
		"accuracy_max":
			_hsim_profile.custom_accuracy_max = clampf(value, 0.0, 1.0)
			_persist_human_sim(HSIM_KEY_ACC_MAX, _hsim_profile.custom_accuracy_max, persist)
		"mistake_rate":
			_hsim_profile.custom_mistake_rate = clampf(value, 0.0, 1.0)
			_persist_human_sim(HSIM_KEY_MISTAKE, _hsim_profile.custom_mistake_rate, persist)
		"jitter_px":
			_hsim_profile.custom_jitter_px = maxf(0.0, value)
			_persist_human_sim(HSIM_KEY_JITTER, _hsim_profile.custom_jitter_px, persist)
		_:
			return false
	return true

func get_human_sim_param(param: String) -> float:
	if _hsim_profile == null:
		return 0.0
	match param:
		"reaction_min_ms":
			return _hsim_profile.custom_reaction_min_ms
		"reaction_max_ms":
			return _hsim_profile.custom_reaction_max_ms
		"accuracy_min":
			return _hsim_profile.custom_accuracy_min
		"accuracy_max":
			return _hsim_profile.custom_accuracy_max
		"mistake_rate":
			return _hsim_profile.custom_mistake_rate
		"jitter_px":
			return _hsim_profile.custom_jitter_px
		_:
			return 0.0

func get_remaining_time() -> float:
	if auto_play_duration <= 0:
		return -1.0  # Unlimited
	
	var elapsed = (Time.get_ticks_msec() - auto_play_start_time) / 1000.0
	return max(0.0, auto_play_duration - elapsed)

func is_auto_play_enabled() -> bool:
	return auto_play_enabled

func set_mp_auto_play_enabled(enabled: bool) -> void:
	mp_auto_play_enabled = enabled
	if enabled:
		mp_auto_play_start_time = Time.get_ticks_msec()
		var dur_str = _format_duration(mp_auto_play_duration) if mp_auto_play_duration > 0 else "Unlimited"
		print("🤖 MP Auto-play ENABLED (Duration: %s)" % dur_str)
	else:
		mp_auto_play_start_time = 0
		print("🤖 MP Auto-play DISABLED")

func is_mp_auto_play_enabled() -> bool:
	return mp_auto_play_enabled

func set_mp_auto_play_duration(minutes: float) -> void:
	mp_auto_play_duration = minutes * 60.0
	var dur_str = _format_duration(mp_auto_play_duration) if mp_auto_play_duration > 0 else "Unlimited"
	print("🤖 MP Auto-play duration set to: %s" % dur_str)

func get_mp_auto_play_duration_minutes() -> float:
	return mp_auto_play_duration / 60.0

func get_mp_remaining_time() -> float:
	if mp_auto_play_duration <= 0:
		return -1.0  # Unlimited
	if mp_auto_play_start_time == 0:
		return mp_auto_play_duration
	var elapsed := (Time.get_ticks_msec() - mp_auto_play_start_time) / 1000.0
	return max(0.0, mp_auto_play_duration - elapsed)

func _reset_state() -> void:
	_release_pointer()
	_reset_gesture()
	_hsim_reset()
	current_game = null
	game_name = ""
	auto_play_strategy = ""
	_paused_seconds = 0.0
	_resume_requested = false
	drag_target = Vector2.ZERO
	is_dragging = false
	swipe_cooldown = 0.0
	tap_cooldown = 0.0
	memory_pairs.clear()
	memory_first_card = null
	trace_path_index = 0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GAME REGISTRATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func register_game(game: Node, game_type: String) -> void:
	if not auto_play_enabled:
		return

	current_game = game
	game_name = game_type
	auto_play_strategy = _determine_strategy(game_type)
	action_timer = 0.0

	print("🤖 Auto-play registered: %s (Strategy: %s)" % [game_type, auto_play_strategy])

func unregister_game() -> void:
	if current_game:
		games_played += 1
		print("🤖 Auto-play completed game #%d: %s" % [games_played, game_name])
	
	_reset_state()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STRATEGY DETERMINATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _determine_strategy(game_type: String) -> String:
	# Map game names to their input strategies
	var strategies := {
		# Tap-based games
		"Timing Tap": "timing_tap",
		"Turn Off Tap": "tap_targets",
		"Spot The Speck": "tap_targets",
		"Plug The Leak": "tap_targets",
		"Fix Leak": "fix_leak",
		"Fix the Leak": "fix_leak",
		"Thirsty Plant": "thirsty_plant",
		"Water Plant": "tap_targets",
		
		# Drag-based games
		"Catch The Rain": "drag_catcher",
		"Bucket Brigade": "drag_catcher",
		"Cloud Catcher": "cloud_catcher",
		"Droplet Dash": "drag_avoid",
		"Cover The Drum": "cover_the_drum",
		"Filter Builder": "drag_arrange",
		
		# Swipe-based games
		"Swipe The Soap": "swipe_direction",
		"Wring It Out": "swipe_direction",
		"Scrub To Save": "scrub_to_save",
		
		# Sorting/Selection games
		"Greywater Sorter": "tap_targets",
		"Rice Wash Rescue": "tap_targets",
		"Vegetable Bath": "tap_targets",
		
		# Memory/Pattern games
		"Water Memory": "memory_match",
		"Trace Pipe Path": "trace_path",
		
		# Special games
		"Quick Shower": "quick_shower",
		"Toilet Tank Fix": "toilet_tank_fix",
		"Mud Pie Maker": "mud_pie_maker",
		"Rainwater Harvesting": "tap_targets",
		
		# ═══════════════════════════════════════════════════════════════
		# MULTIPLAYER GAMES (Main 5)
		# ═══════════════════════════════════════════════════════════════
		"CoopMiniGame": "mp_dual_mode",  # Generic fallback
		"MiniGame_Rain": "mp_rain",
		"MiniGame_LeafSort": "mp_leaf_sort",
		"MiniGame_WaterHarvest": "mp_water_harvest",
		"MiniGame_GreywaterSort": "mp_greywater_sort",
		"MiniGame_BucketBrigade": "mp_bucket_brigade"
	}

	# Canonicalised so the scene id ("FixLeak"), the script basename ("MP_WashCar")
	# and the English titles above all reach the same row. Before this, a localized
	# title reached none of them and every game reported "tap_targets" — a real
	# strategy for eight of the games, which is why the fallback looked plausible
	# in the log.
	var want: String = _canon(game_type)
	for k in strategies:
		if _canon(str(k)) == want:
			return str(strategies[k])
	return "tap_targets"  # Default to tap strategy

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTO-PLAY PROCESS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _process(delta: float) -> void:
	# A lift deferred by a pause is retried here, ahead of every early return, so the
	# synthetic finger cannot outlive the pause that swallowed its release.
	if _pointer_release_pending:
		_release_pointer()

	# Elapsed FIRST, ahead of every early return. A frozen auto_play_elapsed used
	# to be the only visible symptom of the driver being stuck, and it froze
	# because the line that updates it sat behind three of them: a 420 s run
	# reported "Played for 25s" and no failures at all.
	if auto_play_enabled and auto_play_start_time > 0:
		auto_play_elapsed = (Time.get_ticks_msec() - auto_play_start_time) / 1000.0
		if auto_play_duration > 0 and auto_play_elapsed >= auto_play_duration:
			var dur_str = _format_duration(auto_play_duration)
			print("🤖 Auto-play duration reached (%s) - Stopping" % dur_str)
			_expire_auto_play()
			return

	# A paused tree is not a state the bot can play in, and it is a state the bot
	# can put itself into. Injecting input here would be dishonest anyway, so the
	# only action taken while paused is undoing the pause.
	if auto_play_enabled or mp_auto_play_enabled:
		if get_tree().paused:
			_paused_seconds += delta
			_try_resume_from_pause()
			return
		_paused_seconds = 0.0
		_resume_requested = false

	# MP auto-play: runs independently of the SP auto_play_enabled flag
	if mp_auto_play_enabled:
		_process_mp_auto_play(delta)
		# Also navigate UI if MP auto-play is on (results screens, lobby, etc.)
		if not current_game or not is_instance_valid(current_game):
			_navigate_ui(delta)

	if not auto_play_enabled:
		return

	# Dismiss StoryScreen overlay if it is showing (it overlays the scene,
	# so scene_file_path stays unchanged — we must handle it here first).
	if _try_advance_story_screen():
		return

	# If no active game, navigate menus autonomously.
	#
	# is_instance_valid() alone is not enough: change_scene_to_file() removes the
	# outgoing minigame from the tree and only memdeletes it at the end of the
	# frame, so for one frame the node is still VALID, still reports game_active
	# true, and gets driven by the strategy dispatch below. Any strategy that
	# touches the viewport then faults — measured as
	#   Condition "!is_inside_tree()" is true. Returning: Rect2()
	#   at get_viewport_rect ... [0] _shell_drag (CatchTheRainV2.gd:320)
	#         [1] _aim_catcher [2] _play_catcher [3] _dispatch_game_strategy
	# on every scene change that lands mid-drag. The reference is dropped so the
	# next scene re-registers cleanly instead of re-entering this branch forever.
	if current_game and is_instance_valid(current_game) \
			and not current_game.is_inside_tree():
		current_game = null
		_release_pointer()
		_reset_gesture()
	if not current_game or not is_instance_valid(current_game):
		_navigate_ui(delta)
		return

	# Check if game is active
	var is_active := false
	if "game_active" in current_game:
		is_active = current_game.game_active
	elif "is_playing" in current_game:
		is_active = current_game.is_playing

	if not is_active:
		# The round is over or has not started. _navigate_ui() clicks real UI next, so
		# the finger comes up first: a touch left down reads as a finger resting on the
		# screen for every game that polls get_touch_count().
		_release_pointer()
		_reset_gesture()
		_navigate_ui(delta)
		return

	# Update cooldowns
	if swipe_cooldown > 0:
		swipe_cooldown -= delta
	if tap_cooldown > 0:
		tap_cooldown -= delta

	# Update action timer
	action_timer += delta

	# Execute game-specific AI strategy
	_dispatch_game_strategy(delta)


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEADLINE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## The configured duration has to end the SESSION, not just the synthetic finger.
##
## Reaching the deadline used to do exactly one thing - clear auto_play_enabled -
## which stops the bot injecting input and stops nothing else. The round it was in
## the middle of stayed on screen with its own clock still running, so an unattended
## run did not end at its configured duration: it ended whenever the round it had
## already entered happened to finish. The attempt-budget rounds from the fairness
## rework overrun the furthest, because the clock is not their opponent - with
## nobody left to tap, one of those runs to MiniGameBase's anti-hang ceiling
## (ATTEMPT_CEILING_SCALE x the nominal length, never under
## ATTEMPT_CEILING_MIN_SEC = 45s) before anything ends it.
##
## current_game is read BEFORE the flags are touched, because
## set_auto_play_enabled(false) calls _reset_state(), which nulls it - a deadline
## handler that clears first has nothing left to end.
func _expire_auto_play() -> void:
	var g: Node = current_game
	set_auto_play_enabled(false)
	_abort_round(g)

## The MP deadline had the same hole plus one of its own: set_mp_auto_play_enabled()
## does not reset the driver, so current_game, the chosen strategy and a
## half-finished drag all survived the stop for the next session to inherit.
func _expire_mp_auto_play() -> void:
	var g: Node = current_game
	set_mp_auto_play_enabled(false)
	_reset_state()
	_abort_round(g)

## End the round in progress through THAT ROUND'S OWN quit handler.
##
## Not by clearing game_active from out here: each of these handlers does
## bookkeeping only it knows about, and skipping it is how a session ends up with a
## round nothing played in the logs, or a partner left waiting on a peer that
## stopped answering.
##   - MiniGameBase._on_exit_pressed() reports the round to GameManager with
##     _report_accuracy(false) - a quit is not a completed objective - stops the
##     game and chaos timers, shows the tally, then returns to the main menu. Its
##     own _quitting / _round_ended guards make a second call inert, so racing the
##     round's real end is safe. pause_menu, which that handler writes without a
##     check, is live by then: register_game() is called at MiniGameBase.gd:284,
##     after _setup_ui() built it at 270, so a round the bot knows about is a round
##     that finished building.
##   - MultiplayerMiniGameBase._on_quit_pressed() goes through
##     GameManager.return_to_multiplayer_lobby(), which closes the ENet peer so the
##     partner is told (server_disconnected) instead of sitting on a dead session.
##   - the five legacy co-op rounds (MultiplayerMiniGameEffects) carry their own
##     _on_exit_pressed(), ending the session via NetworkManager.return_to_lobby().
##
## Classified by script inheritance rather than by scene path or title, for the same
## reason ButtonAnimator._is_gameplay_button() is: a table of paths rots silently.
func _abort_round(g: Node) -> void:
	if not is_instance_valid(g) or not g.is_inside_tree():
		return
	var method: String = ""
	if g is MiniGameBase or g is MultiplayerMiniGameEffects:
		method = "_on_exit_pressed"
	elif g is MultiplayerMiniGameBase:
		method = "_on_quit_pressed"
	if method.is_empty() or not g.has_method(method):
		# Said out loud, never swallowed: a round the deadline could not end is a
		# round still running after the bot was told to stop.
		push_warning(("AutoPlay deadline: no quit handler on %s (%s) - "
			+ "the round was left running") % [g.name, g.get_class()])
		return
	print("🤖 Auto-play deadline: ending the round in progress (%s -> %s())"
		% [g.name, method])
	# Trepn-dataset guard: a round the configured duration cut short is NOT a
	# real 0% failure. Latch while the round's own quit handler runs —
	# complete_minigame() is reached synchronously inside it — so
	# SessionLogger.record_sp_game() can stamp the row with
	# "interrupted_by_timeout". Also tag the node so a deferred report path
	# could still see why the round ended. Cleared after the call returns so a
	# human's QUIT press (or a later normal round end) is never misflagged.
	deadline_interrupt_active = true
	g.set_meta("autoplay_interrupted", true)
	g.call(method)
	deadline_interrupt_active = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PAUSE RECOVERY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Undo a pause the bot did not ask for.
##
## Nothing else can: the pause overlay is dismissed by a human tapping RESUME, and
## an unattended run has no human. Before this, one stray press of the pause glyph
## ended the session — get_tree().paused stopped this autoload's own _process, so
## the code that would have dismissed the overlay was frozen by the thing it was
## meant to clear. The visible result was a soak that quietly stopped playing 25 s
## in and still reported zero failures, which is worse than a crash.
##
## The game's own resume path is preferred so its bookkeeping runs — MiniGameBase
## subtracts the paused span from played-seconds there, and clearing the flag
## behind its back would leave the overlay on screen and the round's duration wrong.
##
## TWO RULES THIS GAINED, both from session_2026-09-05T00-27-36.json.
##
## 1. A DELIBERATE pause is left alone. In multiplayer the round's _on_resume_pressed()
##    is NetworkManager.request_resume(), so this function was un-pausing a co-op round a
##    player had deliberately paused — which is what "autoplay is not pausable" means.
##    NetworkManager.is_pause_deliberate() distinguishes a player's press from a pause
##    with no owner (an app-focus handler, say), and only the latter is the deadlock this
##    guard exists for.
##
## 2. ONE attempt per pause episode. _process() runs while the tree is paused, and a
##    co-op resume is a network round trip, so the old code sent one resume request per
##    frame until the state came back — the duplicated consecutive "Game resumed" lines
##    in that log. NetworkManager now drops the repeats, but the bot should not be
##    generating them: it asks once and waits for the pause to actually lift.
func _try_resume_from_pause() -> bool:
	# A pause a player asked for is theirs to lift. Autoplay keeps its deadlock guard
	# below for pauses nobody owns, but it no longer fights a human.
	var nm := get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("is_pause_deliberate") and nm.is_pause_deliberate():
		return false

	var g := current_game
	if is_instance_valid(g) and g.has_method("_on_resume_pressed"):
		var overlay = g.get("pause_menu") if "pause_menu" in g else null
		if overlay == null or (is_instance_valid(overlay) and overlay.visible):
			if not _resume_requested:
				_resume_requested = true
				g._on_resume_pressed()
				print("🤖 Auto-play dismissed a pause overlay it did not ask for")
			# Requested and waiting. Reporting true keeps the caller's early-return, so
			# no synthetic input is injected into a tree that is still frozen.
			return true

	# Nothing recognisable to dismiss (a pause set by something with no overlay of
	# its own, e.g. an app-focus handler). Waiting it out is the deadlock, so the
	# flag is cleared once the grace period is up — loudly, because a pause the bot
	# cannot explain is itself a finding.
	if _paused_seconds >= PAUSE_GRACE_SECONDS:
		push_warning(
			"AutoPlayManager: tree paused %.1fs with no overlay to dismiss — clearing"
			% _paused_seconds
		)
		get_tree().paused = false
		if nm and nm.has_method("clear_pause_state"):
			nm.clear_pause_state()
		_paused_seconds = 0.0
		return true
	return false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STORY SCREEN BYPASS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## StoryScreen is added as a CanvasLayer overlay — the scene_file_path
## never changes, so we must detect and advance it every frame ourselves.
## Returns true if a story screen was found and advanced (caller should return early).
func _try_advance_story_screen() -> bool:
	# Find any StoryScreen in the tree
	var story: Node = _find_story_screen_node(get_tree().root)
	if not story:
		return false
	# If it is still animating this page, wait
	if story.get("_is_animating"):
		return true
	# If it is finishing (fade-out), do nothing — just wait
	if story.get("_is_finishing"):
		return true
	# Advance to the next page / finish the story
	if story.has_method("advance_page"):
		print("🤖 AutoPlay: advancing StoryScreen page")
		story.advance_page()
	return true

func _find_story_screen_node(node: Node) -> Node:
	if node.scene_file_path == "res://scenes/ui/StoryScreen.tscn":
		return node
	for child in node.get_children():
		var found := _find_story_screen_node(child)
		if found:
			return found
	return null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AUTONOMOUS MENU NAVIGATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Called every frame when no game is active.
## Detects the current scene and clicks the appropriate button
## to autonomously navigate from Main Menu → game → results → repeat.
func _navigate_ui(delta: float) -> void:
	nav_timer += delta
	if nav_timer < nav_interval:
		return
	nav_timer = 0.0

	var scene: Node = get_tree().current_scene
	if not scene:
		return

	var path: String = scene.scene_file_path
	print("🤖 AutoNav: current scene = %s" % path)

	# ── Loading screen (auto-proceeds; nothing to click) ─────────
	if "LoadingScreen" in path:
		return

	# ── Main Menu ─────────────────────────────────────────────────
	if "MainMenu" in path:
		var btn: Button = scene.get_node_or_null("UI/VBoxContainer/PlayButton")
		if btn:
			print("🤖 AutoNav: clicking Play on MainMenu")
			btn.pressed.emit()
		return

	# ── Initial / Hub Screen ──────────────────────────────────────
	if "InitialScreen" in path:
		# Dismiss welcome popup if visible
		var popup: Node = scene.get_node_or_null("WelcomePopup")
		if popup and popup.visible:
			var close_btn: Button = popup.get_node_or_null("Panel/CloseButton")
			if close_btn:
				close_btn.pressed.emit()
				return
		# Always click single-player Play (multiplayer requires two devices)
		var play_btn: Button = scene.get_node_or_null("UI/ButtonContainer/PlayButton")
		if play_btn and not play_btn.disabled and play_btn.visible:
			print("🤖 AutoNav: clicking Play on InitialScreen")
			play_btn.pressed.emit()
		return

	# ── MiniGame intro bridge & animated cutscenes (auto-advance; no button needed) ─
	if (
		"MiniGameIntroBridge" in path
		or "MiniGameIntroCutscene" in path
		or "MiniGameOutroCutscene" in path
		or "MiniGameWinOutroCutscene" in path
		or "MiniGameLoseOutroCutscene" in path
		or "CharacterOutcomeNarrative" in path
		or "SimpleCutscenePlayer" in path
	):
		return  # These scenes animate automatically; nothing for AutoPlay to do

	# ── Instructions / Tutorial screens ───────────────────────────
	if "Instructions" in path or "StoryScreen" in path:
		var btn: Button = _find_button_recursive(scene, [
			"BackButton", "ContinueButton", "SkipButton",
			"NextButton", "CloseButton", "StartButton"
		])
		if btn:
			print("🤖 AutoNav: dismissing instruction/story screen")
			btn.pressed.emit()
		return

	# ── Result / Score / Transition screens ───────────────────────
	if (
		"MiniGameResults" in path or "FinalScore" in path
		or "RoundTransition" in path or "PostTest" in path
		or "PostTestResults" in path or "MultiplayerGameOver" in path
	):
		var btn: Button = _find_button_recursive(scene, [
			"ContinueButton", "NextButton", "RetryButton",
			"BackButton", "DoneButton", "HomeButton"
		])
		if btn:
			print("🤖 AutoNav: continuing from result screen")
			btn.pressed.emit()
		return

	# ── Multiplayer Lobby / Menu ───────────────────────────────────
	if "MultiplayerLobby" in path or "MultiplayerMenu" in path:
		# When MP auto-play is active the lobby is human-driven:
		# players connect manually, then the host presses Start (or
		# AutoPlay auto-starts once both are ready). Never navigate
		# away from the lobby or try to re-enter single-player here.
		if mp_auto_play_enabled:
			return

		# If a StartGameButton is present and enabled (2 players connected), start the game
		var start_btn: Button = _find_button_recursive(scene, ["StartGameButton"])
		if start_btn and not start_btn.disabled:
			print("🤖 AutoNav: starting multiplayer game")
			start_btn.pressed.emit()
			return
		# Single-device testing: back out gracefully since we can't host+join simultaneously
		var exit_btn: Button = _find_button_recursive(scene, ["BackButton", "DisconnectButton"])
		if exit_btn:
			print("🤖 AutoNav: exiting multiplayer lobby (no second player available)")
			exit_btn.pressed.emit()
		return

	# ── Character / Roadmap / Unlockables screens ─────────────────
	if (
		"CharacterCustomization" in path or "RoadmapScreen" in path
		or "UnlockablesScreen" in path
	):
		var btn: Button = _find_button_recursive(scene, [
			"BackButton", "CloseButton", "DoneButton"
		])
		if btn:
			print("🤖 AutoNav: backing out of non-game screen")
			btn.pressed.emit()
		return

## Search a node tree for the first enabled button matching any of the given names.
func _find_button_recursive(root: Node, names: Array) -> Button:
	for nm in names:
		var found: Node = root.find_child(nm, true, false)
		if found and found is Button:
			var btn := found as Button
			if not btn.disabled and btn.visible:
				return btn
	return null

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STRATEGY IMPLEMENTATIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Dispatch to game-specific AI based on the registered game name.
## Canonical game key -> the method that plays it.
##
## This used to be a `match game_name:` over 66 English display titles. Two things
## made that unverifiable and, in Filipino, inert:
##   * MiniGameBase registers with its DISPLAY TITLE, and FixLeakV2 builds that
##     title from Localization, so "Ayusin ang Tagas" matched no case and the game
##     fell through to _play_generic_tap. Every single-player game reaches this
##     table through the same call, so any title that gets translated later loses
##     its ai silently.
##   * a typo in a `match` case is invisible — the case simply never fires. A
##     dictionary can be swept: tools/VerifyAutoPlayDrive.tscn [3] asserts every
##     roster id has an entry AND that has_method() finds what the entry names.
## Keys are _canon()'d: lower case, no spaces, no underscores, no trailing "V2".
## That accepts all three spellings that reach here — the scene id "FixLeak" from
## MiniGameBase, the script basename "MP_WashCar" from register_multiplayer_game(),
## and the older English titles — without a second table to keep in step.
const HANDLERS: Dictionary = {
	# ── Single-player roster (all 24) ──────────────────────────────
	"timingtap": "_play_timing_tap",
	"turnofftap": "_play_turn_off_tap",
	"spotthespeck": "_play_spot_the_speck",
	"plugtheleak": "_play_plug_the_leak",
	"fixleak": "_play_fix_leak",
	"fixtheleak": "_play_fix_leak",
	"thirstyplant": "_play_thirsty_plant",
	"waterplant": "_play_water_plant",
	"catchtherain": "_play_catcher",
	"bucketbrigade": "_play_bucket_brigade",
	"cloudcatcher": "_play_cloud_catcher",
	"dropletdash": "_play_droplet_dash",
	"coverthedrum": "_play_cover_the_drum",
	"filterbuilder": "_play_filter_builder",
	"swipethesoap": "_play_swipe_soap",
	"wringitout": "_play_wring_it_out",
	"scrubtosave": "_play_scrub_to_save",
	"greywatersorter": "_play_greywater_sorter",
	"ricewashrescue": "_play_rice_wash_rescue",
	"vegetablebath": "_play_vegetable_bath",
	"watermemory": "_play_water_memory",
	"tracepipepath": "_play_trace_pipe_path",
	"quickshower": "_play_quick_shower",
	"toilettankfix": "_play_toilet_tank_fix",
	"mudpiemaker": "_play_mud_pie_maker",
	# ── Two-player bundle games (MP_*.tscn) ────────────────────────
	"mpcatchtherain": "_play_catcher",
	"mpcatchrainaquarium": "_play_catcher",
	"mpcollectdishwater": "_play_mp_drag_collection",
	"mpcollectlaundrywater": "_play_mp_drag_collection",
	"mpcollectshowerwater": "_play_mp_drag_collection",
	"mpwashvegetables": "_play_mp_wash_vegetables",
	"mpwaterplants": "_play_mp_water_plants",
	"mpflushtoilets": "_play_mp_flush_toilets",
	"mpfillaquarium": "_play_mp_fill_aquarium",
	"mpfilterwater": "_play_mp_filter_water",
	"mpmopfloor": "_play_mp_mop_floor",
	"mpwashcar": "_play_mp_wash_car",
	# ── Co-op games (MiniGame_*.tscn) ──────────────────────────────
	"minigamerain": "_play_mp_rain",
	"minigameleafsort": "_play_mp_leaf_sort",
	"minigamewaterharvest": "_play_mp_water_harvest",
	"minigamegreywatersort": "_play_mp_greywater_sort",
	"minigamebucketbrigade": "_play_mp_bucket_brigade",
}


## One spelling for a game, whatever the caller had: the scene id, the script
## basename, or a display title in either language.
func _canon(raw: String) -> String:
	var out: String = raw.strip_edges().to_lower()
	out = out.replace(" ", "").replace("_", "").replace("-", "")
	if out.ends_with("v2"):
		out = out.substr(0, out.length() - 2)
	return out


func _dispatch_game_strategy(delta: float) -> void:
	var handler: String = str(HANDLERS.get(_canon(game_name), ""))
	if handler != "" and has_method(handler):
		call(handler, delta)
		return
	# Unknown game: fall back on the strategy string alone.
	if auto_play_strategy == "drag_catcher":
		_play_catcher(delta)
	elif auto_play_strategy == "click_target":
		_play_mp_click_target(delta)
	elif auto_play_strategy.begins_with("mp_"):
		_play_mp_generic(delta)
	else:
		_play_generic_tap(delta)

# ──────────────────────────────────────────────────────────────────
# MP CLICK_TARGET STRATEGY
# Finds the first visible, interactive node in the game scene and
# simulates a click on it. Used for Distributor-role MP games where
# the player taps aquariums, plants, dirty surfaces, etc.
# ──────────────────────────────────────────────────────────────────
func _play_mp_click_target(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	# Walk the tree looking for a visible, clickable Button or Area2D
	var candidates: Array[Node] = []
	_collect_clickable_nodes(g, candidates)
	if candidates.is_empty():
		tap_cooldown = 0.6
		return
	# Pick the first enabled candidate and INJECT a real tap on it (was
	# emit_signal("pressed") / push_input(MouseButton), which never touched
	# TouchInputManager and left `received` at 0 for the whole MP round).
	var target: Node = candidates[0]
	if target is Button:
		_tap_at(_screen_center_of_control(target as Button))
	elif target is Area2D:
		var area := target as Area2D
		_tap_at(_screen_from_parent_point(area, area.position))
	tap_cooldown = 0.5

func _play_mp_drag_collection(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	var catcher := _get_mp_collection_catcher(g)
	if catcher == null or not is_instance_valid(catcher):
		_release_pointer()
		return
	var target := _get_mp_falling_target(g)
	if target == null or not is_instance_valid(target):
		# No drop to chase: keep the finger on the catcher so it stays grabbed.
		_drag_to(_screen_from_parent_point(catcher, catcher.position))
		return
	# MP_CollectDishWater: pressing ON a bucket Area2D sets dragging_bucket, then
	# its _input() MouseMotion moves the bucket to world_from_screen(pointer).x. An
	# injected drag reaches both, exactly as a human finger does - no direct
	# catcher.position write.
	var viewport_width := get_viewport().get_visible_rect().size.x
	var aim_x := clampf(target.position.x, 50.0, viewport_width - 50.0)
	if not _pointer_down:
		_drag_to(_screen_from_parent_point(catcher, catcher.position))
	else:
		_drag_to(_screen_from_parent_point(catcher, Vector2(aim_x, catcher.position.y)))

func _get_mp_collection_catcher(g: Node) -> Node2D:
	var catchers: Array = []
	if "containers" in g:
		catchers = g.containers
	elif "buckets" in g:
		catchers = g.buckets
	if catchers.is_empty():
		return null
	var best: Node2D = null
	var lowest_fill := INF
	for catcher in catchers:
		if not is_instance_valid(catcher):
			continue
		var fill := 0.0
		if catcher.has_meta("current"):
			fill = float(catcher.get_meta("current", 0))
		elif catcher.has_meta("water_level"):
			fill = float(catcher.get_meta("water_level", 0))
		if best == null or fill < lowest_fill:
			best = catcher
			lowest_fill = fill
	return best

func _get_mp_falling_target(g: Node) -> Area2D:
	var best: Area2D = null
	var best_y := -INF
	for child in g.get_children():
		if not child is Area2D:
			continue
		var area := child as Area2D
		if not is_instance_valid(area) or not area.has_meta("velocity"):
			continue
		if area.position.y > best_y:
			best = area
			best_y = area.position.y
	return best

func _play_mp_wash_vegetables(_delta: float) -> void:
	if _gest_active:
		_step_gesture()
		return
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var sink: Node2D = g.get("sink_area")
	var vegetables: Array = g.get("vegetables") if "vegetables" in g else []
	if sink == null or not is_instance_valid(sink) or vegetables.is_empty():
		return
	# MP_WashVegetables: pressing a vegetable Area2D sets dragging_vegetable, its
	# _input() MouseMotion follows the finger, and release inside sink_area runs
	# _check_wash_vegetable(). A grab->drag->release gesture drives all three, so
	# the score fires through injected input rather than a direct _check call.
	for vegetable in vegetables:
		if not is_instance_valid(vegetable) or not (vegetable is Node2D):
			continue
		var v := vegetable as Node2D
		var from := _screen_from_parent_point(v, v.position)
		var to := _screen_from_parent_point(sink, sink.position)
		_start_gesture([from, to, to], true, 0.15)
		return

func _play_mp_water_plants(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_try_water_plant"):
		return
	if int(g.get("available_water")) <= 0:
		return
	for plant in g.get("plants"):
		if not is_instance_valid(plant):
			continue
		if plant.get_meta("watered", false):
			continue
		# Area2D physics picking: an injected tap -> emulated MouseButton reaches
		# _on_plant_clicked -> _try_water_plant, exactly as a human tap does.
		_tap_at(_screen_from_parent_point(plant as Node2D, (plant as Node2D).position))
		tap_cooldown = 0.12
		return

func _play_mp_flush_toilets(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_try_flush"):
		return
	if int(g.get("available_water")) <= 0:
		return
	for toilet in g.get("toilets"):
		if not is_instance_valid(toilet):
			continue
		if not toilet.get_meta("needs_flush", false):
			continue
		_tap_at(_screen_from_parent_point(toilet as Node2D, (toilet as Node2D).position))
		tap_cooldown = 0.15
		return

func _play_mp_fill_aquarium(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_try_fill"):
		return
	if int(g.get("available_water")) <= 0:
		return
	var aquarium_level := float(g.get("aquarium_level"))
	var aquarium_max := float(g.get("aquarium_max"))
	if aquarium_level >= aquarium_max:
		return
	# The aquarium Area2D is a local in _create_aquarium(); find it among the
	# game's children and tap it so physics picking drives _on_aquarium_clicked.
	var aquarium: Node2D = null
	for child in g.get_children():
		if child is Area2D:
			aquarium = child as Node2D
			break
	if aquarium == null:
		return
	_tap_at(_screen_from_parent_point(aquarium, aquarium.position))
	tap_cooldown = 0.15

func _play_mp_filter_water(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_filter_particle"):
		return
	for particle in g.get("dirt_particles"):
		if not is_instance_valid(particle):
			continue
		_tap_at(_screen_from_parent_point(particle as Node2D, (particle as Node2D).position))
		tap_cooldown = 0.08
		return

func _play_mp_mop_floor(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_try_mop"):
		return
	if int(g.get("available_water")) <= 0:
		return
	for tile in g.get("floor_tiles"):
		if not is_instance_valid(tile):
			continue
		if not tile.get_meta("dirty", false):
			continue
		_tap_at(_screen_from_parent_point(tile as Node2D, (tile as Node2D).position))
		tap_cooldown = 0.15
		return

func _play_mp_wash_car(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g) or not g.has_method("_try_wash"):
		return
	if int(g.get("available_water")) <= 0:
		return
	for section in g.get("car_sections"):
		if not is_instance_valid(section):
			continue
		if not section.get_meta("dirty", false):
			continue
		_tap_at(_screen_from_parent_point(section as Node2D, (section as Node2D).position))
		tap_cooldown = 0.15
		return

func _collect_clickable_nodes(node: Node, out: Array[Node]) -> void:
	if out.size() >= 5:
		return
	# Skip HUD / overlay elements
	if node.name in ["ClickCatcher", "PauseButton", "ResumeButton", "QuitButton"]:
		return
	if node is CanvasLayer:
		return  # Don't recurse into HUD layers
	if node is Button:
		var btn := node as Button
		# is_visible_in_tree(), not visible: a control inside a hidden panel still
		# reports visible == true, and emitting `pressed` on it works, so the same
		# read used to hand the bot buttons the player could not see.
		if btn.is_visible_in_tree() and not btn.disabled and not _is_shell_button(btn):
			out.append(btn)
			return
	if node is Area2D:
		var a := node as Area2D
		# Skip bucket/catcher nodes — only collect tappable targets
		if a.is_visible_in_tree() and a.has_meta("type"):
			out.append(a)
	for child in node.get_children():
		_collect_clickable_nodes(child, out)

# ──────────────────────────────────────────────────────────────────
# FIX LEAK
# Iterate leaks[]; call _on_leak_clicked() on each unfixed leak.
# ──────────────────────────────────────────────────────────────────
func _play_fix_leak(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_on_leak_clicked"):
		return
	var leaks: Array = g.get("leaks") if "leaks" in g else []
	for leak in leaks:
		if not is_instance_valid(leak):
			continue
		if leak.get_meta("fixed", false):
			continue
		# FixLeakV2 is a MicrogameShell game: an injected tap -> _shell_tap hit-tests
		# leak.position -> _on_leak_clicked -> record_hit. No camera, so the leak's
		# parent-space position IS the viewport point the shell input layer sees.
		_tap_at(_screen_from_parent_point(leak as Node2D, (leak as Node2D).position))
		tap_cooldown = 0.25
		return

# ──────────────────────────────────────────────────────────────────
# CLOUD CATCHER
# Tap the untapped cloud best aligned with a plant that still needs water.
# ──────────────────────────────────────────────────────────────────
## Autoplay taps the cloud best ALIGNED with a plant that still needs water, not simply the
## first untapped cloud in the array. The old loop ignored the plants entirely, and in this game
## alignment is the whole skill: a tap releases five drops in a 60-unit band around the cloud
## while the plants sit 213 units apart on Hard, so an unaimed tap waters a plant only by luck.
## Measured before the change with tools/VerifyCloudCatcherClearable.tscn's aiming bot as the
## reference - autoplay could not clear CloudCatcher at any difficulty, which matters because
## AutoPlayManager is what the demo/attract path and the unattended test runs play through.
##
## AIM_TOL is the horizontal error that still lands rain: drops spawn within +/-30 of the cloud
## and a plant tests at a 50-unit radius, so 40 keeps most of the five drops inside the plant.
const CLOUD_AIM_TOL: float = 40.0

func _play_cloud_catcher(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_on_cloud_tapped"):
		return
	var clouds: Array = g.get("clouds") if "clouds" in g else []
	var plants: Array = g.get("plants") if "plants" in g else []
	if clouds.is_empty() or plants.is_empty():
		return
	# Rain already on its way, so a cloud is not spent on a plant the last tap has covered.
	var falling: Array = []
	for child in g.get_children():
		if child is Label and child.has_meta("is_rain"):
			falling.append(child)
	var best_cloud: Node = null
	var best_err: float = CLOUD_AIM_TOL
	for plant in plants:
		if not is_instance_valid(plant) or plant.get_meta("watered", false):
			continue
		var have: float = float(plant.get_meta("water_amount", 0.0))
		var target: float = float(plant.get_meta("target_water", 1.0))
		# FIX 93 - each drop that lands adds half the target, so two drops finish a plant, and that
		# what this expression already yields. The "* 2" it used to carry double-booked the plant:
		# autoplay kept aiming clouds at a plant with two drops inbound and only moved on at four,
		# spending clouds the rest of the quota needed. committed below counts only drops already
		# within 50 units in x, and a drop's x is fixed at spawn, so a committed drop lands.
		var need: int = int(ceil((target - have) / (target * 0.5)))
		var committed: int = 0
		for drop in falling:
			if absf(drop.position.x - plant.position.x) <= 50.0 \
				and drop.position.y < plant.position.y:
				committed += 1
		if committed >= need:
			continue
		for cloud in clouds:
			if not is_instance_valid(cloud) or cloud.get_meta("tapped", false):
				continue
			var err: float = absf(cloud.position.x - plant.position.x)
			if err < best_err:
				best_err = err
				best_cloud = cloud
	if best_cloud == null:
		# Nothing is lined up this frame. Waiting is the correct move: the clouds drift, and a
		# tap now would consume one over empty ground.
		return
	# Aim at the cloud's Button child by its LIVE on-screen centre, not at the cloud's Node2D
	# origin. centre_hit_control() centres the button with position = -size * 0.5, but only once
	# its size resolves - the 48dp floor and MobileUIManager restyle the button AFTER creation, so
	# on a freshly spawned / still-condensing cloud the button rect can sit at [origin, origin+size]
	# with its centre half a button away from the cloud origin. An injected tap aimed at the origin
	# then lands on the button's top-left corner and misses, which is what halved the shipped bot's
	# conversion rate against the synchronous direct call it replaced. Reading the Control's global
	# rect centre makes the tap land where the button actually is this frame.
	var btn: Control = best_cloud.get_meta("btn") if best_cloud.has_meta("btn") else null
	if btn != null and is_instance_valid(btn):
		_tap_at(_screen_center_of_control(btn))
	else:
		_tap_at(_screen_from_parent_point(best_cloud as Node2D, (best_cloud as Node2D).position))
	tap_cooldown = 0.3

# ──────────────────────────────────────────────────────────────────
# COVER THE DRUM
# Find first uncovered drum in drums[]; call _cover_drum().
# Re-covers drums as they uncover over time (4s timer).
# ──────────────────────────────────────────────────────────────────
func _play_cover_the_drum(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_cover_drum"):
		return
	var drums: Array = g.get("drums") if "drums" in g else []
	for drum in drums:
		if not is_instance_valid(drum):
			continue
		if not drum.get_meta("covered", false):
			# CoverTheDrum._input compares event.position to drum.position (<100), so a
			# tap at the drum drives _cover_drum through the real input path.
			_tap_at(_screen_from_parent_point(drum as Node2D, (drum as Node2D).position))
			tap_cooldown = 0.2
			return

# ──────────────────────────────────────────────────────────────────
# QUICK SHOWER
# Wait for gauge_position to enter [target_zone_start, target_zone_end],
# then call _check_timing() for a perfect tap.
# ──────────────────────────────────────────────────────────────────
func _play_quick_shower(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.get("shower_running"):
		return
	if not g.has_method("_check_timing"):
		return
	var gauge: float = float(g.get("gauge_position")) if "gauge_position" in g else -1.0
	var z_start: float = float(g.get("target_zone_start")) if "target_zone_start" in g else 0.0
	var z_end: float = float(g.get("target_zone_end")) if "target_zone_end" in g else 100.0
	if gauge >= z_start and gauge <= z_end:
		# QuickShower._input fires _check_timing() on ANY press while shower_running,
		# so tap the screen centre; the game reads no position.
		_tap_at(get_viewport().get_visible_rect().size * 0.5)
		tap_cooldown = 1.2

# ──────────────────────────────────────────────────────────────────
# SCRUB TO SAVE
# Zero out dirt_level on current_dish and call _dish_cleaned().
# ──────────────────────────────────────────────────────────────────
func _play_scrub_to_save(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	var dish: Node2D = g.get("current_dish")
	if dish == null or not is_instance_valid(dish):
		# Nothing to scrub: lift the finger so it cannot linger as a phantom touch.
		_release_pointer()
		return
	# ScrubToSave._handle_scrubbing() polls is_mouse_button_pressed(LEFT) +
	# get_mouse_position() and drops dirt_level only while the held finger MOVES
	# >5px within 100px of the dish; dirt_level<=0 then fires _dish_cleaned() ->
	# record_action(true) honestly. Alternate a held finger +/-24px across the dish
	# each frame (injected ScreenDrag -> emulated mouse motion) instead of writing
	# dirt_level and calling _dish_cleaned() directly.
	var dish_pos := _screen_from_parent_point(dish, dish.position)
	var off := Vector2(24.0, 0.0) if _scrub_phase else Vector2(-24.0, 0.0)
	_scrub_phase = not _scrub_phase
	_hold_at(dish_pos + off)

# ──────────────────────────────────────────────────────────────────
# THIRSTY PLANT
# Wait for can_click (after shuffle phase); then call
# _on_bucket_pressed() on the bucket with is_correct meta.
# ──────────────────────────────────────────────────────────────────
func _play_thirsty_plant(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.get("can_click"):
		return
	if not g.has_method("_on_bucket_pressed"):
		return
	var buckets: Array = g.get("buckets") if "buckets" in g else []
	for bucket in buckets:
		if not is_instance_valid(bucket):
			continue
		if bucket.get_meta("is_correct", false):
			# ThirstyPlant._input tests distance to bucket.position (<80), so tap the bucket.
			_tap_at(_screen_from_parent_point(bucket as Node2D, (bucket as Node2D).position))
			tap_cooldown = 1.0
			return

# ──────────────────────────────────────────────────────────────────
# TOILET TANK FIX
# Snap water_level to target_level and call _check_level() to record
# a successful fill without waiting for real mouse-hold input.
# ──────────────────────────────────────────────────────────────────
func _play_toilet_tank_fix(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	if not "water_level" in g or not "target_level" in g:
		return
	# Between tanks the game ignores input and re-rolls the target; lift and wait.
	if bool(g.get("_awaiting_next_tank")):
		_release_pointer()
		return
	var water_level: float = float(g.get("water_level"))
	var target: float = float(g.get("target_level"))
	var tol: float = float(g.get("tolerance")) if "tolerance" in g else 10.0
	# ToiletTankFix._process fills while Input.is_mouse_button_pressed(LEFT) and
	# grades on the RELEASE edge (_check_level succeeds when |water-target|<=tol).
	# Hold a real finger until just inside the window, then lift it -> graded hit,
	# instead of snapping water_level and calling _check_level() directly.
	if water_level < target - tol + 1.0:
		_hold_at(get_viewport().get_visible_rect().size * 0.5)
	else:
		_release_pointer()

# ──────────────────────────────────────────────────────────────────
# MUD PIE MAKER
# Directly drive the pouring flag to keep water_level in the green
# zone [target_min, target_max] throughout the survival timer.
# ──────────────────────────────────────────────────────────────────
func _play_mud_pie_maker(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	if not "water_level" in g:
		return
	var water_level: float = float(g.get("water_level"))
	var t_min: float = float(g.get("target_min")) if "target_min" in g else 35.0
	var t_max: float = float(g.get("target_max")) if "target_max" in g else 65.0
	# MudPieMaker._input sets `pouring` on a ScreenTouch/MouseButton press and its
	# _process pays record_action(true) for every interval spent inside the green
	# band. Hold a real finger to pour up, lift to drain back, with hysteresis so the
	# finger does not chatter every frame — no direct write to `pouring`.
	var lo: float = t_min + (t_max - t_min) * 0.35
	var hi: float = t_min + (t_max - t_min) * 0.65
	if water_level < lo:
		_hold_at(get_viewport().get_visible_rect().size * 0.5)
	elif water_level > hi:
		_release_pointer()

# ──────────────────────────────────────────────────────────────────
# SWIPE THE SOAP
# Read the required direction from current_soap meta, then call
# _correct_swipe() directly — always wins every soap.
# ──────────────────────────────────────────────────────────────────
func _play_swipe_soap(_delta: float) -> void:
	if _gest_active:
		_step_gesture()
		return
	if swipe_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var soap: Node2D = g.get("current_soap")
	if soap == null or not is_instance_valid(soap):
		return
	# SwipeTheSoap._handle_swipe() polls the held pointer: press at the soap, move
	# >50px in the required direction, release -> _correct_swipe(). Inject the swipe
	# as a real gesture (down -> drag -> up) instead of calling _correct_swipe().
	var dir: String = str(soap.get_meta("direction", "UP"))
	var vec := Vector2.ZERO
	match dir:
		"UP": vec = Vector2(0.0, -90.0)
		"DOWN": vec = Vector2(0.0, 90.0)
		"LEFT": vec = Vector2(-90.0, 0.0)
		"RIGHT": vec = Vector2(90.0, 0.0)
	var from := _screen_from_parent_point(soap, soap.position)
	_start_gesture([from, from + vec], true, 0.7)

# ──────────────────────────────────────────────────────────────────
# WRING IT OUT
# Set tap_requested = true every frame; the game's _process() will
# consume it and call _on_tap() with its built-in 0.08s throttle.
# ──────────────────────────────────────────────────────────────────
func _play_wring_it_out(_delta: float) -> void:
	if tap_cooldown > 0.0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	# WringItOut._input sets tap_requested on ANY press; _process consumes it with
	# its own 0.08 s throttle and calls _on_tap(). Inject the tap, not the flag.
	_tap_at(get_viewport().get_visible_rect().size * 0.5)

# ──────────────────────────────────────────────────────────────────
# CATCH THE RAIN / BUCKET BRIGADE / CLOUD CATCHER / COVER THE DRUM
# Steer the catcher toward the nearest good (blue) falling drop.
# Legacy catchers lerp drum_node.position.x to the OS cursor in _process, so
# warping the mouse is enough for them. See _aim_catcher for why the v2 shell
# games need more than that.
# ──────────────────────────────────────────────────────────────────
func _play_catcher(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	var catcher: Node2D = g.get("drum_node")
	if catcher == null:
		catcher = g.get("bucket_node")
	if catcher == null:
		catcher = g.get("bucket")
	if catcher == null or not is_instance_valid(catcher):
		return
	var drops = g.get("drops")
	if drops == null or not drops is Array or drops.is_empty():
		drops = []
		var container: Node = g.get_node_or_null("GameLayer/ObjectsContainer")
		var search_root: Node = container if container != null else g
		for child in search_root.get_children():
			if not is_instance_valid(child):
				continue
			var is_drop := false
			if child.has_meta("type") and str(child.get_meta("type")) == "raindrop":
				is_drop = true
			if child.name.begins_with("Drop_") or child.name == "WaterDrop":
				is_drop = true
			if child is MPMovingObject:
				if child.object_type == MPMovingObject.ObjectType.WATER_DROP:
					is_drop = true
			if is_drop:
				drops.append(child)
	if drops.is_empty():
		_aim_catcher(g, catcher, catcher.position.x)
		return
	var screen_size := get_viewport().get_visible_rect().size
	var best_x: float = catcher.position.x
	var best_score: float = -INF
	# Find nearest good (blue) drop to chase.
	# `visible` is the liveness test, not an aesthetic one: the v2 games hand out
	# drops from a fixed EntityPool, and a released drop keeps the position it died
	# at — just off the bottom edge. That is the LARGEST y in the array, so it wins
	# the score below and the AI parks the drum under a drop that no longer exists.
	# Legacy catchers queue_free()d theirs, so the array only ever held live nodes.
	for drop in drops:
		if not is_instance_valid(drop):
			continue
		if not drop.visible:
			continue
		if drop is MPMovingObject and drop.is_special:
			continue
		if not drop.get_meta("good", true):
			continue
		var score: float = drop.position.y - absf(drop.position.x - catcher.position.x) * 0.3
		if score > best_score:
			best_score = score
			best_x = drop.position.x
	# Dodge any bad (red) drops near our target position — but only ones close
	# enough to the paddle to actually threaten this catch. The old test was
	# `position.y > 100.0`, written when the playfield was a small window; on a
	# 1920-tall portrait viewport the paddle sits near y=1790, so y>100 means
	# "anywhere below the top 5%" and EVERY red drop on screen counted, including
	# ones still 1500 px up that will not arrive for over a second. Each match
	# shoves best_x by 130 px — nearly twice DRUM_HALF_WIDTH — so the driver
	# repeatedly abandoned a good drop it was already lined up on to dodge a threat
	# that was not there yet.
	var threat_reach: float = catcher.position.y - screen_size.y * 0.18
	for drop in drops:
		if not is_instance_valid(drop):
			continue
		if not drop.visible:
			continue
		if drop is MPMovingObject and drop.is_special:
			continue
		if drop.get_meta("good", true):
			continue
		if drop.position.y < threat_reach:
			continue
		if absf(drop.position.x - best_x) < 80.0:
			best_x += 130.0 * signf(catcher.position.x - drop.position.x)
			best_x = clampf(best_x, 70.0, screen_size.x - 70.0)
	_aim_catcher(g, catcher, best_x)


## Point a catcher paddle at `x`.
##
## Warping the cursor steers a legacy catcher because its _process() lerps toward
## the mouse every frame. The v2 MicrogameShell does not poll: input arrives as
## events on the shell's Control, and the mouse-motion arm is gated behind
## `Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)` — a button this driver never
## holds. So a warp alone moved nothing, and the shell drum sat dead-centre for the
## whole round while the log still reported a played game. Call the handler
## directly instead, exactly as the other drivers here call _sort_bucket(),
## _on_leak_clicked() and _handle_tap().
##
## The position is passed in ALREADY MAPPED — _on_shell_gui_input is where
## _shell_map_drag applies — so control_reverse does not steer the AI into the
## wrong half. That matches every other driver in this file: they reach past the
## input layer, so no chaos effect handicaps them.
func _aim_catcher(g: Node, catcher: Node2D, x: float) -> void:
	var aim := Vector2(x, catcher.position.y)
	# v2 shell games route the injected drag through _shell_map_drag, which mirrors x
	# when the control_reverse chaos effect is active. Pre-invert so the drum still
	# lands on the intended x. Legacy/MP catchers lerp toward the raw pointer in
	# _process and never mirror, so their aim is left untouched.
	if g.has_method("_shell_drag") and "controls_reversed" in g and bool(g.get("controls_reversed")):
		aim.x = get_viewport().get_visible_rect().size.x - aim.x
	# Steer with a real injected finger for EVERY catcher: the v2 shell receives it as
	# a ScreenDrag -> _shell_drag, and the legacy/MP catchers read the emulated mouse
	# position their _process lerps toward. No direct _shell_drag() call.
	_drag_to(_screen_from_parent_point(catcher, aim))

# ──────────────────────────────────────────────────────────────────
# WATER MEMORY
# Omniscient strategy: read emoji from card meta to always pair
# correctly. Calls _on_card_pressed() directly.
# ──────────────────────────────────────────────────────────────────
func _play_water_memory(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.get("can_flip"):
		return
	if not g.has_method("_on_card_pressed"):
		return
	var cards: Array = g.get("cards")
	if cards == null or cards.is_empty():
		return
	var first_card: Node = g.get("first_card")
	if first_card == null:
		# Find a card that has at least one unmatched duplicate emoji
		for card in cards:
			if not is_instance_valid(card) or card.get_meta("matched", false):
				continue
			var my_emoji: String = card.get_meta("emoji", "")
			for other in cards:
				if not is_instance_valid(other) or other == card:
					continue
				if other.get_meta("matched", false):
					continue
				if other.get_meta("emoji", "") == my_emoji:
					if card is Control:
						# Card is a Panel with a full-rect Button bound to
						# _on_card_pressed(card); inject a tap on its centre.
						_tap_at(_screen_center_of_control(card))
						tap_cooldown = 0.5
					return
	else:
		# A card is already face-up — find its matching partner
		var target_emoji: String = first_card.get_meta("emoji", "")
		for card in cards:
			if not is_instance_valid(card) or card == first_card:
				continue
			if card.get_meta("matched", false):
				continue
			if card.get_meta("emoji", "") == target_emoji:
				if card is Control:
					_tap_at(_screen_center_of_control(card))
					tap_cooldown = 0.5
				return

# ──────────────────────────────────────────────────────────────────
# TRACE PIPE PATH
# Directly populate path_points with densely sampled target_path data,
# then call _check_path() for an instant perfect trace.
# ──────────────────────────────────────────────────────────────────
func _play_trace_pipe_path(_delta: float) -> void:
	if _gest_active:
		_step_gesture()
		return
	if swipe_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_check_path"):
		return
	var target_path: Array = g.get("target_path")
	if target_path == null or target_path.size() < 2:
		return
	# TracePipePath._handle_drawing() polls the held pointer: it starts drawing when
	# the press lands within 74px of target_path[0], appends a point every >10px of
	# travel, and grades on release (_check_path -> _complete_path when the traced
	# points hug the target). Walk a densely sampled copy of target_path with a real
	# finger instead of writing path_points and calling _check_path() directly.
	# target_path is already in VIEWPORT space (the game compares it against
	# get_mouse_position()), so the waypoints feed straight into the gesture.
	var pts: Array = []
	for i in range(target_path.size() - 1):
		var p1: Vector2 = target_path[i]
		var p2: Vector2 = target_path[i + 1]
		var steps: int = maxi(1, int(ceil(p1.distance_to(p2) / 24.0)))
		for s in range(steps):
			pts.append(p1.lerp(p2, float(s) / float(steps)))
	pts.append(target_path[-1])
	_start_gesture(pts, true, 1.8)

# ──────────────────────────────────────────────────────────────────
# GREYWATER SORTER
# Read each bucket's "safe" meta (true = garden, false = drain),
# then call _sort_bucket() directly with the correct destination.
# ──────────────────────────────────────────────────────────────────
func _play_greywater_sorter(_delta: float) -> void:
	if _gest_active:
		_step_gesture()
		return
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var buckets: Array = g.get("buckets") if "buckets" in g else []
	if buckets == null or buckets.is_empty():
		return
	var current_bucket: Node = g.get("current_bucket")
	var vp_w: float = get_viewport().get_visible_rect().size.x
	for bucket in buckets:
		if not is_instance_valid(bucket) or not (bucket is Node2D):
			continue
		if bucket == current_bucket:
			continue
		if not (bucket as Node2D).visible:
			continue
		if bucket.get_meta("being_sorted", false):
			continue
		# GreywaterSorterV2._shell_tap grabs a bucket within GRAB_RADIUS(80), _shell_drag
		# follows the finger's x, and _shell_release judges by the BUCKET's x: left of
		# 0.30*vp = garden (safe), right of 0.70*vp = drain (unsafe). Grab a real finger
		# on the bucket, drag it to the correct zone and let go — no direct _sort_bucket.
		# The 0.4s post-cooldown outlasts the 0.28s sort tween, so the bucket is pooled
		# (invisible) before this loop can pick it again.
		var is_safe: bool = bucket.get_meta("safe", true)
		var from := _screen_from_parent_point(bucket as Node2D, (bucket as Node2D).position)
		var target_x: float = vp_w * 0.15 if is_safe else vp_w * 0.85
		_start_gesture([from, Vector2(target_x, from.y), Vector2(target_x, from.y)], true, 0.4)
		return

# ──────────────────────────────────────────────────────────────────
# FILTER BUILDER
# Place each unplaced layer into its correct zone:
#   cloth=0, charcoal=1, sand=2, gravel=3
# Calls _check_filter() when all 4 layers are placed.
# ──────────────────────────────────────────────────────────────────
func _play_filter_builder(_delta: float) -> void:
	if _gest_active:
		_step_gesture()
		return
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var filter_layers: Array = g.get("filter_layers")
	if filter_layers == null:
		return
	var correct_order: Array = g.get("correct_order")
	if correct_order == null or correct_order.is_empty():
		correct_order = ["cloth", "charcoal", "sand", "gravel"]
	var bottle := g.get_node_or_null("Bottle") as Node2D
	if bottle == null:
		return
	for layer in filter_layers:
		if not is_instance_valid(layer) or not (layer is Node2D):
			continue
		if layer.get_meta("placed", false):
			continue
		var ltype: String = layer.get_meta("type", "")
		var zone_idx: int = correct_order.find(ltype)
		if zone_idx < 0:
			continue
		var zone := bottle.get_node_or_null("Zone_%d" % zone_idx) as Control
		if zone == null or zone.get_meta("filled", false):
			continue
		# FilterBuilder._handle_drag() grabs the layer whose 150px box contains the
		# pressed pointer, follows it while held, and snaps it into a zone on release
		# (-> _check_filter once all four are placed). Drag a real finger from the layer
		# to its zone centre instead of writing positions + calling _check_filter().
		var lay := layer as Node2D
		var from := _screen_from_parent_point(lay, lay.position)
		var zone_center: Vector2 = bottle.position + zone.position + zone.size * 0.5
		var to := _screen_from_parent_point(lay, zone_center)
		_start_gesture([from, to, to], true, 0.5)
		return

# ──────────────────────────────────────────────────────────────────
# TIMING TAP / QUICK SHOWER
# Use _touch_holding to control fill level. Fill until just inside
# the target window, then release.
# ──────────────────────────────────────────────────────────────────
func _play_timing_tap(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	if not "container_fill" in g or not "target_fill" in g:
		return
	var fill: float = float(g.get("container_fill"))
	var target: float = float(g.get("target_fill"))
	var tolerance: float = float(g.get("fill_tolerance")) if "fill_tolerance" in g else 10.0
	# TimingTap._input sets _touch_holding on a ScreenTouch press and its _process
	# fills while held, grading on the RELEASE edge (_check_fill succeeds when
	# |fill-target|<=tolerance). Hold a real finger until just inside the window, then
	# lift it -> graded hit, instead of writing _touch_holding directly.
	if fill < (target - tolerance + 1.0):
		_hold_at(get_viewport().get_visible_rect().size * 0.5)
	else:
		_release_pointer()

# ──────────────────────────────────────────────────────────────────
# TURN OFF TAP
# Iterate active_taps; call _on_tap_closed() on each running tap.
# ──────────────────────────────────────────────────────────────────
func _play_turn_off_tap(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_on_tap_closed"):
		return
	var active_taps: Array = g.get("active_taps")
	if active_taps == null:
		return
	for tap in active_taps:
		if not is_instance_valid(tap):
			continue
		if tap.get_meta("running", false):
			# TurnOffTap._input handles the emulated MouseButton from an injected touch
			# and tests distance to tap.position (<74), so tap the running faucet.
			_tap_at(_screen_from_parent_point(tap as Node2D, (tap as Node2D).position))
			tap_cooldown = 0.12
			return

# ──────────────────────────────────────────────────────────────────
# PLUG THE LEAK / FIX LEAK
# Hold a synthetic finger on the leaking pipe and let the game's OWN _process
# holding branch (PlugTheLeak.gd:189-221) advance plug_progress, stop the
# water_wasted accumulation and call record_action(true) honestly.
#
# The old handler poked pipe.set_meta("plug_progress") directly and never
# produced a touch, so PlugTheLeak._process saw is_holding=false, its else-branch
# (line 224) accumulated water_wasted += leak_rate*delta until end_game(false),
# and _report_accuracy(false) x objective-0 scored 0%. Injecting the real hold
# drives the same code path a human finger does. Only ONE leak exists at a time
# (the next is scheduled by the round_delay timer at PlugTheLeak.gd:219), so one
# finger suffices; release it when nothing is leaking so it cannot go phantom.
# ──────────────────────────────────────────────────────────────────
func _play_plug_the_leak(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	var pipes: Array = g.get("pipes")
	if pipes == null:
		return
	for entry in pipes:
		var pipe := entry as Node2D
		if pipe == null or not is_instance_valid(pipe):
			continue
		if not pipe.get_meta("leaking", false):
			continue
		# Aim at the pipe's own position (parent space -> viewport space). The
		# game's target rect is a generous 150x150 centred on pipe.position
		# (PlugTheLeak.gd:187), so this lands dead centre and drives the hold.
		_hold_at(_screen_from_parent_point(pipe, pipe.position))
		return
	# Nothing leaking this frame: lift the finger so it cannot linger as a phantom
	# touch into the next leak or the next round.
	_release_pointer()

# ──────────────────────────────────────────────────────────────────
# BUCKET BRIGADE
# Read people[] and bucket_at_person[]; call _handle_tap() on any
# person currently holding a bucket to pass it along the chain.
# ──────────────────────────────────────────────────────────────────
func _play_bucket_brigade(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_handle_tap"):
		return
	var people: Array = g.get("people") if "people" in g else []
	var bucket_at: Array = g.get("bucket_at_person") if "bucket_at_person" in g else []
	for i in range(mini(people.size(), bucket_at.size())):
		if bucket_at[i] != null and is_instance_valid(bucket_at[i]):
			var person: Node2D = people[i]
			if is_instance_valid(person):
				# BucketBrigadeV2._shell_tap hit-tests people[i].position; inject the tap.
				_tap_at(_screen_from_parent_point(person, person.position))
				tap_cooldown = 0.35
				return

# ──────────────────────────────────────────────────────────────────
# RICE WASH RESCUE
# The basin follows the pointer's X. Hold the finger on the pot's X
# every frame so the basin tracks the moving pot.
#
# The pointer is INJECTED, not warped: the basin reads
# TouchInputManager.get_touch_position(0) (falling back to the mouse),
# and a cursor warp reaches neither of those on a phone. See
# _drive_pointer() for the measurements.
# ──────────────────────────────────────────────────────────────────
func _play_rice_wash_rescue(_delta: float) -> void:
	var g := current_game
	if not is_instance_valid(g):
		return
	var basin: Node2D = g.get("basin_node")
	if basin == null or not is_instance_valid(basin):
		return
	var pot: Node2D = g.get("pot_node")
	# Intercept the drop that lands NEXT - not the pot that poured it. The pot only
	# spawns; the catch test is abs(drop.x - basin.x) < 85 evaluated when the drop
	# reaches basin.y - 30, and a drop stays in the air long enough for the pot to walk
	# out of that window: on Easy it falls 455px at 350px/s (1.30s) while the pot moves
	# 120px/s, so a basin glued to the pot is 156px behind the landing point and EVERY
	# drop misses. Measured: 0 catches, 8 misses, round over on max_misses. Drops fall
	# straight down, so the lowest one's x IS the interception point.
	var aim_x: float = basin.position.x
	var lowest_y: float = -INF
	var drops: Variant = g.get("water_drops")
	if drops is Array:
		for d in (drops as Array):
			if not is_instance_valid(d) or not (d is Node2D):
				continue
			var dy: float = (d as Node2D).position.y
			if dy > lowest_y:
				lowest_y = dy
				aim_x = (d as Node2D).position.x
	if lowest_y == -INF and pot != null and is_instance_valid(pot):
		# Nothing falling yet: wait under the spout so the next drop starts close.
		aim_x = pot.position.x
	# Aimed at the basin's own row: only X is read by the game, and a y taken from a
	# cursor-free viewport is 0 - the top edge, inside the dead zone a real finger
	# would be rejected in.
	_drive_pointer(_screen_from_parent_point(basin, Vector2(aim_x, basin.position.y)))

# ──────────────────────────────────────────────────────────────────
# VEGETABLE BATH
# Two-step pipeline per veggie: move to wash_bowl → call
# _check_placement, then move to clean_basket → call _check_placement.
# ──────────────────────────────────────────────────────────────────
func _play_vegetable_bath(_delta: float) -> void:
	if _gest_active:
		_step_gesture()
		return
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var veggies: Array = g.get("veggies") if "veggies" in g else []
	var wash_bowl: Node2D = g.get("wash_bowl")
	var clean_basket: Node2D = g.get("clean_basket")
	if wash_bowl == null or clean_basket == null:
		return
	# VegetableBath._input grabs the nearest veggie within GRAB_RADIUS(74) on press
	# (recording _record_touch_processed there), _process follows the held pointer,
	# and release runs _check_placement: wash_bowl -> washed, clean_basket -> done +
	# record_action(true). Drag a real finger from each veggie to the bowl, then to the
	# basket, instead of writing positions + calling _check_placement directly.
	for veggie in veggies:
		if not is_instance_valid(veggie) or not (veggie is Node2D):
			continue
		if veggie.get_meta("done", false):
			continue
		var v := veggie as Node2D
		var dest: Node2D = clean_basket if v.get_meta("washed", false) else wash_bowl
		var from := _screen_from_parent_point(v, v.position)
		var to := _screen_from_parent_point(dest, dest.position)
		_start_gesture([from, to, to], true, 0.4)
		return

# ──────────────────────────────────────────────────────────────────
# SPOT THE SPECK
# Read current_glass dirty meta; call _judge_glass() with the correct
# answer to always identify glasses accurately.
# ──────────────────────────────────────────────────────────────────
func _play_spot_the_speck(_delta: float) -> void:
	if _gest_active:
		_step_gesture()
		return
	if swipe_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var glass: Node2D = g.get("current_glass")
	if glass == null or not is_instance_valid(glass):
		return
	# SpotTheSpeck._input reads a ScreenTouch swipe: press, then release with a
	# vertical delta >60px — UP (dy<0) judges clean, DOWN (dy>0) judges dirty
	# (_judge_glass -> record_action(true) when correct). The _process mouse path
	# shares the is_swiping guard, so the injected touch cannot double-fire. Swipe a
	# real finger instead of calling _judge_glass() directly.
	var is_dirty: bool = glass.get_meta("dirty", false)
	var from := _screen_from_parent_point(glass, glass.position)
	var dy: float = 80.0 if is_dirty else -80.0
	_start_gesture([from, from + Vector2(0.0, dy)], true, 0.7)

# ──────────────────────────────────────────────────────────────────
# WATER PLANT / THIRSTY PLANT
# Monitor plants[] hydration; call _on_plant_tapped(i) for the
# driest plant before it wilts.
# ──────────────────────────────────────────────────────────────────
func _play_water_plant(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_on_plant_tapped"):
		return
	var plants: Array = g.get("plants")
	if plants == null:
		return
	var driest_idx: int = -1
	var driest_hydration: float = INF
	for i in range(plants.size()):
		var plant = plants[i]
		if not plant is Dictionary:
			continue
		var h: float = float(plant.get("hydration", 1.0))
		if h < driest_hydration:
			driest_hydration = h
			driest_idx = i
	if driest_idx >= 0 and driest_hydration < 0.45:
		var node: Node2D = plants[driest_idx].get("node")
		if node != null and is_instance_valid(node):
			# The plant container holds an invisible full-cover Button bound to
			# _on_plant_tapped(i); an injected tap -> emulated mouse press fires it.
			_tap_at(_screen_from_parent_point(node, node.position))
			tap_cooldown = 0.25

# ──────────────────────────────────────────────────────────────────
# DROPLET DASH
# Score each lane by obstacle density; call _move_lane() to switch
# into the safest available lane.
# ──────────────────────────────────────────────────────────────────
func _play_droplet_dash(_delta: float) -> void:
	if _gest_active:
		_step_gesture()
		return
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	if not g.has_method("_move_lane"):
		return
	var current_lane: int = int(g.get("current_lane")) if "current_lane" in g else 1
	var lane_count: int = int(g.get("lane_count")) if "lane_count" in g else 3
	var lane_width: float = float(g.get("lane_width")) if "lane_width" in g else 200.0
	var droplet: Node2D = g.get("droplet")
	if droplet == null or not is_instance_valid(droplet):
		return
	# Danger AND reward. Dodging on its own made this the only roster entry whose bot
	# logged 0% accuracy: record_action(true) fires ONLY when a collectible is caught
	# (30% of spawns), so a bot that merely avoids obstacles finishes with
	# correct=0 total=0 - a round indistinguishable from one where nothing moved.
	# Lanes are lane_width apart (640px at 1920 wide) and both collision tests are
	# radial at <45px, so only the item's OWN lane can reach the droplet: danger and
	# reward stay in one lane each instead of bleeding into the neighbours.
	var lane_scores: Array = []
	for lane_index in range(lane_count):
		lane_scores.append(0.0)
	# Weighted by arrival: an item one frame from the droplet's row decides the lane,
	# one that just spawned barely counts. An obstacle outweighs a collectible because
	# a hit both costs an accuracy point and spends one of only 3 lives.
	for kind in [["obstacles", -3.0], ["collectibles", 1.0]]:
		var items: Variant = g.get(str(kind[0]))
		if not (items is Array):
			continue
		for it in (items as Array):
			if not is_instance_valid(it) or not (it is Node2D):
				continue
			# Distance still to fall before it reaches the droplet's row. Already past
			# it (<= 0) means it can no longer be caught or hit.
			var gap: float = droplet.position.y - (it as Node2D).position.y
			if gap <= 0.0 or gap > DASH_LOOKAHEAD_PX:
				continue
			var lane_i: int = clampi(
				int((it as Node2D).position.x / lane_width), 0, lane_count - 1)
			lane_scores[lane_i] += float(kind[1]) * (1.0 - gap / DASH_LOOKAHEAD_PX)
	# Best lane, with a margin so a tie does not make the bot oscillate between two
	# equally empty lanes and spend every frame mid-tween.
	var best_lane: int = current_lane
	var best_score: float = lane_scores[current_lane]
	for i in range(lane_count):
		if lane_scores[i] > best_score + DASH_SWITCH_MARGIN:
			best_score = lane_scores[i]
			best_lane = i
	if best_lane != current_lane:
		# DropletDash._input fires _move_lane() from a DRAG whose |dx| exceeds
		# SWIPE_THRESHOLD(40px); one press = one lane step (_swipe_consumed guards a
		# long drag from chaining). Swipe a real finger from the droplet toward the
		# target lane instead of calling _move_lane() directly.
		var from := _screen_from_parent_point(droplet, droplet.position)
		var dir := float(signi(best_lane - current_lane))
		_start_gesture([from, from + Vector2(dir * 80.0, 0.0)], true, 0.18)

# ──────────────────────────────────────────────────────────────────
# GENERIC TAP FALLBACK
# Find all visible, non-disabled game buttons; emit pressed on the
# best candidate. Skips common UI navigation buttons by name.
# ──────────────────────────────────────────────────────────────────
## Press one of the game's OWN buttons at random. Only reached for a game with no
## authored strategy — every roster entry has one (see HANDLERS).
func _play_generic_tap(_delta: float) -> void:
	if tap_cooldown > 0:
		return
	var g := current_game
	if not is_instance_valid(g):
		return
	var game_btns := _collect_all_buttons(g)
	# No gameplay button to press is a legitimate answer: this game is driven by
	# drags or Area2D taps. Pressing whatever else is on screen instead is how the
	# bot used to press its own PAUSE and QUIT GAME.
	if game_btns.is_empty():
		return
	var chosen: Button = game_btns[randi() % game_btns.size()]
	# Inject a real tap on the button's centre: emulated mouse press -> GUI pick ->
	# pressed, exactly as a human tap. No direct emit() (which bypassed input).
	_tap_at(_screen_center_of_control(chosen))
	tap_cooldown = 0.3


## Words a player reads on a control that ENDS or SUSPENDS the round. Matched
## against the button's text, not only its name, because MiniGameBase builds its
## HUD and its pause overlay with Button.new() and never names any of it.
const SHELL_BUTTON_WORDS: Array[String] = [
	"back", "close", "skip", "menu", "pause", "undo", "home", "exit",
	"quit", "resume", "restart", "retry", "settings",
]
## The pause glyph carries no word at all — MiniGameBase draws it as "II".
## Both x glyphs are listed on purpose. The close and QUIT buttons were re-lettered from U+2715
## to U+2716 when the Android 8 tofu fix moved every on-screen glyph onto a bundled font, and this
## list matches button TEXT exactly: dropping the old one would silently stop recognising any
## screen not yet re-lettered, and the bot would start pressing its own way out of rounds again.
const SHELL_BUTTON_GLYPHS: Array[String] = ["ii", "❚❚", "⏸", "✕", "✖", "×"]


## Buttons the bot may legitimately press: on screen for real, enabled, part of
## the game rather than its shell.
##
## Three separate holes let the bot press its own way out of every round, measured
## across all 24 roster games by tools/VerifyAutoPlayDrive.tscn: the pause glyph
## was pressed in 24 of 24 and the hidden "✕ QUIT GAME" in 13 of 24.
##   * `visible` is true for a button inside a HIDDEN parent, so the whole pause
##     overlay (RESUME / QUIT GAME) and the tally screen were collected while
##     invisible. is_visible_in_tree() is the question that was meant.
##   * the skip list matched on `name`, but every one of these buttons is a bare
##     Button.new() whose name is "@Button@7", so no word in the list could match.
##     The TEXT is what a player sees, so it is what the filter reads.
##   * MiniGameBase's own pause_button_ref / pause_menu are exact answers where a
##     word list is a guess, so the subtree is excluded by reference as well.
## Pressing pause froze the tree, and the driver's _process froze with it, so
## nothing could ever resume — see _try_resume_from_pause().
func _collect_all_buttons(node: Node) -> Array:
	var out: Array = []
	_gather_playable_buttons(node, out, _shell_subtrees_of(current_game))
	return out


## Nodes whose entire subtree is shell, taken from the game itself.
func _shell_subtrees_of(g: Node) -> Array:
	var refs: Array = []
	if not is_instance_valid(g):
		return refs
	for prop in ["pause_menu", "pause_button_ref", "pause_button"]:
		if prop in g:
			var n = g.get(prop)
			if n is Node and is_instance_valid(n):
				refs.append(n)
	return refs


func _gather_playable_buttons(node: Node, out: Array, shell: Array) -> void:
	if node in shell:
		return
	if node is Button:
		var btn := node as Button
		if btn.is_visible_in_tree() and not btn.disabled and not _is_shell_button(btn):
			out.append(btn)
	for child in node.get_children():
		_gather_playable_buttons(child, out, shell)


func _is_shell_button(btn: Button) -> bool:
	var t: String = btn.text.strip_edges().to_lower()
	if t in SHELL_BUTTON_GLYPHS:
		return true
	var n: String = btn.name.to_lower()
	for w in SHELL_BUTTON_WORDS:
		if w in t or w in n:
			return true
	return false


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER MAIN GAMES (MiniGame_Rain, MiniGame_LeafSort, etc.)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _play_mp_rain(_delta: float) -> void:
	## MiniGame_Rain: Mode 1 = drag bucket, Mode 2 = click leaves
	var g := current_game
	if not is_instance_valid(g):
		return
	
	# Check player mode
	var my_mode = g.get("my_mode")
	if my_mode == null:
		return
	
	# Mode 1 (Collector): Move bucket to catch water drops
	if my_mode == 0:  # MODE_1_COLLECTOR
		_play_mp_rain_collector(g)
	# Mode 2 (Filter): Click on leaves
	else:  # MODE_2_FILTER
		_play_mp_rain_filter(g)

func _play_mp_rain_collector(g: Node) -> void:
	## Move bucket under falling water drops
	var bucket = g.get_node_or_null("GameLayer/Bucket")
	if not bucket:
		return
	
	# Find closest water drop
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	var closest_drop: Node2D = null
	var closest_dist: float = INF
	
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		var is_drop := false
		if child.name.begins_with("Drop_") or child.name == "WaterDrop":
			is_drop = true
		if child.has_meta("type") and str(child.get_meta("type")) == "raindrop":
			is_drop = true
		if child is MPMovingObject:
			if child.object_type == MPMovingObject.ObjectType.WATER_DROP:
				is_drop = true
			if child.is_special:
				is_drop = false
		if not is_drop:
			continue
		var dist = child.global_position.distance_to(bucket.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_drop = child
	
	# Move bucket toward closest drop. MiniGame_Rain mode 1 lerps bucket.position.x
	# toward viewport.get_mouse_position().x every _process frame, so pointing the
	# injected finger at the drop steers the bucket exactly as a human drag does.
	if closest_drop:
		_drag_to(_screen_from_parent_point(closest_drop, closest_drop.position))

func _play_mp_rain_filter(g: Node) -> void:
	## Click on leaves to remove them
	if tap_cooldown > 0.0:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	# Find clickable leaves
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.name.begins_with("Leaf") or child.name.begins_with("Dirt"):
			# Area2D physics picking: an injected tap -> emulated MouseButton reaches
			# the leaf's input_event, as a human tap does.
			_tap_at(_screen_from_parent_point(child as Node2D, (child as Node2D).position))
			tap_cooldown = 0.3
			return

func _play_mp_leaf_sort(_delta: float) -> void:
	## MiniGame_LeafSort: P1 = drag bucket, P2 = click leaves
	var g := current_game
	if not is_instance_valid(g):
		return
	
	var is_player_one = g.get("is_player_one")
	if is_player_one == null:
		return
	
	if is_player_one:
		# Player 1: Move bucket to catch clean leaves
		_play_mp_leaf_sort_p1(g)
	else:
		# Player 2: Click dirty leaves
		_play_mp_leaf_sort_p2(g)

func _play_mp_leaf_sort_p1(g: Node) -> void:
	## Move bucket under falling clean leaves
	var bucket = g.get_node_or_null("GameLayer/Bucket")
	if not bucket:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	var closest_leaf: Node2D = null
	var closest_dist: float = INF
	
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.name.begins_with("CleanLeaf"):
			var dist = child.global_position.distance_to(bucket.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest_leaf = child
	
	# Same poll-the-pointer path as MiniGame_Rain mode 1: point the finger at the
	# clean leaf and the bucket lerps under it (no direct position write).
	if closest_leaf:
		_drag_to(_screen_from_parent_point(closest_leaf, closest_leaf.position))

func _play_mp_leaf_sort_p2(g: Node) -> void:
	## Click dirty leaves
	if tap_cooldown > 0.0:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.name.begins_with("DirtyLeaf"):
			_tap_at(_screen_from_parent_point(child as Node2D, (child as Node2D).position))
			tap_cooldown = 0.3
			return

func _play_mp_water_harvest(_delta: float) -> void:
	## MiniGame_WaterHarvest: Mode 1 = drag bucket, Mode 2 = click dirt
	var g := current_game
	if not is_instance_valid(g):
		return
	
	var my_mode = g.get("my_mode")
	if my_mode == null:
		return
	
	if my_mode == 0:  # MODE_1_COLLECTOR
		_play_mp_rain_collector(g)  # Same as rain collector
	else:  # MODE_2_FILTER
		_play_mp_water_harvest_filter(g)

func _play_mp_water_harvest_filter(g: Node) -> void:
	## Click dirt particles
	if tap_cooldown > 0.0:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.name.begins_with("Dirt"):
			_tap_at(_screen_from_parent_point(child as Node2D, (child as Node2D).position))
			tap_cooldown = 0.3
			return

func _play_mp_greywater_sort(_delta: float) -> void:
	## MiniGame_GreywaterSort: Mode 1 = drag water to tank, Mode 2 = click filters
	var g := current_game
	if not is_instance_valid(g):
		return
	
	var my_mode = g.get("my_mode")
	if my_mode == null:
		return
	
	if my_mode == 0:  # MODE_1_SORTER
		_play_mp_greywater_sorter(g)
	else:  # MODE_2_FILTER
		_play_mp_greywater_filter(g)

func _play_mp_greywater_sorter(g: Node) -> void:
	## Drag good water to the tank.
	if _gest_active:
		_step_gesture()
		return
	if tap_cooldown > 0.0:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	var tank = g.get_node_or_null("GameLayer/GreywaterTank")
	if objects_container == null or tank == null or not (tank is Node2D):
		return
	
	# MiniGame_GreywaterSort: pressing a Greywater Area2D sets dragging_water, its
	# _input() MouseMotion follows the finger, and release inside the tank rect
	# scores good water (bad water damages). is_bad is stored as a META, so the old
	# child.get("is_bad") read a missing property (always null) and NEVER dragged.
	# A grab->drag->release gesture to the tank now drives the real input path.
	for child in objects_container.get_children():
		if not is_instance_valid(child) or not (child is Node2D):
			continue
		if child.name.begins_with("Greywater") and not child.get_meta("is_bad", false):
			var from := _screen_from_parent_point(child as Node2D, (child as Node2D).position)
			var to := _screen_from_parent_point(tank as Node2D, (tank as Node2D).position)
			_start_gesture([from, to, to], true, 0.5)
			return

func _play_mp_greywater_filter(g: Node) -> void:
	## Click filter icons
	if tap_cooldown > 0.0:
		return
	
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		return
	
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.name.begins_with("Filter"):
			_tap_at(_screen_from_parent_point(child as Node2D, (child as Node2D).position))
			tap_cooldown = 0.4
			return

func _play_mp_bucket_brigade(_delta: float) -> void:
	## MiniGame_BucketBrigade: P1 = fill buckets, P2 = empty buckets
	var g := current_game
	if not is_instance_valid(g):
		return
	
	if tap_cooldown > 0.0:
		return
	
	var is_player_one = g.get("is_player_one")
	if is_player_one == null:
		return
	
	var buckets = g.get("buckets")
	if not buckets or buckets.is_empty():
		return
	
	# P1: Click empty buckets to fill
	# P2: Click full buckets to empty
	for bucket_data in buckets:
		var status = bucket_data.get("status", "")
		var bucket_node = bucket_data.get("node")
		
		if not is_instance_valid(bucket_node):
			continue
		
		if is_player_one and status == "empty":
			# Fill it - tap the bucket Control's on-screen centre; its full-rect
			# Button.pressed -> _on_bucket_clicked(i), exactly as a human tap does.
			_tap_at(_screen_center_of_control(bucket_node as Control))
			tap_cooldown = 0.5
			return
		elif not is_player_one and status == "full":
			# Empty it
			_tap_at(_screen_center_of_control(bucket_node as Control))
			tap_cooldown = 0.5
			return

func _play_mp_generic(_delta: float) -> void:
	## Generic multiplayer handler - tries to click on interactive objects
	if tap_cooldown > 0.0:
		return
	
	var g := current_game
	if not is_instance_valid(g):
		return
	
	# Try to find objects container
	var objects_container = g.get_node_or_null("GameLayer/ObjectsContainer")
	if not objects_container:
		objects_container = g.get_node_or_null("ObjectsContainer")
	
	if not objects_container:
		return
	
	# Click first clickable child
	for child in objects_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.has_method("_input_event") or child.get("input_pickable"):
			if child is Control:
				_tap_at(_screen_center_of_control(child as Control))
			elif child is Node2D:
				_tap_at(_screen_from_parent_point(child as Node2D, (child as Node2D).position))
			tap_cooldown = 0.4
			return

# ──────────────────────────────────────────────────────────────────
# POINTER INJECTION
# The bot's one synthetic finger. Every driver that steers by POSITION
# rather than by a discrete action points it with _drive_pointer().
# ──────────────────────────────────────────────────────────────────

## Point the finger at a SCREEN position, pressing first if it is not down yet.
##
## Input.warp_mouse() used to be how the position drivers steered, and that is a
## DisplayServer *cursor* call: a phone has no cursor, so on Android the warp was a
## silent no-op and every game that reads a pointer saw one that never moved. The
## RiceWashRescue basin sat on its left clamp for a whole round on the test phone,
## caught 0 of 8 drops and lost by max misses, while the session log still recorded a
## played game with 0% accuracy - the reported "autoplay doesnt work on rice wash".
## Headless has no cursor either, which is what makes it reproducible off-device
## (tools/VerifyAutoPlayProgress.tscn measured range=0px, mean_err=1219px).
##
## A real InputEventScreenTouch/Drag pair works on every platform and reaches both
## readers this project actually uses: TouchInputManager.active_touches, which
## RiceWashRescue._process polls, and _input/_unhandled_input handlers, which is the
## only lever MP_CatchTheRain and MP_CatchRainAquarium have. It also updates the
## viewport's last-pointer position, and that is exactly what get_mouse_position()
## returns on a host with no mouse feature - so the pollers are steered too.
func _drive_pointer(view_pos: Vector2) -> void:
	# Human-sim realism for CONTINUOUS actions (item 3) lives HERE, in the single
	# continuous injector, so it is defined once and inherited by every continuous
	# caller: _hold_at, _drag_to, _step_gesture AND the handlers that drive
	# _drive_pointer directly (e.g. _play_rice_wash_rescue). A ONE-time reaction
	# delay gates the first engage; per-frame aim jitter / occasional slip follow.
	# In PERFECT the gate returns true and the aim returns view_pos unchanged, so
	# the body below is byte-identical to the pre-realism primitive.
	if not _hsim_gate_continuous(view_pos):
		return
	view_pos = _hsim_aim_continuous(view_pos)
	var vp := get_viewport()
	if vp == null:
		return
	# Kept clear of the bezel: TouchInputManager rejects a touch START inside its 15px
	# edge dead zone on mobile, which would leave the finger unpressed while this
	# manager believed it was down. No driver aims that close to an edge anyway.
	var r := vp.get_visible_rect()
	var inset := Vector2(POINTER_INSET_PX, POINTER_INSET_PX)
	view_pos = view_pos.clamp(r.position + inset, r.end - inset)
	# Injected events are read as WINDOW coordinates - Viewport turns them back into
	# viewport space with get_final_transform().affine_inverse() before any node sees
	# them. Skipping this conversion multiplied every aim by the stretch factor: on a
	# headless host (64x36 window behind a 1920x1080 viewport) an aim at 300,700
	# arrived at 9000,21000. Real devices stretch too (1920x1080 base on a 2400x1080
	# screen), so the same conversion is what makes the aim land on the phone.
	var win_pos: Vector2 = vp.get_final_transform() * view_pos
	_pointer_release_pending = false
	if not _pointer_down:
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.pressed = true
		press.position = win_pos
		Input.parse_input_event(press)
		_pointer_down = true
		_pointer_pos = win_pos
		return
	if win_pos.is_equal_approx(_pointer_pos):
		return
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = win_pos
	drag.relative = win_pos - _pointer_pos
	Input.parse_input_event(drag)
	_pointer_pos = win_pos

## Lift the finger. Called whenever the bot stops driving a live round.
##
## A finger left down is the phantom touch TouchInputManager documents:
## get_touch_count() would report it for the rest of the app's life, and
## RiceWashRescue would lock its basin to a stale position for the next round.
func _release_pointer() -> void:
	if not _pointer_down:
		_pointer_release_pending = false
		# Finger is up: a future hold must clear its ONE reaction delay again. A
		# harmless bool write in PERFECT (produces no input, changes no behaviour).
		_hsim_hold_engaged = false
		return
	# Deferred, not skipped: a paused tree does not deliver input, so lifting here
	# would clear this manager's flag while TouchInputManager kept the finger.
	if get_tree() != null and get_tree().paused:
		_pointer_release_pending = true
		return
	var lift := InputEventScreenTouch.new()
	lift.index = 0
	lift.pressed = false
	lift.position = _pointer_pos
	Input.parse_input_event(lift)
	_pointer_down = false
	_pointer_release_pending = false
	_hsim_hold_engaged = false

## Discrete tap: a MATCHED down->up InputEventScreenTouch pair (index 0) at one
## screen position, emitted through Input.parse_input_event() so a tap increments
## TouchInputManager's `received` (down) AND `up_events` (up) by exactly 1 each -
## the shape of a human finger's discrete tap. Use this for the tap games; use
## _hold_at()/_drag_to() (a finger that stays down) for hold/steer games.
##
## Coordinates and the bezel inset are the SAME conversion _drive_pointer() uses
## (viewport -> window via vp.get_final_transform(), clamped by POINTER_INSET_PX),
## so the tap lands where a real finger would and is not swallowed by
## TouchInputManager's 15px edge dead zone. The pair is self-contained: it never
## leaves a phantom finger down, and any continuous finger still down is lifted
## first so the down/up below stay matched. Skipped while the tree is paused,
## exactly like _release_pointer(): input is not delivered to a paused tree, so a
## tap there would be swallowed and could strand the down.
##
## `hold_frames` reserves the intended press duration for the human-simulation
## realism layer (item 3) and, meanwhile, spaces repeat taps by at least that many
## frames so a per-frame handler cannot flood the input queue.
func _tap_at(view_pos: Vector2, hold_frames: int = 2) -> void:
	if tap_cooldown > 0.0:
		return
	if get_tree() != null and get_tree().paused:
		return
	# Human-sim reaction delay (item 3). In PERFECT this is a no-op returning true,
	# so the tap fires immediately exactly as before. With realism on and a NEW
	# target it returns false WITHOUT consuming tap_cooldown, so the handler's next
	# per-frame call keeps the same reaction clock until it is ready to fire.
	if not _hsim_gate_discrete(view_pos):
		return
	# Aim jitter / deliberate miss. In PERFECT this returns view_pos unchanged, so
	# the clamp + transform below are byte-identical to the pre-realism primitive.
	var fire_pos: Vector2 = _hsim_aim_discrete(view_pos)
	var vp := get_viewport()
	if vp == null:
		return
	var r := vp.get_visible_rect()
	var inset := Vector2(POINTER_INSET_PX, POINTER_INSET_PX)
	fire_pos = fire_pos.clamp(r.position + inset, r.end - inset)
	var win_pos: Vector2 = vp.get_final_transform() * fire_pos
	# A continuous finger left down from a prior hold would make the pair below
	# unmatched; lift it first so this tap is a clean down->up.
	if _pointer_down:
		_release_pointer()
	# DOWN - TouchInputManager._record_diag_event() counts this as one `received`.
	_tap_down_ev.index = 0
	_tap_down_ev.pressed = true
	_tap_down_ev.position = win_pos
	Input.parse_input_event(_tap_down_ev)
	# UP - the matched release, counted as one `up_events`. Distinct object and
	# identical index/position so the pair reads as a single discrete tap.
	_tap_up_ev.index = 0
	_tap_up_ev.pressed = false
	_tap_up_ev.position = win_pos
	Input.parse_input_event(_tap_up_ev)
	# Keep the finger state consistent: nothing is down after a tap.
	_pointer_down = false
	_pointer_pos = win_pos
	_pointer_release_pending = false
	tap_cooldown = maxf(TAP_INJECT_COOLDOWN, float(hold_frames) / 60.0)

## Continuous finger down at a screen position - thin wrapper over _drive_pointer()
## for HOLD games. Presses once, then keeps the finger down across frames (a no-op
## when the position is unchanged). Lift with _release_pointer() when the hold ends.
func _hold_at(view_pos: Vector2) -> void:
	# Human-sim realism for continuous actions is applied ONCE, inside _drive_pointer
	# (the single continuous injector), so this stays a thin wrapper. The reaction
	# delay gates only the FIRST engage (_hsim_hold_engaged latches true until the
	# finger is released), never per frame, so a hold can still engage; in PERFECT
	# every hook is a no-op and this is exactly _drive_pointer(view_pos).
	_drive_pointer(view_pos)

## Semantic alias over _drive_pointer() for DRAG/steer games: the finger is already
## down (or is pressed here) and moves to view_pos. Identical mechanics to _hold_at;
## the distinct name documents intent at the call site.
func _drag_to(view_pos: Vector2) -> void:
	_drive_pointer(view_pos)

## Viewport position of a point given in `ci`'s PARENT space - the space `ci.position`
## itself is in, so a driver can hand over the coordinates it already has.
##
## Two hops: parent space -> canvas space (the parent's own global transform, which
## covers a playfield nested under scaled or offset containers) and canvas space ->
## viewport space (the canvas transform, which is where a Camera2D on an MP playfield
## lives). get_viewport_transform() is NOT used here: it is final * canvas, and the
## final part is _drive_pointer's job, applied once, there.
func _screen_from_parent_point(ci: Node2D, parent_point: Vector2) -> Vector2:
	if not is_instance_valid(ci) or not ci.is_inside_tree():
		return parent_point
	var world: Vector2 = parent_point
	var parent := ci.get_parent()
	if parent is Node2D:
		world = (parent as Node2D).get_global_transform() * parent_point
	return ci.get_canvas_transform() * world

## Viewport-space centre of a Control target (Button / Panel) so an injected tap
## lands on it. MUST use get_canvas_transform() (canvas -> viewport), NOT
## get_viewport_transform(): the latter already folds in the window/stretch
## (final) transform, and _tap_at()/_drive_pointer() apply get_final_transform()
## themselves. Using get_viewport_transform() here double-applied the stretch, so
## on a 1920-px viewport behind a 64-px headless window a card centred at (960,960)
## was reported as (32,32) and the tap then landed at window ~(1,1) - missing the
## Button entirely (WaterMemory flipped 0 cards). get_canvas_transform() matches
## _screen_from_parent_point(), so both hand _tap_at() true viewport coordinates.
func _screen_center_of_control(ctrl: Control) -> Vector2:
	if not is_instance_valid(ctrl) or not ctrl.is_inside_tree():
		return Vector2.ZERO
	return ctrl.get_canvas_transform() * ctrl.get_global_rect().get_center()

## Script a multi-frame finger path. `pts` are VIEWPORT points walked one per
## frame by _step_gesture(); the finger is pressed on the first and (when
## release_at_end) lifted on the frame after the last. `post_cooldown` spaces the
## next gesture so a handler cannot re-trigger faster than the game can react.
func _start_gesture(pts: Array, release_at_end: bool = true, post_cooldown: float = 0.0) -> void:
	# Human-sim reaction delay on the gesture's first waypoint (item 3). In PERFECT
	# this is a no-op returning true, so the gesture starts this frame exactly as
	# before. A still-reacting gesture is NOT started; the handler re-calls next
	# frame and the same reaction clock keeps running (no re-delay per frame).
	if pts.size() > 0 and not _hsim_gate_discrete(pts[0] as Vector2):
		return
	_gest_pts.clear()
	for p in pts:
		_gest_pts.append(p as Vector2)
	_gest_i = 0
	_gest_release_at_end = release_at_end
	_gest_post_cooldown = post_cooldown
	_gest_active = _gest_pts.size() > 0
	# The gesture's reaction delay has now been paid: latch the finger as engaged so
	# the continuous _drag_to() calls in _step_gesture() drive immediately (they
	# still apply aim jitter / slip). A no-op in PERFECT — _hsim_active() is false.
	if _hsim_active():
		_hsim_hold_engaged = true

## Walk one waypoint of the active gesture. Returns true while the gesture is
## still running AFTER this frame, so a caller can `return` and wait for the next.
func _step_gesture() -> bool:
	if not _gest_active:
		return false
	if _gest_i < _gest_pts.size():
		_drag_to(_gest_pts[_gest_i])
		_gest_i += 1
		return true
	# Waypoints exhausted: lift on the frame after the last move so a _process
	# poller sees the final position while the finger is still down.
	if _gest_release_at_end:
		_release_pointer()
	_gest_active = false
	if _gest_post_cooldown > 0.0:
		tap_cooldown = maxf(tap_cooldown, _gest_post_cooldown)
		swipe_cooldown = maxf(swipe_cooldown, _gest_post_cooldown)
	return false

## Drop any in-flight gesture WITHOUT lifting the finger (callers that release
## separately, e.g. the round-boundary _release_pointer(), use this).
func _reset_gesture() -> void:
	_gest_active = false
	_gest_i = 0
	_gest_pts.clear()
	_scrub_phase = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HUMAN-SIMULATION REALISM HOOKS (item 3)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Consulted by the injection primitives. EVERY function here short-circuits on
# `not _hsim_active()` — which is false in PERFECT mode and for human gameplay —
# returning the input unchanged / true, so the primitives behave exactly as they
# did before this layer. No per-action allocation: one pre-seeded _hsim_rng.

## True only when realism should actually be applied: a non-PERFECT profile AND
## the autoplay path is live. Human gameplay never reaches the primitives, and
## PERFECT (the default) never turns this on, so the invariant holds.
func _hsim_active() -> bool:
	if _hsim_profile == null or _hsim_profile.mode == HumanSimProfile.Mode.PERFECT:
		return false
	return auto_play_enabled or mp_auto_play_enabled

## Map AdaptiveDifficulty.current_difficulty ("Easy"/"Medium"/"Hard") onto the
## profile's Difficulty tier. Anything unknown reads as NORMAL.
func _hsim_diff() -> int:
	var d: String = "Medium"
	if AdaptiveDifficulty != null and "current_difficulty" in AdaptiveDifficulty:
		d = str(AdaptiveDifficulty.current_difficulty)
	match d:
		"Easy":
			return HumanSimProfile.Difficulty.EASY
		"Hard":
			return HumanSimProfile.Difficulty.HARD
		_:
			return HumanSimProfile.Difficulty.NORMAL

## Sample a reaction delay (ms) from the active difficulty's range and log it for
## the variance harness. Only ever called from a non-PERFECT path.
func _hsim_sample_reaction_ms() -> int:
	var band: Vector2 = _hsim_profile.get_reaction_range(_hsim_diff())
	var ms: int = int(round(_hsim_rng.randf_range(band.x, band.y)))
	if hsim_reaction_samples.size() < 1024:
		hsim_reaction_samples.append(ms)
	return ms

## DISCRETE reaction gate (_tap_at, _start_gesture). Returns true when the action
## may fire now. On first sight of a new target it starts a reaction clock and
## returns false (wait); the clock survives repeat per-frame calls for the SAME
## target, so it delays ONCE per target rather than every frame. In PERFECT this
## returns true immediately without touching any state.
func _hsim_gate_discrete(view_pos: Vector2) -> bool:
	if not _hsim_active():
		return true
	var now: int = Time.get_ticks_msec()
	if _hsim_reaction_ready_ms < 0 \
			or view_pos.distance_to(_hsim_reaction_target) > HSIM_REACQUIRE_PX:
		# New target: start (or restart) the reaction clock, do not fire yet.
		_hsim_reaction_target = view_pos
		_hsim_reaction_ready_ms = now + _hsim_sample_reaction_ms()
		return false
	# Same target: follow slow drift, keep the existing deadline.
	_hsim_reaction_target = view_pos
	if now < _hsim_reaction_ready_ms:
		return false
	# Deadline reached: clear the pending clock so the NEXT target re-delays.
	_hsim_reaction_ready_ms = -1
	return true

## CONTINUOUS reaction gate (_hold_at, _drag_to). The delay applies ONCE when the
## finger first engages a new target; after that it returns true every frame so a
## hold can actually engage and be re-asserted. _release_pointer() clears
## _hsim_hold_engaged so the next engage re-delays. In PERFECT returns true.
func _hsim_gate_continuous(view_pos: Vector2) -> bool:
	if not _hsim_active():
		return true
	if _hsim_hold_engaged:
		return true
	var now: int = Time.get_ticks_msec()
	if _hsim_reaction_ready_ms < 0:
		_hsim_reaction_target = view_pos
		_hsim_reaction_ready_ms = now + _hsim_sample_reaction_ms()
		return false
	if now < _hsim_reaction_ready_ms:
		return false
	_hsim_hold_engaged = true
	_hsim_reaction_ready_ms = -1
	return true

## Small random drift around the true target (a shaky but on-target hand).
func _hsim_jitter(view_pos: Vector2, scale: float = 1.0) -> Vector2:
	if not _hsim_active():
		return view_pos
	var mag: float = _hsim_profile.get_aim_jitter(_hsim_diff()) * scale
	if mag <= 0.0:
		return view_pos
	var ang: float = _hsim_rng.randf() * TAU
	var rad: float = _hsim_rng.randf() * mag
	return view_pos + Vector2(cos(ang), sin(ang)) * rad

## Roll the mistake-injection probability for the active difficulty.
func _hsim_should_miss() -> bool:
	if not _hsim_active():
		return false
	return _hsim_rng.randf() < _hsim_profile.get_mistake_rate(_hsim_diff())

## A deliberately off-target aim, so the game's OWN record_action(false) path
## produces a natural mistakes>0 and exercises its failure/retry UI.
func _hsim_miss_pos(view_pos: Vector2) -> Vector2:
	var ang: float = _hsim_rng.randf() * TAU
	var dist: float = HSIM_MISS_OFF_PX * (0.6 + _hsim_rng.randf() * 0.8)
	return view_pos + Vector2(cos(ang), sin(ang)) * dist

## Discrete aim: miss roll first, otherwise a jittered-but-on-target shot.
func _hsim_aim_discrete(view_pos: Vector2) -> Vector2:
	if not _hsim_active():
		return view_pos
	if _hsim_should_miss():
		return _hsim_miss_pos(view_pos)
	return _hsim_jitter(view_pos)

## Continuous aim: gentle jitter, with an occasional brief "slip" off-target.
func _hsim_aim_continuous(view_pos: Vector2) -> Vector2:
	if not _hsim_active():
		return view_pos
	if _hsim_rng.randf() < HSIM_SLIP_CHANCE:
		return _hsim_miss_pos(view_pos)
	return _hsim_jitter(view_pos, HSIM_CONT_JITTER_SCALE)

## Drop any pending reaction clock / engaged-hold state. Called at every round
## boundary so a delay from a finished game cannot leak into the next one.
func _hsim_reset() -> void:
	_hsim_reaction_ready_ms = -1
	_hsim_reaction_target = Vector2.INF
	_hsim_hold_engaged = false

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UTILITY FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _format_duration(_seconds: float) -> String:
	if _seconds <= 0:
		return "Unlimited"
	
	var hours = int(_seconds / 3600.0)
	var minutes = int((_seconds - hours * 3600) / 60.0)
	var secs = int(_seconds - hours * 3600 - minutes * 60)
	
	if hours > 0:
		return "%dh %dm %ds" % [hours, minutes, secs]
	if minutes > 0:
		return "%dm %ds" % [minutes, secs]
	return "%ds" % secs

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MULTIPLAYER SUPPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _process_mp_auto_play(delta: float) -> void:
	# Check MP duration limit
	if mp_auto_play_duration > 0 and mp_auto_play_start_time > 0:
		var mp_elapsed := (Time.get_ticks_msec() - mp_auto_play_start_time) / 1000.0
		if mp_elapsed >= mp_auto_play_duration:
			print("🤖 MP Auto-play duration reached (%s) — stopping" % _format_duration(mp_auto_play_duration))
			_expire_mp_auto_play()
			return

	# Drive the registered multiplayer game using the chosen strategy.
	if not current_game or not is_instance_valid(current_game):
		# No game registered — try to auto-dismiss instruction overlay
		_try_dismiss_mp_instruction_overlay()
		return
	var is_active := false
	if "game_active" in current_game:
		is_active = current_game.game_active
	elif "is_playing" in current_game:
		is_active = current_game.is_playing
	if not is_active:
		# Game exists but not started — dismiss instruction overlay if showing
		_try_dismiss_mp_instruction_overlay()
		return

	# ── Tick cooldowns (critical — without this the bot fires once then stalls) ──
	if swipe_cooldown > 0:
		swipe_cooldown -= delta
	if tap_cooldown > 0:
		tap_cooldown -= delta
	action_timer += delta

	# Reuse the existing strategy dispatch — the fallback branch handles
	# "drag_catcher" → _play_catcher and "click_target" → _play_mp_click_target.
	_dispatch_game_strategy(delta)

## Auto-dismiss instruction overlays so the MP bot can actually start playing.
func _try_dismiss_mp_instruction_overlay() -> void:
	var scene = get_tree().current_scene
	if not scene:
		return
	# Look for the InstructionOverlay's ClickCatcher button
	var overlay = scene.find_child("InstructionOverlay", true, false)
	if overlay and overlay.visible:
		var catcher = overlay.find_child("ClickCatcher", true, false)
		if catcher and catcher is Button:
			catcher.pressed.emit()
			print("🤖 MP AutoPlay: dismissed instruction overlay")


func register_multiplayer_game(game: Node, mode: String) -> void:
	if not mp_auto_play_enabled:
		return
	current_game = game
	game_name = game.get_script().resource_path.get_file().get_basename()
	# Collector-role games: move/drag a catcher to intercept falling objects
	const CATCHER_GAMES: Array[String] = [
		"MP_CatchTheRain", "MP_CatchRainAquarium",
		"MP_CollectDishWater", "MP_CollectLaundryWater", "MP_CollectShowerWater",
	]
	# Distributor-role games: click/tap interactive targets to use received water
	const TARGET_GAMES: Array[String] = [
		"MP_FillAquarium", "MP_WaterPlants", "MP_WashCar",
		"MP_MopFloor", "MP_FilterWater", "MP_FlushToilets", "MP_WashVegetables",
	]
	if game_name in CATCHER_GAMES:
		auto_play_strategy = "drag_catcher"
	elif game_name in TARGET_GAMES:
		auto_play_strategy = "click_target"
	else:
		auto_play_strategy = "tap"  # safe fallback
	action_timer = 0.0
	print(
		"🤖 Auto-play registered MP game: %s (role: %s, strategy: %s)"
		% [game_name, mode, auto_play_strategy]
	)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATS & REPORTING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Session figures for the auto-play run currently in progress.
##
## Anchored on auto_play_start_time, which set_auto_play_enabled() stamps at the
## same moment it zeroes games_played and total_score. The old anchor was a
## second field, session_start_time, that nothing ever assigned — it stayed 0, so
## the elapsed figure was the engine's whole uptime and games_per_minute was
## understated by however long the app had been open before auto-play began.
func get_session_stats() -> Dictionary:
	var elapsed_ms := Time.get_ticks_msec() - auto_play_start_time
	var elapsed_minutes := elapsed_ms / 60000.0
	
	return {
		"games_played": games_played,
		"total_score": total_score,
		"session_duration_min": elapsed_minutes,
		# float() first: two ints divide as an int, which truncated the mean.
		"average_score": float(total_score) / float(max(games_played, 1)),
		# The old max(..., 1.0) clamp did not guard a division, it rewrote the rate:
		# 5 games in 20 s reported as 5/min instead of 15/min. Zero elapsed time has
		# no rate, so it reports none.
		"games_per_minute": (float(games_played) / elapsed_minutes if elapsed_minutes > 0.0 else 0.0)
	}

func print_session_stats() -> void:
	var stats := get_session_stats()
	print("═══════════════════════════════════════════════════════")
	print("🤖 AUTO-PLAY SESSION STATS")
	print("═══════════════════════════════════════════════════════")
	print("  Games Played: %d" % stats.games_played)
	print("  Total Score: %d" % stats.total_score)
	print("  Average Score: %.1f" % stats.average_score)
	print("  Session Duration: %.1f minutes" % stats.session_duration_min)
	print("  Games/Minute: %.2f" % stats.games_per_minute)
	print("═══════════════════════════════════════════════════════")
