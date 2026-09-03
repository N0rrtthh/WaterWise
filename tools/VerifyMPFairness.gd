extends Node

## MULTIPLAYER FAIRNESS SWEEP - all 12 MP_* games in one pass.
##
## WHAT THIS MEASURES AND WHY IT IS ANALYTIC
##
## A co-op round here is two different games wired together: one player produces water, the
## other spends it, and both pay into one CRDT G-Counter and one 3-life pool. That makes a
## whole class of defect invisible from inside either game - a failure rule whose threshold
## cannot be crossed before the clock runs out, a fail timer that ticks while the player has
## nothing to act with, a role whose point ceiling is a fraction of its partner's. None of
## them error, none of them look wrong in isolation, and a bot cannot demonstrate them:
## AutoPlayManager's MP bots are heuristic ("drag_catcher"/"click_target"), so a bot that
## wins proves winnability but a bot that loses proves nothing. So this sweep computes the
## round's arithmetic from numbers read off the live instance and its script constants.
##
## Every number below is READ, not assumed: game_duration and win_quota off the instance
## after start_game(), spawn cadence off the live Timer's wait_time (so difficulty scaling
## is included), thresholds and point values out of get_script_constant_map(). Where a game
## pays a literal - add_score(10) - the literal is parsed from its source at the declared
## call site, and a call site that has moved is reported as unresolved rather than skipped.
## A criterion with no sensor behind it publishes null, never true.

const MP_SRC_DIR := "res://scripts/multiplayer"
const MP_SCENE_DIR := "res://scenes/multiplayer"
const MP_PORT := 28051
const SETTLE_FRAMES := 30

## Human action rate ceiling, actions/second. Same bound tools/VerifyFairness.gd uses for the
## single-player quota pace, for the same reason: a role's ceiling is limited by how fast a
## finger can go, not only by how much work the game offers.
const MAX_APS := 1.6

## How far apart two roles in one pair may sit in reachable points. CoopAdaptation compares
## each player's performance across the pair to pick the next tier, and the shared scoreboard
## shows both totals, so a role that cannot approach its partner's number reads as the weak
## player no matter how well it is played. 3x is generous - it is a defect bound, not a design
## target.
const MAX_ROLE_RATIO := 3.0

## Cross-supply margin: units the producer can send per round over units the consumer needs
## to finish its own quota. 1.0 is exact-supply, which leaves no room for a single miss.
const MIN_SUPPLY_MARGIN := 1.0

