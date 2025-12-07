extends Control

@onready var title_label = $UI/VBoxContainer/TitleContainer/Title
@onready var subtitle_label = $UI/VBoxContainer/TitleContainer/Subtitle
@onready var host_button = $UI/VBoxContainer/HostButton
@onready var join_button = $UI/VBoxContainer/JoinButton
@onready var back_button = $UI/VBoxContainer/BackButton

func _ready() -> void:
	_update_translations()
	
	# Connect to language changes
	if Localization:
		Localization.language_changed.connect(_on_language_changed)

func _update_translations() -> void:
	if not Localization:
		return
	
	title_label.text = Localization.get_text("multiplayer")
	subtitle_label.text = "" # No subtitle for multiplayer
	host_button.text = Localization.get_text("host")
	join_button.text = Localization.get_text("join")
	back_button.text = Localization.get_text("back")

func _on_language_changed(_new_lang: String) -> void:
	_update_translations()

func _on_host_button_pressed() -> void:
	print("Host button pressed")

func _on_join_button_pressed() -> void:
	print("Join button pressed")

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")