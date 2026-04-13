extends Control

## ═══════════════════════════════════════════════════════════════════
## RESEARCH DASHBOARD - THESIS METRICS AGGREGATOR
## ═══════════════════════════════════════════════════════════════════
## One-stop panel for panelists to see ALL thesis metrics at a glance
## and export comprehensive JSON for the research paper.
##
## Aggregates data from:
## - AdaptiveDifficulty (Obj 1: Rolling Window, Φ, WMA, CP)
## - PerformanceProfiler (Obj 1: FPS, latency, thermal, battery)
## - GCounter (Obj 3: CRDT properties, sync state)
## - NetworkFaultSimulator (Obj 3: convergence under packet loss)
## ═══════════════════════════════════════════════════════════════════

# Autoload reference (resolved at runtime to avoid static analysis errors)
@onready var _net_fault_sim = get_node_or_null("/root/NetworkFaultSimulator")

# UI references
var metrics_label: RichTextLabel
var export_status_label: Label

func _ready() -> void:
	_build_ui()
	_refresh_metrics()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.10, 0.10, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_margin = MarginContainer.new()
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_top", 20)
	main_margin.add_theme_constant_override("margin_bottom", 20)
	main_margin.add_theme_constant_override("margin_left", 20)
	main_margin.add_theme_constant_override("margin_right", 20)
	add_child(main_margin)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)

	# Header
	var title = Label.new()
	title.text = "📋 RESEARCH DATA DASHBOARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "WaterWise — ISO/IEC 25010 Thesis Metrics Aggregator"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.modulate = Color(0.6, 0.6, 0.7)
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	# Metrics display
	metrics_label = RichTextLabel.new()
	metrics_label.bbcode_enabled = true
	metrics_label.fit_content = true
	metrics_label.custom_minimum_size.y = 500
	metrics_label.selection_enabled = true
	vbox.add_child(metrics_label)

	# Action buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_hbox)

	var refresh_btn = _make_btn("🔄 Refresh", Color(0.3, 0.5, 0.7))
	refresh_btn.pressed.connect(_refresh_metrics)
	btn_hbox.add_child(refresh_btn)

	var export_btn = _make_btn("💾 Export JSON", Color(0.2, 0.6, 0.3))
	export_btn.pressed.connect(_export_json)
	btn_hbox.add_child(export_btn)

	var export_csv_btn = _make_btn("📊 Export CSV", Color(0.5, 0.4, 0.2))
	export_csv_btn.pressed.connect(_export_csv)
	btn_hbox.add_child(export_csv_btn)

	export_status_label = Label.new()
	export_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	export_status_label.add_theme_font_size_override("font_size", 14)
	export_status_label.modulate = Color(0.5, 0.5, 0.5)
	vbox.add_child(export_status_label)

	vbox.add_child(HSeparator.new())

	# Navigation
	var nav = HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 15)
	vbox.add_child(nav)

	var back_btn = _make_btn("← Back to Menu", Color(0.4, 0.4, 0.4))
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn"))
	nav.add_child(back_btn)

	var algo_btn = _make_btn("🔬 Φ Demo", Color(0.2, 0.4, 0.8))
	algo_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/AlgorithmDemo.tscn"))
	nav.add_child(algo_btn)

	var crdt_btn = _make_btn("📊 G-Counter Demo", Color(0.7, 0.3, 0.1))
	crdt_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/GCounterDemo.tscn"))
	nav.add_child(crdt_btn)

