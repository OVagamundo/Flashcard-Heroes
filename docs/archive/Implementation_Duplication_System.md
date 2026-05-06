# Comprehensive Implementation Guide: Duplication & Resurrection System

This document provides a complete technical blueprint of the **Doppleganger**, **Echoing Orb**, and **Soul Echo** features. It includes all localization strings, asset paths, animation parameters, and full source code for the logic scripts.

---

## 1. Localization Strings (game.csv)
Ensure these keys are added to your localization source before compiling.

| Key | English (en) | Portuguese (pt_BR) |
| :--- | :--- | :--- |
| **unit_t3_i.name** | Doppleganger | Doppleganger |
| **unit_t3_i.desc** | A shape-shifting entity that grows stronger with each copy of itself. When defeated, it spawns another clone. | Uma entidade metamorfa que fica mais forte a cada cópia de si mesma. Quando derrotada, gera outro clone. |
| **ability.doppleganger_scale.name** | Mirrored Might | Força Espelhada |
| **ability.doppleganger_scale.desc** | Passive: Gains +3 PWR for every other Doppleganger in the Battle Pool. | Passivo: Ganha +3 PWR para cada outro Doppleganger no Conjunto de Batalha. |
| **ability.doppleganger_death.name** | Clone Split | Divisão de Clone |
| **ability.doppleganger_death.desc** | On death, spawn an additional Doppleganger into the Discard Pile. | Ao morrer, gera um Doppleganger adicional na Pilha de Descarte. |
| **item_t2_d.name** | Echoing Orb | Orbe Ressonante |
| **item_t2_d.desc** | A mystical orb that resonates with its copies, amplifying power. Duplicates itself upon the holder's death. | Um orbe místico que ressoa com suas cópias, amplificando o poder. Duplica-se quando o portador morre. |
| **ability.echoing_orb_scale.name** | Resonance | Ressonância |
| **ability.echoing_orb_scale.desc** | Passive: Grants the holder +2 PWR for every other Echoing Orb in the Battle Pool. | Passivo: Concede ao portador +2 PWR para cada outro Orbe Ressonante no Conjunto de Batalha. |
| **ability.echoing_orb_death.name** | Echo Split | Divisão de Eco |
| **ability.echoing_orb_death.desc** | When the holder dies, create a copy of Echoing Orb in the Discard Pile. | Quando o portador morre, cria uma cópia do Orbe Ressonante na Pilha de Descarte. |
| **trinket.soul_echo.name** | Soul Echo | Eco da Alma |
| **trinket.soul_echo.desc** | A mystical gem that echoes the souls of the fallen. | Uma gema mística que ecoa as almas dos caídos. |
| **ability.soul_echo.name** | Soul Echo | Eco da Alma |
| **ability.soul_echo.desc** | When an ally dies, resurrect the first non-hero unit that died this turn. | Quando um aliado morre, ressuscita a primeira unidade não-herói que morreu neste turno. |

---

## 2. Visual Assets & Textures
- **Doppleganger Sprite**: `res://assets/sprites/units/Tier3unitI.png`
- **Echoing Orb Sprite**: `res://assets/sprites/items/Tier2ItemD.png`
- **Soul Echo Sprite**: `res://assets/sprites/trinkets/Trinket3A.png`

---

## 3. The Doppleganger (Unit: unit_t3_i)
**Resource Path**: `res://resources/units/UnitTier3I.tres`

### Core Stats:
- Tier: 3 | Cost: 4 | HP: 3 | PWR: 3
- Abilities: 
  - `BasicAttack.tres`
  - `ability_doppleganger_scale` (Triggers: `on_pre_combat`, `on_turn_start`, `on_ally_death`, `on_unit_death`)
  - `ability_doppleganger_death` (Trigger: `on_death`, Priority: 205, Execute on Lethal: True)

### Scaling Logic (EffectDopplegangerScaling.gd):
```gdscript
# Grants +3 PWR for every OTHER instance of Doppleganger in the Battle Pool.
func execute(source_uuid: String, targets: Array[String], battle_manager: Node, context: Dictionary) -> Variant:
    var is_simulation = context.get("is_simulation", false)
    var all_instances = battle_manager.get_all_instances()
    var copy_count = 0
    for uuid in all_instances:
        if uuid == source_uuid: continue
        var inst = all_instances[uuid]
        if inst.definition_id == &"unit_t3_i": copy_count += 1
    
    var bonus_pwr = copy_count * 3
    var source = battle_manager.get_instance_by_uuid(source_uuid)
    var last_scaling = source.get_status_effect_amount(&"doppleganger_scaling")
    var delta = bonus_pwr - last_scaling
    
    if delta == 0: return EffectResult.empty() if is_simulation else null

    # Update state
    if last_scaling > 0: source.status_effects.erase(&"doppleganger_scaling")
    if bonus_pwr > 0: source.status_effects[&"doppleganger_scaling"] = bonus_pwr
    source.current_pwr += delta

    if is_simulation:
        var result = EffectResult.new()
        result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
            "text": "Doppleganger scales to %d PWR (%d copies)" % [source.current_pwr, copy_count]
        }))
        result.state_applied = true
        return result
    return delta
```

