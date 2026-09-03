class_name CartoonScenarios
extends RefCounted

## Declarative scenario data for CartoonStage.
##
## One entry per minigame, each with three clips:
##   cause — the situation that creates the problem the minigame solves
##   win   — the good outcome
##   lose  — the "dumb way to waste water" outcome
##
## Adding a minigame means adding a Dictionary here; no new scene or script.
## Keys per clip: palette, start_expression, props, beats.

const E := CartoonActor.Mood
const A := CartoonActor.ArmPose

# Shared palettes so clips stay visually consistent per theme.
const SKY_DAY := Color(0.44, 0.74, 0.94)
const SKY_STORM := Color(0.27, 0.35, 0.48)
const SKY_DUSK := Color(0.52, 0.42, 0.58)
const SKY_INDOOR := Color(0.86, 0.80, 0.70)
const GROUND_GRASS := Color(0.32, 0.63, 0.35)
const GROUND_DIRT := Color(0.58, 0.44, 0.30)
const GROUND_TILE := Color(0.74, 0.72, 0.68)
const WATER := Color(0.40, 0.75, 0.96)
const METAL := Color(0.62, 0.66, 0.72)

## The built table and the built fallback, kept for the life of the process.
##
## _all() used to rebuild all five families - every clip, every beat Dictionary and every
## prop Dictionary inside them - on each call, and both public entry points call it. A
## single cutscene therefore constructed the whole 25-game table at least twice:
## MiniGameIntroBridge asks has_scenario() before CartoonStage asks get_scenario(), and a
## fallback adds up to two more builds of the generic clip. Measured with
## tools/ProbeScenarioBuild on this desktop: 0.4885 ms per _all() call, 0.5248 ms per
## has_scenario(), 0.4783 ms per get_scenario() - about 1 ms of pure Dictionary allocation
## per cutscene here, and this is the machine everything is fastest on. That lands exactly
## at a scene transition on the low-end Android target.
##
## Caching is safe because the data is read-only by contract: every consumer
## (CartoonStage._apply_beat_state / _build_props / _play_beats, tools/BeatTimingReport,
## tools/VerifyCartoonCutscenes, tools/VerifyCartoonLoop) only reads with .get(), .has()
## and indexing - nothing writes into a clip, a beat or a prop spec. If that ever changes,
## the writer must duplicate first, because these dictionaries are now shared.
static var _table: Dictionary = {}
static var _generic_cache: Dictionary = {}

static func get_scenario(game_key: String, kind: int) -> Dictionary:
	var entry: Dictionary = _all().get(game_key, {})
	if entry.is_empty():
		entry = _generic()
	var clip_key := _clip_key(kind)
	var clip: Dictionary = entry.get(clip_key, {})
	if clip.is_empty():
		clip = _generic().get(clip_key, {})
	return clip

static func has_scenario(game_key: String) -> bool:
	return _all().has(game_key)

static func _clip_key(kind: int) -> String:
	match kind:
		CartoonStage.Kind.EFFECT_WIN:
			return "win"
		CartoonStage.Kind.EFFECT_LOSE:
			return "lose"
		_:
			return "cause"

# ── Generic fallback ──────────────────────────────────────────────────────

static func _generic() -> Dictionary:
	if _generic_cache.is_empty():
		_generic_cache = _build_generic()
	return _generic_cache

