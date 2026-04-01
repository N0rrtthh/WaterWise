extends Control

@onready var title_label = $CenterContainer/VBoxContainer/Title
@onready var placeholder_label = $CenterContainer/VBoxContainer/Placeholder
@onready var back_button = $CenterContainer/VBoxContainer/BackButton

func _ready() -> void:
	await get_tree().process_frame
	_update_translations()
	
	if Localization:
		Localization.language_changed.connect(_on_language_changed)

func _update_translations() -> void:
	if not Localization:
		return
	
	title_label.text = Localization.get_text("character_customization")
	placeholder_label.text = Localization.get_text("coming_soon")
	back_button.text = Localization.get_text("back")

func _on_language_changed(_new_lang: String) -> void:
	_update_translations()

func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
