# Action Constitution v1 --- Monster Train Resolution Research Reference

**Purpose:** Reference document for the coding/design agent when
auditing the current Flashcard Heroes codebase and producing **Action
Constitution v1**.

**Scope:** This document records research findings about Monster Train
1/2's action, trigger, effect, timing, ordering, semantics, and
presentation model. It is intentionally **not** an implementation
specification for Flashcard Heroes. The agent must inspect the current
codebase and documentation before deciding what existing systems can be
retained, refactored, or replaced.

**Evidence standard**

-   **Verified:** directly supported by exposed Monster Train 2 modding
    references, official/patch material, or documented game behavior.
-   **Observed/documented:** established through developer/community
    documentation of actual game behavior.
-   **Inference:** an architectural interpretation supported by several
    observations but not directly confirmed by proprietary source code.
-   **Recommendation:** a design requirement derived from the research
    and intended to guide the Flashcard Heroes constitution.

------------------------------------------------------------------------

## 1. Executive finding

Monster Train does not treat every occurrence in a run as an
undifferentiated "event" or every reaction as an undifferentiated
callback.

The observable model is a layered resolution system:

1.  A **phase or primary action** establishes what the game is currently
    doing.
2.  That action produces one or more **events/state changes**.
3.  Specific **triggers** become eligible when their semantic condition
    is satisfied.
4.  Trigger eligibility is tested separately from trigger execution.
5.  Trigger instances are queued with contextual information.
6.  Trigger effects can create new events, which can make additional
    triggers eligible.
7.  The current causal chain is resolved before unrelated primary
    progression continues.
8.  Deterministic phase, semantic, ownership, spatial, and stable-order
    rules resolve cases where multiple candidates are eligible.
9.  The player-facing presentation follows the resulting causal order
    closely enough that the visible sequence teaches the same rules as
    the simulation.

The central lesson for Flashcard Heroes is therefore:

> **Action order is not one priority list. It is a hierarchy of semantic
> timing rules, causal dependencies, deterministic scheduling rules, and
> explicit tie-breakers.**

------------------------------------------------------------------------

# 2. Monster Train's terminology and semantic vocabulary

Monster Train's terminology is unusually important because its
player-facing keywords correspond to distinct timing semantics.

The MT2 modding reference explicitly separates the internal trigger
names from their in-game names. This is evidence that the game has a
deliberate distinction between **engine vocabulary** and **player
vocabulary**.

## 2.1 Player-facing trigger semantics documented for MT2

  -------------------------------------------------------------------------------
  Player-facing term      Engine trigger               Semantic meaning
  ----------------------- ---------------------------- --------------------------
  Enchant                 `AfterSpawnEnchant`          Trigger associated with
                                                       the post-spawn enchantment
                                                       timing.

  Inspire                 `CardCorruptPlayed` /        Triggered by the
                          `CorruptionAdded`            corresponding
                                                       corruption/gain condition.

  Etch                    `CardExhausted`              Triggered when a card is
                                                       Consumed/exhausted on the
                                                       relevant floor.

  Rally                   `CardMonsterPlayed`          Triggered when a
                                                       non-Morsel monster/unit
                                                       card is played on the
                                                       floor.

  Incant                  `CardSpellPlayed`            Triggered when a spell is
                                                       played on the floor.

  End of Turn             `EndTurnPreHandDiscard`      End-of-round/end-of-turn
                                                       timing before the relevant
                                                       discard phase.

  Siphon                  `OnAnyHeroDeathOnFloor`      Triggered when a hero dies
                                                       on the floor.

  Hellborne Harvest       `OnAnyMonsterDeathOnFloor`   Triggered when a monster
                                                       dies on the floor.

  Harvest                 `OnAnyUnitDeathOnFloor`      Triggered when a unit dies
                                                       on the floor.

  Armored                 `OnArmorAdded`               Triggered when Armor is
                                                       added.

  Strike                  `OnAttacking`                Triggered by an attack.

  Strike --- alternative  `OnAttackingBeforeDamage`    Strike-like trigger
  timing                                               specifically placed before
                                                       damage.

  Extinguish              `OnDeath`                    Triggered by the unit's
                                                       death.

  Vanguard                `OnDeathwish`                Conditional trigger active
                                                       while the unit is in the
                                                       required positional
                                                       condition.

  Eaten                   `OnEaten`                    Triggered when the unit is
                                                       eaten.

  Celebrate               `OnEncounterComplete`        Triggered when the
                                                       encounter completes.

  Equipped                `OnEquipmentAdded`           Triggered when equipment
                                                       is added.

  Artificer               `OnEquipmentAddedToAlly`     Triggered when equipment
                                                       is added to an ally.

  Unequipped              `OnEquipmentRemoved`         Triggered when equipment
                                                       is removed.

  Gorge                   `OnFeed`                     Triggered when the unit
                                                       feeds/eats the relevant
                                                       food unit.

  Hunger                  `OnFoodSpawn`                Triggered when the
                                                       relevant food unit spawns.

  Graft Equipped          `OnGraftEquipmentAdded`      Triggered when graft
                                                       equipment is added.

  Rejuvenate              `OnHeal`                     Triggered when healed,
                                                       including the documented
                                                       full-health case.

  Revenge                 `OnHit`                      Triggered when damaged.

  Slay                    `OnKill`                     Triggered after dealing a
                                                       killing blow.

  Full Moon               `OnMoonLit`                  Conditional trigger while
                                                       the full-moon condition is
                                                       active.

  Mooncycle               `OnMoonPhaseShift`           Triggered when the moon
                                                       phase changes.

  New Moon                `OnMoonShade`                Conditional trigger while
                                                       the new-moon condition is
                                                       active.

  Conjure                 `OnOwnAbilityActivated`      Triggered when the unit's
                                                       own ability is activated.

  Conjure --- alternative `OnPreOwnAbilityActivated`   Pre-activation variant.

  Gelfuel                 `OnPyregelAdded`             Triggered when Pyregel is
                                                       added.

  Reanimated              `OnReanimated`               Triggered when the unit is
                                                       reanimated.

  Shift                   `OnShift`                    Triggered by
                                                       movement/shift semantics.

  Summon                  `OnSpawn`                    Triggered when a unit
                                                       spawns.

  Summon --- alternative  `OnSpawnNotFromCard`         Spawn trigger restricted
                                                       to the specified source
                                                       condition.

  On Team Turn            `OnTeamTurnBegin`            Fires at the end of
                                                       deployment and before
                                                       battling begins.

  Loop                    `OnTrainRoomLoop`            Triggered by the room loop
                                                       timing.

  Action                  `OnTurnBegin`                Unit-turn action timing.

  Valiant                 `OnValiant`                  Triggered when the unit
                                                       gains Valor / reaches the
                                                       relevant threshold.

  Ascension               `PostAscension`              Post-ascension timing.

  Resolve                 `PostCombat`                 Post-combat timing.

  Descension              `PostDescension`             Post-descension timing.

  Start of Turn           `PreCombat`                  Literally start of turn;
                                                       documented as occurring
                                                       before the hand is drawn.
  -------------------------------------------------------------------------------