static func _build_generic() -> Dictionary:
	return {
		"cause": {
			"palette": {"sky": SKY_DAY, "ground": GROUND_GRASS, "skin": WATER},
			"start_expression": E.NEUTRAL,
			"props": [{"type": "bucket", "id": "bucket", "x": 0.72, "y": 0.66, "color": METAL}],
			"beats": [
				{
					"caption": "Water doesn't come from nowhere.",
					"expression": E.NEUTRAL, "arms": A.REST, "hold": 1.1,
				},
				{
					"caption": "Every drop we lose is a drop nobody drinks.",
					"expression": E.WORRIED, "arms": A.REACH,
					"action": "look_side", "hold": 1.3,
				},
				{
					"caption": "Your turn — don't waste it!",
					"expression": E.PANIC, "arms": A.UP,
					"action": "hop", "hold": 1.0,
				},
			],
		},
		"win": {
			"palette": {"sky": SKY_DAY, "ground": GROUND_GRASS, "skin": WATER},
			"start_expression": E.HAPPY,
			"props": [{"type": "bucket", "id": "bucket", "x": 0.72, "y": 0.66, "color": METAL}],
			"beats": [
				{
					"caption": "Saved!",
					"expression": E.HAPPY, "arms": A.CHEER,
					"action": "cheer", "hold": 1.0,
				},
				{
					"caption": "Every drop counted.",
					"expression": E.SMUG, "arms": A.UP,
					"action": "fill_bucket", "power": 1.0, "hold": 1.2,
				},
			],
		},
		"lose": {
			"palette": {"sky": SKY_DUSK, "ground": GROUND_DIRT, "skin": WATER},
			"start_expression": E.WORRIED,
			"props": [{"type": "puddle", "id": "puddle", "x": 0.5, "y": 0.72, "color": WATER}],
			"beats": [
				{
					"caption": "Gone down the drain.",
					"expression": E.SAD, "arms": A.DROOP,
					"action": "grow_puddle", "power": 1.2, "hold": 1.1,
				},
				{
					"caption": "That water isn't coming back.",
					"expression": E.DIZZY, "arms": A.DROOP,
					"action": "faint", "hold": 1.2,
				},
			],
		},
	}

# ── Clip builders ─────────────────────────────────────────────────────────
# Small helpers keep the scenario tables readable: each clip is
# palette + props + a list of beats.

static func _clip(
	sky: Color, ground: Color, props: Array, beats: Array,
	start_expression: int = E.NEUTRAL, skin: Color = WATER
) -> Dictionary:
	return {
		"palette": {"sky": sky, "ground": ground, "skin": skin},
		"start_expression": start_expression,
		"props": props,
		"beats": beats,
	}

static func _beat(
	caption: String, expression: int, arms: int,
	action: String = "", hold: float = 1.1, power: float = 1.0
) -> Dictionary:
	var b := {
		"caption": caption,
		"expression": expression,
		"arms": arms,
		"hold": hold,
	}
	if action != "":
		b["action"] = action
		b["power"] = power
	return b

static func _prop(
	type_name: String, x: float, y: float,
	color: Color = METAL, scale_v: float = 1.0, id: String = ""
) -> Dictionary:
	return {
		"type": type_name,
		"id": id if id != "" else type_name,
		"x": x,
		"y": y,
		"color": color,
		"scale": scale_v,
	}

static func _all() -> Dictionary:
	if _table.is_empty():
		_table = _build_all()
	return _table

static func _build_all() -> Dictionary:
	var scenarios := {}
	_add_rain_family(scenarios)
	_add_leak_family(scenarios)
	_add_reuse_family(scenarios)
	_add_plant_family(scenarios)
	_add_hygiene_family(scenarios)
	return scenarios

# ── Rain / harvesting ─────────────────────────────────────────────────────

