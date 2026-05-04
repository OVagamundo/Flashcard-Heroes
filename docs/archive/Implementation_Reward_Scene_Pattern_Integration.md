# Implementation: Reward Scene Pattern Integration

## Objective
Refactor the Reward Scene by integrating the **Rest Site** machine/slot architecture and the **Black Market** service overlay mechanics.

## 1. Logic Port: Rest Site Architecture
The Reward Scene must replicate the mechanics and layout of `RestSite.gd` and the black market bottom panels for the transform and remove to ensure system parity and visual consistency. make sure you know exactly what i mean about what parts os each scene i want you to use. if you need clarifications after reviewing those encounter´s code ask me for clarifications.

### 1.1 Token & Machine Logic
- **Reference:** `RestSite.gd`.
- **Mechanic:** Implement the same `StudyButton`  token generation and the `GachaMachine` spend/draw logic.
- **Labels:**  Add these labes to the machine buttons.
  - Machine 1: "Tier 1 prizes" (1 Token).
  - Machine 2: "Tier 2 prizes" (2 Tokens).
  - Machine 3: "Tier 3 prizes" (3 Tokens).

### 1.2 Slot Management
- **Reference:** `RestSite.gd` -> `PrizeLineup`.
- **Mechanic:** Use the same 5-slot `PrizeLineup` (without the hero on the first slot). 
- **Draw Animation:** Port the machine-to-slot "jump" animation used in the Rest Site and the slot to appropriate tier machine from the SHOP scene.

## 2. Interaction Port: Service Overlays
The Reward Scene must replicate the interaction model of the Black Market "Service Zones."

### 2.1 Contextual Overlays
- **Reference:** `Main.gd` / `Shop.gd` -> `ConfirmDropZone`.
- **Mechanic:** When a gachaball in the `PrizeLineup` is selected or dragged, display the dual-zone overlay similar to the black market.
- **Zones:**
  - **Left (Collect):** "Drag or click here to add it to your collection". 
  - **Right (Sell):** "Drag or click here to sell it". (Gold = $Tier \times Level \times 0.5$).


## 3. UI Guard & Auto-Collect
- **Reference:** `RestSite.gd` -> `_on_leave_pressed`.
- **Mechanic:** Sequential auto-collection of all remaining items in the `PrizeLineup` upon exiting.
- **Constraint:** Run inventory access must be blocked while a gachaball is selected or being dragged since the opened state of the run inventory panel would block the slots in the prize line up of the reward scene.