func _make_btn(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 50)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = color.darkened(0.3)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style)
	var hover = style.duplicate()
	hover.bg_color = color
	btn.add_theme_stylebox_override("hover", hover)
	return btn

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# METRICS AGGREGATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _refresh_metrics() -> void:
	var text = ""

	# ── OBJECTIVE 1: PERFORMANCE EFFICIENCY ──
	text += "[b][color=cyan]═══ OBJECTIVE 1: PERFORMANCE EFFICIENCY (ISO 25010) ═══[/color][/b]\n\n"

	if PerformanceProfiler:
		var report = PerformanceProfiler.export_session_report()

		var fps = report.get("fps", {})
		var ico_fps = _ico(fps.get("meets_target", false))
		text += "%s [b]FPS:[/b] avg %.0f / min %.0f / target %d\n" % [
			ico_fps, fps.get("average", 0), fps.get("minimum", 999), fps.get("target", 60)]

		var ft = report.get("frame_timing", {})
		var ico_ft = _ico(ft.get("meets_budget", false))
		text += "%s [b]Frame Budget:[/b] dropped %d (%.1f%%) budget %.1fms\n" % [
			ico_ft, ft.get("dropped_frames", 0), ft.get("drop_rate_percent", 0), ft.get("budget_ms", 16.67)]

		var mem = report.get("memory", {})
		var ico_mem = _ico(mem.get("meets_limit", false))
		text += "%s [b]Memory:[/b] peak %.0fMB / limit %.0fMB\n" % [
			ico_mem, mem.get("peak_mb", 0), mem.get("limit_mb", 200)]

		var algo = report.get("algorithm_latency", {})
		var ico_algo = _ico(algo.get("meets_budget", true))
		text += "%s [b]Algorithm Latency:[/b] avg %.2fms / max %.2fms / budget %.0fms\n" % [
			ico_algo, algo.get("average_ms", 0), algo.get("maximum_ms", 0), algo.get("budget_ms", 16)]

		var therm = report.get("thermal", {})
		var ico_therm = _ico(therm.get("meets_threshold", true))
		text += "%s [b]CPU Temp:[/b] peak %.1f°C / threshold %.0f°C\n" % [
			ico_therm, therm.get("cpu_temp_peak", 0), therm.get("threshold_c", 45)]

		var ico_clk = _ico(therm.get("s_clk_stable", true))
		text += "%s [b]Clock Stability:[/b] ratio %.0f%% / throttle events: %d\n" % [
			ico_clk, therm.get("clock_speed_ratio", 1.0) * 100.0, therm.get("throttle_events", 0)]

		var iso = report.get("iso_25010_pass", false)
		text += "\n[b]ISO 25010 Overall:[/b] %s\n" % ("✅ PASS" if iso else "❌ FAIL")
	else:
		text += "⚠️ PerformanceProfiler not loaded\n"

	# ── OBJECTIVE 2: ENERGY EFFICIENCY ──
	text += "\n[b][color=yellow]═══ OBJECTIVE 2: ENERGY EFFICIENCY ═══[/color][/b]\n\n"

	if PerformanceProfiler:
		var report = PerformanceProfiler.export_session_report()
		var batt = report.get("battery", {})
		var ico_batt = _ico(batt.get("meets_limit", true))
		text += "%s [b]Battery Drain:[/b] %.2f mAh / limit %.0f mAh (5min)\n" % [
			ico_batt, batt.get("estimated_mah", 0), batt.get("limit_mah_per_5min", 10)]
		text += "   [b]Drain Rate:[/b] %.2f mAh/min\n" % batt.get("drain_per_min_mah", 0)
		text += "   [b]Source:[/b] %s\n" % batt.get("measurement_source", "unknown")

		var dl = report.get("dl_baseline_comparison", {})
		text += "\n[b]vs Deep Learning Baseline (MobileNet TF Lite):[/b]\n"
		text += "   Rule-Based: %.2f mAh/min\n" % dl.get("rule_based_mah_min", 0)
		text += "   DL Baseline: %.1f mAh/min\n" % dl.get("dl_baseline_mah_min", 10)
		text += "   [b]Savings: %.0f%%[/b] %s\n" % [
			dl.get("reduction_pct", 0),
			_ico(dl.get("is_more_efficient", true))]
	else:
		text += "⚠️ PerformanceProfiler not loaded\n"

	# ── OBJECTIVE 3: G-COUNTER CRDT RELIABILITY ──
	text += "\n[b][color=lime]═══ OBJECTIVE 3: G-COUNTER CRDT RELIABILITY ═══[/color][/b]\n\n"

	if GCounter:
		var spec = GCounter.get_output_specification()
		text += "[b]Current State:[/b]\n"
		text += "   g_counter: %s\n" % str(spec.get("g_counter", {}))
		text += "   GlobalScore: %d\n" % spec.get("GlobalScore", 0)
		text += "   is_synchronized: %s\n" % str(spec.get("is_synchronized", false))
		text += "   last_sync_timestamp: %d ms\n" % spec.get("last_sync_timestamp", 0)
		text += "   network_latency: %d ms\n" % spec.get("network_latency", 0)

		var props = GCounter.verify_all_properties()
		text += "\n[b]Mathematical Property Verification:[/b]\n"
		text += "   %s Commutativity: merge(A,B) = merge(B,A)\n" % _ico(props.get("commutativity", false))
		text += "   %s Associativity: merge(merge(A,B),C) = merge(A,merge(B,C))\n" % _ico(props.get("associativity", false))
		text += "   %s Idempotency: merge(A,A) = A\n" % _ico(props.get("idempotency", false))
	else:
		text += "⚠️ GCounter not loaded\n"

	if _net_fault_sim and _net_fault_sim.sweep_results.size() > 0:
		text += "\n[b]Packet Loss Sweep Results:[/b]\n"
		text += "   Loss%%  | Conv%%  | Avg ms  | Pass?\n"
		for r in _net_fault_sim.sweep_results:
			text += "   %5.0f%%  | %5.0f%%  | %6.1f  | %s\n" % [
				r["loss_rate_pct"], r["convergence_rate_pct"],
				r["avg_convergence_ms"], _ico(r["meets_target"])]
	else:
		text += "\n⚠️ No packet loss sweep data yet (run from G-Counter Demo)\n"

	# ── ADAPTIVE DIFFICULTY ALGORITHM ──
	text += "\n[b][color=orange]═══ ADAPTIVE DIFFICULTY ALGORITHM ═══[/color][/b]\n\n"

	if AdaptiveDifficulty:
		var status = AdaptiveDifficulty.get_algorithm_status()
		text += "[b]Current Difficulty:[/b] %s\n" % status.get("current_difficulty", "N/A")
		text += "[b]Proficiency Index (Φ):[/b] %.4f\n" % status.get("proficiency_index", 0)
		text += "[b]WMA:[/b] %.4f\n" % status.get("wma", 0)
		text += "[b]Consistency Penalty:[/b] %.4f\n" % status.get("consistency_penalty", 0)
		text += "[b]Window:[/b] %d / %d games\n" % [
			status.get("window_size", 0), status.get("max_window_size", 5)]
		text += "[b]Total Games:[/b] %d\n" % status.get("total_games", 0)
		text += "[b]Difficulty Changes:[/b] %d\n" % status.get("difficulty_changes", 0)
	else:
		text += "⚠️ AdaptiveDifficulty not loaded\n"

	metrics_label.text = text

