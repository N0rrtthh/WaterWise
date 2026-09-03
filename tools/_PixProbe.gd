extends Node

func _ready() -> void:
	var img: Image = Image.load_from_file(
		"res://tools/probe_frames/sweep_hard/MP_FillAquarium.png")
	print("image ", img.get_size())
	var counts: Dictionary = {}
	for y in range(100, 123):
		var line: String = ""
		for x in range(20, 107):
			var c: Color = img.get_pixel(x, y)
			var l: float = c.get_luminance()
			line += "#" if l > 0.7 else ("+" if l > 0.35 else (":" if l > 0.12 else "."))
			var key: String = "(%.2f,%.2f,%.2f)" % [c.r, c.g, c.b]
			counts[key] = int(counts.get(key, 0)) + 1
		print(line)
	var ranked: Array = counts.keys()
	ranked.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]))
	for i in range(mini(6, ranked.size())):
		print("  colour %-22s x%d" % [ranked[i], int(counts[ranked[i]])])
	get_tree().quit()
