extends Node
class_name FileExporter

## ═══════════════════════════════════════════════════════════════════
## FILE EXPORTER - ANDROID EXTERNAL STORAGE
## ═══════════════════════════════════════════════════════════════════
## Exports game files to Downloads folder (accessible without ADB)
## Works on Android 10+ with proper permissions
## ═══════════════════════════════════════════════════════════════════

const EXPORT_FOLDER_NAME = "WaterwiseExports"

static func _get_session_logger() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return loop.root.get_node_or_null("SessionLogger")
	return null

static func _normalize_dir(path: String) -> String:
	var dir = path.strip_edges()
	if dir.is_empty():
		return "user://session_logs/"
	if not dir.ends_with("/"):
		dir += "/"
	return dir

static func _is_user_or_res_path(path: String) -> bool:
	return path.begins_with("user://") or path.begins_with("res://")

static func _get_session_log_dir() -> String:
	var log_dir := "user://session_logs/"
	var session_logger = _get_session_logger()
	if session_logger:
		if session_logger.has_method("get_export_dir"):
			log_dir = str(session_logger.call("get_export_dir"))
		else:
			log_dir = str(session_logger.get("export_dir"))
	return _normalize_dir(log_dir)

## Export save file to Downloads folder
static func export_save_file() -> Dictionary:
	var result = {"success": false, "path": "", "error": ""}
	
	if not OS.has_feature("android"):
		result.error = "Not on Android - files are in user:// folder"
		return result
	
	# Read save file from internal storage
	var internal_path = "user://waterwise_save.cfg"
	if not FileAccess.file_exists(internal_path):
		result.error = "Save file not found"
		return result
	
	var file = FileAccess.open(internal_path, FileAccess.READ)
	if not file:
		result.error = "Could not read save file"
		return result
	
	var content = file.get_as_text()
	file.close()
	
	# Get external storage path (Downloads)
	var external_path = _get_external_path("waterwise_save.cfg")
	if external_path.is_empty():
		result.error = "Could not access external storage"
		return result
	
	# Write to external storage
	var export_file = FileAccess.open(external_path, FileAccess.WRITE)
	if not export_file:
		result.error = "Could not write to external storage. Check permissions."
		return result
	
	export_file.store_string(content)
	export_file.close()
	
	result.success = true
	result.path = external_path
	return result

## Export ONLY session logs and metrics (no save files or settings)
static func export_session_data_only() -> Dictionary:
	var result = {"success": false, "path": "", "error": "", "files_exported": 0}
	
	if not OS.has_feature("android"):
		result.error = "Not on Android - files are in user:// folder"
		print("📊 Session logs location: user://session_logs/")
		return result

	# Ensure a log exists for the current session before copying.
	var session_logger = _get_session_logger()
	var previous_dir := ""
	var should_restore_dir := false
	if session_logger and session_logger.has_method("export_session"):
		if session_logger.has_method("get_export_dir"):
			previous_dir = str(session_logger.call("get_export_dir"))
		elif session_logger.has_method("get"):
			previous_dir = str(session_logger.get("export_dir"))
		should_restore_dir = not previous_dir.is_empty()

		# Always export from user:// so we can reliably copy out.
		session_logger.set("export_dir", "user://session_logs/")
		session_logger.call("export_session")
	
	print("📊 Starting session data export...")
	
	# Export session logs
	var logs_result = export_session_logs()
	if logs_result.success:
		result.success = true
		result.files_exported = logs_result.files_exported
		result.path = logs_result.path
		print("✅ Exported %d session log files" % result.files_exported)
	else:
		result.error = logs_result.error
		print("❌ Failed to export session logs: %s" % result.error)

	if session_logger and should_restore_dir:
		session_logger.set("export_dir", previous_dir)
	
	return result

