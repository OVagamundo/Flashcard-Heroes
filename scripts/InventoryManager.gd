# res://scripts/InventoryManager.gd
extends Node

const C = preload("res://scripts/Constants.gd")
const AC = preload("res://scripts/animations/AnimationConstants.gd")

func _ready() -> void:
	SignalBus.try_inventory_action.connect(_on_try_inventory_action)
	SignalBus.choice_made.connect(_on_choice_made)

# --- Main Action Handler ---

func _on_try_inventory_action(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> void:
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		GlobalInteractionRouter.end_drag(false)
		return

	# Early-case: Allow equipping items onto units even across functional groups
	var early_source_instance = _get_instance_at_location(source_loc)
	var early_target_instance = _get_instance_at_location(target_loc)
	if is_instance_valid(early_source_instance) and is_instance_valid(early_target_instance):
		var sdef = early_source_instance.get_definition()
		var tdef = early_target_instance.get_definition()
		
		# Early-case: Consumable usage on a specific unit
		if sdef.category == C.CATEGORY_CONSUMABLE and tdef.category == C.CATEGORY_UNIT:
			# Allow consumables on both Player and Enemy units (regardless of test mode)
			var allowed_consumable_containers = [&"PlayerLineup", &"PlayerBench", &"EnemyLineup"]
			if target_loc.container in allowed_consumable_containers:
				_use_consumable(early_source_instance, early_target_instance)
				return
		
		# Rule I3: Allow equipping from InventoryGrid or BattleBoard (PlayerBench) onto a UNIT on the board
		var s_group = GlobalInteractionRouter.get_context_group(source_loc.container)
		var allowed_containers = [&"PlayerLineup", &"PlayerBench"]
		# In test mode, also allow equipping on enemy units
		if GameManager.is_test_mode:
			allowed_containers.append(&"EnemyLineup")
		
		# Items can be equipped from InventoryGrid OR BattleBoard (unified bench holds both units and items)
		var is_valid_source = s_group == &"InventoryGrid" or s_group == &"BattleBoard" or s_group == &"EquippedGrid"
		if sdef.category == &"ITEM" and tdef.category == &"UNIT" and is_valid_source and target_loc.container in allowed_containers:
			# Use atomic equip API
			var owner = _get_data_owner()
			if is_instance_valid(owner):
				owner.equip_item(early_source_instance.ball_uuid, early_target_instance.ball_uuid, -1)
			GlobalInteractionRouter.end_drag(true)
			SignalBus.emit_signal("inventory_action_completed", [early_target_instance.ball_uuid])
			return

	# Early-case: Allow equipping items by dropping onto an equipped_item slot (empty or same-unit slot)
	if is_instance_valid(early_source_instance) and target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var sdef2 = early_source_instance.get_definition()
		if sdef2.category == &"ITEM":
			var data_owner = _get_data_owner()
			if is_instance_valid(data_owner):
				var parent_unit: GachaBallInstance = data_owner.get_all_instances().get(target_loc.unit_uuid)
				if is_instance_valid(parent_unit):
					# If slot already occupied, fall through to swap/merge logic later
					var slot_is_empty = true
					if target_loc.index < parent_unit.equipped_item_uuids.size():
						slot_is_empty = parent_unit.equipped_item_uuids[target_loc.index].is_empty()
					
					if slot_is_empty:
						# Rule I3: Allow equipping into equipped_item from InventoryGrid or BattleBoard.
						var s_group2 = GlobalInteractionRouter.get_context_group(source_loc.container)
						var is_valid_source2 = s_group2 == &"InventoryGrid" or s_group2 == &"BattleBoard" or s_group2 == &"EquippedGrid"
						if is_valid_source2:
							# Use atomic equip with explicit slot
							data_owner.equip_item(early_source_instance.ball_uuid, parent_unit.ball_uuid, target_loc.index)
							GlobalInteractionRouter.end_drag(true)
							SignalBus.emit_signal("inventory_action_completed", [parent_unit.ball_uuid])
							return

	# TDD 4.3.IV: Check for invalid actions between incompatible contexts
	var source_context_group = GlobalInteractionRouter.get_context_group(source_loc.container)
	var target_context_group = GlobalInteractionRouter.get_context_group(target_loc.container)
	# SelectionOnly contexts (Shop/Rewards): all inventory actions are invalid by design.
	# Cancel drag immediately so the original sprite reappears and nothing moves.
	if source_context_group == &"SelectionOnly" or target_context_group == &"SelectionOnly":
		SignalBus.emit_signal("inventory_action_invalid", source_loc, target_loc)
		GlobalInteractionRouter.end_drag(false)
		return
	
	# If contexts are incompatible, this is an invalid action
	if source_context_group != target_context_group:
		# Exception: Allow InventoryGrid -> equipped_item (click-to-click equip)
		if source_context_group == &"InventoryGrid" and target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
			# Allowed exception; fall through to normal handling below
			pass
		else:
			# Special case: Selection-Only contexts allow changing selection
			if target_context_group == &"SelectionOnly":
				# We shouldn't reach here, but if we do, it's invalid
				SignalBus.emit_signal("inventory_action_invalid", source_loc, target_loc)
				GlobalInteractionRouter.end_drag(false)
				return
			else:
				# Incompatible contexts - invalid action
				SignalBus.emit_signal("inventory_action_invalid", source_loc, target_loc)
				GlobalInteractionRouter.end_drag(false)
				return
	
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)

	if not is_instance_valid(source_instance):
		GlobalInteractionRouter.end_drag(false)
		return

	if not is_instance_valid(target_instance):
		if is_valid_placement(source_instance, target_loc):
			_move(source_loc, target_loc)
			GlobalInteractionRouter.end_drag(true)
		else:
			# The placement is invalid. Report it.
			SignalBus.emit_signal("inventory_action_invalid", source_loc, target_loc)
			GlobalInteractionRouter.end_drag(false)
		return

	var source_def = source_instance.get_definition()
	var target_def = target_instance.get_definition()

	var data_owner: Object = _get_data_owner()
	if not is_instance_valid(data_owner): return
	var all_instances_db = data_owner.get_all_instances()

	# Case 3: Same-slot drop (return to original position) - trigger bounce, no action
	# Must be checked BEFORE merge to avoid self-merge edge cases
	if source_loc.container == target_loc.container and source_loc.index == target_loc.index:
		SignalBus.emit_signal("inventory_action_completed", [source_instance.ball_uuid])
		# Return unhandled (false) so GIR unhides the source view immediately
		GlobalInteractionRouter.end_drag(false)
		return

	# Case 4: Possible Merge
	var recipe = MergeManager.find_recipe(source_instance, target_instance, source_loc, target_loc, all_instances_db)
	if is_instance_valid(recipe):
		var context: Dictionary = {"source_location": source_loc, "target_location": target_loc, "recipe_id": recipe.id}
		
		# VISUAL FIX: Hide the source view so it doesn't snap back while the prompt is open.
		# CRITICAL: Use GIR's known source view, NOT WindowManager lookup (which might find placeholders/wrong views).
		var source_view = GlobalInteractionRouter.get_drag_source_view()
		if is_instance_valid(source_view):
			source_view.visible = false
			context["source_view_id"] = source_view.get_instance_id()
			
		# ORDER FIX: End drag FIRST to clear old state/locks.
		# Pass true (handled) so GIR doesn't restore visibility or play sounds yet.
		GlobalInteractionRouter.end_drag(true)
		
		# LOCK FIX: Open window SECOND. Its _ready() will request a NEW lock.
		# If we opened first, end_drag would clear the lock we just requested.
		WindowManager.open_choice_window(context)
		return


	# Case 5: Possible Swap
	if is_valid_placement(source_instance, target_loc) and is_valid_placement(target_instance, source_loc):
		_swap(source_loc, target_loc)
		GlobalInteractionRouter.end_drag(true)
		return

	# If we reach the end and no valid action was found, report it.
	SignalBus.emit_signal("inventory_action_invalid", source_loc, target_loc)
	GlobalInteractionRouter.end_drag(false)


