extends Node

## Will every glyph the game draws actually have a shape, and where does that shape come from?
##
## Batch 5's eyes-on review of the Hard-tier frames caught WaterPlant's fourth growth stage
## rendering as a hex box instead of a plant. Nothing in the readability metric can see that: a
## tofu box is ink on a background like any other glyph, so it measures a healthy contrast ratio
## and passes. Only the text server knows, and it will say so if asked.
##
## HOW A MISSING GLYPH IS DETECTED
##
## Shape the character and look at the result. TextServer returns glyph index 0 for a character no
## font in the chain could supply, and Godot then draws its hex-code box - the exact artefact in
## the frame. So this harness shapes every non-ASCII codepoint the project puts in a string and
## asks whether index 0 comes back. That is the drawn truth, not an inference from a cmap.
##
## THE THREE CHAINS, AND WHY ALL THREE MATTER
##
## Godot resolves a character in three steps: the font's own cmap, then the explicit fallbacks on
## that font, then - if allow_system_fallback is on, which is the default - a font belonging to the
## operating system. That last step is the trap. On this Windows box it reaches Segoe UI Emoji, so
## an emoji missing from everything the project ships still LOOKS right here and is a hex box on a
## legacy Android phone whose system emoji font predates it. The exported build carries fonts/.
##
##   PRODUCTION-DEFAULT   ThemeDB.fallback_font, what a Label with no font override draws. Most of
##                        the minigames are this: they set font_size and nothing else.
##   PRODUCTION-DISPLAY   the loaded Cubao and NT Brick Sans instances, which ThemeManager patches
##                        with Noto Emoji at startup. The menus and the MP HUD use these.
##   BUNDLED-ONLY         the three shipped font files with the chain cleared and the system step
##                        turned off: what survives on a device that offers Godot nothing.
##
## A codepoint that tofus in either production chain is a defect visible right now and fails. A
## codepoint that only the operating system rescues is reported with its sites, because that is a
## risk the thesis build carries onto the demo device, not something a font file here can fix.
##
## WHAT THE REMAINING WARNS ARE, AND WHY THEY STAY
##
## The OS-dependent list is down to seven codepoints, and each one was traced to where the string
## is actually consumed rather than left as a standing risk. None of them reaches a rasteriser on
## the device:
##
##   U+2192 -> U+2500 - U+2501 - U+2514 L   console dividers and log text: AdaptiveDifficulty's
##                        decision_path (which goes to _queue_log and into the exported JSON, and
##                        has no UI consumer), its status_message field (no consumer anywhere), and
##                        PerformanceProfiler's thermal print(). U+2192 also survives in
##                        FileExporter's EXPORT_INFO.txt, which is a file on disk read in a text
##                        editor, not drawn by this project's font chain.
##   U+2550 =             the same, plus AutoPlayManager's own console banner.
##   U+2715 X - U+275A |  AutoPlayManager.SHELL_BUTTON_GLYPHS, an EXACT-MATCH detector on button
##                        text. The close and QUIT buttons were re-lettered to U+2716 by the fix,
##                        and both spellings are kept on purpose so a screen not yet re-lettered is
##                        still recognised - see the comment there. Matched against, never drawn.
##
## Every on-screen occurrence was substituted for a glyph this harness measures as reachable
## (tools/ProbeGlyphCandidates.tscn is what chose them). So a NEW warn naming a scenes/ or scripts/
## line that assigns .text is a real finding, not more of the same.
const BUNDLED_FONTS: Array[String] = [
	"res://fonts/Cubao_Free_Wide.otf",
	"res://fonts/NTBrickSans.otf",
	"res://fonts/NotoEmoji.ttf",
]

## Everything that can put a string on screen at runtime, plus tools/ - reported apart, because a
## harness printing to a console has no glyph problem to fix.
const SCAN_DIRS: Array[String] = ["res://autoload", "res://scenes", "res://scripts", "res://tools"]
const SCAN_EXT: Array[String] = ["gd", "tscn", "tres", "csv", "json"]

## Shaping size. Coverage does not vary with it, but a real size keeps the probe on the same code
## path the game uses.
const PROBE_PX: int = 32

