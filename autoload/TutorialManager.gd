extends Node

## ═══════════════════════════════════════════════════════════════════
## TUTORIALMANAGER.GD - First-Time Player Instructions & Hints
## ═══════════════════════════════════════════════════════════════════
## Provides:
## - Welcome popups for first-time players
## - Game-specific tutorials
## - Contextual hints
## - Progress-aware guidance
## ═══════════════════════════════════════════════════════════════════

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SIGNALS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

signal tutorial_started(game_id: String)
signal tutorial_completed(game_id: String)
signal hint_shown(hint_text: String)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TUTORIAL DATA (English + Filipino)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var tutorials: Dictionary = {
	"CatchTheRain": {
		"en": {
			"title": "Catch The Rain",
			"steps": [
				{ "text": "Move your bucket left and right to catch falling raindrops! 🌧️", "image": "" },
				{ "text": "Blue drops = +1 point ✅\nRed drops = -1 life ❌", "image": "" },
				{ "text": "Save as much rainwater as you can before time runs out!", "image": "" }
			],
			"tip": "Focus on the center - most drops fall there!"
		},
		"tl": {
			"title": "Saluhin ang Ulan",
			"steps": [
				{ "text": "Igalaw ang balde pakaliwa at pakanan para saluhin ang ulan! 🌧️", "image": "" },
				{ "text": "Asul na patak = +1 puntos ✅\nPula na patak = -1 buhay ❌", "image": "" },
				{ "text": "Mag-ipon ng maraming tubig-ulan bago maubos ang oras!", "image": "" }
			],
			"tip": "Tumuon sa gitna - karamihan ng patak ay nahuhulog doon!"
		}
	},
	"FixLeak": {
		"en": {
			"title": "Fix The Leak",
			"steps": [
				{ "text": "Tap on leaking pipes to fix them before water is wasted! 💧", "image": "" },
				{ "text": "Fix leaks quickly - they get worse over time!", "image": "" },
				{ "text": "Watch for new leaks appearing around the screen.", "image": "" }
			],
			"tip": "Prioritize the biggest leaks first!"
		},
		"tl": {
			"title": "Ayusin ang Tagas",
			"steps": [
				{ "text": "I-tap ang tumatagas na tubo para ayusin bago masayang ang tubig! 💧", "image": "" },
				{ "text": "Mabilis na ayusin - lumalala ang tagas sa oras!", "image": "" },
				{ "text": "Bantayan ang bagong tagas na lumilitaw.", "image": "" }
			],
			"tip": "Unahin ang malalaking tagas!"
		}
	},
	"GreywaterSorter": {
		"en": {
			"title": "Greywater Sorter",
			"steps": [
				{ "text": "Sort items by swiping! ⬆️⬇️", "image": "" },
				{ "text": "Swipe UP for items that can use GREYWATER 🌿", "image": "" },
				{ "text": "Swipe DOWN for items needing CLEAN water 🚿", "image": "" }
			],
			"tip": "Plants and gardens love greywater!"
		},
		"tl": {
			"title": "Pag-uuri ng Greywater",
			"steps": [
				{ "text": "Pag-uri-uriin sa pamamagitan ng pag-swipe! ⬆️⬇️", "image": "" },
				{ "text": "Swipe PATAAS para sa pwedeng gumamit ng GREYWATER 🌿", "image": "" },
				{ "text": "Swipe PABABA para sa kailangan ng MALINIS na tubig 🚿", "image": "" }
			],
			"tip": "Gusto ng mga halaman ang greywater!"
		}
	},
	"PlugTheLeak": {
		"en": {
			"title": "Plug The Leak",
			"steps": [
				{ "text": "Drag the correct plugs to seal leaking holes! 🔌", "image": "" },
				{ "text": "Match the plug shape to the hole shape.", "image": "" },
				{ "text": "Work fast before too much water escapes!", "image": "" }
			],
			"tip": "Look at the hole shape before grabbing a plug!"
		},
		"tl": {
			"title": "Takpan ang Tagas",
			"steps": [
				{ "text": "I-drag ang tamang takip para isara ang butas! 🔌", "image": "" },
				{ "text": "Itugma ang hugis ng takip sa hugis ng butas.", "image": "" },
				{ "text": "Bilisan bago masyadong maraming tubig ang masayang!", "image": "" }
			],
			"tip": "Tingnan muna ang hugis ng butas!"
		}
	},
	"SwipeTheSoap": {
		"en": {
			"title": "Swipe The Soap",
			"steps": [
				{ "text": "Swipe in patterns to wash efficiently! 🧼", "image": "" },
				{ "text": "Follow the arrow directions for bonus points!", "image": "" },
				{ "text": "Complete patterns quickly to save water!", "image": "" }
			],
			"tip": "Smooth, continuous swipes work best!"
		},
		"tl": {
			"title": "I-swipe ang Sabon",
			"steps": [
				{ "text": "Mag-swipe sa pattern para maghugas nang maayos! 🧼", "image": "" },
				{ "text": "Sundin ang direksyon ng arrow para sa bonus!", "image": "" },
				{ "text": "Kumpletuhin ang pattern nang mabilis para makatipid ng tubig!", "image": "" }
			],
			"tip": "Ang maayos at tuloy-tuloy na swipe ang pinakamabisa!"
		}
	},
	"QuickShower": {
		"en": {
			"title": "Quick Shower",
			"steps": [
				{ "text": "Tap body parts to wash them before time runs out! 🚿", "image": "" },
				{ "text": "Each part needs to be scrubbed 3 times.", "image": "" },
				{ "text": "Shorter showers save more water!", "image": "" }
			],
			"tip": "Start from top to bottom for efficiency!"
		},
		"tl": {
			"title": "Mabilis na Paligo",
			"steps": [
				{ "text": "I-tap ang bahagi ng katawan para hugasan bago maubos ang oras! 🚿", "image": "" },
				{ "text": "Bawat bahagi ay kailangang hugasan 3 beses.", "image": "" },
				{ "text": "Mas maikling paligo = mas maraming tubig na naiipon!", "image": "" }
			],
			"tip": "Magsimula sa itaas pababa para sa efficiency!"
		}
	},
	"TimingTap": {
		"en": {
			"title": "Timing Tap",
			"steps": [
				{ "text": "Tap when the indicator is in the GREEN zone! 🎯", "image": "" },
				{ "text": "Perfect timing = maximum water saved!", "image": "" },
				{ "text": "Miss the zone = water wasted.", "image": "" }
			],
			"tip": "Watch the rhythm - it gets faster!"
		},
		"tl": {
			"title": "Tamang Timing",
			"steps": [
				{ "text": "I-tap kapag nasa BERDE na zone ang indicator! 🎯", "image": "" },
				{ "text": "Perpektong timing = maximum na tubig na naiipon!", "image": "" },
				{ "text": "Sumala = nasayang na tubig.", "image": "" }
			],
			"tip": "Panoorin ang ritmo - bumibilis ito!"
		}
	},
	"TurnOffTap": {
		"en": {
			"title": "Turn Off The Tap",
			"steps": [
				{ "text": "Spot running taps and turn them off! 🚰", "image": "" },
				{ "text": "Tap the faucet handle to close it.", "image": "" },
				{ "text": "Don't let water run unnecessarily!", "image": "" }
			],
			"tip": "Check all corners of the room!"
		},
		"tl": {
			"title": "Isara ang Gripo",
			"steps": [
				{ "text": "Hanapin ang bukas na gripo at isara! 🚰", "image": "" },
				{ "text": "I-tap ang hawakan ng gripo para isara.", "image": "" },
				{ "text": "Huwag hayaang tumatakbo ang tubig nang walang saysay!", "image": "" }
			],
			"tip": "Tingnan ang lahat ng sulok ng kwarto!"
		}
	}
}

