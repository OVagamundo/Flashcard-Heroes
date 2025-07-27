class_name InspectionWindow
extends PanelContainer

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# WindowManager might not exist if the game is shutting down.
		if WindowManager:
			WindowManager.stop_tracking_window(self.get_instance_id())

func _position_child_window(parent_window: Control):
	# This method is called by WindowManager to position child windows
	# after they are fully set up and have their correct size
	if WindowManager:
		var position = WindowManager._calculate_child_window_position(parent_window, self)
		set_global_position(position)

func _position_root_window(source_view: Control):
	# This method is called by WindowManager to position root windows
	# after they are fully set up and have their correct size
	if WindowManager:
		var position = WindowManager._calculate_window_position(source_view, self)
		set_global_position(position)