static func _add_rain_family(out: Dictionary) -> void:
	var rain_cause := _clip(
		SKY_STORM, GROUND_GRASS,
		[
			_prop("cloud", 0.30, 0.20, Color(0.80, 0.84, 0.90), 1.2),
			_prop("cloud", 0.70, 0.16, Color(0.74, 0.78, 0.86), 1.0, "cloud2"),
			_prop("drum", 0.78, 0.60, METAL),
		],
		[
			_beat("Rainy season. Free water, falling from the sky.",
				E.NEUTRAL, A.REST, "rain", 1.3),
			_beat("And it all runs off the roof into the mud.",
				E.WORRIED, A.REACH, "look_up", 1.4),
			_beat("Catch it before it's gone!", E.PANIC, A.UP, "hop", 1.0),
		]
	)

	out["CatchTheRain"] = {
		"cause": rain_cause,
		"win": _clip(
			SKY_DAY, GROUND_GRASS,
			[_prop("drum", 0.74, 0.60, METAL),
			_prop("sun", 0.16, 0.18, Color(1.0, 0.86, 0.36))],
			[
				_beat("Caught it!", E.HAPPY, A.CHEER, "cheer", 1.0),
				_beat("A full drum — days of water, for free.",
					E.SMUG, A.UP, "fill_bucket", 1.3),
			],
			E.HAPPY
		),
		"lose": _clip(
			SKY_STORM, GROUND_DIRT,
			[_prop("drum", 0.78, 0.60, METAL),
			_prop("puddle", 0.42, 0.74, WATER, 1.3)],
			[
				_beat("Missed it. The rain hit the dirt instead.",
					E.SAD, A.DROOP, "grow_puddle", 1.2, 1.4),
				_beat("Empty drum. Dry week.", E.DIZZY, A.DROOP, "faint", 1.3),
			],
			E.WORRIED
		),
	}

	out["RainwaterHarvesting"] = {
		"cause": rain_cause,
		"win": _clip(
			SKY_DAY, GROUND_GRASS,
			[_prop("drum", 0.72, 0.60, METAL), _prop("bucket", 0.28, 0.68, METAL)],
			[
				_beat("Gutters aimed, tank open.", E.HAPPY, A.REACH, "splash", 1.0),
				_beat("Now the whole roof feeds your tank.",
					E.SMUG, A.CHEER, "fill_bucket", 1.3),
			],
			E.HAPPY
		),
		"lose": _clip(
			SKY_STORM, GROUND_DIRT,
			[_prop("drum", 0.74, 0.60, METAL),
			_prop("puddle", 0.40, 0.74, WATER, 1.4)],
			[
				_beat("The downpipe missed the tank.",
					E.SHOCKED, A.BRACE, "grow_puddle", 1.1, 1.5),
				_beat("A whole storm, wasted.", E.SAD, A.DROOP, "faint", 1.2),
			],
			E.WORRIED
		),
	}

	out["CloudCatcher"] = {
		"cause": _clip(
			SKY_STORM, GROUND_GRASS,
			[_prop("cloud", 0.34, 0.22, Color(0.82, 0.86, 0.92), 1.3),
			_prop("cloud", 0.68, 0.15, Color(0.70, 0.76, 0.84), 1.1, "cloud2")],
			[
				_beat("Clouds pass over every afternoon.", E.NEUTRAL, A.REST, "", 1.1),
				_beat("Most days nobody is ready for them.",
					E.WORRIED, A.REACH, "look_up", 1.3),
				_beat("Line up your catchers — now!", E.PANIC, A.UP, "hop", 1.0),
			]
		),
		"win": _clip(
			SKY_DAY, GROUND_GRASS,
			[_prop("bucket", 0.68, 0.66, METAL),
			_prop("sun", 0.18, 0.18, Color(1.0, 0.86, 0.36))],
			[
				_beat("Every cloud paid out.", E.HAPPY, A.CHEER, "cheer", 1.0),
				_beat("Buckets full before sunset.", E.SMUG, A.UP, "fill_bucket", 1.2),
			],
			E.HAPPY
		),
		"lose": _clip(
			SKY_DUSK, GROUND_DIRT,
			[_prop("bucket", 0.68, 0.66, METAL),
			_prop("sun", 0.80, 0.22, Color(1.0, 0.62, 0.34))],
			[
				_beat("The clouds drifted right past you.",
					E.SAD, A.REACH, "shake", 1.1),
				_beat("Sun's back out. Buckets still empty.",
					E.DIZZY, A.DROOP, "faint", 1.2),
			],
			E.WORRIED
		),
	}


# ── Leaks / taps ──────────────────────────────────────────────────────────

