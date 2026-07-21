# res://scripts/GachaBallInstance.gd
class_name GachaBallInstance
extends Resource


## A unique, individual instance of a GachaBall. Its state is defined by its properties.

# --- Core Properties ---
var definition_id: StringName
var ball_uuid: String
var origin_uuid: String = "" # UUID of the permanent instance this battle copy was created from.

# --- State Properties ---
var level: int = 1
var current_hp: int
var current_pwr: int

# --- Stat Debt (Systemic Minimum 1 constraint) ---
var _hp_debt: int = 0
var _pwr_debt: int = 0

# --- Location Properties (for temporary battle state) ---
var location_container_tag: StringName = &""
var location_slot_index: int = -1

# --- Relationship Properties ---
var equipped_on_uuid: String = ""
var equipped_slot_index: int = -1
# Equipped items (by UUID). Units currently support a single slot.
var equipped_item_uuids: Array[String] = []

# --- Dynamic State Properties ---
var dynamic_tags: Array[StringName] = [] # For status effects like "POISONED", "HONEY_ARMOR"
var status_effects: Dictionary = {} # Key: StringName (effect_id), Value: int (stack_count)

# --- Component Composition ---
var components: Array[GachaBallComponent] = []
var battle_components: Array[GachaBallComponent] = []

# --- Initialization ---
func initialize(definition: GachaBallDefinition) -> void:
	if not is_instance_valid(definition):
		return

	self.definition_id = definition.id
	self.ball_uuid = UUIDUtils.generate_uuid(definition.id)
	self.level = definition.level if "level" in definition else 1
	self.current_hp = definition.base_hp
	self.current_pwr = definition.base_pwr
	self.components.clear()
	self.battle_components.clear()

	# Initialize equipment state
	self.equipped_on_uuid = ""
	self.equipped_slot_index = -1
	self.equipped_item_uuids.clear()
	self.equipped_item_uuids.resize(definition.item_slot_count)
	self.equipped_item_uuids.fill("")

# --- Cloning ---
func create_battle_copy(all_instances_db: Dictionary = {}) -> GachaBallInstance:
	var copy = self.duplicate(false) # Shallow copy of value types
	var definition = get_definition()
	if not is_instance_valid(definition):
		return null

	# Deep copy mutable types
	copy.dynamic_tags = self.dynamic_tags.duplicate(true)
	copy.status_effects = self.status_effects.duplicate(true)
	copy.components = _duplicate_components(self.components)
	copy.battle_components.clear()

	# Assign new unique ID for the battle context
	copy.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
	copy.origin_uuid = self.ball_uuid # Link back to the original
	copy.definition_id = self.definition_id
	copy.level = self.level

	# Copy equipment state (needed for effective stat calculation)
	copy.equipped_on_uuid = self.equipped_on_uuid
	copy.equipped_slot_index = self.equipped_slot_index
	copy.equipped_item_uuids = self.equipped_item_uuids.duplicate()

	# Reset to effective starting stats using component-aware calculation
	copy.current_hp = copy.get_effective_starting_hp(all_instances_db)
	copy.current_pwr = copy.get_effective_starting_pwr(all_instances_db)

	return copy


# --- Trinket Initialization ---
# Initialize this instance from a TrinketDefinition (no base stats, no item slots).
func initialize_from_trinket(trinket_def: Resource) -> void:
	if not is_instance_valid(trinket_def):
		return
	self.definition_id = trinket_def.id if "id" in trinket_def else &""
	self.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
	self.components.clear()
	self.battle_components.clear()
	# Neutralize stats and equipment for trinkets
	self.current_hp = 0
	self.current_pwr = 0
	self.equipped_on_uuid = ""
	self.equipped_slot_index = -1
	self.equipped_item_uuids.clear()
	self.location_container_tag = &""
	self.location_slot_index = -1

# --- Equipment Stat Modification (Component-Aware Delta) ---
# These compute the stat delta by comparing effective totals before/after the equipment
# change. This preserves battle damage while deriving values from the component system.
func equip_item_bonus(item_instance: GachaBallInstance) -> void:
	if not is_instance_valid(item_instance): return
	var item_def = item_instance.get_definition()
	if not is_instance_valid(item_def): return
	var hp_delta: int = int(item_def.bonus_hp) if "bonus_hp" in item_def else 0
	var pwr_delta: int = int(item_def.bonus_pwr) if "bonus_pwr" in item_def else 0
	
	if hp_delta != 0:
		apply_hp_delta(hp_delta, {"silent": false})
	if pwr_delta != 0:
		apply_pwr_delta(pwr_delta, {"silent": false})