func _ico(passed: bool) -> String:
	return "✅" if passed else "❌"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DATA EXPORT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _build_export_data() -> Dictionary:
	var data = {
		"export_timestamp": Time.get_datetime_string_from_system(),
		"project": "WaterWise",
		"institution": "Cavite State University, CEIT",
		"authors": ["Ralph Laurence J. Cruto", "Raeven M. Espineli", "Elroni F. Quiñones"],
	}

	# Objective 1 + 2: Performance Profiler
	if PerformanceProfiler:
		data["performance_profiler"] = PerformanceProfiler.export_session_report()

	# Objective 3: G-Counter
	if GCounter:
		data["g_counter"] = GCounter.export_session_data()
		data["g_counter"]["output_specification"] = GCounter.get_output_specification()

	# Objective 3: Network Fault Simulation
	if _net_fault_sim:
		data["network_fault_simulation"] = _net_fault_sim.get_sweep_summary()

	# Adaptive Difficulty
	if AdaptiveDifficulty:
		data["adaptive_difficulty"] = AdaptiveDifficulty.get_algorithm_status()

	return data

func _export_json() -> void:
	var data = _build_export_data()
	var json_str = JSON.stringify(data, "\t")
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path = "user://waterwise_research_%s.json" % timestamp

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		var real_path = ProjectSettings.globalize_path(path)
		export_status_label.text = "✅ Exported to: %s" % real_path
		export_status_label.modulate = Color(0.3, 0.9, 0.3)
		print("📋 Research data exported: %s" % real_path)
	else:
		export_status_label.text = "❌ Failed to write file"
		export_status_label.modulate = Color(0.9, 0.3, 0.3)