static func _add_leak_family(out: Dictionary) -> void:
	var leak_cause := _clip(
		SKY_INDOOR, GROUND_TILE,
		[_prop("pipe", 0.34, 0.52, METAL),
		_prop("puddle", 0.34, 0.72, WATER, 1.0)],
		[
			_beat("There's a crack in the pipe under the sink.",
				E.NEUTRAL, A.REST, "leak", 1.3),
			_beat("Drip. Drip. Drip. All day, every day.",
				E.WORRIED, A.REACH, "grow_puddle", 1.3, 1.0),
			_beat("A slow leak wastes a bucket a day. Plug it!",
				E.PANIC, A.BRACE, "panic", 1.2),
		]
	)

	var leak_win := _clip(
		SKY_INDOOR, GROUND_TILE,
		[_prop("pipe", 0.34, 0.52, METAL)],
		[
			_beat("Sealed. Silence.", E.HAPPY, A.CHEER, "cheer", 1.0),
			_beat("No more drip. That's a bucket saved every day.",
				E.SMUG, A.UP, "hop", 1.2),
		],
		E.HAPPY
	)

	var leak_lose := _clip(
		SKY_INDOOR, GROUND_TILE,
		[_prop("pipe", 0.34, 0.52, METAL),
		_prop("puddle", 0.40, 0.74, WATER, 1.5)],
		[
			_beat("The leak won.", E.SHOCKED, A.BRACE, "leak", 1.1),
			_beat("Floor's flooded and the meter keeps spinning.",
				E.DIZZY, A.DROOP, "faint", 1.3),
		],
		E.WORRIED
	)

	for key in ["FixLeak", "PlugTheLeak", "TracePipePath"]:
		out[key] = {"cause": leak_cause, "win": leak_win, "lose": leak_lose}

	out["TurnOffTap"] = {
		"cause": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("tap", 0.62, 0.50, METAL),
			_prop("puddle", 0.62, 0.72, WATER, 0.9)],
			[
				_beat("Someone left the tap running.", E.SHOCKED, A.REST, "leak", 1.2),
				_beat("Clean water, straight down the drain.",
					E.WORRIED, A.REACH, "grow_puddle", 1.2, 1.1),
				_beat("Shut it off — fast!", E.PANIC, A.UP, "hop", 0.9),
			]
		),
		"win": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("tap", 0.62, 0.50, METAL)],
			[
				_beat("Off. Just like that.", E.HAPPY, A.CHEER, "cheer", 1.0),
				_beat("Two seconds of effort, litres saved.",
					E.SMUG, A.UP, "hop", 1.1),
			],
			E.HAPPY
		),
		"lose": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("tap", 0.62, 0.50, METAL),
			_prop("puddle", 0.55, 0.74, WATER, 1.6)],
			[
				_beat("Still running.", E.SHOCKED, A.BRACE, "leak", 1.0),
				_beat("The whole sink overflowed. Oops.",
					E.DIZZY, A.DROOP, "faint", 1.3),
			],
			E.WORRIED
		),
	}

	out["TimingTap"] = out["TurnOffTap"]
	out["ToiletTankFix"] = {
		"cause": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("drum", 0.68, 0.58, Color(0.86, 0.88, 0.92)),
			_prop("puddle", 0.68, 0.76, WATER, 0.8)],
			[
				_beat("The toilet tank never stops refilling.",
					E.NEUTRAL, A.REST, "leak", 1.2),
				_beat("That's drinking water flushing itself away.",
					E.WORRIED, A.REACH, "grow_puddle", 1.3, 1.0),
				_beat("Fix the float!", E.PANIC, A.UP, "hop", 0.9),
			]
		),
		"win": leak_win,
		"lose": leak_lose,
	}


# ── Reuse / greywater ─────────────────────────────────────────────────────

