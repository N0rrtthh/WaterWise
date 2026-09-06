extends Node

## ═══════════════════════════════════════════════════════════════════
## LOCALIZATION VERIFICATION HARNESS (headless, thesis-auditable)
## ═══════════════════════════════════════════════════════════════════
## The thesis requires English + Filipino via an in-memory hash-map lookup with
## real-time switching and no runtime file I/O. Nothing verified that, and the
## project's own logs could not: of the three _loc() helpers in the codebase, two
## guard with has_text() before calling get_text(), so a key that exists in no
## language silently renders the English fallback and never warns. 40 keys were
## in exactly that state — the Filipino build showed English on every minigame
## intro line, every failure reaction line and both roadmap tabs, with a clean log.
##
## This harness reads the actual source files to find every _loc("key", ...) call
## site, so it fails when someone adds a call site without a table entry, which is
## how the defect happened in the first place.
##
## Verifies:
##   1. Every _loc()/get_text() key referenced in source exists in the table
##   2. Every table entry defines both "en" and "tl", both non-empty
##   3. Real-time language switching returns different strings, no file I/O
##   4. get_text() on an unknown key degrades to the key (no crash, no empty UI)
##   5. Format-specifier parity: en and tl take the same printf arguments
##   6. The table is a pure in-memory dictionary (O(1) lookup, no per-call load)
##   7. No UI label is assigned an English literal instead of a table lookup
##   8. Every runtime-composed key (narrative_*, mp_role_*, cutscene_line_*) exists
##   9. Every key stored in a data table ({"key": "..."}) exists
##
## Run:
##   Godot --headless --path <project> res://tools/VerifyLocalization.tscn
## Exit code 0 = all passed, 1 = at least one failure.
## ═══════════════════════════════════════════════════════════════════

## Directories scanned for _loc() call sites.
##
## test/ is .gdignore'd and tools/ is harness code, so neither ships in a build
## and neither is required to be localized.
const SCAN_DIRS: Array[String] = [
	"res://scenes", "res://scripts", "res://autoload",
]

## Keys whose Filipino text is deliberately identical to the English.
##
## An en == tl pair is normally a translation that was never done — 20 of them were
## exactly that, and were translated rather than listed here. The list below holds the
## reviewed exceptions, in three categories (the count in the pass line is the list size):
##
##   Proper nouns          the game's own names, which do not translate:
##                         title (WATERVILLE), the 8 character_name_*, the 4
##                         minigame_* titles, accessory_default/party_cap.
##   Established loanwords terms Filipino players use in English, and which this
##                         table already treated that way before this harness
##                         existed: multiplayer, host, join, settings, round,
##                         leaderboard, highscore, the roadmap tabs, dev-mode header.
##                         "filipino" and "language" are endonyms/already bilingual.
##   Format-only strings   no translatable words at all, just specifiers and
##                         punctuation: "%d / %d", "%s: %.0f%%", the *_row and
##                         mini_results_*/posttest_* lines, the two emoji-only
##                         narrative character keys.
##
## Anything NOT on this list that has identical text fails the check, so a newly
## added untranslated string cannot slip in as an invisible note.
const INTENTIONAL_IDENTICAL: Array[String] = [
	# Proper nouns
	"title", "character_name_droppy_blue", "character_name_pinky",
	"character_name_minty", "character_name_sunny", "character_name_lavvy",
	"character_name_peachy", "character_name_cyanny", "character_name_coral",
	"minigame_pipe_puzzle", "minigame_water_quiz", "minigame_bucket_relay",
	"minigame_fun_games", "accessory_default", "accessory_party_cap",
	# Established loanwords / endonyms
	"multiplayer", "multiplayer_lobby", "host", "join", "settings", "round",
	"initial_highscore_sign", "leaderboard_title", "language", "filipino",
	"settings_dev_mode_header", "roadmap_tab_singleplayer", "roadmap_tab_multiplayer",
	# Established loanwords: the five below joined the list with Batch 3's sweep.
	# "Auto-Play" is the feature's name in this project's own UI and stays English in
	# the Filipino build the way "multiplayer" already does; "aquarium" and "combo" are
	# the words Filipino players use, and both labels are mostly specifier anyway.
	"menu_auto_play_toggle", "settings_auto_play_mp", "mp_auto_play",
	"mp_aquarium_label", "hud_combo",
	# Established loanwords: the four below joined the list with Batch 3's data-table pass.
	# "Player 1"/"Player 2" are what this screen's own translations dict already calls the
	# two seats in Filipino ("Player 1 (Mang-ipon)"), "Round %d" follows the "round" entry
	# five lines up, and "Hood" is the word for that car panel in both languages — the
	# descriptive gloss ("Takip ng Makina") does not fit the 150-unit panel.
	"mp_lb_col_p1", "mp_lb_col_p2", "mp_lb_round_num", "mp_car_hood",
	# Established loanwords: the Multiplayer page's round-timer caption is the "round"
	# entry above with a colon on it - this project's Filipino has used the loanword
	# throughout ("Kanselado ang round"), and "bilog" is the shape. Its VALUE label
	# (mp_round_timer_default) is translated rather than listed, since "default" is not
	# one of the words this table treats that way.
	"mp_round_timer",
	# Format-only strings
	"leaderboard_score_row", "finalscore_round_row", "finalscore_top_score_row",
	"story_page_indicator", "mini_results_accuracy_line", "mini_results_time_line",
	"mini_results_mistakes_line", "mini_results_difficulty_line",
	"mini_results_accuracy_caps", "mini_results_mistakes_caps",
	"posttest_gameplay_performance_line", "posttest_knowledge_score_line",
	"posttest_correlation_line", "posttest_alignment_line",
	"narrative_trace_pipe_path_lose_character", "narrative_cover_the_drum_win_character",
]


