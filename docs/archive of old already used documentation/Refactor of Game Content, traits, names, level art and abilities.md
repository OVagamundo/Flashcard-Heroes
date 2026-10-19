# FLASHCARD HEROES: UNIT REFACTOR SPECIFICATION & ADAPTATION GUIDE

> **Scope**: Master reference for adapting existing 25 units to descriptive trait names, recipes, trait tags (souls, classes, visuals), and mechanics-only ability specifications.  
> *(Note: Content expansion math, 11-pack Hero architecture, and wildcard pool rules have been moved to [ProgressionSystems.md](file:///Users/danhh/Desktop/Flashcard%20Heroes/docs/ProgressionSystems.md)).*

---

## 1. System Rules & Unified Trait Architecture

1. **All Tags are Mechanically Traits**:
   - Elements, Classes, and Visual Themes are stored in the unit's `tags: Array[StringName]` array.
   - Any trait is queryable by Trinkets, Items, and Combat Triggers (`count_trait()`, `has_trait()`).
2. **Elemental Souls (Multiplicity)**:
   - **Tier 1**: 1 Soul.
   - **Tier 2**: 2 Souls (Inherited directly as the exact sum of both Tier 1 parents: $1 + 1 = 2$).
   - **Tier 3**: 4 Souls (Inherited directly as the exact sum of both Tier 2 parents: $2 + 2 = 4$).
3. **Class Traits (Role Mechanics)**:
   - `Tank`, `Fighter`, `Support`, `Specialist`.
4. **Visual Traits (Thematic Archetypes)**:
   - `Food`, `Mecha`, `Animal`, `Plant`, `Toy`, `Appliance`, `Costume`.
5. **Trait Trinkets & Synergies**:
   - Each of the 15 traits has an associated Trait Trinket (`trinket_trait_<trait>`).
   - All 15 Trait Trinkets activate at the start of each combat phase during Pre-Combat (`on_pre_combat`, when the Battle button is pressed) rather than at turn start.
   - Elemental Trinkets (Fire, Earth, Water, Air) deliver their opening effects (Earth Armor/Spikes, Fire 7+ Burn, Water adjacent Heal, Air mirrored PWR steal) at the start of each combat phase.
   - Class and Visual Trinkets deliver their scaling PWR buff (+1 for 2 units, +2 for 3 units, +3 for 4 units, +4 for 5 units) to matching trait units at the start of each combat phase.
   - All trait trinkets are available to both player and enemy loadouts (`is_player_exclusive = false`).

---

## 2. Descriptive Naming Algorithm

Every unit and resource is identified by a standardized descriptive name that directly reflects its traits:

### 2.1 Descriptive Unit Name Formula
$$\text{\{Element Souls (E, F, W, A)\} + \{Class Trait(s)\} + \{Visual Trait(s)\}}$$

- **Elements**: `E` (Earth), `F` (Fire), `W` (Water), `A` (Air). Multiplicity is represented by repeating the letter: `EE` (2 Earth), `FF` (2 Fire), `WW` (2 Water), `AA` (2 Air).
  - Tier 1 has 1 letter (1 soul).
  - Tier 2 has 2 letters (2 souls).
  - Tier 3 has 4 letters (4 souls).
- **Class Trait(s)** (3-letter abbreviations): `Tnk` (Tank), `Fig` (Fighter), `Sup` (Support), `Spe` (Specialist).
- **Visual Trait(s)** (3-letter abbreviations, except Toy): `Fod` (Food), `Mec` (Mecha), `Ani` (Animal), `Pla` (Plant), `Toy` (Toy), `App` (Appliance), `Cos` (Costume).
- **Unified Identity**: The descriptive name is used identically across all layers:
  - File name: `<Name>.tres`
  - Resource ID: `id = &"<Name>"`
  - Display name: `<Name>`
  - Localization: `<Name>.name`

**Examples**:
- `ETnkPlaToy`: 1 Earth, Tank, Plant, Toy
- `EWFigCosToy`: Earth + Water, Fighter, Costume, Toy
- `EWWATnkMecApp`: Earth + 2x Water + Air, Tank, Mecha, Appliance

### 2.2 Ability Specification Rule
Unit abilities do not have standalone fantasy names or titles. They are identified and displayed strictly by their trigger and mechanic description.

---

## 3. Master Unit Directory & Adaptation Plan

### 3.1 Tier 1 Units (Base 4)

#### [ETnkPlaToy]
- **ID / Name**: `ETnkPlaToy`
- **Resource File**: `resources/units/ETnkPlaToy.tres`
- **Tier**: 1
- **Merge Recipe**: None (Base Unit)
- **Elemental Souls (1 Total)**: 1 Earth (`E`)
- **Class Trait(s)**: `Tank`
- **Visual Trait(s)**: `Plant`, `Toy`
- **Tags Array**: `[&"SOUL_EARTH", &"Tank", &"Plant", &"Toy"]`
- **Base Stats**: 2 HP / 1 PWR
- **Ability Description**: Deal (PWR) damage to the frontmost enemy. When hurt BY AN ATTACK, Heal this unit by [1 / 2 / 3] HP.

#### [FFigMecApp]
- **ID / Name**: `FFigMecApp`
- **Resource File**: `resources/units/FFigMecApp.tres`
- **Tier**: 1
- **Merge Recipe**: None (Base Unit)
- **Elemental Souls (1 Total)**: 1 Fire (`F`)
- **Class Trait(s)**: `Fighter`
- **Visual Trait(s)**: `Mecha`, `Appliance`
- **Tags Array**: `[&"SOUL_FIRE", &"Fighter", &"Mecha", &"Appliance"]`
- **Base Stats**: 1 HP / 2 PWR
- **Ability Description**: Deal (PWR) damage to the enemy in mirror slot. [Ranged Attack]. When hurt BY AN ATTACK, shoot a projectile at attacker dealing damage equal to PWR (bounces to additional targets at L2/L3).

#### [WSupAniCos]
- **ID / Name**: `WSupAniCos`
- **Resource File**: `resources/units/WSupAniCos.tres`
- **Tier**: 1
- **Merge Recipe**: None (Base Unit)
- **Elemental Souls (1 Total)**: 1 Water (`W`)
- **Class Trait(s)**: `Support`
- **Visual Trait(s)**: `Animal`, `Costume`
- **Tags Array**: `[&"SOUL_WATER", &"Support", &"Animal", &"Costume"]`
- **Base Stats**: 1 HP / 1 PWR
- **Ability Description**: Deal (PWR) damage to the frontmost enemy. When the ally directly in front takes damage, heal them for [1 / 2 / 3] HP.

#### [ASpeFodToy]
- **ID / Name**: `ASpeFodToy`
- **Resource File**: `resources/units/ASpeFodToy.tres`
- **Tier**: 1
- **Merge Recipe**: None (Base Unit)
- **Elemental Souls (1 Total)**: 1 Air (`A`)
- **Class Trait(s)**: `Specialist`
- **Visual Trait(s)**: `Food`, `Toy`
- **Tags Array**: `[&"SOUL_AIR", &"Specialist", &"Food", &"Toy"]`
- **Base Stats**: 1 HP / 1 PWR
- **Ability Description**: Deal (PWR) damage to the enemy in mirror slot. [Ranged Attack]. When this unit dies, grant its current PWR to the ally behind (cascades to further allies at L2/L3).

---

### 3.2 Tier 2 Units (6 Combinations)

#### [EWFigCosToy]
- **ID / Name**: `EWFigCosToy`
- **Resource File**: `resources/units/EWFigCosToy.tres`
- **Tier**: 2
- **Merge Recipe**: `ETnkPlaToy` + `WSupAniCos` (`resources/recipes/Merge_ETnkPlaToy_WSupAniCos_to_EWFigCosToy.tres`)
- **Elemental Souls (2 Total)**: Earth, Water (`EW`)
- **Class Trait(s)**: `Fighter`
- **Visual Trait(s)**: `Costume`, `Toy`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_WATER", &"Fighter", &"Costume", &"Toy"]`
- **Base Stats**: 3 HP / 3 PWR
- **Ability Description**: When an ally is defeated, gain [+1/+1, +2/+1, +2/+2] HP/PWR.

#### [FASpeMecApp]
- **ID / Name**: `FASpeMecApp`
- **Resource File**: `resources/units/FASpeMecApp.tres`
- **Tier**: 2
- **Merge Recipe**: `FFigMecApp` + `ASpeFodToy` (`resources/recipes/Merge_FFigMecApp_ASpeFodToy_to_FASpeMecApp.tres`)
- **Elemental Souls (2 Total)**: Fire, Air (`FA`)
- **Class Trait(s)**: `Specialist`
- **Visual Trait(s)**: `Mecha`, `Appliance`
- **Tags Array**: `[&"SOUL_FIRE", &"SOUL_AIR", &"Specialist", &"Mecha", &"Appliance"]`
- **Base Stats**: 2 HP / 3 PWR
- **Ability Description**: Deal (PWR) damage to the frontmost enemy. Gains extra PWR equal to [100% / 150% / 200%] of current Tokens, updating whenever Tokens change.

#### [EASpeFodToy]
- **ID / Name**: `EASpeFodToy`
- **Resource File**: `resources/units/EASpeFodToy.tres`
- **Tier**: 2
- **Merge Recipe**: `ETnkPlaToy` + `ASpeFodToy` (`resources/recipes/Merge_ETnkPlaToy_ASpeFodToy_to_EASpeFodToy.tres`)
- **Elemental Souls (2 Total)**: Earth, Air (`EA`)
- **Class Trait(s)**: `Specialist`
- **Visual Trait(s)**: `Food`, `Toy`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_AIR", &"Specialist", &"Food", &"Toy"]`
- **Base Stats**: 3 HP / 2 PWR
- **Ability Description**: Deal (PWR) damage to the frontmost enemy. Initial PWR equals current Gold multiplied by [50% / 100% / 150%] when drawn or spawned.

#### [WATnkPlaAni]
- **ID / Name**: `WATnkPlaAni`
- **Resource File**: `resources/units/WATnkPlaAni.tres`
- **Tier**: 2
- **Merge Recipe**: `WSupAniCos` + `ASpeFodToy` (`resources/recipes/Merge_WSupAniCos_ASpeFodToy_to_WATnkPlaAni.tres`)
- **Elemental Souls (2 Total)**: Water, Air (`WA`)
- **Class Trait(s)**: `Tank`
- **Visual Trait(s)**: `Plant`, `Animal`
- **Tags Array**: `[&"SOUL_WATER", &"SOUL_AIR", &"Tank", &"Plant", &"Animal"]`
- **Base Stats**: 2 HP / 2 PWR
- **Ability Description**: Deal (PWR) damage to the frontmost enemy. At start of combat, gain [+1/+1, +2/+2, +3/+3] HP/PWR for each empty slot in your team.

#### [EFTnkAniCos]
- **ID / Name**: `EFTnkAniCos`
- **Resource File**: `resources/units/EFTnkAniCos.tres`
- **Tier**: 2
- **Merge Recipe**: `ETnkPlaToy` + `FFigMecApp` (`resources/recipes/Merge_ETnkPlaToy_FFigMecApp_to_EFTnkAniCos.tres`)
- **Elemental Souls (2 Total)**: Earth, Fire (`EF`)
- **Class Trait(s)**: `Tank`
- **Visual Trait(s)**: `Animal`, `Costume`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_FIRE", &"Tank", &"Animal", &"Costume"]`
- **Base Stats**: 3 HP / 2 PWR
- **Ability Description**: When healed, gain [1 / 2 / 3] Armor and Spikes.

#### [FWSpeAppFod]
- **ID / Name**: `FWSpeAppFod`
- **Resource File**: `resources/units/FWSpeAppFod.tres`
- **Tier**: 2
- **Merge Recipe**: `FFigMecApp` + `WSupAniCos` (`resources/recipes/Merge_FFigMecApp_WSupAniCos_to_FWSpeAppFod.tres`)
- **Elemental Souls (2 Total)**: Fire, Water (`FW`)
- **Class Trait(s)**: `Specialist`
- **Visual Trait(s)**: `Appliance`, `Food`
- **Tags Array**: `[&"SOUL_FIRE", &"SOUL_WATER", &"Specialist", &"Appliance", &"Food"]`
- **Base Stats**: 2 HP / 3 PWR
- **Ability Description**: Deal (PWR) damage to the frontmost enemy. When healed, shoot a bouncing burn projectile at a random enemy, applying Burn stacks equal to heal amount.

---

### 3.3 Tier 3 Units (15 Combinations)

#### [EFWAFigSpeAniMec]
- **ID / Name**: `EFWAFigSpeAniMec`
- **Resource File**: `resources/units/EFWAFigSpeAniMec.tres`
- **Merge Recipe**: `EASpeFodToy` + `FWSpeAppFod`
- **Elemental Souls (4 Total)**: Earth, Fire, Water, Air (`EFWA`)
- **Class Trait(s)**: `Fighter`, `Specialist`
- **Visual Trait(s)**: `Animal`, `Mecha`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_FIRE", &"SOUL_WATER", &"SOUL_AIR", &"Specialist", &"Fighter", &"Animal", &"Mecha"]`
- **Base Stats**: 5 HP / 5 PWR
- **Ability Description**: Attacks enemy in opposite mirror slot for [100% / 150% / 200%] damage.

#### [EWWATnkMecApp]
- **ID / Name**: `EWWATnkMecApp`
- **Resource File**: `resources/units/EWWATnkMecApp.tres`
- **Merge Recipe**: `EWFigCosToy` + `WATnkPlaAni`
- **Elemental Souls (4 Total)**: Earth, 2x Water, Air (`EWWA`)
- **Class Trait(s)**: `Tank`
- **Visual Trait(s)**: `Mecha`, `Appliance`
- **Tags Array**: `[&"intercept_lethal", &"SOUL_EARTH", &"SOUL_WATER", &"SOUL_WATER", &"SOUL_AIR", &"Tank", &"Mecha", &"Appliance"]`
- **Base Stats**: 5 HP / 5 PWR
- **Ability Description**: Leaps to intercept lethal damage on allies (gains [0 / 1 / 2] Armor).

#### [EFWWFigSpeAniFodMecCos]
- **ID / Name**: `EFWWFigSpeAniFodMecCos`
- **Resource File**: `resources/units/EFWWFigSpeAniFodMecCos.tres`
- **Merge Recipe**: `EWFigCosToy` + `FWSpeAppFod`
- **Elemental Souls (4 Total)**: Earth, Fire, 2x Water (`EFWW`)
- **Class Trait(s)**: `Fighter`, `Specialist`
- **Visual Trait(s)**: `Animal`, `Food`, `Mecha`, `Costume`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_FIRE", &"SOUL_WATER", &"SOUL_WATER", &"Specialist", &"Fighter", &"Animal", &"Food", &"Mecha", &"Costume"]`
- **Base Stats**: 5 HP / 6 PWR
- **Ability Description**: Deals [100% / 150% / 200%] cascade AOE damage to front enemy and units behind.

#### [EFAASupToy]
- **ID / Name**: `EFAASupToy`
- **Resource File**: `resources/units/EFAASupToy.tres`
- **Merge Recipe**: `EASpeFodToy` + `FASpeMecApp`
- **Elemental Souls (4 Total)**: Earth, Fire, 2x Air (`EFAA`)
- **Class Trait(s)**: `Support`
- **Visual Trait(s)**: `Toy`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_FIRE", &"SOUL_AIR", &"SOUL_AIR", &"Support", &"Toy"]`
- **Base Stats**: 5 HP / 5 PWR
- **Ability Description**: Summons a random Level [1 / 2 / 3] Tier 2 unit on death.

#### [EEFWFigTnkPlaToy]
- **ID / Name**: `EEFWFigTnkPlaToy`
- **Resource File**: `resources/units/EEFWFigTnkPlaToy.tres`
- **Merge Recipe**: `EWFigCosToy` + `EFTnkAniCos`
- **Elemental Souls (4 Total)**: 2x Earth, Fire, Water (`EEFW`)
- **Class Trait(s)**: `Fighter`, `Tank`
- **Visual Trait(s)**: `Plant`, `Toy`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_EARTH", &"SOUL_FIRE", &"SOUL_WATER", &"Fighter", &"Tank", &"Plant", &"Toy"]`
- **Base Stats**: 6 HP / 5 PWR
- **Ability Description**: Grants [+1/+1, +2/+1, +2/+2] HP/PWR to adjacent allies when hurt by an attack.

#### [EEWAFigFodAniCos]
- **ID / Name**: `EEWAFigFodAniCos`
- **Resource File**: `resources/units/EEWAFigFodAniCos.tres`
- **Merge Recipe**: `EWFigCosToy` + `EASpeFodToy`
- **Elemental Souls (4 Total)**: 2x Earth, Water, Air (`EEWA`)
- **Class Trait(s)**: `Fighter`
- **Visual Trait(s)**: `Food`, `Animal`, `Costume`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_EARTH", &"SOUL_WATER", &"SOUL_AIR", &"Fighter", &"Food", &"Animal", &"Costume"]`
- **Base Stats**: 6 HP / 5 PWR
- **Ability Description**: Deals damage to enemies equal to [100% / 150% / 200%] of PWR when they are summoned.

#### [EFFASupPlaToy]
- **ID / Name**: `EFFASupPlaToy`
- **Resource File**: `resources/units/EFFASupPlaToy.tres`
- **Merge Recipe**: `EFTnkAniCos` + `FASpeMecApp`
- **Elemental Souls (4 Total)**: Earth, 2x Fire, Air (`EFFA`)
- **Class Trait(s)**: `Support`
- **Visual Trait(s)**: `Plant`, `Toy`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_FIRE", &"SOUL_FIRE", &"SOUL_AIR", &"Support", &"Plant", &"Toy"]`
- **Base Stats**: 5 HP / 5 PWR
- **Ability Description**: Grants [+3 / +5 / +7] HP to newly summoned allies.

#### [FWAASupToy]
- **ID / Name**: `FWAASupToy`
- **Resource File**: `resources/units/FWAASupToy.tres`
- **Merge Recipe**: `FASpeMecApp` + `WATnkPlaAni`
- **Elemental Souls (4 Total)**: Fire, Water, 2x Air (`FWAA`)
- **Class Trait(s)**: `Support`
- **Visual Trait(s)**: `Toy`
- **Tags Array**: `[&"SOUL_FIRE", &"SOUL_WATER", &"SOUL_AIR", &"SOUL_AIR", &"Support", &"Toy"]`
- **Base Stats**: 4 HP / 5 PWR
- **Ability Description**: Deal (PWR) damage to frontmost enemy. If on the player bench at start of turn, gain [+3 / +5 / +7] HP and PWR.

#### [EFFWSupMecApp]
- **ID / Name**: `EFFWSupMecApp`
- **Resource File**: `resources/units/EFFWSupMecApp.tres`
- **Merge Recipe**: `EFTnkAniCos` + `FWSpeAppFod`
- **Elemental Souls (4 Total)**: Earth, 2x Fire, Water (`EFFW`)
- **Class Trait(s)**: `Support`
- **Visual Trait(s)**: `Mecha`, `Appliance`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_FIRE", &"SOUL_FIRE", &"SOUL_WATER", &"Support", &"Mecha", &"Appliance"]`
- **Base Stats**: 5 HP / 5 PWR
- **Ability Description**: Deal (PWR) damage to frontmost enemy. Whenever a merge happens on the battle board, gain [+2 / +3 / +4] HP and PWR.

#### [EFWASupFodToy]
- **ID / Name**: `EFWASupFodToy`
- **Resource File**: `resources/units/EFWASupFodToy.tres`
- **Merge Recipe**: `EFTnkAniCos` + `WATnkPlaAni`
- **Elemental Souls (4 Total)**: Earth, Fire, Water, Air (`EFWA`)
- **Class Trait(s)**: `Support`
- **Visual Trait(s)**: `Food`, `Toy`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_FIRE", &"SOUL_WATER", &"SOUL_AIR", &"Support", &"Food", &"Toy"]`
- **Base Stats**: 5 HP / 4 PWR
- **Ability Description**: Deal (PWR) damage to frontmost enemy. Gains [+3 / +4 / +5] PWR for each other copy in battle. Summons 1 copy of itself on death into Gacha Machine.

#### [FFWASpeSupMecAniApp]
- **ID / Name**: `FFWASpeSupMecAniApp`
- **Resource File**: `resources/units/FFWASpeSupMecAniApp.tres`
- **Merge Recipe**: `FWSpeAppFod` + `FASpeMecApp`
- **Elemental Souls (4 Total)**: 2x Fire, Water, Air (`FFWA`)
- **Class Trait(s)**: `Specialist`, `Support`
- **Visual Trait(s)**: `Mecha`, `Animal`, `Appliance`
- **Tags Array**: `[&"SOUL_FIRE", &"SOUL_FIRE", &"SOUL_WATER", &"SOUL_AIR", &"Specialist", &"Support", &"Mecha", &"Animal", &"Appliance"]`
- **Base Stats**: 5 HP / 5 PWR
- **Ability Description**: On death, transfers equipped item to the ally directly behind it (and extra copies behind them at L2/L3).

#### [EWAASpePlaApp]
- **ID / Name**: `EWAASpePlaApp`
- **Resource File**: `resources/units/EWAASpePlaApp.tres`
- **Merge Recipe**: `EASpeFodToy` + `WATnkPlaAni`
- **Elemental Souls (4 Total)**: Earth, Water, 2x Air (`EWAA`)
- **Class Trait(s)**: `Specialist`
- **Visual Trait(s)**: `Plant`, `Appliance`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_WATER", &"SOUL_AIR", &"SOUL_AIR", &"Specialist", &"Plant", &"Appliance"]`
- **Base Stats**: 5 HP / 4 PWR
- **Ability Description**: Deal (PWR) damage to frontmost enemy. At the start of each turn, permanently gain [+3 / +4 / +5] HP and PWR for every 5 Gold you currently have.

#### [EEFASpeFodCos]
- **ID / Name**: `EEFASpeFodCos`
- **Resource File**: `resources/units/EEFASpeFodCos.tres`
- **Merge Recipe**: `EFTnkAniCos` + `EASpeFodToy`
- **Elemental Souls (4 Total)**: 2x Earth, Fire, Air (`EEFA`)
- **Class Trait(s)**: `Specialist`
- **Visual Trait(s)**: `Food`, `Costume`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_EARTH", &"SOUL_FIRE", &"SOUL_AIR", &"Specialist", &"Food", &"Costume"]`
- **Base Stats**: 6 HP / 4 PWR
- **Ability Description**: Before its turn action, transforms into the enemy unit in mirror slot (+0 Level / +1 Level / Level 3 Max) and takes its turn immediately.

#### [EFWATnkCosMec]
- **ID / Name**: `EFWATnkCosMec`
- **Resource File**: `resources/units/EFWATnkCosMec.tres`
- **Merge Recipe**: `EWFigCosToy` + `FASpeMecApp`
- **Elemental Souls (4 Total)**: Earth, Fire, Water, Air (`EFWA`)
- **Class Trait(s)**: `Tank`
- **Visual Trait(s)**: `Costume`, `Mecha`
- **Tags Array**: `[&"SOUL_EARTH", &"SOUL_FIRE", &"SOUL_WATER", &"SOUL_AIR", &"Tank", &"Costume", &"Mecha"]`
- **Base Stats**: 5 HP / 6 PWR
- **Ability Description**: Gain [+2 / +4 / +6] HP before taking damage.

#### [FWWASupAniToy]
- **ID / Name**: `FWWASupAniToy`
- **Resource File**: `resources/units/FWWASupAniToy.tres`
- **Merge Recipe**: `FWSpeAppFod` + `WATnkPlaAni`
- **Elemental Souls (4 Total)**: Fire, 2x Water, Air (`FWWA`)
- **Class Trait(s)**: `Support`
- **Visual Trait(s)**: `Animal`, `Toy`
- **Tags Array**: `[&"SOUL_FIRE", &"SOUL_WATER", &"SOUL_WATER", &"SOUL_AIR", &"Support", &"Animal", &"Toy"]`
- **Base Stats**: 4 HP / 5 PWR
- **Ability Description**: Grants an additional copy of any buff received by an adjacent ally at [100% / 150% / 200%] effectiveness.

---

## 4. Recipe & Elemental Inheritance Audit

To achieve clean, non-duplicate elemental pairs in Tier 2 and exact soul sums in Tier 3 ($2 + 2 = 4$):

### 4.1 Recipe Swap Realignment
1. **`EWFigCosToy`**:
   - Recipe: `ETnkPlaToy` (E) + `WSupAniCos` (W) $	o$ **EW** (Earth, Water).
2. **`EFTnkAniCos`**:
   - Recipe: `ETnkPlaToy` (E) + `FFigMecApp` (F) $	o$ **EF** (Earth, Fire).

### 4.2 Tier 3 Soul Audits (Exact Parent Element Sums)
All Tier 3 units have their elemental souls 100% mathematically aligned to the sum of their Tier 2 parents ($2 + 2 = 4$):
- **`EWWATnkMecApp`**: `EWFigCosToy` (EW) + `WATnkPlaAni` (WA) = **EWWA** (1 Earth, 2 Water, 1 Air).
- **`EFAASupToy`**: `EASpeFodToy` (EA) + `FASpeMecApp` (FA) = **EFAA** (1 Earth, 1 Fire, 2 Air).
- **`EEWAFigFodAniCos`**: `EWFigCosToy` (EW) + `EASpeFodToy` (EA) = **EEWA** (2 Earth, 1 Water, 1 Air).
- **`EFFASupPlaToy`**: `EFTnkAniCos` (EF) + `FASpeMecApp` (FA) = **EFFA** (1 Earth, 2 Fire, 1 Air).