## THE ROUND MODEL, ONE ENTRY PER MP GAME
##
## Each entry says WHERE to read a number, never what the number is. Fields:
##   g       script/scene basename under scripts/multiplayer.
##   pts     points paid per scoring action - {"c": CONST} or {"f": func, "n": "add_score("}
##           to parse the literal at that call site. bonus adds a second literal per action.
##   acts    how many scoring chances the round offers:
##             {"k":"spawn","t":"spawn_timer"}      live Timer.wait_time off the instance
##             {"k":"interval","c":CONST,"plus":N}  a mess/re-dirty cadence, +N present at start
##             {"k":"supply"}                       nothing but partner water limits it
##             {"k":"fixed","n":N,"nn":needle}      a fixed board, N verified against source
##   taps    taps per scoring action (default 1) - only >1 where one score costs several taps.
##   sends   resource units handed to the partner per own action (producers).
##   fail    the advertised failure rule:
##             c     threshold constant
##             k     "time" (seconds of neglect) or "count" (simultaneous/total mess)
##             per   event source for "count", same shapes as acts
##             after optional constant the first event waits on (a wilt age)
##             gate  true when the player needs partner water to answer it
##             gate_f function whose body must test available_water for the gate to be real
const MODEL: Array[Dictionary] = [
	{"g": "MP_CollectShowerWater", "pair": "producer",
		"pts": {"c": "POINTS_PER_DROP"}, "acts": {"k": "spawn", "t": "spawn_timer"},
		"sends": {"c": "BUCKET_CAPACITY"}, "sends_per": {"c": "BUCKET_CAPACITY"},
		"fail": {"c": "MAX_OVERFLOW", "k": "count", "per": {"k": "spawn", "t": "spawn_timer"}}},
	{"g": "MP_CollectLaundryWater", "pair": "producer",
		"pts": {"c": "POINTS_PER_CATCH"}, "acts": {"k": "spawn", "t": "spawn_timer"},
		"sends": {"c": "CONTAINER_CAPACITY"}, "sends_per": {"c": "CONTAINER_CAPACITY"},
		"fail": {"c": "MAX_MISSED", "k": "count", "per": {"k": "spawn", "t": "spawn_timer"}}},
	{"g": "MP_CollectDishWater", "pair": "producer",
		"pts": {"c": "POINTS_PER_DROP"}, "acts": {"k": "spawn", "t": "spawn_timer"},
		"sends": {"n": 1}, "sends_per": {"n": 1},
		"fail": {"c": "MAX_SPILLS", "k": "count", "per": {"k": "spawn", "t": "spawn_timer"}}},
	{"g": "MP_CatchRainAquarium", "pair": "producer",
		"pts": {"c": "POINTS_PER_DROP"}, "acts": {"k": "spawn", "t": "spawn_timer"},
		"sends": {"n": 1}, "sends_per": {"n": 1},
		"fail": {"c": "MAX_MISSED", "k": "count", "per": {"k": "spawn", "t": "spawn_timer"}},
		"catch": {"speed": "BUCKET_SPEED", "fall": "DROP_SPEED"}},
	{"g": "MP_CatchTheRain", "pair": "producer",
		"pts": {"c": "POINTS_PER_DROP"},
		"acts": {"k": "spawn", "t": "spawn_timer"},
		"sends": {"n": 1}, "sends_per": {"n": 1},
		"fail": {"c": "MAX_ALLOWED_MISSES", "k": "count", "per": {"k": "spawn", "t": "spawn_timer"}},
		"catch": {"speed": "BUCKET_SPEED", "fall": "DROP_SPEED"}},
	{"g": "MP_WashVegetables", "pair": "producer",
		"pts": {"c": "POINTS_PER_VEGGIE"},
		"acts": {"k": "spawn", "t": "spawn_timer"},
		"sends": {"c": "DIRTY_WATER_PER_VEGGIE"}, "sends_per": {"n": 1},
		"fail": {"c": "MAX_MISSES", "k": "count", "per": {"k": "spawn", "t": "spawn_timer"}}},
	{"g": "MP_WaterPlants", "pair": "consumer",
		"pts": {"c": "POINTS_PER_PLANT"},
		"acts": {"k": "interval", "c": "PLANT_RECOVERY_SECONDS", "plus": 12},
		"needs": {"c": "WATER_PER_PLANT"}, "own_quota": {"c": "QUOTA_P2"},
		"fail": {"c": "MAX_WILTED", "k": "count",
			"per": {"k": "fixed", "n": 12, "nn": "for i in range(12)"},
			"after": {"c": "WILT_SECONDS"}, "gate": true, "gate_f": "_check_wilted_plants"}},
	{"g": "MP_FlushToilets", "pair": "consumer",
		"pts": {"f": "_try_flush", "n": "add_score("},
		"acts": {"k": "interval", "c": "DIRTY_INTERVAL", "plus": 1},
		"needs": {"n": 1},
		"fail": {"c": "MAX_UNFLUSHED", "k": "count",
			"per": {"k": "interval", "c": "DIRTY_INTERVAL", "plus": 1},
			"gate": true, "gate_f": "_mark_toilet_dirty"}},
	{"g": "MP_MopFloor", "pair": "consumer",
		"pts": {"f": "_try_mop", "n": "add_score("},
		"acts": {"k": "interval", "c": "DIRTY_INTERVAL", "plus": 1},
		"needs": {"n": 1},
		"fail": {"c": "MAX_DIRTY_TILES", "k": "count",
			"per": {"k": "interval", "c": "DIRTY_INTERVAL", "plus": 1},
			"gate": true, "gate_f": "_make_tile_dirty"}},
	{"g": "MP_WashCar", "pair": "consumer",
		"pts": {"f": "_try_wash", "n": "add_score("},
		"acts": {"k": "interval", "c": "RE_DIRTY_SECONDS", "plus": 1},
		"needs": {"n": 1},
		"fail": {"c": "MAX_DIRTY_TIME", "k": "time", "gate": true, "gate_f": "_process"}},
	{"g": "MP_FillAquarium", "pair": "consumer",
		"pts": {"c": "POINTS_PER_ADD"}, "acts": {"k": "supply"},
		"needs": {"n": 1}, "own_quota": {"c": "ADDS_TO_WIN"},
		"fail": {"c": "MAX_EMPTY_TIME", "k": "time", "gate": true, "gate_f": "_process"}},
	{"g": "MP_FilterWater", "pair": "consumer",
		"pts": {"c": "POINTS_PER_PARTICLE", "times": {"c": "PARTICLES_PER_WATER"}},
		"bonus": {"c": "BONUS_PER_UNIT"},
		"acts": {"k": "supply"}, "taps": {"c": "PARTICLES_PER_WATER"}, "needs": {"n": 1},
		"fail": {}},
]

