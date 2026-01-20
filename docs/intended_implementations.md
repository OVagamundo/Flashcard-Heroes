# Intended Project Implementations (Session: Creating Unified Refactor Plan)

This document describes the specific features and architectural shifts requested during the "Creating Unified Refactor Plan" session.

## 1. Royal Insignia Trinket (New Implementation)
**Description**: 
A passive buff trinket that improves newly acquired or existing low-tier units.
- **Effect**: Grants **+2 HP and +2 PWR** to all Tier 1 units.
- **Visual Requirement**: Strict adherence to the "VCR Pattern". The unit must appear with its **Base Stats** (e.g., 2/2), followed immediately by the SAME buff animation used in combat
- **Scope**: Applies to both **Player and Enemy** teams on the battle board.
- **Triggers**:
    triggered by Gacha Draw, Summon, or Merge (only when units are placed on the board)
    - **Static**: triggered during the first Start Turn phase of combat for units already in the lineup of the team with the trinket.
- **Classes & Tags**: As specified in the first prompt, there are 6 classes for Tier 1 units: **Warrior, Defender, Support, Ranged, Mage, and Healer**. These are implemented as tags on the unit's definition. Every Tier 1 unit belongs to exactly one of these classes and also possesses the `tier_1` tag. The *Royal Insignia* targets units that have both the `tier_1` tag and one of these class tags.
- **Recursion Prevention**: Use the tag `buff_applied_[source_uuid]` on the target unit to prevent multiple applications.


---

## 2. Reward Reroll Mechanic
**Description**: 
The addition of a "Reroll" button to the **Battle Reward** just like the **Shop** scene.


## 3. Unified System Refactor (Refactor First!)
**Description**: 
A strict enforcement of **Simulation-Presentation Decoupling** across all phases of the game (start turn, Management, combat, end turn).

> [!IMPORTANT]
> **Priority**: The architectural refactor must be completed and verified BEFORE the Royal Insignia or Reroll features are implemented.

- **Objective**: Standardize the "Simulate First, Present Later" pattern. The UI must be "dumb" and only react to `CombatEvent` payloads, never querying live instance data.
- **Phases**:
    - **Combat**: Already event-driven; must remain the reference implementation.
    - **Management (Draw/Merge)**: Move from "Hybrid" (Direct mutation + redraw) to "Event-Driven" (Simulate sequence -> Generate TurnLog -> Playback).
- **No Defensive Code**: Use `assert()` to fail-fast on architectural violations instead of silently handling desyncs.
- **Animation Chaining**: Support linear sequences of management events (e.g., Draw -> Buff -> Merge -> Buff) without intermediate board redraws.

---

## 4. Burn Vial Trinket (Planned)
**Description**: 
- **Effect**: Applies 1 level of Burn on target hits.
- **Implementation Goal**: Handle team-wide triggers (`on_team_damage`) purely within the simulation state without visual-logic cross-pollution.