func unequip_item_bonus(item_instance: GachaBallInstance) -> void:
	if not is_instance_valid(item_instance): return
	var item_def = item_instance.get_definition()
	if not is_instance_valid(item_def): return
	var hp_delta: int = int(item_def.bonus_hp) if "bonus_hp" in item_def else 0
	var pwr_delta: int = int(item_def.bonus_pwr) if "bonus_pwr" in item_def else 0
	
	if hp_delta != 0:
		apply_hp_delta(-hp_delta, {"silent": false})
	if pwr_delta != 0:
		apply_pwr_delta(-pwr_delta, {"silent": false})

# --- Stat Management ---
func set_current_hp(new_hp: int) -> void:
	var old_hp = self.current_hp
	if old_hp != new_hp:
		self.current_hp = new_hp
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"hp", old_hp, new_hp)

func set_current_hp_silent(new_hp: int) -> void:
	# Update HP without emitting UI signals. Used during simulation passes.
	self.current_hp = new_hp

func set_current_pwr_silent(new_pwr: int) -> void:
	# Update PWR without emitting UI signals. Used during simulation passes.
	self.current_pwr = new_pwr

func reset_battle_stats() -> void:
	# Store old values for granular signal
	var old_hp = current_hp
	var old_pwr = current_pwr
	
	# Restore HP and PWR using component-aware persistent modifiers
	current_hp = get_definition_base_hp() + get_persistent_hp_modifier()
	current_pwr = get_definition_base_pwr() + get_persistent_pwr_modifier()
	
	# Clear all status effects (poison, etc.)
	status_effects.clear()
	battle_components.clear()
	
	# Reset dynamic tags
	dynamic_tags.clear()
	
	# Emit granular signals for each stat that changed
	if old_hp != current_hp:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"hp", old_hp, current_hp)
	if old_pwr != current_pwr:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"pwr", old_pwr, current_pwr)

func reset_battle_stats_silent() -> void:
	# Restore HP and PWR using component-aware persistent modifiers - SILENT VERSION
	current_hp = get_definition_base_hp() + get_persistent_hp_modifier()
	current_pwr = get_definition_base_pwr() + get_persistent_pwr_modifier()
	
	# Clear all status effects (poison, etc.)
	status_effects.clear()
	battle_components.clear()
	
	# Reset dynamic tags
	dynamic_tags.clear()

# --- Stat Recalculation ---
func recalculate_stats(all_instances_db: Dictionary) -> void:
	var definition = get_definition()
	if not is_instance_valid(definition):
		return

	var previous_hp = self.current_hp
	var previous_pwr = self.current_pwr

	# Calculate effective max stats using component-aware resolution
	var _effective_max_hp = get_effective_starting_hp(all_instances_db)
	var effective_max_pwr = get_effective_starting_pwr(all_instances_db)

	# Preserve current HP/PWR - only clamp PWR to maximum, allow HP to exceed max due to healing
	var new_hp = previous_hp # Preserve current HP (can exceed max due to healing effects)
	var new_pwr = previous_pwr # Allow PWR to scale indefinitely (needed for merge logic)

	self.current_hp = new_hp
	self.current_pwr = new_pwr

	# Emit granular signals
	if previous_hp != current_hp:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"hp", previous_hp, current_hp)
	if previous_pwr != current_pwr:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"pwr", previous_pwr, current_pwr)

# --- Tag Helpers ---
func add_tag(tag: StringName) -> void:
	if not dynamic_tags.has(tag):
		dynamic_tags.append(tag)

func remove_tag(tag: StringName) -> void:
	if dynamic_tags.has(tag):
		dynamic_tags.erase(tag)

func has_tag(tag: StringName) -> bool:
	return get_active_tags().has(tag)

# --- Status Effect Helpers ---
func add_status_effect(effect_id: StringName, amount: int) -> void:
	if amount == 0: return
	
	var current = status_effects.get(effect_id, 0)
	var new_amount = current + amount
	
	if new_amount <= 0:
		status_effects.erase(effect_id)
		new_amount = 0
	else:
		status_effects[effect_id] = new_amount
		
	# Emit granular signal with stat name like "armor_stacks", "burn_stacks"
	var stat_name = StringName(String(effect_id) + "_stacks")
	SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, stat_name, current, new_amount)

func add_status_effect_silent(effect_id: StringName, amount: int) -> void:
	# Update status effect without emitting UI signals. Used during simulation.
	if amount == 0: return
	
	var current = status_effects.get(effect_id, 0)
	var new_amount = current + amount
	
	if new_amount <= 0:
		status_effects.erase(effect_id)
	else:
		status_effects[effect_id] = new_amount

func get_status_effect_amount(effect_id: StringName) -> int:
	return status_effects.get(effect_id, 0)

func clear_status_effect(effect_id: StringName) -> void:
	var current = status_effects.get(effect_id, 0)
	if current > 0:
		status_effects.erase(effect_id)
		# Emit granular signal with stat name like "armor_stacks", "burn_stacks"
		var stat_name = StringName(String(effect_id) + "_stacks")
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, stat_name, current, 0)

