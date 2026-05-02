extends Control

@onready var title_label = $UI/VBoxContainer/TitleContainer/Title
@onready var subtitle_label = $UI/VBoxContainer/TitleContainer/Subtitle
@onready var host_button = $UI/VBoxContainer/HostButton
@onready var join_button = $UI/VBoxContainer/JoinButton
@onready var back_button = $UI/VBoxContainer/BackButton

var _pending_notice: String = ""

func _ready() -> void:
	if GameManager and GameManager.has_method("consume_multiplayer_notice"):
		_pending_notice = GameManager.consume_multiplayer_notice()
	_update_translations()
	
	# Connect to language changes
	if Localization:
		Localization.language_changed.connect(_on_language_changed)

func _update_translations() -> void:
	title_label.text = "MULTIPLAYER"
	host_button.text = "HOST"
	join_button.text = "JOIN"
	back_button.text = "BACK"
	if Localization:
		title_label.text = Localization.get_text("multiplayer")
		host_button.text = Localization.get_text("host")
		join_button.text = Localization.get_text("join")
		back_button.text = Localization.get_text("back")
	if _pending_notice.is_empty():
		subtitle_label.text = ""
		subtitle_label.add_theme_color_override("font_color", Color(0.894118, 0.45098, 0.133333, 1))
	else:
		subtitle_label.text = _pending_notice
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))

func _on_language_changed(_new_lang: String) -> void:
	_update_translations()

func _on_host_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _on_join_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")