func _on_choice_made(choice: StringName, source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName) -> void:
	if not is_instance_valid(source_loc) or not is_instance_valid(target_loc):
		return
	# Activate suppression via GIR for the parent inspection window of the target (or source) view
	# to avoid premature closure during swap/merge execution triggered by ChoiceWindow.
	var wm = WindowManager
	var anchor_view: Control = wm.find_view_for_location(target_loc)
	if not is_instance_valid(anchor_view):
		anchor_view = wm.find_view_for_location(source_loc)
	var parent_window: Control = wm.find_ancestor_window_for_view(anchor_view) if is_instance_valid(anchor_view) else null
	var parent_id: int = parent_window.get_instance_id() if is_instance_valid(parent_window) else -1
	var inside_unit: bool = target_loc.container == C.CONTAINER_EQUIPPED_ITEM or target_loc.container in [&"PlayerLineup", &"PlayerBench"]
	if parent_id != -1:
		# Note: Using GIR's suppression helper to ensure WindowManager.request_close_inspection_window honors it.
		GlobalInteractionRouter.activate_close_suppression_for_window_id(parent_id, 420 if inside_unit else 320)

	match choice:
		&"MERGE":
			_merge(source_loc, target_loc, recipe_id)
		&"SWAP":
			_swap(source_loc, target_loc)