**Important:** These are not interchangeable synonyms. For example,
**Start of Turn**, **Action**, **On Team Turn**, **End of Turn**, and
**Resolve** identify different semantic windows.

Source: MT2 Base Game Character Triggers.

------------------------------------------------------------------------

## 2.2 Important MT1 trigger semantics

MT1's documented status vocabulary includes:

-   **Action** --- triggers at the start of that unit's turn.
-   **End of Turn** --- end-of-turn timing.
-   **Extinguish** --- triggers on death.
-   **Harvest** --- triggers when a unit on the floor dies.
-   **Hellborne Harvest** --- triggers when one of the relevant team's
    units dies on the floor.
-   **Rejuvenate** --- triggers when healed, even at full health.
-   **Revenge** --- triggers when damaged.
-   **Slay** --- triggers after dealing a killing blow.
-   **Strike** --- triggers when attacking.
-   **Summon** --- triggers when played/summoned.
-   **Resolve** --- triggers after combat.
-   **Incant** --- triggers when a spell is cast on the floor.
-   **Rally** --- triggers when a non-Morsel unit card is played on the
    floor.
-   **Gorge** --- triggers when the unit eats a Morsel.
-   **Etch** --- triggers when a card is Consumed on the floor.
-   **Hatch** --- occurs when an Egg's Shell is completely removed and
    the Egg dies/hatches.
-   **Inspire** --- tied to gaining the relevant resource/condition.
-   **Hunger** --- tied to a unit with Eaten being summoned.
-   **Eaten** --- marks the relevant post-round eating behavior.

The important design lesson is that Monster Train names triggers after
the **semantic event or timing condition**, not after the implementation
mechanism.

------------------------------------------------------------------------

# 3. The action-order hierarchy

## 3.1 Ordinary combat action order

Monster Train 1 documentation/community confirmation establishes this
ordinary ordering:

1.  Quick enemy units, front to back.
2.  Quick friendly/player units, front to back.
3.  Non-Quick enemy units, front to back.
4.  Non-Quick friendly/player units, front to back.

Without Quick, this reduces to:

1.  Enemy units, front to back.
2.  Player units, front to back.

This is an **action scheduling rule**, not a reaction rule.

Source: Monster Train community discussion on attack order.

### Consequence

Position is not the only ordering dimension. The scheduler first
establishes the action class, then team ordering, then spatial ordering.

The rule is therefore conceptually:

``` text
action class
    → team
        → spatial position
```

rather than simply "front unit acts first."

------------------------------------------------------------------------

## 3.2 A unit's Action trigger is part of its turn timing

MT1 patch notes explicitly state that the **Action** trigger, previously
called "On Turn," is used on player units and triggers **on the unit's
turn, before it attacks**.

Therefore:

``` text
unit receives its turn
    → Action trigger
    → attack opportunity
```

is a meaningful semantic distinction.

The Action trigger is not merely another arbitrary passive reaction to
the attack.

------------------------------------------------------------------------

## 3.3 Team-turn start is separate from individual action

