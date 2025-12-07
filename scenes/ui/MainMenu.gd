extends Control

## ═══════════════════════════════════════════════════════════════════
## MAIN MENU CONTROLLER
## ═══════════════════════════════════════════════════════════════════

@onready var title_label = $UI/VBoxContainer/TitleContainer/Title
@onready var subtitle_label = $UI/VBoxContainer/TitleContainer/Subtitle
@onready var play_button = $UI/VBoxContainer/PlayButton
@onready var quit_button = $UI/VBoxContainer/QuitButton
@onready var loading_container = $UI/VBoxContainer/LoadingContainer
@onready var progress_bar = $UI/VBoxContainer/LoadingContainer/ProgressBar
@onready var loading_label = $UI/VBoxContainer/LoadingContainer/LoadingLabel
@onready var character = $Decorations/Character
@onready var left_arm = $Decorations/Character/LeftArm
@onready var right_arm = $Decorations/Character/RightArm

var loading_messages_en = [
	"Fetching watering can...",
	"Planting seeds...",
	"Setting up adaptive difficulty...",
	"Waiting for water...",
	"Analyzing water conservation..."
]

var loading_messages_tl = [
	"Naglalako ng watering can...",
	"Tinatanim ang halaman...",
	"Ini-set up ang adaptive difficulty...",
	"Hinihintay ang tubig...",
	"Sinusuri ang water conservation..."
]

func _ready() -> void:
	await get_tree().process_frame
	_update_translations()
	_animate_entrance()
	_start_character_animation()
	
	# Connect to language changes
	if Localization:
		Localization.language_changed.connect(_on_language_changed)

	# Connect button hover/press signals for smooth animations
	if play_button:
		play_button.connect("mouse_entered", Callable(self, "_on_button_mouse_entered").bind(play_button))
		play_button.connect("mouse_exited", Callable(self, "_on_button_mouse_exited").bind(play_button))
		play_button.connect("pressed", Callable(self, "_on_button_pressed_anim").bind(play_button))

	if quit_button:
		quit_button.connect("mouse_entered", Callable(self, "_on_button_mouse_entered").bind(quit_button))
		quit_button.connect("mouse_exited", Callable(self, "_on_button_mouse_exited").bind(quit_button))
		quit_button.connect("pressed", Callable(self, "_on_button_pressed_anim").bind(quit_button))

func _update_translations() -> void:
	if not Localization:
		return
	
	title_label.text = Localization.get_text("title")
	subtitle_label.text = Localization.get_text("subtitle")
	play_button.text = Localization.get_text("play")
	quit_button.text = Localization.get_text("quit")

func _on_language_changed(_new_lang: String) -> void:
	_update_translations()

func _animate_entrance() -> void:
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8)

func _start_character_animation() -> void:
	if not character:
		return

	# ROTATION - separate looping tween
	var rotation_tween = create_tween().set_loops()
	rotation_tween.tween_property(character, "rotation", 0.261799, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rotation_tween.tween_property(character, "rotation", 0.436332, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# UP / DOWN MOVEMENT (Y axis) - separate looping tween
	var position_tween = create_tween().set_loops()
	position_tween.tween_property(character, "position:y", 727.07, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	position_tween.tween_property(character, "position:y", 750.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Wave arms up and down
	if left_arm and right_arm:
		# LEFT ARM
		var arm_tween = create_tween().set_loops()
		arm_tween.tween_property(left_arm, "rotation", -5.565, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		arm_tween.tween_property(left_arm, "rotation", -3.609, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		# RIGHT ARM
		var arm_tween2 = create_tween().set_loops()
		arm_tween2.tween_property(right_arm, "rotation", -0.702, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		arm_tween2.tween_property(right_arm, "rotation", -2.360, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)



func _on_button_mouse_entered(btn: Button) -> void:
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_button_mouse_exited(btn: Button) -> void:
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(1, 1), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_button_pressed_anim(btn: Button) -> void:
	# quick press down then recover
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(0.98, 0.98), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(btn, "scale", Vector2(1.03, 1.03), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_play_button_pressed() -> void:
	_play_button_sound()
	
	if GameManager:
		GameManager.start_new_session()
	
	# Switch to loading state within Main Menu
	play_button.hide()
	quit_button.hide()
	loading_container.show()
	
	# Start dynamic text updates
	var text_timer = Timer.new()
	text_timer.wait_time = 0.8
	text_timer.one_shot = false
	add_child(text_timer)
	text_timer.timeout.connect(_update_loading_text)
	text_timer.start()
	_update_loading_text() # Initial call
	
	# Simulate loading
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", 100.0, 4.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		text_timer.stop()
		text_timer.queue_free()
		_on_loading_complete()
	)

func _update_loading_text() -> void:
	var messages = loading_messages_tl
	if Localization and Localization.is_english():
		messages = loading_messages_en
	
	# Pick a random message different from the current one if possible
	var current_text = loading_label.text
	var new_text = messages[randi() % messages.size()]
	while new_text == current_text and messages.size() > 1:
		new_text = messages[randi() % messages.size()]
	
	loading_label.text = new_text

func _on_loading_complete() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")

func _on_quit_button_pressed() -> void:
	_play_button_sound()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _play_button_sound() -> void:
	# Placeholder for button sound
	pass