## Every criterion this sweep can report, so a game that resolves none of them is visible as
## unmeasured rather than absent from the output.
const CRITERIA: Array[String] = ["duration", "fail_reachable", "powerless_gate",
	"decided_by_play", "role_ratio", "supply_margin", "catch_reachable"]

var passed: int = 0
var failed: int = 0
var src_cache: Dictionary = {}

var unmeasured: int = 0

func _check(ok: bool, what: String, detail: String) -> void:
	if ok:
		passed += 1
		print("    [PASS] %s — %s" % [what, detail])
	else:
		failed += 1
		print("    [FAIL] %s — %s" % [what, detail])

## A criterion with nothing behind it. Never a pass: an unresolved constant or a moved call
## site means this sweep stopped measuring, which is exactly the state that must not read as
## green. Counted apart from failures so the summary can say which it was.
func _null(what: String, why: String) -> void:
	unmeasured += 1
	print("    [NULL] %s — unmeasured: %s" % [what, why])

func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _src(g: String) -> PackedStringArray:
	if src_cache.has(g):
		return src_cache[g]
	var f := FileAccess.open("%s/%s.gd" % [MP_SRC_DIR, g], FileAccess.READ)
	var lines: PackedStringArray = PackedStringArray()
	if f:
		lines = f.get_as_text().split("\n")
		f.close()
	src_cache[g] = lines
	return lines

## Constants come out of the script's own constant map - Object.get() cannot see a const.
func _const(g: String, name: String) -> Variant:
	var gs := load("%s/%s.gd" % [MP_SRC_DIR, g]) as GDScript
	if gs == null:
		return null
	var m := gs.get_script_constant_map()
	return m.get(name, null)

## The lines of one function body: from its declaration to the next top-level func.
func _body(g: String, fname: String) -> PackedStringArray:
	var out := PackedStringArray()
	var inside := false
	for line in _src(g):
		if line.begins_with("func "):
			if inside:
				break
			inside = line.begins_with("func %s(" % fname)
			continue
		if inside:
			out.append(line)
	return out

