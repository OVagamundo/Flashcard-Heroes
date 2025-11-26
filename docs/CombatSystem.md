# Combat System Architecture

The Combat System is built on a **Strict State-Event Decoupling** architecture. This ensures that the complex, instantaneous logic of the simulation is completely separated from the temporal, visual presentation of the battle.

## Core Philosophy: "Simulate First, Present Later"

The system is divided into two distinct, non-overlapping phases:

1.  **Simulation Phase (The Black Box):** The entire turn is calculated instantly. The result is a **TurnLog**—an ordered queue of `CombatEvent`s that describes *exactly* what happened, step-by-step.
2.  **Presentation Phase (The Dumb Player):** The UI receives the `TurnLog` and plays it back sequentially. The UI is **stateless** regarding the simulation; it only knows what the current event tells it.

> [!IMPORTANT]
> **The Golden Rule of Decoupling:**
> During the Presentation Phase, the UI must **NEVER** query the live `GachaBallInstance` or `BattleManager` for current state (e.g., `unit.current_hp`). The live data is already at the "End of Turn" state. The UI must *only* use the data provided in the `CombatEvent` to update itself.

---

## 1. The Simulation Phase (`BattleManager`)

The `BattleManager` acts as the authoritative simulation engine. It operates on the **Logical Model** (the `GachaBallInstance` data and `DataContainer` structures).

### Responsibilities
1.  **Snapshotting:** Captures the state of the board *before* any logic runs. This snapshot is sent to the Animator to reset the UI before playback.
2.  **Execution:** Runs the turn logic (Attacks, Abilities, Deaths, Summons) instantly.
3.  **Recording:** Generates a `CombatEvent` for *every* significant state change.
4.  **No Side Effects:** The simulation **must not** manipulate the SceneTree, play sounds, or spawn visual nodes directly. It only mutates data and records events.

### The Event Queue (TurnLog)
The output of the simulation is a linear queue of `CombatEvent` objects. This queue represents the **Causal History** of the turn.

**Causality Principle:**
Events must be ordered by cause and effect. A cause must *always* precede its effect in the queue.

*   **Correct:** `ATTACK_START` -> `DAMAGE` -> `DEATH` -> `SUMMON` -> `BUFF`
*   **Incorrect:** `DEATH` -> `BUFF` -> `SUMMON` (Violates causality; the buff source might be the summoned unit)

### Handling Complex Logic (Priority-Based Reaction Resolution)

The system uses a **Priority-Based Reaction System** to resolve complex interactions. Reactions are not instantaneous; they are collected, sorted by priority, and filtered by validity (e.g., lethality checks) before execution.

**1. The Priority Hierarchy**
Every effect and reaction has a priority value. Higher priority resolves first.
*   **Tier 1 (Highest):** State-Based Effects (e.g., "Mark of Death" detonation).
*   **Tier 2:** Counter-Attacks (Vengeful/Interrupting).
*   **Tier 3:** Defensive Reactions (Heals, Shields).
*   **Tier 4 (Lowest):** Standard cleanup/buffs.

**2. The Resolution Flow (Step-by-Step)**
When an action (like an Attack) occurs, the system follows this strict sequence:

1.  **Base Action:** The action executes fully.
    *   *Example:* AOE Attack deals 10 damage to Unit A and Unit B.
2.  **Lethality Check:** The system checks for deaths *immediately* after the action.
    *   *Example:* Unit A (0 HP) -> Dead. Unit B (0 HP) -> Dead.
3.  **Trigger Collection:** All applicable triggers (`on_hurt`, `on_death`) are collected into a pending list.
4.  **Validity Filtering:**
    *   **Dead Units:** Triggers from dead units are **discarded** unless the ability has the `execute_on_death` flag (e.g., Vengeful Counter).
    *   *Example:* Unit A's "On Hurt: Self Heal" is discarded because A is dead.
    *   *Example:* Unit A's "On Death: Heal Ally" is kept.
5.  **Priority Sorting:** The remaining valid triggers are sorted by their Priority Tier.
6.  **Execution:** The sorted triggers are executed one by one.

**Scenario: The AOE Chain (Corrected)**
*   **Setup:** AOE Attack targets Unit A (1 HP) and Unit B (1 HP). Unit A has "On Death: Heal Ally".
*   **Execution:**
    1.  **Action:** Damage A (10), Damage B (10).
    2.  **Check:** A is Dead. B is Dead.
    3.  **Triggers:**
        *   A: `OnDeath` (Heal Ally).
        *   B: `OnHurt` (Self Heal) - *Discarded* (B is dead).
    4.  **Resolution:** A's `Heal Ally` targets B.
    5.  **Result:** B is *already dead*. The heal targets a corpse (or is invalid).
    *   *Outcome:* Both die. The priority system correctly prevented the "zombie heal".