func _use_consumable(consumable_instance: GachaBallInstance, target_unit: GachaBallInstance) -> void:
	var def = consumable_instance.get_definition()
	if not def or def.ability_definitions.is_empty():
		GlobalInteractionRouter.end_drag(false)
		return
	
	var ability = def.ability_definitions[0]
	# ARCHITECTURE: Unified Queue System
	# Instead of manually executing effects, we enqueue an EffectRequest and let BattleManager
	# process it through the standard pipeline (Simulation -> Truth -> Animation).
	# This ensures Priority, Triggers (Echo), and State Consistency are handled identically to combat.
	
	var is_battle = GameManager.is_in_battle
	var bm = null
	if is_battle:
		bm = get_tree().get_first_node_in_group("battle_manager")
	
	if not is_battle or not is_instance_valid(bm):
		# Fallback for Run State (outside battle) - simplistic execution
		# (RunState logic dictates this, but usually consumables are used in Battle/Shop)
		_use_consumable_simple(consumable_instance, target_unit)
		return

	# 1. Block UI Updates (Prevent Scene Tree thrashing during logic)
	if bm.has_method("block_ui_updates"):
		bm.block_ui_updates()
	
	# 2. Capture Snapshot (Includes Consumable + Target)
	var snapshot = VisualDataAdapter.create_board_snapshot(bm.get_all_instances())
	
	# 3. Enqueue EffectRequests (Truth Pending)
	# The consumable instance MUST remain valid during enqueue_effect_request and subsequent resolution
	# because CombatSimulator checks is_instance_valid(source).
	# We will consume (remove) the item only AFTER logic is processed.
	
	var consumable_uuid = consumable_instance.ball_uuid
	var owner = _get_data_owner()
	
	var targets: Array[String] = [target_unit.ball_uuid]
	var any_success = false
	
	for effect in ability.effects:
		if not is_instance_valid(effect): continue
		
		# Create minimal context for the request
		var trig_context = {
			"source_category": &"ITEM",
			"source_holder_uuid": target_unit.ball_uuid,
		}
		
		# Construct Request
		var req = EffectRequest.new(
			target_unit.ball_uuid, # Source is the UNIT (Visual Preference: Self-Cast)
			ability.id,
			effect,
			targets,
			trig_context,
			0 # Priority 0 for manual action
		)
		
		bm.enqueue_effect_request(req)
		any_success = true
		
	if any_success:
		# AUDIO HOOK: Consumable usage sound
		Audio.play_sfx("ui_heal")
		
		# 4. Consume the Item (Truth) - IMMEDIATELY (Before Animation)
		owner.remove_instance(consumable_uuid)
		GlobalInteractionRouter.end_drag(true)
		SignalBus.emit_signal("inventory_action_completed", [target_unit.ball_uuid])

		# 5. Resolve & Animate (Standard Pipeline)
		# This async call processes the effect
		await bm.resolve_management_effects_and_animate(snapshot)
		
	else:
		SignalBus.emit_signal("inventory_action_invalid", consumable_instance.get_location(), target_unit.get_location())
		GlobalInteractionRouter.end_drag(false)

		
	# 6. Unblock UI (Refreshes Inventory Grid)
	if bm.has_method("unblock_ui_updates"):
		bm.unblock_ui_updates()

func _use_consumable_simple(_consumable_instance: GachaBallInstance, _target_unit: GachaBallInstance) -> void:
	# Fallback for non-battle state (rare)
	pass

# --- Core Logic Functions ---

