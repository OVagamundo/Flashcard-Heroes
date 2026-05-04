# Session Change Log: Exhaustive Technical Diff

This document contains the full source code and data for every component implemented in this session. Use this to restore the duplication/resurrection logic after rolling back.

---

## 1. New Logic Scripts

### EffectDuplicateToDiscard.gd
**Path**: `res://scripts/effects/EffectDuplicateToDiscard.gd`
```gdscript
# res://scripts/effects/EffectDuplicateToDiscard.gd
@tool
extends EffectDefinition

## Spawns a duplicate of a specified definition into the Discard Pile.
## Used by Doppleganger (on_death: duplicate self) and Echoing Orb (on_death: duplicate item).

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var result := EffectResult.new()

	var dup_def_id: StringName = parameters.get("duplicate_def_id", &"")
	var dup_type: String = parameters.get("duplicate_type", "UNIT")

	var dying_uuid: String = context.get("dying_uuid", "")
	if dying_uuid.is_empty() and dup_type == "UNIT":
		dying_uuid = source_uuid # Fallback for self-triggered death
	
	if dup_def_id.is_empty():
		return EffectResult.empty()

	var dup_def = Database.get_definition(dup_def_id)
	if not is_instance_valid(dup_def):
		return EffectResult.empty()

	if dup_type == "ITEM":
		var equipped_items: Array = context.get("equipped_items", [])
		var item_found := false
		for item_data in equipped_items:
			if item_data.get("uuid") == source_uuid:
				item_found = true
				break
		if not item_found:
			return EffectResult.empty()

	var discard_location := LocationIdentifier.new(C.BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE, -1)

	result.spawn_request = {
		"spawn_unit_id": dup_def_id,
		"holder_uuid": "", 
		"holder_location": discard_location,
		"is_resurrection": false,
		"spawn_source_uuid": dying_uuid, 
		"unit_tier": dup_def.tier if "tier" in dup_def else 1
	}

	var display_name: String = ""
	if "display_name_key" in dup_def:
		display_name = tr(dup_def.display_name_key)
	elif "name_key" in dup_def:
		display_name = tr(dup_def.name_key)
	if display_name.is_empty():
		display_name = String(dup_def_id)

	result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
		"text": "A copy of %s was added to the Discard Pile!" % display_name
	}))

	return result
```

### EffectDopplegangerScaling.gd
**Path**: `res://scripts/effects/EffectDopplegangerScaling.gd`
```gdscript
# res://scripts/effects/EffectDopplegangerScaling.gd
@tool
extends EffectDefinition

## Doppleganger Scaling: Grants +3 PWR for every OTHER instance of "Doppleganger"
## currently in the Battle Pool.

const DOPPLEGANGER_DEF_ID: StringName = &"unit_t3_i"
const PWR_PER_COPY: int = 3

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	if targets.is_empty():
		return EffectResult.empty() if is_simulation else null

	var all_instances: Dictionary = battle_manager.get_all_instances()
	var copy_count: int = 0
	for uuid in all_instances:
		if uuid == source_uuid:
			continue
		var inst: GachaBallInstance = all_instances[uuid]
		if not is_instance_valid(inst):
			continue
		if inst.definition_id == DOPPLEGANGER_DEF_ID:
			copy_count += 1

	var bonus_pwr: int = copy_count * PWR_PER_COPY
	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.empty() if is_simulation else null

	var last_scaling: int = source.get_status_effect_amount(&"doppleganger_scaling")
	var delta: int = bonus_pwr - last_scaling

	if delta == 0:
		return EffectResult.empty() if is_simulation else null

	if last_scaling > 0:
		source.status_effects.erase(&"doppleganger_scaling")
	if bonus_pwr > 0:
		source.status_effects[&"doppleganger_scaling"] = bonus_pwr

	if is_simulation:
		var result := EffectResult.new()
		var old_pwr: int = source.current_pwr
		source.current_pwr += delta
		var new_pwr: int = source.current_pwr

		result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
			"text": "Doppleganger scales to %d PWR (%d copies detected)" % [new_pwr, copy_count]
		}))
		result.state_applied = true
		return result
	else:
		source.current_pwr += delta
		return delta
```