## Files exempt from the hardcoded-label check of criterion 7, with the reason each
## one is exempt.
##
## Exempt means "this text never reaches a player", never "translating it was too
## much work". Every entry is either gated behind the dev_mode setting or is a
## script no shipping scene loads — both verifiable from the project, not asserted
## here: the dev screens are reached only from Settings' dev block, and the three
## scenes/minigames scripts are dead because their own .tscn files point at
## scripts/minigames_v2/*V2.gd instead.
const LABEL_SCAN_SKIP: Array[String] = [
	# Dev-mode screens: unreachable unless SaveManager's "dev_mode" setting is on.
	"res://scenes/ui/DevStats.gd",
	# PerformanceProfiler.gd:448 - set_overlay_visible(dev_mode_enabled and
	# should_show_profiler), so the ISO/IEC 25010 readout is a dev instrument, not copy.
	"res://autoload/PerformanceProfiler.gd",
	"res://autoload/AlgorithmOverlay.gd",
	"res://scenes/ui/BeatViewer.gd",
	# Same gate as BeatViewer above, and the same evidence: Settings.gd:863 sets the
	# Game Lab button disabled = not dev_mode_enabled and _apply_dev_mode_visibility()
	# re-applies that at :1028, so the screen cannot be opened without dev mode - the
	# button's own caption lives in Settings.gd, which this scan does NOT exempt and
	# did not flag: it goes through _loc("settings_game_lab", ...). The screen behind
	# it is a sandbox that records nothing - no droplets, no lives, no session log -
	# and its labels say so in developer English on purpose.
	"res://scenes/ui/GameLab.gd",
	"res://scenes/ui/DebugMultiplayer.gd",
	"res://scripts/cutscenes/AnimatedCutscenePlayerDemo.gd",
	# Legacy prototype co-op family: reachable only through DebugMultiplayer.gd, and
	# superseded by the 12 MP_* games MultiplayerLobby actually loads.
	"res://scripts/multiplayer/MiniGame_BucketBrigade.gd",
	"res://scripts/multiplayer/MiniGame_GreywaterSort.gd",
	"res://scripts/multiplayer/MiniGame_LeafSort.gd",
	"res://scripts/multiplayer/MiniGame_Rain.gd",
	"res://scripts/multiplayer/MiniGame_WaterHarvest.gd",
	# Dead single-player scripts: the matching .tscn loads a minigames_v2 script.
	"res://scenes/minigames/FixLeak.gd",
	"res://scenes/minigames/BucketBrigade.gd",
	"res://scenes/minigames/GreywaterSorter.gd",
]

## Literals that set a glyph or a developer overlay string, not a translatable label.
const LABEL_SCAN_ALLOWED: Array[String] = [
	"II",  # the pause glyph on the in-game pause button
	"Safe Area Debug (Red=Top, Green=Bottom, Blue=Left, Yellow=Right)",
]

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []
var _stale_rows: int = 0
var _mp_reaches_base: bool = false
var _rwh_reaches_base: bool = false


