extends Control

## ═══════════════════════════════════════════════════════════════════
## DEV STATS — Developer-Only Session Statistics & Log Export
## ═══════════════════════════════════════════════════════════════════
## Accessible from Settings when Dev Mode is enabled.
## Shows live session metrics and all data needed for thesis defence.
## Press EXPORT to save a JSON log to user://session_logs/
## ═══════════════════════════════════════════════════════════════════

const FONT_TITLE: Font = preload("res://fonts/Cubao_Free_Wide.otf")
const FONT_BODY: Font = preload("res://fonts/NTBrickSans.otf")

# Colours
const COL_BG        := Color(0.05, 0.07, 0.12, 1.0)
const COL_PANEL     := Color(0.10, 0.13, 0.20, 1.0)
const COL_HEADER    := Color(0.30, 0.70, 1.00, 1.0)
const COL_GOOD      := Color(0.30, 1.00, 0.50, 1.0)
const COL_WARN      := Color(1.00, 0.85, 0.20, 1.0)
const COL_BAD       := Color(1.00, 0.30, 0.30, 1.0)
const COL_TEXT      := Color(0.90, 0.92, 0.95, 1.0)
const COL_MUTED     := Color(0.55, 0.60, 0.70, 1.0)
const COL_ACCENT    := Color(0.20, 0.80, 0.60, 1.0)

# UI nodes
var _scroll: ScrollContainer
var _vbox: VBoxContainer
var _export_btn: Button
var _export_txt_btn: Button
var _export_status_lbl: Label
var _dir_input: LineEdit
var _refresh_timer: Timer

# Section labels that need live refresh
var _live_fps_lbl: Label
var _live_temp_lbl: Label
var _live_mem_lbl: Label
var _live_phi_lbl: Label
var _live_diff_lbl: Label
var _sp_table_vbox: VBoxContainer
var _mp_table_vbox: VBoxContainer
var _diff_change_vbox: VBoxContainer
var _throttle_vbox: VBoxContainer
var _iso_vbox: VBoxContainer