### EffectEchoingOrbScaling.gd
**Path**: `res://scripts/effects/EffectEchoingOrbScaling.gd`
```gdscript
# res://scripts/effects/EffectEchoingOrbScaling.gd
@tool
extends EffectDefinition

## Echoing Orb Scaling: Grants the HOLDER +2 PWR for every instance of "Echoing Orb"
## currently in the Battle Pool.

const ECHOING_ORB_DEF_ID: StringName = &"item_t2_d"
const PWR_PER_COPY: int = 2

func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
	var is_simulation: bool = context.get("is_simulation", false)
	if targets.is_empty():
		return EffectResult.empty() if is_simulation else null

	var source: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source):
		return EffectResult.empty() if is_simulation else null

	var holder_uuid: String = source.equipped_on_uuid
	if holder_uuid.is_empty():
		return EffectResult.empty() if is_simulation else null

	var holder: GachaBallInstance = battle_manager.get_instance_by_uuid(holder_uuid)
	if not is_instance_valid(holder) or holder.current_hp <= 0:
		return EffectResult.empty() if is_simulation else null

	var all_instances: Dictionary = battle_manager.get_all_instances()
	var other_orb_count: int = 0
	for uuid in all_instances:
		if uuid == source_uuid:
			continue
		var inst: GachaBallInstance = all_instances[uuid]
		if not is_instance_valid(inst):
			continue
		if inst.definition_id == ECHOING_ORB_DEF_ID:
			other_orb_count += 1

	var bonus_pwr: int = other_orb_count * PWR_PER_COPY
	var scaling_key: StringName = &"echoing_orb_scaling"
	var last_scaling: int = holder.get_status_effect_amount(scaling_key)
	var delta: int = bonus_pwr - last_scaling

	if delta == 0:
		return EffectResult.empty() if is_simulation else null

	if last_scaling > 0:
		holder.status_effects.erase(scaling_key)
	if bonus_pwr > 0:
		holder.status_effects[scaling_key] = bonus_pwr

	if is_simulation:
		var result := EffectResult.new()
		holder.current_pwr += delta
		result.state_applied = true
		return result
	else:
		holder.current_pwr += delta
		return delta
```

### EffectResurrectFirstKilledUnit.gd
**Path**: `res://scripts/EffectResurrectFirstKilledUnit.gd`
```gdscript
# res://scripts/EffectResurrectFirstKilledUnit.gd
@tool
extends EffectDefinition

## Effect: Resurrect the first non-hero unit that died this turn.

func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
	var fainting_ally_team: String = context.get("fainting_ally_team", "")
	if fainting_ally_team.is_empty():
		return EffectResult.empty()
	
	var is_player_team := (fainting_ally_team == "PLAYER")
	var flag_key := "resurrection_done_player" if is_player_team else "resurrection_done_enemy"
	if battle_manager._turn_metadata.get(flag_key, false):
		return EffectResult.empty() 

	var killed_key := "first_killed_player_unit" if is_player_team else "first_killed_enemy_unit"
	var killed_data: Dictionary = battle_manager._turn_metadata.get(killed_key, {})
	if killed_data.is_empty():
		return EffectResult.empty() 

	var def_id: StringName = killed_data.get("def_id", &"")
	var summon_location: LocationIdentifier = context.get("fainting_ally_location")
	
	battle_manager._turn_metadata[flag_key] = true

	var result := EffectResult.new()
	result.summon_request = {
		"summon_unit_id": def_id,
		"holder_uuid": killed_data.get("uuid", ""), 
		"holder_location": summon_location,
		"is_resurrection": true
	}
	return result
```

---

## 2. Resource Files (Full Data)

### Doppleganger (UnitTier3I.tres)
- ID: `unit_t3_i` | Tier: 3 | Cost: 4 | HP: 3 | PWR: 3
- Abilities (SubResources): 
  - `ability_doppleganger_scale` (PreCombat, TurnStart, AllyDeath, UnitDeath)
  - `ability_doppleganger_death` (on_death, Priority 205, Execute on Lethal)

### Echoing Orb (ItemTier2D.tres)
- ID: `item_t2_d` | Tier: 2 | Cost: 2 | Bonus PWR: 2
- Abilities (SubResources):
  - `ability_echoing_orb_scale` (PreCombat, TurnStart, AllyDeath)
  - `ability_echoing_orb_death` (on_death, Priority 200, Execute on Lethal)

### Soul Echo (trinket_soul_echo.tres)
- ID: `trinket_soul_echo` | Ability: `ability_trinket_soul_echo.tres`

---

## 3. Core System Modifications

### BattleState.gd (Reshuffle & Containers)
```gdscript
# Change in get_container() to support unlimited Discard Pile
BATTLE_CONTAINER_TAGS.BATTLE_DISCARD_PILE:
    new_container = ListContainer.new() # Was FixedArrayContainer(5)

# Ensure bm_add_instance is present
func bm_add_instance(instance: GachaBallInstance, container_name: StringName, index: int = -1) -> bool:
    var container = get_container(container_name)
    var slot := index
    if slot < 0:
        slot = container.find_first_empty_slot()
    container.set_uuid(slot, instance.ball_uuid)
    _battle_instances[instance.ball_uuid] = instance
    update_instance_location(instance.ball_uuid, container_name, slot)
    return true
```

### DeathProcessor.gd (Sequencing)
Ensure `on_death` triggers run before clearing board instances. This allows duplication effects to capture the dying unit's state correctly.

### BattleAnimator.gd (Summon/Spawn)
Ensure `CombatEvent.Type.SUMMON` handles the `spawn_source_uuid` payload to play the "arc" animation from source to machine/pile.