var _bundled: Array[Font] = []
var _bundled_names: Array[String] = []
var _prod: Array[Font] = []
var _prod_names: Array[String] = []
var _prod_offline: Array[Font] = []
var _prod_offline_names: Array[String] = []
## codepoint -> {"sites": Array, "count": int, "dev_only": bool, "drawn": bool}
var _used: Dictionary = {}

## Codepoints that are never drawn as a glyph of their own: they modify the run around them. A
## presentation selector or a skin tone shapes to nothing on its own, so testing one alone would
## report a failure that does not exist.
##   FE0E/FE0F   text and emoji presentation selectors
##   200D        zero-width joiner (family and profession sequences)
##   20E3        combining enclosing keycap
##   1F3FB-1F3FF skin tone modifiers
##   E0020-E007F tag characters (flag sequences)
func _is_modifier(cp: int) -> bool:
	if cp == 0xFE0E or cp == 0xFE0F or cp == 0x200D or cp == 0x20E3:
		return true
	if cp >= 0x1F3FB and cp <= 0x1F3FF:
		return true
	if cp >= 0xE0020 and cp <= 0xE007F:
		return true
	return false

## The same font object with the operating system's fonts taken away and its own fallback chain
## left intact - recursively, since a fallback font carries the flag too. This is the legacy
## Android device modelled honestly: Godot still has fonts/ and whatever the engine ships, and the
## OS supplies nothing the project can count on.
##
## Measuring this is the point. With the system step left on, every chain draws every emoji on this
## Windows box because Segoe UI Emoji answers, so the report went GREEN while a Label with no font
## override had an EMPTY fallback list and nothing bundled to fall back TO. That is the reported
## Android 8 tofu, and it was invisible to the chains this harness had.
func _offline_probe(font: Font, depth: int = 0) -> Font:
	var p: Font = font.duplicate()
	if p is FontFile:
		(p as FontFile).allow_system_fallback = false
	elif p is SystemFont:
		(p as SystemFont).allow_system_fallback = false
	var chain: Array[Font] = []
	if depth < 4:
		for sub in font.fallbacks:
			if sub is Font:
				chain.append(_offline_probe(sub as Font, depth + 1))
	p.fallbacks = chain
	return p

## True when this font chain draws the character as Godot's hex-code box.
##
## The signal is font_rid, not the glyph index. When no font in the chain can supply a character,
## TextServerAdvanced does not emit a .notdef: it clears font_rid and puts the CODEPOINT ITSELF in
## index, and the canvas layer then routes that glyph to draw_hex_code_box(index) - which is why the
## box in the frame reads 01FAB4. Testing index == 0 therefore finds nothing and reports a false
## GREEN, exactly what the first version of this harness did.
func _tofu(font: Font, cp: int) -> bool:
	var tl := TextLine.new()
	tl.add_string(String.chr(cp), font, PROBE_PX)
	var ts := TextServerManager.get_primary_interface()
	ts.shaped_text_shape(tl.get_rid())
	var glyphs: Array = ts.shaped_text_get_glyphs(tl.get_rid())
	if glyphs.is_empty():
		return true  # nothing to draw at all
	for g in glyphs:
		var rid: RID = g.get("font_rid", RID())
		if not rid.is_valid():
			return true  # hex-code box
		if int(g.get("index", 0)) == 0:
			return true  # a real .notdef from a font that claimed the run
	return false

