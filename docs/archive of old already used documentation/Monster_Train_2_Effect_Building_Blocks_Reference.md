# Monster Train 2 --- Effect & Building-Block Reference

## Inspiration Library for Flashcard Heroes Action Constitution v1

**Purpose**

This document is a companion to **Action Constitution v1 --- Monster
Train Resolution Research Reference**.

The first document focuses on **when and why things resolve**. This
document focuses on **what kinds of things Monster Train 2 can make
happen**, how those building blocks combine, what targets and conditions
they can use, and where those effects sit in a deterministic resolution
hierarchy.

It is intended as a reference for the coding agent and game-design work.
It is **not** a specification of the current Flashcard Heroes
implementation.

Monster Train 2 is especially useful as a design reference because its
content is built from reusable primitives: direct effects, persistent
status effects, temporary/permanent upgrades, triggers, abilities,
equipment, room effects, targeting rules, scaling rules, and chained
consequences. The exposed Trainworks Reloaded reference documents a
large base-game CardEffect vocabulary, while the current card database
indexes 564 cards in patch 2.2.1. [Trainworks Reloaded --- Base Game
Card Effect
Reference](https://github-wiki-see.page/m/Monster-Train-2-Modding-Group/Trainworks-Reloaded/wiki/Base-Game-Card-Effect-Reference)
[Monster Train 2 Card
Database](https://railtools.net/monster-train-2/cards/)

------------------------------------------------------------------------

# 1. The fundamental building-block model

Monster Train's content can be understood as combinations of six major
building blocks:

``` text
TARGET
  ↓
TRIGGER / TIMING
  ↓
CONDITION / FILTER
  ↓
EFFECT
  ↓
PERSISTENCE / STATUS
  ↓
NEW EVENT → NEW TRIGGERS → NEW EFFECTS
```

A single card or unit ability can combine several of these.

For example:

``` text
WHEN I STRIKE
    ↓
target: friendly Burnout units
    ↓
apply Rage 3
```

or:

``` text
WHEN AN ALLY DIES
    ↓
target: self
    ↓
gain Rage
```

or:

``` text
WHEN SUMMONED
    ↓
target: all enemy units on the floor
    ↓
apply Decay
```

or:

``` text
WHEN KILLED
    ↓
target: random defeated friendly unit
    ↓
return it to hand
    ↓
apply permanent Attack
```

This compositional structure is one of the most valuable things to
borrow.

------------------------------------------------------------------------

# 2. Effect families

The exposed MT2 CardEffect reference contains effect classes covering
the following broad families.

## 2.1 Direct damage

Monster Train supports much more than a single `DealDamage(amount)`.

Documented damage families include:

-   fixed damage;
-   ranged damage;
-   random/ranged damage;
-   damage based on remaining health;
-   damage based on units killed;
-   damage based on a target's HP;
-   damage based on source Attack;
-   damage based on target Attack;
-   damage based on source status effects;
-   damage including or excluding Armor;
-   damage to the last attacker;
-   damage with Trample;
-   repeated damage;
-   damage to all units on a floor;
-   damage to selected/random units;
-   damage conditional on room state;
-   damage that also applies a status;
-   damage caused by an immediate attack;
-   direct Kill, which is a separate effect from ordinary damage.

The reference explicitly exposes classes such as:

-   `CardEffectDamage`
-   `CardEffectDamageByPercentRemainingHealth`
-   `CardEffectDamageByUnitsKilled`
-   `CardEffectDamagePerHp`
-   `CardEffectDamagePerSourceAttack`
-   `CardEffectDamagePerTargetAttack`
-   `CardEffectDamageWithTrample`
-   `CardEffectKill`

Source: Base Game Card Effect Reference.

### Design implication

Damage should be treated as a **family of effect calculations**, not
merely a numerical mutation.

The calculation can depend on:

``` text
constant
source stats
target stats
current HP
missing HP
Armor
status stacks
number of kills
previous attack
room state
resource expenditure
```

------------------------------------------------------------------------

# 3. Healing

Documented healing primitives include:

-   fixed healing;
-   ranged healing;
-   healing based on resource/cost;
-   healing plus damage;
-   healing one unit and another friendly unit;
-   healing with Overheal;
-   healing the Pyre;
-   healing the train/room;
-   restoring to full health.

Examples from the current card pool include:

-   `Focused Growth` --- restore 20 health twice and draw next turn;
-   `Glimmer` --- heal friendly units and damage enemies;
-   `Restoration Detonation` --- heal, then deal damage based on the
    amount healed;
-   `Tidal Turning` --- healing beyond max health becomes Armor.

This illustrates a powerful composition pattern:

``` text
EFFECT A produces a VALUE
        ↓
EFFECT B scales from that VALUE
```

rather than requiring every card to be a bespoke ability.

Source: current MT2 card database and CardEffect reference.

------------------------------------------------------------------------

# 4. Stat modification

Monster Train separates persistent stat changes from many stack-based
status effects.

Documented stat-changing primitives include:

-   Attack increase/decrease;
-   Max Health increase/decrease;
-   current Health setting;
-   Pyre Attack changes;
-   Pyre Max Health changes;
-   room Capacity changes;
-   unit Size changes;
-   temporary or permanent CardUpgrades;
-   stat transfer;
-   stat copying;
-   stat swapping.

Examples:

``` text
+Attack
+Health
+Max Health
-Attack
-Max Health
Attack ← source's Attack
Health ← source's Health
Attack ↔ Health
```

`CardEffectBuffDamage`, `CardEffectBuffMaxHealth`,
`CardEffectDebuffDamage`, `CardEffectDebuffMaxHealth`,
`CardEffectAdjustMaxHealth`, `CardEffectTransferAttackFromUnit`,
`CardEffectAddStatsFromSelf`, and related upgrade effects are documented
in the base effect reference.

### Important semantic distinction

Monster Train historically clarified that ordinary Status Effects do not
necessarily persist through death while **stat changes do**. Patch notes
explicitly removed the old "Enhance" wording to improve clarity around
this distinction.

Therefore:

``` text
status stack
```

and:

``` text
stat modification
```

are different persistence concepts even if both visibly change a unit.

------------------------------------------------------------------------

# 5. Status effects

Status effects are persistent state attached to a unit, room, card, or
other game object.

The MT2 system allows:

-   adding status;
-   removing status;
-   multiplying status;
-   transferring status;
-   copying status;
-   adding status based on another status;
-   adding status based on health;
-   adding status based on resources;
-   adding status based on attack;
-   adding status when another status is applied;
-   adding status when another status is removed;
-   modifying status magnitude globally;
-   propagating status;
-   adjusting all positive statuses;
-   adjusting all statuses;
-   status-dependent effects.

The base effect reference explicitly includes:

-   `CardEffectAddStatusEffect`
-   `CardEffectAddStatusEffectBasedOnHealth`
-   `CardEffectAddStatusEffectDependingOnHealthPercent`
-   `CardEffectAddStatusEffectOnStatusThreshold`
-   `CardEffectAddStatusEffectPerEnergy`
-   `CardEffectAddStatusEffectPerGoldSpent`
-   `CardEffectAddStatusEffectPerLastAttackDamage`
-   `CardEffectAddStatusEffectPerMissingHp`
-   `CardEffectAddStatusEffectPerOtherEffect`
-   `CardEffectAddStatusEffectPerSelfAttack`
-   `CardEffectAdjustAllStatusEffects`
-   `CardEffectMultiplyAllPositiveStatusEffects`
-   `CardEffectMultiplyAllStatusEffects`
-   `CardEffectMultiplyStatusEffect`
-   `CardEffectRemoveAllStatusEffects`
-   `CardEffectRemoveStatusEffect`
-   `CardEffectRemoveStatusEffectOnStatusThreshold`
-   `CardEffectRemoveStatusEffectPerCorrupt`
-   `CardEffectSynergizeStatusEffects`
-   `CardEffectTransferAllStatusEffects`
-   `CardEffectTransferAllStatusEffectsFromUnit`

Source: Base Game Card Effect Reference.

------------------------------------------------------------------------

# 6. Major status-effect families

The current MT2 content demonstrates several useful families.

## 6.1 Offensive scaling buffs

Examples include:

-   Rage;
-   Attack increases;
-   Valor;
-   permanent Attack growth;
-   Attack gained from another stat;
-   Attack gained from status count;
-   Attack gained from kills;
-   Attack gained from combat events.

Typical construction:

``` text
TRIGGER
    ↓
target
    ↓
+Attack / Rage / Valor
```

Important variations:

-   self;
-   all friendly units;
-   specific subtype;
-   front unit;
-   Burnout units;
-   unit that was summoned;
-   unit that killed something;
-   unit with a particular status.

------------------------------------------------------------------------

# 7. Defensive buffs

MT2 uses several distinct defensive mechanics rather than one generic
"Defense" number.

## Armor

Absorbs damage through an explicit Armor resource/status.

Examples:

-   `Apply Armor`;
-   gain Armor when healed;
-   gain Armor when another event occurs;
-   Armor based on Forge;
-   Armor based on a status count.

## Damage Shield

Prevents/absorbs a hit rather than reducing damage by a fixed amount.

This creates an important semantic distinction:

``` text
Armor:
    damage is reduced/absorbed through Armor

Damage Shield:
    an applicable damage instance is completely prevented
```

That distinction matters for reactions such as Revenge.

The MT2 card database contains examples such as `Gem Trove`,
`Crucible Warden`, `Void Binding`, and `Prismal Dust` using Damage
Shield.

## Regen

A persistent healing-over-time status processed at end-of-turn.

## Stealth

A temporary defensive/targeting state with stack-based duration.

## Reanimate

A death-prevention/lifecycle status. When a unit with Reanimate is
killed, it can return with 1 Health while losing one stack.

## Titanskin

A defensive/status mechanic introduced by Luna Coven content.

## Fragile

A highly lethal vulnerability: if the affected unit takes damage to
Health, it dies.

The existence of these separate mechanisms is important: they do not all
belong in a single generic "defense buff" category.

------------------------------------------------------------------------

# 8. Damage-over-time and decay mechanics

This deserves special treatment because it directly informs Action
Constitution.

## Frostbite

A stack-based damage-over-time effect.

## Decay

A stack-based damage-over-time effect.

A card such as **Rot** applies Decay rather than introducing a separate
"Rot" status.

This distinction should be preserved in a semantic taxonomy:

``` text
Rot = content/card name
Decay = underlying status mechanic
```

The current MT2 card database contains:

-   Rot --- deal 15 damage and apply Decay 15;
-   Pandemic --- apply Decay and Sap;
-   Cheery Deathcap --- Summon: apply Decay to enemy units;
-   Mushroom Cloud --- deal damage and apply Decay;
-   Sporetouch --- apply Decay;
-   Prickly Puffball --- Revenge: apply Decay to attacker.

This shows how the same status can be delivered by completely different
triggers.

------------------------------------------------------------------------

# 9. End-of-turn DoT ordering

MT2's documented end-of-turn sequence is particularly useful for Action
Constitution.

After a round of attacks:

1.  Eaten/Morsel processing.
2.  Enemy Cherubs.
3.  Shell processing/Hatch.
4.  For each enemy:
    -   Regen;
    -   Frostbite, Decay, Burnout, Witherbloom, and Stealth processing;
    -   Corruption;
    -   Unstable.
5.  The corresponding friendly-unit sequence.
6.  If Relentless continues, another combat round begins.

After combat actually ends:

1.  Reap.
2.  Resolve/healing.
3.  Valor.
4.  room PostCombat effects.
5.  End-of-Turn artifacts.
6.  Charged Echo cleanup.

The public discussion explicitly notes that
Frostbite/Decay/Burnout/Witherbloom/Stealth occur in the same broad
subphase, while their exact internal order was not established there and
was speculated to depend on application order. That speculation should
**not** be treated as a verified Monster Train rule.

Source: MT2 end-of-combat ordering discussion.

### Important Action Constitution lesson

The constitution must distinguish:

``` text
verified ordering
```

from:

``` text
same-phase effects whose internal ordering is not publicly established
```

Do not invent a priority rule merely because an observed sequence
happened to look consistent.

------------------------------------------------------------------------

# 10. DoT interaction with mitigation

Monster Train's building blocks make it possible for a DoT effect to
interact with:

-   Armor;
-   Damage Shield;
-   Reanimate;
-   healing;
-   status removal;
-   damage modifiers;
-   damage-type-specific modifiers;
-   death triggers;
-   status-triggered effects.

The important Action Constitution question for each DoT is:

``` text
At what phase does it become damage?
    ↓
Which damage pipeline does it enter?
    ↓
Which prevention/modification systems can affect it?
    ↓
Does it generate "damaged" reactions?
    ↓
Can it cause lethal damage?
    ↓
Which death/kill semantics follow?
```

Do not define "DoT" as a special shortcut around the normal damage
pipeline unless the game's rules explicitly require that behavior.

------------------------------------------------------------------------

# 11. Negative status effects

MT2 includes several distinct forms of debuff.

## Attack reduction / Sap

Sap weakens Attack.

It is different from:

``` text
-Health
```

or:

``` text
Melee Weakness
```

because it modifies offensive capability rather than directly increasing
incoming damage.

## Melee Weakness

Increases vulnerability to normal combat damage.

MT1 patch notes explicitly clarified its decay behavior: it decays at
end of turn regardless of whether the unit was hit in combat.

## Spell Weakness

Increases damage from applicable spells.

## Pyregel

MT2 status: increases incoming damage per stack.

## Dazed

Restricts a unit's ability to perform its normal attack/action
opportunity.

## Fragile

Causes death if the affected unit takes Health damage.

## Stealth

Can be offensive/defensive depending on context, but is fundamentally a
temporary state that changes targeting/damage interaction.

## Silence / Mute

Suppresses ability/trigger behavior.

## Emberdrain

Restricts/reduces Ember availability.

## Corruption

A status/resource mechanism with its own trigger timing and scaling
interactions.

------------------------------------------------------------------------

# 12. Control effects

Monster Train has several ways to change what an actor is able to do or
where it is located.

### Dazed

Prevents/affects attack opportunities for its duration.

### Frozen

Applies to cards rather than units and prevents normal card play until
removed.

### Phased

Units cannot attack, be targeted, or take damage.

### Silence

Removes/suppresses abilities and trigger behavior.

### Retreat

Moves an enemy unit out of the active floor/encounter.

### Ascend

Moves a unit upward.

### Descend

Moves a unit downward.

### Advance

Moves a unit to the front of a floor.

### Shift

Moves a unit and can itself be a trigger condition.

### Teleport

Abilities can move units directly to targeted locations.

These should be treated as **state-changing effects with
positional/lifecycle consequences**, not merely visual movement.

------------------------------------------------------------------------

# 13. Attack-pattern effects

Monster Train makes attack behavior modular.

Important attack traits/effects include:

-   Multistrike;
-   Quick;
-   Sweep;
-   Trample;
-   immediate attack;
-   attack any enemy;
-   attack front enemy;
-   repeated attack;
-   attack based on current stats;
-   attacks generated by abilities;
-   attacks generated outside the normal combat scheduler.

Examples from MT2 include:

-   Animus of Speed --- Quick ability that attacks immediately;
-   Follower --- Multistrike;
-   Coldcaelia --- Sweep Strike;
-   Bog Wurmling --- Trample;
-   Conductor Steward --- ability causing friendly units to attack
    immediately;
-   Consumer of Crowns --- immediate attack ability.

This is important for Action Constitution because:

> **An attack is an action primitive that can itself be initiated by
> several different sources.**

The source does not have to be the normal turn scheduler.

------------------------------------------------------------------------

# 14. Trigger families are reusable building blocks

The most important design pattern in Monster Train is:

``` text
TRIGGER
    +
TARGET
    +
EFFECT
```

Examples:

### Summon + Rage

``` text
When summoned
→ friendly units
→ apply Rage
```

### Strike + Unstable

``` text
When striking
→ enemy units
→ apply Unstable
```

### Revenge + Frostbite

``` text
When damaged
→ attacker / enemy floor
→ apply Frostbite
```

### Revenge + Decay

``` text
When damaged
→ attacker
→ apply Decay
```

### Slay + Resource

``` text
When you kill
→ self
→ gain Ember / Gold / Forge / etc.
```

### Harvest + Rage

``` text
When a unit dies
→ self
→ gain Rage
```

### Resolve + Armor

``` text
After combat
→ friendly units
→ apply Armor
```

### Incant + Damage

``` text
When a spell is played
→ enemy floor
→ deal damage
```

This compositional vocabulary is one of the strongest things to
reproduce.

------------------------------------------------------------------------

# 15. Targeting building blocks

Monster Train's target system is extremely expressive.

The exposed effect reference includes target modes such as:

-   self;
-   source;
-   current target;
-   front friendly unit;
-   front opposing unit;
-   random friendly unit;
-   random opposing unit;
-   all friendly units;
-   all opposing units;
-   all units;
-   selected units;
-   room/floor;
-   Pyre;
-   specific subtype;
-   units with/without a status;
-   units meeting health conditions;
-   units meeting equipment conditions;
-   units on specific floors;
-   units created from cards;
-   units not created from cards;
-   units with/without equipment;
-   units with a specific upgrade/status;
-   target collected by a previous effect.

The CardEffect reference explicitly includes parameters for:

-   target team;
-   target mode;
-   subtype;
-   excluded subtype;
-   status filters;
-   room index;
-   first-wave restriction;
-   equipment state;
-   card origin;
-   character filters.

------------------------------------------------------------------------

# 16. Targeting can be positional

Examples:

``` text
front friendly unit
front opposing unit
random enemy
random friendly
all enemies
all friendlies
same floor
all floors
```

MT2 also includes effects such as:

-   Retreat front enemy;
-   Descend all units;
-   Advance a friendly unit;
-   deal damage to front enemy;
-   apply status to enemy units on all floors;
-   transfer statuses to front opposing unit.

This makes **position a reusable targeting primitive**, not a special
case.

------------------------------------------------------------------------

# 17. Targeting can be semantic

Examples:

``` text
all Burnout units
all units of subtype X
units without equipment
units with status X
units below health threshold
units above health threshold
units summoned from cards
units not summoned from cards
enemy non-boss units
```

This is particularly valuable for Flashcard Heroes because it enables
traits and factions to be expressed through filters rather than bespoke
abilities.

------------------------------------------------------------------------

# 18. Targeting can be conditional

The effect reference supports conditions such as:

-   only if there are no player units;
-   only above/below a health percentage;
-   only if a status exists;
-   only when a threshold is crossed;
-   only when enough Gold/Energy was spent;
-   only when a room has capacity;
-   only when a target is valid;
-   only if the target is unequipped;
-   only for specific subtypes;
-   only in specific moon phases.

This allows:

``` text
TRIGGER
  +
TARGET FILTER
  +
CONDITION
  +
EFFECT
```

rather than creating a unique ability class for every combination.

------------------------------------------------------------------------

# 19. Scaling building blocks

MT2 repeatedly uses effects whose magnitude is derived from another game
value.

Documented scaling sources include:

-   current Attack;
-   target Attack;
-   current Health;
-   missing Health;
-   remaining Health percentage;
-   Armor;
-   number of units killed;
-   number of status stacks;
-   energy/Ember spent;
-   Gold spent;
-   Forge spent;
-   Dragon's Hoard;
-   Corruption;
-   number of cards;
-   number of consumed spells;
-   previous attack damage;
-   capacity;
-   number of deaths;
-   another effect's stack count.

Examples from the card pool:

``` text
damage = 10 × Spikes
damage = 4 × Armor
damage = 2 × Health + Armor
damage = 8 × Corrupt
damage = 20 × consumed spells
Attack gained = based on Pyregel
status stacks = based on missing HP
status stacks = based on Gold spent
```

This is one of the richest areas for Flashcard Heroes inspiration.

------------------------------------------------------------------------

# 20. Distribution building blocks

Status application can be distributed in different ways.

The MT2 effect reference explicitly supports:

### Identical distribution

Every target gets the same number of stacks.

### Even distribution

A total amount is divided across all targets.

This distinction is valuable for effects such as:

``` text
Apply 10 Armor to all allies
```

versus:

``` text
Distribute 10 Armor among all allies
```

The same concept can apply to damage, buffs, resources, or other
effects.

------------------------------------------------------------------------

# 21. Status stacking operations

MT2 supports more than simply "add N stacks."

It has primitives for:

-   add stacks;
-   remove stacks;
-   multiply stacks;
-   multiply all positive statuses;
-   multiply all statuses;
-   transfer stacks;
-   copy stacks;
-   convert one status into another;
-   add a status based on another status;
-   propagate a status;
-   remove all statuses of a category;
-   remove statuses at thresholds;
-   modify status magnitude globally.

Examples:

``` text
Frostbite 5 → Frostbite 10
```

``` text
Decay → transfer to another unit
```

``` text
Status A × Status B count
```

``` text
Status A is removed
→ apply Status B
```

``` text
Status threshold reached
→ add Status C
```

This is a powerful combinatorial system.

------------------------------------------------------------------------

# 22. Status synergy

`CardEffectSynergizeStatusEffects` is especially interesting.

It allows:

``` text
Status A triggers
→ add Status B
```

and can either:

-   add one B;
-   add B based on A's stack count.

This creates mechanics such as:

``` text
every 3 stacks of X
→ gain Y
```

or:

``` text
when X is applied
→ convert/translate it into Y
```

The important architecture insight is that **one status can become the
event source for another effect without requiring a bespoke ability
class**.

------------------------------------------------------------------------

# 23. Status transfer

MT2 can transfer all or selected statuses:

``` text
source unit
    ↓
target unit
```

and target selection can include:

-   random opposing unit;
-   random friendly unit;
-   front friendly unit;
-   front opposing unit;
-   every opposing unit;
-   distributed across a team;
-   distributed across a hero team.

The card **Brain Transfer** is a concrete example of transferring Attack
plus buff/debuff state to the front friendly unit.

This is a rich building block for Flashcard Heroes:

``` text
sacrifice / move / merge / infect / cleanse / possession
```

can all be built from state transfer primitives.

------------------------------------------------------------------------

# 24. Buff lifetime

MT2 supports explicit upgrade lifetimes:

``` text
TemporaryUntilEndOfBattle
TemporaryUntilUnitDeath
Permanent
```

This is distinct from ordinary stack decay.

That distinction is useful:

### Temporary upgrade

``` text
+20 Attack until combat ends
```

### Until death

``` text
+20 Attack until this unit dies
```

### Permanent

``` text
+20 Attack permanently
```

A constitution should define these as different persistence classes.

------------------------------------------------------------------------

# 25. Equipment as a compositional container

Equipment is particularly instructive.

An Equipment card can:

-   modify Attack;
-   modify Health;
-   modify Size;
-   add Status Effects;
-   add Character Triggers;
-   add abilities/upgrades;
-   alter equipment-specific state.

When equipment is removed/replaced, the associated upgrade is removed.

This creates:

``` text
EQUIPMENT
    ↓
UPGRADE PACKAGE
    ├── stats
    ├── statuses
    ├── triggers
    └── abilities
```

This is a strong example of composition instead of bespoke character
logic.

------------------------------------------------------------------------

# 26. Rooms as global effect containers

Rooms can provide:

-   passive stat bonuses;
-   capacity changes;
-   room-wide status effects;
-   triggered effects;
-   post-combat effects;
-   effects applied to units entering the room;
-   effects applied to units when statuses change;
-   effects that modify the room itself.

A room therefore acts like:

``` text
ROOM
    ↓
ROOM STATE
    +
ROOM MODIFIERS
    +
GLOBAL TRIGGERS
```

This is conceptually different from a unit-owned effect.

------------------------------------------------------------------------

# 27. Ability building blocks

MT2 represents unit abilities through card-like effect structures.

An ability can:

-   deal damage;
-   heal;
-   apply statuses;
-   move units;
-   summon units;
-   modify stats;
-   consume/smelt cards;
-   attack immediately;
-   manipulate resources;
-   interact with equipment;
-   manipulate cooldown;
-   cause another trigger.

Abilities therefore use the same basic effect vocabulary as cards.

This is a strong argument for a unified effect language across different
action sources.

------------------------------------------------------------------------

# 28. Resource effects

Monster Train has effects for:

-   gaining Ember;
-   gaining Ember next turn;
-   gaining Ember every turn;
-   spending Forge;
-   gaining Forge points;
-   gaining Gold;
-   gaining Gold based on Dragon's Hoard;
-   Dragon's Hoard;
-   modifying card cost;
-   Emberdrain;
-   drawing cards;
-   modifying future draw;
-   discarding;
-   consuming/exhausting;
-   adding cards to piles.

These effects can be triggered from combat events:

``` text
Slay
→ gain Gold
```

or:

``` text
Summon
→ gain Ember
```

or:

``` text
End of Turn
→ gain resource
```

This demonstrates that the Action Constitution cannot be combat-only.

------------------------------------------------------------------------

# 29. Card manipulation building blocks

MT2 can:

-   draw;
-   discard;
-   consume;
-   freeze;
-   add cards;
-   create copies;
-   create upgraded copies;
-   return cards;
-   move cards between piles;
-   modify cost;
-   apply temporary upgrades;
-   apply permanent upgrades;
-   add cards to the deck;
-   add cards to hand;
-   create cards based on previous cards;
-   replay triggers;
-   replay effects;
-   create cards based on targets.

These are management-phase effects that use the same general
action/effect resolution principles.

------------------------------------------------------------------------

# 30. Unit creation and lifecycle building blocks

Monster Train provides:

-   Spawn Hero;
-   Spawn Monster;
-   Spawn multiple units;
-   Spawn from a pool;
-   Spawn from deck;
-   Spawn conditionally;
-   Spawn-or-apply-status;
-   Return unit to hand;
-   Retreat;
-   Despawn;
-   Kill;
-   Reanimate;
-   Reform;
-   Endless;
-   Eaten;
-   Hatch;
-   Sacrifice;
-   Feed;
-   Merge equipment;
-   Equip/remove equipment.

These are lifecycle effects and should be considered first-class
actions/effects in Action Constitution.

------------------------------------------------------------------------

# 31. Immediate attack versus scheduled attack

MT2 provides effects that cause a unit to attack immediately.

This is important because it proves:

``` text
attack
```

does not necessarily mean:

``` text
normal scheduled combat turn
```

There can be:

``` text
primary scheduled attack
```

and:

``` text
effect-generated immediate attack
```

The Action Constitution must explicitly define whether an immediate
attack:

-   becomes a nested action;
-   resolves as a child of the initiating effect;
-   can generate all normal attack triggers;
-   can itself create further immediate attacks.

The coding agent should inspect the current implementation before
deciding the exact architecture.

------------------------------------------------------------------------

# 32. Sacrifice and feed

MT2 distinguishes destruction/death-related operations from ordinary
damage.

Examples include:

-   sacrifice;
-   sacrifice-or-feed;
-   destroy a friendly unit;
-   kill an enemy;
-   Eaten trigger;
-   Gorge trigger.

The **Glutton's Maw** example is especially useful:

``` text
destroy friendly unit
→ gain Attack/Health
→ triggers Gorge
→ triggers Eaten
```

This is a compact example of one effect producing multiple semantic
consequences.

------------------------------------------------------------------------

# 33. Death-prevention building blocks

Reanimate provides a clear pattern:

``` text
unit would die
    ↓
death-prevention state checked
    ↓
unit survives/revives
    ↓
status stack consumed
    ↓
post-reanimation effects may occur
```

This belongs in the same hierarchy as lethal damage and death.

It should not be implemented as an unrelated "heal to 1" shortcut
because its semantic meaning is:

> The unit was killed, but a death-prevention/reanimation rule altered
> the final lifecycle result.

------------------------------------------------------------------------

# 34. "Kill" versus damage

`CardEffectKill` is a distinct effect from `CardEffectDamage`.

This is important.

A direct Kill does not mean:

``` text
deal infinite damage
```

It is a different semantic operation.

The Action Constitution should therefore distinguish:

``` text
Damage
```

from:

``` text
Kill
```

even if both can eventually result in a dead unit.

The downstream trigger semantics may depend on the cause.

------------------------------------------------------------------------

# 35. Damage type is itself a building block

The MT2 effect/relic references expose damage types including:

-   Default;
-   Spikes;
-   Poison;
-   TowerHeart;
-   DirectAttack;
-   Splash;
-   Trample;
-   CorruptPoison;
-   Decay;
-   Corruption;
-   SpellOverflow.

This matters because some effects can filter or modify damage based on
its type.

Therefore:

``` text
DamageContext
```

should carry **damage provenance/type** as semantic data.

This is especially important when building reactions such as:

``` text
When killed by X
```

or:

``` text
reduce damage from X
```

or:

``` text
trigger only from combat damage
```

------------------------------------------------------------------------

# 36. Damage-source and cause provenance

MT2 relic effects can filter a unit-death reaction by damage type.

This means a death can retain information such as:

``` text
who killed it
what caused the damage
what damage type it was
what source team caused it
```

That is a major building block for advanced reactive design.

For Flashcard Heroes, useful future semantics include:

``` text
Killed by attack
Killed by ability
Killed by status
Killed by reflected damage
Killed by environmental effect
Killed by self-sacrifice
```

The game should only expose these if the design actually needs them, but
the architecture should not make provenance impossible to preserve.

------------------------------------------------------------------------

# 37. Reactions can modify the next resolution

MT2 status-effect trigger output parameters can affect subsequent
processing.

Documented examples include:

-   modify damage;
-   modify stacks removed;
-   block CharacterTriggers;
-   block attacking;
-   block healing.

This demonstrates a critical category:

> **A reaction can modify the resolution currently underway rather than
> merely create a later effect.**

That means Action Constitution needs a distinction between:

``` text
pre-resolution modifiers
```

and:

``` text
post-resolution reactions
```

This is particularly important for damage.

------------------------------------------------------------------------

# 38. Before/after modification pattern

A useful generic pattern is:

``` text
ACTION
  ↓
PRE-EFFECT MODIFIERS
  ↓
EFFECT CALCULATION
  ↓
EFFECT APPLICATION
  ↓
POST-EFFECT REACTIONS
```

Examples:

``` text
Before damage
→ modify/prevent damage
→ apply damage
→ Revenge
```

``` text
Before attack
→ modify attack
→ attack
→ Strike
```

``` text
Before death
→ Reanimate/death prevention
→ death
→ Extinguish/Harvest/Slay
```

This is one of the most important reusable patterns for Flashcard
Heroes.

------------------------------------------------------------------------

# 39. Trigger-generated trigger chains

Monster Train content frequently composes chains:

``` text
Summon
→ Summon trigger
→ Rage
```

``` text
Strike
→ Unstable
→ end-of-turn explosion
→ damage
→ death
→ Slay
```

``` text
Revenge
→ Decay
→ end-of-turn damage
→ death
→ Harvest
```

``` text
Slay
→ gain resource
→ resource threshold
→ another effect
```

This is where the Action Constitution becomes essential: every generated
effect must enter the same deterministic resolution system.

------------------------------------------------------------------------

# 40. "Buffs are not abilities"; buffs are payloads

One of the most useful design lessons is that:

``` text
+Attack
```

is a reusable effect payload.

It can be attached to:

-   Summon;
-   Strike;
-   Slay;
-   Revenge;
-   Harvest;
-   Resolve;
-   Incant;
-   equipment;
-   room;
-   ability;
-   card play;
-   health threshold;
-   status threshold;
-   resource spending.

Similarly:

``` text
Apply Armor
```

can be delivered by:

-   a spell;
-   an ability;
-   equipment;
-   Resolve;
-   Revenge;
-   a room;
-   a status conversion;
-   a resource threshold.

Therefore the design vocabulary should separate:

``` text
WHEN
```

from:

``` text
WHAT
```

and:

``` text
TO WHOM
```

------------------------------------------------------------------------

# 41. A reusable composition matrix

The most useful way to study Monster Train is as a matrix.

## Trigger axis

``` text
Start of Turn
Team Turn Start
Action
Summon
Strike
Damage Received / Revenge
Kill / Slay
Death / Extinguish
Any Ally Death
Any Enemy Death
Heal / Rejuvenate
Spell Played / Incant
Unit Played / Rally
Gorge
Eaten
Equipment Added
Equipment Removed
Status Added
Status Removed
Moon Phase Change
Conditional State Entered
Conditional State Lost
End of Turn
Post Combat / Resolve
Ability Activated
Room Entered
Encounter Complete
```

## Target axis

``` text
Self
Specific Source
Front Ally
Front Enemy
Any Ally
Any Enemy
All Allies
All Enemies
All Units
Random Ally
Random Enemy
Attacker
Killer
Affected Unit
Same Floor
All Floors
Pyre
Card in Hand
Card in Deck
Specific Subtype
Specific Status
Specific Equipment State
```

## Effect axis

``` text
Deal Damage
Heal
Kill
Apply Status
Remove Status
Modify Status
Multiply Status
Transfer Status
Copy Status
+Attack
+Health
+Max Health
-Health
+Armor
Damage Shield
Draw
Discard
Consume
Freeze
Add Card
Return Card
Modify Cost
Gain Resource
Lose Resource
Summon
Retreat
Advance
Ascend
Descend
Move
Attack Immediately
Equip
Unequip
Reanimate
Sacrifice
Feed
Modify Cooldown
Modify Capacity
Modify Room State
Create/Copy
Replay Trigger
```

The combination:

``` text
TRIGGER × TARGET × EFFECT
```

is the primary content-generation vocabulary.

------------------------------------------------------------------------

# 42. Interesting Monster Train combinations worth studying

These are particularly useful design patterns.

## Summon → global debuff

A unit summons and immediately applies Decay/Sap/Rage/etc.

This makes the act of entering the board meaningful.

------------------------------------------------------------------------

## Summon → conditional scaling

A unit is summoned and gains stats based on:

-   current room;
-   status count;
-   existing units;
-   max health;
-   resources.

This makes board state affect deployment value.

------------------------------------------------------------------------

## Strike → status application

An attacker can transform ordinary attacks into status delivery.

Examples:

``` text
Strike → Rage
Strike → Unstable
Strike → Frostbite
Strike → attack reduction
```

This makes repeated attacks interact multiplicatively with trigger
design.

------------------------------------------------------------------------

## Revenge → attacker punishment

Damage received becomes a source of retaliation.

Examples:

``` text
Revenge → Frostbite attacker
Revenge → Decay attacker
Revenge → Melee Weakness attacker
Revenge → Forge/resource
```

This makes defensive positioning offensive.

------------------------------------------------------------------------

## Slay → permanent growth

Killing becomes a scaling engine:

``` text
Slay → +Attack
Slay → Gold
Slay → Capacity
Slay → resource
Slay → new card
Slay → Reanimate
```

------------------------------------------------------------------------

## Harvest → global snowball

Any unit death becomes a trigger for the surviving board.

This creates intentional death economies.

------------------------------------------------------------------------

## Rejuvenate → permanent growth

Healing itself becomes progression:

``` text
heal
→ permanent Attack
```

This makes defense an offensive scaling strategy.

------------------------------------------------------------------------

## End of Turn → state decay

Persistent statuses become timed resources.

Examples:

``` text
Burnout
Stealth
Frostbite
Decay
Regen
Corruption
Unstable
```

Each has a distinct interaction with the lifecycle.

------------------------------------------------------------------------

## Status → status conversion

Examples:

``` text
Status A
→ add Status B
```

or:

``` text
remove Status A
→ gain Status B
```

This supports combo engines without hardcoding every combination.

------------------------------------------------------------------------

## Status count → stat scaling

Examples:

``` text
Spikes → damage
Corrupt → Attack
Pyregel → Attack
Armor → damage
Status count → number of upgrades
```

This is an important bridge between persistent state and direct effects.

------------------------------------------------------------------------

# 43. Example: a complete causal chain

Consider:

``` text
Unit A has Revenge:
    Apply Decay 5 to attacker.

Enemy B attacks A.
```

Resolution conceptually becomes:

``` text
Primary Action:
    Enemy B Attack
        ↓
Attack Started
        ↓
Damage Calculation
        ↓
Damage Applied to A
        ↓
A's Revenge becomes eligible
        ↓
Revenge Effect:
    Apply Decay 5 to B
        ↓
Status Applied
        ↓
future End-of-Turn processing
        ↓
Decay damage
        ↓
Damage Event
        ↓
possible lethal check
        ↓
possible Death
        ↓
death-related triggers
```

The Revenge effect is not "another attack."

It is a reaction whose effect changes future state.

------------------------------------------------------------------------

# 44. Example: multiple DoTs

Suppose a unit has:

``` text
Frostbite
Decay
Burnout
Regen
Unstable
```

At End of Turn, these do not form one generic "status tick."

The documented lifecycle gives them semantic sub-phases:

``` text
Regen
→ Frostbite / Decay / Burnout / Witherbloom / Stealth
→ Corruption
→ Unstable
```

and this entire sequence happens separately for enemy and friendly
units.

This is exactly the kind of hierarchy Action Constitution must
represent.

Where the public documentation does not establish the ordering inside a
shared sub-phase, the constitution should not manufacture one.

------------------------------------------------------------------------

# 45. Example: mitigation before damage reaction

Suppose:

``` text
Enemy deals damage.
Target has Damage Shield.
Target has Revenge.
```

The semantic questions are:

``` text
Was damage actually applied?
```

If the Damage Shield prevents the damage instance, then the condition
for Revenge is not satisfied.

This illustrates why:

``` text
damage attempt
```

and:

``` text
damage applied
```

must remain different events.

------------------------------------------------------------------------

# 46. Example: healing as an event source

Suppose:

``` text
Unit has Rejuvenate.
Spell heals unit.
```

The heal is an effect.

The successful heal is an event.

Rejuvenate becomes eligible.

Its effect may then:

``` text
+Attack permanently
```

Therefore:

``` text
Heal
→ Rejuvenate
→ permanent stat change
```

The same event/effect chain can be used whether the heal came from:

-   a spell;
-   an ability;
-   a room;
-   a status;
-   another reaction.

------------------------------------------------------------------------

# 47. Example: death-prevention interaction

Suppose:

``` text
Unit has Reanimate.
Enemy deals lethal damage.
```

The hierarchy must allow:

``` text
damage
→ lethal determination
→ death-resolution window
→ Reanimate modifies outcome
→ unit survives/revives
→ death-dependent effects that require actual death are handled according to the final outcome
```

This is fundamentally different from:

``` text
heal to 1
```

because the effect is attached to the **death lifecycle**.

------------------------------------------------------------------------

# 48. Example: multi-effect card

MT2 cards often combine several effects in one action.

Example pattern:

``` text
Consume
+
Heal
+
Apply Armor
+
Apply Status
+
Draw
```

The card is one primary action, but its effects have an ordered internal
sequence.

Action Constitution therefore needs an explicit concept of:

``` text
effect sequence within an action
```

not only:

``` text
action sequence between actions
```

------------------------------------------------------------------------

# 49. Example: generated action inside an effect

An ability can:

``` text
Move unit
→ attack immediately
```

The immediate attack is not merely a visual consequence. It is another
meaningful action.

The constitution must determine:

``` text
Does the immediate attack fully resolve before the parent ability continues?
```

and:

``` text
Can its reactions generate further nested actions?
```

Monster Train's content demonstrates that this class of composition is
necessary.

------------------------------------------------------------------------

# 50. Example: room + unit + trigger

Consider:

``` text
Room:
    Friendly units gain Valor on Slay.
```

Then:

``` text
Unit A kills Enemy B.
```

The causal chain becomes:

``` text
Attack
→ damage
→ Enemy death
→ A's Slay
→ room's Slay listener
→ apply Valor
```

This is a critical example of **scope**:

``` text
unit-owned trigger
```

and:

``` text
room-owned trigger
```

can listen to the same semantic event.

------------------------------------------------------------------------

# 51. Example: equipment + trigger + status

An Equipment can give:

``` text
+10 Attack
+10 Health
Strike:
    Apply Unstable 5
```

This creates a package:

``` text
equipment
    ├── permanent/attached stat modifications
    └── trigger
           └── status effect
```

This is an excellent model for Flashcard Heroes trinkets/equipment if
the game ever needs richer conditional behavior.

------------------------------------------------------------------------

# 52. Example: status count as a resource

MT2 frequently treats status stacks as an internal resource.

Examples:

``` text
Corrupt count → damage
Spikes count → damage
Armor count → damage
Pyregel count → Attack
Forge count → stat scaling
Dragon's Hoard → reward scaling
```

This allows a status to serve simultaneously as:

``` text
state
counter
scaling input
trigger condition
resource
```

That is a particularly powerful building block for deckbuilder design.

------------------------------------------------------------------------

# 53. Example: effect generated by effect magnitude

The CardEffect reference supports effects where the amount of one effect
depends on another quantity.

Examples:

``` text
Heal amount
→ determines damage

Status count
→ determines upgrade count

Missing health
→ determines status stacks

Gold spent
→ determines upgrade count

Last attack damage
→ determines status stacks

Other status count
→ determines new status stacks
```

This is a general pattern:

``` text
Measure State
    ↓
Calculate Magnitude
    ↓
Apply Effect
```

It should be recognized as a reusable effect primitive.

------------------------------------------------------------------------

# 54. Propagation

MT2's Propagate mechanic provides another important building block.

A status/effect can be propagated from one unit to others.

The card pool contains examples such as:

``` text
Propagate 2
```

and cards that cause enemy units to Propagate.

This creates a distinction between:

``` text
apply to selected targets
```

and:

``` text
spread through the board/state
```

For Flashcard Heroes, this could inspire:

-   status infection;
-   elemental spread;
-   chain buffs;
-   adjacent-unit propagation;
-   chain reactions.

------------------------------------------------------------------------

# 55. Copying state

MT2 supports copying:

-   units;
-   upgrades;
-   stats;
-   positive status effects;
-   cards;
-   upgraded cards.

This is a powerful building block for:

``` text
clone
duplicate
inherit
echo
mirror
replicate
```

The implementation should preserve whether the copied thing is:

``` text
identity
base stats
current stats
temporary modifiers
persistent modifiers
status stacks
equipment
ability state
```

Those are distinct copying semantics.

------------------------------------------------------------------------

# 56. Removal and cleansing

Monster Train provides multiple levels of removal:

-   remove one specific status;
-   remove all positive statuses;
-   remove all negative statuses;
-   remove all statuses of a category;
-   remove equipment;
-   remove ability;
-   remove temporary upgrade;
-   purge a unit;
-   return unit to hand;
-   despawn;
-   kill.

This demonstrates that "remove" is not one operation.

The player-facing vocabulary should make the scope explicit.

------------------------------------------------------------------------

# 57. Conditional status application

MT2 can add a status based on:

-   current health percentage;
-   missing health;
-   another status;
-   another status threshold;
-   resource expenditure;
-   subtype;
-   equipment;
-   room;
-   moon phase;
-   presence/absence of units;
-   status count.

This is one of the strongest examples of a **generic effect language**.

Instead of creating:

``` text
ApplyDecayWhenLowHealth
```

the system can conceptually compose:

``` text
condition:
    health ≤ threshold

effect:
    Apply Decay
```

------------------------------------------------------------------------

# 58. Randomness as a controlled effect parameter

MT2 uses randomization in several places:

-   random unit;
-   random card;
-   random status;
-   random target;
-   random discard;
-   random amount;
-   random pool selection.

Randomness therefore belongs in the effect specification rather than
being allowed to leak into ordering.

For deterministic replays:

``` text
random selection
```

must itself be a recorded resolution decision.

------------------------------------------------------------------------

# 59. Important distinction: random choice vs deterministic resolution

A random target can be selected deterministically from a seeded RNG.

After the target is selected:

``` text
the resolution sequence remains deterministic.
```

Therefore:

``` text
randomness
```

and:

``` text
nondeterministic execution order
```

are completely different problems.

Action Constitution should explicitly separate them.

------------------------------------------------------------------------

# 60. Cooldowns and ability availability

MT2 abilities can have:

-   cooldown at spawn;
-   cooldown after activation;
-   cooldown adjustment;
-   cooldown reset;
-   ability enabled/disabled states.

This creates another lifecycle:

``` text
Ability available
→ player/AI activates
→ ability resolves
→ cooldown begins
→ turns/phases progress
→ cooldown decreases
→ ability available again
```

Cooldown state is therefore another form of persistent state that can
interact with actions.

------------------------------------------------------------------------

# 61. Movement is a trigger source

Movement can be both:

``` text
EFFECT:
    Move unit
```

and:

``` text
EVENT:
    Unit moved
```

and:

``` text
TRIGGER:
    Shift
```

This is a useful model for Flashcard Heroes because
movement/rearrangement is likely to matter in the game's board state.

The action constitution should distinguish:

``` text
requested movement
```

from:

``` text
successful movement
```

so movement-triggered effects only fire when appropriate.

------------------------------------------------------------------------

# 62. Position can be a condition

Vanguard demonstrates:

``` text
condition:
    unit is frontmost
```

with a trigger that activates when the condition becomes true and a
separate lost condition when it stops being true.

This is different from:

``` text
OnMove
```

The player-facing semantics are:

``` text
while in front
```

rather than:

``` text
when moved
```

That distinction is extremely useful for designing positional passives.

------------------------------------------------------------------------

# 63. Trigger activation versus persistent conditional state

The Vanguard pattern is:

``` text
condition becomes true
→ activate effect

condition becomes false
→ lost/undo effect
```

This can model:

-   front-row bonuses;
-   low-health bonuses;
-   moon-phase bonuses;
-   equipment requirements;
-   room occupancy;
-   adjacent-unit relationships.

This is different from an event trigger and should be a first-class
semantic category.

------------------------------------------------------------------------

# 64. Adjacent targeting and topology

Although the MT2 effect reference exposes many target modes, not every
relationship should be reduced to "all units."

Useful topological relationships include:

``` text
self
front ally
front enemy
attacker
killer
same floor
all floors
unit's eater
units affected by event
specific subtype
specific status
```

The important lesson is to make target relationships reusable.

If the game later wants:

``` text
adjacent allies
```

it should ideally be a target selector, not a bespoke ability.

------------------------------------------------------------------------

# 65. A practical design grammar

Monster Train's content can be described with a grammar:

``` text
ABILITY :=
    TRIGGER
    +
    TARGET_SELECTOR
    +
    OPTIONAL_CONDITION
    +
    EFFECT_SEQUENCE
```

Where:

``` text
TRIGGER :=
    lifecycle
    | action
    | state event
    | cause-specific event
    | persistent condition
```

``` text
TARGET_SELECTOR :=
    self
    | source
    | attacker
    | killer
    | front ally
    | front enemy
    | random ally
    | random enemy
    | all allies
    | all enemies
    | floor
    | all floors
    | filtered units
    | resource/card target
```

``` text
EFFECT :=
    damage
    | heal
    | stat change
    | status change
    | lifecycle
    | movement
    | attack
    | resource
    | card manipulation
    | equipment
    | room modification
    | ability/cooldown
```

``` text
CONDITION :=
    health
    | status
    | status threshold
    | resource
    | subtype
    | position
    | equipment
    | room
    | moon phase
    | card origin
    | target availability
```

This grammar is the core inspiration to extract from Monster Train.

------------------------------------------------------------------------

# 66. Where effects fit into the Action Constitution hierarchy

A generic example:

``` text
PRIMARY ACTION
│
├── PRE-ACTION TRIGGERS
│
├── EFFECT
│   │
│   ├── STATE MUTATION
│   │
│   ├── EVENT
│   │
│   └── REACTION DISCOVERY
│       │
│       ├── TRIGGER A
│       │   └── EFFECT
│       │       └── EVENT
│       │
│       └── TRIGGER B
│           └── EFFECT
│
├── CONDITIONAL CONSEQUENCES
│
└── ACTION COMPLETE
```

A status application is therefore not inherently "higher" or "lower"
priority than damage.

Its position depends on **why it is being applied**.

Examples:

``` text
Attack
→ Apply Rage to attacker
```

and:

``` text
Attack
→ Damage enemy
→ Revenge
→ Apply Rage
```

can legitimately have different resolution positions.

The trigger semantics determine the placement.

------------------------------------------------------------------------

# 67. DoT hierarchy example

A useful canonical structure is:

``` text
END-OF-TURN PHASE
│
├── Regen
│
├── DoT / decay family
│   ├── Frostbite
│   ├── Decay
│   ├── Burnout
│   ├── Witherbloom
│   └── Stealth
│
├── Corruption
│
└── Unstable
```

This is the documented MT2 broad ordering.

Inside the shared DoT/decay family, the public source does **not**
establish a definitive universal ordering among every individual effect.
Therefore Action Constitution should not invent one from this document.

If Flashcard Heroes needs deterministic ordering among multiple
same-phase DoTs, that ordering must be deliberately designed and
documented.

------------------------------------------------------------------------

# 68. DoT can create ordinary death chains

If a DoT causes actual damage, it can produce:

``` text
DoT tick
→ damage
→ lethal check
→ death
→ death triggers
→ kill/source reactions where applicable
→ cleanup
```

This is why DoT must be treated as a genuine damage-producing effect
rather than a special "tick HP at end of turn" shortcut.

------------------------------------------------------------------------

# 69. Defensive mitigation belongs inside the damage pipeline

If a DoT produces ordinary damage, then the relevant damage rules should
determine whether:

-   Armor absorbs it;
-   Damage Shield prevents it;
-   damage modifiers alter it;
-   vulnerability amplifies it;
-   death prevention changes the result;
-   damage-triggered reactions become eligible.

This is the most robust way to avoid contradictions between direct
attacks and damage-over-time effects.

------------------------------------------------------------------------

# 70. Content-design matrix for Flashcard Heroes

The Monster Train library suggests building content from these
dimensions.

  -----------------------------------------------------------------------
  Dimension                           Examples
  ----------------------------------- -----------------------------------
  Trigger                             Start Turn, Attack, Damage, Death,
                                      Kill, Summon, Heal, End Turn

  Source                              Self, Ally, Enemy, Room, Item,
                                      Ability, Card

  Target                              Self, Front Ally, Front Enemy,
                                      Attacker, Killer, All Allies, All
                                      Enemies

  Condition                           HP, Status, Position, Subtype,
                                      Resource, Equipment

  Payload                             Damage, Heal, Attack, HP, Armor,
                                      Status, Movement, Resource

  Persistence                         Instant, Until End of Turn, Until
                                      Death, Battle, Permanent

  Scaling                             Fixed, Attack, HP, Missing HP,
                                      Status Count, Resource

  Distribution                        Single, All, Random, Even,
                                      Identical

  Secondary effect                    Draw, Summon, Move, Trigger, Create
                                      Card

  Follow-up                           New Event, Reaction, Death, Cleanup
  -----------------------------------------------------------------------

This matrix is more valuable for content generation than a list of
individual abilities.

------------------------------------------------------------------------

# 71. High-value patterns for Flashcard Heroes

The following combinations are particularly worth exploring because
Monster Train demonstrates that they create deep interactions from
simple primitives.

### Trigger × stat growth

``` text
Slay → +Attack
Rejuvenate → +Attack
Strike → +Attack
Summon → +Health
```

### Trigger × status

``` text
Revenge → Decay
Strike → Unstable
Summon → Sap
Resolve → Armor
```

### Status × scaling

``` text
Spikes → damage
Armor → damage
Corrupt → damage
Pyregel → Attack
```

### Status × status

``` text
Status A → Status B
Status A removed → Status B
Status threshold → Status B
```

### Lifecycle × resource

``` text
Summon → Ember
Slay → Gold
Death → Forge
Extinguish → card/resource
```

### Position × effect

``` text
front → defensive bonus
front → Armor
front → attack bonus
move → trigger
front enemy → damage
```

### Death × recursion

``` text
Death
→ Reanimate
→ Extinguish
→ return unit
→ new summon
```

### Board topology × effect

``` text
all allies
front ally
front enemy
same floor
all floors
random enemy
filtered subtype
```

------------------------------------------------------------------------

# 72. The most important lesson for Action Constitution v1

The effect library should not be allowed to define its own arbitrary
timing.

Instead:

``` text
EFFECT
```

describes **what** happens.

``` text
TRIGGER / ACTION / PHASE
```

describes **when it becomes eligible**.

``` text
RESOLUTION RULE
```

determines **when it executes relative to other eligible things**.

This prevents an effect such as "Apply Armor" from having an implicit
universal priority.

Armor can be:

``` text
Summon → Armor
```

or:

``` text
Revenge → Armor
```

or:

``` text
Resolve → Armor
```

and those are different semantic chains despite sharing the same
payload.

------------------------------------------------------------------------

# 73. The same payload can appear in many semantic positions

This is one of the most important Monster Train design patterns.

For example:

``` text
ARMOR
```

can happen:

``` text
on Summon
on Revenge
on Resolve
on Equipment
on Spell Play
on Status Conversion
on Forge
on Heal/Overheal
on Ability
```

Similarly:

``` text
ATTACK BUFF
```

can happen:

``` text
on Summon
on Strike
on Slay
on Rejuvenate
on Harvest
on Incant
on Equipment
on Resolve
on Status Threshold
```

This separation should become a core content-design principle for
Flashcard Heroes.

------------------------------------------------------------------------

# 74. Presentation implications

The presentation system should communicate the semantic trigger, not
merely the resulting numeric change.

For example:

``` text
Enemy dies
    ↓
Slay
    ↓
+5 Attack
```

is more understandable than:

``` text
+5 Attack
```

appearing with no causal indication.

Likewise:

``` text
Unit takes damage
    ↓
Revenge
    ↓
Apply Decay
```

should be visually readable as a retaliation.

This is especially important when multiple reactions are chained.

------------------------------------------------------------------------

# 75. Recommended player-facing semantic grammar

For Flashcard Heroes, the vocabulary should distinguish:

### Lifecycle

-   At the Start of Turn
-   At the End of Turn
-   At the End of Combat
-   When Summoned
-   When Destroyed
-   When Revived

### Action

-   When Attacking
-   Before Damage
-   After Damage
-   When an Ability Activates

### Reaction

-   When Damaged
-   When You Kill
-   When an Ally Dies
-   When an Enemy Dies
-   When Healed
-   When a Status is Applied
-   When a Status is Removed

### Persistent condition

-   While in Front
-   While Below X Health
-   While this Status is Active
-   While Equipped
-   During \[phase/state\]

The exact vocabulary should be finalized by the Flashcard Heroes design
team, but it should remain semantically consistent.

------------------------------------------------------------------------

# 76. Source-quality notes

The following sources were used for this reference.

### Trainworks Reloaded

The Base Game Card Effect Reference exposes a large catalog of concrete
CardEffect classes and their parameters, including damage, healing,
status manipulation, targeting, upgrades, movement, spawning, card
manipulation, resources, equipment, and room effects.

The Anatomy of a Card documentation explicitly describes:

-   CardEffects;
-   CardTriggers;
-   CardTriggerEffects;
-   CharacterTriggers;
-   RoomModifiers;
-   CardUpgrades;
-   Equipment.

### Current MT2 card database

RailTools indexes 564 MT2 cards in patch 2.2.1 and provides resolved
card text. It is useful for studying actual combinations of the building
blocks rather than only the engine API.

### MT2 end-of-turn discussion

The developer/community discussion provides the most detailed publicly
documented ordering for end-of-turn and end-of-combat effects.

------------------------------------------------------------------------

# 77. Evidence boundaries

### Verified

-   The exposed MT2 effect reference contains the documented effect
    families.
-   MT2 has explicit status-effect mechanics and trigger stages.
-   MT2 supports extensive target filters and target modes.
-   MT2 supports temporary/permanent upgrades.
-   MT2 supports status transfer/copy/multiplication.
-   MT2 supports scaling from numerous game-state values.
-   MT2 supports multiple damage types.
-   MT2 supports equipment and room modifiers as effect containers.
-   MT2 supports immediate attacks and ability-driven actions.
-   MT2's current card pool demonstrates the combinations described
    here.
-   The broad end-of-turn ordering is publicly documented.

### Observed in content

-   The same payloads are reused across many trigger types.
-   The same trigger types can target different scopes.
-   Statuses frequently become both state and scaling resources.
-   Abilities/cards/equipment/rooms reuse the same effect vocabulary.

### Not established

-   A universal hidden numeric priority for every effect.
-   A universal exact order among every individual status in a shared
    timing subphase.
-   Private implementation details not exposed by the modding/API
    references.

Do not convert unknown implementation details into assumed rules.

------------------------------------------------------------------------

# 78. How this should be used by the coding agent

The agent should use this document to answer:

> **What effect-building blocks does the current Flashcard Heroes
> architecture need to support if we want the content system to have
> Monster Train-level compositional depth?**

The agent should inspect the current codebase and map existing systems
against:

``` text
Trigger
Target
Condition
Effect
Status
Persistence
Scaling
Distribution
Source
Cause
Lifecycle
Follow-up Event
```

For each missing building block, determine whether it can be represented
by existing abstractions or whether a new abstraction is actually
required.

Do not reproduce Monster Train's class names or architecture
mechanically.

The target is a **Flashcard Heroes effect language with equivalent
expressive power and deterministic semantics**.

------------------------------------------------------------------------

# 79. Final design principle

Monster Train's mature content is not primarily impressive because it
contains hundreds of unique bespoke effects.

It is impressive because a relatively manageable vocabulary of:

``` text
TRIGGERS
+
TARGET SELECTORS
+
CONDITIONS
+
EFFECT PAYLOADS
+
STATUS STATES
+
SCALING SOURCES
+
PERSISTENCE RULES
+
LIFECYCLE EVENTS
```

can be recombined into a very large design space.

That is the building-block philosophy worth carrying into Flashcard
Heroes.

The goal of Action Constitution v1 should therefore be:

> **Every meaningful effect has a precise semantic meaning, every
> trigger has a precise timing condition, every target has a precise
> selection rule, every state mutation produces the appropriate event,
> and every resulting chain enters one deterministic resolution
> system.**

This lets a small set of well-defined primitives produce a large,
balanced, understandable content ecosystem without requiring bespoke
logic for every new ability.
