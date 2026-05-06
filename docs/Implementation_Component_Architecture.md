# Implementation: Component-Based GachaBall Architecture (Final Specification)

## 1. Vision & Core Principles
This architecture transforms GachaBalls (Units and Items) from **Definition-Driven** entities to **Composition-Driven** entities. It enables a robust, flexible system where visuals, abilities, and stats are plug-and-play components.

### 1.1 Composition-Driven Model
- **The Shell**: `GachaBallInstance` is a base container that holds a collection of components.
- **The Components**: Individual `GachaBallComponent` resources define specific behaviors or visuals.
- **The Result**: A unit's final state is the dynamic sum of its active components.

---

## 2. The Component System

### 2.1 GachaBallComponent (Base Resource)
A new resource type (`res://scripts/resources/GachaBallComponent.gd`) acting as the universal building block.

**Properties:**
- `id`: StringName (e.g., &"prismatic_foil", &"extra_attack_trait").
- `category`: Enum {RARITY, STATUS, EQUIPMENT, PASSIVE} (Used for conflict resolution).
- `priority`: int (Order of application; high priority overrides/stacks last).
- `allow_stacking`: bool (Determines if multiple instances of the same ID/Category can execute).
- `is_persistent`: bool (True = Saved in RunState; False = Transient battle-only).

### 2.2 Component Subtypes

#### A. StatComponent
- `hp_add`, `pwr_add`: Flat additions.
- `hp_mult`, `pwr_mult`: Multipliers (always applied AFTER additions).
- **Injection Mode**: Locked to source (e.g., if from an Item, it cannot be inherited during merge).

#### B. AbilityComponent
- `ability_def`: AbilityDefinition resource.
- `mode`: Enum {ADD, REPLACE, DISABLE}.
- `target_ability_id`: StringName (For REPLACE/DISABLE logic).

#### C. VisualComponent
- `shader`: Master Shader reference or specific pass.
- `shader_params`: Dictionary (e.g., `{"shine_speed": 2.0}`).
- `modulate`: Color tint.
- `vfx_scene`: PackedScene path for particle overlays.
- **Exclusivity**: Only one component per `VisualCategory` (e.g., only one Rarity shader).

#### D. TagComponent
- `tags_to_add / tags_to_remove`: Dynamic gameplay tags (e.g., &"ELITE", &"STUN_IMMUNE").

---

## 3. Data Model & Logic: GachaBallInstance.gd

### 3.1 Component Storage & Registry
```gdscript
var components: Array[GachaBallComponent] = []
var _cached_stats: Dictionary = {} # Performance: Cache HP/PWR to avoid per-frame loops
```

### 3.2 Expert Caching Layer
To prevent performance degradation in UI loops, stats are only recalculated when the component list is modified.
- **Signal**: `components_changed` triggers `_recalculate_internal_stats()`.

### 3.3 Item Injection (Option A)
Equipping an item **injects** its components into the unit's list.
- **Un-equip Logic**: The unit maintains a registry of "Injected Source UUIDs" to cleanly remove only the item's components without affecting native unit traits.

---

## 4. Gameplay Logic & Combat

### 4.1 Ability Stacking & De-duplication
- `AbilityResolver` iterates through `instance.get_abilities()`.
- If two components provide the same Ability ID and `allow_stacking` is `false`, only the highest-priority component executes.

### 4.2 Merge Evolution & Inheritance
- **Stat Inheritance**: Base stats are additive; current battle stats are preserved.
- **Rarity Probability**: A probability hook determines if the child inherits the "Prismatic" or "Legendary" component from a parent.
- **Ability Mutation**: A hook allows Parent A + Parent B to evolve into a new, unique Ability Component C.
- **Item Lockdown**: Injected item components are **not** inheritable during merges.

### 4.3 Bench Stasis
- Units on the **Bench** are in "Stasis." 
- **Rule**: Standard DOT/Decay logic is paused.
- **Context-Sensitivity**: Components can be flagged as `lineup_only` or `bench_only` (e.g., a unit that only grows while benched).

---

## 5. Visual Stack Controller

`GachaBallView` and `PhysicsGachaBall` utilize a layered approach:
1. **Base Sprite**: The unit's standard icon.
2. **Rarity Pass**: Shaders like Prismatic Foil.
3. **Status Pass**: Tints/Glows for Burn, Poison, etc.
4. **VFX Overlay**: Particle systems (fire, bubbles) attached via `VisualComponent`.

---

## 6. UX: Nested Inspection Pattern
To prevent "Wall of Text" descriptions, the UI utilizes a branching model:
- **Main Window**: Shows the Unit + Base Ability.
- **Branching Links**: Each active component (Item, Curse, Rarity) appears as a clickable "Keyword Link."
- **Child Windows**: Clicking a link opens a specialized sub-window for that specific component.

---

## 7. Implementation Roadmap

### Phase 1: Infrastructure
- Create `GachaBallComponent` resource hierarchy.
- Refactor `GachaBallInstance` with `ComponentRegistry` and `StatCache`.

### Phase 2: System Integration
- Update `AbilityResolver` for stacking/de-duplication.
- Implement Item Injection in `InventoryManager`.

### Phase 3: Visual Stack
- Implement `VisualStackController` with category-based exclusivity.
- Transition Prismatic Variant to a `VisualComponent`.

### Phase 4: Evolution & Persistence
- Implement `MergeManager` evolution hooks.
- Update `RunState` to serialize component blueprints.
