# Component Composition Refactor Specification

## 1. Purpose

This refactor changes gachaballs from mostly definition-driven objects with scattered special-case state into source-aware, component-composed instances.

The goal is not simply to add a component system. The goal is to make every meaningful change to a gachaball explicit, inspectable, serializable, and resolvable from one consistent model.

A unit should be able to:

- start from a base definition;
- gain persistent run upgrades;
- gain or lose equipment;
- gain temporary battle effects;
- gain injected abilities;
- gain visual variants such as prismatic;
- carry level, tier, rarity, tags, and traits as attributes;
- merge with another gachaball and preserve the correct inherited state;
- show every active source of modification in the UI;
- save and load without losing instance-specific changes.

Two gachaballs with the same base definition must be allowed to become different individual entities.

## 2. Current Codebase Reality

The current project already has a partial instance model, but the state is spread across several unrelated fields and systems.

Current important files:

- `scripts/GachaBallDefinition.gd`: static template for units/items.
- `scripts/GachaBallInstance.gd`: runtime instance state.
- `scripts/AbilityDefinition.gd`: trigger/effect ability resource.
- `scripts/AbilityResolver.gd`: resolves unit, item, and trinket abilities.
- `scripts/InventoryManager.gd`: handles movement, equip, merge, and consumables.
- `scripts/MergeManager.gd`: calculates merge results.
- `scripts/RunState.gd`: persistent run data and save/load.
- `scripts/BattleManager.gd` and `scripts/battle/*`: battle state, combat mutation, status processing, death handling.
- `scripts/VisualDataAdapter.gd`: converts instance data into view data.
- `scripts/GachaBallView.gd`: renders gachaball visuals and stats.
- `scripts/UnitInspectionWindow.gd`, `scripts/ItemInspectionWindow.gd`: inspection UI.

Current scattered state on `GachaBallInstance` includes:

- `definition_id`
- `ball_uuid`
- `origin_uuid`
- `variant_id`
- `current_hp`
- `current_pwr`
- `base_hp_modifier`
- `base_pwr_modifier`
- `dynamic_tags`
- `status_effects`
- `abilities`
- equipment relationship fields
- location fields

Current static state on definitions includes:

- `tier`
- `category`
- `base_hp`
- `base_pwr`
- `bonus_hp`
- `bonus_pwr`
- `ability_definitions`
- `tags`
- visual `icon`

The refactor must preserve the current gameplay behavior while moving these scattered responsibilities into a clearer composition model.

## 3. Core Concept

`GachaBallInstance` should become a stateful composition container.

Meaning:

- It remains the unique runtime object for one individual gachaball.
- It keeps identity, location, live HP/PWR, and equipment relationships.
- It owns or references a list of active components.
- Those components explain why the instance has extra stats, abilities, tags, traits, rarity, level, visual effects, or temporary state.

The instance is not stateless. It is stateful because each individual gachaball must remember its own history and current attachments.

Example:

```text
Unit definition:
  Apprentice, base HP 4, base PWR 2, tier 1

Instance components:
  Level 2
  Rarity: Prismatic
  Permanent +2 HP from training
  Equipped item: Tiger Spirit
  Temporary battle +3 PWR
  Burn status: 2 stacks

Live state:
  current_hp = 5
  current_pwr = 8
```

The component system should allow the game to explain where the final values came from.

## 4. Design Principles

### 4.1 Source Awareness

Every component must know where it came from.

Examples:

- base definition
- permanent run upgrade
- equipped item UUID
- trinket
- rarity/variant
- merge inheritance
- battle status effect
- consumable
- temporary ability effect

This matters because combat, visuals, save/load, inspection, and removal rules depend on source.

### 4.2 Preserve Live Combat Semantics

HP and PWR are live gameplay numbers.

This game has no max HP. Healing is simply adding HP to current HP. Damage is subtracting HP from current HP. PWR can also be directly modified.

The refactor must not accidentally introduce a max-health model.