func _ready() -> void:
	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  WATERWISE LOCALIZATION VERIFICATION")
	print("═══════════════════════════════════════════════════════════")

	_verify_all_referenced_keys_exist()
	_verify_every_key_has_both_languages()
	_verify_runtime_switching()
	_verify_unknown_key_degrades()
	_verify_format_specifier_parity()
	_verify_lookup_is_in_memory()
	_verify_no_hardcoded_labels()
	_verify_composed_keys_defined()
	_verify_data_field_keys_defined()

	print("")
	print("═══════════════════════════════════════════════════════════")
	print("  RESULT: %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		for f in _failures:
			print("    ✗ %s" % f)
	print("═══════════════════════════════════════════════════════════")
	print("")

	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ✓ %s" % label)
	else:
		_failed += 1
		var msg := label if detail == "" else "%s — %s" % [label, detail]
		_failures.append(msg)
		print("  ✗ %s  %s" % [label, detail])


## Collect every `_loc("key"` / `get_text("key"` literal under SCAN_DIRS.
##
## Source-scanning rather than trusting a hand-maintained list: the failure this
## guards against is a call site added without a table entry, which a hand list
## would miss by construction.
##
## Scans the whole file, NOT line by line. The line-by-line version this replaces
## could only see a call whose key literal sat on the same physical line as the
## `_loc(`, and this file wraps the long ones:
##
##     return _loc(
##         "result_line_success_turn_off_tap",
##         "Tap shut off right on cue!"
##     )
##
## 79 of the project's 251 call sites are wrapped that way, so the old scan
## reported "all 172 referenced keys defined" while 34 keys were in fact missing
## from the table -- every win line on the round score page among them. The
## fallback argument keeps those rendering in English, which is why nothing ever
## looked broken.
func _collect_referenced_keys() -> Dictionary:
	var keys := {}  # key -> first "file:line" seen, for the failure message
	var pattern := RegEx.create_from_string(
		'(?:_loc|get_text|translate)[(][[:space:]]*"([a-z0-9_]+)"')
	for dir_path in SCAN_DIRS:
		for file_path in _list_gd_files(dir_path):
			var text := FileAccess.get_file_as_string(file_path)
			if text.is_empty():
				continue
			for m in pattern.search_all(text):
				var key := m.get_string(1)
				if keys.has(key):
					continue
				# Line number from the match offset: count newlines before it.
				var line_no := text.substr(0, m.get_start()).count("\n") + 1
				keys[key] = "%s:%d" % [file_path, line_no]
	return keys


func _list_gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_list_gd_files(full))
		elif name.ends_with(".gd"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out


# ── 1. Every referenced key exists ──────────────────────────────────

func _verify_all_referenced_keys_exist() -> void:
	print("\n[1] Referenced keys exist in the table")
	var referenced := _collect_referenced_keys()
	var missing: Array[String] = []
	for key in referenced:
		if not Localization.has_text(key):
			missing.append("%s (%s)" % [key, referenced[key]])
	_check(
		"all %d referenced keys defined" % referenced.size(),
		missing.is_empty(),
		"missing: %s" % ", ".join(missing.slice(0, 8)) if not missing.is_empty() else ""
	)
	# A table with far more entries than call sites is not an error, but a table
	# with FEWER referenced-and-found keys than expected means the scan regressed
	# and the check above passed vacuously.
	_check(
		"source scan found call sites",
		referenced.size() >= 100,
		"only %d keys found — scan likely broken" % referenced.size()
	)


# ── 2. Both languages present and non-empty ─────────────────────────

func _verify_every_key_has_both_languages() -> void:
	print("\n[2] Every entry defines non-empty en and tl")
	var incomplete: Array[String] = []
	var identical: Array[String] = []
	for key in Localization.translations:
		var entry = Localization.translations[key]
		if typeof(entry) != TYPE_DICTIONARY:
			incomplete.append("%s (not a dictionary)" % key)
			continue
		var en := str(entry.get("en", ""))
		var tl := str(entry.get("tl", ""))
		if en.strip_edges().is_empty() or tl.strip_edges().is_empty():
			incomplete.append(key)
		elif en == tl and not INTENTIONAL_IDENTICAL.has(key):
			identical.append(key)
	_check(
		"%d entries have both languages" % Localization.translations.size(),
		incomplete.is_empty(),
		"incomplete: %s" % ", ".join(incomplete.slice(0, 8))
	)
	# Fails rather than warns: an identical pair that nobody signed off on is an
	# untranslated string, and the Filipino build shows it in English with no error.
	_check(
		"no unreviewed en == tl pairs (%d reviewed exceptions)" % INTENTIONAL_IDENTICAL.size(),
		identical.is_empty(),
		"untranslated: %s" % ", ".join(identical.slice(0, 10))
	)
	# The reviewed list must stay honest too: an entry that later gets a real
	# translation should be taken off it, or the list quietly grants amnesty to a
	# key it no longer describes.
	var stale: Array[String] = []
	for key in INTENTIONAL_IDENTICAL:
		if not Localization.translations.has(key):
			stale.append("%s (no such key)" % key)
			continue
		var e = Localization.translations[key]
		if typeof(e) == TYPE_DICTIONARY and str(e.get("en", "")) != str(e.get("tl", "")):
			stale.append("%s (now translated)" % key)
	_check(
		"reviewed-exception list has no stale entries",
		stale.is_empty(),
		"stale: %s" % ", ".join(stale.slice(0, 8))
	)


# ── 3. Real-time switching ──────────────────────────────────────────

func _verify_runtime_switching() -> void:
	print("\n[3] Real-time switching, both directions")
	var original: int = Localization.current_language

	# "how_to_play" is a stable UI string present since the first table revision.
	Localization.set_language(Localization.Language.ENGLISH)
	var en_text := Localization.get_text("how_to_play")
	Localization.set_language(Localization.Language.FILIPINO)
	var tl_text := Localization.get_text("how_to_play")
	Localization.set_language(Localization.Language.ENGLISH)
	var en_again := Localization.get_text("how_to_play")

	_check("English lookup returns text", not en_text.is_empty() and en_text != "how_to_play")
	_check("Filipino lookup returns text", not tl_text.is_empty() and tl_text != "how_to_play")
	_check("the two languages differ", en_text != tl_text, "both were '%s'" % en_text)
	_check("switching back is lossless", en_again == en_text, "'%s' vs '%s'" % [en_again, en_text])
	_check("is_english/is_filipino agree with state", Localization.is_english())

	# Every key must resolve in BOTH languages, not just the active one — the
	# original defect only manifested in Filipino.
	var unresolved_tl: Array[String] = []
	Localization.set_language(Localization.Language.FILIPINO)
	for key in Localization.translations:
		if Localization.get_text(key) == key:
			unresolved_tl.append(key)
	_check(
		"all keys resolve in Filipino",
		unresolved_tl.is_empty(),
		"unresolved: %s" % ", ".join(unresolved_tl.slice(0, 8))
	)

	Localization.set_language(original)


# ── 4. Unknown key degrades safely ──────────────────────────────────

func _verify_unknown_key_degrades() -> void:
	print("\n[4] Unknown key degrades without crashing")
	# get_text() is documented to warn and echo the key back. An empty string here
	# would mean a blank label on a phone screen with no clue why.
	var result := Localization.get_text("waterwise_key_that_does_not_exist")
	_check("unknown key echoes the key", result == "waterwise_key_that_does_not_exist", result)
	_check("has_text() reports false", not Localization.has_text("waterwise_key_that_does_not_exist"))


# ── 5. Format-specifier parity ──────────────────────────────────────

func _verify_format_specifier_parity() -> void:
	print("\n[5] en and tl take the same printf arguments")
	# A tl string that drops or reorders a %d relative to its en counterpart throws
	# at runtime the moment the Filipino build reaches that screen. Several entries
	# are format strings ("finalscore_round_row" takes %d %s %d %d), so this is the
	# one localization bug class that CRASHES rather than degrades.
	var mismatched: Array[String] = []
	var spec := RegEx.create_from_string("%[0-9.\\-+ #]*[difsxXeEgGco%]")
	for key in Localization.translations:
		var entry = Localization.translations[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var en_specs := _specs_of(spec, str(entry.get("en", "")))
		var tl_specs := _specs_of(spec, str(entry.get("tl", "")))
		if en_specs != tl_specs:
			mismatched.append("%s (en=%s tl=%s)" % [key, en_specs, tl_specs])
	_check(
		"format specifiers match in every entry",
		mismatched.is_empty(),
		"mismatched: %s" % ", ".join(mismatched.slice(0, 6))
	)


func _specs_of(spec: RegEx, text: String) -> Array[String]:
	var out: Array[String] = []
	for m in spec.search_all(text):
		var s := m.get_string()
		if s != "%%":  # literal percent, not an argument
			out.append(s)
	return out


# ── 6. In-memory lookup ─────────────────────────────────────────────

func _verify_lookup_is_in_memory() -> void:
	print("\n[6] Lookup is an in-memory hash map (no runtime I/O)")
	_check(
		"translations is a Dictionary",
		typeof(Localization.translations) == TYPE_DICTIONARY,
		"got type %d" % typeof(Localization.translations)
	)

	# The thesis claims O(1) hash-map lookup with no per-call file access. Timing
	# proves the second half: any file open per get_text() would put this several
	# orders of magnitude higher than a dictionary probe.
	var keys := Localization.translations.keys()
	var iterations := 20000
	var start := Time.get_ticks_usec()
	for i in range(iterations):
		Localization.get_text(keys[i % keys.size()])
	var usec_per_call := float(Time.get_ticks_usec() - start) / float(iterations)
	print("      %d lookups, %.3f µs/call" % [iterations, usec_per_call])
	_check(
		"lookup cost is dictionary-order (< 10 µs/call)",
		usec_per_call < 10.0,
		"%.3f µs/call suggests per-call I/O" % usec_per_call
	)


# ── 7. No hardcoded player-facing label literal ─────────────────────

## Fails when a UI label is assigned an English literal instead of a table lookup.
##
## Criteria 1-6 all assume the string reached the player through the table. Nothing
## checked the other direction, and 128 sites assigned the literal straight to
## Label.text: the Filipino build showed English on every minigame HUD counter, the
## pause sheet, the round-summary page, both menu screens, the co-op resource meters
## and the cutscene stingers, while all six existing criteria passed -- those strings
## never touched the table, so there was nothing for the other checks to look at.
##
## A literal counts as player-facing when anything alphabetic survives the removal of
## printf specifiers and escapes, which is what separates a label from a formatter:
## "%d / %d", "💧 x %d" and "%02d:%02d" carry no words and are left alone, "Undo Last"
## and "Waiting for host to start..." do not.
##
## The scan reads the assignment form the defect took (`label.text = "..."`) and cannot
## be fooled by a fallback argument -- in `_loc("k", "Undo Last")` the literal does
## not follow the `=`. Comment lines are skipped so commented-out code does not fail the build.
##
## One physical line is not enough, though, and that blind spot cost real copy: a
## parenthesised assignment puts the literal on the NEXT line, and
## RainwaterHarvesting._show_role_instructions() hid two English task briefs behind
## `task_label.text = (` for as long as this check has existed while reporting green. So an
## assignment ending in a bare `(` is joined to the next line that carries code before being
## matched, and the hit is attributed to the line the literal is actually on.
func _verify_no_hardcoded_labels() -> void:
	print("\n[7] No UI label carries an English literal")
	var setter := RegEx.create_from_string(
		'(?:[.]text|[.]tooltip_text|[.]placeholder_text)[[:space:]]*=[[:space:]]*[(]?[[:space:]]*"([^"]*)"')
	var caller := RegEx.create_from_string('(?:set_text|add_item)[(][[:space:]]*"([^"]*)"')
	var spec := RegEx.create_from_string("%[#0-9.+ -]*[a-zA-Z%]")
	var word := RegEx.create_from_string("[A-Za-z]{2,}")
	# `label.text = (` with nothing after it: the literal is on a following line.
	var opener := RegEx.create_from_string(
		'(?:[.]text|[.]tooltip_text|[.]placeholder_text)[[:space:]]*=[[:space:]]*[(][[:space:]]*$')
	
	var hits: Array[String] = []
	var scanned := 0
	var exempt_hits := 0
	for dir_path in SCAN_DIRS:
		for file_path in _list_gd_files(dir_path):
			var is_exempt: bool = LABEL_SCAN_SKIP.has(file_path)
			var text := FileAccess.get_file_as_string(file_path)
			if text.is_empty():
				continue
			var lines := text.split("\n")
			for i in range(lines.size()):
				var line: String = lines[i]
				if line.strip_edges().begins_with("#"):
					continue
				var line_no := i + 1
				if opener.search(line) != null:
					var j := i + 1
					while j < lines.size() and _is_blank_or_comment(lines[j]):
						j += 1
					if j < lines.size():
						line = line.strip_edges() + " " + lines[j].strip_edges()
						line_no = j + 1
				for re in [setter, caller]:
					var m: RegExMatch = re.search(line)
					if m == null:
						continue
					scanned += 1
					var lit := m.get_string(1)
					if LABEL_SCAN_ALLOWED.has(lit):
						continue
					# Strip what a formatter is made of; whatever is left is copy.
					var bare := spec.sub(lit, "", true)
					bare = bare.replace("\n", " ").replace("\t", " ")
					if word.search(bare) == null:
						continue
					if is_exempt:
						exempt_hits += 1
					else:
						hits.append("%s:%d  \"%s\"" % [file_path, line_no, lit])
	
	_check(
		"no hardcoded player-facing label literal (%d label assignments scanned)" % scanned,
		hits.is_empty(),
		"%d still hardcoded" % hits.size())
	for i in range(min(hits.size(), 12)):
		print("      → %s" % hits[i])
	if hits.size() > 12:
		print("      → ... and %d more" % (hits.size() - 12))
	
	# A detector that flags nothing proves nothing. The exempt files are known
	# positives -- 105 English literals across the dev screens and the legacy co-op
	# family -- so if the pass above went green with zero hits there too, the regex
	# stopped matching and the green is meaningless.
	_check(
		"hardcoded-label detector still fires — %d literals found in the exempt files" % exempt_hits,
		exempt_hits > 0,
		"detector matched nothing anywhere; criterion 7 is vacuous")

## A line the join in criterion 7 steps over rather than treating as the literal.
func _is_blank_or_comment(line: String) -> bool:
	var s := line.strip_edges()
	return s.is_empty() or s.begins_with("#")

# ── 8. Composed keys: the family a literal scan cannot see ──────────

## Criterion 1 scans source for `_loc("literal"`, so it is blind to a key that is
## built at runtime. Three call sites build theirs from a data table:
##
##   MiniGameBase._narrative()                "narrative_%s_%s" % [key.to_snake_case(), field]
##   CharacterOutcomeNarrative                "narrative_%s_%s_%s" % [slug, outcome, field]
##   MultiplayerMiniGameBase._role_display()  "mp_role_%s" % role_id.to_snake_case()
##
## All three fall back to the authored English when the key is absent, so a missing
## entry there renders English in the Filipino build with a clean log and a green
## criterion 1 — the exact failure mode this harness exists for. This check walks
## the SOURCE tables those keys are derived from and demands an entry per row.
##
## Glyph-only values are skipped: a value with no letters (the emoji "character"
## field) reads the same in both languages, and forcing 72 en == tl entries into
## the table would only grow the reviewed-exception list without changing a pixel.
func _verify_composed_keys_defined() -> void:
	print("\n[8] Composed (runtime-built) keys exist in the table")
	var word := RegEx.create_from_string("[A-Za-z]{2,}")
	var spec := RegEx.create_from_string("%[#0-9.+ -]*[a-zA-Z%]")
	_stale_rows = 0
	_mp_reaches_base = _extends_minigame_base(
		"res://scripts/multiplayer/MultiplayerMiniGameBase.gd")
	_rwh_reaches_base = _extends_minigame_base(
		"res://scenes/minigames/RainwaterHarvesting.gd")

	var expected := {}  # key -> "source:line" for the failure message
	_collect_flat_narrative_keys(expected, word, spec)
	_collect_outcome_narrative_keys(expected, word, spec)
	_collect_role_keys(expected)
	_collect_mp_react_keys(expected)
	_collect_cutscene_line_keys(expected, word, spec)
	_collect_character_name_keys(expected)

	var missing: Array[String] = []
	for key in expected:
		if not Localization.has_text(key):
			missing.append("%s (%s)" % [key, expected[key]])
	_check(
		"all %d composed keys defined" % expected.size(),
		missing.is_empty(),
		"%d missing" % missing.size())
	for i in range(min(missing.size(), 14)):
		print("      → %s" % missing[i])
	if missing.size() > 14:
		print("      → ... and %d more" % (missing.size() - 14))
	if _stale_rows > 0:
		print("      i %d table rows skipped as unreachable (see _narrative_row_is_reachable)"
			% _stale_rows)

	# The six parsers are regex over source layout. If a table is reformatted the
	# scan silently returns nothing and the check above passes vacuously, so assert
	# the floor the six families are known to contain.
	_check(
		"composed-key scan found all six families (%d keys)" % expected.size(),
		expected.size() >= 200,
		"only %d keys derived — a source parser stopped matching" % expected.size())

## MiniGameBase._get_narratives(): "Game": { "intro": "...", "win": "...", "fail": "..." }
## keyed as narrative_<snake>_<field>.
func _collect_flat_narrative_keys(out: Dictionary, word: RegEx, spec: RegEx) -> void:
	var path := "res://scripts/MiniGameBase.gd"
	var text := FileAccess.get_file_as_string(path)
	var game := RegEx.create_from_string('^"([A-Za-z0-9_]+)":[[:space:]]*[{]$')
	var field := RegEx.create_from_string('^"([a-z_]+)":[[:space:]]*"(.*)"[,]?$')
	var in_table := false
	var current := ""
	var line_no := 0
	for raw in text.split("\n"):
		line_no += 1
		if raw.begins_with("func _get_narratives"):
			in_table = true
			continue
		if not in_table:
			continue
		if raw.begins_with("func "):
			break
		var line := raw.strip_edges()
		var g := game.search(line)
		if g != null:
			current = g.get_string(1)
			if not _narrative_row_is_reachable(current):
				_stale_rows += 1
				current = ""
			continue
		var f := field.search(line)
		if f == null or current == "":
			continue
		if not _is_translatable(f.get_string(2), word, spec):
			continue
		var key := "narrative_%s_%s" % [current.to_snake_case(), f.get_string(1)]
		if not out.has(key):
			out[key] = "%s:%d" % [path, line_no]

## CharacterOutcomeNarrative._get_narrative_for_key():
## "Game": { "win": {"character": "X", "context": "Y"}, "lose": {...} }
## keyed as narrative_<slug>_<outcome>_<field>.
func _collect_outcome_narrative_keys(out: Dictionary, word: RegEx, spec: RegEx) -> void:
	var path := "res://scenes/ui/cutscenes/CharacterOutcomeNarrative.gd"
	var text := FileAccess.get_file_as_string(path)
	var game := RegEx.create_from_string('^"([A-Za-z0-9_]+)":[[:space:]]*[{]$')
	var row := RegEx.create_from_string(
		'^"(win|lose)":[[:space:]]*[{]"character":[[:space:]]*"([^"]*)",'
		+ '[[:space:]]*"context":[[:space:]]*"(.*)"[}][,]?$')
	var in_table := false
	var current := ""
	var line_no := 0
	for raw in text.split("\n"):
		line_no += 1
		if raw.begins_with("func _get_narrative_for_key"):
			in_table = true
			continue
		if not in_table:
			continue
		if raw.begins_with("func "):
			break
		var line := raw.strip_edges()
		var g := game.search(line)
		if g != null:
			current = g.get_string(1)
			if not _narrative_row_is_reachable(current):
				_stale_rows += 1
				current = ""
			continue
		var r := row.search(line)
		if r == null or current == "":
			continue
		var slug := current.to_snake_case().to_lower()
		var fields := {"character": r.get_string(2), "context": r.get_string(3)}
		for fname in fields:
			if not _is_translatable(fields[fname], word, spec):
				continue
			var key := "narrative_%s_%s_%s" % [slug, r.get_string(1), fname]
			if not out.has(key):
				out[key] = "%s:%d" % [path, line_no]

## LevelSets: "player1_role": "Vegetable Washer" — keyed as mp_role_<snake>.
## NetworkManager's placeholder pair {Collector, User} is a role ID the game branches
## on, and it is displayed through the same helper, so both belong in the family.
func _collect_role_keys(out: Dictionary) -> void:
	var sources := {
		"res://scripts/multiplayer/LevelSets.gd":
			'"player[12]_role":[[:space:]]*"([^"]+)"',
		"res://autoload/NetworkManager.gd":
			'player_roles[[:space:]]*=[[:space:]]*[{]1:[[:space:]]*"([^"]+)",[[:space:]]*2:[[:space:]]*"([^"]+)"',
	}
	for path in sources:
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		var re := RegEx.create_from_string(sources[path])
		for m in re.search_all(text):
			var line_no := text.substr(0, m.get_start()).count("\n") + 1
			for i in range(1, m.get_group_count() + 1):
				var role: String = m.get_string(i)
				if role.strip_edges() == "":
					continue
				var key := "mp_role_%s" % role.to_snake_case()
				if not out.has(key):
					out[key] = "%s:%d" % [path, line_no]


## A value carries translatable copy only if something survives stripping the
## formatter out of it — same rule criterion 7 applies to label literals, so an
## emoji-only or "%d / %d" value is not demanded to have a table entry. A lone
## letter cannot be copy either, which is why the word pattern wants two: it is
## what keeps the "n" of an escaped newline from reading as a word.
func _is_translatable(value: String, word: RegEx, spec: RegEx) -> bool:
	return word.search(spec.sub(value, "", true)) != null

## Whether any live script can hand this table row's key to the composer.
##
## Both narrative tables live on the singleplayer side: _get_narratives() is a
## MiniGameBase method and the outcome table is only ever populated by
## MiniGameBase's cutscene call, so the key always comes from
## _get_minigame_key() -- the filename of a script that extends MiniGameBase. The
## 12 MP_* scripts extend MultiplayerMiniGameBase (a plain Node2D) and read their
## own mp_react_* family instead, and RainwaterHarvesting extends Node2D
## directly, so 24 rows in those two tables can never reach a player: they are
## stale rows to delete, not translations to write, and demanding keys for them
## would put 60 entries in the table that nothing can ever look up.
##
## The two flags are re-derived from the source on every run, so if either script
## is ever re-parented onto MiniGameBase the rows stop being skipped and their
## keys are demanded on the spot.
func _narrative_row_is_reachable(game_key: String) -> bool:
	if game_key.begins_with("MP_"):
		return _mp_reaches_base
	if game_key == "RainwaterHarvesting":
		return _rwh_reaches_base
	return true


func _extends_minigame_base(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	var re := RegEx.create_from_string('(?m)^extends[[:space:]]+(.*)$')
	var m := re.search(text)
	if m == null:
		return false
	return m.get_string(1).contains("MiniGameBase")


## MultiplayerMiniGameBase._react_line(): "mp_react_%s_%s" % [outcome, _mp_game_key()],
## and _mp_game_key() is the script filename with MP_ stripped, so the MP_*.gd file
## list is the source table for this family. A missing key here degrades to the shared
## default line rather than to English, which is why it needs a check of its own: the
## symptom is a generic line, not a visibly untranslated one.
func _collect_mp_react_keys(out: Dictionary) -> void:
	for path in _list_gd_files("res://scripts/multiplayer"):
		var base := path.get_file().trim_suffix(".gd")
		if not base.begins_with("MP_"):
			continue
		var game := base.trim_prefix("MP_").to_snake_case()
		for outcome in ["win", "fail"]:
			var key := "mp_react_%s_%s" % [outcome, game]
			if not out.has(key):
				out[key] = path

## SimpleCutscenePlayer._get_scene_data():
##   "Game": { "win": { "bg":…, "props":[…], "text": "…" }, "fail": {…} }
## The flavour line is looked up as cutscene_line_<slug>_<win|fail> just before that
## function returns, with the authored English as the fallback — so a missing entry is
## invisible in the log and shows English in the Filipino build, the same failure mode
## the narrative families had.
func _collect_cutscene_line_keys(out: Dictionary, word: RegEx, spec: RegEx) -> void:
	var path := "res://scripts/cutscenes/SimpleCutscenePlayer.gd"
	var text := FileAccess.get_file_as_string(path)
	var outcome_re := RegEx.create_from_string('^"(win|fail)":[[:space:]]*[{]$')
	var game_re := RegEx.create_from_string('^"([A-Za-z0-9_]+)":[[:space:]]*[{]$')
	var text_re := RegEx.create_from_string('^"text":[[:space:]]*"(.*)"[,]?$')
	var in_table := false
	var current := ""
	var outcome := ""
	var line_no := 0
	for raw in text.split("\n"):
		line_no += 1
		if raw.begins_with("func _get_scene_data"):
			in_table = true
			continue
		if not in_table:
			continue
		if raw.begins_with("func "):
			break
		var line := raw.strip_edges()
		var o := outcome_re.search(line)
		if o != null:
			outcome = o.get_string(1)
			continue
		var g := game_re.search(line)
		if g != null:
			current = g.get_string(1)
			outcome = ""
			# Same reachability rule as the narrative tables, for the same reason: this
			# player is created and driven by MiniGameBase (_show_success_micro_cutscene),
			# so a row for a game that does not extend MiniGameBase is never looked up.
			if not _narrative_row_is_reachable(current):
				_stale_rows += 1
				current = ""
			continue
		var t := text_re.search(line)
		if t == null or current == "" or outcome == "":
			continue
		if not _is_translatable(t.get_string(1), word, spec):
			continue
		var key := "cutscene_line_%s_%s" % [current.to_snake_case(), outcome]
		if not out.has(key):
			out[key] = "%s:%d" % [path, line_no]

## CharacterCustomization._get_character_name() and UnlockablesScreen's twin both compose
## character_name_<id>; the eight preset ids are therefore the expected key set. Both call
## sites pass the English name as the fallback, so a missing id shows English silently.
func _collect_character_name_keys(out: Dictionary) -> void:
	var path := "res://scenes/ui/CharacterCustomization.gd"
	var text := FileAccess.get_file_as_string(path)
	var id_re := RegEx.create_from_string('^[{]"id":[[:space:]]*"([a-z0-9_]+)"')
	var in_table := false
	var line_no := 0
	for raw in text.split("\n"):
		line_no += 1
		if raw.begins_with("const CHARACTER_PRESETS"):
			in_table = true
			continue
		if not in_table:
			continue
		if raw.begins_with("]"):
			break
		var m := id_re.search(raw.strip_edges())
		if m == null:
			continue
		var key := "character_name_%s" % m.get_string(1)
		if not out.has(key):
			out[key] = "%s:%d" % [path, line_no]

# ── 9. Data-table "key" fields name real entries ────────────────────

## Criterion 1 reads the literal argument of _loc()/get_text(); it cannot see a key that
## a data table stores and hands to the lookup later — {"key": "material_cloth"} in
## FilterBuilder.MATERIALS, InitialScreen.ALL_UNLOCKABLES, the three MP object tables,
## VegetableBath's quips. That indirection is what let those labels stay English while
## the harness was green, so the pattern gets its own check: every "key": "<literal>"
## data field must name an entry that exists.
func _verify_data_field_keys_defined() -> void:
	print("\n[9] Data-table \"key\" fields name real entries")
	var field := RegEx.create_from_string('"key":[[:space:]]*"([A-Za-z0-9_]+)"')
	var found := {}
	for dir_path in ["res://autoload", "res://scenes", "res://scripts"]:
		for path in _list_gd_files(dir_path):
			var text := FileAccess.get_file_as_string(path)
			var line_no := 0
			for raw in text.split("\n"):
				line_no += 1
				var m := field.search(raw)
				if m == null:
					continue
				var key := m.get_string(1)
				if not found.has(key):
					found[key] = "%s:%d" % [path, line_no]
	var missing: Array[String] = []
	for key in found:
		if not Localization.has_text(key):
			missing.append("%s (%s)" % [key, found[key]])
	_check(
		"all %d data-field keys defined" % found.size(),
		missing.is_empty(),
		"%d missing" % missing.size())
	for i in range(min(missing.size(), 10)):
		print("      → %s" % missing[i])
	# Vacuity floor: the six converted tables carry 38 of these fields between them, so a
	# scan that suddenly finds fewer has stopped matching rather than found a clean project.
	_check(
		"data-field scan still finds the converted tables (%d fields)" % found.size(),
		found.size() >= 38,
		"only %d found — the scan or the tables moved" % found.size())