func _ready() -> void:
	_build_ui()
	_populate_all()

	_refresh_timer = Timer.new()
	_refresh_timer.wait_time = 1.0
	_refresh_timer.timeout.connect(_on_refresh_tick)
	add_child(_refresh_timer)
	_refresh_timer.start()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UI BUILD
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COL_BG
	add_child(bg)

	# Header bar
	var header_bar := PanelContainer.new()
	header_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var hbar_style := StyleBoxFlat.new()
	hbar_style.bg_color = Color(0.08, 0.12, 0.22, 1.0)
	hbar_style.border_color = COL_HEADER
	hbar_style.border_width_bottom = 2
	hbar_style.content_margin_left = 20
	hbar_style.content_margin_right = 20
	hbar_style.content_margin_top = 12
	hbar_style.content_margin_bottom = 12
	header_bar.add_theme_stylebox_override("panel", hbar_style)
	add_child(header_bar)

	var hbar_hbox := HBoxContainer.new()
	hbar_hbox.add_theme_constant_override("separation", 16)
	header_bar.add_child(hbar_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "📊 WaterWise — Dev Stats & Session Log"
	if FONT_TITLE:
		title_lbl.add_theme_font_override("font", FONT_TITLE)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", COL_HEADER)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbar_hbox.add_child(title_lbl)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "⬅ BACK"
	back_btn.custom_minimum_size = Vector2(120, 50)
	back_btn.pressed.connect(_on_back_pressed)
	hbar_hbox.add_child(back_btn)

	# Main scroll area (below header)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Leave top space for header (~70px)
	_scroll.offset_top = 70.0
	_scroll.offset_bottom = -80.0  # Leave bottom space for export bar
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 16)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin_wrap := MarginContainer.new()
	margin_wrap.add_theme_constant_override("margin_left", 20)
	margin_wrap.add_theme_constant_override("margin_right", 20)
	margin_wrap.add_theme_constant_override("margin_top", 16)
	margin_wrap.add_theme_constant_override("margin_bottom", 16)
	margin_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin_wrap.add_child(_vbox)
	_scroll.add_child(margin_wrap)

	# Export bar at bottom (two rows: dir picker + export buttons)
	var export_bar := PanelContainer.new()
	export_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	export_bar.offset_top = -138.0
	var ebar_style := StyleBoxFlat.new()
	ebar_style.bg_color = Color(0.08, 0.12, 0.22, 1.0)
	ebar_style.border_color = COL_ACCENT
	ebar_style.border_width_top = 2
	ebar_style.content_margin_left = 20
	ebar_style.content_margin_right = 20
	ebar_style.content_margin_top = 10
	ebar_style.content_margin_bottom = 10
	export_bar.add_theme_stylebox_override("panel", ebar_style)
	add_child(export_bar)

	var ebar_vbox := VBoxContainer.new()
	ebar_vbox.add_theme_constant_override("separation", 8)
	export_bar.add_child(ebar_vbox)

	# ── Row 1: export directory picker ──────────────────────────────
	var dir_row := HBoxContainer.new()
	dir_row.add_theme_constant_override("separation", 10)
	ebar_vbox.add_child(dir_row)

	var dir_lbl := Label.new()
	dir_lbl.text = "📁 Save to:"
	dir_lbl.add_theme_font_size_override("font_size", 14)
	dir_lbl.add_theme_color_override("font_color", COL_MUTED)
	dir_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dir_row.add_child(dir_lbl)

	_dir_input = LineEdit.new()
	var sl_node: Node = get_node_or_null("/root/SessionLogger")
	_dir_input.text = sl_node.export_dir if sl_node else "user://session_logs/"
	_dir_input.placeholder_text = "e.g. user://session_logs/ or /sdcard/Documents/"
	_dir_input.custom_minimum_size = Vector2(420, 36)
	_dir_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dir_input.add_theme_font_size_override("font_size", 13)
	dir_row.add_child(_dir_input)

	var change_dir_btn := Button.new()
	change_dir_btn.text = "✔ Apply"
	change_dir_btn.custom_minimum_size = Vector2(100, 36)
	change_dir_btn.add_theme_font_size_override("font_size", 14)
	change_dir_btn.pressed.connect(_on_change_dir_pressed)
	dir_row.add_child(change_dir_btn)

	var reset_dir_btn := Button.new()
	reset_dir_btn.text = "↺ Reset"
	reset_dir_btn.custom_minimum_size = Vector2(90, 36)
	reset_dir_btn.add_theme_font_size_override("font_size", 14)
	reset_dir_btn.pressed.connect(func():
		var _sl: Node = get_node_or_null("/root/SessionLogger")
		if _sl and _sl.has_method("set_export_dir"):
			_sl.set_export_dir("")
			_dir_input.text = _sl.export_dir
			_export_status_lbl.text = "↺ Reset to default: %s" % _sl.export_dir
			_export_status_lbl.add_theme_color_override("font_color", COL_MUTED)
	)
	dir_row.add_child(reset_dir_btn)

	# ── Row 2: export buttons + status ───────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	ebar_vbox.add_child(btn_row)

	_export_btn = Button.new()
	_export_btn.text = "💾 Export JSON"
	_export_btn.custom_minimum_size = Vector2(190, 46)
	_export_btn.add_theme_font_size_override("font_size", 17)
	_export_btn.pressed.connect(_on_export_pressed)
	btn_row.add_child(_export_btn)

	_export_txt_btn = Button.new()
	_export_txt_btn.text = "📄 Export TXT"
	_export_txt_btn.custom_minimum_size = Vector2(190, 46)
	_export_txt_btn.add_theme_font_size_override("font_size", 17)
	_export_txt_btn.pressed.connect(_on_export_txt_pressed)
	btn_row.add_child(_export_txt_btn)

	_export_status_lbl = Label.new()
	_export_status_lbl.text = "No export yet. Choose a format above."
	_export_status_lbl.add_theme_font_size_override("font_size", 14)
	_export_status_lbl.add_theme_color_override("font_color", COL_MUTED)
	_export_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_export_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	btn_row.add_child(_export_status_lbl)

	var refresh_hint := Label.new()
	refresh_hint.text = "Auto-refreshes every 1s"
	refresh_hint.add_theme_font_size_override("font_size", 12)
	refresh_hint.add_theme_color_override("font_color", COL_MUTED)
	refresh_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	btn_row.add_child(refresh_hint)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# POPULATE ALL SECTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _populate_all() -> void:
	# Clear vbox
	for c in _vbox.get_children():
		c.queue_free()

	var sl: Node = get_node_or_null("/root/SessionLogger")
	var sum: Dictionary = sl.get_current_summary() if sl else {}

	_add_section_header("🗓️  SESSION INFO")
	_add_session_info(sum)

	_add_section_header("🎮  GAMEPLAY SUMMARY")
	_add_gameplay_summary(sum)

	_add_section_header("🧠  SP ALGORITHM (AdaptiveDifficulty — Φ Rolling Window)")
	_add_sp_algorithm(sum)

	_add_section_header("🤝  MP ALGORITHM (CoopAdaptation — Skill Gap Co-Adaptation)")
	_add_mp_algorithm(sum)

	_add_section_header("⚡  LIVE PERFORMANCE (ISO/IEC 25010)")
	_add_live_performance(sum)

	_add_section_header("📋  SP GAME RECORDS")
	_sp_table_vbox = _add_table_placeholder("sp_games")

	_add_section_header("🎮  MP ROUND RECORDS")
	_mp_table_vbox = _add_table_placeholder("mp_rounds")

	_add_section_header("🔄  SP DIFFICULTY CHANGES")
	_diff_change_vbox = _add_table_placeholder("diff_changes")

	_add_section_header("🔥  THROTTLE EVENTS")
	_throttle_vbox = _add_table_placeholder("throttles")

	_add_section_header("✅  ISO/IEC 25010 COMPLIANCE")
	_iso_vbox = _add_table_placeholder("iso")

	_refresh_tables()