func _move(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> void:
	var instance_to_move = _get_instance_at_location(source_loc)
	if not is_instance_valid(instance_to_move): return

	# Special-case: moving an item into an equipped slot on a unit.
	if target_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		var data_owner = _get_data_owner()
		if not is_instance_valid(data_owner): return
		var parent_unit: GachaBallInstance = data_owner.get_all_instances().get(target_loc.unit_uuid)
		if is_instance_valid(parent_unit):
			# Atomic equip handles removal and signaling
			data_owner.equip_item(instance_to_move.ball_uuid, parent_unit.ball_uuid, target_loc.index)
			SignalBus.emit_signal("selection_clear_requested")
			SignalBus.emit_signal("inventory_action_completed", [parent_unit.ball_uuid])
			return

	# Default move behaviour for normal containers
	var owner = _get_data_owner()
	if not is_instance_valid(owner): return
	
	owner.move_instance(source_loc, target_loc)
	SignalBus.emit_signal("selection_clear_requested")
	SignalBus.emit_signal.call_deferred("inventory_action_completed", [instance_to_move.ball_uuid])

func _swap(source_loc: LocationIdentifier, target_loc: LocationIdentifier) -> void:
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner): return
	
	var all_instances_db = data_owner.get_all_instances()
	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)
	if not is_instance_valid(source_instance) or not is_instance_valid(target_instance): return

	# Use atomic swap APIs
	data_owner.swap_instances(source_loc, target_loc)

	SignalBus.emit_signal("selection_clear_requested")
	SignalBus.emit_signal.call_deferred("inventory_action_completed", [source_instance.ball_uuid, target_instance.ball_uuid])

func _equip_item(item_instance: GachaBallInstance, unit_instance: GachaBallInstance) -> void:
	if not is_instance_valid(item_instance) or not is_instance_valid(unit_instance):
		# We need the locations for the invalid action, but we don't have them here.
		# This is a rare case where the equip logic itself fails.
		GlobalInteractionRouter.end_drag(false)
		SignalBus.emit_signal("selection_clear_requested")
		return

	# Restrict: If the item is already equipped on a unit, it may only be
	# re-equipped on THE SAME unit (i.e., moving between slots). Otherwise block.
	if not item_instance.equipped_on_uuid.is_empty() and item_instance.equipped_on_uuid != unit_instance.ball_uuid:
		# We need the locations for the invalid action, but we don't have them here.
		# This is a rare case where the equip logic itself fails.
		GlobalInteractionRouter.end_drag(false)
		SignalBus.emit_signal("selection_clear_requested")
		return

	var empty_slot_idx = unit_instance.equipped_item_uuids.find("")
	if empty_slot_idx == -1 and unit_instance.equipped_item_uuids.is_empty():
		# We need the locations for the invalid action, but we don't have them here.
		# This is a rare case where the equip logic itself fails.
		GlobalInteractionRouter.end_drag(false)
		SignalBus.emit_signal("selection_clear_requested")
		return
	if empty_slot_idx == -1:
		empty_slot_idx = 0

	# Use atomic equip API (slot resolved above)
	var owner = _get_data_owner()
	if is_instance_valid(owner):
		owner.equip_item(item_instance.ball_uuid, unit_instance.ball_uuid, empty_slot_idx)
	SignalBus.emit_signal("selection_clear_requested")

