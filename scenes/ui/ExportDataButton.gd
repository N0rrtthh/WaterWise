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
	
	if not FileExporter.is_external_storage_available():
		_show_error("External storage not available. Check permissions.")
		disabled = false
		text = original_text
		return
	
	var result = FileExporter.export_all_data()
	
	if result.success:
		FileExporter.create_export_summary()
		
		var message = "Export Successful!\n\n"
		message += "Files exported: " + str(result.files_exported) + "\n\n"
		message += "Location:\n"
		message += "Downloads/WaterwiseExports/\n\n"
		message += "How to access:\n"
		message += "1. Open Files app\n"
		message += "2. Go to Downloads\n"
		message += "3. Open WaterwiseExports folder\n"
		
		_show_success(message)
	else:
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