# Welcome screens shown once per game
var shown_tutorials: Array[String] = []
const SHOWN_TUTORIALS_KEY := "shown_tutorials"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# INITIALIZATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _get_save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")

func _ready() -> void:
	_load_shown_tutorials()

func _load_shown_tutorials() -> void:
	var save_mgr = _get_save_manager()
	if save_mgr:
		var saved = save_mgr.get_setting(SHOWN_TUTORIALS_KEY, [])
		if saved is Array:
			for item in saved:
				shown_tutorials.append(str(item))

func _save_shown_tutorials() -> void:
	var save_mgr = _get_save_manager()
	if save_mgr:
		save_mgr.set_setting(SHOWN_TUTORIALS_KEY, shown_tutorials)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TUTORIAL DISPLAY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func should_show_tutorial(game_id: String) -> bool:
	"""Check if tutorial should be shown for this game"""
	var save_mgr = _get_save_manager()
	if not save_mgr:
		return true
	return game_id not in shown_tutorials and save_mgr.get_setting("show_hints", true)

func mark_tutorial_shown(game_id: String) -> void:
	"""Mark tutorial as shown (won't show again)"""
	if game_id not in shown_tutorials:
		shown_tutorials.append(game_id)
		_save_shown_tutorials()

func get_tutorial(game_id: String) -> Dictionary:
	"""Get tutorial data for a specific game"""
	var lang := "en"
	if Localization and not Localization.is_english():
		lang = "tl"
	
	if tutorials.has(game_id):
		return tutorials[game_id].get(lang, tutorials[game_id].en)
	
	return {}