func _merge(source_loc: LocationIdentifier, target_loc: LocationIdentifier, recipe_id: StringName) -> void:
	var source_view = WindowManager.find_view_for_location(source_loc)
	var target_view = WindowManager.find_view_for_location(target_loc)
	var start_pos = target_view.get_global_rect().get_center() if is_instance_valid(target_view) else Vector2.ZERO

	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner): return

	var all_instances_db = data_owner.get_all_instances()

	var source_instance = _get_instance_at_location(source_loc)
	var target_instance = _get_instance_at_location(target_loc)
	if not is_instance_valid(source_instance) or not is_instance_valid(target_instance): return

	# --- MERGE ENCOUNTER LOGIC ---
	if MergeManager.is_merge_encounter_active():
		if not is_instance_valid(GameManager.run_state) or GameManager.run_state.gold < 5:
			# Play rejection feedback
			var RejectionFeedbackScript = load("res://scripts/vfx/RejectionFeedback.gd")
			var main_node = GameManager._active_main_node
			var gold_group = main_node.get_node_or_null("%GoldGroup") if is_instance_valid(main_node) else null
			RejectionFeedbackScript.play_rejection_with_counter(target_view, gold_group, get_tree())
			return

	var merge_result = MergeManager.calculate_merge_result(source_instance, target_instance, source_loc, target_loc, all_instances_db)
	if merge_result.is_empty():
		return

	var new_instance: GachaBallInstance = merge_result["merged_instance"]
	var result_def = new_instance.get_definition()
	if not is_instance_valid(result_def): return

	# Collect items equipped on parents (if any) to equip onto a UNIT result later
	# MergeManager returns the list of items that should be equipped.
	var all_parent_items: Array = merge_result.get("items_to_equip", [])
	var parent_items_to_discard: Array = merge_result.get("items_to_discard", [])

	# PREPARATION: Hide originals and show the result VFX ball at the merge site
	# This ensures the user sees the result while coins are flying.
	_set_unit_view_visible(source_view, false)
	_set_unit_view_visible(target_view, false)
	
	var vfx_ball = _create_vfx_ball(new_instance, start_pos)

	# DATA MUTATION: Perform all backend changes immediately so they are batched into a single UI refresh
	if MergeManager.is_merge_encounter_active() and is_instance_valid(GameManager.run_state):
		GameManager.run_state.spend_gold(5)
		GameManager.run_state.unlock_recipe_for_result(result_def.id)

	# Context-aware placement logic
	var source_is_equipped = source_loc.container == C.CONTAINER_EQUIPPED_ITEM
	var target_is_equipped = target_loc.container == C.CONTAINER_EQUIPPED_ITEM
	var is_board_merge = target_loc.container.begins_with("Player")
	var placed_container: StringName = &""
	var placed_index: int = -1

	var is_same_unit_item_merge := source_is_equipped and target_is_equipped and source_loc.unit_uuid == target_loc.unit_uuid
	if not is_same_unit_item_merge:
		data_owner.remove_instance(source_instance.ball_uuid)
		data_owner.remove_instance(target_instance.ball_uuid)

	if is_same_unit_item_merge:
		data_owner.remove_instance(source_instance.ball_uuid)
		data_owner.remove_instance(target_instance.ball_uuid)
		data_owner.add_instance(new_instance, &"PlayerBench", -1)
		data_owner.equip_item(new_instance.ball_uuid, target_loc.unit_uuid, target_loc.index)
		placed_container = C.CONTAINER_EQUIPPED_ITEM
		placed_index = target_loc.index
	elif is_board_merge:
		data_owner.add_instance(new_instance, target_loc.container, target_loc.index)
		placed_container = target_loc.container
		placed_index = target_loc.index
	elif ("tier" in result_def) and ("tier" in source_instance.get_definition()) and result_def.tier > source_instance.get_definition().tier:
		var prefix = "BattleInventoryT" if GameManager.is_in_battle else "RunInventoryT"
		var new_container_tag = &"%s%d" % [prefix, result_def.tier]
		data_owner.add_instance(new_instance, new_container_tag, -1)
		placed_container = new_container_tag
		placed_index = -1
	else:
		data_owner.add_instance(new_instance, target_loc.container, target_loc.index)
		placed_container = target_loc.container
		placed_index = target_loc.index

	if result_def.category == &"UNIT":
		var max_slots = new_instance.equipped_item_uuids.size()
		for i in range(min(all_parent_items.size(), max_slots)):
			var it: GachaBallInstance = all_parent_items[i]
			if is_instance_valid(it):
				data_owner.equip_item(it.ball_uuid, new_instance.ball_uuid, i)

	for discarded_item in parent_items_to_discard:
		if is_instance_valid(discarded_item):
			if GameManager.is_in_battle and data_owner.has_method("bm_move_instance_to_discard"):
				data_owner.bm_move_instance_to_discard(discarded_item.ball_uuid)
			else:
				data_owner.remove_instance(discarded_item.ball_uuid)

	# REFRESH: Wait for exactly one frame for the data changes to propagate to UI
	# and for the VFX ball's layout to be ready for animation.
	await get_tree().process_frame
	
	# BOUNCE: Satisfy "merged unit bounce animation should also happen when it first appears"
	vfx_ball.play_landing_bounce()
	
	# HIDE: Ensure the real result unit (newly appeared in its slot) is hidden during the VFX sequence
	var final_loc = LocationIdentifier.new(new_instance.location_container_tag, new_instance.location_slot_index)
	var final_view = WindowManager.find_view_for_location(final_loc)
	_set_unit_view_visible(final_view, false)

	# AUDIO: Play merge sound
	Audio.play_sfx("ui_merge")

	# COINS: Animate gold if applicable
	if MergeManager.is_merge_encounter_active():
		await _animate_merge_gold_deduction(target_loc)

	# Trigger management-phase on_merge abilities for battle-board merges only.
	# This covers lineup/bench merges and same-unit equipped item merges on board.
	var should_trigger_on_merge: bool = false
	var merge_container_tag: StringName = &""
	if GameManager.is_in_battle:
		if is_same_unit_item_merge:
			var parent_unit: GachaBallInstance = data_owner.get_all_instances().get(target_loc.unit_uuid)
			if is_instance_valid(parent_unit) and _is_battle_board_container(parent_unit.location_container_tag):
				should_trigger_on_merge = true
				merge_container_tag = parent_unit.location_container_tag
		elif _is_battle_board_container(target_loc.container):
			should_trigger_on_merge = true
			merge_container_tag = target_loc.container

	var merge_team: String = _get_team_for_board_container(merge_container_tag)

	# Clear selection at the end for UX consistency
	SignalBus.emit_signal("selection_clear_requested")
	
	# Transition: Wait for UI to refresh then perform arc toss
	await get_tree().process_frame
	
	if is_instance_valid(final_view) and not start_pos.is_zero_approx():
		await _animate_vfx_ball_toss(vfx_ball, final_view, new_instance)
	else:
		if is_instance_valid(vfx_ball): vfx_ball.queue_free()
		SignalBus.emit_signal.call_deferred("inventory_action_completed", [new_instance.ball_uuid])

	if should_trigger_on_merge:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(bm):
			# Let queue_free/redraw settle so animator registers the latest merged views.
			await get_tree().process_frame
			var snapshot: Dictionary = bm.get_board_snapshot()
			if bm.has_method("block_ui_updates"):
				bm.block_ui_updates()
			var merge_context: Dictionary = {
				"merged_uuid": new_instance.ball_uuid,
				"merged_team": merge_team,
				"merge_container": merge_container_tag,
				"merge_category": result_def.category
			}
			AbilityResolver.process_trigger(&"on_merge", merge_context)
			var pending_count: int = 0
			if bm.has_method("get_pending_reactions_size"):
				pending_count = int(bm.get_pending_reactions_size())
			else:
				pending_count = int(bm._pending_reactions.size())
			if pending_count > 0:
				await bm.resolve_management_effects_and_animate(snapshot)
			if bm.has_method("unblock_ui_updates"):
				bm.unblock_ui_updates()