static func _add_reuse_family(out: Dictionary) -> void:
	var reuse_win := _clip(
		SKY_INDOOR, GROUND_TILE,
		[_prop("bucket", 0.68, 0.66, METAL), _prop("plant", 0.28, 0.60, GROUND_GRASS)],
		[
			_beat("Caught it in the bucket.", E.HAPPY, A.REACH, "splash", 1.0),
			_beat("Used twice — once for you, once for the garden.",
				E.SMUG, A.CHEER, "fill_bucket", 1.3),
		],
		E.HAPPY
	)

	var reuse_lose := _clip(
		SKY_INDOOR, GROUND_TILE,
		[_prop("puddle", 0.50, 0.74, Color(0.52, 0.58, 0.48), 1.4)],
		[
			_beat("Straight down the drain.", E.SAD, A.DROOP, "grow_puddle", 1.1, 1.4),
			_beat("Water good enough for plants, thrown away.",
				E.DIZZY, A.DROOP, "faint", 1.3),
		],
		E.WORRIED
	)

	out["RiceWashRescue"] = {
		"cause": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("bucket", 0.66, 0.66, METAL), _prop("tap", 0.30, 0.48, METAL)],
			[
				_beat("Rice gets rinsed before every meal.",
					E.NEUTRAL, A.REST, "", 1.1),
				_beat("That cloudy water is plant food — and it's heading for the drain.",
					E.WORRIED, A.REACH, "look_side", 1.4),
				_beat("Catch it!", E.PANIC, A.REACH, "hop", 0.9),
			]
		),
		"win": reuse_win,
		"lose": reuse_lose,
	}

	out["VegetableBath"] = {
		"cause": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("bucket", 0.64, 0.66, METAL), _prop("plant", 0.26, 0.60, GROUND_GRASS)],
			[
				_beat("Vegetables need a wash before cooking.",
					E.NEUTRAL, A.REST, "", 1.1),
				_beat("Most people run the tap the whole time.",
					E.WORRIED, A.REACH, "leak", 1.3),
				_beat("Use a basin, not the tap!", E.PANIC, A.UP, "hop", 1.0),
			]
		),
		"win": reuse_win,
		"lose": reuse_lose,
	}

	out["GreywaterSorter"] = {
		"cause": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("bucket", 0.32, 0.66, Color(0.60, 0.70, 0.62)),
			_prop("bucket", 0.68, 0.66, METAL, 1.0, "bucket2")],
			[
				_beat("Not all used water is the same.",
					E.NEUTRAL, A.REST, "", 1.1),
				_beat("Rinse water waters plants. Soapy water does not.",
					E.WORRIED, A.REACH, "look_side", 1.4),
				_beat("Sort it right!", E.PANIC, A.BRACE, "shake", 1.0),
			]
		),
		"win": reuse_win,
		"lose": reuse_lose,
	}

	out["WringItOut"] = {
		"cause": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("bucket", 0.66, 0.66, METAL)],
			[
				_beat("The cloth is soaked after mopping.",
					E.NEUTRAL, A.REST, "", 1.0),
				_beat("Toss it in the sink and that water's gone.",
					E.WORRIED, A.REACH, "leak", 1.3),
				_beat("Wring every drop into the bucket!",
					E.PANIC, A.BRACE, "squash", 1.0, 0.5),
			]
		),
		"win": reuse_win,
		"lose": reuse_lose,
	}

	out["BucketBrigade"] = {
		"cause": _clip(
			SKY_DAY, GROUND_DIRT,
			[_prop("bucket", 0.24, 0.68, METAL),
			_prop("drum", 0.78, 0.60, METAL)],
			[
				_beat("The tap is at the end of the street.",
					E.NEUTRAL, A.REST, "", 1.1),
				_beat("Every spilled bucket is another walk in the sun.",
					E.WORRIED, A.REACH, "grow_puddle", 1.3, 0.8),
				_beat("Carry it steady!", E.PANIC, A.REACH, "hop", 0.9),
			]
		),
		"win": _clip(
			SKY_DAY, GROUND_DIRT,
			[_prop("drum", 0.74, 0.60, METAL)],
			[
				_beat("Not a drop spilled.", E.HAPPY, A.CHEER, "cheer", 1.0),
				_beat("Tank's full and your arms survived.",
					E.SMUG, A.UP, "fill_bucket", 1.2),
			],
			E.HAPPY
		),
		"lose": _clip(
			SKY_DUSK, GROUND_DIRT,
			[_prop("puddle", 0.48, 0.74, WATER, 1.5)],
			[
				_beat("The bucket tipped.", E.SHOCKED, A.BRACE, "splash", 1.0),
				_beat("Back to the tap. Again.", E.SAD, A.DROOP, "faint", 1.3),
			],
			E.WORRIED
		),
	}

	out["DropletDash"] = out["BucketBrigade"]


# ── Plants / garden ───────────────────────────────────────────────────────

