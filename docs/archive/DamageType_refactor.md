# AI Implementation Guide: Strict Damage Type Refactor

**Systemic Goal:** Implement a strictly decoupled Damage Type system in Flashcard Heroes. This refactor separates the logical behavior of damage (Armor mitigation, Spikes reflection) from the visual presentation (Melee lunges, Ranged projectiles).

**Architectural Mandate (Fail-Fast):** This is a complete, structural refactor. Do not write defensive fallbacks or default values for missing data. Remove all legacy data-routing traps. If an ability or pipeline fails to provide a `damage_type`, the game must crash at compile or runtime to expose the unmigrated code.

---

## Part I: Dependency & Impact Map

**Agent:** Use this map to understand how data flows through the combat pipeline. Check these intersections when altering signatures to ensure you do not break downstream consumers.

* **The DTO Contract (`EffectResult.gd` <-> Abilities):** All abilities must return an `EffectResult`. Modifying the dictionaries here requires updating every ability script that populates them.
* **The Orchestrator (`CombatSimulator.gd`):** Unpacks `EffectResult` and routes it. *Impact:* Deleting legacy fallback blocks here means any ability still returning raw integers or dictionaries will hard-crash.
* **The Processors (`EffectHandlers.gd`):** Translate requests into visual payloads and core math calls. *Impact:* Signatures here must match the new DTO contract. They package the `visual_payload` string (`attack_type: "melee" | "ranged" | "trinket"`) which dictates what `DamageAnimation.gd` renders.
* **The Core Math (`BattleManager.apply_damage`):** The ultimate source of truth for HP reduction. *Impact:* Altering armor or spikes math here directly dictates what values get passed back up to the visual payload and displayed as floating numbers.
* **The Reaction Loop (`trigger_on_hurt` <-> `AbilitiesRegistry.gd`):** Changing how `trigger_on_hurt` identifies the cause of damage impacts all Counter-Attack conditions (e.g., Aegis Charm vs. Retaliation).

---

## Part II: Execution Phases

### Phase 1: The Strict Enum Definition
**Target:** `scripts/Constants.gd`
Define the mechanical categories. No defaults.

```gdscript
enum DamageType {
    MELEE,   # Unit origin + targets only Frontmost Unit (or Shockwave). Mitigated by Armor, Triggers Spikes.
    RANGED,  # Unit origin + targets other units (Mirror, Random, All). Mitigated by Armor, NO Spikes.
    MAGIC,   # Trinket or System origin (no unit origin). Mitigated by Armor, NO Spikes.
    BURN,    # Status effect attacks (Burn). NO Armor, NO Spikes.
    SPIKES   # Status effect attacks (Spikes). Mitigated by Armor, NO Spikes.
}
```

### Phase 2: DTO Enforcement & Legacy Purge
**Targets:** `scripts/battle/EffectResult.gd`, `scripts/battle/CombatSimulator.gd`
* **Strict DTOs:** In `EffectResult.gd`, replace the untyped dictionaries for damage, cascade, and kamikaze requests with strict inner classes (e.g., `class DamageRequest extends RefCounted:`). Ensure their `_init` functions require a `damage_type: int`. This enforces the Fail-Fast mandate at compile/instantiation time.
* **Purge Legacy Handlers:** In `CombatSimulator.gd` (`resolve_effect_request`), delete legacy blocks checking `typeof(res) == TYPE_INT` or `TYPE_DICTIONARY`. Enforce that all abilities return an `EffectResult`.

### Phase 3: The Core Math Overhaul
**Target:** `scripts/BattleManager.gd`
* **Split the Math Logic:** Create `apply_damage(target, amount, damage_type, attacker_uuid = "")` to strictly handle HP reduction and combat math (Armor/Spikes).
* **General Stats:** Refactor `apply_stat_delta` to only handle generic stats (`pwr`, `burn_stacks`, `armor`, and positive `hp` healing). It should NOT process damage.
* **Armor Logic:** In `apply_damage`, apply armor reduction strictly for `MELEE`, `RANGED`, `MAGIC`, and `SPIKES`.
* **VFX Desync Prevention:** If `damage_type == C.DamageType.BURN`, bypass armor math entirely and explicitly set `armor_consumed = 0` in the return dictionary to prevent grey broken-armor numbers.
* **Spikes Logic:** Calculate and generate spikes_data strictly if `damage_type == C.DamageType.MELEE`.

### Phase 4: Pipeline Routing
**Targets:** `scripts/battle/EffectHandlers.gd`, `scripts/battle/CombatSimulator.gd`
* **EffectHandlers:** Update signatures of `handle_damage_effect` and `handle_cascade_damage` to require `damage_type: int`. Update internal calls from `apply_stat_delta` to `apply_damage`.
* **CombatSimulator Routing:** Extract `damage_type` from the new strict DTO objects (`DamageRequest`, etc.) in `EffectResult` and pass it down.
* **The Kamikaze Bypass:** In `CombatSimulator.gd`, extract `damage_type` from `kamikaze_request` and pass it directly to `bm.apply_damage`.

### Phase 5: The on_hurt Paradox (Burn vs. Counters)
**Targets:** `scripts/BattleManager.gd`, `scripts/AbilitiesRegistry.gd`
* **Context Injection:** When `apply_damage` processes `C.DamageType.BURN` at the start of a turn, ensure the resulting call to `trigger_on_hurt` passes `C.CAUSE_STATUS_EFFECT`.
* **Condition Updating:** In `AbilitiesRegistry.gd`, ensure all counter-attack abilities require `TRIGGER_CAUSE=ATTACK` so they do not attempt to counter environmental Burn damage.

### Phase 5.5: Systemic Bonus Burn (Burn Vial / Fire Trait)
**Targets:** `scripts/BattleManager.gd`, `scripts/battle/EffectHandlers.gd`, `scripts/BasicAttackEffect.gd`, custom effects.
* **Centralization:** Add `get_bonus_burn_stacks_for_attack` to `BattleManager.gd` as the single source of truth for bonus burn stacks.
* **All-Ranged Compliance:** Ensure that ANY custom effect or handler doing RANGED/MELEE damage explicitly calls this helper and applies the resulting burn stacks natively, bringing parity to all ranged/melee attacks regarding Trinket/Trait bonuses.

### Phase 6: Strict Ability Migrations
**Targets:** `scripts/abilities/*`, `scripts/AbilitiesRegistry.gd`
Refactor abilities to use the strict DTO pipeline.
* **Kamikaze (Death's Bargain):** Use `KamikazeRequest` with `damage_type = C.DamageType.RANGED` (ignores spikes), but keep visual `attack_type = "melee"`.
* **Scald (`EffectScald.gd`):** Use `DamageRequest` with `damage_type = C.DamageType.MAGIC`. Update target resolution to `TARGET_RANDOM_ENEMY`.
* **Shockwave (Berserker T2B):** Use `CascadeRequest` with `damage_type = C.DamageType.MELEE`. Ensure `attacker_uuid` is injected.
* **Fusion Spark (Trinket):** Use `DamageRequest` with `damage_type = C.DamageType.MAGIC`.
* **Burny Counter (Tier 1B):** Apply `burn_stacks` via `EffectHandlers.handle_burn_stacks`. The script must wrap the returned event using `return EffectResult.from_event(...)`. Update `AbilitiesRegistry.gd`.

### Phase 7: Verification (Agent Self-Check)
Autonomously search for any remaining scripts extending `EffectDefinition.gd` or implementing combat logic. Refactor them to comply with the strictly typed `EffectResult` requests.