func _animate_merge_gold_deduction(target_loc: LocationIdentifier) -> void:
	var target_view = WindowManager.find_view_for_location(target_loc)
	if not is_instance_valid(target_view): return
	
	var end_pos = target_view.get_global_rect().get_center()
	
	var main_node = GameManager._active_main_node
	if not is_instance_valid(main_node): return
	var gold_group = main_node.get_node_or_null("%GoldGroup")
	if not is_instance_valid(gold_group): return
	var gold_icon = gold_group.get_node_or_null("GoldIcon")
	if not is_instance_valid(gold_icon): gold_icon = gold_group
	var gold_rect = gold_icon.get_global_rect()
	var start_pos = Vector2(
		gold_rect.position.x + gold_rect.size.x / 2,
		gold_rect.position.y + gold_rect.size.y / 2
	)
	
	var GoldCoinVFXScript = load("res://scripts/vfx/GoldCoinVFX.gd")
	var coins_to_spawn = 5
	var stagger_delay = 0.08
	for i in range(coins_to_spawn):
		var coin_vfx = GoldCoinVFXScript.new()
		var effects_layer = WindowManager.get_vfx_layer()
		effects_layer.add_child(coin_vfx)
		coin_vfx.coin_landed.connect(func(_pos: Vector2):
			Audio.play_sfx("coin_land")
		)
		var offset = Vector2(randf_range(-15, 15), randf_range(-8, 8))
		coin_vfx.play(start_pos + offset, end_pos, i * stagger_delay)
		Audio.play_sfx("coin_spawn", 1.0 + (i * 0.05))
		
	# Await completion (stagger + flight time)
	var total_wait = (coins_to_spawn - 1) * stagger_delay + 0.55
	await get_tree().create_timer(total_wait).timeout

func _create_vfx_ball(instance: GachaBallInstance, global_pos: Vector2) -> GachaBallView:
	var VisualDataAdapter = load("res://scripts/VisualDataAdapter.gd")
	var visual_data = VisualDataAdapter.create_visual_data(instance)
	var anim_ball = preload("res://scenes/GachaBallView.tscn").instantiate()
	var effects_layer = WindowManager.get_vfx_layer()
	effects_layer.add_child(anim_ball)
	
	anim_ball.force_inventory_mode = true
	# CRITICAL: Set size scale to 1.0 (inventory) and fix dimensions before populate
	# to ensure stat labels and icons are correctly positioned.
	if anim_ball.has_method("set_size_scale"):
		anim_ball.set_size_scale(1.0)
	
	anim_ball.custom_minimum_size = Vector2(C.SLOT_SIZE_BASE, C.SLOT_SIZE_BASE)
	anim_ball.size = Vector2(C.SLOT_SIZE_BASE, C.SLOT_SIZE_BASE)
	
	anim_ball.populate(null, visual_data, false)
	anim_ball.set_is_interactive(false)
	
	var pivot = anim_ball.size / 2.0
	anim_ball.global_position = global_pos - pivot
	return anim_ball

