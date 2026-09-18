# Module 1: The Godot Global Architecture

## The Event-Driven Pipeline

To understand how our game communicates globally, let's look at a concrete example: **A player purchasing an item in the Shop**. Notice how the Shop Scene *never* directly talks to the Inventory UI or the GameManager. Everything is routed through the Communication Layer.

```mermaid
flowchart TD
    %% Define the Layers
    subgraph Presentation_Layer [Presentation Layer (Scenes & Views)]
        direction TB
        ShopView[Shop UI Scene]
        InvUI[Inventory Display UI]
    end

    subgraph Communication_Layer [Communication Layer]
        direction TB
        SB{SignalBus Singleton}
    end

    subgraph Logic_State_Layer [Logic & State Layer (Singletons / Resources)]
        direction TB
        GM[GameManager Singleton]
        DB[(Database Singleton)]
        RS[[RunState Resource]]
    end

    %% The Flow
    ShopView -- "1. Player clicks Buy\nSignalBus.emit_signal('shop_purchase_requested', ...)" --> SB
    SB -- "2. Broadcasts Event" --> GM
    GM -- "3. run_state.spend_gold(cost)\nrun_state.add_instance(item)" --> RS
    RS -- "4. Inventory & Gold Updated\n(Atomic Mutation)" --> RS
    RS -- "5. SignalBus.emit_signal('run_data_changed')\nSignalBus.emit_signal('inventory_ui_refresh_requested')" --> SB
    SB -- "6. Broadcasts State Update" --> InvUI
    InvUI -- "7. Refreshes Visuals" --> InvUI
    GM -- "8. SignalBus.emit_signal('shop_stock_refreshed')" --> SB
    SB -- "9. Refreshes Shop UI" --> ShopView
```

## The "Why" over the "What": Event-Driven Architecture

In many beginner Godot projects, developers tightly couple their nodes together. A shop button might do something like `get_node("../../PlayerInventory").add_item(item)`. **We do not do this.** This creates "Spaghetti Code" where scenes are inextricably linked, and moving or deleting one node breaks the entire game.

Instead, we use an **Event-Driven Architecture** centered around **Autoloads (Singletons)**.

1. **The SignalBus (The Switchboard):** Think of the `SignalBus` as a central radio tower. Nodes broadcast messages ("Someone bought an item!") into the void. They don't care who is listening. Other nodes tune their radios to specific frequencies (`connect()`) to listen for those events. This makes our code infinitely scalable; we can add 10 new systems that react to a shop purchase without ever touching the shop code.
2. **The GameManager (The Authority):** The `GameManager` acts as the definitive source of truth for the active run. If a view wants to change data, it asks the `GameManager` via a signal. 
3. **The RunState (The Brain):** The `GameManager` holds the `RunState`, a Custom Resource that stores exactly how much gold we have, what day it is, and what items are in our inventory. 
4. **The Database (The Library):** The `Database` singleton holds all our static definitions (like `TrinketDefinition` or `EncounterDefinition`). It is read-only during gameplay.

---

## Block-by-Block Breakdown: How the Code Executes

Let's look at exactly how this pipeline is implemented line-by-line using our real project files.

### 1. Defining the Singleton in `project.godot`
Before any script runs, Godot looks at our `project.godot` configuration file to load Singletons (Autoloads). These scripts exist permanently in the root of the SceneTree, above everything else.
```ini
[autoload]
SignalBus="*res://scripts/SignalBus.gd"
Database="*res://scripts/Database.gd"
GameManager="*res://scripts/GameManager.gd"
```
Because they are Autoloads, we can call `SignalBus` or `GameManager` from *anywhere* in the codebase without needing a node reference.

### 2. Broadcasting from the Presentation Layer
When the player clicks "Buy", the Shop triggers its animation sequence. Once the coins reach the machine, it emits the global signal.

*File: `scripts/Shop.gd`*
```gdscript
			# Animate gold coins then purchase, then animate gachaball
			_animate_gold_spend(_selected_cost, interaction_pos, func():
				SignalBus.emit_signal("shop_purchase_requested", ball_uuid, _selected_cost)
				# AUDIO HOOK: Buy
				Audio.play_sfx("shop_buy")
```

### 3. Tuning in: Connecting Signals in `GameManager.gd`
The `GameManager` connects to this signal during `_ready()` and processes the actual transaction.

