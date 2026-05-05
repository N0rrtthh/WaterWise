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
var _export_status_lbl: Label
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
var _temp_curve_vbox: VBoxContainer
var _mem_trend_vbox: VBoxContainer
var _dl_compare_vbox: VBoxContainer

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

	# Export bar at bottom
	var export_bar := PanelContainer.new()
	export_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	export_bar.offset_top = -80.0
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

	var ebar_hbox := HBoxContainer.new()
	ebar_hbox.add_theme_constant_override("separation", 16)
	export_bar.add_child(ebar_hbox)

	_export_btn = Button.new()
	_export_btn.text = "💾 EXPORT SESSION LOG (JSON)"
	_export_btn.custom_minimum_size = Vector2(280, 50)
	_export_btn.add_theme_font_size_override("font_size", 18)
	_export_btn.pressed.connect(_on_export_pressed)
	ebar_hbox.add_child(_export_btn)

	_export_status_lbl = Label.new()
	_export_status_lbl.text = "No export yet. Press EXPORT to save."
	_export_status_lbl.add_theme_font_size_override("font_size", 14)
	_export_status_lbl.add_theme_color_override("font_color", COL_MUTED)
	_export_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_export_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	ebar_hbox.add_child(_export_status_lbl)

	# Refresh hint
	var refresh_hint := Label.new()
	refresh_hint.text = "Auto-refreshes every 1s"
	refresh_hint.add_theme_font_size_override("font_size", 12)
	refresh_hint.add_theme_color_override("font_color", COL_MUTED)
	ebar_hbox.add_child(refresh_hint)

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

	_add_section_header("🌡  TEMPERATURE HEAT CURVE (1-second samples)")
	_temp_curve_vbox = _add_table_placeholder("temp_curve")

	_add_section_header("💾  MEMORY TREND & LEAK DETECTION")
	_mem_trend_vbox = _add_table_placeholder("mem_trend")

	_add_section_header("📊  FPS STABILITY ANALYSIS")
	_add_fps_stability(sum)

	_add_section_header("🏆  DL BASELINE COMPARISON (Rule-Based vs MobileNet on Cortex-A53)")
	_dl_compare_vbox = _add_table_placeholder("dl_compare")

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
	var fps_std: float = float(sum.get("fps_std_dev", 0.0))
	_gkv(grid, "FPS Std Dev (stability)",
		"%.2f fps" % fps_std,
		COL_GOOD if fps_std <= 2.0 else (COL_WARN if fps_std <= 5.0 else COL_BAD))
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
	_fill_temp_curve(sl)
	_fill_memory_trend(sl)
	_fill_dl_comparison(sl)

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
		var p1d: Dictionary = r.get("p1", {}) as Dictionary
		var p2d: Dictionary = r.get("p2", {}) as Dictionary
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

func _on_export_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	_export_btn.disabled = true
	_export_status_lbl.text = "Exporting…"

	var sl: Node = get_node_or_null("/root/SessionLogger")
	if sl:
		var path: String = sl.export_session()
		if path.length() > 0:
			_export_status_lbl.text = "✅ Saved: %s" % path
			_export_status_lbl.add_theme_color_override("font_color", COL_GOOD)
		else:
			_export_status_lbl.text = "❌ Export failed — check console"
			_export_status_lbl.add_theme_color_override("font_color", COL_BAD)
	else:
		_export_status_lbl.text = "❌ SessionLogger not found"
		_export_status_lbl.add_theme_color_override("font_color", COL_BAD)

	_export_btn.disabled = false

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

