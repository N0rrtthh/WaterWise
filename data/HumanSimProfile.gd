class_name HumanSimProfile
extends Resource

## ═══════════════════════════════════════════════════════════════════
## HUMAN-SIMULATION PROFILE  (data-only, zero per-frame cost)
## ═══════════════════════════════════════════════════════════════════
## Opt-in realism tuning for AutoPlayManager's input-injection primitives.
##
## This Resource holds NO logic that runs per frame — it is a plain bag of
## numbers consulted by AutoPlayManager's realism layer (_hsim_*). The layer
## itself lives in the primitives so every game inherits it once.
##
## CRITICAL INVARIANT: `mode` defaults to PERFECT. In PERFECT every realism
## hook in AutoPlayManager is a no-op, so autoplay behaviour is byte-identical
## to the pre-realism build (all existing verification harnesses run in PERFECT
## and must keep passing with the same counts). Realism is strictly opt-in.
##
## Difficulty tuning philosophy (per the plan): HARD = slower reactions +
## wider miss band + higher mistake rate than EASY; NORMAL sits between them.

## How "human" the injected input should be.
enum Mode {
	PERFECT,     ## No realism — deterministic, never misses (default; preserves today's behaviour).
	HUMAN_LIKE,  ## Built-in per-difficulty defaults below.
	CUSTOM,      ## QA override — the flat custom_* scalars apply to every difficulty.
}

## Difficulty tiers. Keyed to AdaptiveDifficulty.current_difficulty:
## "Easy" -> EASY, "Hard" -> HARD, anything else ("Medium"/unknown) -> NORMAL.
enum Difficulty {
	EASY,
	NORMAL,
	HARD,
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MODE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## PERFECT by default — the invariant above.
@export var mode: int = Mode.PERFECT

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PER-DIFFICULTY DEFAULTS (used in HUMAN_LIKE mode)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## Each Vector2 is a (min, max) pair.

## Reaction time before a freshly-acquired target is acted on, in milliseconds.
## Hard reacts slower than Easy.
@export var reaction_ms: Dictionary = {
	Difficulty.EASY: Vector2(140.0, 260.0),
	Difficulty.NORMAL: Vector2(210.0, 380.0),
	Difficulty.HARD: Vector2(300.0, 540.0),
}

## Accuracy target band as a fraction 0..1 (correct / total graded actions).
## Hard lands lower (wider miss band) than Easy.
@export var accuracy_band: Dictionary = {
	Difficulty.EASY: Vector2(0.90, 0.99),
	Difficulty.NORMAL: Vector2(0.80, 0.94),
	Difficulty.HARD: Vector2(0.70, 0.88),
}

## Mistake-injection rate 0..1 — the probability a discrete action deliberately
## aims off-target (or a continuous finger "slips"), so the game's OWN
## record_action(false) path yields a natural mistakes>0. Hard misses more.
@export var mistake_rate: Dictionary = {
	Difficulty.EASY: 0.05,
	Difficulty.NORMAL: 0.11,
	Difficulty.HARD: 0.20,
}

## Aim-jitter magnitude in pixels — the max radius a shot drifts from the true
## target even when it is NOT a deliberate miss. Hard is shakier.
@export var aim_jitter_px: Dictionary = {
	Difficulty.EASY: 5.0,
	Difficulty.NORMAL: 11.0,
	Difficulty.HARD: 20.0,
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CUSTOM OVERRIDE (used in CUSTOM mode — flat, applies to every difficulty)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@export var custom_reaction_min_ms: float = 200.0
@export var custom_reaction_max_ms: float = 400.0
@export var custom_accuracy_min: float = 0.75
@export var custom_accuracy_max: float = 0.95
@export var custom_mistake_rate: float = 0.12
@export var custom_jitter_px: float = 12.0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ACCESSORS  (pure reads; safe fallbacks for missing / malformed keys)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## True when any realism should be applied at all.
func is_realism_on() -> bool:
	return mode != Mode.PERFECT

## (min, max) reaction time in ms for the given difficulty tier.
func get_reaction_range(diff: int) -> Vector2:
	if mode == Mode.CUSTOM:
		return Vector2(
			minf(custom_reaction_min_ms, custom_reaction_max_ms),
			maxf(custom_reaction_min_ms, custom_reaction_max_ms)
		)
	return _range_from(reaction_ms, diff, Vector2(210.0, 380.0))

## (min, max) accuracy band as a fraction 0..1 for the given difficulty tier.
func get_accuracy_band(diff: int) -> Vector2:
	if mode == Mode.CUSTOM:
		return Vector2(
			minf(custom_accuracy_min, custom_accuracy_max),
			maxf(custom_accuracy_min, custom_accuracy_max)
		)
	return _range_from(accuracy_band, diff, Vector2(0.80, 0.94))

## Mistake-injection probability 0..1 for the given difficulty tier.
func get_mistake_rate(diff: int) -> float:
	if mode == Mode.CUSTOM:
		return clampf(custom_mistake_rate, 0.0, 1.0)
	return clampf(_float_from(mistake_rate, diff, 0.11), 0.0, 1.0)

## Aim-jitter radius in pixels for the given difficulty tier.
func get_aim_jitter(diff: int) -> float:
	if mode == Mode.CUSTOM:
		return maxf(0.0, custom_jitter_px)
	return maxf(0.0, _float_from(aim_jitter_px, diff, 11.0))

# ── private readers ────────────────────────────────────────────────

func _range_from(table: Dictionary, diff: int, fallback: Vector2) -> Vector2:
	var v: Variant = table.get(diff, null)
	if v is Vector2:
		var vec := v as Vector2
		return Vector2(minf(vec.x, vec.y), maxf(vec.x, vec.y))
	return fallback

func _float_from(table: Dictionary, diff: int, fallback: float) -> float:
	var v: Variant = table.get(diff, null)
	if v == null:
		return fallback
	return float(v)