### 4.3 Separate Lasting Modifiers From Immediate Live Changes

Persistent and attached changes should be represented as components.

Immediate combat changes should mutate live HP/PWR through a controlled API.

For example:

- Prismatic grants persistent stat/ability/visual components.
- An equipped item grants equipment stat/ability/tag/visual components.
- A battle buff can be a battle-scoped stat component.
- Damage and healing should usually be live HP deltas, not normal persistent components.

This keeps death checks, armor mitigation, animation snapshots, and triggers understandable.

### 4.4 Keep Existing Systems Working During Migration

The refactor should be incremental.

Do not attempt to rewrite combat, inventory, UI, merge, and save/load all at once. Add compatibility methods first, then migrate callers gradually.

## 5. Target Data Model

### 5.1 GachaBallComponent

Create a new base resource:

```text
res://scripts/resources/GachaBallComponent.gd
```

Suggested fields:

```gdscript
class_name GachaBallComponent
extends Resource

@export var id: StringName
@export var display_name_key: String = ""
@export var description_key: String = ""
@export var category: StringName
@export var source_type: StringName
@export var source_id: String = ""
@export var priority: int = 0
@export var allow_stacking: bool = false
@export var is_persistent: bool = true
@export var is_battle_only: bool = false
```

`source_type` examples:

- `BASE_DEFINITION`
- `RARITY`
- `LEVEL`
- `EQUIPMENT`
- `TRINKET`
- `STATUS`
- `PERMANENT_UPGRADE`
- `BATTLE_BUFF`
- `MERGE_INHERITANCE`
- `CONSUMABLE`

`source_id` should identify the source when possible, such as an item UUID, trinket ID, status ID, or merge recipe ID.

### 5.2 Component Subtypes

#### StatComponent

Represents a lasting or attached HP/PWR modifier.

Fields:

```gdscript
@export var modifiers: Dictionary = {}
```

Example:

```text
{ "hp": 2, "pwr": 1 }
```

Use for:

- permanent upgrades;
- equipment bonuses;
- rarity bonuses;
- level bonuses;
- battle-only buffs/debuffs that should be visible as active effects.

Do not use as the primary representation for ordinary damage/healing events unless the design specifically wants a visible temporary component such as "Wound" or "Blessing."

#### AbilityComponent

Represents an ability granted, replaced, or disabled by a source.

Fields:

```gdscript
@export var ability_definitions: Array[AbilityDefinition] = []
@export_enum("ADD", "REPLACE", "DISABLE") var mode: String = "ADD"
@export var target_ability_id: StringName = &""
```

Use for:

- base abilities;
- prismatic bonus ability;
- item-granted abilities;
- trinket-granted abilities;
- temporary ability changes;
- curses/silence effects.

#### TagComponent

Represents tags, traits, level, tier, rarity, and other identity-like attributes.

Fields:

```gdscript
@export var tags_to_add: Array[StringName] = []
@export var tags_to_remove: Array[StringName] = []
@export var attributes: Dictionary = {}
```

Examples:

```text
tags_to_add: [SOUL_FIRE]
attributes: { "tier": 1, "level": 2, "rarity": "PRISMATIC" }
```

Level should be treated as a unit attribute. It can be implemented either as a native field with a component-backed source or as an attribute component. The final API should allow callers to ask:

```gdscript
instance.get_attribute(&"level")
instance.get_attribute(&"tier")
instance.get_attribute(&"rarity")
```

#### VisualComponent

Represents visual overlays, shader effects, color changes, icons, or VFX layers.

Fields may include:

```gdscript
@export var shader: Shader
@export var shader_params: Dictionary = {}
@export var modulate: Color = Color.WHITE
@export var overlay_icon: Texture2D
@export var vfx_scene: PackedScene
@export var layer: int = 0
```

Use for:

- prismatic foil;
- rarity visuals;
- equipment badges;
- status icons;
- temporary battle effects;
- future cosmetic history.

