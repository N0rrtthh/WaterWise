# QUICK FIX GUIDE - Copy Pause Functions

## Step 1: Open the file
Open: `scripts/multiplayer/MiniGame_Rain.gd`

## Step 2: Scroll to the very end of the file
You should see this as the last few lines:
```gdscript
		await get_tree().create_timer(3.0).timeout
		if GameManager:
			GameManager.return_to_main_menu()
		else:
			get_tree().change_scene_to_file("res://scenes/ui/InitialScreen.tscn")
```

## Step 3: Add a blank line after the last line, then paste this code:

```gdscript

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PAUSE SYSTEM (SYNCHRONIZED FOR MULTIPLAYER)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

func _create_pause_ui() -> void:
	"""Create pause button and pause menu"""
	pause_button = Button.new()
	pause_button.text = "⏸"
	pause_button.custom_minimum_size = Vector2(50, 50)
	pause_button.add_theme_font_size_override("font_size", 32)
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.2, 0.3, 0.4, 0.8)
	btn_normal.corner_radius_top_left = 10
	btn_normal.corner_radius_top_right = 10
	btn_normal.corner_radius_bottom_left = 10
	btn_normal.corner_radius_bottom_right = 10
	
	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.3, 0.5, 0.7, 0.9)
	btn_pressed.corner_radius_top_left = 10
	btn_pressed.corner_radius_top_right = 10
	btn_pressed.corner_radius_bottom_left = 10
	btn_pressed.corner_radius_bottom_right = 10
	
	pause_button.add_theme_stylebox_override("normal", btn_normal)
	pause_button.add_theme_stylebox_override("pressed", btn_pressed)
	pause_button.add_theme_stylebox_override("hover", btn_normal)
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_on_pause_button_pressed)
	
	var top_bar = $UI/TopBar
	if top_bar:
		top_bar.add_child(pause_button)
	
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(pause_menu)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.7)
	pause_menu.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)
	
	var label = Label.new()
	label.text = "PAUSED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(label)
	
	var resume_btn = Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(200, 60)
	resume_btn.add_theme_font_size_override("font_size", 24)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)
	
	var exit_btn = Button.new()
	exit_btn.text = "EXIT TO LOBBY"
	exit_btn.custom_minimum_size = Vector2(200, 60)
	exit_btn.add_theme_font_size_override("font_size", 24)
	exit_btn.pressed.connect(_on_exit_pressed)
	vbox.add_child(exit_btn)

func _on_pause_button_pressed() -> void:
	if is_paused:
		return
	is_paused = true
	get_tree().paused = true
	pause_menu.visible = true
	pause_button.text = "▶"
	if NetworkManager and NetworkManager.has_method("sync_pause_state"):
		NetworkManager.rpc("sync_pause_state", true)
	print("⏸ Game paused by local player")

func _on_resume_pressed() -> void:
	if not is_paused:
		return
	is_paused = false
	get_tree().paused = false
	pause_menu.visible = false
	pause_button.text = "⏸"
	if NetworkManager and NetworkManager.has_method("sync_pause_state"):
		NetworkManager.rpc("sync_pause_state", false)
	print("▶ Game resumed by local player")

func _on_exit_pressed() -> void:
	get_tree().paused = false
	if NetworkManager:
		NetworkManager.return_to_lobby()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/MultiplayerLobby.tscn")

func _on_remote_pause() -> void:
	is_paused = true
	get_tree().paused = true
	if pause_menu:
		pause_menu.visible = true
	if pause_button:
		pause_button.text = "▶"
	print("⏸ Game paused by remote player")

func _on_remote_resume() -> void:
	is_paused = false
	get_tree().paused = false
	if pause_menu:
		pause_menu.visible = false
	if pause_button:
		pause_button.text = "⏸"
	print("▶ Game resumed by remote player")
```

## Step 4: Save the file

## Done!
The game should now have:
- ✅ Working P2 leaf clicking
- ✅ Countdown timer (60 seconds)
- ✅ Timer completion logic
- ✅ Synchronized pause system
- ✅ Single-player style UI

## If you get errors:
1. Make sure the code is pasted at the VERY END before the closing of the file
2. Check indentation (should start with `func` at column 0)
3. Reload Godot project