func _add_table_placeholder(tag: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.set_meta("table_tag", tag)
	_vbox.add_child(v)
	return v

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SECTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _add_section_header(text: String) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_vbox.add_child(sep)
	var lbl := Label.new()
	lbl.text = text
	if FONT_TITLE:
		lbl.add_theme_font_override("font", FONT_TITLE)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", COL_HEADER)
	_vbox.add_child(lbl)

func _add_session_info(sum: Dictionary) -> void:
	var sl: Node = get_node_or_null("/root/SessionLogger")
	var grid := _make_grid(2)
	_gkv(grid, "Session ID", str(sum.get("session_id", "?")))
	_gkv(grid, "Start Time", sl.session_start_iso if sl else "?")
	_gkv(grid, "Duration", str(sum.get("elapsed_formatted", "00:00:00")))
	var dev: String = OS.get_model_name()
	var plat: String = OS.get_name()
	_gkv(grid, "Device", "%s (%s)" % [dev, plat])
	_gkv(grid, "Processor", OS.get_processor_name())
	_gkv(grid, "CPU Cores", str(OS.get_processor_count()))
	_vbox.add_child(grid)

func _add_gameplay_summary(sum: Dictionary) -> void:
	var grid := _make_grid(4)
	_gkv(grid, "SP Games Played", str(sum.get("sp_games", 0)))
	_gkv(grid, "SP Total Score", str(sum.get("sp_total_score", 0)))
	_gkv(grid, "MP Rounds Played", str(sum.get("mp_rounds", 0)))
	_gkv(grid, "MP Total Score", str(sum.get("mp_total_score", 0)))
	_gkv(grid, "💧 Droplets Earned", str(sum.get("total_droplets", 0)))
	_gkv(grid, "Scenes Visited", "see export JSON")
	_vbox.add_child(grid)

func _add_sp_algorithm(sum: Dictionary) -> void:
	var phi: float = float(sum.get("phi", 0.0))
	var wma: float = float(sum.get("wma", 0.0))
	var cp: float = float(sum.get("cp", 0.0))
	var diff: String = str(sum.get("sp_difficulty", "N/A"))
	var grid := _make_grid(2)
	_gkv(grid, "Current Difficulty", diff, _diff_color(diff))
	_gkv(grid, "Φ (Proficiency Index)", "%.4f" % phi, _phi_color(phi))
	_gkv(grid, "WMA (Weighted Accuracy)", "%.4f" % wma)
	_gkv(grid, "CP (Consistency Penalty)", "%.4f" % cp)
	_gkv(grid, "Φ = WMA - CP", "%.4f - %.4f = %.4f" % [wma, cp, phi])
	_gkv(grid, "Difficulty Changes", str(sum.get("difficulty_changes", 0)))
	_vbox.add_child(grid)

	# Formula display
	var formula_lbl := Label.new()
	formula_lbl.text = (
		"📐 Formula: Φ = WMA - CP   |   "
		+ "Thresholds: Φ<0.5→Easy  0.5≤Φ≤0.85→Medium  Φ>0.85→Hard"
	)
	formula_lbl.add_theme_font_size_override("font_size", 13)
	formula_lbl.add_theme_color_override("font_color", COL_MUTED)
	formula_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_vbox.add_child(formula_lbl)

	_live_phi_lbl = _make_label("", 15, COL_ACCENT)
	_live_diff_lbl = _make_label("", 15, COL_ACCENT)
	_vbox.add_child(_live_phi_lbl)
	_vbox.add_child(_live_diff_lbl)

func _add_mp_algorithm(sum: Dictionary) -> void:
	var grid := _make_grid(2)
	_gkv(grid, "P1 Difficulty", str(sum.get("p1_difficulty", "N/A")),
		_diff_color(str(sum.get("p1_difficulty", ""))))
	_gkv(grid, "P2 Difficulty", str(sum.get("p2_difficulty", "N/A")),
		_diff_color(str(sum.get("p2_difficulty", ""))))
	_gkv(grid, "Coop Adjustments", str(sum.get("coop_adjustments", 0)))
	_gkv(grid, "Skill Gap Threshold", "0.15 (15%)")
	_vbox.add_child(grid)
	var note := _make_label(
		"gap > 0.15 → Asymmetric (weaker gets Easy, stronger gets Hard)\n"
		+ "gap ≤ 0.15 → Symmetric (both at same level)",
		13, COL_MUTED
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_vbox.add_child(note)

func _add_live_performance(sum: Dictionary) -> void:
	var grid := _make_grid(2)

	var fps_now: float = float(sum.get("fps_now", 0.0))
	var fps_min: float = float(sum.get("fps_min", 0.0))
	var fps_max: float = float(sum.get("fps_max", 0.0))
	var fps_avg: float = float(sum.get("fps_avg", 0.0))
	var mem_peak: float = float(sum.get("memory_peak_mb", 0.0))
	var temp_peak: float = float(sum.get("cpu_temp_peak", 0.0))
	var temp_now: float = float(sum.get("cpu_temp_now", 0.0))
	var throttles: int = int(sum.get("throttle_count", 0))
	var dropped: int = int(sum.get("dropped_frames", 0))
	var total_fr: int = int(sum.get("total_frames", 0))
	var drop_pct: float = float(sum.get("drop_rate_pct", 0.0))
	var lat_avg: float = float(sum.get("algo_latency_avg_ms", 0.0))
	var lat_max: float = float(sum.get("algo_latency_max_ms", 0.0))
	var batt: float = float(sum.get("battery_mah_per_min", 0.0))
	var eff: float = float(sum.get("efficiency_vs_dl_pct", 0.0))

	_gkv(grid, "FPS Now", "%.1f" % fps_now, _fps_color(fps_now))
	_gkv(grid, "FPS Min/Avg/Max", "%.1f / %.1f / %.1f" % [fps_min, fps_avg, fps_max],
		_fps_color(fps_min))
	_gkv(grid, "Memory Peak", "%.1f MB / 200.0 MB" % mem_peak,
		COL_GOOD if mem_peak <= 200.0 else COL_BAD)
	_gkv(grid, "CPU Temp (now / peak)", "%.1f°C / %.1f°C" % [temp_now, temp_peak],
		COL_GOOD if temp_peak <= 45.0 else COL_BAD)
	_gkv(grid, "Throttle Events", str(throttles), COL_GOOD if throttles == 0 else COL_BAD)
	_gkv(grid, "Dropped Frames", "%d / %d (%.2f%%)" % [dropped, total_fr, drop_pct],
		COL_GOOD if drop_pct < 2.0 else COL_WARN)
	_gkv(grid, "Algo Latency (avg / max)", "%.3f ms / %.3f ms" % [lat_avg, lat_max],
		COL_GOOD if lat_max <= 16.0 else COL_BAD)
	_gkv(grid, "Algo Latency Budget", "< 16.0 ms  (O(1) target)", COL_MUTED)
	_gkv(grid, "Battery Drain", "%.3f mAh/min (%s)" % [batt, str(sum.get("battery_source", "?"))],
		COL_GOOD if batt <= 10.0 else COL_WARN)
	_gkv(grid, "Efficiency vs Deep Learning", "%.1f%% less than MobileNet baseline" % eff,
		COL_GOOD if eff > 0.0 else COL_MUTED)
	_gkv(grid, "Perf Warnings", str(sum.get("perf_warnings_count", 0)))
	_vbox.add_child(grid)

	# Live monitoring row
	_live_fps_lbl = _make_label("", 14, COL_ACCENT)
	_live_temp_lbl = _make_label("", 14, COL_ACCENT)
	_live_mem_lbl = _make_label("", 14, COL_ACCENT)
	_vbox.add_child(_live_fps_lbl)
	_vbox.add_child(_live_temp_lbl)
	_vbox.add_child(_live_mem_lbl)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TABLE REFRESH (fills in dynamic tables)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _refresh_tables() -> void:
	var sl: Node = get_node_or_null("/root/SessionLogger")
	if not sl:
		return

	_fill_sp_table(sl)
	_fill_mp_table(sl)
	_fill_diff_changes(sl)
	_fill_throttles(sl)
	_fill_iso(sl)

func _fill_sp_table(sl: Node) -> void:
	if not _sp_table_vbox:
		return
	for c in _sp_table_vbox.get_children():
		c.queue_free()

	var records: Array = sl.get_sp_records()
	if records.is_empty():
		_sp_table_vbox.add_child(_make_label("No SP games played yet.", 14, COL_MUTED))
		return

	# Header row
	var hdr := _make_row_label(
		"#  |  Game                |  Score  |  Acc%  |  RT(s) |  Err |  Diff   |  Φ"
	)
	hdr.add_theme_color_override("font_color", COL_HEADER)
	_sp_table_vbox.add_child(hdr)
	_sp_table_vbox.add_child(_make_separator())

	for g in records:
		var line := "%-3d|  %-20s|  %-7d|  %-6.1f|  %-6.2f|  %-4d|  %-7s|  %.4f" % [
			int(g.get("game_num", 0)),
			str(g.get("game_name", "?")),
			int(g.get("score", 0)),
			float(g.get("accuracy_pct", 0.0)),
			float(g.get("reaction_time_s", 0.0)),
			int(g.get("mistakes", 0)),
			str(g.get("difficulty", "?")),
			float(g.get("phi_index", 0.0))
		]
		var lbl := _make_row_label(line)
		lbl.add_theme_color_override("font_color", _diff_color(str(g.get("difficulty", ""))))
		_sp_table_vbox.add_child(lbl)

func _fill_mp_table(sl: Node) -> void:
	if not _mp_table_vbox:
		return
	for c in _mp_table_vbox.get_children():
		c.queue_free()

	var records: Array = sl.get_mp_records()
	if records.is_empty():
		_mp_table_vbox.add_child(_make_label("No MP rounds played yet.", 14, COL_MUTED))
		return

	var hdr := _make_row_label(
		"Rnd|  P1 Score|  P2 Score|  Team  |  Sync  |  SkillGap|  P1 Diff|  P2 Diff"
	)
	hdr.add_theme_color_override("font_color", COL_HEADER)
	_mp_table_vbox.add_child(hdr)
	_mp_table_vbox.add_child(_make_separator())

	for r in records:
		var p1d: Dictionary = r.get("p1", {})
		var p2d: Dictionary = r.get("p2", {})
		var line := "%-3d|  %-10d|  %-10d|  %-6s|  %-6.1f|  %-10.4f|  %-9s|  %-9s" % [
			int(r.get("round_num", 0)),
			int(p1d.get("score", 0)),
			int(p2d.get("score", 0)),
			"WIN" if bool(r.get("team_success", false)) else "FAIL",
			float(r.get("sync_score", 0.0)),
			float(r.get("skill_gap", 0.0)),
			str(p1d.get("difficulty", "?")),
			str(p2d.get("difficulty", "?"))
		]
		var lbl := _make_row_label(line)
		lbl.add_theme_color_override("font_color",
			COL_GOOD if bool(r.get("team_success", false)) else COL_BAD)
		_mp_table_vbox.add_child(lbl)

func _fill_diff_changes(sl: Node) -> void:
	if not _diff_change_vbox:
		return
	for c in _diff_change_vbox.get_children():
		c.queue_free()

	var changes: Array = sl.get_sp_difficulty_changes()
	if changes.is_empty():
		_diff_change_vbox.add_child(
			_make_label("No difficulty changes yet (need " +
				str(AdaptiveDifficulty.min_games_before_adaptation if AdaptiveDifficulty else 3) +
				"+ games in window).", 14, COL_MUTED)
		)
		return

	var hdr := _make_row_label("Time(s)|  From    |  To      |  Φ     |  WMA   |  CP   |  Reason")
	hdr.add_theme_color_override("font_color", COL_HEADER)
	_diff_change_vbox.add_child(hdr)
	_diff_change_vbox.add_child(_make_separator())

	for d in changes:
		var line := "%-7.1f|  %-8s|  %-8s|  %-6.4f|  %-6.4f|  %-5.4f|  %s" % [
			float(d.get("elapsed_sec", 0.0)),
			str(d.get("from_difficulty", "?")),
			str(d.get("to_difficulty", "?")),
			float(d.get("phi", 0.0)),
			float(d.get("wma", 0.0)),
			float(d.get("consistency_penalty", 0.0)),
			str(d.get("reason", "?"))
		]
		var lbl := _make_row_label(line)
		lbl.add_theme_color_override("font_color", _diff_color(str(d.get("to_difficulty", ""))))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_diff_change_vbox.add_child(lbl)

func _fill_throttles(sl: Node) -> void:
	if not _throttle_vbox:
		return
	for c in _throttle_vbox.get_children():
		c.queue_free()

	var events: Array = sl.get_throttle_events()
	if events.is_empty():
		_throttle_vbox.add_child(
			_make_label("✅ No thermal throttle events recorded.", 14, COL_GOOD))
		return

	var hdr := _make_row_label("Time(s)|  Clock Ratio|  CPU Temp|  FPS at Event")
	hdr.add_theme_color_override("font_color", COL_HEADER)
	_throttle_vbox.add_child(hdr)
	_throttle_vbox.add_child(_make_separator())

	for e in events:
		var line := "%-7.1f|  %-12.1f%%|  %-9.1f°C|  %.1f fps" % [
			float(e.get("elapsed_sec", 0.0)),
			float(e.get("clock_ratio", 0.0)) * 100.0,
			float(e.get("cpu_temp_c", 0.0)),
			float(e.get("fps", 0.0))
		]
		var lbl := _make_row_label(line)
		lbl.add_theme_color_override("font_color", COL_BAD)
		_throttle_vbox.add_child(lbl)

func _fill_iso(sl: Node) -> void:
	if not _iso_vbox:
		return
	for c in _iso_vbox.get_children():
		c.queue_free()

	var sum: Dictionary = sl.get_current_summary()
	var checks := [
		["FPS ≥ 30 (min observed)", float(sum.get("fps_min", 0.0)) >= 30.0,
			"%.1f fps" % float(sum.get("fps_min", 0.0))],
		["FPS ≥ 60 avg (target)", float(sum.get("fps_avg", 0.0)) >= 60.0,
			"%.1f fps avg" % float(sum.get("fps_avg", 0.0))],
		["Memory ≤ 200 MB", float(sum.get("memory_peak_mb", 0.0)) <= 200.0,
			"%.1f MB peak" % float(sum.get("memory_peak_mb", 0.0))],
		["CPU Temp ≤ 45°C", float(sum.get("cpu_temp_peak", 0.0)) <= 45.0,
			"%.1f°C peak" % float(sum.get("cpu_temp_peak", 0.0))],
		["No Throttle Events", int(sum.get("throttle_count", 0)) == 0,
			"%d events" % int(sum.get("throttle_count", 0))],
		["Algo Latency < 16 ms", float(sum.get("algo_latency_max_ms", 0.0)) < 16.0,
			"%.3f ms max" % float(sum.get("algo_latency_max_ms", 0.0))],
		["Frame Drop Rate < 2%", float(sum.get("drop_rate_pct", 0.0)) < 2.0,
			"%.2f%% drop" % float(sum.get("drop_rate_pct", 0.0))],
	]

	var pass_count := 0
	for check in checks:
		var label_text: String = check[0]
		var passed: bool = bool(check[1])
		var value: String = str(check[2])
		if passed:
			pass_count += 1
		var icon := "✅" if passed else "❌"
		var col: Color = COL_GOOD if passed else COL_BAD
		var lbl := _make_label("%s  %s  —  %s" % [icon, label_text, value], 15, col)
		_iso_vbox.add_child(lbl)

	_iso_vbox.add_child(_make_separator())
	var overall := pass_count == checks.size()
	var summary_lbl := _make_label(
		"%s  ISO/IEC 25010: %d/%d checks passed" % [
			"✅ PASS" if overall else "❌ FAIL",
			pass_count, checks.size()
		],
		18,
		COL_GOOD if overall else COL_BAD
	)
	_iso_vbox.add_child(summary_lbl)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LIVE REFRESH (every 1s)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_refresh_tick() -> void:
	var sl: Node = get_node_or_null("/root/SessionLogger")
	if not sl:
		return
	var sum: Dictionary = sl.get_current_summary()

	# Live labels
	if is_instance_valid(_live_fps_lbl):
		_live_fps_lbl.text = "⏱ LIVE — FPS: %.1f  |  Session: %s" % [
			float(sum.get("fps_now", 0.0)),
			str(sum.get("elapsed_formatted", "?"))
		]
	if is_instance_valid(_live_temp_lbl):
		var t: float = float(sum.get("cpu_temp_now", 0.0))
		var tp: float = float(sum.get("cpu_temp_peak", 0.0))
		_live_temp_lbl.text = "🌡 LIVE — CPU Temp: %.1f°C  |  Peak: %.1f°C  |  Throttles: %d" % [
			t, tp, int(sum.get("throttle_count", 0))
		]
		_live_temp_lbl.add_theme_color_override("font_color",
			COL_GOOD if t <= 40.0 else (COL_WARN if t <= 44.0 else COL_BAD))
	if is_instance_valid(_live_mem_lbl):
		var m: float = float(sum.get("memory_now_mb", 0.0))
		_live_mem_lbl.text = "💾 LIVE — Memory: %.1f MB  |  Peak: %.1f MB" % [
			m, float(sum.get("memory_peak_mb", 0.0))
		]
		_live_mem_lbl.add_theme_color_override("font_color",
			COL_GOOD if m <= 160.0 else (COL_WARN if m <= 199.0 else COL_BAD))
	if is_instance_valid(_live_phi_lbl):
		var phi: float = float(sum.get("phi", 0.0))
		_live_phi_lbl.text = "🧠 LIVE — Φ: %.4f  |  Diff: %s  |  Changes: %d" % [
			phi, str(sum.get("sp_difficulty", "N/A")), int(sum.get("difficulty_changes", 0))
		]
		_live_phi_lbl.add_theme_color_override("font_color", _phi_color(phi))
	if is_instance_valid(_live_diff_lbl):
		_live_diff_lbl.text = "🤝 LIVE — P1: %s  |  P2: %s  |  Coop Adjustments: %d" % [
			str(sum.get("p1_difficulty", "N/A")),
			str(sum.get("p2_difficulty", "N/A")),
			int(sum.get("coop_adjustments", 0))
		]

	# Refresh tables (SP + MP grow during gameplay)
	_refresh_tables()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ACTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _on_change_dir_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	var new_dir: String = _dir_input.text.strip_edges()
	if new_dir.is_empty():
		_export_status_lbl.text = "⚠️ Path cannot be empty — use ↺ Reset to restore default."
		_export_status_lbl.add_theme_color_override("font_color", COL_WARN)
		return
	var sl: Node = get_node_or_null("/root/SessionLogger")
	if sl and sl.has_method("set_export_dir"):
		sl.set_export_dir(new_dir)
		_dir_input.text = sl.export_dir  # reflect normalised path (trailing /)
		_export_status_lbl.text = "✅ Export dir set to: %s" % sl.export_dir
		_export_status_lbl.add_theme_color_override("font_color", COL_GOOD)
	else:
		_export_status_lbl.text = "❌ SessionLogger not found"
		_export_status_lbl.add_theme_color_override("font_color", COL_BAD)

func _on_export_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	_export_btn.disabled = true
	_export_status_lbl.text = "Exporting JSON…"

	var sl: Node = get_node_or_null("/root/SessionLogger")
	if sl:
		var path: String = sl.export_session()
		if path.length() > 0:
			_export_status_lbl.text = "✅ JSON saved: %s" % path
			_export_status_lbl.add_theme_color_override("font_color", COL_GOOD)
		else:
			_export_status_lbl.text = "❌ Export failed — check console"
			_export_status_lbl.add_theme_color_override("font_color", COL_BAD)
	else:
		_export_status_lbl.text = "❌ SessionLogger not found"
		_export_status_lbl.add_theme_color_override("font_color", COL_BAD)

	_export_btn.disabled = false

func _on_export_txt_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	_export_txt_btn.disabled = true
	_export_status_lbl.text = "Exporting TXT…"

	var sl: Node = get_node_or_null("/root/SessionLogger")
	if sl and sl.has_method("export_session_txt"):
		var path: String = sl.export_session_txt()
		if path.length() > 0:
			_export_status_lbl.text = "✅ TXT saved: %s" % path
			_export_status_lbl.add_theme_color_override("font_color", COL_GOOD)
		else:
			_export_status_lbl.text = "❌ TXT export failed — check console"
			_export_status_lbl.add_theme_color_override("font_color", COL_BAD)
	else:
		_export_status_lbl.text = "❌ SessionLogger.export_session_txt() not available"
		_export_status_lbl.add_theme_color_override("font_color", COL_BAD)

	_export_txt_btn.disabled = false

func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/Settings.tscn")

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# WIDGET HELPERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _make_grid(cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols * 2
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 6)
	return g

func _gkv(grid: GridContainer, key: String, value: String, val_color: Color = COL_TEXT) -> void:
	var k := Label.new()
	k.text = key + ":"
	if FONT_BODY:
		k.add_theme_font_override("font", FONT_BODY)
	k.add_theme_font_size_override("font_size", 15)
	k.add_theme_color_override("font_color", COL_MUTED)
	grid.add_child(k)
	var v := Label.new()
	v.text = value
	if FONT_BODY:
		v.add_theme_font_override("font", FONT_BODY)
	v.add_theme_font_size_override("font_size", 15)
	v.add_theme_color_override("font_color", val_color)
	grid.add_child(v)

func _make_label(text: String, font_sz: int = 14, col: Color = COL_TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if FONT_BODY:
		lbl.add_theme_font_override("font", FONT_BODY)
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	return lbl

func _make_row_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", COL_TEXT)
	return lbl

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	sep.modulate = Color(1.0, 1.0, 1.0, 0.15)
	return sep

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COLOR HELPERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _fps_color(fps: float) -> Color:
	if fps >= 60.0:
		return COL_GOOD
	if fps >= 30.0:
		return COL_WARN
	return COL_BAD

func _diff_color(diff: String) -> Color:
	match diff:
		"Easy": return COL_GOOD
		"Medium": return COL_WARN
		"Hard": return COL_BAD
		_: return COL_TEXT

func _phi_color(phi: float) -> Color:
	if phi < 0.5:
		return COL_BAD
	if phi > 0.85:
		return COL_GOOD
	return COL_WARN
