extends Node

## Asserts that every game on the singleplayer roster has authored, bilingual,
## non-duplicated end-of-round copy.
##
## Four surfaces read MiniGameBase._get_narratives(): the intro screen's
## atmospheric line, the round score page's flavour line (via
## _get_result_line_for_key(), which prefers the narrative over the short
## result_line_* twins), and the two micro-cutscene lines. Nothing tied that
## table to the roster or to Localization, which hid three separate defects:
##
##   * CloudCatcher was on the roster and in NONE of the copy tables, so its
##     score page fell through to the generic default -- 1 of 24, unreported.
##   * The table is hardcoded English and was read directly, so all four
##     surfaces were English in the Filipino build, AND the narrative shadowed
##     every result_line_* key, so localizing those alone changed nothing.
##   * WaterPlant carried a verbatim copy of WringItOut's laundry text (wrong
##     game), and PlugTheLeak carried a verbatim copy of FixLeak's.
##
## The tl assertions matter because _loc() falls back to its English argument: a
## key merely missing from the table still LOOKS correct on screen. "tl differs
## from en" is the only check that can see an untranslated line. The en
## assertions are the drift guard for the deliberate duplication -- the English
## lives in both the table (as fallback) and Localization (as the live value).

const FIELDS := ["intro", "win", "fail"]

var passed := 0
var failed := 0

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("  %s %s" % ["✓" if ok else "✗", label])

func _ready() -> void:
	print("\n=== ROUND-SCORE / NARRATIVE COPY COVERAGE ===\n")
	var base: Object = load("res://scripts/MiniGameBase.gd").new()
	var narratives: Dictionary = base._get_narratives()
	var roster: Array = GameManager.ALL_SINGLEPLAYER_MINIGAMES

	Localization.set_language(Localization.Language.ENGLISH)
	var def_win: String = base._loc("result_line_success_default", "")
	var def_fail: String = base._loc("result_line_fail_default", "")

	# ── 1. every roster game is covered, in both languages ──────────────
	print("[1] Roster coverage (%d games)" % roster.size())
	var missing := []
	var untranslated := []
	var drifted := []
	var defaulted := []
	for key in roster:
		if not narratives.has(key):
			missing.append("%s:narratives" % key)
			continue
		for f in FIELDS:
			var literal: String = str(narratives[key].get(f, ""))
			if literal.strip_edges().is_empty():
				missing.append("%s.%s" % [key, f])
				continue
			var lkey := "narrative_%s_%s" % [String(key).to_snake_case(), f]
			if not Localization.has_text(lkey):
				missing.append(lkey)
				continue
			Localization.set_language(Localization.Language.ENGLISH)
			var en: String = Localization.get_text(lkey)
			Localization.set_language(Localization.Language.FILIPINO)
			var tl: String = Localization.get_text(lkey)
			Localization.set_language(Localization.Language.ENGLISH)
			if en != literal:
				drifted.append(lkey)
			if tl == en:
				untranslated.append(lkey)
	_check(missing.is_empty(), "every game has intro/win/fail, defined in Localization%s"
		% ("" if missing.is_empty() else "  MISSING: " + ", ".join(missing)))
	_check(drifted.is_empty(), "Localization en matches the _get_narratives() literal%s"
		% ("" if drifted.is_empty() else "  DRIFTED: " + ", ".join(drifted)))
	_check(untranslated.is_empty(), "every line has a distinct Filipino string%s"
		% ("" if untranslated.is_empty() else "  UNTRANSLATED: " + ", ".join(untranslated)))

	# ── 2. the score page never falls through to the generic default ────
	print("\n[2] Score page flavour line is game-specific")
	for key in roster:
		Localization.set_language(Localization.Language.ENGLISH)
		if base._get_result_line_for_key(true, key) == def_win:
			defaulted.append("%s:win" % key)
		if base._get_result_line_for_key(false, key) == def_fail:
			defaulted.append("%s:fail" % key)
	_check(defaulted.is_empty(), "no game falls through to result_line_*_default%s"
		% ("" if defaulted.is_empty() else "  DEFAULTED: " + ", ".join(defaulted)))

	# ── 3. the score page follows the language switch ───────────────────
	print("\n[3] Score page follows the language switch")
	var same := []
	for key in roster:
		Localization.set_language(Localization.Language.ENGLISH)
		var w_en: String = base._get_result_line_for_key(true, key)
		var f_en: String = base._get_result_line_for_key(false, key)
		Localization.set_language(Localization.Language.FILIPINO)
		if base._get_result_line_for_key(true, key) == w_en:
			same.append("%s:win" % key)
		if base._get_result_line_for_key(false, key) == f_en:
			same.append("%s:fail" % key)
	Localization.set_language(Localization.Language.ENGLISH)
	_check(same.is_empty(), "flavour line changes with the language%s"
		% ("" if same.is_empty() else "  STUCK: " + ", ".join(same)))

	# ── 4. no two games share copy ──────────────────────────────────────
	print("\n[4] No two games share the same copy")
	var seen := {}
	var dupes := []
	for key in roster:
		if not narratives.has(key):
			continue
		for f in FIELDS:
			var s: String = str(narratives[key].get(f, ""))
			if s.is_empty():
				continue
			var sig := "%s|%s" % [f, s]
			if seen.has(sig):
				dupes.append("%s.%s == %s.%s" % [key, f, seen[sig], f])
			else:
				seen[sig] = key
	_check(dupes.is_empty(), "every game's copy is its own%s"
		% ("" if dupes.is_empty() else "  DUPLICATE: " + ", ".join(dupes)))

	base.free()
	print("\n=== RESULT: %d passed, %d failed ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
