extends VBoxContainer

# UI References
@onready var top_bar_dummy: Control = $TopBarDummy
@onready var bottom_bar_dummy: Control = $BottomBarDummy

func _ready():
	# Ensure we receive input events for the entire overlay
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if the click occurred outside the GachaInventoriesArea
		if not gacha_inventories_area.get_global_rect().has_point(get_global_mouse_position()):
			hide()
			accept_event() # Consume the event so it doesn't propagate further

@onready var gacha_inventories_area: HBoxContainer = $GachaInventoriesArea

func setup_gacha_pool():
	# Clear existing children from each inventory tier
	for tier_container in gacha_inventories_area.get_children():
		if tier_container is GridContainer:
			for child in tier_container.get_children():
				child.queue_free()
	# The grids will remain empty for now, as per the user's current goal.