# --- Location Helpers ---
# Assembles the definitive location of this instance based on its state.
# This is the single source of truth for an instance's location.
func get_location() -> LocationIdentifier:
	var loc = LocationIdentifier.new()
	
	# If an item is equipped, its location is defined by its parent unit.
	if not equipped_on_uuid.is_empty():
		loc.container = C.CONTAINER_EQUIPPED_ITEM
		loc.unit_uuid = equipped_on_uuid
		loc.index = equipped_slot_index
	# Otherwise, its location is defined by the container it's in.
	else:
		loc.container = location_container_tag
		loc.index = location_slot_index
		
	return loc

# --- Equipment Helpers ---
# Returns the UUID of the item equipped in the given slot (0-2). Returns an
# empty string if the slot is out of range or empty.
func get_equipped_item_uuid(slot_index: int) -> String:
	if slot_index >= 0 and slot_index < equipped_item_uuids.size():
		return equipped_item_uuids[slot_index]
	return ""

# --- Abilities Helpers ---
# Safely retrieve an ability definition by index from the unit's definition.
func get_ability(index: int) -> AbilityDefinition:
	var def = get_definition()
	if not is_instance_valid(def) or not ("ability_definitions" in def):
		return null
	if def.ability_definitions == null:
		return null
	if index >= 0 and index < def.ability_definitions.size():
		return def.ability_definitions[index]
	return null

func get_active_abilities(all_instances_db: Dictionary = {}) -> Array[AbilityDefinition]:
	var result: Array[AbilityDefinition] = []
	for entry in get_active_ability_entries(all_instances_db):
		var ability_def: AbilityDefinition = entry.get("ability_def")
		if is_instance_valid(ability_def):
			result.append(ability_def)
	return result

func get_active_ability_entries(all_instances_db: Dictionary = {}) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var disabled_ids: Dictionary = {}
	var seen: Dictionary = {}

	var active_components := get_active_components(all_instances_db)
	for component in active_components:
		if component is AbilityComponent:
			var ability_component := component as AbilityComponent
			if ability_component.mode == "DISABLE":
				disabled_ids[ability_component.target_ability_id] = true
			elif ability_component.mode == "REPLACE" and ability_component.target_ability_id != &"":
				disabled_ids[ability_component.target_ability_id] = true

	for component in active_components:
		if not component is AbilityComponent:
			continue
		var ability_component := component as AbilityComponent
		if ability_component.mode == "DISABLE":
			continue

		var source_uuid := ball_uuid
		if ability_component.source_type == &"EQUIPMENT" and not ability_component.source_id.is_empty():
			source_uuid = ability_component.source_id
		for ability_def in ability_component.ability_definitions:
			if not is_instance_valid(ability_def):
				continue
			_add_ability_entry(entries, seen, ability_def, source_uuid, ability_component.source_type, ball_uuid, ability_component.priority, ability_component.id)

	var filtered: Array[Dictionary] = []
	for entry in entries:
		var ability_def: AbilityDefinition = entry.get("ability_def")
		if is_instance_valid(ability_def) and not disabled_ids.has(ability_def.id):
			filtered.append(entry)
	return filtered

func get_active_components(all_instances_db: Dictionary = {}) -> Array[GachaBallComponent]:
	var result: Array[GachaBallComponent] = []
	result.append_array(_build_definition_components())
	result.append_array(components)
	result.append_array(_build_dynamic_state_components())
	result.append_array(_build_equipment_components(all_instances_db))
	result.append_array(battle_components)
	result.sort_custom(func(a: GachaBallComponent, b: GachaBallComponent) -> bool:
		return a.priority < b.priority
	)
	return result

func get_active_tags(all_instances_db: Dictionary = {}) -> Array[StringName]:
	var tags: Array[StringName] = []
	var remove_tags: Array[StringName] = []
	for component in get_active_components(all_instances_db):
		if not component is TagComponent:
			continue
		var tag_component := component as TagComponent
		for tag in tag_component.tags_to_add:
			if not tags.has(tag):
				tags.append(tag)
		for tag in tag_component.tags_to_remove:
			if not remove_tags.has(tag):
				remove_tags.append(tag)
	for tag in remove_tags:
		if tags.has(tag):
			tags.erase(tag)
	return tags

func get_active_traits(all_instances_db: Dictionary = {}) -> Array[StringName]:
	var traits: Array[StringName] = []
	for tag in get_active_tags(all_instances_db):
		if String(tag).begins_with("SOUL_"):
			traits.append(tag)
	return traits

func get_trait_soul_counts(all_instances_db: Dictionary = {}) -> Dictionary:
	var counts := {"FIRE": 0, "EARTH": 0, "WATER": 0, "AIR": 0}
	for component in get_active_components(all_instances_db):
		if not component is TagComponent:
			continue
		var tag_component := component as TagComponent
		for tag in tag_component.tags_to_add:
			if tag == &"SOUL_FIRE":
				counts["FIRE"] += 1
			elif tag == &"SOUL_EARTH":
				counts["EARTH"] += 1
			elif tag == &"SOUL_WATER":
				counts["WATER"] += 1
			elif tag == &"SOUL_AIR":
				counts["AIR"] += 1
	return counts