func _ready() -> void:
	print("=== GLYPH COVERAGE ===")
	# BUNDLED-ONLY: duplicate first, so clearing the chain cannot leak into the cached resource the
	# game itself is using - ThemeManager has already patched these instances by now.
	for path in BUNDLED_FONTS:
		if not ResourceLoader.exists(path):
			print("[FAIL] bundled font missing from the project: ", path)
			continue
		var f: Font = load(path)
		if f == null:
			print("[FAIL] bundled font would not load: ", path)
			continue
		var probe: Font = f.duplicate()
		probe.fallbacks = []
		if probe is FontFile:
			(probe as FontFile).allow_system_fallback = false
		_bundled.append(probe)
		_bundled_names.append(path.get_file())
	# PRODUCTION: exactly the objects the game draws with, chains and system step untouched.
	var default_font: Font = ThemeDB.fallback_font
	if default_font != null:
		_prod.append(default_font)
		_prod_names.append("ThemeDB.fallback_font")
		# The engine's own default font travels inside the binary on every platform, so whatever it
		# covers is as safe to ship as fonts/. Measured with the chain cleared and the system step
		# off, the same way the bundled files are, and counted as shipped coverage.
		var engine_probe: Font = default_font.duplicate()
		engine_probe.fallbacks = []
		if engine_probe is FontFile:
			(engine_probe as FontFile).allow_system_fallback = false
		elif engine_probe is SystemFont:
			(engine_probe as SystemFont).allow_system_fallback = false
		_bundled.append(engine_probe)
		_bundled_names.append("engine default (%s)" % default_font.get_class())
	for path in [BUNDLED_FONTS[0], BUNDLED_FONTS[1]]:
		var pf: Font = load(path)
		if pf != null:
			_prod.append(pf)
			_prod_names.append(path.get_file())
	# PRODUCTION-OFFLINE: those same chains on a device whose system fonts offer nothing.
	for i in range(_prod.size()):
		_prod_offline.append(_offline_probe(_prod[i]))
		_prod_offline_names.append(_prod_names[i])
	print("bundled-only chains: ", ", ".join(_bundled_names))
	print("production chains:   ", ", ".join(_prod_names))
	print("production chains, OS fonts removed (the legacy-Android model): ",
		", ".join(_prod_offline_names))

	for d in SCAN_DIRS:
		_walk(d)

	var drawn_tofu: Array = []
	## Shipped in fonts/, and still a hex box on a device with no system emoji font, because the
	## chain that draws it cannot reach the file that has it. A wiring defect, fixable in code -
	## which is why it fails the run rather than warning.
	var unreachable: Array = []
	var os_rescued: Array = []
	var dev_notes: Array = []
	var clean: int = 0
	var cps: Array = _used.keys()
	cps.sort()
	for cp in cps:
		if _is_modifier(cp):
			continue
		var rec: Dictionary = _used[cp]
		var bundled_owner: String = ""
		for i in range(_bundled.size()):
			if not _tofu(_bundled[i], cp):
				bundled_owner = _bundled_names[i]
				break
		var tofu_in: Array = []
		for i in range(_prod.size()):
			if _tofu(_prod[i], cp):
				tofu_in.append(_prod_names[i])
		var plural: String = "" if int(rec["count"]) == 1 else "s"
		var where: String = "%d site%s: %s" % [int(rec["count"]), plural, ", ".join(rec["sites"])]
		var head: String = "U+%04X [%s]" % [cp, String.chr(cp)]
		if not tofu_in.is_empty():
			var line: String = "%s draws a hex box under %s  %s" % [head, ", ".join(tofu_in), where]
			if bool(rec["dev_only"]):
				dev_notes.append(line)
			else:
				drawn_tofu.append(line)
			continue
		if bundled_owner == "":
			var line2: String = "%s only the OS font has it  %s" % [head, where]
			if bool(rec["dev_only"]):
				dev_notes.append(line2)
			else:
				os_rescued.append(line2)
			continue
		# The glyph is in a file this build ships. Can the chains the game actually draws with get
		# to it without asking Android for help?
		var offline_tofu: Array = []
		for i in range(_prod_offline.size()):
			if _tofu(_prod_offline[i], cp):
				offline_tofu.append(_prod_offline_names[i])
		if not offline_tofu.is_empty():
			var line3: String = "%s is in %s but %s cannot reach it  %s" % [
				head, bundled_owner, ", ".join(offline_tofu), where]
			if bool(rec["dev_only"]):
				dev_notes.append(line3)
			else:
				unreachable.append(line3)
			continue
		clean += 1

	var total: int = (clean + drawn_tofu.size() + unreachable.size() + os_rescued.size()
		+ dev_notes.size())
	print("distinct non-ASCII codepoints in string literals: ", total)
	print("shipped in a bundled font and drawn by every production chain, OS font or not: ", clean)
	if not drawn_tofu.is_empty():
		print("--- HEX BOX ON THIS MACHINE, IN A RUNTIME STRING ---")
		for l in drawn_tofu:
			print("[FAIL] ", l)
	if not unreachable.is_empty():
		print("--- SHIPPED BUT UNREACHABLE: hex box on a device with no system font for it ---")
		for l in unreachable:
			print("[FAIL] ", l)
	if not os_rescued.is_empty():
		print("--- DRAWN HERE ONLY BECAUSE WINDOWS SUPPLIES THE GLYPH (legacy Android risk) ---")
		for l in os_rescued:
			print("[warn] ", l)
	if not dev_notes.is_empty():
		print("--- tools/ only: console output, never rasterised ---")
		for l in dev_notes:
			print("[info] ", l)
	print("RESULT: %d draw as a hex box here, %d shipped but unreachable offline, %d depend on the OS font" % [
		drawn_tofu.size(), unreachable.size(), os_rescued.size()])
	var bad: bool = not drawn_tofu.is_empty() or not unreachable.is_empty()
	print("GLYPH COVERAGE: ", "RED" if bad else "GREEN")
	get_tree().quit(1 if bad else 0)

