# Architectural Adjustments & Recipe Reorganization

The evolutionary level-up system requires a strict tiering architecture to preserve clean progression and mathematical symmetry:
* **Tier 1 to Tier 2**: The 4 Tier 1 base units combine into 6 unique cross-combinations to completely exhaust the Tier 1 baseline matrix.
* **Tier 2 to Tier 3**: Combining two different Tier 2 units creates tier 3 units. The remaining former identical-merge definitions (Berserker, Paladin, Mimic, and Shadow Cloner) have been promoted to Tier 3 to prevent recipe duplication and match the new economy.

Ability scaling is documented inline using a bracketed notation `[Level 1 / Level 2 / Level 3]` inside the ability column to maintain a clean, single-row data entry format per unit family.

---

## Flashcard Heroes Unit Directory

### Tier 1 Units
* **Gold Cost**: $1 \times 2^{L-1}$
* **Draw Cost**: 1 Token

| ID | Name | Stats | Souls | Abilities (Level Scaling `[L1 / L2 / L3]`) |
| :--- | :--- | :--- | :--- | :--- |
| `unit_t1_a` | Apprentice | 2 HP / 1 PWR | 1 Earth | **Resilience** (`on_hurt`): Heal self by PWR `[PWR / PWR+1 / PWR+2]`. |
| `unit_t1_b` | Squire | 1 HP / 2 PWR | 1 Fire | **Retaliation** (`on_hurt`): Counter-attack for PWR damage `[100% / 125% / 150%]`. `[L3: Also gains 1 Armor stack]`. |
| `unit_t1_c` | Protector | 1 HP / 1 PWR | 1 Water | **Guardian's Grace** (`on_ally_hurt`): When ally directly in front takes damage, heal them for PWR `[100% / 150% / 200%]`. |
| `unit_t1_d` | Empath | 1 HP / 1 PWR | 1 Wind | **Empathic Link** (`on_death`): On death, grant total current PWR to ally behind `[100% / 150% / 200%]`. |

---

### Tier 2 Units
* **Gold Cost**: $2 \times 2^{L-1}$
* **Draw Cost**: 2 Tokens

| ID | Name | Merge Recipe | Stats | Souls | Abilities (Level Scaling `[L1 / L2 / L3]`) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `unit_t2_c` | Knight | **Apprentice + Squire** | 3 HP / 3 PWR | 1 Fire, 1 Earth | **Morale Boost** (`on_ally_death`): Gain `[+1/+1, +2/+1, +2/+2]` HP/PWR. |
| `unit_t2_d` | Templar | **Squire + Empath** | 2 HP / 3 PWR | 1 Water, 1 Wind | **Gacha Power** (`passive`): PWR is equal to Gacha Tokens `[(Min 1) / (Min 2) / (Min 3)]`. PWR buffs convert to HP at `[100% / 150% / 200%]` effectiveness. |
| `unit_t2_f` | Merchant | **Apprentice + Empath** | 3 HP / 2 PWR | 1 Earth, 1 Wind | **Gold Investments** (`on_draw`, `on_battle_start`): Initial PWR equals your current Gold multiplied by `[1.0 / 1.5 / 2.0]` when drawn or spawned. |
| `unit_t2_i` | Mud Wretch | **Apprentice + Protector** | 3 HP / 2 PWR | 1 Earth, 1 Water | **Mud Coating** (`on_healed`): When healed, gain `[+1/+1, +2/+1, +2/+2]` Armor/Spikes stacks. |
| `unit_t2_j` | Steam Wisp | **Squire + Protector** | 2 HP / 3 PWR | 1 Fire, 1 Water | **Scald** (`on_healed`): When healed, deal damage to the front enemy equal to `[100% / 150% / 200%]` of the heal amount. |
| `unit_t2_h` | Hermit | **Protector + Empath** | 2 HP / 2 PWR | 1 Water, 1 Wind | **Solitary Strength** (`on_pre_combat`): Start of Combat (Lineup Only): Gains `[+1/+1, +2/+2, +3/+3]` HP/PWR per empty lineup slot. |

---

## Tier 3 Units
* **Gold Cost**: $4 \times 2^{L-1}$
* **Draw Cost**: 3 Tokens

