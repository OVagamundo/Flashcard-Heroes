class_name InspectionWindow
extends PanelContainer

## ID of the parent inspection window, or -1 if this is a root inspection window.
var parent_inspection_window_id: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	enforce_display_only()

func enforce_display_only() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_mouse_filter_recursive(self)

func populate(_context: Dictionary) -> void:
	pass

func _apply_mouse_filter_recursive(node: Node) -> void:
	if node is Control:
		if node.get_meta("interactive", false):
			node.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_apply_mouse_filter_recursive(child)

func _notification(what) -> void:
	if what == NOTIFICATION_PREDELETE:
		# WindowManager might not exist if the game is shutting down.
		if WindowManager:
			WindowManager.stop_tracking_window(self.get_instance_id())

func get_child_window_specs() -> Array[Dictionary]:
	return []

func get_glossary_terms() -> Array[String]:
	return []

func _position_child_window(parent_window: Control) -> void:
	# This method is called by WindowManager to position child windows
	# after they are fully set up and have their correct size
	if WindowManager:
		var position = WindowManager._calculate_child_window_position(parent_window, self)
		set_global_position(position)

func _position_root_window(source_view: Control) -> void:
	# This method is called by WindowManager to position root windows
	# after they are fully set up and have their correct size
	if WindowManager:
		var position = WindowManager._calculate_window_position(source_view, self)
		set_global_position(position)