*File: `scripts/GameManager.gd`*
```gdscript
func _on_shop_purchase_requested(instance_uuid: String, cost: int) -> void:
	if not _temporary_shop_master_dict.has(instance_uuid): return
	if not run_state.spend_gold(cost): return

	var purchased_instance = _temporary_shop_master_dict[instance_uuid]
	var def = purchased_instance.get_definition()
	# Route based on category/type; Trinkets go to dedicated player trinkets container
	var container_name: StringName
	if is_instance_valid(def) and def.category == &"TRINKET":
		container_name = RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS
	else:
		var tier_val: int = (int(def.tier) if (def is GachaBallDefinition) else 1)
		container_name = &"RunInventoryT%d" % tier_val
	# Atomic add handles container slot selection and registry updates
	run_state.add_instance(purchased_instance, container_name, -1)
	
	# Unlock recipes for this acquired gachaball
	if is_instance_valid(def):
		run_state.unlock_recipe_for_result(def.id)

	_temporary_shop_master_dict.erase(instance_uuid)
	var temp_slot = _temporary_shop_container.get_all_uuids().find(instance_uuid)
	if temp_slot != -1:
		_temporary_shop_container.set_uuid(temp_slot, "")

	SignalBus.emit_signal("selection_clear_requested")

	# Avoid duplicate run_data_changed; atomic APIs already emitted above
	var context: Dictionary = {"shop_instances": _temporary_shop_master_dict.values(), "reroll_cost": _reroll_cost}
	SignalBus.emit_signal("shop_stock_refreshed", context)
```

### 4. The Atomic Mutation in `RunState.gd`
The `RunState` doesn't just hold data; it uses an "Atomic API" to ensure that whenever data changes, the rest of the game is notified perfectly. It handles emitting the `run_data_changed` signals internally so the `GameManager` doesn't have to guess when to do it.

*File: `scripts/RunState.gd`*
```gdscript
# Trinkets are automatically routed to PlayerTrinkets container in add_instance()
func add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1) -> bool:
	# Adds an instance to the given container/index atomically.
	if not is_instance_valid(instance):
		return false
	# Trinket routing: if the instance's definition is a TRINKET, route to PlayerTrinkets container.
	var def_for_routing = instance.get_definition()
	if is_instance_valid(def_for_routing) and def_for_routing.category == &"TRINKET":
		var trinket_container := get_container(RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
		if not is_instance_valid(trinket_container):
			return false
		var trinket_slot := trinket_container.find_first_empty_slot()
		if trinket_slot == -1:
			return false
		trinket_container.set_uuid(trinket_slot, instance.ball_uuid)
		instance.location_container_tag = RUN_CONTAINER_TAGS.PLAYER_TRINKETS
		instance.location_slot_index = trinket_slot
		run_instances[instance.ball_uuid] = instance
		if OS.is_debug_build():
			_validate_state_consistency()
		SignalBus.emit_signal("run_data_changed")
		SignalBus.emit_signal("inventory_ui_refresh_requested")
		return true

	var container = get_container(container_name)
	if not is_instance_valid(container):
		return false
	var slot := index
	if slot < 0:
		slot = container.find_first_empty_slot()
		if slot == -1:
			# NEW RULE: If a tiered inventory is full, permanently remove a random existing gachaball
			# ONLY applies to RunInventoryT* (not Battle containers that might be accessed via RunState)
			if String(container_name).begins_with("RunInventoryT"):
				var all_uuids = container.get_all_non_empty_uuids()
				if all_uuids.size() > 0:
					# Select a random gachaball
					randomize()
					var uuid_to_replace = all_uuids[randi() % all_uuids.size()]
					var loc_to_replace = get_location_for_uuid(uuid_to_replace)
					slot = loc_to_replace.index
					# Permanently remove the chosen instance from the run to make space
					remove_instance(uuid_to_replace)
			
			if slot == -1:
				return false
	# Update Index
	container.set_uuid(slot, instance.ball_uuid)
	# Update Truth
	instance.location_container_tag = container_name
	instance.location_slot_index = slot
	instance.equipped_on_uuid = ""
	instance.equipped_slot_index = -1
	# Register
	run_instances[instance.ball_uuid] = instance
	# Validate (debug only)
	if OS.is_debug_build():
		_validate_state_consistency()
	# Emit
	SignalBus.emit_signal("run_data_changed")
	SignalBus.emit_signal("inventory_ui_refresh_requested")
	return true
```

### 5. Reacting to the Changes in the UI
Finally, any UI elements that display player resources (like a Gold Tracker or Inventory Grid) are also connected to the `SignalBus`. Whenever `run_data_changed` is emitted, they automatically pull the latest numbers from the global state and redraw themselves.
