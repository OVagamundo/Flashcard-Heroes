extends Node
class_name BattleManager

const GACHA_BALL_VIEW_SCENE = preload("res://scenes/GachaBallView.tscn")
const CHOICE_PROMPT_UI_SCENE = preload("res://scenes/ChoicePromptUI.tscn")
const DISCARD_PILE_MODAL_SCENE = preload("res://scenes/DiscardPileModal.tscn")
const UNIT_INSPECTION_MODAL_SCENE = preload("res://scenes/UnitInspectionModal.tscn")

# --- Node References (from @export in .tscn) ---
@onready var lineup_container: HBoxContainer = %PlayerLineup
@onready var bench_container: HBoxContainer = %PlayerBench
@onready var item_container: HBoxContainer = %ItemInventory
@onready var discard_pile_button: Button = %DiscardPileButton
@onready var modal_layer: CanvasLayer = %ModalLayer
@onready var reshuffle_button: Button = get_node("UI/BattleArea/TeamAreas/EnemyArea/DrawBallArea/DiscardPileArea/ReshuffleButton")

# --- Battle State ---
var lineup_slots: Array[Node]
var bench_slots: Array[Node]
var item_slots: Array[Node]
var _battle_inventory: Dictionary = {0: [], 1: [], 2: [], 3: []} # Master list for the whole battle
var _draw_pools: Dictionary = {0: [], 1: [], 2: [], 3: []}      # Consumable list for drawing
var _discard_pile: Array[GachaBallInstance] = []
var _pending_action: Dictionary = {}

func _ready():
	lineup_slots = lineup_container.get_children()
	bench_slots = bench_container.get_children()
	item_slots = item_container.get_children()
	_setup_battle()
	_connect_signals()
	EventBus.emit_signal("battle_state_changed", true)

func _exit_tree():
	EventBus.emit_signal("battle_state_changed", false)

func _setup_battle():
	# 1. Get the Hero instance directly from its dedicated property in RunState.
	var hero_run_instance: GachaBallInstance = GameManager.run_state.hero_instance

	# 2. Create the Hero's battle copy and place it directly on the board.
	if is_instance_valid(hero_run_instance):
		var hero_battle_copy = hero_run_instance.create_battle_copy()
		# Add the hero to the master battle inventory, but NOT the draw pool.
		_battle_inventory[0].append(hero_battle_copy)
		_place_instance_in_slot(hero_battle_copy, lineup_slots[0])
	else:
		printerr("CRITICAL: BattleManager could not find the Hero instance in the RunState! The game cannot continue correctly.")

	# 3. Populate battle inventories and draw pools with ONLY the gacha-able units/items.
	for tier in GameManager.run_state.run_inventory:
		for instance in GameManager.run_state.run_inventory[tier]:
			var battle_copy = instance.create_battle_copy()
			# Add to both the master list and the consumable draw pool.
			_battle_inventory[tier].append(battle_copy)
			_draw_pools[tier].append(battle_copy)

	# 4. Final UI update.
	_update_discard_pile_ui()

func _connect_signals():
	# Connect signals for various UI interactions
	EventBus.inventory_action_requested.connect(_on_inventory_action_requested)
	EventBus.choice_made.connect(_on_choice_made)
	EventBus.display_discard_pile_requested.connect(_on_display_discard_pile_requested)
	discard_pile_button.pressed.connect(func(): EventBus.emit_signal("display_discard_pile_requested"))
	EventBus.draw_gacha_requested.connect(_on_draw_gacha_requested)
	EventBus.unit_inspection_requested.connect(_on_unit_inspection_requested)
	reshuffle_button.pressed.connect(_on_reshuffle_requested)

# --- Core Logic Flows ---
func _on_inventory_action_requested(source_view: Control, target_view: Control):
	if GameManager.is_inspecting_inventory: return
	var source_data: GachaBallInstance = source_view.get_instance_data()
	
	if target_view is PanelContainer and not target_view.get_child_count() > 0:
		_handle_move(source_view, target_view)
		return

	if not target_view is GachaBallView:
		EventBus.emit_signal("invalid_action_triggered", source_view)
		return
		
	var target_data: GachaBallInstance = target_view.get_instance_data()
	if not source_data or not target_data:
		EventBus.emit_signal("invalid_action_triggered", source_view)
		return

	var source_def = Database.units.get(source_data.definition_id, Database.items.get(source_data.definition_id))
	var target_def = Database.units.get(target_data.definition_id, Database.items.get(target_data.definition_id))

	if source_def.category == &"ITEM" and target_def.category == &"UNIT":
		_handle_equip(source_view, target_view)
		return
		
	if source_def.category == target_def.category:
		var recipe = MergeManager.find_recipe(source_data.definition_id, target_data.definition_id)
		if recipe:
			_pending_action = {"source": source_view, "target": target_view}
			var prompt = CHOICE_PROMPT_UI_SCENE.instantiate()
			modal_layer.add_child(prompt)
		else:
			_handle_swap(source_view, target_view)
	else:
		EventBus.emit_signal("invalid_action_triggered", source_view)