## The integer a call site pays, parsed where it stands. Declared by function rather than by
## line so an edit that moves the call still resolves, and an edit that REMOVES it reports -1
## instead of quietly reading as zero points.
func _lit_in(g: String, fname: String, prefix: String) -> int:
	for line in _body(g, fname):
		var at := line.find(prefix)
		if at < 0:
			continue
		var rest := line.substr(at + prefix.length())
		var digits := ""
		for i in range(rest.length()):
			var ch := rest[i]
			if ch >= "0" and ch <= "9":
				digits += ch
			else:
				break
		if digits != "":
			return int(digits)
	return -1

## Whether a fail path actually consults the player's water before charging the team a life.
## Read as a needle inside the deciding function: the gate is only real if the branch that
## calls report_miss_to_host() can see available_water.
func _gate_in(g: String, fname: String) -> bool:
	var body := _body(g, fname)
	var saw_water := false
	var saw_miss := false
	for line in body:
		if line.contains("available_water"):
			saw_water = true
		if line.contains("report_miss_to_host"):
			saw_miss = true
	return saw_water and saw_miss

## Resolve a {"c": CONST} / {"n": literal} number. Returns NAN when the constant is gone.
func _num(g: String, spec: Variant) -> float:
	if typeof(spec) != TYPE_DICTIONARY:
		return NAN
	var d: Dictionary = spec
	if d.has("n"):
		return float(d["n"])
	if d.has("c"):
		var v: Variant = _const(g, String(d["c"]))
		return NAN if v == null else float(v)
	return NAN

func _has_needle(g: String, needle: String) -> bool:
	for line in _src(g):
		if line.contains(needle):
			return true
	return false

## How many times an event source fires inside one round. Spawn cadence is read off the LIVE
## Timer, so a game that scales its spawn rate by difficulty_multiplier is measured at the tier
## this sweep forced rather than at its authored constant. "supply" returns INF: nothing in the
## game itself limits it, and the real limit is the partner's output, resolved at pair level.
func _events(g: String, spec: Variant, inst: Node, dur: float) -> float:
	if typeof(spec) != TYPE_DICTIONARY or (spec as Dictionary).is_empty():
		return NAN
	var d: Dictionary = spec
	match String(d.get("k", "")):
		"spawn":
			var t: Variant = inst.get(String(d.get("t", "spawn_timer")))
			if not (t is Timer):
				return NAN
			var w := float((t as Timer).wait_time)
			return NAN if w <= 0.0 else floor(dur / w)
		"interval":
			var iv := _num(g, {"c": d.get("c", "")})
			if is_nan(iv) or iv <= 0.0:
				return NAN
			return floor(dur / iv) + float(d.get("plus", 0))
		"fixed":
			if d.has("nn") and not _has_needle(g, String(d["nn"])):
				return NAN
			return float(d.get("n", 0))
		"supply":
			return INF
	return NAN

## Points one scoring action is worth. times multiplies (a unit that needs several taps pays
## per tap), bonus adds a completion award. Any unresolved piece poisons the whole number to
## NAN so the ceiling reports as unmeasured instead of wrong.
func _pts(g: String, e: Dictionary) -> float:
	var p: Dictionary = e["pts"]
	var base := NAN
	if p.has("c"):
		base = _num(g, p)
	else:
		var lit := _lit_in(g, String(p["f"]), String(p["n"]))
		base = NAN if lit < 0 else float(lit)
	if is_nan(base):
		return NAN
	if p.has("times"):
		var m := _num(g, p["times"])
		if is_nan(m):
			return NAN
		base *= m
	if e.has("bonus"):
		# A bonus is declared the same two ways points are: a named constant when the game has one,
		# or the integer parsed out of a call site when it does not. MP_FilterWater's completion
		# bonus became BONUS_PER_UNIT during this sweep, so the {"c": ...} form is the one in use;
		# the parse form stays because the sites that are still bare literals need it.
		var bon: Dictionary = e["bonus"]
		var badd := NAN
		if bon.has("c"):
			badd = _num(g, bon)
		else:
			var b := _lit_in(g, String(bon["f"]), String(bon["n"]))
			badd = NAN if b < 0 else float(b)
		if is_nan(badd):
			return NAN
		base += badd
	return base