func get_attribute(attribute_name: StringName, all_instances_db: Dictionary = {}) -> Variant:
	var def = get_definition()
	var value: Variant = null
	match attribute_name:
		&"tier":
			if is_instance_valid(def) and "tier" in def:
				value = def.tier
		&"category":
			if is_instance_valid(def) and "category" in def:
				value = def.category
		&"level":
			value = self.level
		&"rarity":
			value = &"normal"  # Overridden by components (e.g., prismatic_rarity TagComponent)

	for component in get_active_components(all_instances_db):
		if component is TagComponent:
			var tag_component := component as TagComponent
			if attribute_name == &"level" and tag_component.id == &"base_definition_attributes":
				continue
			if tag_component.attributes.has(attribute_name):
				value = tag_component.attributes[attribute_name]
			elif tag_component.attributes.has(String(attribute_name)):
				value = tag_component.attributes[String(attribute_name)]
	return value

## Returns the gold value of this instance based on its definition.
func get_gold_value() -> int:
	var def = get_definition()
	if not is_instance_valid(def):
		return 1
	# Delegate to GameManager's central economy formula with custom level scaling
	var base_cost = GameManager.get_item_cost(def)
	var multiplier: int = int(pow(2, self.level - 1))
	return base_cost * multiplier

func get_stat_breakdown(all_instances_db: Dictionary = {}) -> Dictionary:
	return {
		"base": {
			"hp": get_definition_base_hp(),
			"pwr": get_definition_base_pwr(),
		},
		"persistent": {
			"hp": get_persistent_hp_modifier(),
			"pwr": get_persistent_pwr_modifier(),
		},
		"equipment": {
			"hp": get_equipment_hp_modifier(all_instances_db),
			"pwr": get_equipment_pwr_modifier(all_instances_db),
		},
		"battle": {
			"hp": get_battle_hp_modifier(),
			"pwr": get_battle_pwr_modifier(),
		},
		"current": {
			"hp": current_hp,
			"pwr": current_pwr,
		},
		"components": _serialize_components(get_active_components(all_instances_db), false),
	}

func get_definition_base_hp() -> int:
	var def = get_definition()
	if is_instance_valid(def) and "base_hp" in def:
		return int(def.base_hp)
	return 0

func get_definition_base_pwr() -> int:
	var def = get_definition()
	if is_instance_valid(def) and "base_pwr" in def:
		return int(def.base_pwr)
	return 0

func get_persistent_hp_modifier() -> int:
	return _sum_own_component_stat(&"hp")

func get_persistent_pwr_modifier() -> int:
	return _sum_own_component_stat(&"pwr")

func get_equipment_hp_modifier(all_instances_db: Dictionary) -> int:
	return _sum_components_stat(_build_equipment_components(all_instances_db), &"hp", true)

func get_equipment_pwr_modifier(all_instances_db: Dictionary) -> int:
	return _sum_components_stat(_build_equipment_components(all_instances_db), &"pwr", true)

func get_battle_hp_modifier() -> int:
	return _sum_components_stat(battle_components, &"hp", true)

func get_battle_pwr_modifier() -> int:
	return _sum_components_stat(battle_components, &"pwr", true)

func get_effective_starting_hp(all_instances_db: Dictionary = {}) -> int:
	var total = get_definition_base_hp() + get_persistent_hp_modifier() + get_equipment_hp_modifier(all_instances_db) + get_battle_hp_modifier()
	return max(1, total)

func get_effective_starting_pwr(all_instances_db: Dictionary = {}) -> int:
	var total = get_definition_base_pwr() + get_persistent_pwr_modifier() + get_equipment_pwr_modifier(all_instances_db) + get_battle_pwr_modifier()
	return max(1, total)

func apply_hp_delta(amount: int, context: Dictionary = {}) -> int:
	var old_hp := current_hp
	
	if amount < 0:
		var max_drop = max(0, current_hp - 1)
		var actual_drop = min(abs(amount), max_drop)
		var debt_added = abs(amount) - actual_drop
		_hp_debt += debt_added
		current_hp -= actual_drop
		
		if actual_drop > 0:
			var comp = StatComponent.new()
			comp.id = &"battle_hp_loss"
			comp.category = &"COMBAT_STATE"
			comp.modifiers = {"hp": -actual_drop}
			battle_components.append(comp)
			
	elif amount > 0:
		var debt_paid = min(amount, _hp_debt)
		_hp_debt -= debt_paid
		var actual_gain = amount - debt_paid
		current_hp += actual_gain
		
		if actual_gain > 0:
			var comp = StatComponent.new()
			comp.id = &"battle_hp_gain"
			comp.category = &"COMBAT_STATE"
			comp.modifiers = {"hp": actual_gain}
			battle_components.append(comp)
		
	if not bool(context.get("silent", false)) and old_hp != current_hp:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"hp", old_hp, current_hp)
	return current_hp