---

## 4. The Echoing Orb (Item: item_t2_d)
**Resource Path**: `res://resources/items/ItemTier2D.tres`

### Core Stats:
- Tier: 2 | Cost: 2 | Bonus PWR: +2
- Abilities:
  - `ability_echoing_orb_scale` (Triggers: `on_pre_combat`, `on_turn_start`, `on_ally_death`)
  - `ability_echoing_orb_death` (Trigger: `on_death`, Priority: 200, Execute on Lethal: True)

---

## 5. The Soul Echo (Trinket: trinket_soul_echo)
**Resource Path**: `res://resources/trinkets/trinket_soul_echo.tres`

### Resurrection Logic (EffectResurrectFirstKilledUnit.gd):
```gdscript
# Resurrects the first ally that died this turn. Triggers once per turn.
func execute(_source_uuid: String, _targets: Array[String], battle_manager: Node, context: Dictionary) -> EffectResult:
    var team = context.get("fainting_ally_team", "")
    var flag = "resurrection_done_" + team.to_lower()
    
    if battle_manager._turn_metadata.get(flag, false): return EffectResult.empty()
    
    var first_killed_key = "first_killed_" + team.to_lower() + "_unit"
    var killed_data = battle_manager._turn_metadata.get(killed_key, {})
    if killed_data.is_empty(): return EffectResult.empty()
    
    battle_manager._turn_metadata[flag] = true
    var result = EffectResult.new()
    result.summon_request = {
        "summon_unit_id": killed_data.get("def_id"),
        "holder_uuid": killed_data.get("uuid", ""), # Critical: Pass original UUID
        "holder_location": context.get("fainting_ally_location"),
        "is_resurrection": true
    }
    return result
```

---

## 6. Shared Duplication Script
**Path**: `res://scripts/effects/EffectDuplicateToDiscard.gd`

```gdscript
func execute(source_uuid: String, _targets: Array[String], _bm: Node, context: Dictionary) -> EffectResult:
    var dup_def_id = parameters.get("duplicate_def_id", &"")
    var dup_type = parameters.get("duplicate_type", "UNIT")
    var dying_uuid = context.get("dying_uuid", source_uuid)
    
    # Item-specific safety check
    if dup_type == "ITEM":
        var equipped = context.get("equipped_items", [])
        var found = false
        for item in equipped:
            if item.get("uuid") == source_uuid: found = true; break
        if not found: return EffectResult.empty()

    var result = EffectResult.new()
    result.spawn_request = {
        "spawn_unit_id": dup_def_id,
        "holder_location": LocationIdentifier.new(&"DiscardPile", -1),
        "spawn_source_uuid": dying_uuid # For Arc Animation
    }
    return result
```

---

## 7. Animation Details (BattleAnimator.gd)
Duplication uses a specialized arc animation to provide visual feedback of the "copy" flying to the discard pile.

- **Trigger**: `CombatEvent.Type.SUMMON` or `CombatEvent.Type.SPAWN` with `spawn_source_uuid`.
- **Duration**: `0.45s`
- **Arc Height**: `400.0px`
- **Easing**: `pow(t, 0.55)` (Fast launch, snappy landing)
- **Pathing**: Quadratic Bezier curve from the dying unit to the Discard Pile button.

---

## 8. Critical Architectural Hooks

### Discard Pile (BucketContainer)
The `DiscardPile` MUST be initialized as a `BucketContainer` (unlimited size).
- **RunState.gd**: `containers[&"DiscardPile"] = BucketContainer.new()`
- **BattleState.gd**: `containers[&"DiscardPile"] = BucketContainer.new()`

### BattleManager Spawning
Always use `bm_add_instance` for duplications:
```gdscript
func bm_add_instance(instance: GachaBallInstance, container: StringName, index: int):
    # 1. Register in BattleState
    # 2. Emit signal for BattleAnimator to create the view
    # 3. Add to the specified container
```

### DeathProcessor Sequencing
Ensure `on_death` triggers are processed **BEFORE** the unit is cleared from the board. This allows the Doppleganger to trigger its own duplication effect before the source unit is removed.

### Turn Metadata (BattleManager.gd)
The **Soul Echo** resurrection logic relies on tracking the first unit to die each turn. Ensure `BattleManager.gd` populates these keys in its `_turn_metadata` dictionary:
- `first_killed_player_unit`: Stores a snapshot of the first player unit that reached 0 HP.
- `first_killed_enemy_unit`: Stores a snapshot of the first enemy unit that reached 0 HP.
- `resurrection_done_player`: A boolean flag to prevent double-resurrection.
- `resurrection_done_enemy`: A boolean flag to prevent double-resurrection.

These should be cleared at the start of every turn.