### 5.3 GachaBallInstance Target Shape

`GachaBallInstance` should remain the single source of truth for one instance.

Suggested target fields:

```gdscript
var definition_id: StringName
var ball_uuid: String
var origin_uuid: String = ""

var current_hp: int
var current_pwr: int

var components: Array[GachaBallComponent] = []
var battle_components: Array[GachaBallComponent] = []

var equipped_on_uuid: String = ""
var equipped_slot_index: int = -1
var equipped_item_uuids: Array[String] = []

var location_container_tag: StringName = &""
var location_slot_index: int = -1
```

During migration, legacy fields may remain temporarily:

- `variant_id`
- `base_hp_modifier`
- `base_pwr_modifier`
- `dynamic_tags`
- `status_effects`
- `abilities`

But the new API should become the preferred access layer.

## 6. HP/PWR Model

HP and PWR must be handled as live values with traceable sources.

### 6.1 Definitions

Base stats:

```text
The HP/PWR from the base definition.
```

Persistent modifiers:

```text
Run-long or permanent changes attached to the instance.
Examples: training, merge inheritance, prismatic bonus.
```

Equipment modifiers:

```text
Stats granted while an item is equipped.
Removing the item removes the modifier.
```

Battle modifiers:

```text
Temporary combat-only stat changes that should be visible as active effects.
Examples: temporary +PWR buff, curse, blessing.
```

Live deltas:

```text
Immediate HP/PWR changes from combat and effects.
Examples: damage, healing, direct PWR gain.
```

### 6.2 Required Behavior

There is no max HP.

Healing is:

```text
current_hp += amount
```

Damage is:

```text
current_hp -= amount
```

PWR changes are:

```text
current_pwr += amount
```

Death checks continue to use:

```text
current_hp <= 0
```

### 6.3 Recommended API

Add helper methods to `GachaBallInstance` or a stat service:

```gdscript
func get_definition_base_hp() -> int
func get_definition_base_pwr() -> int

func get_persistent_hp_modifier() -> int
func get_persistent_pwr_modifier() -> int

func get_equipment_hp_modifier(all_instances: Dictionary) -> int
func get_equipment_pwr_modifier(all_instances: Dictionary) -> int

func get_battle_hp_modifier() -> int
func get_battle_pwr_modifier() -> int

func get_effective_starting_hp(all_instances: Dictionary) -> int
func get_effective_starting_pwr(all_instances: Dictionary) -> int

func apply_hp_delta(amount: int, context: Dictionary = {}) -> int
func apply_pwr_delta(amount: int, context: Dictionary = {}) -> int
```

`apply_hp_delta` and `apply_pwr_delta` should be the controlled mutation path for damage, healing, and direct stat effects.

### 6.4 Reset Behavior

When creating a battle copy or resetting a unit for battle:

```text
current_hp = base HP + persistent HP modifiers + equipment HP modifiers + relevant battle-start modifiers
current_pwr = base PWR + persistent PWR modifiers + equipment PWR modifiers + relevant battle-start modifiers
```

Damage/healing from previous battles should not carry over unless explicitly represented by a persistent component.

## 7. Ability Resolution Model

Current `AbilityResolver` resolves abilities from three paths:

- unit instance abilities;
- equipped item definition abilities;
- trinket definition abilities.

The target model should expose one unified query:

```gdscript
func get_active_ability_entries(all_instances: Dictionary) -> Array[Dictionary]
```

Each entry should include:

```text
ability_def: AbilityDefinition
source_instance_uuid: String
source_type: StringName
holder_uuid: String
priority: int
component_id: StringName
```

This is important because an ability may visually originate from the unit even if the source is an equipped item.

The resolver should eventually process active ability entries without caring whether the ability came from the unit definition, item, trinket, rarity, status, or temporary module.

Preserve existing ordering unless intentionally changed:

```text
1. Units
2. Equipped items, sorted by slot
3. Trinkets
```