func apply_pwr_delta(amount: int, context: Dictionary = {}) -> int:
	var old_pwr := current_pwr
	
	if amount < 0:
		var max_drop = max(0, current_pwr - 1)
		var actual_drop = min(abs(amount), max_drop)
		var debt_added = abs(amount) - actual_drop
		_pwr_debt += debt_added
		current_pwr -= actual_drop
		
		if actual_drop > 0:
			var comp = StatComponent.new()
			comp.id = &"battle_pwr_loss"
			comp.category = &"COMBAT_STATE"
			comp.modifiers = {"pwr": -actual_drop}
			battle_components.append(comp)
			
	elif amount > 0:
		var debt_paid = min(amount, _pwr_debt)
		_pwr_debt -= debt_paid
		var actual_gain = amount - debt_paid
		current_pwr += actual_gain
		
		if actual_gain > 0:
			var comp = StatComponent.new()
			comp.id = &"battle_pwr_gain"
			comp.category = &"COMBAT_STATE"
			comp.modifiers = {"pwr": actual_gain}
			battle_components.append(comp)
		
	if not bool(context.get("silent", false)) and old_pwr != current_pwr:
		SignalBus.emit_signal("unit_stat_changed", self.ball_uuid, &"pwr", old_pwr, current_pwr)
	return current_pwr

func add_component(component: GachaBallComponent) -> void:
	if not is_instance_valid(component):
		return
	if not component.allow_stacking:
		remove_component_by_id(component.id)
	components.append(component)

func add_battle_component(component: GachaBallComponent) -> void:
	if not is_instance_valid(component):
		return
	component.is_battle_only = true
	component.is_persistent = false
	if not component.allow_stacking:
		remove_battle_component_by_id(component.id)
	battle_components.append(component)

func add_or_update_stat_component(component_id: StringName, source_type: StringName, source_id: String,
		hp_delta: int = 0, pwr_delta: int = 0, _unused: bool = false,
		display_name_key: String = "", description_key: String = "") -> void:
	if hp_delta == 0 and pwr_delta == 0:
		return
	var stat_component: StatComponent = null
	for component in components:
		if component is StatComponent and component.id == component_id:
			stat_component = component
			break
	if not is_instance_valid(stat_component):
		stat_component = StatComponent.new()
		stat_component.id = component_id
		stat_component.category = &"STAT"
		stat_component.source_type = source_type
		stat_component.source_id = source_id
		stat_component.display_name_key = display_name_key
		stat_component.description_key = description_key
		components.append(stat_component)
	stat_component.modifiers["hp"] = _get_modifier_value(stat_component.modifiers, &"hp") + hp_delta
	stat_component.modifiers["pwr"] = _get_modifier_value(stat_component.modifiers, &"pwr") + pwr_delta

func add_or_update_tag_component(component_id: StringName, source_type: StringName, source_id: String,
		attributes: Dictionary = {}, tags_to_add: Array = [], tags_to_remove: Array = [],
		display_name_key: String = "", description_key: String = "") -> void:
	var tag_component: TagComponent = null
	for component in components:
		if component is TagComponent and component.id == component_id:
			tag_component = component
			break
	if not is_instance_valid(tag_component):
		tag_component = TagComponent.new()
		tag_component.id = component_id
		tag_component.category = &"TAG"
		tag_component.source_type = source_type
		tag_component.source_id = source_id
		tag_component.display_name_key = display_name_key
		tag_component.description_key = description_key
		components.append(tag_component)
	
	for key in attributes:
		tag_component.attributes[key] = attributes[key]
	for tag in tags_to_add:
		if not tag in tag_component.tags_to_add:
			tag_component.tags_to_add.append(tag)
	for tag in tags_to_remove:
		if not tag in tag_component.tags_to_remove:
			tag_component.tags_to_remove.append(tag)

func remove_component_by_id(component_id: StringName) -> void:
	for i in range(components.size() - 1, -1, -1):
		if components[i].id == component_id:
			components.remove_at(i)

func remove_battle_component_by_id(component_id: StringName) -> void:
	for i in range(battle_components.size() - 1, -1, -1):
		if battle_components[i].id == component_id:
			battle_components.remove_at(i)

func has_component(component_id: StringName) -> bool:
	for component in components:
		if component.id == component_id:
			return true
	for component in battle_components:
		if component.id == component_id:
			return true
	return false

func apply_prismatic_variant() -> void:
	var already_prismatic := has_component(&"prismatic_stat")
	_ensure_prismatic_components()

	# Recalculate stats from components (prismatic adds +2/+2 via its StatComponent)
	current_hp = get_definition_base_hp() + get_persistent_hp_modifier()
	current_pwr = get_definition_base_pwr() + get_persistent_pwr_modifier()

