extends VBoxContainer

const UnitScene = preload("res://scenes/Unit.tscn")
const ItemScene = preload("res://scenes/Item.tscn")

# UI References
@onready var top_bar_dummy: Control = $TopBarDummy
@onready var bottom_bar_dummy: Control = $BottomBarDummy
@onready var gacha_inventories_area: HBoxContainer = $GachaInventoriesArea


func _ready():
	# Ensure we receive input events for the entire overlay
	mouse_filter = Control.MOUSE_FILTER_STOP

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			setup_gacha_pool()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if the click occurred outside the GachaInventoriesArea
		if not gacha_inventories_area.get_global_rect().has_point(get_global_mouse_position()):
			hide()
			accept_event() # Consume the event so it doesn't propagate further

func setup_gacha_pool():
	# Get the tier containers from the HBoxContainer
	var tier_containers = gacha_inventories_area.get_children()
	if tier_containers.size() != 3:
		push_error("GachaPoolInspection expects exactly 3 tier containers, but found %d" % tier_containers.size())
		return

	# Clear existing children from each inventory tier
	for i in range(tier_containers.size()):
		var tier_container = tier_containers[i]
		if tier_container is GridContainer:
			for child in tier_container.get_children():
				child.queue_free()
		else:
			push_warning("Child %d of GachaInventoriesArea is not a GridContainer." % i)

	# We now populate from the RunState's master pool, not the Database.
	# This shows the player THEIR collection for this run.
	for tier in RunState.master_run_pool:
		var instances_in_tier = RunState.master_run_pool[tier]
		
		# Tier is 1, 2, or 3. Array is 0-indexed.
		if tier - 1 >= tier_containers.size():
			push_warning("Not enough tier containers for tier %d." % tier)
			continue
			
		var container = tier_containers[tier - 1]

		# We are now looping through INSTANCES, not DEFINITIONS
		for instance in instances_in_tier:
			var scene_to_instance = UnitScene if instance.is_unit() else ItemScene
			
			var new_card = scene_to_instance.instantiate()
			container.add_child(new_card)
			
			# The node is now in the tree, so its onready vars should be accessible.
			if new_card.has_method("initialize"):
				new_card.initialize(instance)
			else:
				push_error("Instanced scene %s does not have an initialize method." % new_card.get_path())
