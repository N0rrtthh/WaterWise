extends Button

var popup: AcceptDialog

func _ready() -> void:
	if not OS.has_feature("android"):
		visible = false
		return
	
	if not pressed.is_connected(_on_export_pressed):
		pressed.connect(_on_export_pressed)
	
	popup = AcceptDialog.new()
	popup.title = "Export Data"
	add_child(popup)

func _on_export_pressed() -> void:
	disabled = true
	var original_text = text
	text = "Exporting..."
	
	print("📤 Export button pressed - exporting SESSION DATA ONLY...")
	
	if not FileExporter.is_external_storage_available():
		print("❌ External storage not available")
		_show_error("External storage not available. Check permissions.")
		disabled = false
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
	
	disabled = false
	text = original_text

func _show_success(message: String) -> void:
	if popup:
		popup.dialog_text = message
		popup.popup_centered()
	else:
		print(message)

func _show_error(message: String) -> void:
	if popup:
		popup.dialog_text = message
		popup.popup_centered()
	else:
		push_error(message)