func _add_ability_entry(entries: Array[Dictionary], seen: Dictionary, ability: AbilityDefinition,
		source_uuid: String, source_type: StringName, holder_uuid: String, priority_value: int,
		component_id: StringName) -> void:
	if not is_instance_valid(ability):
		return
	if self.level < ability.required_level or self.level > ability.max_level:
		return
	var seen_key := "%s|%s" % [String(ability.id), source_uuid]
	if seen.has(seen_key):
		return
	seen[seen_key] = true
	entries.append({
		"ability_def": ability,
		"source_instance_uuid": source_uuid,
		"source_type": source_type,
		"holder_uuid": holder_uuid,
		"priority": priority_value if priority_value != 0 else ability.priority,
		"component_id": component_id,
	})

func _build_definition_components() -> Array[GachaBallComponent]:
	var result: Array[GachaBallComponent] = []
	var def = get_definition()
	if not is_instance_valid(def):
		return result

	var tag_component := TagComponent.new()
	tag_component.id = &"base_definition_attributes"
	tag_component.category = &"IDENTITY"
	tag_component.source_type = &"BASE_DEFINITION"
	tag_component.source_id = String(definition_id)
	tag_component.priority = -1000
	tag_component.is_persistent = false
	if "tags" in def:
		tag_component.tags_to_add = def.tags.duplicate()
	if "tier" in def:
		tag_component.attributes[&"tier"] = def.tier
	if "category" in def:
		tag_component.attributes[&"category"] = def.category
	if "level" in def:
		tag_component.attributes[&"level"] = def.level
	else:
		tag_component.attributes[&"level"] = 1
	# Rarity is determined by components (e.g., prismatic_rarity TagComponent)
	var rarity: StringName = &"normal"
	for comp in components:
		if comp is TagComponent and comp.attributes.has(&"rarity"):
			rarity = comp.attributes[&"rarity"]
			break
	tag_component.attributes[&"rarity"] = rarity
	result.append(tag_component)

	if "ability_definitions" in def and def.ability_definitions != null and not def.ability_definitions.is_empty():
		var ability_component := AbilityComponent.new()
		ability_component.id = &"base_definition_abilities"
		ability_component.category = &"ABILITY"
		ability_component.source_type = &"BASE_DEFINITION"
		ability_component.source_id = String(definition_id)
		ability_component.priority = -900
		ability_component.is_persistent = false
		for ability_def in def.ability_definitions:
			ability_component.add_ability_definition(ability_def)
		result.append(ability_component)

	return result

func _build_dynamic_state_components() -> Array[GachaBallComponent]:
	var result: Array[GachaBallComponent] = []
	if not dynamic_tags.is_empty():
		var dynamic_tag_component := TagComponent.new()
		dynamic_tag_component.id = &"legacy_dynamic_tags"
		dynamic_tag_component.category = &"TAG"
		dynamic_tag_component.source_type = &"STATUS"
		dynamic_tag_component.source_id = "dynamic_tags"
		dynamic_tag_component.is_persistent = false
		dynamic_tag_component.is_battle_only = true
		dynamic_tag_component.tags_to_add = dynamic_tags.duplicate()
		result.append(dynamic_tag_component)

	if not status_effects.is_empty():
		var status_tag_component := TagComponent.new()
		status_tag_component.id = &"legacy_status_effects"
		status_tag_component.category = &"STATUS"
		status_tag_component.source_type = &"STATUS"
		status_tag_component.source_id = "status_effects"
		status_tag_component.is_persistent = false
		status_tag_component.is_battle_only = true
		status_tag_component.attributes = status_effects.duplicate(true)
		result.append(status_tag_component)
	return result