func _set_unit_view_visible(slot_view: Control, is_visible: bool) -> void:
	if not is_instance_valid(slot_view): return
	for child in slot_view.get_children():
		if child is GachaBallView:
			child.visible = is_visible
			break

func _animate_vfx_ball_toss(vfx_ball: GachaBallView, target_slot: Control, instance: GachaBallInstance) -> void:
	if not is_instance_valid(target_slot) or not is_instance_valid(vfx_ball): 
		if is_instance_valid(vfx_ball): vfx_ball.queue_free()
		return
	
	var start_pos = vfx_ball.global_position + (vfx_ball.size / 2.0)
	var end_pos = target_slot.get_global_rect().get_center()
	
	# If start and end are too close, just trigger bounce and return
	if start_pos.distance_to(end_pos) < 20.0:
		vfx_ball.queue_free()
		SignalBus.emit_signal("inventory_action_completed", [instance.ball_uuid])
		return
		
	# Hide the real ball view in the target slot
	var real_ball_view: GachaBallView = null
	for child in target_slot.get_children():
		if child is GachaBallView:
			real_ball_view = child
			break
	
	if is_instance_valid(real_ball_view):
		real_ball_view.visible = false
		target_slot.visible = true

	# Animate Arc (Kinematic Parabola)
	var arc_height = clamp(start_pos.distance_to(end_pos) * 0.5, 80.0, 300.0)
	var duration = 0.55
	
	var control_point = Vector2(
		(start_pos.x + end_pos.x) / 2.0,
		min(start_pos.y, end_pos.y) - arc_height
	)
	
	var tween = vfx_ball.create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	
	Audio.play_sfx("unit_toss")
	
	var pivot = vfx_ball.size / 2.0
	tween.tween_method(func(t: float):
		if not is_instance_valid(vfx_ball): return
		var eased_t = pow(t, 1.05)
		var inv_t = 1.0 - eased_t
		var pos = (inv_t * inv_t * start_pos) + \
				  (2.0 * inv_t * eased_t * control_point) + \
				  (eased_t * eased_t * end_pos)
		vfx_ball.global_position = pos - pivot
	, 0.0, 1.0, duration)
	
	await tween.finished
	
	# Cleanup
	if is_instance_valid(vfx_ball): vfx_ball.queue_free()
	if is_instance_valid(real_ball_view):
		real_ball_view.visible = true
		real_ball_view.play_landing_bounce()
	
# --- Single-Responsibility Helpers ---

func _perform_equip(item_instance: GachaBallInstance, unit_instance: GachaBallInstance, target_item_slot: int) -> void:
	if not is_instance_valid(item_instance) or not is_instance_valid(unit_instance): return

	# If the item was previously equipped on another unit, unequip its bonus from that unit
	if not item_instance.equipped_on_uuid.is_empty() and item_instance.equipped_on_uuid != unit_instance.ball_uuid:
		var data_owner = _get_data_owner()
		if is_instance_valid(data_owner):
			var prev_unit: GachaBallInstance = data_owner.get_all_instances().get(item_instance.equipped_on_uuid)
			if is_instance_valid(prev_unit):
				prev_unit.unequip_item_bonus(item_instance)

	# If the item was previously equipped on this unit, unequip from old slot
	if item_instance.equipped_on_uuid == unit_instance.ball_uuid:
		unit_instance.unequip_item_bonus(item_instance)

	item_instance.equipped_on_uuid = unit_instance.ball_uuid
	item_instance.equipped_slot_index = target_item_slot
	item_instance.location_container_tag = &""
	item_instance.location_slot_index = -1

	if target_item_slot < unit_instance.equipped_item_uuids.size():
		unit_instance.equipped_item_uuids[target_item_slot] = item_instance.ball_uuid

	# Equip the bonus to the new unit
	unit_instance.equip_item_bonus(item_instance)

	SignalBus.emit_signal("unit_inventory_changed", unit_instance.ball_uuid)

# --- Other Helpers ---

func _is_battle_board_container(container_tag: StringName) -> bool:
	return (
		container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP
		or container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH
		or container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP
		or container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH
	)

func _get_team_for_board_container(container_tag: StringName) -> String:
	if container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_LINEUP or container_tag == C.BATTLE_CONTAINER_TAGS.PLAYER_BENCH:
		return "PLAYER"
	if container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_LINEUP or container_tag == C.BATTLE_CONTAINER_TAGS.ENEMY_BENCH:
		return "ENEMY"
	return ""