func _export_csv() -> void:
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path = "user://waterwise_metrics_%s.csv" % timestamp

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		export_status_label.text = "❌ Failed to write CSV"
		export_status_label.modulate = Color(0.9, 0.3, 0.3)
		return

	# Header
	file.store_line("Metric,Value,Threshold,Pass")

	# Performance metrics
	if PerformanceProfiler:
		var r = PerformanceProfiler.export_session_report()
		var fps = r.get("fps", {})
		file.store_line("FPS_avg,%.1f,%d,%s" % [fps.get("average", 0), fps.get("target", 60), str(fps.get("meets_target", false))])
		file.store_line("FPS_min,%.1f,%d,%s" % [fps.get("minimum", 0), 30, str(fps.get("minimum", 0) >= 30)])

		var ft = r.get("frame_timing", {})
		file.store_line("Dropped_frames,%d,<5%%,%s" % [ft.get("dropped_frames", 0), str(ft.get("meets_budget", false))])

		var mem = r.get("memory", {})
		file.store_line("Memory_peak_MB,%.1f,%.0f,%s" % [mem.get("peak_mb", 0), mem.get("limit_mb", 200), str(mem.get("meets_limit", false))])

		var algo = r.get("algorithm_latency", {})
		file.store_line("Algo_latency_avg_ms,%.3f,%.0f,%s" % [algo.get("average_ms", 0), algo.get("budget_ms", 16), str(algo.get("meets_budget", true))])
		file.store_line("Algo_latency_max_ms,%.3f,%.0f,%s" % [algo.get("maximum_ms", 0), algo.get("budget_ms", 16), str(algo.get("meets_budget", true))])

		var therm = r.get("thermal", {})
		file.store_line("CPU_temp_peak_C,%.1f,%.0f,%s" % [therm.get("cpu_temp_peak", 0), therm.get("threshold_c", 45), str(therm.get("meets_threshold", true))])
		file.store_line("Throttle_events,%d,0,%s" % [therm.get("throttle_events", 0), str(therm.get("s_clk_stable", true))])

		var batt = r.get("battery", {})
		file.store_line("Battery_mAh,%.2f,%.0f,%s" % [batt.get("estimated_mah", 0), batt.get("limit_mah_per_5min", 10), str(batt.get("meets_limit", true))])
		file.store_line("Battery_source,%s,n/a,n/a" % batt.get("measurement_source", "unknown"))

	# G-Counter properties
	if GCounter:
		var props = GCounter.verify_all_properties()
		file.store_line("CRDT_commutativity,%s,true,%s" % [str(props.get("commutativity", false)), str(props.get("commutativity", false))])
		file.store_line("CRDT_associativity,%s,true,%s" % [str(props.get("associativity", false)), str(props.get("associativity", false))])
		file.store_line("CRDT_idempotency,%s,true,%s" % [str(props.get("idempotency", false)), str(props.get("idempotency", false))])

	# Sweep results
	if _net_fault_sim:
		for r in _net_fault_sim.sweep_results:
			file.store_line("Convergence_%d%%_loss,%.1f,%.0f,%s" % [
				int(r["loss_rate_pct"]), r["avg_convergence_ms"],
				200.0, str(r["meets_target"])])

	file.close()
	var real_path = ProjectSettings.globalize_path(path)
	export_status_label.text = "✅ CSV exported to: %s" % real_path
	export_status_label.modulate = Color(0.3, 0.9, 0.3)
	print("📊 CSV exported: %s" % real_path)
