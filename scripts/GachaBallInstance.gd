# res://scripts/GachaBallInstance.gd
class_name GachaBallInstance
extends Resource



## A unique, individual instance of a GachaBall. Its state is defined by its properties.

# --- Core Properties ---
var definition_id: StringName
var ball_uuid: String
var origin_uuid: String = "" # UUID of the permanent instance this battle copy was created from.

# --- State Properties ---
var current_hp: int
var current_pwr: int

# --- Location Properties (for temporary battle state) ---
var location_container_tag: StringName = &""
var location_slot_index: int = -1

# --- Relationship Properties ---
var equipped_on_uuid: String = ""
var equipped_slot_index: int = -1
# Up to 3 equipped items (by UUID). Empty string indicates empty slot.
var equipped_item_uuids: Array[String] = ["", "", ""]

# --- Dynamic State Properties ---
var dynamic_tags: Array[StringName] = [] # For status effects like "POISONED", "HONEY_ARMOR"

# --- Abilities ---
var abilities: Array[AbilityDefinition] = []

# --- Initialization ---
func initialize(definition: GachaBallDefinition):
	if not is_instance_valid(definition):
		printerr("GachaBallInstance.initialize() called with a null definition.")
		return

	self.definition_id = definition.id
	self.ball_uuid = UUIDUtils.generate_uuid(definition.id)
	self.abilities = definition.ability_definitions.duplicate(true) # Deep copy
	self.current_hp = definition.base_hp
	self.current_pwr = definition.base_pwr

	# Initialize equipment state
	self.equipped_on_uuid = ""
	self.equipped_slot_index = -1
	self.equipped_item_uuids.clear()
	self.equipped_item_uuids.resize(definition.item_slot_count)
	self.equipped_item_uuids.fill("")

# --- Cloning ---
func create_battle_copy() -> GachaBallInstance:
	var copy = self.duplicate(false) # Shallow copy of value types
	var definition = get_definition()
	if not is_instance_valid(definition):
		printerr("Cannot create battle copy, definition not found for ID: ", self.definition_id)
		return null

	# Deep copy mutable types
	copy.abilities = self.abilities.duplicate(true)
	copy.dynamic_tags = self.dynamic_tags.duplicate(true)
	
	# Assign new unique ID for the battle context
	copy.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
	copy.origin_uuid = self.ball_uuid # Link back to the original

	# CRITICAL: Explicitly copy the definition ID.
	copy.definition_id = self.definition_id

	# Copy stats 
	copy.current_hp = self.current_hp
	copy.current_pwr = self.current_pwr
	# Copy equipment state
	copy.equipped_on_uuid = self.equipped_on_uuid
	copy.equipped_slot_index = self.equipped_slot_index
	

	return copy

# --- Stat Management ---
func reset_battle_stats():
	var definition = get_definition()
	if not is_instance_valid(definition):
		printerr("GachaBallInstance: Could not reset stats, definition not found for ID: ", self.definition_id)
		return
	
	self.current_hp = definition.base_hp
	self.current_pwr = definition.base_pwr

# --- Stat Recalculation ---
func recalculate_stats(all_instances_db: Dictionary):
	var definition = get_definition()
	if not is_instance_valid(definition):
		return

	var previous_hp = self.current_hp
	var previous_pwr = self.current_pwr

	var new_hp = definition.base_hp
	var new_pwr = definition.base_pwr

	# Add bonuses from each equipped item by looking up its UUID in the provided database.
	for item_uuid in equipped_item_uuids:
		if not item_uuid.is_empty():
			var item_instance: GachaBallInstance = all_instances_db.get(item_uuid)
			if is_instance_valid(item_instance):
				var item_def = item_instance.get_definition()
				if is_instance_valid(item_def):
					new_hp += item_def.bonus_hp
					new_pwr += item_def.bonus_pwr

	var stats_did_change = (new_hp != previous_hp or new_pwr != previous_pwr)

	self.current_hp = new_hp
	self.current_pwr = new_pwr

	if stats_did_change:
		EventBus.emit_signal("unit_stats_changed", self.ball_uuid)

# --- Tag Helpers ---
func add_tag(tag: StringName):
	if not dynamic_tags.has(tag):
		dynamic_tags.append(tag)

func remove_tag(tag: StringName):
	if dynamic_tags.has(tag):
		dynamic_tags.erase(tag)

func has_tag(tag: StringName) -> bool:
	# Check static tags on the definition first.
	var def = get_definition()
	if is_instance_valid(def) and def.tags.has(tag):
		return true
	# Then check dynamic tags on this instance.
	return dynamic_tags.has(tag)

# --- Equipment Helpers ---
# Returns the UUID of the item equipped in the given slot (0-2). Returns an
# empty string if the slot is out of range or empty.
func get_equipped_item_uuid(slot_index: int) -> String:
	if slot_index >= 0 and slot_index < equipped_item_uuids.size():
		return equipped_item_uuids[slot_index]
	return ""

# --- Abilities Helpers ---
# Safely retrieve an ability definition by index. Returns null if the index is
# out of bounds or the slot is empty.
func get_ability(index: int) -> AbilityDefinition:
	if abilities == null:
		return null
	if index >= 0 and index < abilities.size():
		return abilities[index]
	return null

# --- Utilities ---
func get_definition() -> GachaBallDefinition:
	return Database.get_definition(definition_id)