## Boots one game the way a player reaches it - past the instruction overlay and into a live
## round - then reads its numbers off the running instance. Same boot as
## tools/VerifyTouchTargets.gd: with no partner, MultiplayerMiniGameBase would spend ~9s in its
## host fallback and countdown before _on_game_start() ran, so start_game() is called directly.
## It self-guards on game_active, so this is the same entry the countdown uses.
func _probe(e: Dictionary) -> Dictionary:
	var g := String(e["g"])
	var row: Dictionary = {"g": g, "ok": false}
	var path := "%s/%s.tscn" % [MP_SCENE_DIR, g]
	if not ResourceLoader.exists(path):
		_null("%s scene" % g, "%s missing" % path)
		return row
	var packed := load(path) as PackedScene
	if packed == null:
		_null("%s scene" % g, "would not load")
		return row
	var inst: Node = packed.instantiate()
	get_tree().root.add_child(inst)
	await _frames(SETTLE_FRAMES)
	if inst.has_method("_on_instruction_dismissed"):
		inst.call("_on_instruction_dismissed")
	if inst.has_method("start_game") and not bool(inst.get("game_active")):
		inst.call("start_game")
	await _frames(12)

	print("\n  %s (%s)" % [g, String(e["pair"])])
	var dur := float(inst.get("game_duration"))
	var quota := int(inst.get("win_quota"))
	_check(dur > 0.0 and dur < 999999.0, "%s round length is finite and positive" % g,
		"game_duration=%.1fs win_quota=%d" % [dur, quota])

	# FAILURE RULE REACHABILITY
	var has_fail := false
	var fail: Dictionary = e.get("fail", {})
	if fail.is_empty():
		print("    [INFO] %s advertises no failure rule" % g)
	else:
		var th := _num(g, {"c": fail.get("c", "")})
		if is_nan(th):
			_null("%s fail threshold" % g, "constant %s is gone" % String(fail.get("c", "?")))
		elif String(fail.get("k", "")) == "time":
			has_fail = th < dur
			_check(has_fail, "%s neglect allowance fits inside the round" % g,
				"%s=%.0fs vs %.0fs round (margin %.0fs)" % [String(fail["c"]), th, dur, dur - th])
		else:
			var after := 0.0
			if fail.has("after"):
				after = _num(g, fail["after"])
				if is_nan(after):
					after = 0.0
			var ev := _events(g, fail.get("per", {}), inst, max(0.0, dur - after))
			if is_nan(ev):
				_null("%s fail event rate" % g, "event source unresolved")
			else:
				has_fail = ev >= th
				_check(has_fail, "%s mess allowance is crossable inside the round" % g,
					"%s=%.0f vs %.0f events available%s" % [String(fail["c"]), th, ev,
						("" if after == 0.0 else " after %.0fs" % after)])
	row["has_fail"] = has_fail
	row["quota"] = quota
	row["dur"] = dur

	# THE PLAYER MUST BE ABLE TO ANSWER THE RULE THAT PUNISHES THEM
	#
	# Every consumer role can only act while it holds water its partner sent. A fail measure
	# that keeps accruing through a dry spell charges the team a life for the partner's pace,
	# which is the least fair thing a co-op round can do - and it is invisible in single play
	# because the harness-side partner never stops delivering.
	if bool(fail.get("gate", false)):
		var gf := String(fail.get("gate_f", ""))
		_check(_gate_in(g, gf), "%s stops charging lives while the player has no water" % g,
			"%s() consults available_water before report_miss_to_host()" % gf)

	# AN OUTCOME THE PLAYER DECIDES
	#
	# MultiplayerMiniGameBase ends a quota-less round with an unconditional end_game(true) on
	# time-up. A game with neither a quota nor a reachable failure rule therefore cannot be
	# lost and cannot be finished early: it plays itself, and CoopAdaptation reads success from
	# it no matter what happened, which poisons the tier it picks next.
	_check(quota > 0 or has_fail, "%s outcome is decided by play" % g,
		"win_quota=%d, reachable failure rule=%s" % [quota, str(has_fail)])

	# ROLE CEILING
	var pts := _pts(g, e)
	var acts := _events(g, e.get("acts", {}), inst, dur)
	var taps := 1.0
	if e.has("taps"):
		taps = _num(g, e["taps"])
		if is_nan(taps) or taps <= 0.0:
			taps = 1.0
	var tap_cap := MAX_APS * dur / taps
	if is_nan(pts) or is_nan(acts):
		_null("%s role ceiling" % g, "pts=%s acts=%s" % [str(pts), str(acts)])
	else:
		row["pts"] = pts
		row["acts_offered"] = acts
		row["tap_cap"] = tap_cap
		row["ceiling_solo"] = min(acts, tap_cap) * pts
		row["ok"] = true
		var lim := "offer" if acts <= tap_cap else "tap rate %.0f/round" % tap_cap
		print("    [INFO] %s pays %.0f x %s chances = %.0f pts reachable in %.0fs%s" % [g, pts,
			("unlimited (partner-fed)" if is_inf(acts) else "%.0f" % acts),
			row["ceiling_solo"], dur, "" if is_inf(acts) else " (limited by %s)" % lim])
	if e.has("sends_per"):
		row["sends_per"] = _num(g, e["sends_per"])
		row["sends"] = _num(g, e["sends"])
	if e.has("needs"):
		row["needs"] = _num(g, e["needs"])
	if e.has("own_quota"):
		row["own_quota"] = _num(g, e["own_quota"])

	# CAN THE CATCHER PHYSICALLY REACH THE DROP
	#
	# A collector role is only fair if the bucket can cross the field in less time than a drop
	# takes to fall: otherwise the far-side drop is unmissable-by-design and the miss counter
	# fills through no fault of the player. Measured against the analog/keyboard speed, which
	# is the slower of the two control paths (touch adds pointer easing on top of it).
	if e.has("catch"):
		var cat: Dictionary = e["catch"]
		var bs := _num(g, {"c": cat.get("speed", "")})
		var ds := _num(g, {"c": cat.get("fall", "")})
		var margin := _num(g, {"c": "SPAWN_MARGIN"})
		var bottom := _num(g, {"c": "BUCKET_MARGIN_BOTTOM"})
		var sz := get_viewport().get_visible_rect().size
		if is_nan(bs) or is_nan(ds) or is_nan(margin) or is_nan(bottom):
			_null("%s catcher reachability" % g, "speed/geometry constants unresolved")
		else:
			var width := sz.x - 2.0 * margin
			var fall := sz.y - bottom
			var t_cross := width / bs
			var t_fall := fall / ds
			_check(t_cross <= t_fall, "%s bucket can cross the field before a drop lands" % g,
				"%.0fu at %.0fu/s = %.2fs vs fall %.0fu at %.0fu/s = %.2fs" %
					[width, bs, t_cross, fall, ds, t_fall])

	inst.queue_free()
	await _frames(2)
	return row

