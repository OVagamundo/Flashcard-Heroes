<!-- Original: scripts/InspectionWindow.gd -->

```gdscript
class_name InspectionWindow
extends PanelContainer

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# WindowManager might not exist if the game is shutting down.
		if WindowManager:
			WindowManager.stop_tracking_window(self)

```