func _on_choice_made(choice: StringName):
	var source = _pending_action.get("source")
	var target = _pending_action.get("target")
	if not is_instance_valid(source) or not is_instance_valid(target):
		_pending_action.clear()
		return
		
	if choice == &"MERGE": _handle_merge(source, target)
	elif choice == &"SWAP": _handle_swap(source, target)
	_pending_action.clear()

func _on_unit_inspection_requested(unit_view: GachaBallView):
	var modal = UNIT_INSPECTION_MODAL_SCENE.instantiate()
	modal_layer.add_child(modal)
	modal.display_unit(unit_view.get_instance_data(), _battle_inventory)

# --- Action Handlers ---
func _handle_merge(source_view: GachaBallView, target_view: GachaBallView):
	var merged_instance = MergeManager.attempt_merge(source_view.get_instance_data(), target_view.get_instance_data(), _battle_inventory)
	if merged_instance:
		var target_slot = target_view.get_parent()
		source_view.queue_free()
		target_view.queue_free()
		_place_instance_in_slot(merged_instance, target_slot)
	else:
		EventBus.emit_signal("invalid_action_triggered", source_view)

func _handle_swap(source_view: GachaBallView, target_view: GachaBallView):
	var source_parent = source_view.get_parent()
	var target_parent = target_view.get_parent()
	source_parent.remove_child(source_view)
	target_parent.remove_child(target_view)
	source_parent.add_child(target_view)
	target_parent.add_child(source_view)

func _handle_move(source_view: GachaBallView, target_slot: PanelContainer):
	source_view.get_parent().remove_child(source_view)
	target_slot.add_child(source_view)

func _handle_equip(item_view: GachaBallView, unit_view: GachaBallView):
	var item_data = item_view.get_instance_data()
	var unit_data = unit_view.get_instance_data()
	var empty_slot_idx = unit_data.equipped_item_uuids.find("")
	if empty_slot_idx != -1:
		unit_data.equipped_item_uuids[empty_slot_idx] = item_data.ball_uuid
		item_view.queue_free()
	else:
		EventBus.emit_signal("invalid_action_triggered", item_view)

# --- Gacha & Discard Pile ---
func _on_draw_gacha_requested(tier: int):
	if not _draw_pools.has(tier) or _draw_pools[tier].is_empty():
		print("BattleManager: Draw pool for tier %d is empty. Consider reshuffling." % tier)
		return

	var pool = _draw_pools[tier]
	var drawn_instance = pool.pick_random()
	pool.erase(drawn_instance) # Remove from the draw pool, NOT the master inventory.
	
	var definition = Database.units.get(drawn_instance.definition_id, Database.items.get(drawn_instance.definition_id))
	var empty_slot = null
	if definition.category == &"UNIT":
		empty_slot = _find_empty_unit_slot()
	elif definition.category == &"ITEM":
		empty_slot = _find_empty_item_slot()

	if is_instance_valid(empty_slot):
		_place_instance_in_slot(drawn_instance, empty_slot)
	else:
		_discard_pile.append(drawn_instance)
		_update_discard_pile_ui()
		print("BattleManager: No empty slot found. Discarding ", drawn_instance.definition_id)

func _on_display_discard_pile_requested():
	var modal = DISCARD_PILE_MODAL_SCENE.instantiate()
	modal.discard_pile_data = self._discard_pile
	modal_layer.add_child(modal)

func _on_reshuffle_requested():
	if _discard_pile.is_empty():
		print("Reshuffle requested, but discard pile is empty.")
		return

	print("Reshuffling %d items from discard pile into draw pools." % _discard_pile.size())
	for instance in _discard_pile:
		var definition = Database.units.get(instance.definition_id, Database.items.get(instance.definition_id))
		if definition:
			if _draw_pools.has(definition.tier):
				_draw_pools[definition.tier].append(instance)
			else:
				printerr("BattleManager: Cannot reshuffle instance '%s' to a non-existent tier pool: %d" % [instance.definition_id, definition.tier])
		else:
			printerr("BattleManager: Could not find definition for instance '%s' during reshuffle." % instance.definition_id)
	
	_discard_pile.clear()
	_update_discard_pile_ui()

func _update_discard_pile_ui():
	discard_pile_button.text = "DISCARD PILE (%d)" % _discard_pile.size()

# --- Helper Functions ---
func _find_empty_unit_slot() -> PanelContainer:
	for slot in bench_slots:
		if slot.get_child_count() == 0: return slot
	for slot in lineup_slots:
		# Don't overwrite the hero in slot 0 if it's there
		if slot.get_child_count() > 0 and slot.get_child(0).get_instance_data().definition_id == &"hero":
			continue
		if slot.get_child_count() == 0: return slot
	return null

func _find_empty_item_slot() -> PanelContainer:
	for slot in item_slots:
		if slot.get_child_count() == 0: return slot
	return null

func _place_instance_in_slot(instance_data: GachaBallInstance, slot_node: Node):
	var view = GACHA_BALL_VIEW_SCENE.instantiate()
	slot_node.add_child(view)
	view.set_instance_data(instance_data)

# --- Public Getters ---
func get_draw_pools() -> Dictionary:
	return _draw_pools

func _find_instance_by_uuid(uuid: String) -> GachaBallInstance:
	for tier in _battle_inventory:
		for instance in _battle_inventory[tier]:
			if instance.ball_uuid == uuid:
				return instance
	return null