## The reachable point total for one role, once the partner's output is known. A partner-fed
## consumer has no cadence of its own, so its ceiling is whatever the producer can deliver,
## capped by how fast a finger can spend it.
func _resolve_ceiling(row: Dictionary, supply_units: float) -> float:
	var acts: float = float(row.get("acts_offered", NAN))
	var pts: float = float(row.get("pts", NAN))
	if is_nan(pts):
		return NAN
	var by_supply := INF
	if not is_inf(supply_units):
		var needs: float = float(row.get("needs", 1.0))
		by_supply = supply_units / max(1.0, needs)
	var lim: float = min(min(acts, float(row.get("tap_cap", INF))), by_supply)
	return NAN if is_inf(lim) else lim * pts

## PAIR-LEVEL FAIRNESS
##
## The pair table is read live out of LevelSets rather than copied here, so a set added or
## re-ordered later is swept without editing this file - and a game that belongs to no set is
## reported instead of quietly going unaudited.
func _pairs(rows: Dictionary) -> void:
	print("\n  ── pairs, as the lobby actually hands them out ──")
	var seen: Dictionary = {}
	var sets: Array = LevelSets.LEVEL_SETS if LevelSets else []
	for s in sets:
		var a := String(s["player1_game"]).get_file().get_basename()
		var b := String(s["player2_game"]).get_file().get_basename()
		seen[a] = true
		seen[b] = true
		print("\n  %s  ↔  %s" % [a, b])
		if not rows.has(a) or not rows.has(b):
			_null("pair %s/%s" % [a, b], "one side was not probed")
			continue
		var ra: Dictionary = rows[a]
		var rb: Dictionary = rows[b]
		if not bool(ra.get("ok", false)) or not bool(rb.get("ok", false)):
			_null("pair %s/%s ceilings" % [a, b], "a role ceiling was unmeasured")
			continue
		_check(is_equal_approx(float(ra["dur"]), float(rb["dur"])),
			"both halves of %s/%s run the same clock" % [a, b],
			"%.0fs vs %.0fs" % [float(ra["dur"]), float(rb["dur"])])
		# Units the producer can hand over across the round.
		var supply := INF
		if ra.has("sends_per") and ra.has("sends"):
			var per: float = max(1.0, float(ra["sends_per"]))
			supply = min(float(ra["acts_offered"]), float(ra["tap_cap"])) * float(ra["sends"]) / per
		var ca := _resolve_ceiling(ra, INF)
		var cb := _resolve_ceiling(rb, supply)
		if is_nan(ca) or is_nan(cb):
			_null("pair %s/%s ceilings" % [a, b], "ca=%s cb=%s" % [str(ca), str(cb)])
			continue
		var ratio: float = max(ca, cb) / max(1.0, min(ca, cb))
		_check(ratio <= MAX_ROLE_RATIO, "%s/%s roles can score within %.1fx of each other"
			% [a, b, MAX_ROLE_RATIO],
			"%s %.0f pts vs %s %.0f pts = %.2fx" % [a, ca, b, cb, ratio])
		# Enough water for the consumer to finish its own advertised quota.
		if rb.has("own_quota") and not is_inf(supply):
			var need: float = float(rb["own_quota"]) * float(rb.get("needs", 1.0))
			var margin: float = supply / max(1.0, need)
			_check(margin > MIN_SUPPLY_MARGIN, "%s can supply %s past its exact quota" % [a, b],
				"%.0f units sent vs %.0f needed = %.2fx" % [supply, need, margin])
	for g in rows:
		_check(seen.has(g), "%s is reachable from the lobby" % g,
			"appears in LevelSets.LEVEL_SETS" if seen.has(g) else "in no level set — unplayable")