If the new component model changes ordering, the spec must explicitly define the replacement rule.

## 8. Equipment Model

Equipment should become component injection or virtual component aggregation.

Preferred approach:

```text
Do not physically copy all item components into the unit unless necessary.
Instead, when querying a unit's active components, include components from its equipped items.
```

This avoids duplicated state and makes unequipping clean.

However, the query result must still make the item source explicit:

```text
component source_type = EQUIPMENT
component source_id = item instance UUID
```

When an item is removed, all of its granted stat, tag, ability, and visual effects disappear automatically from the unit's aggregate state.

The current direct methods:

- `equip_item_bonus`
- `unequip_item_bonus`

should eventually be replaced by component-aware stat recalculation or by controlled stat sync logic.

## 9. Tags, Traits, Tier, Level, And Rarity

The new system should treat identity-like attributes consistently.

Required attributes:

- `tier`
- `level`
- `rarity`
- `category`

Required trait tags:

- `SOUL_FIRE`
- `SOUL_EARTH`
- `SOUL_WATER`
- `SOUL_AIR`

Current trait counting checks definition tags and equipped item tags. The refactor must preserve that behavior while moving toward:

```gdscript
instance.get_active_tags(all_instances)
instance.get_active_traits(all_instances)
instance.get_attribute(&"tier")
instance.get_attribute(&"level")
instance.get_attribute(&"rarity")
```

Temporary tag removal must be supported.

Example:

```text
Silence or curse component removes SOUL_FIRE while active.
```

## 10. Visual Composition Model

Current visuals are mostly:

- definition icon;
- equipped item icon;
- status icons;
- `variant_id == "prismatic"` shader handling inside `GachaBallView`.

The target should move visual source logic into the data adapter layer first.

Recommended path:

1. `VisualDataAdapter.create_visual_data()` asks the instance for active visual components.
2. It outputs a visual stack.
3. `GachaBallView` renders the visual stack.

Example visual data:

```text
icon: base unit icon
visual_layers:
  - prismatic shader
  - item badge icon
  - burn status icon
  - armor status icon
```

Do not start by rewriting all rendering. First make the data source component-aware.

## 11. Inspection UI Goal

The inspection UI should explain the composed instance.

The main unit inspection should show:

- final HP/PWR;
- level, tier, rarity;
- active traits/tags;
- active abilities;
- equipped items;
- active status effects;
- active permanent/battle/equipment modules.

Each module should be inspectable.

Examples:

- Click "Prismatic" to see what it grants.
- Click an equipped item to see its stat/ability/tag components.
- Click a temporary status to see its effect.
- Click a permanent upgrade to see its source if available.

The nested inspection pattern is valid, but the document must specify the data model first. UI should consume component metadata rather than reconstructing the logic manually.

## 12. Save/Load Requirements

The current save flow serializes some instance fields but does not serialize arbitrary injected ability state.

The new save format must serialize persistent components.

Do save:

- persistent stat components;
- level/rarity components;
- persistent tag/trait components;
- persistent ability components;
- persistent visual components;
- equipment relationships;
- current run location;
- current run HP/PWR if outside battle state requires it.

Do not save:

- battle-only components after battle ends;
- transient animation-only state;
- temporary combat status unless saving mid-battle is explicitly supported.

Save migration must preserve old saves where possible:

- `base_hp_modifier` and `base_pwr_modifier` become persistent stat components.
- `variant_id == "prismatic"` becomes rarity/visual/stat/ability components.
- `dynamic_tags` become tag components or battle tag components depending on context.
- `status_effects` become battle status components or remain a compatibility dictionary until fully migrated.

## 13. Merge Requirements

Current merge logic sums parent current HP/PWR, subtracts item bonuses to avoid double dipping, then stores surplus in base modifiers.

The new merge logic must define exactly what is inherited.

Required questions:

