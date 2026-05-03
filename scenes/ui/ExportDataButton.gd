extends Button

var popup: AcceptDialog

func _ready() -> void:
	if not OS.has_feature("android"):
		visible = false
		return
	
	if not pressed.is_connected(_on_export_pressed):
		pressed.connect(_on_export_pressed)
	
	# Create the popup and add it to the scene tree root (not as a child of
	# this Button). Adding it to the Button caused the popup's OK button to be
	# unclickable because the Button's own input handling swallowed clicks.
	popup = AcceptDialog.new()
	popup.title = "Export Data"
	popup.exclusive = true
	popup.unresizable = false
	popup.min_size = Vector2(400, 200)
	# Defer so the tree is ready
	call_deferred("_add_popup_to_tree")

func _add_popup_to_tree() -> void:
	if popup and not popup.is_inside_tree():
		var root = get_tree().root if get_tree() else null
		if root:
			root.add_child(popup)
			# Re-enable export button when popup is dismissed
			popup.confirmed.connect(_on_popup_dismissed)
			popup.canceled.connect(_on_popup_dismissed)

func _on_popup_dismissed() -> void:
	# Ensure the export button is re-enabled after the popup is closed
	disabled = false

func _on_export_pressed() -> void:
	disabled = true
	var original_text = text
	text = "Exporting..."
	
	print("📤 Export button pressed - exporting SESSION DATA ONLY...")
	
	if not FileExporter.is_external_storage_available():
		print("❌ External storage not available")
		_show_error("External storage not available. Check permissions.")
		text = original_text
		return
	
	print("✅ External storage available - exporting session logs...")
	var result = FileExporter.export_session_data_only()
	
	print("📊 Export result: success=%s, files=%s, error=%s" % [
		result.get("success", false),
		result.get("files_exported", 0),
		result.get("error", "")
	])
	
	if result.success:
		var message = "Session Data Exported!\n\n"
		message += "Files exported: " + str(result.files_exported) + "\n\n"
		message += "What was exported:\n"
		message += "- Session logs with metrics\n"
		message += "- Performance data (FPS, memory)\n"
		message += "- Player accuracy & reaction times\n"
		message += "- Difficulty adaptation data\n\n"
		message += "Location:\n"
		message += "Downloads/WaterwiseExports/session_logs/\n\n"
		message += "How to access:\n"
		message += "1. Open Files app\n"
		message += "2. Go to Downloads\n"
		message += "3. Open WaterwiseExports\n"
		message += "4. Open session_logs folder\n"
		
		print("✅ Export successful!")
		_show_success(message)
	else:
		print("❌ Export failed: %s" % result.error)
		_show_error("Export failed: " + result.error)
	
	# Restore button text; it stays disabled until popup is dismissed
	text = original_text

func _show_success(message: String) -> void:
	if popup and popup.is_inside_tree():
		popup.dialog_text = message
		popup.popup_centered()
	else:
		print(message)
		disabled = false

func _show_error(message: String) -> void:
	if popup and popup.is_inside_tree():
		popup.dialog_text = message
		popup.popup_centered()
	else:
		push_error(message)
		disabled = false

func _exit_tree() -> void:
	# Clean up the popup from the root when this button is removed
	if popup and popup.is_inside_tree():
		popup.queue_free()
