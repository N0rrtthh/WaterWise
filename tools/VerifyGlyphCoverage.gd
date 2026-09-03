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
	print("bundled-only chains: ", ", ".join(_bundled_names))
	print("production chains:   ", ", ".join(_prod_names))

	for d in SCAN_DIRS:
		_walk(d)

	var drawn_tofu: Array = []
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
		clean += 1

	var total: int = clean + drawn_tofu.size() + os_rescued.size() + dev_notes.size()
	print("distinct non-ASCII codepoints in string literals: ", total)
	print("shipped in a bundled font and drawn by every production chain: ", clean)
	if not drawn_tofu.is_empty():
		print("--- HEX BOX ON THIS MACHINE, IN A RUNTIME STRING ---")
		for l in drawn_tofu:
			print("[FAIL] ", l)
	if not os_rescued.is_empty():
		print("--- DRAWN HERE ONLY BECAUSE WINDOWS SUPPLIES THE GLYPH (legacy Android risk) ---")
		for l in os_rescued:
			print("[warn] ", l)
	if not dev_notes.is_empty():
		print("--- tools/ only: console output, never rasterised ---")
		for l in dev_notes:
			print("[info] ", l)
	print("RESULT: %d runtime codepoints draw as a hex box, %d depend on the OS font" % [
		drawn_tofu.size(), os_rescued.size()])
	print("GLYPH COVERAGE: ", "GREEN" if drawn_tofu.is_empty() else "RED")
	get_tree().quit(0 if drawn_tofu.is_empty() else 1)

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
