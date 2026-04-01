extends Control

@onready var title_label = $ScrollContainer/VBoxContainer/Title
@onready var gameplay_label = $ScrollContainer/VBoxContainer/Section1
@onready var gameplay_text = $ScrollContainer/VBoxContainer/Text1
@onready var difficulty_label = $ScrollContainer/VBoxContainer/Section2
@onready var difficulty_text = $ScrollContainer/VBoxContainer/Text2
@onready var posttest_label = $ScrollContainer/VBoxContainer/Section3
@onready var posttest_text = $ScrollContainer/VBoxContainer/Text3
@onready var tips_label = $ScrollContainer/VBoxContainer/Section4
@onready var tips_text = $ScrollContainer/VBoxContainer/Text4
@onready var back_button = $ScrollContainer/VBoxContainer/BackButton

func _ready() -> void:
	await get_tree().process_frame
	_update_translations()
	
	if Localization:
		Localization.language_changed.connect(_on_language_changed)

func _update_translations() -> void:
	if not Localization:
		return
	
	title_label.text = Localization.get_text("how_to_play")
	gameplay_label.text = Localization.get_text("gameplay")
	gameplay_text.text = Localization.get_text("gameplay_text")
	difficulty_label.text = Localization.get_text("difficulty")
	difficulty_text.text = Localization.get_text("difficulty_text")
	posttest_label.text = Localization.get_text("post_test")
	posttest_text.text = Localization.get_text("post_test_text")
	tips_label.text = Localization.get_text("water_tips")
	tips_text.text = Localization.get_text("water_tips_text")
	back_button.text = Localization.get_text("back")

func _on_language_changed(_new_lang: String) -> void:
	_update_translations()

func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