func reset_tutorials() -> void:
	"""Reset all tutorials to show again"""
	shown_tutorials.clear()
	_save_shown_tutorials()

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TUTORIAL POPUP CREATION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func create_tutorial_popup(game_id: String, parent: Node) -> Control:
	"""Create and return a tutorial popup for the given game"""
	var tutorial_data = get_tutorial(game_id)
	if tutorial_data.is_empty():
		return null
	
	tutorial_started.emit(game_id)
	
	# Create overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.name = "TutorialOverlay"
	
	# Create panel
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(600, 400)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.95)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "📚 " + tutorial_data.title
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.2, 0.4, 0.8))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# Steps container
	var steps_container = VBoxContainer.new()
	steps_container.add_theme_constant_override("separation", 12)
	vbox.add_child(steps_container)
	
	var steps = tutorial_data.get("steps", [])
	for i in range(steps.size()):
		var step = steps[i]
		var step_label = Label.new()
		step_label.text = str(i + 1) + ". " + step.text
		step_label.add_theme_font_size_override("font_size", 22)
		step_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		steps_container.add_child(step_label)
	
	# Tip
	if tutorial_data.has("tip"):
		var tip_box = PanelContainer.new()
		var tip_style = StyleBoxFlat.new()
		tip_style.bg_color = Color(1.0, 0.95, 0.8)
		tip_style.corner_radius_top_left = 10
		tip_style.corner_radius_top_right = 10
		tip_style.corner_radius_bottom_left = 10
		tip_style.corner_radius_bottom_right = 10
		tip_box.add_theme_stylebox_override("panel", tip_style)
		
		var tip_margin = MarginContainer.new()
		tip_margin.add_theme_constant_override("margin_left", 15)
		tip_margin.add_theme_constant_override("margin_right", 15)
		tip_margin.add_theme_constant_override("margin_top", 10)
		tip_margin.add_theme_constant_override("margin_bottom", 10)
		tip_box.add_child(tip_margin)
		
		var tip_label = Label.new()
		tip_label.text = "💡 TIP: " + tutorial_data.tip
		tip_label.add_theme_font_size_override("font_size", 18)
		tip_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.1))
		tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip_margin.add_child(tip_label)
		
		vbox.add_child(tip_box)
	
	# Start button
	var start_btn = Button.new()
	start_btn.text = "▶️ START GAME"
	start_btn.custom_minimum_size = Vector2(200, 60)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.7, 0.3)
	btn_style.corner_radius_top_left = 15
	btn_style.corner_radius_top_right = 15
	btn_style.corner_radius_bottom_left = 15
	btn_style.corner_radius_bottom_right = 15
	start_btn.add_theme_stylebox_override("normal", btn_style)
	start_btn.add_theme_stylebox_override("hover", btn_style)
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.add_theme_color_override("font_color", Color.WHITE)
	
	start_btn.pressed.connect(func():
		mark_tutorial_shown(game_id)
		tutorial_completed.emit(game_id)
		overlay.queue_free()
	)
	
	vbox.add_child(start_btn)
	
	overlay.add_child(panel)
	parent.add_child(overlay)
	
	# Entrance animation
	overlay.modulate.a = 0
	panel.scale = Vector2(0.8, 0.8)
	var tween = overlay.create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.3)
	tween.tween_property(panel, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	return overlay

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONTEXTUAL HINTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

var gameplay_hints: Dictionary = {
	"low_accuracy": {
		"en": "Take your time! Accuracy is more important than speed.",
		"tl": "Dahan-dahan lang! Mas importante ang tamang sagot kaysa sa bilis."
	},
	"too_slow": {
		"en": "Try to pick up the pace a little!",
		"tl": "Subukang bilisan ng kaunti!"
	},
	"losing_streak": {
		"en": "Don't give up! Practice makes perfect! 💪",
		"tl": "Huwag sumuko! Ang pagsasanay ang susi sa tagumpay! 💪"
	},
	"perfect_game": {
		"en": "Amazing! You're a water conservation expert! ⭐",
		"tl": "Kahanga-hanga! Ikaw ay eksperto sa pagtitipid ng tubig! ⭐"
	}
}

func get_contextual_hint(hint_type: String) -> String:
	"""Get a hint based on player performance"""
	var lang := "en"
	if Localization and not Localization.is_english():
		lang = "tl"
	
	if gameplay_hints.has(hint_type):
		var hint = gameplay_hints[hint_type].get(lang, gameplay_hints[hint_type].en)
		hint_shown.emit(hint)
		return hint
	
	return ""

func show_hint_popup(parent: Node, hint_text: String, duration: float = 3.0) -> void:
	"""Show a temporary hint popup"""
	var label = Label.new()
	label.text = "💡 " + hint_text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.position.y = 100
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.custom_minimum_size = Vector2(label.size.x + 40, 50)
	
	parent.add_child(label)
	
	# Animate
	label.modulate.a = 0
	var tween = label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)