## Check if placing an instance into a target location is valid
## Made public for SlotIndicatorController to reuse this validation logic
func is_valid_placement(instance_to_check: GachaBallInstance, target_loc: LocationIdentifier) -> bool:
	if not is_instance_valid(instance_to_check): return true

	var def = instance_to_check.get_definition()
	var target_container_name = target_loc.container

	# ------------------------------------------------------------------
	# HERO RESTRICTION: Heroes may only reside in PlayerLineup.
	var is_hero := String(def.id).to_lower() == "hero"
	if "is_hero" in def and def.is_hero:
		is_hero = true

	if not is_hero and "tags" in def:
		for tag in def.tags:
			if String(tag).to_lower() == "hero":
				is_hero = true
				break
	if is_hero:
		return target_container_name == &"PlayerLineup"

	# ------------------------------------------------------------------
	# EQUIPPED ITEM RESTRICTIONS
	var source_loc := instance_to_check.get_location()

	# 1. If the item is currently equipped, it cannot be moved anywhere except
	#    another slot on the SAME parent unit.
	if source_loc and source_loc.container == C.CONTAINER_EQUIPPED_ITEM:
		return target_container_name == C.CONTAINER_EQUIPPED_ITEM and target_loc.unit_uuid == source_loc.unit_uuid

	# 2. If the target is an equipped_item container, only allow equipping
	#    from PlayerBench or InventoryGrid (Rule I3). All actual equipping is handled in the
	#    early equip path; general placement into equipped_item is otherwise illegal.
	if target_container_name == C.CONTAINER_EQUIPPED_ITEM:
		var s_group = GlobalInteractionRouter.get_context_group(source_loc.container)
		return source_loc.container == &"PlayerBench" or s_group == &"InventoryGrid" or s_group == &"EquippedGrid"


	if target_container_name.begins_with("RunInventoryT"):
		var container_tier = target_container_name.substr(len("RunInventoryT")).to_int()
		# Definitions without 'tier' (e.g., TrinketDefinition) are not allowed in tiered inventory containers
		if not ("tier" in def) or def.tier != container_tier:
			return false
	if target_container_name.begins_with("BattleInventoryT"):
		var container_tier_b = target_container_name.substr(len("BattleInventoryT")).to_int()
		# Definitions without 'tier' (e.g., TrinketDefinition) are not allowed in tiered inventory containers
		if not ("tier" in def) or def.tier != container_tier_b:
			return false

	# Items and Consumables cannot be placed in lineup containers (only bench and equipped slots)
	if (target_container_name == &"PlayerLineup" or target_container_name == &"EnemyLineup") and \
		(def.category == &"ITEM" or def.category == &"CONSUMABLE"):
		return false

	return true

func _get_instance_at_location(loc: LocationIdentifier) -> GachaBallInstance:
	return GameManager.get_instance_from_location(loc)

func _get_data_owner() -> Object:
	if GameManager.is_in_battle:
		return get_tree().get_first_node_in_group("battle_manager")
	else:
		return GameManager.run_state

func _emit_data_changed_signal() -> void:
	var signal_name = "battle_inventory_changed" if GameManager.is_in_battle else "run_data_changed"
	SignalBus.emit_signal(signal_name)
	SignalBus.emit_signal("inventory_ui_refresh_requested")

# --- Golden Rule Validation Helpers ---

func _validate_state_consistency() -> bool:
	"""Validates that the index and truth are synchronized across all instances"""
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner):
		return false
	
	var all_instances = data_owner.get_all_instances()
	
	for instance_uuid in all_instances:
		var instance = all_instances[instance_uuid]
		var location = instance.get_location()
		
		# Skip equipped items (they have special handling)
		if location.container == C.CONTAINER_EQUIPPED_ITEM:
			continue
			
		var container = data_owner.get_container(location.container)
		if not is_instance_valid(container):
			continue
			
		if container.get_uuid(location.index) != instance_uuid:
			push_error("State inconsistency detected: Instance %s location mismatch" % instance_uuid)
			return false
	
	return true

func _atomic_move_instance(instance: GachaBallInstance, from_loc: LocationIdentifier, to_loc: LocationIdentifier) -> void:
	"""Performs an atomic move using centralized atomic APIs"""
	var owner = _get_data_owner()
	if not is_instance_valid(owner):
		return
	owner.move_instance(from_loc, to_loc)
	# Optional extra validation (atomic APIs already validate in debug builds)
	if OS.is_debug_build():
		_validate_state_consistency()