## Export all session logs to Downloads folder
static func export_session_logs() -> Dictionary:
	var result = {"success": false, "path": "", "error": "", "files_exported": 0}
	
	if not OS.has_feature("android"):
		result.error = "Not on Android - files are in user:// folder"
		return result
	
	# Check if session logs exist
	var log_dir = _get_session_log_dir()
	# Get all log files
	var dir = DirAccess.open(log_dir)
	if not dir:
		result.error = "No session logs found"
		return result
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var exported_count = 0
	
	while file_name != "":
		if (
			not dir.current_is_dir()
			and (file_name.ends_with(".json") or file_name.ends_with(".txt"))
		):
			# Read log file
			var internal_path = log_dir + file_name
			var file = FileAccess.open(internal_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				
				# Write to external storage
				var external_path = _get_external_path("session_logs/" + file_name)
				if not external_path.is_empty():
					var export_file = FileAccess.open(external_path, FileAccess.WRITE)
					if export_file:
						export_file.store_string(content)
						export_file.close()
						exported_count += 1
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if exported_count > 0:
		result.success = true
		result.files_exported = exported_count
		result.path = _get_external_base_path()
	else:
		result.error = "No files exported. Check permissions."
	
	return result

## Export all game data (save + logs + settings)
static func export_all_data() -> Dictionary:
	var result = {"success": false, "path": "", "error": "", "files_exported": 0}
	
	if not OS.has_feature("android"):
		result.error = "Not on Android - files are in user:// folder"
		return result
	
	var total_exported = 0
	var export_path = ""
	
	# Export save file
	var save_result = export_save_file()
	if save_result.success:
		total_exported += 1
		export_path = save_result.path.get_base_dir()
	
	# Export session logs
	var logs_result = export_session_logs()
	if logs_result.success:
		total_exported += logs_result.files_exported
		if export_path.is_empty():
			export_path = logs_result.path
	
	# Export settings
	var settings_result = export_settings_file()
	if settings_result.success:
		total_exported += 1
		if export_path.is_empty():
			export_path = settings_result.path.get_base_dir()
	
	if total_exported > 0:
		result.success = true
		result.files_exported = total_exported
		result.path = export_path
	else:
		result.error = "No files exported. Check permissions or no data exists."
	
	return result

## Export settings file
static func export_settings_file() -> Dictionary:
	var result = {"success": false, "path": "", "error": ""}
	
	if not OS.has_feature("android"):
		result.error = "Not on Android"
		return result
	
	var internal_path = "user://waterwise_settings.json"
	if not FileAccess.file_exists(internal_path):
		# Try .cfg extension
		internal_path = "user://waterwise_settings.cfg"
		if not FileAccess.file_exists(internal_path):
			result.error = "Settings file not found"
			return result
	
	var file = FileAccess.open(internal_path, FileAccess.READ)
	if not file:
		result.error = "Could not read settings file"
		return result
	
	var content = file.get_as_text()
	file.close()
	
	var external_path = _get_external_path("waterwise_settings" + internal_path.get_extension())
	if external_path.is_empty():
		result.error = "Could not access external storage"
		return result
	
	var export_file = FileAccess.open(external_path, FileAccess.WRITE)
	if not export_file:
		result.error = "Could not write to external storage"
		return result
	
	export_file.store_string(content)
	export_file.close()
	
	result.success = true
	result.path = external_path
	return result

## Get external storage path (Downloads folder)
static func _get_external_path(filename: String) -> String:
	if not OS.has_feature("android"):
		return ""
	
	# Get external storage directory (usually /storage/emulated/0/)
	var external_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	
	# Create our export folder
	var export_dir = external_dir + "/" + EXPORT_FOLDER_NAME
	
	# Create directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(export_dir):
		var dir_result = DirAccess.make_dir_recursive_absolute(export_dir)
		if dir_result != OK:
			print("❌ Failed to create export directory: ", export_dir)
			return ""
	
	# Handle subdirectories (e.g., "session_logs/file.json")
	if "/" in filename:
		var subdir = filename.get_base_dir()
		var full_subdir = export_dir + "/" + subdir
		if not DirAccess.dir_exists_absolute(full_subdir):
			var subdir_result = DirAccess.make_dir_recursive_absolute(full_subdir)
			if subdir_result != OK:
				print("❌ Failed to create subdirectory: ", full_subdir)
				return ""
	
	return export_dir + "/" + filename

## Get base export path
static func _get_external_base_path() -> String:
	if not OS.has_feature("android"):
		return ""
	
	var external_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	return external_dir + "/" + EXPORT_FOLDER_NAME

## Check if external storage is accessible
static func is_external_storage_available() -> bool:
	if not OS.has_feature("android"):
		return false
	
	var downloads_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	return not downloads_dir.is_empty() and DirAccess.dir_exists_absolute(downloads_dir)

## Get user-friendly export location message
static func get_export_location_message() -> String:
	if not OS.has_feature("android"):
		return "Files are in: user:// folder"
	
	return "Files exported to:\nDownloads/" + EXPORT_FOLDER_NAME + "/"

## Create a summary file with export info
static func create_export_summary() -> Dictionary:
	var result = {"success": false, "path": "", "error": ""}
	
	if not OS.has_feature("android"):
		result.error = "Not on Android"
		return result
	
	var summary = "WATERWISE GAME DATA EXPORT\n"
	var divider = "=".repeat(50)
	var dash = "-".repeat(50)
	summary += divider + "\n\n"
	summary += "Export Date: " + Time.get_datetime_string_from_system() + "\n"
	summary += "Game Version: 1.2\n\n"
	
	# List exported files
	summary += "EXPORTED FILES:\n"
	summary += dash + "\n"
	
	var export_dir = _get_external_base_path()
	var dir = DirAccess.open(export_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var file_path = export_dir + "/" + file_name
				var file_size = FileAccess.get_file_as_string(file_path).length()
				summary += "- " + file_name + " (" + str(file_size) + " bytes)\n"
			file_name = dir.get_next()
		dir.list_dir_end()
	
	summary += "\n" + dash + "\n"
	summary += "Location: Downloads/" + EXPORT_FOLDER_NAME + "/\n"
	summary += "Access: Open Files app → Downloads → " + EXPORT_FOLDER_NAME + "\n"
	
	# Write summary file
	var summary_path = _get_external_path("EXPORT_INFO.txt")
	if summary_path.is_empty():
		result.error = "Could not create summary file"
		return result
	
	var file = FileAccess.open(summary_path, FileAccess.WRITE)
	if not file:
		result.error = "Could not write summary file"
		return result
	
	file.store_string(summary)
	file.close()
	
	result.success = true
	result.path = summary_path
	return result

## Create a summary file for session data export only
static func create_session_export_summary() -> Dictionary:
	var result = {"success": false, "path": "", "error": ""}
	
	if not OS.has_feature("android"):
		result.error = "Not on Android"
		return result
	
	var summary = "WATERWISE SESSION DATA EXPORT\n"
	var divider = "=".repeat(50)
	var dash = "-".repeat(50)
	summary += divider + "\n\n"
	summary += "Export Date: " + Time.get_datetime_string_from_system() + "\n"
	summary += "Export Type: SESSION LOGS & METRICS ONLY\n"
	summary += "Game Version: 1.2\n\n"
	
	# List session log files
	summary += "SESSION LOG FILES:\n"
	summary += dash + "\n"
	
	var export_dir = _get_external_base_path() + "/session_logs"
	var dir = DirAccess.open(export_dir)
	var total_size = 0
	var file_count = 0
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var file_path = export_dir + "/" + file_name
				var file_size = FileAccess.get_file_as_string(file_path).length()
				total_size += file_size
				file_count += 1
				summary += "- " + file_name + " (" + str(file_size) + " bytes)\n"
			file_name = dir.get_next()
		dir.list_dir_end()
	
	summary += "\n" + dash + "\n"
	summary += "Total Files: " + str(file_count) + "\n"
	summary += "Total Size: " + str(total_size) + " bytes\n\n"
	summary += "Location: Downloads/" + EXPORT_FOLDER_NAME + "/session_logs/\n"
	summary += "Access: Open Files app → Downloads → " + EXPORT_FOLDER_NAME + " → session_logs\n\n"
	summary += "WHAT'S IN THESE FILES:\n"
	summary += "- Game performance metrics (FPS, memory, CPU)\n"
	summary += "- Player accuracy and reaction times\n"
	summary += "- Difficulty adaptation data (Φ algorithm)\n"
	summary += "- Session timestamps and duration\n"
	summary += "- ISO 25010 compliance metrics\n"
	
	# Write summary file
	var summary_path = _get_external_path("SESSION_EXPORT_INFO.txt")
	if summary_path.is_empty():
		result.error = "Could not create summary file"
		return result
	
	var file = FileAccess.open(summary_path, FileAccess.WRITE)
	if not file:
		result.error = "Could not write summary file"
		return result
	
	file.store_string(summary)
	file.close()
	
	result.success = true
	result.path = summary_path
	return result
