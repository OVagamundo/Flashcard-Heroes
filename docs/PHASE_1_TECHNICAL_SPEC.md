# Phase 1 Technical Specification: Foundation & Core Architecture

**Phase**: 1 of 10
**Status**: 🔄 IN PROGRESS
**Dependencies**: None (Foundation Phase)

## 🎯 **PHASE OBJECTIVES**

Establish the new hybrid architecture and core data structures that will serve as the foundation for all subsequent phases. This phase implements the "Instance as Source of Truth + DataContainer as Performant Index" pattern.

## 📋 **DETAILED TASK BREAKDOWN**

### **Task 1.1: Create New Core Data Resources**

#### **1.1.1 InteractionContext.gd**
**File**: `scripts/InteractionContext.gd`
**Type**: Resource class
**Purpose**: Standardized data packet for all UI interactions

```gdscript
@tool
class_name InteractionContext extends Resource

@export var source_view: Control
@export var event_type: StringName  # "SINGLE_CLICK", "DOUBLE_CLICK"
@export var location: LocationIdentifier
@export var entity_uuid: String
@export var entity_type: StringName  # "UNIT", "ITEM", "EMPTY_SLOT", "WINDOW_BACKGROUND", "UI_LINK", "GLOBAL_BACKGROUND"
@export var interaction_mode: StringName  # "FULLY_INTERACTIVE", "SELECTION_ONLY", "INSPECTION_ONLY"
@export var window_group_id: int = 0
```

#### **1.1.2 Update GachaBallDefinition.gd**
**File**: `scripts/GachaBallDefinition.gd`
**Type**: Resource modification
**Purpose**: Add cost property for encounter generation

```gdscript
# Add this property to existing GachaBallDefinition
@export var cost: int = 1  # Cost for shop/encounter generation
```

#### **1.1.3 FlashcardDefinition.gd**
**File**: `scripts/FlashcardDefinition.gd`
**Type**: New resource class
**Purpose**: In-memory resource created from JSON deck files

```gdscript
@tool
class_name FlashcardDefinition extends Resource

@export var id: StringName
@export var question: String
@export var answer: String
@export var explanation: String
```

#### **1.1.4 FlashcardProgress.gd**
**File**: `scripts/FlashcardProgress.gd`
**Type**: New resource class
**Purpose**: Tracks run-specific progress for a single flashcard

```gdscript
@tool
class_name FlashcardProgress extends Resource

@export var definition_id: StringName
@export var mastery_level: int = 0
@export var last_review_time: int = 0
```

#### **1.1.5 EncounterDefinition.gd**
**File**: `scripts/EncounterDefinition.gd`
**Type**: New resource class
**Purpose**: Defines enemy team composition and behavior

```gdscript
@tool
class_name EncounterDefinition extends Resource

@export var id: StringName
@export var display_name_key: String
@export var enemy_placements: Array[Dictionary]  # Array of enemy unit placements
@export var ai_behavior: StringName
@export var environment: StringName
@export var background: Texture2D
@export var music_track: StringName
@export var is_boss: bool = false
@export var victory_rewards: Array[RewardDefinition]
@export var possible_rewards: Array[RewardDefinition]
```

#### **1.1.6 PathNodeDefinition.gd**
**File**: `scripts/PathNodeDefinition.gd`
**Type**: New resource class
**Purpose**: Defines a single selectable node in the run's path

```gdscript
@tool
class_name PathNodeDefinition extends Resource

@export var node_type: StringName  # "BATTLE", "SHOP", "EVENT", "REST"
@export var subtype: StringName  # "COMMON", "ELITE", "MINIBOSS", "BOSS", etc.
@export var display_name_key: String
@export var description_key: String
@export var icon: Texture2D
@export var encounter_id: StringName
@export var rewards: Array[RewardDefinition]
@export var difficulty: int = 1
```

#### **1.1.7 RewardDefinition.gd**
**File**: `scripts/RewardDefinition.gd`
**Type**: New resource class
**Purpose**: Defines rewards that can be granted to the player

```gdscript
@tool
class_name RewardDefinition extends Resource

@export var type: StringName  # "GOLD", "ITEM", "UNIT", "CARD", "UPGRADE"
@export var amount: int
@export var item_id: StringName
@export var rarity_weights: Dictionary
@export var min_tier: int = 1
@export var max_tier: int = 3
```

#### **1.1.8 BattleResult.gd**
**File**: `scripts/BattleResult.gd`
**Type**: New resource class
**Purpose**: Contains the outcome of a battle

```gdscript
@tool
class_name BattleResult extends Resource

@export var victory: bool
@export var rounds: int
@export var player_units_lost: int
@export var enemy_units_defeated: int
@export var gold_earned: int
@export var experience_gained: int
@export var drops: Array[StringName]
@export var achievements: Array[StringName]
```

### **Task 1.2: Implement New Data Containers**

#### **1.2.1 DataContainer.gd (Abstract Base)**
**File**: `scripts/DataContainer.gd`
**Type**: Abstract base class
**Purpose**: Defines common interface for all container implementations