func _build_equipment_components(all_instances_db: Dictionary) -> Array[GachaBallComponent]:
	var result: Array[GachaBallComponent] = []
	if all_instances_db.is_empty():
		return result

	for slot_index in range(equipped_item_uuids.size()):
		var item_uuid := equipped_item_uuids[slot_index]
		if item_uuid.is_empty():
			continue
		var item_instance: GachaBallInstance = all_instances_db.get(item_uuid)
		if not is_instance_valid(item_instance):
			continue
		var item_def = item_instance.get_definition()
		if not is_instance_valid(item_def):
			continue

		if ("bonus_hp" in item_def and int(item_def.bonus_hp) != 0) or ("bonus_pwr" in item_def and int(item_def.bonus_pwr) != 0):
			var stat_component := StatComponent.new()
			stat_component.id = StringName("equipment_stats_%s" % item_uuid)
			stat_component.category = &"STAT"
			stat_component.source_type = &"EQUIPMENT"
			stat_component.source_id = item_uuid
			stat_component.priority = slot_index
			stat_component.is_persistent = false
			stat_component.modifiers = {
				"hp": int(item_def.bonus_hp) if "bonus_hp" in item_def else 0,
				"pwr": int(item_def.bonus_pwr) if "bonus_pwr" in item_def else 0,
			}
			result.append(stat_component)

		if "tags" in item_def and not item_def.tags.is_empty():
			var tag_component := TagComponent.new()
			tag_component.id = StringName("equipment_tags_%s" % item_uuid)
			tag_component.category = &"TAG"
			tag_component.source_type = &"EQUIPMENT"
			tag_component.source_id = item_uuid
			tag_component.priority = slot_index
			tag_component.is_persistent = false
			tag_component.tags_to_add = item_def.tags.duplicate()
			result.append(tag_component)

		if "ability_definitions" in item_def and item_def.ability_definitions != null and not item_def.ability_definitions.is_empty():
			var ability_component := AbilityComponent.new()
			ability_component.id = StringName("equipment_abilities_%s" % item_uuid)
			ability_component.category = &"ABILITY"
			ability_component.source_type = &"EQUIPMENT"
			ability_component.source_id = item_uuid
			ability_component.priority = slot_index
			ability_component.is_persistent = false
			for ability_def in item_def.ability_definitions:
				ability_component.add_ability_definition(ability_def)
			result.append(ability_component)

		if "icon" in item_def and is_instance_valid(item_def.icon):
			var visual_component := VisualComponent.new()
			visual_component.id = StringName("equipment_visual_%s" % item_uuid)
			visual_component.category = &"VISUAL"
			visual_component.source_type = &"EQUIPMENT"
			visual_component.source_id = item_uuid
			visual_component.priority = slot_index
			visual_component.is_persistent = false
			visual_component.overlay_icon = item_def.icon
			visual_component.layer = slot_index
			result.append(visual_component)

	return result

func _sum_own_component_stat(stat_name: StringName) -> int:
	var result := 0
	for component in components:
		if not component is StatComponent:
			continue
		var stat_component := component as StatComponent
		if stat_component.is_battle_only:
			continue
		result += _get_modifier_value(stat_component.modifiers, stat_name)
	return result

func _sum_components_stat(component_list: Array, stat_name: StringName, _include_all: bool = true) -> int:
	var result := 0
	for component in component_list:
		if not component is StatComponent:
			continue
		result += _get_modifier_value((component as StatComponent).modifiers, stat_name)
	return result

func _get_modifier_value(modifiers: Dictionary, stat_name: StringName) -> int:
	if modifiers.has(stat_name):
		return int(modifiers[stat_name])
	var stat_key := String(stat_name)
	if modifiers.has(stat_key):
		return int(modifiers[stat_key])
	return 0

func _duplicate_components(source_components: Array[GachaBallComponent]) -> Array[GachaBallComponent]:
	var result: Array[GachaBallComponent] = []
	for component in source_components:
		if is_instance_valid(component):
			result.append(component.duplicate(true))
	return result

func _serialize_components(component_list: Array, persistent_only: bool = false) -> Array:
	var result: Array = []
	for component in component_list:
		if not is_instance_valid(component):
			continue
		if persistent_only and (not component.is_persistent or component.is_battle_only):
			continue
		result.append(component.to_save_dict())
	return result

func _deserialize_components(data: Array) -> void:
	components.clear()
	for component_data in data:
		if not component_data is Dictionary:
			continue
		var component := GachaBallComponent.from_save_dict(component_data)
		if is_instance_valid(component) and component.is_persistent and not component.is_battle_only:
			components.append(component)

func _ensure_prismatic_components() -> void:
	if not has_component(&"prismatic_stat"):
		var stat_component := StatComponent.new()
		stat_component.id = &"prismatic_stat"
		stat_component.display_name_key = "rarity.prismatic.name"
		stat_component.description_key = "rarity.prismatic.desc"
		stat_component.category = &"STAT"
		stat_component.source_type = &"RARITY"
		stat_component.source_id = "prismatic"
		stat_component.priority = -50
		stat_component.modifiers = {"hp": 2, "pwr": 2}
		add_component(stat_component)

	if not has_component(&"prismatic_rarity"):
		var tag_component := TagComponent.new()
		tag_component.id = &"prismatic_rarity"
		tag_component.display_name_key = "rarity.prismatic.name"
		tag_component.description_key = "rarity.prismatic.desc"
		tag_component.category = &"IDENTITY"
		tag_component.source_type = &"RARITY"
		tag_component.source_id = "prismatic"
		tag_component.priority = -50
		tag_component.attributes = {&"rarity": &"prismatic"}
		add_component(tag_component)

	if not has_component(&"prismatic_visual"):
		var visual_component := VisualComponent.new()
		visual_component.id = &"prismatic_visual"
		visual_component.display_name_key = "rarity.prismatic.name"
		visual_component.description_key = "rarity.prismatic.desc"
		visual_component.category = &"VISUAL"
		visual_component.source_type = &"RARITY"
		visual_component.source_id = "prismatic"
		visual_component.priority = -50
		visual_component.shader_path = "res://assets/shaders/prismatic_foil.gdshader"
		visual_component.modulate = Color(1.2, 1.2, 1.2, 1.0)
		visual_component.layer = 10
		visual_component.call("_resolve_resources")
		add_component(visual_component)

	if not has_component(&"prismatic_ability"):
		var ability_component := AbilityComponent.new()
		ability_component.id = &"prismatic_ability"
		ability_component.display_name_key = "rarity.prismatic.name"
		ability_component.description_key = "rarity.prismatic.desc"
		ability_component.category = &"ABILITY"
		ability_component.source_type = &"RARITY"
		ability_component.source_id = "prismatic"
		ability_component.priority = -50
		var tiger_spirit_def := Database.get_ability_definition(&"item_tier1b_extra_attack")
		if is_instance_valid(tiger_spirit_def):
			ability_component.add_ability_definition(tiger_spirit_def)
		add_component(ability_component)

