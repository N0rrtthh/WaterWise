extends Control

@onready var title_label = $UI/VBoxContainer/TitleContainer/Title
@onready var subtitle_label = $UI/VBoxContainer/TitleContainer/Subtitle
@onready var host_button = $UI/VBoxContainer/HostButton
@onready var join_button = $UI/VBoxContainer/JoinButton
@onready var back_button = $UI/VBoxContainer/BackButton

## A localization KEY, not a sentence — see GameManager.set_multiplayer_notice(). Holding the
## key rather than the rendered line is what lets _update_translations() re-render it when the
## language changes while this screen is open.
var _pending_notice_key: String = ""

func _ready() -> void:
	# Read once and clear, so the reason cannot resurface on a later visit. The call used to
	# sit behind a has_method() guard for a method that existed nowhere, which meant every
	# involuntary departure arrived here explaining nothing.
	_pending_notice_key = GameManager.consume_multiplayer_notice()
	_update_translations()
	
	# Connect to language changes
	if Localization:
		Localization.language_changed.connect(_on_language_changed)

func _update_translations() -> void:
	title_label.text = Localization.get_text("multiplayer")
	host_button.text = Localization.get_text("host")
	join_button.text = Localization.get_text("join")
	back_button.text = Localization.get_text("back")
	if Localization:
		title_label.text = Localization.get_text("multiplayer")
		host_button.text = Localization.get_text("host")
		join_button.text = Localization.get_text("join")
		back_button.text = Localization.get_text("back")
	if _pending_notice_key.is_empty():
		subtitle_label.text = ""
		subtitle_label.add_theme_color_override("font_color", Color(0.894118, 0.45098, 0.133333, 1))
	else:
		subtitle_label.text = Localization.get_text(_pending_notice_key) if Localization else _pending_notice_key
		subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))

func _on_language_changed(_new_lang: String) -> void:
	_update_translations()

func _on_host_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _on_join_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _on_back_button_pressed() -> void:
	if GameManager and GameManager.has_method("set_game_mode"):
		GameManager.set_game_mode(GameManager.GameMode.SINGLE_PLAYER)
	get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")