```gdscript
class_name DataContainer extends RefCounted

# Abstract methods that must be implemented
func get_uuid(index: int) -> String:
	push_error("DataContainer.get_uuid() must be overridden")
	return ""

func set_uuid(index: int, uuid: String) -> void:
	push_error("DataContainer.set_uuid() must be overridden")

func find_first_empty_slot() -> int:
	push_error("DataContainer.find_first_empty_slot() must be overridden")
	return -1

func is_valid_index(index: int) -> bool:
	push_error("DataContainer.is_valid_index() must be overridden")
	return false

func get_size() -> int:
	push_error("DataContainer.get_size() must be overridden")
	return 0

func is_empty() -> bool:
	push_error("DataContainer.is_empty() must be overridden")
	return true
```

#### **1.2.2 FixedArrayContainer.gd**
**File**: `scripts/FixedArrayContainer.gd`
**Type**: Concrete implementation
**Purpose**: Fixed-size array container for lineups, benches, etc.

```gdscript
class_name FixedArrayContainer extends DataContainer

var _data: Array[String] = []
var _size: int

func _init(initial_size: int):
	_size = initial_size
	_data.resize(initial_size)
	for i in range(initial_size):
		_data[i] = ""

func get_uuid(index: int) -> String:
	if not is_valid_index(index):
		return ""
	return _data[index]

func set_uuid(index: int, uuid: String) -> void:
	if not is_valid_index(index):
		push_error("FixedArrayContainer: Invalid index %d" % index)
		return
	_data[index] = uuid

func find_first_empty_slot() -> int:
	for i in range(_size):
		if _data[i] == "":
			return i
	return -1

func is_valid_index(index: int) -> bool:
	return index >= 0 and index < _size

func get_size() -> int:
	return _size

func is_empty() -> bool:
	for uuid in _data:
		if uuid != "":
			return false
	return true
```

#### **1.2.3 GrowableGridContainer.gd**
**File**: `scripts/GrowableGridContainer.gd`
**Type**: Concrete implementation
**Purpose**: Growable container for inventories, discard piles, etc.

```gdscript
class_name GrowableGridContainer extends DataContainer

var _data: Array[String] = []
var _free_list: Array[int] = []
var _growth_amount: int = 16

func _init(initial_size: int = 16):
	_data.resize(initial_size)
	for i in range(initial_size):
		_data[i] = ""
		_free_list.append(i)

func get_uuid(index: int) -> String:
	if not is_valid_index(index):
		return ""
	return _data[index]

func set_uuid(index: int, uuid: String) -> void:
	if not is_valid_index(index):
		push_error("GrowableGridContainer: Invalid index %d" % index)
		return
	
	var was_empty = _data[index] == ""
	_data[index] = uuid
	
	if was_empty and uuid != "":
		_free_list.erase(index)
	elif not was_empty and uuid == "":
		_free_list.append(index)

func find_first_empty_slot() -> int:
	if _free_list.is_empty():
		_expand_container()
	if _free_list.is_empty():
		return -1
	return _free_list[0]

func is_valid_index(index: int) -> bool:
	return index >= 0 and index < _data.size()

func get_size() -> int:
	return _data.size()

func is_empty() -> bool:
	return _free_list.size() == _data.size()

func _expand_container() -> void:
	var old_size = _data.size()
	var new_size = old_size + _growth_amount
	
	_data.resize(new_size)
	for i in range(old_size, new_size):
		_data[i] = ""
		_free_list.append(i)
```

#### **1.2.4 Update RunState.gd**
**File**: `scripts/RunState.gd`
**Type**: Resource modification
**Purpose**: Integrate new container system

```gdscript
# Add these properties to RunState
var _containers: Dictionary[StringName, DataContainer] = {}

# Add these methods
func get_container(container_tag: StringName) -> DataContainer:
	return _containers.get(container_tag)

func _initialize_containers() -> void:
	# Initialize all run containers
	_containers[&"PlayerLineup"] = FixedArrayContainer.new(6)
	_containers[&"PlayerBench"] = FixedArrayContainer.new(6)
	_containers[&"ItemInventory"] = FixedArrayContainer.new(12)
	_containers[&"RunInventoryT1"] = GrowableGridContainer.new(16)
	_containers[&"RunInventoryT2"] = GrowableGridContainer.new(16)
	_containers[&"RunInventoryT3"] = GrowableGridContainer.new(16)
```

#### **1.2.5 Update BattleManager.gd**
**File**: `scripts/BattleManager.gd`
**Type**: Node modification
**Purpose**: Integrate new container system