| ID | Name | Merge Recipe | Stats | Souls | Abilities (Level Scaling `[L1 / L2 / L3]`) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `unit_t3_a` | Duelist | **Merchant + Steam Wisp** | 5 HP / 5 PWR | 4 Fire | **Mirror Strike** (`on_attack`): Attacks enemy in opposite mirror slot. If empty, targets backmost enemy. Deals `[100% / 125% / 150%]` damage. |
| `unit_t3_b` | Guardian | **Knight + Hermit** | 5 HP / 5 PWR | 4 Earth | **Guardian Sacrifice** (`on_before_damage`): Leaps to intercept lethal damage on allies. Gains `[2 / 4 / 6]` temporary Armor upon interception. |
| `unit_t3_c` | Necromancer | **Merchant + Templar** | 5 HP / 5 PWR | 2 Fire, 2 Earth | **Soul Summon** (`on_death`): Summons a Tier 2 unit on death at Level `[1 / 2 / 3]`. |
| `unit_t3_d` | Warden | **Knight + Mud Wretch** | 6 HP / 5 PWR | 2 Fire, 2 Earth | **Resilient Aura** (`on_hurt`): Grants `[+1/+1, +2/+1, +2/+2]` HP/PWR to adjacent allies. |
| `unit_t3_e` | Assassin | **Knight + Merchant** | 6 HP / 5 PWR | 3 Fire, 1 Earth | **Ambush Predator** (`on_enemy_summon`): Deals damage to enemies equal to `[100% / 150% / 200%]` of PWR when they are summoned. |
| `unit_t3_f` | Summoner | **Mud Wretch + Templar** | 5 HP / 5 PWR | 1 Fire, 3 Earth | **Summon Blessing** (`on_ally_summon`): Heals allies for `[2 / 4 / 6]` HP when they are summoned. |
| `unit_t3_g` | Phantom Wayfarer | **Templar + Hermit** | 4 HP / 5 PWR | 4 Wind | **Quiet Meditation** (`on_turn_start`): If on bench, gain `[+3/+3, +4/+4, +6/+6]` HP/PWR. **[Player Exclusive]** |
| `unit_t3_h` | Fusion Warden | **Mud Wretch + Steam Wisp** | 5 HP / 5 PWR | 1 Fire, 1 Water, 2 Wind | **Convergence Surge** (`on_merge`): If on board when a merge happens, gain `[+2/+2, +3/+3, +4/+4]` HP/PWR. |
| `unit_t3_i` | Doppleganger | **Mud Wretch + Hermit** | 5 HP / 4 PWR | — | **Mirrored Might** (`passive`): `[+3 / +4 / +5]` PWR for every other Doppleganger in the Battle Pool.<br>**Clone Split** (`on_death`): Spawn `[1 / 1 / 2]` additional Dopplegangers into the Gacha Machine. **[Player Exclusive]** |
| `unit_t3_paladin` | Paladin | **Knight + Templar** | 5 HP / 6 PWR | 2 Earth | **Defensive Stance** (`on_before_damage`): Gain `[+2, +4, +6]` HP before taking damage. |
| `unit_t3_berserker` | Berserker | **Knight + Steam Wisp** | 5 HP / 6 PWR | 2 Fire | **Shockwave** (`on_attack`): Deals cascade AOE damage to front enemy and units behind for `[50% / 75% / 100%]` of PWR. |
| `unit_t3_mimic` | Mimic | **Mud Wretch + Merchant** | 6 HP / 4 PWR | 2 Water | **Mirror Transformation** (`on_turn_start`): Transforms into the enemy unit in the mirror slot. Level matches target level `[+0 / +1 / maxed out]`. |
| `unit_t3_shadow` | Shadow Cloner | **Steam Wisp + Hermit** | 4 HP / 5 PWR | 1 Wind | **Buff Echo** (`on_stat_increased`): Repeats any buff received by an adjacent ally at `[100% / 150% / 200%]` effectiveness. | |

---

## Technical Notes & Implementation Specifics

### Evolutionary Leveling Details
* **Abilities**: For the initial implementation, leveled-up units (Level 2 and Level 3) will retain the same core logic and execution as their Level 1 baseline.
* **Base Stat Buffs**: Leveling up automatically grants a flat, persistent stat increase of **+1 HP and +1 PWR** per level gained (added to their baseline stats).
* **Level Visualization**: A distinct, clear level label (e.g. `Lv. 2`, `Lv. 3`) is appended to the unit's portrait/name overlay in battle slots and within the inspection screen to clearly identify its current evolution.
