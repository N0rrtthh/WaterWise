extends Control

## ═══════════════════════════════════════════════════════════════════
## G-COUNTER TEST - Visual Demonstration
## ═══════════════════════════════════════════════════════════════════
## Interactive demonstration of G-Counter algorithm for multiplayer
## scoring: GlobalScore = Σ(PlayerInput_i)
## ═══════════════════════════════════════════════════════════════════

var p1_score: int = 0
var p2_score: int = 0
var quota: int = 20

var p1_label: Label = null
var p2_label: Label = null
var total_label: Label = null
var formula_label: Label = null
var quota_label: Label = null
var log_label: RichTextLabel = null

func _ready() -> void:
	var screen_size = get_viewport_rect().size
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Main container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 30)
	margin.add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "🔢 G-COUNTER ALGORITHM TEST"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.7, 0.4, 0.9))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Multiplayer Score Synchronization\nGlobalScore = Σ(PlayerInput_i)"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(subtitle)
	
	# Score display panel
	var score_panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.6)
	panel_style.border_color = Color(0.7, 0.4, 0.9)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(15)
	score_panel.add_theme_stylebox_override("panel", panel_style)
	main_vbox.add_child(score_panel)
	
	var score_margin = MarginContainer.new()
	score_margin.add_theme_constant_override("margin_left", 40)
	score_margin.add_theme_constant_override("margin_right", 40)
	score_margin.add_theme_constant_override("margin_top", 30)
	score_margin.add_theme_constant_override("margin_bottom", 30)
	score_panel.add_child(score_margin)
	
	var score_vbox = VBoxContainer.new()
	score_vbox.add_theme_constant_override("separation", 20)
	score_margin.add_child(score_vbox)
	
	# Player scores in HBox
	var players_hbox = HBoxContainer.new()
	players_hbox.add_theme_constant_override("separation", 100)
	players_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	score_vbox.add_child(players_hbox)
	
	# Player 1
	var p1_vbox = VBoxContainer.new()
	p1_vbox.add_theme_constant_override("separation", 10)
	players_hbox.add_child(p1_vbox)
	
	var p1_title = Label.new()
	p1_title.text = "Player 1"
	p1_title.add_theme_font_size_override("font_size", 28)
	p1_title.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	p1_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1_vbox.add_child(p1_title)
	
	p1_label = Label.new()
	p1_label.text = "0"
	p1_label.add_theme_font_size_override("font_size", 64)
	p1_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	p1_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1_vbox.add_child(p1_label)
	
	var p1_btn = Button.new()
	p1_btn.text = "+5 Points"
	p1_btn.custom_minimum_size = Vector2(200, 60)
	p1_btn.add_theme_font_size_override("font_size", 24)
	p1_btn.pressed.connect(_on_p1_score)
	p1_vbox.add_child(p1_btn)
	
	# Plus sign
	var plus = Label.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 72)
	plus.add_theme_color_override("font_color", Color.WHITE)
	players_hbox.add_child(plus)
	
	# Player 2
	var p2_vbox = VBoxContainer.new()
	p2_vbox.add_theme_constant_override("separation", 10)
	players_hbox.add_child(p2_vbox)
	
	var p2_title = Label.new()
	p2_title.text = "Player 2"
	p2_title.add_theme_font_size_override("font_size", 28)
	p2_title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	p2_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2_vbox.add_child(p2_title)
	
	p2_label = Label.new()
	p2_label.text = "0"
	p2_label.add_theme_font_size_override("font_size", 64)
	p2_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.5))
	p2_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2_vbox.add_child(p2_label)
	
	var p2_btn = Button.new()
	p2_btn.text = "+5 Points"
	p2_btn.custom_minimum_size = Vector2(200, 60)
	p2_btn.add_theme_font_size_override("font_size", 24)
	p2_btn.pressed.connect(_on_p2_score)
	p2_vbox.add_child(p2_btn)
	
	score_vbox.add_child(HSeparator.new())
	
	# Formula display
	formula_label = Label.new()
	formula_label.add_theme_font_size_override("font_size", 36)
	formula_label.add_theme_color_override("font_color", Color(1, 1, 0.7))
	formula_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_vbox.add_child(formula_label)
	
	# Total score
	total_label = Label.new()
	total_label.add_theme_font_size_override("font_size", 72)
	total_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_vbox.add_child(total_label)
	
	# Quota display
	quota_label = Label.new()
	quota_label.add_theme_font_size_override("font_size", 28)
	quota_label.add_theme_color_override("font_color", Color(1, 1, 0.5))
	quota_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_vbox.add_child(quota_label)
	
	# Log panel
	var log_panel = PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_style = StyleBoxFlat.new()
	log_style.bg_color = Color(0, 0, 0, 0.8)
	log_style.set_corner_radius_all(10)
	log_panel.add_theme_stylebox_override("panel", log_style)
	main_vbox.add_child(log_panel)
	
	var log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(log_scroll)
	
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 18)
	log_scroll.add_child(log_label)
	
	# Control buttons
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 20)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(btn_hbox)
	
	var reset_btn = Button.new()
	reset_btn.text = "🔄 RESET"
	reset_btn.custom_minimum_size = Vector2(200, 60)
	reset_btn.add_theme_font_size_override("font_size", 22)
	reset_btn.pressed.connect(_on_reset)
	btn_hbox.add_child(reset_btn)
	
	var back_btn = Button.new()
	back_btn.text = "← BACK"
	back_btn.custom_minimum_size = Vector2(200, 60)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(_on_back)
	btn_hbox.add_child(back_btn)
	
	# Initialize
	_update_display()
	_log("🔢 G-Counter initialized: {1: 0, 2: 0}")
	_log("🎯 Quota: %d points" % quota)
	_log("")

func _update_display() -> void:
	"""Update all displays"""
	p1_label.text = str(p1_score)
	p2_label.text = str(p2_score)
	
	var total = p1_score + p2_score
	formula_label.text = "%d + %d = %d" % [p1_score, p2_score, total]
	total_label.text = "Global Score: %d" % total
	
	var remaining = max(0, quota - total)
	quota_label.text = "🎯 Quota: %d / %d (need %d more)" % [total, quota, remaining]
	
	if total >= quota:
		quota_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		quota_label.text = "🏆 QUOTA REACHED!"

func _log(text: String) -> void:
	"""Add to log"""
	log_label.text += text + "\n"
	print(text)

func _on_p1_score() -> void:
	"""Player 1 scores"""
	p1_score += 5
	_update_display()
	_log("[color=cyan]💧 Player 1 scored 5 points → Total: %d[/color]" % p1_score)
	
	var total = p1_score + p2_score
	if total >= quota:
		_log("[color=lime]🏆 TEAM VICTORY! Quota reached![/color]")
		_log("")

func _on_p2_score() -> void:
	"""Player 2 scores"""
	p2_score += 5
	_update_display()
	_log("[color=orange]💧 Player 2 scored 5 points → Total: %d[/color]" % p2_score)
	
	var total = p1_score + p2_score
	if total >= quota:
		_log("[color=lime]🏆 TEAM VICTORY! Quota reached![/color]")
		_log("")

func _on_reset() -> void:
	"""Reset scores"""
	p1_score = 0
	p2_score = 0
	log_label.text = ""
	_update_display()
	_log("🔄 G-Counter reset: {1: 0, 2: 0}")
	_log("🎯 Quota: %d points" % quota)
	_log("")

func _on_back() -> void:
	"""Return to launcher"""
	get_tree().change_scene_to_file("res://test/DemoLauncher.tscn")