MT2's `OnTeamTurnBegin` is documented as occurring at the end of
deployment and **before battling starts**.

MT2's `PreCombat` is documented as the literal start of turn and occurs
before the hand is drawn.

This demonstrates that "start" is not one universal timing point. The
game has multiple nested lifecycle semantics.

------------------------------------------------------------------------

# 4. Primary action versus reaction

The research strongly supports treating the unit's scheduled attack as
different from triggers caused by that attack.

A useful conceptual distinction is:

### Primary action

The scheduler intentionally gives an actor an opportunity to perform a
normal game action.

Examples:

-   a unit's attack opportunity;
-   a start-of-turn operation;
-   a card play;
-   a player-initiated effect;
-   a management-phase operation.

### Reaction

A rule becomes eligible because something has already happened.

Examples:

-   Revenge because damage occurred;
-   Slay because a killing blow occurred;
-   Harvest because a unit died;
-   Rejuvenate because healing occurred;
-   Summon because a unit spawned.

This distinction is directly supported by the semantics of MT triggers
and by MT2's `QueueTrigger` architecture.

------------------------------------------------------------------------

# 5. Trigger eligibility is separate from trigger execution

MT2's status-effect architecture explicitly documents two stages:

1.  `TestTrigger`
2.  `OnTriggered`

`TestTrigger` determines whether the status should actually fire. If it
returns false, processing stops. If true, `OnTriggered` executes the
status effect.

Therefore the conceptual sequence is:

``` text
event occurs
    ↓
candidate trigger identified
    ↓
trigger eligibility tested
    ↓
trigger instance executes
```

This is important because "the condition happened" does not necessarily
mean "the effect executes."

Examples include:

-   a trigger being silenced;
-   a threshold not being met;
-   a trigger having an unavailable target;
-   a conditional trigger not currently being active;
-   trigger count modifications;
-   effects explicitly suppressing further triggers.

------------------------------------------------------------------------

# 6. Trigger instances carry context

MT2's custom-trigger documentation exposes `QueueTriggerParams`, which
carries contextual information into `CombatManager.QueueTrigger`.

Documented contextual fields include, among others:

-   dying character;
-   whether the character can attack or heal;
-   whether the character can fire triggers;
-   trigger count;
-   exclusive-trigger information;
-   fire-trigger data;
-   override target character.

This demonstrates that a trigger is not merely:

``` text
TriggerType = Revenge
```

It is a concrete trigger instance associated with contextual state.

For Action Constitution purposes, a trigger resolution record should
therefore preserve enough context to answer:

-   What caused this trigger?
-   Who owns it?
-   What event made it eligible?
-   What target/source does it use?
-   Was it allowed to fire?
-   How many times should it fire?
-   What phase/timing window is active?

The exact representation must be chosen after auditing the current
codebase.

------------------------------------------------------------------------

# 7. Strike demonstrates semantic sub-phases

MT2 exposes both:

-   `OnAttacking`
-   `OnAttackingBeforeDamage`

The second is explicitly an alternative Strike timing used by specific
effects.

This is direct evidence that "when attacking" can contain meaningful
sub-phases.

The practical semantic distinction is:

``` text
attack begins
    ↓
before-damage attack reactions
    ↓
damage
```

The key lesson is not to collapse all attack reactions into one generic
"OnAttack" callback if different mechanics need different causal
positions.

------------------------------------------------------------------------

# 8. Damage and Revenge demonstrate event causality

MT1 documents:

-   Revenge triggers when damaged.
-   Revenge still triggers on the killing blow.
-   Effects that prevent damage also prevent Revenge.

Therefore:

``` text
attack declared
    ↓
damage is evaluated
    ↓
damage is actually applied
    ↓
Revenge becomes eligible
```

The condition is **damage**, not merely an attempted attack.

This distinction must remain visible in both implementation semantics
and player-facing wording.

------------------------------------------------------------------------

# 9. Death, Slay, Extinguish and Harvest are distinct semantics

Monster Train deliberately distinguishes several death-related triggers.

### Extinguish

The dying unit's own death trigger.

### Slay

The attacker/source's reaction to having dealt the killing blow.

### Harvest

A floor-level reaction to a unit dying.

### Hellborne Harvest

A team-specific/floor-specific reaction to a relevant enemy death.

These cannot safely be collapsed into a generic `OnDeath`.

MT1 additionally documents that:

-   Slay happens after the killing blow.
-   Slay can respond to kills caused by abilities, not just ordinary
    melee attacks.
-   Extinguish cannot normally create a Slay response because the unit
    is already dead when Extinguish resolves.

The important semantic distinction is therefore:

``` text
who is reacting?
what happened?
what caused the death?
when is the unit considered dead?
```

------------------------------------------------------------------------

# 10. Summon is an event with its own semantic timing

MT2 exposes `OnSpawn` as the Summon trigger and also exposes
`OnSpawnNotFromCard` as an alternate form.

This matters because "a unit exists" and "a unit was summoned in this
specific way" can be different semantic facts.

The Action Constitution should preserve the distinction between:

-   the act that creates/spawns the unit;
-   the unit becoming present in the state;
-   summon-trigger eligibility;
-   effects caused by that summon.