static func _add_plant_family(out: Dictionary) -> void:
	var plant_cause := _clip(
		SKY_DAY, GROUND_DIRT,
		[_prop("plant", 0.68, 0.58, GROUND_GRASS),
		_prop("sun", 0.16, 0.18, Color(1.0, 0.82, 0.34)),
		_prop("bucket", 0.28, 0.68, METAL)],
		[
			_beat("Hot afternoon. The plants are drooping.",
				E.WORRIED, A.REST, "wilt", 1.3),
			_beat("Too little and they die. Too much and it drains away.",
				E.NEUTRAL, A.REACH, "look_side", 1.4),
			_beat("Water it just right!", E.PANIC, A.REACH, "hop", 1.0),
		],
		E.WORRIED
	)

	var plant_win := _clip(
		SKY_DAY, GROUND_GRASS,
		[_prop("plant", 0.68, 0.58, Color(0.30, 0.72, 0.34)),
		_prop("bucket", 0.28, 0.68, METAL)],
		[
			_beat("Perfect pour.", E.HAPPY, A.REACH, "splash", 1.0),
			_beat("Roots got the water — none of it wasted.",
				E.SMUG, A.CHEER, "cheer", 1.2),
		],
		E.HAPPY
	)

	var plant_lose := _clip(
		SKY_DUSK, GROUND_DIRT,
		[_prop("plant", 0.68, 0.58, Color(0.62, 0.54, 0.28)),
		_prop("puddle", 0.40, 0.74, WATER, 1.3)],
		[
			_beat("Too much, too fast.", E.SHOCKED, A.BRACE, "grow_puddle", 1.1, 1.4),
			_beat("The soil couldn't hold it, and the plant still wilted.",
				E.SAD, A.DROOP, "wilt", 1.3),
		],
		E.WORRIED
	)

	for key in ["ThirstyPlant", "WaterPlant"]:
		out[key] = {"cause": plant_cause, "win": plant_win, "lose": plant_lose}

	out["MudPieMaker"] = {
		"cause": _clip(
			SKY_DAY, GROUND_DIRT,
			[_prop("bucket", 0.66, 0.66, METAL),
			_prop("puddle", 0.34, 0.74, Color(0.52, 0.38, 0.24), 1.0)],
			[
				_beat("Mud pies need water. Not a whole bucket of it.",
					E.NEUTRAL, A.REST, "", 1.1),
				_beat("Get the mix wrong and you pour it out and start again.",
					E.WORRIED, A.REACH, "grow_puddle", 1.3, 1.1),
				_beat("Measure carefully!", E.PANIC, A.REACH, "shake", 1.0),
			]
		),
		"win": _clip(
			SKY_DAY, GROUND_DIRT,
			[_prop("bucket", 0.66, 0.66, METAL)],
			[
				_beat("Perfect consistency, first try.", E.HAPPY, A.CHEER, "cheer", 1.0),
				_beat("Nothing poured out. Nothing wasted.",
					E.SMUG, A.UP, "hop", 1.1),
			],
			E.HAPPY
		),
		"lose": _clip(
			SKY_DUSK, GROUND_DIRT,
			[_prop("puddle", 0.48, 0.74, Color(0.48, 0.34, 0.22), 1.6)],
			[
				_beat("Soup, not mud.", E.SHOCKED, A.BRACE, "splash", 1.0),
				_beat("Tip it out and fetch more water. Again.",
					E.DIZZY, A.DROOP, "faint", 1.3),
			],
			E.WORRIED
		),
	}


# ── Washing / hygiene / purity ────────────────────────────────────────────