func _ensure_prismatic_legacy_ability() -> void:
	var tiger_spirit_def := Database.get_ability_definition(&"item_tier1b_extra_attack")
	if not is_instance_valid(tiger_spirit_def):
		return
## Migrate legacy save data into components. Called once during from_save_dict.
## Converts old variant_id and base_hp/pwr_modifier fields into proper components.
func _migrate_legacy_state_to_components(legacy_variant_id: StringName, legacy_hp_mod: int, legacy_pwr_mod: int) -> void:
	# Migrate prismatic variant into components
	if legacy_variant_id == &"prismatic":
		_ensure_prismatic_components()

	# Migrate legacy base modifiers into a StatComponent (if not already present from components)
	if legacy_hp_mod != 0 or legacy_pwr_mod != 0:
		var already_has_modifier := false
		for comp in components:
			if comp is StatComponent and comp.source_type == &"PERMANENT_UPGRADE":
				already_has_modifier = true
				break
		if not already_has_modifier:
			add_or_update_stat_component(
				&"legacy_base_modifiers",
				&"PERMANENT_UPGRADE",
				"legacy_base_modifiers",
				legacy_hp_mod,
				legacy_pwr_mod,
				false
			)

# --- Serialization ---
## Converts this instance to a Dictionary for saving.
func to_save_dict() -> Dictionary:
	return {
		"definition_id": String(definition_id),
		"ball_uuid": ball_uuid,
		"origin_uuid": origin_uuid,
		"level": level,
		"current_hp": current_hp,
		"current_pwr": current_pwr,
		"location_container_tag": String(location_container_tag),
		"location_slot_index": location_slot_index,
		"equipped_on_uuid": equipped_on_uuid,
		"equipped_slot_index": equipped_slot_index,
		"equipped_item_uuids": equipped_item_uuids.duplicate(),
		"dynamic_tags": _serialize_tags(),
		"status_effects": status_effects.duplicate(),
		"components": _serialize_components(components, true),
	}

## Restores this instance from a saved Dictionary.
func from_save_dict(data: Dictionary) -> void:
	definition_id = StringName(data.get("definition_id", ""))
	ball_uuid = data.get("ball_uuid", "")
	origin_uuid = data.get("origin_uuid", "")
	level = int(data.get("level", 1))
	current_hp = data.get("current_hp", 0)
	current_pwr = data.get("current_pwr", 0)
	location_container_tag = StringName(data.get("location_container_tag", ""))
	location_slot_index = data.get("location_slot_index", -1)
	equipped_on_uuid = data.get("equipped_on_uuid", "")
	equipped_slot_index = data.get("equipped_slot_index", -1)
	
	# Restore equipped_item_uuids
	var saved_items: Array = data.get("equipped_item_uuids", [])
	equipped_item_uuids.clear()
	for item_uuid in saved_items:
		equipped_item_uuids.append(str(item_uuid))
	
	_deserialize_tags(data.get("dynamic_tags", []))
	
	# Restore status effects
	var saved_effects: Dictionary = data.get("status_effects", {})
	status_effects.clear()
	for key in saved_effects.keys():
		status_effects[StringName(str(key))] = saved_effects[key]
	
	_deserialize_components(data.get("components", []))
	battle_components.clear()
	
	# Migrate legacy fields from old saves into components, then discard
	var legacy_variant := StringName(data.get("variant_id", ""))
	var legacy_hp_mod := int(data.get("base_hp_modifier", 0))
	var legacy_pwr_mod := int(data.get("base_pwr_modifier", 0))
	_migrate_legacy_state_to_components(legacy_variant, legacy_hp_mod, legacy_pwr_mod)

func _serialize_tags() -> Array:
	var result: Array = []
	for tag in dynamic_tags:
		result.append(String(tag))
	return result

func _deserialize_tags(data: Array) -> void:
	dynamic_tags.clear()
	for tag_str in data:
		dynamic_tags.append(StringName(str(tag_str)))

# --- Utilities ---
func get_definition() -> Resource:
	return Database.get_definition(definition_id)