------------------------------------------------------------------------

# 11. Conditional triggers are a separate semantic class

MT2 exposes conditional triggers such as:

-   Vanguard / `OnDeathwish`
-   Full Moon / `OnMoonLit`
-   New Moon / `OnMoonShade`

The modding reference explains that these have corresponding "lost"
triggers that undo the conditional state.

This gives a useful semantic distinction:

``` text
event trigger
```

versus:

``` text
state-condition trigger
```

An event trigger fires because an event occurred.

A conditional trigger becomes active because a condition becomes true
and remains active while that condition holds.

This should be explicit in Action Constitution terminology.

------------------------------------------------------------------------

# 12. End of Turn and End of Combat are different semantic phases

MT2's documented ordering makes this especially clear.

After a round of combat, the documented **end-of-turn** sequence is:

1.  Morsels / Eaten processing.
2.  Enemy Cherubs.
3.  Shell processing; Hatch can occur if Shell is fully removed.
4.  Enemy end-of-turn effects:
    -   Regen.
    -   Frostbite / Decay / Burnout / Witherbloom / Stealth.
    -   Corruption.
    -   Unstable.
5.  Friendly end-of-turn effects in the corresponding sequence.
6.  If Relentless continues, combat begins again.

After combat actually ends:

1.  Enemy Reap.
2.  Friendly Reap.
3.  Enemy healer processing and Resolve.
4.  Friendly Resolve.
5.  Enemy Valor.
6.  Friendly Valor.
7.  PostCombat room effects.
8.  End-of-Turn artifacts.
9.  Charged Echo cleanup.

The key finding is that **same-sounding timing labels do not imply one
flat queue**.

The game uses a semantic hierarchy within the phase.

Source: MT2 developer/community discussion documenting the full
end-of-turn/end-of-combat order.

------------------------------------------------------------------------

# 13. End-of-turn ordering is a model for explicit semantic phases

The end-of-turn sequence demonstrates that a robust Action Constitution
should permit:

``` text
phase
    → semantic family
        → actor/group
            → stable ordering
```

rather than requiring every effect in the entire game to share one
global priority value.

The documented order also establishes that Relentless is a major
lifecycle boundary: end-of-turn processing can occur while the combat
encounter remains active, whereas post-combat effects wait until combat
has actually ended.

------------------------------------------------------------------------

# 14. Spatial ordering is a deterministic tie-breaker

Monster Train's front-to-back attack order makes spatial topology part
of the rules.

The player's board position is not merely presentation:

-   it determines targeting;
-   it determines who is exposed to attacks;
-   it contributes to action order;
-   it affects which units remain alive when later actions occur.

Therefore a combat system should not treat spatial order as an
accidental array iteration order.

If spatial ordering is a mechanic, it must be represented as an explicit
rule.

------------------------------------------------------------------------

# 15. Monster Train uses semantics to define what a mechanic means

Several examples show that the semantic wording is intended to
correspond to a distinct condition:

-   **Strike** = attacking.
-   **Revenge** = being damaged.
-   **Slay** = dealing a killing blow.
-   **Extinguish** = dying.
-   **Harvest** = a unit dying on the floor.
-   **Rejuvenate** = being healed.
-   **Summon** = spawning/being played.
-   **Rally** = playing a relevant unit card.
-   **Incant** = playing a spell.
-   **Gorge** = feeding/eating.
-   **Resolve** = post-combat.
-   **Action** = the unit's own turn.
-   **Start of Turn** = lifecycle start before hand draw.
-   **On Team Turn** = the transition into the battle phase after
    deployment.

This is more than naming style. It gives players a stable mental model
for when a rule can fire.

------------------------------------------------------------------------

# 16. Player-facing terminology should distinguish timing from cause

For Action Constitution, timing words should have one stable meaning.

Recommended semantic categories for the design audit:

### Lifecycle timing

-   Start of Turn
-   Team Turn Start
-   End of Turn
-   End of Combat
-   Post Combat
-   Before Action
-   After Action

### Action timing

-   When Attacking
-   Before Damage
-   After Damage
-   Before/After an Ability

### State-event timing

-   When Damaged
-   When Healed
-   When Summoned
-   When a Status is Applied
-   When a Status is Removed
-   When Equipped
-   When Unequipped
-   When Moved
-   When Killed
-   When Revived

### Cause-specific timing

-   When You Kill
-   When an Ally Dies
-   When an Enemy Dies
-   When a Unit on This Floor Dies
-   When You Play a Unit
-   When You Play a Spell
-   When You Consume/Exhaust a Card

These should not be treated as interchangeable wording variants.

------------------------------------------------------------------------

# 17. Hidden/internal trigger semantics

MT2 also exposes triggers without player-facing names, including:

-   `OnBurnout`
-   `OnDeathwishLost`
-   `OnHatched`
-   `OnMoonlitLost`
-   `OnMoonshadeLost`
-   `OnNewStatusEffectAdded`
-   `OnQueuedStatusEffectToAdd`
-   `OnRemoveHatch`
-   `OnSilence`
-   `OnSilenceLost`
-   `OnStatusEffectChanged`
-   `OnTimebomb`
-   `OnTroopAdded`
-   `OnTroopRemoved`
-   `OnUnitAbilityAvailable`
-   `OnUnitAbilityUnavailable`
-   `OnUnscaledSpawn`
-   `PostAttemptedAscension`
-   `PostAttemptedDescension`
-   `PostCombatHealing`
-   `RegalCountAdded`

The modding reference explicitly states that hidden/internal triggers
generally should not receive player-facing descriptions.

This establishes a useful rule:

> **Engine-level distinctions can be finer-grained than player-facing
> semantic vocabulary.**

The player should see the stable concept that explains the mechanic;
implementation may require additional internal lifecycle events.

------------------------------------------------------------------------

# 18. Trigger versus status effect versus keyword

MT2's keyword documentation explicitly distinguishes:

-   Status Effects.
-   Triggers.
-   CardTraits.

The modding keyword decision tree says that a keyword that is a status
effect should be implemented as a status effect; a trigger on a
character is a character trigger; a trigger on a card is a card trigger;
and a keyword that modifies card behavior belongs to a CardTrait.

This demonstrates that "keyword" is a player-facing semantic layer,
while multiple engine constructs can implement different kinds of rules.

For Flashcard Heroes, the coding agent should similarly audit whether
the current project has accidentally conflated:

-   a displayed keyword;
-   a persistent state/status;
-   an event;
-   a trigger condition;
-   an effect;
-   an executable action.

------------------------------------------------------------------------

# 19. Priority should be semantic, not arbitrary

The research supports the following hierarchy for deciding order.

## 19.1 Causal necessity

If B cannot exist until A has occurred:

``` text
A → B
```

must resolve in that order.

Example:

``` text
damage → lethal determination → death
```

------------------------------------------------------------------------

## 19.2 Explicit semantic timing

If a mechanic is defined as "before damage," it must occur before
damage.

If it is "after combat," it must wait for combat to end.

------------------------------------------------------------------------

## 19.3 State consistency

Order operations so that downstream state is evaluated against the
intended state.

A strong MT1 example is a Cleanse/Spawn ordering change documented in
patch history: the operation order was changed so that the resulting
state matched the intended mechanic.

This is a state-invariant decision, not an arbitrary priority choice.

------------------------------------------------------------------------

## 19.4 Strategic/gameplay intent

When two orders are causally valid, the designer may deliberately choose
one because it produces the intended strategic interaction.

This decision must be recorded as a rule, not left to incidental
execution order.

------------------------------------------------------------------------

## 19.5 Player comprehension

Monster Train's patch history explicitly records reversing the sentence
order and trigger order of Crushing Demise to reduce player confusion.

This is direct evidence that the designers consider **understandability
of resolution order** a valid reason to change the order.

------------------------------------------------------------------------

## 19.6 Deterministic tie-breaker

Only after the meaningful semantic rules are exhausted should a stable
deterministic rule decide the order.

Potential categories include:

-   team/ownership;
-   spatial order;
-   effect/source order;
-   stable registration/order ID.

The specific Flashcard Heroes tie-breakers must be derived from the
actual game design rather than copied from Monster Train.

------------------------------------------------------------------------

# 20. Simulation order and presentation order must correspond

Monster Train's visible combat teaches players the game's deterministic
rules:

-   units visibly attack in the established action order;
-   reaction effects appear as consequences of preceding events;
-   deaths happen after lethal damage;
-   post-death effects occur in their semantic position;
-   end-of-turn/end-of-combat processing has a discernible lifecycle.

For Flashcard Heroes, the Action Constitution should require a single
authoritative resolution sequence.

The presentation layer should consume that sequence rather than
independently deciding what to show first.

A useful conceptual record is:

``` text
Resolution:
    sequence
    phase
    action/event/effect/trigger kind
    source
    target
    cause
    parent resolution
    semantic timing
    result
```

This is a **design requirement**, not a prescription for the current
code structure.

The coding agent should determine how the existing code can expose the
required information with minimal disruption.

------------------------------------------------------------------------

# 21. Causal chains should remain inspectable

A complex interaction should be explainable as:

``` text
Primary action
    → event
        → reaction
            → effect
                → new event
                    → reaction
```

rather than as an unexplained flat list of callbacks.

For example, conceptually:

``` text
Attack
  → Damage
      → Revenge
          → Damage
              → Death
                  → Extinguish
                  → Harvest
                  → Slay
```

The exact ordering of the final death-related reactions is game-specific
and must be defined explicitly in Action Constitution v1.

The important requirement is that each node has an identifiable
**cause**.

------------------------------------------------------------------------

# 22. "Primary action" is broader than combat

This distinction is important for Flashcard Heroes.

The constitution should not be called a **Combat Constitution**.

An action can originate from:

-   combat;
-   player management;
-   shop interaction;
-   path selection;
-   event selection;
-   item/trinket activation;
-   flashcard-related gameplay;
-   turn/round lifecycle;
-   enemy AI;
-   scripted encounter logic.

The same resolution principles apply:

``` text
Action
    → Event
        → Trigger eligibility
            → Reaction
                → Effect
                    → Event
```

Combat is one domain that produces actions and reactions; it is not the
entire resolution model.

------------------------------------------------------------------------

# 23. Monster Train's presentation lesson

The game does not need to expose engine terminology such as queue IDs or
trigger stages.

It does need to make the **semantic cause** visible.

Good presentation communicates:

``` text
Attack
↓
Damage
↓
Revenge
↓
Counter-effect
```

rather than visually presenting unrelated effects at the same time.

The player should be able to infer:

> "This happened because that happened."

This is especially important for simultaneous-looking effects.

------------------------------------------------------------------------

# 24. Requirements for Action Constitution v1

The coding agent should audit the existing project and produce a formal
constitution that answers all of the following.

## 24.1 Action identity

For every action class:

-   What creates it?
-   Who owns it?
-   What begins it?
-   What ends it?
-   Can it be cancelled?
-   Can it create reactions?
-   Can it create nested actions?
-   When is it considered complete?

------------------------------------------------------------------------

## 24.2 Event identity

For every event class:

-   What state change or occurrence produces it?
-   What information does it carry?
-   Which trigger families listen to it?
-   Does it represent an attempted operation or a successful state
    change?
-   Can it occur more than once within one action?

------------------------------------------------------------------------

## 24.3 Trigger identity

For every trigger family:

-   What exact condition makes it eligible?
-   What semantic phrase describes it?
-   Is it event-based or condition-based?
-   When is eligibility tested?
-   Can it be suppressed?
-   Can its count be modified?
-   What contextual information is required?

------------------------------------------------------------------------

## 24.4 Effect identity

For every effect:

-   What state does it mutate?
-   Does it generate an event?
-   Does it generate reactions?
-   Is it atomic?
-   Can it fail or be prevented?
-   Does it create another action?

------------------------------------------------------------------------

## 24.5 Ordering

The constitution must explicitly define:

1.  lifecycle phases;
2.  primary action scheduling;
3.  reaction scheduling;
4.  nested resolution;
5.  death/kill resolution;
6.  cleanup;
7.  end-of-phase processing;
8.  tie-breaking.

No critical order should depend on incidental engine execution order.

------------------------------------------------------------------------

# 25. Required distinction: eligibility, scheduling, execution, completion

These should be treated as separate concepts.

``` text
ELIGIBILITY
    Is this rule allowed to fire?

SCHEDULING
    It is eligible; when does it resolve?

EXECUTION
    What does it do?

COMPLETION
    What state/results mark it finished?
```

This distinction is directly supported by MT2's `TestTrigger` →
`OnTriggered` status-effect model and queued trigger mechanism.

------------------------------------------------------------------------

# 26. Required distinction: attempted versus successful operations

The constitution should distinguish:

``` text
attempted damage
```

from:

``` text
damage actually applied
```

and:

``` text
attempted summon
```

from:

``` text
unit actually spawned
```

and similarly for:

-   healing;
-   movement;
-   status application;
-   death;
-   card play;
-   equipment;
-   other state mutations.

Monster Train's Revenge behavior is a clear example: an effect that
prevents damage also prevents Revenge because the required state event
did not occur.

------------------------------------------------------------------------

# 27. Required distinction: condition versus event

A condition such as:

> Unit is in front.

is different from:

> Unit moved to the front.

Monster Train's conditional Vanguard semantics and Shift/movement
semantics demonstrate why this distinction matters.

A condition may establish an active state.

An event records something that happened.

The constitution should not use one interchangeably with the other.

------------------------------------------------------------------------

# 28. Required distinction: phase versus trigger

"End of Combat" is a phase/timing boundary.

"Resolve" is a trigger that fires at that boundary.

"Revenge" is a trigger caused by a damage event.

This distinction allows the constitution to say:

``` text
PHASE:
    End of Combat

TRIGGER:
    Resolve

CONDITION:
    Unit is eligible

EFFECT:
    Resolve ability
```

rather than encoding all three concepts into one overloaded term.

------------------------------------------------------------------------

# 29. Required distinction: effect versus trigger

A trigger describes **when/why** something becomes eligible.

An effect describes **what happens**.

Example:

``` text
Trigger:
    When Damaged

Effect:
    Gain 2 Armor
```

The player-facing text may combine them naturally, but the simulation
must retain the distinction.

------------------------------------------------------------------------

# 30. Action resolution should be deterministic before presentation

The authoritative order should be determined by simulation.

Presentation should then represent:

-   the same action order;
-   the same reaction order;
-   the same causal relationships;
-   the same state transitions.

Presentation may compress purely cosmetic steps, but it must not reorder
meaningful gameplay events.

If presentation needs to pause for readability, it should pause
**between already-determined resolution nodes**, not decide the next
game event dynamically.

------------------------------------------------------------------------

# 31. The coding agent's audit checklist

The agent should inspect the current codebase for:

### Scheduler

-   Is there a single authoritative source of primary action order?
-   Can unrelated actions interleave with unresolved reactions?
-   Is action completion explicitly represented?
-   Is action ordering deterministic?

### Events