```gdscript
# Add these properties to BattleManager
var _battle_containers: Dictionary[StringName, DataContainer] = {}

# Add these methods
func get_container(container_tag: StringName) -> DataContainer:
	return _battle_containers.get(container_tag)

func _initialize_battle_containers() -> void:
	# Initialize all battle containers
	_battle_containers[&"EnemyLineup"] = FixedArrayContainer.new(6)
	_battle_containers[&"DiscardPile"] = GrowableGridContainer.new(16)
	_battle_containers[&"BattleInventoryT1"] = GrowableGridContainer.new(16)
	_battle_containers[&"BattleInventoryT2"] = GrowableGridContainer.new(16)
	_battle_containers[&"BattleInventoryT3"] = GrowableGridContainer.new(16)
```

### **Task 1.3: Establish Golden Rule of State Synchronization**

#### **1.3.1 Audit InventoryManager.gd**
**File**: `scripts/InventoryManager.gd`
**Type**: Code audit and modification
**Purpose**: Ensure all operations follow the Golden Rule

**Golden Rule**: Any operation that moves an instance MUST update both:
1. The DataContainer (the index)
2. The GachaBallInstance's properties (the truth)

**Key Methods to Audit**:
- `_move()`
- `_swap()`
- `_merge()`
- `_equip_item()`
- `_perform_equip()`
- `_perform_unequip()`
- `_place_in_container_slot()`
- `_remove_from_location()`

#### **1.3.2 Create Helper Functions**
**File**: `scripts/InventoryManager.gd`
**Type**: New helper methods
**Purpose**: Ensure atomic operations

```gdscript
# Add these helper functions to InventoryManager
func _atomic_move_instance(instance: GachaBallInstance, from_loc: LocationIdentifier, to_loc: LocationIdentifier) -> void:
	# Step 1: Update the index (DataContainer)
	_remove_from_location(from_loc)
	_place_in_container_slot(instance, to_loc.container, to_loc.index)
	
	# Step 2: Update the truth (GachaBallInstance)
	instance.location_container_tag = to_loc.container
	instance.location_slot_index = to_loc.index

func _validate_state_consistency() -> bool:
	# Validation function to ensure index and truth are synchronized
	var data_owner = _get_data_owner()
	if not is_instance_valid(data_owner):
		return false
	
	var all_instances = data_owner.get_all_instances()
	
	for instance_uuid in all_instances:
		var instance = all_instances[instance_uuid]
		var location = instance.get_location()
		var container = data_owner.get_container(location.container)
		
		if not is_instance_valid(container):
			continue
			
		if container.get_uuid(location.index) != instance_uuid:
			push_error("State inconsistency detected: Instance %s location mismatch" % instance_uuid)
			return false
	
	return true
```

## 🔧 **IMPLEMENTATION NOTES**

### **Backward Compatibility**
- All new properties should have default values
- Existing save files should continue to work
- Gradual migration of existing data structures

### **Performance Considerations**
- DataContainer lookups should be O(1)
- Container expansion should be amortized O(1)
- Memory usage should be reasonable for expected game state sizes

### **Error Handling**
- All container operations should validate indices
- Invalid operations should emit clear error messages
- State validation should be available for debugging

### **Testing Strategy**
- Unit tests for each container type
- Integration tests for state synchronization
- Performance tests for large datasets

## 📊 **SUCCESS CRITERIA**

### **Functional Requirements**
- [ ] All new resource classes can be instantiated
- [ ] DataContainers provide correct O(1) lookups
- [ ] State synchronization is maintained
- [ ] Backward compatibility is preserved

### **Performance Requirements**
- [ ] Container operations complete in <1ms
- [ ] Memory usage is reasonable (<100MB for typical game state)
- [ ] No memory leaks in container operations

### **Quality Requirements**
- [ ] All code follows project coding standards
- [ ] Error handling is comprehensive
- [ ] Documentation is complete
- [ ] Tests pass

## 🚨 **RISKS & MITIGATION**

### **Risk 1: Breaking Existing Functionality**
**Mitigation**: Implement feature flags, maintain backward compatibility

### **Risk 2: Performance Degradation**
**Mitigation**: Profile before and after, optimize critical paths

### **Risk 3: Data Corruption**
**Mitigation**: Implement validation functions, add comprehensive testing

### **Risk 4: Complex State Management**
**Mitigation**: Follow Golden Rule strictly, add debugging tools

## 📝 **NEXT PHASE DEPENDENCIES**

Phase 1 must complete successfully before Phase 2 can begin, as:
- GlobalInteractionRouter depends on InteractionContext
- UI updates depend on new data structures
- Window management depends on container system

## 🔗 **RELATED FILES**

### **Files to Create**:
- `scripts/InteractionContext.gd`
- `scripts/FlashcardDefinition.gd`
- `scripts/FlashcardProgress.gd`
- `scripts/EncounterDefinition.gd`
- `scripts/PathNodeDefinition.gd`
- `scripts/RewardDefinition.gd`
- `scripts/BattleResult.gd`
- `scripts/DataContainer.gd`
- `scripts/FixedArrayContainer.gd`
- `scripts/GrowableGridContainer.gd`

### **Files to Modify**:
- `scripts/GachaBallDefinition.gd`
- `scripts/RunState.gd`
- `scripts/BattleManager.gd`
- `scripts/InventoryManager.gd` 