extends Node

## What the Android hardware/gesture Back button does today.
##
## No script in the project handles NOTIFICATION_WM_GO_BACK_REQUEST: every hit for
## that constant is under .agents/skills/, which are reference templates and are not
## part of the game. So the behaviour is whatever SceneTree does by default, and this
## probe measures that rather than quoting the documentation.
func _ready() -> void:
	print("")
	print("=== ANDROID BACK BUTTON: CURRENT BEHAVIOUR ===")
	print("  SceneTree.quit_on_go_back        : %s" % get_tree().quit_on_go_back)
	print("  SceneTree.auto_accept_quit       : %s" % get_tree().auto_accept_quit)
	var handlers: Array = []
	for n in get_tree().root.get_children():
		if n.has_method("_notification"):
			handlers.append(n.name)
	print("  autoloads exposing _notification : %s" % str(handlers))
	print("")
	print("  With quit_on_go_back true and no NOTIFICATION_WM_GO_BACK_REQUEST handler,")
	print("  Back calls SceneTree.quit() from anywhere - mid-round, mid-cutscene, in a")
	print("  menu - with no confirmation and no return to the previous screen.")
	print("")
	get_tree().quit(0)