-   Are state changes distinguishable from attempts?
-   Are events carrying their source/cause?
-   Can one effect silently mutate state without generating the event
    needed by reactions?

### Triggers

-   Are trigger eligibility and trigger execution separated?
-   Are triggers queued or recursively executed?
-   Can trigger order depend on node-tree traversal or dictionary/hash
    order?
-   Are trigger counts and suppression explicit?

### Effects

-   Are effects distinct from trigger conditions?
-   Can effects create events?
-   Are nested effects resolved deterministically?

### Context

-   Can a reaction determine what caused it?
-   Is the killing source preserved?
-   Is the initiating action preserved?
-   Is the original target preserved after redirects?
-   Is lethal state evaluated at the correct stage?

### Presentation

-   Does UI/VFX independently infer event order?
-   Can animations display an effect before its causal event?
-   Can multiple reactions visually appear simultaneous when the
    simulation treats them sequentially?
-   Can the presentation layer explain why a reaction occurred?

### Semantics

-   Do code names and player-facing names refer to the same semantic
    concept?
-   Are "before," "after," "when," "start," and "end" used consistently?
-   Are phase names distinct from trigger names?
-   Are hidden implementation events unnecessarily exposed to players?

------------------------------------------------------------------------

# 32. Required output of Action Constitution v1

The final Flashcard Heroes document should contain, at minimum:

## A. Action taxonomy

A complete list of action categories actually present in the game.

## B. Event taxonomy

A complete list of meaningful state/event boundaries.

## C. Trigger taxonomy

A complete list of player-facing trigger semantics and their exact
timing.

## D. Effect taxonomy

A complete list of state-changing effect categories.

## E. Phase model

A deterministic ordered list of lifecycle phases.

## F. Primary action scheduler

Exact rule for selecting the next primary action.

## G. Reaction scheduler

Exact rule for selecting the next eligible reaction.

## H. Nested resolution

Exact rule for effects generated by effects generated by reactions.

## I. Death/kill rules

Exact causal order for damage, lethal checks, death, death
prevention/revival, death triggers, kill triggers, and cleanup.

## J. Tie-breakers

Explicit deterministic rules for genuinely simultaneous candidates.

## K. Presentation contract

Exact relationship between simulation resolution records and visible
presentation.

## L. Player-facing semantics

The canonical vocabulary used consistently in:

-   effect descriptions;
-   tooltips;
-   status descriptions;
-   trigger names;
-   combat log;
-   VFX/event labels where applicable.

## M. Test matrix

Concrete interaction tests that prove every ordering rule.

------------------------------------------------------------------------

# 33. Recommended test philosophy

The most valuable tests are not isolated unit tests such as:

``` text
Revenge works.
```

They are ordering tests:

``` text
Attack
+ Revenge
+ lethal damage
+ Slay
+ Harvest
```

and tests where several independent reactions become eligible at the
same event.

Each test should verify:

1.  final state;
2.  resolution order;
3.  causal parent of each reaction;
4.  presentation order;
5.  deterministic repeatability.

The same scenario should produce the same resolution sequence every
time.

------------------------------------------------------------------------

# 34. Monster Train evidence that ordering is deliberately designed

Several independent pieces of evidence demonstrate that execution order
is part of the game design.

### Action ordering

Quick and front-to-back attack order is a deterministic gameplay rule.

### Semantic trigger stages

MT2 distinguishes `OnAttacking` from `OnAttackingBeforeDamage`.

### Trigger eligibility

MT2 separates `TestTrigger` from `OnTriggered`.

### Queued triggers

MT2 exposes `CombatManager.QueueTrigger`.

### Lifecycle hierarchy

MT2 has separate Team Turn, Start of Turn, Action, End of Turn,
PostCombat, Ascension, and Descension semantics.

### State-consistency ordering

Monster Train patch history documents changes to operation order when
the resulting state needed to match the intended mechanic.

### Player-comprehension ordering

Monster Train patch history explicitly documents changing Crushing
Demise's sentence/trigger order to reduce player confusion.

Together, these establish that ordering is a first-class gameplay
concern rather than an implementation accident.

------------------------------------------------------------------------

# 35. What should be treated as evidence versus inference

## Verified / directly documented

-   MT2 has explicit named character triggers and internal triggers.
-   MT2 distinguishes multiple trigger timings.
-   MT2 has `QueueTrigger`.
-   MT2 has `TestTrigger` and `OnTriggered` for status-effect trigger
    stages.
-   MT2 trigger parameters carry contextual information.
-   MT2 documents exact examples of distinct start/end/post-combat
    timings.
-   MT1/MT2 have deterministic combat ordering rules.
-   MT1 Revenge is based on actual damage, including lethal damage.
-   MT1 Slay is based on a killing blow.
-   MT1/MT2 distinguish Strike, Revenge, Slay, Extinguish, Harvest,
    Resolve, Summon, etc.
-   Monster Train changed at least one trigger/order presentation
    relationship specifically to reduce player confusion.

## Strong inference

-   Monster Train's overall model is best understood as nested
    deterministic resolution rather than a flat callback system.
-   A trigger instance is conceptually distinct from the primary action
    that caused it.