**Event Generation:**
Events are generated sequentially as they happen. The `TurnLog` reflects the final, causal reality: `AOE_DAMAGE` -> `DEATH (A)` -> `DEATH (B)` -> `HEAL (Invalid/Corpse)`.


---

## 2. The Presentation Phase (`BattleAnimator`)


The `BattleAnimator` is a dumb playback engine. It does not know rules; it only knows how to visualize events.

### Responsibilities
1.  **State Restoration:** Before playback, it uses the **State Snapshot** to reset all Unit Views to their "Start of Turn" values (HP, Position, Status).
2.  **Sequential Playback:** Iterates through the `TurnLog` one event at a time.
3.  **Visual State Management:**
    *   **Updates:** When a `DAMAGE` event plays, the Animator updates the target View's HP bar *visually* to match the event's `new_hp`.
    *   **Mutations:** When a `SUMMON` event plays, the Animator performs the visual container swap (removing the dead unit view, spawning the new unit view).
4.  **Blocking:** Waits for animations (e.g., projectile travel, death fade) to complete before processing the next event.

### Visual Queueing
The Animator maintains a **Visual Queue** of actions.
*   **Event:** `DAMAGE (Target: A, Amount: 10)`
*   **Visual Action:**
    1.  Play "Hurt" animation on View A.
    2.  Spawn "Floating Text -10".
    3.  Tween HP Bar from Current -> Current - 10.
    4.  Wait for Tween.

---

## 3. Data Structures

### `CombatEvent`
The atomic unit of the TurnLog.
```gdscript
class_name CombatEvent
enum Type { DAMAGE, HEAL, DEATH, SUMMON, BUFF, ... }

var type: Type
var source_uuid: String
var target_uuids: Array[String]
var payload: Dictionary # Flexible data (e.g., { "damage": 10, "is_crit": true })
var resultant_state: Dictionary # { target_uuid: { "hp": 50, "status": [...] } }
```

### `StateSnapshot`
Captured at the start of the turn.
```gdscript
{
    "unit_uuid": {
        "hp": 100,
        "pwr": 10,
        "container": "PlayerLineup",
        "index": 0,
        "status_effects": { "poison": 2 }
    }
}
```

---

## 4. Implementation Guidelines

### For Simulation Logic (Effects)
*   **DO:** Mutate `GachaBallInstance` properties (HP, PWR).
*   **DO:** Create `CombatEvent`s with all necessary data for the UI to visualize the change.
*   **DO NOT:** Call `get_node()` to find UI elements.
*   **DO NOT:** Emit signals that the UI listens to (except for debugging).
*   **DO NOT:** Mutate `DataContainer`s in a way that breaks the "Start of Turn" snapshot assumption, unless you explicitly handle it in the event metadata (like Summons).

### For Presentation Logic (Views)
*   **DO:** Listen to signals from `BattleAnimator`.
*   **DO:** Read data from the `CombatEvent` payload.
*   **DO NOT:** Read `BattleManager.get_instance(uuid).current_hp`. (This value is from the future!)
*   **DO NOT:** Start animations on your own. Wait for the Animator.

---

## 5. Example Flow: The "Summoning" Turn

1.  **Start:** Unit A (10 HP) holds "Summon Item".
2.  **Simulation:**
    *   Enemy attacks Unit A for 10 damage.
    *   Unit A HP -> 0.
    *   **Event:** `DAMAGE (Target: A, Amount: 10, NewHP: 0)`.
    *   Death Check: Unit A is dead.
    *   **Event:** `DEATH (Target: A)`.
    *   Trigger `on_death`: Summon Item activates.
    *   **Event:** `SUMMON (Source: A, NewUnit: B, Slot: 0)`.
    *   Trigger `on_ally_death`: Unit C gets +5 PWR.
    *   **Event:** `BUFF (Target: C, Amount: 5)`.
3.  **Presentation:**
    *   **Reset:** UI sets Unit A to 10 HP. Unit B is hidden/not created yet.
    *   **Play DAMAGE:** Unit A takes 10 damage (Visual HP -> 0).
    *   **Play DEATH:** Unit A plays death animation and fades out.
    *   **Play SUMMON:** Unit A's view is removed. Unit B's view is created in Slot 0 and fades in.
    *   **Play BUFF:** Unit C plays buff animation.