## Every MP scene on disk must appear in MODEL. A sweep that silently skips a game it does not
## know about is worse than no sweep, because the summary still reads green.
func _census() -> void:
	var on_disk: Array = []
	var d := DirAccess.open(MP_SCENE_DIR)
	if d:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.ends_with(".tscn") and f.begins_with("MP_"):
				on_disk.append(f.get_basename())
			f = d.get_next()
		d.list_dir_end()
	on_disk.sort()
	var modelled: Array = []
	for e in MODEL:
		modelled.append(String(e["g"]))
	modelled.sort()
	_check(on_disk == modelled, "every MP scene on disk is in this sweep's model",
		"%d on disk, %d modelled" % [on_disk.size(), modelled.size()])
	if on_disk != modelled:
		for g in on_disk:
			if not modelled.has(g):
				print("      unmodelled: %s" % g)

## A miss already costs the team one of three shared lives. Taking clock seconds as well would
## charge one mistake twice, and the SP clock penalty is tuned for a solo timer, not a co-op
## life pool - so the base's miss path must stay off it.
func _no_double_charge() -> void:
	var f := FileAccess.open("res://scripts/multiplayer/MultiplayerMiniGameBase.gd", FileAccess.READ)
	if f == null:
		_null("mistake is charged once", "base script unreadable")
		return
	var lines := f.get_as_text().split("\n")
	f.close()
	var inside := false
	var doubled := false
	for line in lines:
		if line.begins_with("func "):
			if inside:
				break
			inside = line.begins_with("func report_miss_to_host(")
			continue
		if inside and line.strip_edges().begins_with("_apply_time_penalty("):
			doubled = true
	_check(not doubled, "a co-op mistake is charged once",
		"report_miss_to_host() takes a life and not clock seconds as well")