-   Causal context is important to the resolution system.
-   Presentation must reflect the semantic resolution order for the
    player to form correct expectations.

## Not established

This research does **not** establish a single universal numeric priority
value for every Monster Train trigger.

Where the proprietary source is unavailable, do not fabricate a global
priority table.

------------------------------------------------------------------------

# 36. Design principles to carry into Action Constitution v1

1.  **Name semantics before implementation.**
2.  **Give every meaningful timing window a precise meaning.**
3.  **Separate actions, events, triggers, effects, and phases.**
4.  **Separate trigger eligibility from trigger execution.**
5.  **Preserve causal context through nested resolution.**
6.  **Make ordering deterministic and explicit.**
7.  **Use semantic timing before arbitrary priority.**
8.  **Use state invariants to decide ambiguous order where applicable.**
9.  **Use gameplay intent for genuinely ambiguous design choices.**
10. **Use stable topology/order only as the final deterministic
    tie-breaker.**
11. **Make player-facing wording reflect the same semantic model used by
    code.**
12. **Make presentation consume authoritative resolution order.**
13. **Test interactions as ordered causal chains, not merely isolated
    effects.**
14. **Treat management-phase and combat-phase actions under the same
    general constitution.**
15. **Document every non-obvious ordering rule and its reason.**

------------------------------------------------------------------------

# 37. Canonical conceptual model

The research can be reduced to this model:

``` text
PHASE
  ↓
PRIMARY ACTION
  ↓
ACTION-SPECIFIC TIMING
  ↓
STATE CHANGE / EVENT
  ↓
TRIGGER ELIGIBILITY
  ↓
REACTION SCHEDULING
  ↓
REACTION EXECUTION
  ↓
NEW EVENT(S)
  ↓
NESTED RESOLUTION
  ↓
CLEANUP / NORMALIZATION
  ↓
ACTION COMPLETE
  ↓
NEXT PRIMARY ACTION
```

The presentation system observes the same resolved sequence:

``` text
AUTHORITATIVE RESOLUTION
        ↓
PRESENTATION SEQUENCE
        ↓
animation / VFX / numbers / UI feedback
```

The player-facing semantic vocabulary should describe the same
boundaries.

------------------------------------------------------------------------

# 38. References

### Monster Train 2 --- Trainworks Reloaded

-   Base Game Character Triggers\
    https://github-wiki-see.page/m/Monster-Train-2-Modding-Group/Trainworks-Reloaded/wiki/Base-Game-Character-Triggers

-   Custom Triggers\
    https://github-wiki-see.page/m/Monster-Train-2-Modding-Group/Trainworks-Reloaded/wiki/Custom-Triggers

-   Custom Status Effects\
    https://github-wiki-see.page/m/Monster-Train-2-Modding-Group/Trainworks-Reloaded/wiki/Custom-Status-Effects

-   MT2 Keywords\
    https://github-wiki-see.page/m/Monster-Train-2-Modding-Group/Trainworks-Reloaded/wiki/MT2-Keywords

### Monster Train 2 --- documented runtime behavior

-   End-of-combat ordering discussion containing the detailed
    developer-provided order\
    https://steamcommunity.com/app/2742830/discussions/0/562532756308978819/

### Monster Train 1

-   Status Effects / trigger semantics\
    https://monster-train.fandom.com/wiki/Status_Effects

-   Version History / ordering and wording changes\
    https://monster-train.fandom.com/wiki/Version_History

-   Attack order discussion\
    https://steamcommunity.com/app/1102190/discussions/0/2284960483097520924/

### Official Monster Train patch material

-   Friends & Foes update / Action trigger semantics\
    https://steamcommunity.com/games/1102190/announcements/detail/2845666883512849122

### Slay the Spire 2 comparative architecture

-   Architecture repository\
    https://github.com/Hexpion/Slay-the-spire-2/blob/main/Slay%20the%20Spire%202/ARCHITECTURE.md

-   Hook trigger order documentation\
    https://tutorials.sts2modding.com/en/docs/12-hook-trigger-order/

------------------------------------------------------------------------

# 39. Final instruction to the implementation agent

Use this document as **research evidence and a semantic reference**, not
as an assumed description of the current Flashcard Heroes architecture.

Before changing code:

1.  Inspect the current Action, EventBus, Ability, Effect, Combat,
    status, trinket, AI, management-phase, and presentation systems.
2.  Map the existing implementation to the concepts in this document.
3.  Identify where the current implementation already satisfies the
    constitution.
4.  Identify ambiguities, accidental ordering, duplicated concepts,
    missing causal context, and presentation/simulation divergence.
5.  Produce the project's **Action Constitution v1** based on the actual
    current codebase.
6.  Only then propose the smallest coherent architectural changes
    required to make the implementation deterministic, semantically
    consistent, testable, and player-understandable.

The objective is not to copy Monster Train's implementation.

The objective is to reproduce the **quality of its deterministic
semantic contract**: when multiple things can happen, the game has a
deliberate, stable, explainable reason for choosing what happens next,
and the player can learn that reason from the game's terminology and
presentation.