- Which components are inherited by the result?
- Which components are consumed?
- Which components are discarded?
- Which equipped item remains equipped?
- Are battle-only components inherited during battle merges?
- Does rarity inherit deterministically or probabilistically?
- Does level inherit, combine, or reset?
- Do ability components mutate into new abilities?

Initial conservative rule:

```text
Preserve current merge behavior first.
Represent the inherited stat surplus as a persistent merge-inheritance StatComponent.
Preserve target item priority for equipped item inheritance.
Do not invent probability-based inheritance until explicitly designed.
```

## 14. Migration Plan

### Phase 1: Add Component Infrastructure

Add component resource classes.

Add compatibility APIs to `GachaBallInstance`:

- `get_active_components`
- `get_active_abilities`
- `get_active_tags`
- `get_attribute`
- `get_stat_breakdown`
- `apply_hp_delta`
- `apply_pwr_delta`

Keep existing fields working.

### Phase 2: Migrate Prismatic Proof Of Concept

Move `variant_id == "prismatic"` behavior into components:

- rarity/tag attribute;
- visual shader component;
- stat component;
- ability component.

Ensure save/load preserves it.

### Phase 3: Migrate Equipment Effects

Represent item `bonus_hp`, `bonus_pwr`, tags, visuals, and abilities as equipment-sourced components.

Keep equip/unequip behavior identical.

Remove direct stat double-application risks.

### Phase 4: Migrate Ability Resolver Queries

Change `AbilityResolver` to use active ability entries.

Preserve current response filters and source/holder semantics.

### Phase 5: Migrate Traits And Attributes

Move tier, level, rarity, category, and soul traits behind active tag/attribute queries.

Update trait counting to use the new query.

### Phase 6: Migrate Visual Data

Update `VisualDataAdapter` to emit visual component layers.

Keep `GachaBallView` compatible while gradually moving special-case visuals out of it.

### Phase 7: Migrate Save/Load And Merge

Serialize persistent components.

Convert legacy fields on load.

Represent merge inheritance as components.

### Phase 8: Cleanup Legacy Fields

Only after all call sites use the new APIs, remove or deprecate:

- `variant_id`
- `base_hp_modifier`
- `base_pwr_modifier`
- direct ability injection into `abilities`
- direct item stat bonus mutation paths

## 15. Acceptance Criteria

The refactor is successful when:

- Existing units/items/trinkets behave the same before and after migration.
- A unit can gain an ability from a component and combat resolves it correctly.
- A unit can gain stats from definition, permanent upgrades, equipment, rarity, and battle buffs without double counting.
- Damage and healing still mutate current HP directly and death checks remain correct.
- PWR changes still work as direct live stat changes.
- There is still no max HP system.
- Equipment removal removes its stat, ability, tag, and visual contributions.
- Prismatic behavior survives save/load.
- Merge stat inheritance matches current behavior.
- Trait counting works from unit and equipped item sources.
- Visuals still render correctly, including prismatic and status icons.
- Unit and item inspection can show active modules and their sources.
- Battle animations and combat logs still receive enough source/holder data.

## 16. Non-Goals

Do not introduce XP unless separately requested.

Do not introduce max HP.

Do not redesign combat rules.

Do not redesign all UI windows in the same pass.

Do not change merge balance or inheritance probabilities unless explicitly specified.

Do not make all damage/healing persistent components by default.

Do not remove legacy fields until all dependent systems have migrated.

## 17. Implementation Warning For AI Agents

This refactor touches core gameplay. The safest approach is to add the new component abstraction as a compatibility layer first, then migrate one source of behavior at a time.

When uncertain, preserve current behavior over architectural purity.

The target outcome is a system where the game can ask one instance:

```text
What are your current HP/PWR?
Why are they those values?
What abilities do you currently have?
Where did those abilities come from?
What tags, traits, level, tier, and rarity do you currently have?
What visual layers should represent your current state?
Which parts of your state should persist?
```

If the new architecture cannot answer those questions, the refactor is incomplete.