func _ready() -> void:
	await get_tree().process_frame
	print("\n=== MP FAIRNESS SWEEP — 12 co-op games, one pass ===")
	print("  bounds: role ratio <= %.1fx, tap rate <= %.1f/s, supply margin > %.2fx" %
		[MAX_ROLE_RATIO, MAX_APS, MIN_SUPPLY_MARGIN])
	if AdaptiveDifficulty:
		# Hard is the tier where spawn rates are scaled up and allowances bite hardest, and it
		# is the tier a competent pair reaches - so it is the one worth being fair at.
		AdaptiveDifficulty.current_difficulty = "Hard"
		AdaptiveDifficulty.progressive_level = 0
	# CoopAdaptation IS THE MP TIER, NOT AdaptiveDifficulty
	#
	# This block used to set AdaptiveDifficulty alone and print "difficulty tier forced: Hard",
	# while every game underneath it logged "CoopAdaptation difficulty loaded: Medium" — the sweep
	# was announcing a tier none of the games were running at. MultiplayerMiniGameBase reads its
	# per-round settings from CoopAdaptation.get_player_difficulty(); AdaptiveDifficulty is the
	# single-player path. Both are set now, and both are printed, so the header cannot claim a tier
	# the games are not at.
	if CoopAdaptation:
		CoopAdaptation.player1_difficulty = "Hard"
		CoopAdaptation.player2_difficulty = "Hard"
	print("  difficulty tier forced: coop P1=%s P2=%s / solo %s (multiplier %.2f)" % [
		CoopAdaptation.player1_difficulty if CoopAdaptation else "<none>",
		CoopAdaptation.player2_difficulty if CoopAdaptation else "<none>",
		AdaptiveDifficulty.current_difficulty if AdaptiveDifficulty else "<none>",
		GameManager.difficulty_multiplier if GameManager else 1.0])

	_census()
	_no_double_charge()

	# The mistake budget the whole pair shares, printed so the reachability numbers above have a
	# scale: three of anything below ends the round.
	print("  shared life pool: %d (NetworkManager.START_TEAM_LIVES)" %
		(NetworkManager.START_TEAM_LIVES if NetworkManager else -1))

	var hosted: bool = GameManager != null and bool(GameManager.host_game(MP_PORT))
	_check(hosted and NetworkManager != null and bool(NetworkManager.connection_active),
		"a lone-host session is open, which is all MultiplayerMiniGameBase gates on",
		"connection_active=%s" % str(NetworkManager.connection_active if NetworkManager else "<none>"))
	await _frames(6)

	var rows: Dictionary = {}
	for e in MODEL:
		var row: Dictionary = await _probe(e)
		rows[String(e["g"])] = row

	_pairs(rows)

	print("\n=== %d passed / %d failed / %d unmeasured ===" % [passed, failed, unmeasured])
	if failed == 0 and unmeasured == 0:
		print("=== MP FAIRNESS: GREEN ===")
	await get_tree().process_frame
	get_tree().quit()