func _make_label(text: String, size: int = 14, col: Color = COL_TEXT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if FONT_BODY:
		lbl.add_theme_font_override("font", FONT_BODY)
	lbl.add_theme_font_size_override("font_size", size)
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
# THESIS DEFENCE DATA SECTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _fps_stability_label(std_dev: float) -> String:
	if std_dev <= 2.0:
		return "EXCELLENT"
	if std_dev <= 5.0:
		return "ACCEPTABLE"
	return "UNSTABLE"

func _add_fps_stability(sum: Dictionary) -> void:
	var std_dev: float = float(sum.get("fps_std_dev", 0.0))
	var fps_min_v: float = float(sum.get("fps_min", 0.0))
	var fps_avg_v: float = float(sum.get("fps_avg", 0.0))
	var fps_max_v: float = float(sum.get("fps_max", 0.0))
	var col: Color = COL_GOOD if std_dev <= 2.0 else (COL_WARN if std_dev <= 5.0 else COL_BAD)
	var grid := _make_grid(2)
	_gkv(grid, "FPS Std Dev", "%.2f fps" % std_dev, col)
	_gkv(grid, "Stability Rating", _fps_stability_label(std_dev), col)
	_gkv(grid, "Min / Avg / Max", "%.1f / %.1f / %.1f fps" % [fps_min_v, fps_avg_v, fps_max_v],
		_fps_color(fps_min_v))
	_gkv(grid, "ISO Min Target", "30 fps  (mandatory floor)", COL_MUTED)
	_gkv(grid, "ISO Avg Target", "60 fps  (thesis target)", COL_MUTED)
	_gkv(grid, "Interpretation",
		"Lower std dev = smoother gameplay = algorithm not stressing GPU",
		COL_MUTED)
	_vbox.add_child(grid)

func _fill_temp_curve(sl: Node) -> void:
	if not _temp_curve_vbox:
		return
	for c in _temp_curve_vbox.get_children():
		c.queue_free()

	var samples: Array = sl.get_temp_curve() if sl.has_method("get_temp_curve") else []
	if samples.is_empty():
		var src := PerformanceProfiler.get_thermal_source() if PerformanceProfiler else "unknown"
		var msg: String
		if src == "sensor":
			msg = "No samples yet — collecting (updates every second)."
		else:
			msg = "Sensor unavailable (%s). Data will appear on Android with /sys/class/thermal access." % src
		_temp_curve_vbox.add_child(_make_label(msg, 14, COL_MUTED))
		return

	var hdr := _make_row_label("Time(min) |  Temp (°C)  |  Status")
	hdr.add_theme_color_override("font_color", COL_HEADER)
	_temp_curve_vbox.add_child(hdr)
	_temp_curve_vbox.add_child(_make_separator())

	for pt in samples:
		var t: float = float(pt.get("avg_temp_c", 0.0))
		var status: String
		var col: Color
		if t <= 0.0:
			status = "N/A"
			col = COL_MUTED
		elif t <= 38.0:
			status = "COOL"
			col = COL_GOOD
		elif t <= 44.0:
			status = "WARM"
			col = COL_WARN
		else:
			status = "HOT (may throttle)"
			col = COL_BAD
		var line := "%-9.1f |  %-10.1f |  %s" % [
			float(pt.get("elapsed_min", 0.0)), t, status
		]
		var lbl := _make_row_label(line)
		lbl.add_theme_color_override("font_color", col)
		_temp_curve_vbox.add_child(lbl)

	var peak: float = float(PerformanceProfiler.cpu_temp_peak if PerformanceProfiler else 0.0)
	_temp_curve_vbox.add_child(_make_separator())
	_temp_curve_vbox.add_child(_make_label(
		"Peak: %.1f°C  |  Threshold: 45.0°C  |  %s" % [
			peak, "✅ PASS" if peak <= 45.0 else "❌ FAIL"
		], 15,
		COL_GOOD if peak <= 45.0 else COL_BAD
	))

func _fill_memory_trend(sl: Node) -> void:
	if not _mem_trend_vbox:
		return
	for c in _mem_trend_vbox.get_children():
		c.queue_free()

	var points: Array = sl.get_memory_trend() if sl.has_method("get_memory_trend") else []
	if points.is_empty():
		_mem_trend_vbox.add_child(
			_make_label("No memory trend data yet — collecting (updates every 5s).", 14, COL_MUTED))
		return

	var hdr := _make_row_label("Time(min) |  RAM (MB)  |  Delta   |  Status")
	hdr.add_theme_color_override("font_color", COL_HEADER)
	_mem_trend_vbox.add_child(hdr)
	_mem_trend_vbox.add_child(_make_separator())

	var prev_mb := -1.0
	var leak_flag := false
	for pt in points:
		var mb: float = float(pt.get("memory_mb", 0.0))
		var delta_str := "--"
		var col: Color = COL_GOOD if mb <= 150.0 else (COL_WARN if mb <= 199.0 else COL_BAD)
		if prev_mb >= 0.0:
			var delta := mb - prev_mb
			delta_str = "%+.1f MB" % delta
			if delta > 5.0:
				col = COL_WARN
				leak_flag = true
		var line := "%-9.1f |  %-10.1f |  %-8s |  %s" % [
			float(pt.get("elapsed_min", 0.0)), mb, delta_str,
			"OK" if mb <= 150.0 else ("WARNING" if mb <= 199.0 else "OVER BUDGET")
		]
		var lbl := _make_row_label(line)
		lbl.add_theme_color_override("font_color", col)
		_mem_trend_vbox.add_child(lbl)
		prev_mb = mb

	_mem_trend_vbox.add_child(_make_separator())
	var peak: float = float(PerformanceProfiler.memory_peak_mb if PerformanceProfiler else 0.0)
	var leak_str := " | ⚠ Memory growing — possible leak" if leak_flag else " | No leak detected"
	_mem_trend_vbox.add_child(_make_label(
		"Peak: %.1f MB / 200.0 MB  |  %s%s" % [
			peak,
			"✅ PASS" if peak <= 200.0 else "❌ FAIL",
			leak_str
		], 15,
		COL_GOOD if peak <= 200.0 and not leak_flag else COL_WARN
	))

func _fill_dl_comparison(sl: Node) -> void:
	if not _dl_compare_vbox:
		return
	for c in _dl_compare_vbox.get_children():
		c.queue_free()

	var rows: Array = sl.get_dl_comparison() if sl.has_method("get_dl_comparison") else []
	if rows.is_empty():
		_dl_compare_vbox.add_child(
			_make_label("Data not available yet — play at least one game.", 14, COL_MUTED))
		return

	for i in rows.size():
		var row: Array = rows[i]
		if row.size() < 4:
			continue
		var line := "%-22s|  %-28s|  %-24s|  %s" % [
			str(row[0]), str(row[1]), str(row[2]), str(row[3])
		]
		var lbl := _make_row_label(line)
		if i == 0:
			# Header row
			lbl.add_theme_color_override("font_color", COL_HEADER)
			_dl_compare_vbox.add_child(lbl)
			_dl_compare_vbox.add_child(_make_separator())
		else:
			lbl.add_theme_color_override("font_color", COL_GOOD)
			_dl_compare_vbox.add_child(lbl)

	_dl_compare_vbox.add_child(_make_separator())
	var note := _make_label(
		"MobileNet baseline = TFLite MobileNetV1 on Cortex-A53 @ ~1.4GHz (literature values).\n"
		+ "Battery data requires real Android device with /sys/class/power_supply access.",
		12, COL_MUTED
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dl_compare_vbox.add_child(note)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# COLOR HELPERS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _fps_color(fps: float) -> Color:
	if fps >= 60.0:
		return COL_GOOD
	elif fps >= 30.0:
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
	elif phi > 0.85:
		return COL_GOOD
	return COL_WARN