static func _add_hygiene_family(out: Dictionary) -> void:
	var shower_cause := _clip(
		SKY_INDOOR, GROUND_TILE,
		[_prop("showerhead", 0.50, 0.30, METAL),
		_prop("puddle", 0.50, 0.74, WATER, 1.0),
		_prop("bucket", 0.76, 0.66, METAL)],
		[
			_beat("A long shower feels great.", E.HAPPY, A.REST, "rain", 1.2),
			_beat("It also drains more water than a family drinks in a day.",
				E.SHOCKED, A.BRACE, "grow_puddle", 1.4, 1.2),
			_beat("Keep it short!", E.PANIC, A.UP, "panic", 1.1),
		],
		E.HAPPY
	)

	var wash_win := _clip(
		SKY_INDOOR, GROUND_TILE,
		[_prop("bucket", 0.70, 0.66, METAL)],
		[
			_beat("Quick and clean.", E.HAPPY, A.CHEER, "cheer", 1.0),
			_beat("Same result, a fraction of the water.",
				E.SMUG, A.UP, "hop", 1.2),
		],
		E.HAPPY
	)

	var wash_lose := _clip(
		SKY_INDOOR, GROUND_TILE,
		[_prop("puddle", 0.50, 0.74, WATER, 1.6)],
		[
			_beat("The tap ran the whole time.",
				E.SHOCKED, A.BRACE, "grow_puddle", 1.1, 1.6),
			_beat("Litres gone, and you're still not done.",
				E.DIZZY, A.DROOP, "faint", 1.3),
		],
		E.WORRIED
	)

	out["QuickShower"] = {"cause": shower_cause, "win": wash_win, "lose": wash_lose}

	out["ScrubToSave"] = {
		"cause": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("tap", 0.30, 0.48, METAL), _prop("bucket", 0.70, 0.66, METAL)],
			[
				_beat("Dishes pile up after dinner.", E.NEUTRAL, A.REST, "", 1.0),
				_beat("Scrubbing under a running tap wastes most of it.",
					E.WORRIED, A.REACH, "leak", 1.3),
				_beat("Scrub first, rinse once!", E.PANIC, A.BRACE, "shake", 1.0),
			]
		),
		"win": wash_win,
		"lose": wash_lose,
	}

	out["SwipeTheSoap"] = out["ScrubToSave"]

	out["SpotTheSpeck"] = {
		"cause": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("bucket", 0.50, 0.62, METAL)],
			[
				_beat("This is the water you're about to drink.",
					E.NEUTRAL, A.REST, "", 1.1),
				_beat("Look closer. Something's floating in it.",
					E.SHOCKED, A.REACH, "look_side", 1.3),
				_beat("Find every speck!", E.PANIC, A.REACH, "shake", 1.0),
			]
		),
		"win": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("bucket", 0.50, 0.62, METAL)],
			[
				_beat("Crystal clear.", E.HAPPY, A.CHEER, "cheer", 1.0),
				_beat("Safe to drink — no boiling, no waste.",
					E.SMUG, A.UP, "fill_bucket", 1.2),
			],
			E.HAPPY
		),
		"lose": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("bucket", 0.50, 0.62, Color(0.56, 0.54, 0.42))],
			[
				_beat("You missed one.", E.SHOCKED, A.BRACE, "shake", 1.0),
				_beat("Now the whole batch has to be thrown out.",
					E.DIZZY, A.DROOP, "faint", 1.3),
			],
			E.WORRIED
		),
	}

	out["FilterBuilder"] = {
		"cause": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("drum", 0.66, 0.58, METAL),
			_prop("bucket", 0.30, 0.68, Color(0.56, 0.52, 0.40))],
			[
				_beat("The only water left is muddy.",
					E.WORRIED, A.REST, "", 1.1),
				_beat("Sand, charcoal, gravel — in the right order it comes out clean.",
					E.NEUTRAL, A.REACH, "look_side", 1.4),
				_beat("Wrong order and you waste the whole batch. Build it!",
					E.PANIC, A.BRACE, "shake", 1.1),
			],
			E.WORRIED
		),
		"win": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("drum", 0.66, 0.58, METAL), _prop("bucket", 0.30, 0.68, METAL)],
			[
				_beat("Clear water out the bottom.",
					E.HAPPY, A.REACH, "splash", 1.0),
				_beat("Muddy water, made drinkable. No waste.",
					E.SMUG, A.CHEER, "fill_bucket", 1.3),
			],
			E.HAPPY
		),
		"lose": _clip(
			SKY_INDOOR, GROUND_TILE,
			[_prop("bucket", 0.50, 0.66, Color(0.50, 0.46, 0.34)),
			_prop("puddle", 0.50, 0.76, Color(0.48, 0.42, 0.30), 1.2)],
			[
				_beat("Still murky.", E.SHOCKED, A.BRACE, "grow_puddle", 1.1, 1.2),
				_beat("Layers in the wrong order. Start over.",
					E.DIZZY, A.DROOP, "faint", 1.3),
			],
			E.WORRIED
		),
	}

	out["CoverTheDrum"] = {
		"cause": _clip(
			SKY_DUSK, GROUND_DIRT,
			[_prop("drum", 0.58, 0.58, METAL)],
			[
				_beat("The storage drum is full and wide open.",
					E.NEUTRAL, A.REST, "", 1.1),
				_beat("Uncovered water breeds mosquitoes overnight.",
					E.SHOCKED, A.BRACE, "shake", 1.4),
				_beat("Get the lid on!", E.PANIC, A.UP, "hop", 0.9),
			]
		),
		"win": _clip(
			SKY_DAY, GROUND_GRASS,
			[_prop("drum", 0.58, 0.58, METAL)],
			[
				_beat("Sealed tight.", E.HAPPY, A.CHEER, "cheer", 1.0),
				_beat("Clean water, still clean tomorrow.",
					E.SMUG, A.UP, "hop", 1.2),
			],
			E.HAPPY
		),
		"lose": _clip(
			SKY_DUSK, GROUND_DIRT,
			[_prop("drum", 0.58, 0.58, Color(0.50, 0.52, 0.46))],
			[
				_beat("Too slow.", E.SHOCKED, A.BRACE, "shake", 1.0),
				_beat("The whole drum has to be dumped now.",
					E.DIZZY, A.DROOP, "faint", 1.3),
			],
			E.WORRIED
		),
	}

	out["WaterMemory"] = out["SpotTheSpeck"]

