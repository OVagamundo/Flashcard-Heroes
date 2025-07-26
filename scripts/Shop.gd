# res://scripts/Shop.gd
extends VBoxContainer

const GachaBallViewScene = preload("res://scenes/GachaBallView.tscn")

@onready var slots_container: HBoxContainer = %ShopSlotsContainer
@onready var buy_button: Button = %BuyButton
@onready var reroll_button: Button = %RerollButton
@onready var leave_button: Button = %LeaveButton

var _current_shop_instances: Array = []
var _selected_cost: int = 0
var _price_labels_container: HBoxContainer

func _ready():
	EventBus.selection_changed.connect(_on_selection_changed)
	EventBus.shop_stock_refreshed.connect(populate)

	buy_button.pressed.connect(_on_buy_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	
	# Create price labels container
	_price_labels_container = HBoxContainer.new()
	_price_labels_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_price_labels_container.add_theme_constant_override("separation", 20)
	add_child(_price_labels_container)
	move_child(_price_labels_container, 2)  # Place after slots container
	
	# Add global input handling for closing inspection windows
	gui_input.connect(_on_gui_input)

func populate(context: Dictionary):
	_current_shop_instances = context.get("shop_instances", [])
	var reroll_cost = context.get("reroll_cost", 1)
	reroll_button.text = "Reroll (%d Gold)" % reroll_cost

	# Clear existing price labels
	for child in _price_labels_container.get_children():
		child.queue_free()

	var slot_nodes = slots_container.get_children()

	for i in range(slot_nodes.size()):
		var slot_view = slot_nodes[i]
		for child in slot_view.get_children():
			child.queue_free()

		var loc = LocationIdentifier.new(&"Shop", i)
		slot_view.populate(loc)

		var inst_for_slot = _find_instance_for_slot(i)
		if is_instance_valid(inst_for_slot):
			# Add GachaBallView directly to SlotView (exactly like Reward.gd)
			var gacha_view = GachaBallViewScene.instantiate()
			slot_view.add_child(gacha_view)
			# THE CRITICAL FIX: The last argument must be 'false' to enable double-click inspection.
			gacha_view.populate(loc, inst_for_slot, true, false)
			
			# Add price label below the slot
			var price_label = Label.new()
			price_label.text = "%d Gold" % inst_for_slot.get_definition().tier
			price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			price_label.add_theme_font_size_override("font_size", 12)
			price_label.custom_minimum_size = Vector2(120, 30)
			_price_labels_container.add_child(price_label)
	
	# Don't clear selection here as it might interfere with double-click inspection

func _find_instance_for_slot(slot_index: int) -> GachaBallInstance:
	for inst in _current_shop_instances:
		if is_instance_valid(inst) and inst.get_location().index == slot_index:
			return inst
	return null

func _on_selection_changed(new_location: LocationIdentifier):
	if new_location and new_location.container == &"Shop":
		var instance = _find_instance_for_slot(new_location.index)
		if is_instance_valid(instance):
			_selected_cost = instance.get_definition().tier
			buy_button.text = "Buy (%d Gold)" % _selected_cost
			buy_button.disabled = false
			return

	buy_button.text = "Buy"
	buy_button.disabled = true
	_selected_cost = 0

func _on_buy_pressed():
	var selected_loc = InteractionManager.get_selected_location()
	if selected_loc and selected_loc.container == &"Shop":
		var instance = _find_instance_for_slot(selected_loc.index)
		if is_instance_valid(instance):
			EventBus.emit_signal("shop_purchase_requested", instance.ball_uuid, _selected_cost)

func _on_reroll_pressed():
	EventBus.emit_signal("shop_reroll_requested")

func _on_leave_pressed():
	EventBus.emit_signal("path_choice_scene_requested")
	queue_free()

func _on_gui_input(event: InputEvent):
	# Close inspection windows when clicking on background
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# If we clicked on this scene's background, close inspection windows
		WindowManager.close_all_inspection_windows()
		EventBus.emit_signal("selection_clear_requested") 
