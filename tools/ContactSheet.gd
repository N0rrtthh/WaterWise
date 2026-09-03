extends Node

## ═══════════════════════════════════════════════════════════════════
## CONTACT SHEET — montage the visual-sweep frames for eyes-on review
## ═══════════════════════════════════════════════════════════════════
## The sweep in VisualSweepHard.gd measures contrast, collision and off-screen text, but a metric
## cannot see "this screen is empty", "the mascot is standing in the drum" or "there is a black box
## in the corner". Those need looking at, and opening 36 full-size PNGs one at a time is the slow
## way to look. This tiles them 3x2 at quarter scale, which is the whole set in six sheets.
##
## Usage (headless is fine - it only reads and writes files):
##   Godot --headless --path . res://tools/ContactSheet.tscn -- group=1
##   Godot --headless --path . res://tools/ContactSheet.tscn        (writes every sheet)

const SRC: String = "res://tools/probe_frames/sweep_hard"
const CELL: Vector2i = Vector2i(640, 360)
const COLS: int = 3
const ROWS: int = 2

var group: int = 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "group":
			group = int(kv[1])
	var names: Array = _frames()
	if names.is_empty():
		print("[SHEET] no frames in ", SRC, " - run VisualSweepHard first")
		get_tree().quit(1)
		return
	var per: int = COLS * ROWS
	var sheets: int = int(ceil(float(names.size()) / float(per)))
	print("[SHEET] %d frames -> %d sheets of %d" % [names.size(), sheets, per])
	for s in range(sheets):
		if group > 0 and s != group - 1:
			continue
		_build(names.slice(s * per, mini((s + 1) * per, names.size())), s + 1)
	get_tree().quit()


## Sweep output only: the annotated _boxes and repainted _paint copies are diagnostics for the
## metric itself, not frames of the game, and they would double-count every row.
func _frames() -> Array:
	var out: Array = []
	var d: DirAccess = DirAccess.open(SRC)
	if d == null:
		return out
	d.list_dir_begin()
	var f: String = d.get_next()
	while f != "":
		if f.ends_with(".png") and not f.contains("_boxes") and not f.contains("_paint") \
				and not f.begins_with("_sheet"):
			out.append(f)
		f = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


func _build(names: Array, index: int) -> void:
	var sheet: Image = Image.create(CELL.x * COLS, CELL.y * ROWS, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.08, 0.1))
	var placed: Array = []
	for i in range(names.size()):
		var img: Image = Image.load_from_file("%s/%s" % [SRC, String(names[i])])
		if img == null:
			continue
		img.resize(CELL.x - 4, CELL.y - 4, Image.INTERPOLATE_BILINEAR)
		var at := Vector2i((i % COLS) * CELL.x + 2, (i / COLS) * CELL.y + 2)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
		placed.append("%d:%s" % [i + 1, String(names[i]).get_basename()])
	var path: String = "%s/_sheet%d.png" % [SRC, index]
	sheet.save_png(ProjectSettings.globalize_path(path))
	print("[SHEET %d] %s" % [index, "  ".join(placed)])