func _walk(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full: String = dir_path.path_join(name)
		if dir.current_is_dir():
			_walk(full)
		elif SCAN_EXT.has(name.get_extension().to_lower()):
			_scan_file(full)
		name = dir.get_next()
	dir.list_dir_end()

func _scan_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var dev_only: bool = path.begins_with("res://tools")
	if path.get_extension().to_lower() == "gd":
		_scan_gd(text, path, dev_only)
		return
	# .tscn/.tres/.csv/.json: no comment syntax worth modelling, and every non-ASCII character in
	# them is either display text or part of a resource path.
	var line: int = 1
	for i in range(text.length()):
		var cp: int = text.unicode_at(i)
		if cp == 10:
			line += 1
		elif cp > 127:
			_record(cp, path, line, dev_only)

## Only string literals count. A doc comment full of em dashes is never rasterised, and counting it
## as content would bury the real findings under punctuation this project uses on every page.
## Triple-quoted blocks are in scope: the MP intro cards are written that way and carry emoji.
func _scan_gd(text: String, path: String, dev_only: bool) -> void:
	var i: int = 0
	var line: int = 1
	var n: int = text.length()
	while i < n:
		var cp: int = text.unicode_at(i)
		if cp == 10:
			line += 1
			i += 1
		elif cp == 35:  # hash outside a literal: comment runs to the end of the line
			while i < n and text.unicode_at(i) != 10:
				i += 1
		elif cp == 34 and i + 2 < n and text.unicode_at(i + 1) == 34 and text.unicode_at(i + 2) == 34:
			i += 3
			while i < n:
				if text.unicode_at(i) == 34 and i + 2 < n and text.unicode_at(i + 1) == 34 and text.unicode_at(i + 2) == 34:
					i += 3
					break
				var c: int = text.unicode_at(i)
				if c == 10:
					line += 1
				elif c > 127:
					_record(c, path, line, dev_only)
				i += 1
		elif cp == 34 or cp == 39:  # a single-line literal in either quote style
			var quote: int = cp
			i += 1
			while i < n:
				var c2: int = text.unicode_at(i)
				if c2 == 92:  # backslash escape: skip the escaped character too
					i += 2
					continue
				if c2 == quote:
					i += 1
					break
				if c2 == 10:  # unterminated literal: resync on the newline
					line += 1
					i += 1
					break
				if c2 > 127:
					_record(c2, path, line, dev_only)
				i += 1
		else:
			i += 1

func _record(cp: int, path: String, line: int, dev_only: bool) -> void:
	if not _used.has(cp):
		_used[cp] = {"sites": [], "count": 0, "dev_only": true}
	var rec: Dictionary = _used[cp]
	rec["count"] = int(rec["count"]) + 1
	if not dev_only:
		rec["dev_only"] = false
	var sites: Array = rec["sites"]
	if sites.size() < 4:
		var site: String = "%s:%d" % [path.replace("res://", ""), line]
		if not sites.has(site):
			sites.append(site)
